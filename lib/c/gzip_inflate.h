#ifndef GZIP_STREAM_INFLATE_H
#define GZIP_STREAM_INFLATE_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct GzipDecoder GzipDecoder;

typedef void (*gzip_output_fn)(
    void *userdata,
    const uint8_t *data,
    size_t len
);

GzipDecoder *gzip_decoder_new(void);
void gzip_decoder_free(GzipDecoder *d);

int gzip_decoder_push(
    GzipDecoder *d,
    const uint8_t *data,
    size_t len,
    gzip_output_fn out,
    void *userdata
);

#ifdef __cplusplus
}
#endif

#endif
