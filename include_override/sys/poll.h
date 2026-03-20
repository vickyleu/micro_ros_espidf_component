/*
 * Minimal ESP-IDF-compatible poll definitions for standalone micro-ROS builds.
 */

#ifndef _MICRO_ROS_SYS_POLL_H_
#define _MICRO_ROS_SYS_POLL_H_

#define POLLIN      (1u << 0)
#define POLLRDNORM  (1u << 1)
#define POLLRDBAND  (1u << 2)
#define POLLPRI     (POLLRDBAND)
#define POLLOUT     (1u << 3)
#define POLLWRNORM  (POLLOUT)
#define POLLWRBAND  (1u << 4)
#define POLLERR     (1u << 5)
#define POLLHUP     (1u << 6)
#define POLLNVAL    (1u << 7)

#ifdef __cplusplus
extern "C" {
#endif

struct pollfd {
    int fd;
    short events;
    short revents;
};

typedef unsigned int nfds_t;

int poll(struct pollfd *fds, nfds_t nfds, int timeout);

#ifdef __cplusplus
}
#endif

#endif
