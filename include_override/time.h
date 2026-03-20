/*
 * Minimal ESP-IDF-compatible time wrapper for standalone micro-ROS builds.
 * Xtensa libc provides the base time types, while ESP-IDF adds POSIX timer
 * constants and declarations used by Micro XRCE-DDS.
 */

#pragma once

#include <sys/types.h>
#include_next <time.h>

#ifdef __cplusplus
extern "C" {
#endif

#define _POSIX_TIMERS 1
#ifndef CLOCK_MONOTONIC
#define CLOCK_MONOTONIC (clockid_t)4
#endif
#ifndef CLOCK_BOOTTIME
#define CLOCK_BOOTTIME (clockid_t)4
#endif

int clock_settime(clockid_t clock_id, const struct timespec *tp);
int clock_gettime(clockid_t clock_id, struct timespec *tp);
int clock_getres(clockid_t clock_id, struct timespec *res);

#ifdef __cplusplus
}
#endif
