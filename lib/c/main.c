#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include "gzip_inflate.h"

// 这是输出回调，把解码后的内容打印到 stdout
void print_output(void *userdata, const uint8_t *data, size_t len) {
    // userdata 可以忽略，这里不用
    fwrite(data, 1, len, stdout);
    printf("\n");
}

int main(void) {
    const char *gzip_file = "/Users/11048490/VSCodeProjects/fget/page.gz";  // 你的 gzip 文件路径

    // 打开文件
    FILE *fp = fopen(gzip_file, "rb");
    if (!fp) {
        perror("fopen");
        return 1;
    }

    // 获取文件大小
    fseek(fp, 0, SEEK_END);
    long fsize = ftell(fp);
    fseek(fp, 0, SEEK_SET);

    if (fsize <= 0) {
        fprintf(stderr, "文件为空或获取大小失败\n");
        fclose(fp);
        return 1;
    }

    // 分配缓冲区读取 gzip 文件
    uint8_t *input = (uint8_t *)malloc(fsize);
    if (!input) {
        fprintf(stderr, "内存分配失败\n");
        fclose(fp);
        return 1;
    }

    size_t read_len = fread(input, 1, fsize, fp);
    fclose(fp);

    if (read_len != fsize) {
        fprintf(stderr, "读取文件失败\n");
        free(input);
        return 1;
    }

    // 创建 gzip decoder
    GzipDecoder *decoder = gzip_decoder_new();
    if (!decoder) {
        fprintf(stderr, "创建 decoder 失败\n");
        free(input);
        return 1;
    }

    // 推送整个 gzip 数据流，输出回调打印内容
    int ret = gzip_decoder_push(decoder, input, fsize, print_output, NULL);
    if (ret != 0) {
        fprintf(stderr, "解码失败\n");
    }

    // 释放资源
    gzip_decoder_free(decoder);
    free(input);

    return ret;
}
