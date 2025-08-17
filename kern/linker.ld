ENTRY(_start)
posix_spawn_file_actions_addchdir
{
    . = 1M;
    .text : { *(.text) }
    .rodata : { *(.rodata) }
    .data : { *(.data) }
    .bss : { *(.bss) }
}