#include <stdio.h>
#include <errno.h>
#include <string.h>

/*
 * 修改文件名
 * from_path: 原文件路径
 * to_path: 新文件路径
 * 返回值:
 *   0  成功
 *  -1 失败，errno 可用
 */
int rename_file(const char* from_path, const char* to_path) {
    if (!from_path || !to_path) {
        return -1;
    }

    int rc = rename(from_path, to_path);
    if (rc != 0) {
        // 可以打印错误信息
        fprintf(stderr, "rename failed: %s -> %s, error: %s\n",
                from_path, to_path, strerror(errno));
        return -1;
    }

    return 0;
}
