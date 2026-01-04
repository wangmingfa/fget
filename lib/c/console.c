// console.c
#include <stdio.h>

#ifdef _WIN32
#include <windows.h>
#endif

void console_overwrite(const char* text) {
#ifdef _WIN32
    // Windows 10+ 需要启用 ANSI 支持
    static int enabled = 0;
    if (!enabled) {
        HANDLE hOut = GetStdHandle(STD_OUTPUT_HANDLE);
        DWORD dwMode = 0;
        GetConsoleMode(hOut, &dwMode);
        dwMode |= ENABLE_VIRTUAL_TERMINAL_PROCESSING;
        SetConsoleMode(hOut, dwMode);
        enabled = 1;
    }
#endif

    // \r        回到行首
    // \033[2K   清空整行
    printf("\r\033[2K%s", text);
    fflush(stdout);
}

void console_clear_line() {
    printf("\r\033[2K");
    fflush(stdout);
}

void console_newline() {
    printf("\n");
    fflush(stdout);
}
