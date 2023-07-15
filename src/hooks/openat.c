#include "nolibc.h"

__attribute__((section(".text.entry")))
int64_t my_openat(int fd, const char *filename, int flags, mode_t mode) {
	// Allows for "important" ioctls to be delivered
	if (0 == strcmp(filename, "/proc/self/exe")) {
		return my_syscall4(__NR_openat, fd, "/run/rosetta/rosetta", flags, mode);
	}
	return my_syscall4(__NR_openat, fd, filename, flags, mode);
}
