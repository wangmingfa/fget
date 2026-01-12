#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* ================= 输出回调 ================= */

typedef void (*gzip_output_fn)(
    void *userdata,
    const uint8_t *data,
    size_t len
);

/* ================= Huffman ================= */

#define MAXBITS 15
#define MAXLCODES 286
#define MAXDCODES 30
#define MAXCODES  (MAXLCODES + MAXDCODES)

typedef struct {
    uint16_t sym[1 << MAXBITS];
    uint8_t  len[1 << MAXBITS];
} HuffTable;

static void build_huffman(
    HuffTable *ht,
    const int *lengths,
    int n
) {
    int count[MAXBITS + 1] = {0};
    int next[MAXBITS + 1];
    int code = 0;

    for (int i = 0; i < n; i++)
        if (lengths[i])
            count[lengths[i]]++;

    for (int i = 1; i <= MAXBITS; i++) {
        code = (code + count[i - 1]) << 1;
        next[i] = code;
    }

    memset(ht, 0, sizeof(*ht));

    for (int sym = 0; sym < n; sym++) {
        int len = lengths[sym];
        if (!len) continue;

        int c = next[len]++;
        int rev = 0;
        for (int i = 0; i < len; i++) {
            rev = (rev << 1) | (c & 1);
            c >>= 1;
        }

        int fill = 1 << (MAXBITS - len);
        for (int i = 0; i < fill; i++) {
            int idx = (i << len) | rev;
            ht->sym[idx] = sym;
            ht->len[idx] = len;
        }
    }
}

/* ================= Decoder State ================= */

#define WSIZE 32768

typedef struct {
    /* input */
    const uint8_t *input;
    size_t in_len;
    size_t in_pos;

    /* bitstream */
    uint32_t bitbuf;
    int bitcnt;

    /* window */
    uint8_t window[WSIZE];
    size_t win_pos;

    /* huffman */
    HuffTable ll;
    HuffTable dd;

    /* state */
    int header_done;
    int finished;
    int last_block;
} GzipDecoder;

/* ================= Bitstream ================= */

static int bs_need(GzipDecoder *d, int bits) {
    while (d->bitcnt < bits) {
        if (d->in_pos >= d->in_len)
            return 0;
        d->bitbuf |= (uint32_t)d->input[d->in_pos++] << d->bitcnt;
        d->bitcnt += 8;
    }
    return 1;
}

static uint32_t bs_read(GzipDecoder *d, int bits) {
    if (!bs_need(d, bits))
        return (uint32_t)-1;
    uint32_t v = d->bitbuf & ((1u << bits) - 1);
    d->bitbuf >>= bits;
    d->bitcnt -= bits;
    return v;
}

static void bs_align(GzipDecoder *d) {
    d->bitbuf = 0;
    d->bitcnt = 0;
}

/* ================= Window ================= */

static void win_put(
    GzipDecoder *d,
    uint8_t c,
    gzip_output_fn out,
    void *ud
) {
    d->window[d->win_pos & (WSIZE - 1)] = c;
    d->win_pos++;
    out(ud, &c, 1);
}

static void win_copy(
    GzipDecoder *d,
    size_t dist,
    size_t len,
    gzip_output_fn out,
    void *ud
) {
    size_t pos = (d->win_pos - dist) & (WSIZE - 1);
    while (len--) {
        uint8_t c = d->window[pos & (WSIZE - 1)];
        pos++;
        win_put(d, c, out, ud);
    }
}

/* ================= Huff decode ================= */

static int huff_decode(GzipDecoder *d, HuffTable *ht) {
    if (!bs_need(d, MAXBITS))
        return -1;
    int idx = d->bitbuf & ((1 << MAXBITS) - 1);
    int len = ht->len[idx];
    d->bitbuf >>= len;
    d->bitcnt -= len;
    return ht->sym[idx];
}

/* ================= GZIP Header ================= */

static int gzip_try_skip_header(GzipDecoder *d) {
    if (d->in_len - d->in_pos < 10)
        return 0;

    const uint8_t *p = d->input + d->in_pos;
    if (p[0] != 0x1f || p[1] != 0x8b || p[2] != 8)
        return -1;

    int flg = p[3];
    size_t pos = 10;

    if (flg & 0x04) {
        if (d->in_len - d->in_pos < pos + 2)
            return 0;
        uint16_t xlen = p[pos] | (p[pos + 1] << 8);
        pos += 2 + xlen;
    }
    if (flg & 0x08)
        while (pos < d->in_len - d->in_pos && p[pos++]);
    if (flg & 0x10)
        while (pos < d->in_len - d->in_pos && p[pos++]);
    if (flg & 0x02)
        pos += 2;

    if (d->in_len - d->in_pos < pos)
        return 0;

    d->in_pos += pos;
    d->header_done = 1;
    return 1;
}

/* ================= Inflate ================= */

static int inflate_blocks(
    GzipDecoder *d,
    gzip_output_fn out,
    void *ud
) {
    static const int lbase[] = {
        3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,
        35,43,51,59,67,83,99,115,131,163,195,227,258
    };
    static const int lext[] = {
        0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,
        3,3,3,3,4,4,4,4,5,5,5,5,0
    };
    static const int dbase[] = {
        1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,
        257,385,513,769,1025,1537,2049,3073,
        4097,6145,8193,12289,16385,24577
    };
    static const int dext[] = {
        0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,
        7,7,8,8,9,9,10,10,11,11,12,12,13,13
    };

    while (!d->finished) {
        if (!d->last_block) {
            uint32_t last = bs_read(d, 1);
            uint32_t type = bs_read(d, 2);
            if ((int)type < 0)
                return 0;

            d->last_block = last;

            if (type == 0) {
                bs_align(d);
                if (d->in_len - d->in_pos < 4)
                    return 0;

                uint16_t len =
                    d->input[d->in_pos] |
                    (d->input[d->in_pos + 1] << 8);
                d->in_pos += 4;

                if (d->in_len - d->in_pos < len)
                    return 0;

                while (len--)
                    win_put(d, d->input[d->in_pos++], out, ud);

                d->last_block = 0;
                continue;
            }

            int ll_len[MAXLCODES] = {0};
            int d_len[MAXDCODES] = {0};

            if (type == 1) {
                for (int i = 0; i <= 143; i++) ll_len[i] = 8;
                for (int i = 144; i <= 255; i++) ll_len[i] = 9;
                for (int i = 256; i <= 279; i++) ll_len[i] = 7;
                for (int i = 280; i <= 285; i++) ll_len[i] = 8;
                for (int i = 0; i < 30; i++) d_len[i] = 5;
            } else {
                int hlit = bs_read(d, 5) + 257;
                int hdist = bs_read(d, 5) + 1;
                int hclen = bs_read(d, 4) + 4;

                static const int order[19] = {
                    16,17,18,0,8,7,9,6,10,5,
                    11,4,12,3,13,2,14,1,15
                };

                int clen[19] = {0};
                for (int i = 0; i < hclen; i++)
                    clen[order[i]] = bs_read(d, 3);

                HuffTable ch;
                build_huffman(&ch, clen, 19);

                int n = hlit + hdist;
                int i = 0;
                while (i < n) {
                    int sym = huff_decode(d, &ch);
                    if (sym < 16) {
                        if (i < hlit) ll_len[i++] = sym;
                        else d_len[i++ - hlit] = sym;
                    } else {
                        int rep = 0;
                        int val = 0;
                        if (sym == 16) {
                            rep = bs_read(d, 2) + 3;
                            val = (i == 0) ? 0 :
                                (i <= hlit ? ll_len[i - 1] : d_len[i - hlit - 1]);
                        } else if (sym == 17) {
                            rep = bs_read(d, 3) + 3;
                        } else {
                            rep = bs_read(d, 7) + 11;
                        }
                        while (rep--) {
                            if (i < hlit) ll_len[i++] = val;
                            else d_len[i++ - hlit] = val;
                        }
                    }
                }
            }

            build_huffman(&d->ll, ll_len, MAXLCODES);
            build_huffman(&d->dd, d_len, MAXDCODES);
        }

        int sym = huff_decode(d, &d->ll);
        if (sym < 0)
            return 0;

        if (sym < 256) {
            win_put(d, sym, out, ud);
        } else if (sym == 256) {
            if (d->last_block)
                d->finished = 1;
            d->last_block = 0;
        } else {
            int i = sym - 257;
            int len = lbase[i] + bs_read(d, lext[i]);
            int ds = huff_decode(d, &d->dd);
            int dist = dbase[ds] + bs_read(d, dext[ds]);
            win_copy(d, dist, len, out, ud);
        }
    }
    return 1;
}

/* ================= Public API ================= */

GzipDecoder *gzip_decoder_new(void) {
    return calloc(1, sizeof(GzipDecoder));
}

void gzip_decoder_free(GzipDecoder *d) {
    free(d);
}

int gzip_decoder_push(
    GzipDecoder *d,
    const uint8_t *data,
    size_t len,
    gzip_output_fn out,
    void *userdata
) {
    d->input = data;
    d->in_len = len;
    d->in_pos = 0;

    if (!d->header_done) {
        int r = gzip_try_skip_header(d);
        if (r <= 0)
            return r;
    }

    inflate_blocks(d, out, userdata);
    return 0;
}

typedef void* UserData;