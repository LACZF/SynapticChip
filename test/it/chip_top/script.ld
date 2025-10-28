OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY {
    ram (rwx) : ORIGIN = 0x00000000, LENGTH = 64K
}

SECTIONS {
    .text : {
        *(.text)
    } > ram

    .data : {
        *(.data)
    } > ram

    .bss : {
        *(.bss)
    } > ram

    /* 栈指针初始位置 */
    _stack_start = ORIGIN(ram) + LENGTH(ram) - 4;
}