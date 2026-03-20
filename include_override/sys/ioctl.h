/*
 * Minimal ESP-IDF-compatible ioctl declaration for standalone micro-ROS
 * builds. ESP-IDF 6.x expects this POSIX symbol via lwipopts.h, but the
 * regular Xtensa libc headers do not provide it.
 */

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

int ioctl(int fd, int request, ...);

#ifdef __cplusplus
}
#endif
