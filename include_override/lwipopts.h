#ifndef MICRO_ROS_LWIPOPTS_OVERRIDE_H
#define MICRO_ROS_LWIPOPTS_OVERRIDE_H

// Pull in ESP-IDF's lwipopts.h, then override socket compat for micro-ROS builds.
#include_next "lwipopts.h"

// ESP-IDF v5.5+ provides BSD socket names (accept, bind, send, …) via static
// inline wrappers in its own lwip/sockets.h.  Setting LWIP_COMPAT_SOCKETS to 1
// enables conflicting #define macros in the core lwIP headers that clash with
// those wrappers.  Keep it at 0 so only ESP-IDF's wrappers are active.
#ifdef LWIP_COMPAT_SOCKETS
#undef LWIP_COMPAT_SOCKETS
#endif
#define LWIP_COMPAT_SOCKETS 0

#endif
