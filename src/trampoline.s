trampoline:
str lr, [sp, -16]!
adrp x8, trampoline
add x8, x8, 0x1000
blr x8
ldr lr, [sp], 16
ldr x8, retaddr
br x8
retaddr:
.quad %retaddr%
.balign 4096
