#ifndef MICRO_ROS_LWIPOPTS_OVERRIDE_H
#define MICRO_ROS_LWIPOPTS_OVERRIDE_H

// Pull in ESP-IDF's lwipopts.h, then override socket compat for micro-ROS builds.
#include_next "lwipopts.h"

// ESP-IDF 5.5 的 lwip 包装层使用 static inline 函数
// 如果 LWIP_COMPAT_SOCKETS=1，原始 lwip 头文件会定义宏把 accept -> lwip_accept
// 这会导致 ESP-IDF 的 static inline accept 被替换成 static inline lwip_accept
// 与原始 lwip 的 int lwip_accept 声明冲突
// 设置为 0 禁用这些宏，让 ESP-IDF 的 static inline 正常工作
#ifdef LWIP_COMPAT_SOCKETS
#undef LWIP_COMPAT_SOCKETS
#endif
#define LWIP_COMPAT_SOCKETS 0

#endif
