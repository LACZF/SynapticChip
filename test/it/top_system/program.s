.section .text
.global _start

# 内存映射地址定义
.equ UART_BASE,      0x18000000
.equ UART_RBR,       0x18000000  # 接收缓冲区寄存器
.equ UART_THR,       0x18000000  # 发送保持寄存器
.equ UART_IER,       0x18000001  # 中断使能寄存器
.equ UART_IIR,       0x18000002  # 中断标识寄存器
.equ UART_FCR,       0x18000002  # FIFO控制寄存器
.equ UART_LCR,       0x18000003  # 线控制寄存器
.equ UART_MCR,       0x18000004  # Modem控制寄存器
.equ UART_LSR,       0x18000005  # 线状态寄存器
.equ UART_MSR,       0x18000006  # Modem状态寄存器
.equ UART_SCR,       0x18000007  # Scratch寄存器

# 栈指针初始地址
.equ STACK_TOP,      0x1000

_start:
    # 初始化栈指针
    li sp, STACK_TOP

    # 初始化UART
    call uart_init

    # 主循环
main_loop:
    # 检查是否有数据可读
    call uart_check_rx
    beqz a0, main_loop

    # 读取UART数据
    call uart_read_byte

    # 处理接收到的数据
    call process_command

    j main_loop

# UART初始化
uart_init:
    addi sp, sp, -8
    sw ra, 4(sp)

    # 设置波特率等参数（这里使用默认值）
    # 实际硬件中可能需要配置LCR等寄存器

    li a0, UART_LSR
    li a1, 0x60           # 使能FIFO，清除接收/发送FIFO
    sb a1, 0(a0)

    lw ra, 4(sp)
    addi sp, sp, 8
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

# 处理接收到的命令
# 参数: a0 = 接收到的字节
process_command:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    sw s1, 4(sp)

    mv s0, a0             # 保存接收到的字节

    # 命令处理逻辑
    # 示例1: 大小写转换 (A-Z <-> a-z)
    li s1, 'A'
    li t0, 'Z'
    bge s0, s1, check_upper_range
    j check_other_commands

check_upper_range:
    ble s0, t0, convert_to_lower

    li s1, 'a'
    li t0, 'z'
    bge s0, s1, check_lower_range
    j check_other_commands

check_lower_range:
    ble s0, t0, convert_to_upper
    j check_other_commands

convert_to_lower:
    # 大写转小写: +0x20
    addi s0, s0, 0x20
    j send_response

convert_to_upper:
    # 小写转大写: -0x20
    addi s0, s0, -0x20
    j send_response

check_other_commands:
    # 示例2: 数字命令
    li s1, '0'
    li t0, '9'
    bge s0, s1, check_digit_range
    j default_response

check_digit_range:
    ble s0, t0, digit_response
    j default_response

digit_response:
    # 数字保持不变，但可以添加前缀标识
    li a0, '['
    call uart_write_byte
    mv a0, s0
    call uart_write_byte
    li a0, ']'
    call uart_write_byte
    j process_end

default_response:
    # 默认回显
    mv a0, s0
    call uart_write_byte

send_response:
    mv a0, s0
    call uart_write_byte

process_end:
    lw ra, 12(sp)
    lw s0, 8(sp)
    lw s1, 4(sp)
    addi sp, sp, 16
    ret

# 延时函数（用于调试）
delay:
    addi sp, sp, -4
    sw ra, 0(sp)

    li t0, 1000
delay_loop:
    addi t0, t0, -1
    bnez t0, delay_loop

    lw ra, 0(sp)
    addi sp, sp, 4
    ret

.section .data
# 数据段可以在这里定义
message:
    .string "RISC-V UART Test Program\n"

.section .bss
# 未初始化数据段