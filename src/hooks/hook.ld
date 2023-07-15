OUTPUT_FORMAT(elf64-littleaarch64)
OUTPUT_ARCH(aarch64)
SECTIONS {
  . = 0x0;
  .text : {
	  KEEP(*(.text.entry*));
	  *(.text.entry*) *(.text*)
  }
  .data : { *(.data*) *(.rodata*) }
  .got : { *(.got.plt) *(.igot.plt) *(.got) *(.igot) }
  .bss : { *(.bss*); }
}
