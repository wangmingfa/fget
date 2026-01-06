// signal.c
#include "signal.h"

#ifdef _WIN32

// ============================
// Windows implementation
// ============================

#include <windows.h>
#include <stdatomic.h>

static atomic_int interrupted = 0;

static BOOL WINAPI console_handler(DWORD type) {
    switch (type) {
    case CTRL_C_EVENT:
    case CTRL_BREAK_EVENT:
    case CTRL_CLOSE_EVENT:
        interrupted = 1;
        return TRUE;
    default:
        return FALSE;
    }
}

void setup_signal_handler(int sig) {
    (void)sig; // Windows 不使用 POSIX signal 编号
    SetConsoleCtrlHandler(console_handler, TRUE);
}

int is_interrupted(int sig) {
    (void)sig;
    return interrupted;
}

void clear_signal(int sig) {
    (void)sig;
    interrupted = 0;
}

#else

// ============================
// Unix / macOS / Linux
// ============================

#include <signal.h>
#include <stdatomic.h>

#define MAX_SIGNAL 64

static atomic_int signal_flags[MAX_SIGNAL];

static void handle_signal(int sig) {
    if (sig >= 0 && sig < MAX_SIGNAL) {
        signal_flags[sig] = 1;
    }
}

void setup_signal_handler(int sig) {
    if (sig < 0 || sig >= MAX_SIGNAL) return;

    struct sigaction sa;
    sa.sa_handler = handle_signal;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = 0;

    sigaction(sig, &sa, NULL);
}

int is_interrupted(int sig) {
    if (sig < 0 || sig >= MAX_SIGNAL) return 0;
    return signal_flags[sig];
}

void clear_signal(int sig) {
    if (sig < 0 || sig >= MAX_SIGNAL) return;
    signal_flags[sig] = 0;
}

#endif
