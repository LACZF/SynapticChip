OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY {
    rom (rwx) : ORIGIN = 0x00000000, LENGTH = 32K
    bootrom (rwx) : ORIGIN = 0x01000000, LENGTH = 4K
    ram (rwx) : ORIGIN = 0x20000000, LENGTH = 4K
}

SECTIONS {
    .text : {
        *(.text)
    } > rom

    .data : {
        *(.data)
    } > ram

    .bootrom : {
        *(.bootrom)
    } > bootrom

    .bss : {
        *(.bss)
    } > ram

    /* 栈指针初始位置 */
    _stack_start = ORIGIN(ram) + LENGTH(ram) - 4;
}