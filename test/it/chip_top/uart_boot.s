.section .text
.global _start

# 地址定义
.equ IO_BASE,        0x40000000
.equ ROM_BASE,       0x00000000
.equ RAM_BASE,       0x20000000

# 内存映射地址定义
.equ UART_BASE,      IO_BASE   + 0x00020000
# .equ UART_BASE,      RAM_BASE  + 0x2000
.equ UART_RBR,       UART_BASE + 0x00  # 接收缓冲区寄存器
.equ UART_THR,       UART_BASE + 0x00  # 发送保持寄存器
.equ UART_IER,       UART_BASE + 0x04  # 中断使能寄存器
.equ UART_IIR,       UART_BASE + 0x08  # 中断标识寄存器
.equ UART_FCR,       UART_BASE + 0x0c  # FIFO控制寄存器
.equ UART_LCR,       UART_BASE + 0x10  # 线控制寄存器
.equ UART_MCR,       UART_BASE + 0x14  # Modem控制寄存器
.equ UART_LSR,       UART_BASE + 0x18  # 线状态寄存器
.equ UART_MSR,       UART_BASE + 0x1c  # Modem状态寄存器
.equ UART_SCR,       UART_BASE + 0x20  # Scratch寄存器
.equ UART_SMPR,      UART_BASE + 0x24  # 采样率寄存器
.equ UART_BDV_L,     UART_BASE + 0x28  # 分频系数低字节
.equ UART_BDV_H,     UART_BASE + 0x2C  # 分频系数高字节
.equ UART_BDV_VALUE_L,   0x2           # 仿真场景下速率较慢，设置为2分频
.equ UART_BDV_VALUE_H,   0x0
.equ UART_SIMPLE_CYCLES, 0x4           # 仿真场景下速率较慢，配置采样率为4倍

# 指令长度（字节数）
.equ INSTRUCTION_LENGTH, 4096  # 固定指令长度

.section .bootrom
_start:
    # 初始化堆栈指针
    li sp, RAM_BASE + 0x200

    # UART初始化
    call uart_init

    # 等待接收指令
    call receive_instructions

    # 跳转到RAM执行指令
    li a0, ROM_BASE
    jr a0

# UART初始化
uart_init:
    addi sp, sp, -8
    sw ra, 4(sp)

    # 设置波特率等参数（使用默认值）
    # 实际硬件中可能需要配置LCR等寄存器

    li a0, UART_LSR
    li a1, 0x60           # 使能FIFO，清除接收/发送FIFO
    sb a1, 0(a0)

    li a0, UART_SMPR
    li a1, UART_SIMPLE_CYCLES
    sb a1, 0(a0)

    li a0, UART_BDV_L
    li a1, UART_BDV_VALUE_L
    sb a1, 0(a0)

    li a0, UART_BDV_H
    li a1, UART_BDV_VALUE_H
    sb a1, 0(a0)

    # 发送初始化完成消息
    li a0, 'I'
    call uart_write_byte
    li a0, 'n'
    call uart_write_byte
    li a0, 'i'
    call uart_write_byte
    li a0, 't'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'O'
    call uart_write_byte
    li a0, 'K'
    call uart_write_byte
    li a0, 0x04
    call uart_write_byte
    li a0, '\n'
    call uart_write_byte

    lw ra, 4(sp)
    addi sp, sp, 8
    ret

# 接收指令并写入RAM
receive_instructions:
    addi sp, sp, -20
    sw ra, 16(sp)
    sw s0, 12(sp)  # 字节计数器
    sw s1, 8(sp)   # RAM地址指针
    sw s2, 4(sp)   # 临时数据累积寄存器

    # 初始化计数器
    li s0, 0
    li s1, ROM_BASE
    li s2, 0        # 清零临时数据寄存器

receive_loop:
    # 检查是否已接收完所有指令
    li t0, INSTRUCTION_LENGTH
    bge s0, t0, receive_done

    # 等待UART有数据可读
    call uart_check_rx
    beqz a0, receive_loop

    # 读取UART数据
    call uart_read_byte

    # 累积数据到临时寄存器
    # s2寄存器按字节位置存储数据：
    # 字节0 -> s2[7:0], 字节1 -> s2[15:8], 字节2 -> s2[23:16], 字节3 -> s2[31:24]
    andi a0, a0, 0xFF     # 确保只使用低8位
    li t1, 3
    and t2, s0, t1        # t2 = s0 % 4 (当前字节在字中的位置)
    slli t2, t2, 3        # 乘以8得到位移位数
    sll a0, a0, t2        # 将字节移动到正确位置
    or s2, s2, a0         # 累积到临时寄存器

    # 检查是否累积满4个字节（32位）
    andi t3, s0, 0x3      # 检查是否是4字节边界
    li t4, 0x3
    bne t3, t4, not_word_boundary

    # 累积满4个字节，写入32位字到RAM
    sw s2, 0(s1)
    li s2, 0              # 清零临时寄存器
    addi s1, s1, 4        # 地址递增4字节
    j increment_counter

not_word_boundary:
    # 未满4个字节，继续累积
    # 不写入RAM，只递增计数器

increment_counter:
    # 发送确认字符
    li a0, '.'
    call uart_write_byte

    # 递增计数器
    addi s0, s0, 1

    j receive_loop

receive_done:
    # 发送接收完成消息
    li a0, '\n'
    call uart_write_byte
    li a0, 'D'
    call uart_write_byte
    li a0, 'o'
    call uart_write_byte
    li a0, 'n'
    call uart_write_byte
    li a0, 'e'
    call uart_write_byte
    li a0, '!'
    call uart_write_byte
    li a0, '\n'
    call uart_write_byte

    lw ra, 16(sp)
    lw s0, 12(sp)
    lw s1, 8(sp)
    lw s2, 4(sp)
    addi sp, sp, 20
    ret

# 检查UART是否有数据可读
# 返回: a0 = 1(有数据), 0(无数据)
uart_check_rx:
    li a0, UART_LSR
    lb a0, 0(a0)
    andi a0, a0, 0x01     # 检查DR位(数据就绪)
    snez a0, a0
    ret

# 从UART读取一个字节
# 返回: a0 = 读取的字节
uart_read_byte:
    li a0, UART_RBR
    lb a0, 0(a0)
    ret

# 向UART写入一个字节
# 参数: a0 = 要发送的字节
uart_write_byte:
    addi sp, sp, -8
    sw ra, 4(sp)
    sw a0, 0(sp)

wait_tx_ready:
    li a1, UART_LSR
    lb a1, 0(a1)
    andi a1, a1, 0x20     # 检查THRE位(发送保持寄存器空)
    beqz a1, wait_tx_ready

    # 发送数据
    lw a0, 0(sp)
    li a1, UART_THR
    sb a0, 0(a1)

    lw ra, 4(sp)
    addi sp, sp, 8
    ret
