global _start
extern lilyspark_kern_main

section .txt
bits 32
_start:
    mov     esp, stack_top
    call    lilyspark_kern_main
    hlt

section .bss
stack_bottom:
    resb 4096
stack_top: