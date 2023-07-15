#include "nolibc.h"
#include "elf.h"

// Workaround for <https://github.com/NixOS/nixpkgs/issues/209242>
__attribute__((section(".text.entry")))
int64_t my_mmap(void *addr, size_t length, int prot, int flags, int fd, off_t offset) {
	//fprintf(stderr, "mmap addr=%p fd=%d, offset=%lu length=%zu prot=%x\n", addr, fd, offset, length, prot);
	int64_t ret = my_syscall6(__NR_mmap, addr, length, prot, flags, fd, offset);

	if (ret < 0) {
		return ret;
	}

	if (addr == 0 && fd > 0 && offset == 0 && prot == PROT_READ && length > 64 && length < 1000) {
		void *ptr = (void*)ret;
		if (0 != memcmp(ELFMAG, ptr, SELFMAG)) {
			// Not an ELF
			return ret;
		}

		Elf64_Ehdr *eh = (Elf64_Ehdr*)ptr;
		size_t phnum = eh->e_phnum;
		if (length != phnum * 0x38 + 0x40) {
			// Not trying to map the header or the bug has been fixed
			return ret;
		}

		Elf64_Phdr *ph = (Elf64_Phdr*)(ptr + 0x40);
		size_t header_end = 0;
		for (size_t i = 0; i < phnum; ++i) {
			if (ph[i].p_type == PT_INTERP) {
				header_end = ph[i].p_offset + ph[i].p_filesz;
				break;
			}
		}

		if (!header_end || length >= header_end) {
			// No interpreter or already mapped enough
			return ret;
		}

		my_syscall2(__NR_munmap, addr, length);
		return my_syscall6(__NR_mmap, addr, header_end, prot, flags, fd, offset);
	}

	return ret;
}
