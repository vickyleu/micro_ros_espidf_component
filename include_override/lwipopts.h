#ifndef MICRO_ROS_LWIPOPTS_OVERRIDE_H
#define MICRO_ROS_LWIPOPTS_OVERRIDE_H

// Pull in ESP-IDF's lwipopts.h, then override socket compat for micro-ROS builds.
#include_next "lwipopts.h"

#ifdef LWIP_COMPAT_SOCKETS
#undef LWIP_COMPAT_SOCKETS
#endif
#define LWIP_COMPAT_SOCKETS 1

#endif
