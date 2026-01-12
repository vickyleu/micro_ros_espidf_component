#pragma once

// Fallback sdkconfig.h for micro-ROS host builds.
// Prefer the real sdkconfig.h if it's already on the include path.
#if defined(__has_include_next)
#  if __has_include_next("sdkconfig.h")
#    include_next "sdkconfig.h"
#  endif
#endif

// Minimal defaults to unblock compilation when sdkconfig.h is unavailable.
#ifndef CONFIG_IDF_TARGET_ESP32S3
#define CONFIG_IDF_TARGET_ESP32S3 1
#endif
