/*
 * Minimal ESP-IDF-compatible esp_newlib declarations for standalone micro-ROS
 * builds under IDF 6.x.
 */

#pragma once

#include "sdkconfig.h"
#include <sys/reent.h>

#ifdef __cplusplus
extern "C" {
#endif

void esp_libc_init(void);
void esp_setup_syscall_table(void) __attribute__((deprecated("Please call esp_libc_init() in newer code")));

#if CONFIG_VFS_SUPPORT_IO
void esp_libc_init_global_stdio(const char *stdio_dev);
#else
void esp_libc_init_global_stdio(void);
#endif

void esp_libc_time_init(void);

#if CONFIG_LIBC_NEWLIB
void esp_reent_init(struct _reent *r);
#endif

void esp_reent_cleanup(void);
void esp_set_time_from_rtc(void);
void esp_sync_timekeeping_timers(void);
void esp_libc_locks_init(void);

#define esp_sync_counters_rtc_and_frc esp_sync_timekeeping_timers

void esp_newlib_time_init(void) __attribute__((deprecated("Please use esp_libc_time_init instead")));
void esp_newlib_init(void) __attribute__((deprecated("Please use esp_libc_init instead")));
void esp_newlib_locks_init(void) __attribute__((deprecated("Please use esp_libc_locks_init instead")));

#ifdef __cplusplus
}
#endif
