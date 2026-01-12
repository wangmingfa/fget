cmake_minimum_required(VERSION 3.20)
project(gzip_test C)

set(CMAKE_C_STANDARD 99)

# 添加可执行文件
add_executable(main
        main.c
        gzip_inflate.c    # ✅ 一定要加上实现文件
)
