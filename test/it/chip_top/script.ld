OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY {
    rom (rwx) : ORIGIN = 0x00000000, LENGTH = 32K
    ram (rwx) : ORIGIN = 0x20000000, LENGTH = 4K
    data (rwx) : ORIGIN = 0x20000C00, LENGTH = 4K
}

SECTIONS {
    .text : {
        *(.text)
    } > rom

    .data : {
        *(.data)
    } > ram

    .bss : {
        *(.bss)
    } > ram

    /* 栈指针初始位置 */
    _stack_start = ORIGIN(ram) + LENGTH(ram) - 4;
}