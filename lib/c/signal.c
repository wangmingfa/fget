#include "signal.h"
#include <stddef.h>

#if defined(_WIN32)

// =====================
// Windows
// =====================

#include <windows.h>
#include <signal.h>   // sig_atomic_t

// Windows 无法区分 POSIX signal，这里统一用一个标志
static volatile sig_atomic_t interrupted = 0;

/*
 * Windows console handler
 */
static BOOL WINAPI console_handler(DWORD type) {
    switch (type) {
        case CTRL_C_EVENT:
        case CTRL_CLOSE_EVENT:
        case CTRL_BREAK_EVENT:
        case CTRL_SHUTDOWN_EVENT:
            interrupted = 1;
            return TRUE;
        default:
            return FALSE;
    }
}

void setup_signal_handler(int sig) {
    (void)sig; // Windows 忽略 sig
    SetConsoleCtrlHandler(console_handler, TRUE);
}

int is_interrupted(int sig) {
    (void)sig; // Windows 无法区分 signal
    return interrupted != 0;
}

void clear_signal(int sig) {
    (void)sig;
    interrupted = 0;
}

#else

// =====================
// Unix (Linux / macOS)
// =====================

#include <signal.h>

// 用数组保存各 signal 的状态
// NSIG 是系统支持的最大 signal 数量
static volatile sig_atomic_t signal_flags[NSIG] = {0};

/*
 * POSIX signal handler
 */
static void handle_signal(int sig) {
    if (sig > 0 && sig < NSIG) {
        signal_flags[sig] = 1;
    }
}

void setup_signal_handler(int sig) {
    if (sig <= 0 || sig >= NSIG) {
        return;
    }

    struct sigaction sa;
    sa.sa_handler = handle_signal;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;
    sigaction(sig, &sa, NULL);
}

int is_interrupted(int sig) {
    if (sig <= 0 || sig >= NSIG) {
        return 0;
    }
    return signal_flags[sig] != 0;
}

void clear_signal(int sig) {
    if (sig <= 0 || sig >= NSIG) {
        return;
    }
    signal_flags[sig] = 0;
}

#endif
