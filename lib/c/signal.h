#ifndef MB_SIGNAL_H
#define MB_SIGNAL_H

#ifdef __cplusplus
extern "C" {
#endif

void setup_signal_handler(int sig);
int  is_interrupted(int sig);
void clear_signal(int sig);

#ifdef __cplusplus
}
#endif

#endif
