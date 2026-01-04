// console.h
#ifndef CONSOLE_H
#define CONSOLE_H

#ifdef __cplusplus
extern "C" {
#endif

void console_overwrite(const char* text);
void console_clear_line(void);
void console_newline(void);

#ifdef __cplusplus
}
#endif

#endif
