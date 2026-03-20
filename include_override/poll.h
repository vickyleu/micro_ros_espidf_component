/*
 * Standalone micro-ROS builds on IDF 6.x need poll declarations, but the
 * regular Xtensa libc headers do not ship poll.h.
 */

#pragma once

#include <sys/poll.h>
