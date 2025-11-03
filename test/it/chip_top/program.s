.section .text
.global _start

.equ IO_BASE,        0x40000000
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

# GPIO模块地址定义
.equ GPIO_BASE,      IO_BASE   + 0x00030000
.equ GPIO_IN_DATA,   GPIO_BASE + 0x00  # 输入数据寄存器
.equ GPIO_OUT_DATA,  GPIO_BASE + 0x04  # 输出数据寄存器
.equ GPIO_IO_DIR,    GPIO_BASE + 0x08  # IO方向寄存器
.equ GPIO_IO_DATA,   GPIO_BASE + 0x0C  # IO数据寄存器

# Timer模块地址定义
.equ TIMER_BASE,     IO_BASE    + 0x00010000
.equ TIMER_CTRL,     TIMER_BASE + 0x00  # 控制寄存器
.equ TIMER_INTR,     TIMER_BASE + 0x04  # 中断寄存器
.equ TIMER_EXPR,     TIMER_BASE + 0x08  # 最大值寄存器
.equ TIMER_COUNTER,  TIMER_BASE + 0x0C  # 计数器寄存器

# SPI模块地址定义
.equ SPI_BASE,       IO_BASE  + 0x00040000
.equ SPI_CONTROL,    SPI_BASE + 0x00  # 控制寄存器
.equ SPI_STATUS,     SPI_BASE + 0x04  # 状态寄存器
.equ SPI_DATA,       SPI_BASE + 0x08  # 数据寄存器
.equ SPI_ADDR,       SPI_BASE + 0x0C  # 地址寄存器
.equ SPI_CMD,        SPI_BASE + 0x10  # 命令寄存器
.equ SPI_CLK_DIV,    SPI_BASE + 0x14  # 时钟分频寄存器
.equ SPI_CONFIG,     SPI_BASE + 0x18  # 配置寄存器
.equ SPI_CS_SEL,     SPI_BASE + 0x1C  # 片选寄存器

# PE模块地址定义
.equ PE_TOP_BASE,    0x30000000
.equ PE_CTRL_ADDR,   PE_TOP_BASE + 0x00  # 控制寄存器
.equ PE_STATUS_ADDR, PE_TOP_BASE + 0x04  # 状态寄存器
.equ PE_INST_ADDR,   PE_TOP_BASE + 0x08  # 指令寄存器
.equ PE_DATA_ADDR,   PE_TOP_BASE + 0x0c  # 数据寄存器
.equ PE_ROUTE_ADDR,  PE_TOP_BASE + 0x10  # 路由配置寄存器

# PE控制寄存器位定义
.equ PE_EN_BIT,      0                   # 使能位
.equ PE_RESET_BIT,   1                   # 复位位

# 栈指针初始地址
.equ STACK_TOP,      RAM_BASE + 0x1000

_start:
    # 初始化栈指针
    li sp, STACK_TOP

    # 初始化UART
    call uart_init

    # 发送字符'O'
    li a0, 'O'
    call uart_write_byte

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

    li a0, UART_SMPR
    li a1, 0x10           # 配置采样率为16倍
    sb a1, 0(a0)

    li a0, UART_BDV_L
    li a1, 0x2           # 仿真场景下速率较慢，设置为2分频
    sb a1, 0(a0)

    li a0, UART_BDV_H
    li a1, 0x0
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

    # 检查是否为GPIO模块相关命令
    li s1, 'g'
    beq s0, s1, gpio_test_command
    li s1, 'G'
    beq s0, s1, gpio_test_command

    # 检查是否为SPI模块相关命令
    li s1, 's'
    beq s0, s1, spi_test_command
    li s1, 'S'
    beq s0, s1, spi_test_command

    # 检查是否为Timer模块相关命令
    li s1, 't'
    beq s0, s1, timer_test_command
    li s1, 'T'
    beq s0, s1, timer_test_command

    # 检查是否为PE模块相关命令
    li s1, 'p'
    beq s0, s1, pe_test_command
    li s1, 'P'
    beq s0, s1, pe_test_command

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

# PE模块测试命令处理
pe_test_command:
    li a0, 'P'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, ':'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte

    # 执行PE模块测试
    call test_pe_module

    j process_end

# PE模块测试函数
test_pe_module:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    sw s1, 4(sp)
    sw s2, 0(sp)

    # 打印测试标题
    li a0, '='
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'P'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    call print_newline

    # 1. 测试读取PE状态寄存器
    li s0, PE_STATUS_ADDR
    lw s1, 0(s0)

    # 打印状态寄存器值
    li a0, 'S'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'A'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'U'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    mv a0, s1
    call print_hex
    call print_newline

    # 2. 复位PE模块
    li s0, PE_CTRL_ADDR
    li s1, 1<<PE_RESET_BIT     # 设置复位位
    sw s1, 0(s0)
    call delay                 # 等待复位完成
    call delay
    call delay

    # 清除复位位
    li s1, 0
    sw s1, 0(s0)
    call delay

    li a0, 'R'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    li a0, 'D'
    call uart_write_byte
    li a0, 'O'
    call uart_write_byte
    call print_newline

    # 3. 使能PE模块
    li s0, PE_CTRL_ADDR
    li s1, 1<<PE_EN_BIT        # 设置使能位
    sw s1, 0(s0)

    li a0, 'E'
    call uart_write_byte
    li a0, 'N'
    call uart_write_byte
    li a0, 'A'
    call uart_write_byte
    li a0, 'B'
    call uart_write_byte
    li a0, 'L'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    li a0, '1'
    call uart_write_byte
    call print_newline

    # 4. 指令测试 - 算术运算测试
    # li a0, '\n'
    li a0, '!'
    call uart_write_byte
    li a0, 'A'
    call uart_write_byte
    li a0, 'R'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'H'
    call uart_write_byte
    li a0, 'M'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, 'C'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    call print_newline

    # 4.1 ADD指令测试
    li s0, PE_INST_ADDR
    li s1, 0x00000001          # ADD指令测试
    sw s1, 0(s0)
    call delay                 # 等待指令执行

    li a0, 'A'
    call uart_write_byte
    li a0, 'D'
    call uart_write_byte
    li a0, 'D'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    mv a0, s1
    call print_hex
    call print_newline

    # 读取结果
    li s0, PE_DATA_ADDR
    lw s1, 0(s0)
    li a0, 'R'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    mv a0, s1
    call print_hex
    call print_newline

    # 4.2 SUB指令测试
    li s0, PE_INST_ADDR
    li s1, 0x00000002          # SUB指令测试
    sw s1, 0(s0)
    call delay                 # 等待指令执行

    li a0, 'S'
    call uart_write_byte
    li a0, 'U'
    call uart_write_byte
    li a0, 'B'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    mv a0, s1
    call print_hex
    call print_newline

    # 读取结果
    li s0, PE_DATA_ADDR
    lw s1, 0(s0)
    li a0, 'R'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    mv a0, s1
    call print_hex
    call print_newline

    # 4.3 MUL指令测试
    li s0, PE_INST_ADDR
    li s1, 0x00000003          # MUL指令测试
    sw s1, 0(s0)
    call delay                 # 等待指令执行

    li a0, 'M'
    call uart_write_byte
    li a0, 'U'
    call uart_write_byte
    li a0, 'L'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    mv a0, s1
    call print_hex
    call print_newline

    # 读取结果
    li s0, PE_DATA_ADDR
    lw s1, 0(s0)
    li a0, 'R'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    mv a0, s1
    call print_hex
    call print_newline

    # 5. 指令测试 - 逻辑运算测试
    # li a0, '\n'
    li a0, '!'
    call uart_write_byte
    li a0, 'L'
    call uart_write_byte
    li a0, 'O'
    call uart_write_byte
    li a0, 'G'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, 'C'
    call uart_write_byte
    li a0, 'A'
    call uart_write_byte
    li a0, 'L'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    call print_newline

    # 5.1 AND指令测试
    li s0, PE_INST_ADDR
    li s1, 0x00000004          # AND指令测试
    sw s1, 0(s0)
    call delay                 # 等待指令执行

    li a0, 'A'
    call uart_write_byte
    li a0, 'N'
    call uart_write_byte
    li a0, 'D'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    mv a0, s1
    call print_hex
    call print_newline

    # 读取结果
    li s0, PE_DATA_ADDR
    lw s1, 0(s0)
    li a0, 'R'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    mv a0, s1
    call print_hex
    call print_newline

    # 5.2 OR指令测试
    li s0, PE_INST_ADDR
    li s1, 0x00000005          # OR指令测试
    sw s1, 0(s0)
    call delay                 # 等待指令执行

    li a0, 'O'
    call uart_write_byte
    li a0, 'R'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    mv a0, s1
    call print_hex
    call print_newline

    # 读取结果
    li s0, PE_DATA_ADDR
    lw s1, 0(s0)
    li a0, 'R'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    mv a0, s1
    call print_hex
    call print_newline

    # 5.3 XOR指令测试
    li s0, PE_INST_ADDR
    li s1, 0x00000006          # XOR指令测试
    sw s1, 0(s0)
    call delay                 # 等待指令执行

    li a0, 'X'
    call uart_write_byte
    li a0, 'O'
    call uart_write_byte
    li a0, 'R'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    mv a0, s1
    call print_hex
    call print_newline

    # 读取结果
    li s0, PE_DATA_ADDR
    lw s1, 0(s0)
    li a0, 'R'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    mv a0, s1
    call print_hex
    call print_newline

    # 6. 数据寄存器读写测试
    # li a0, '\n'
    li a0, '!'
    call uart_write_byte
    li a0, 'D'
    call uart_write_byte
    li a0, 'A'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'A'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'R'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'G'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    call print_newline

    # 6.1 写入测试数据
    li s0, PE_DATA_ADDR
    li s1, 0x12345678          # 测试数据
    sw s1, 0(s0)

    li a0, 'W'
    call uart_write_byte
    li a0, 'R'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    mv a0, s1
    call print_hex
    call print_newline

    # 6.2 读取验证
    lw s2, 0(s0)
    li a0, 'R'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'A'
    call uart_write_byte
    li a0, 'D'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    mv a0, s2
    call print_hex
    call print_newline

    # 6.3 验证结果
    beq s1, s2, data_write_read_ok

    # 读写失败
    li a0, 'F'
    call uart_write_byte
    li a0, 'A'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, 'L'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'D'
    call uart_write_byte
    call print_newline
    j data_test_end

    data_write_read_ok:
    li a0, 'O'
    call uart_write_byte
    li a0, 'K'
    call uart_write_byte
    call print_newline

    data_test_end:

    # 7. 路由配置模块测试
    # li a0, '\n'
    li a0, '!'
    call uart_write_byte
    li a0, 'R'
    call uart_write_byte
    li a0, 'O'
    call uart_write_byte
    li a0, 'U'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, 'N'
    call uart_write_byte
    li a0, 'G'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    call print_newline

    # 7.1 测试配置1: 基本路由配置
    li s0, PE_ROUTE_ADDR
    li s1, 0x00001111          # 测试配置1
    sw s1, 0(s0)
    call delay

    li a0, 'C'
    call uart_write_byte
    li a0, 'F'
    call uart_write_byte
    li a0, 'G'
    call uart_write_byte
    li a0, '1'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    mv a0, s1
    call print_hex
    call print_newline

    # 验证配置1效果
    li s0, PE_INST_ADDR
    li s1, 0x00000010          # 路由测试指令1
    sw s1, 0(s0)
    call delay

    li s0, PE_DATA_ADDR
    lw s1, 0(s0)
    li a0, 'R'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    mv a0, s1
    call print_hex
    call print_newline

    # 7.2 测试配置2: 复杂路由配置
    li s0, PE_ROUTE_ADDR
    li s1, 0x0000AAAA          # 测试配置2
    sw s1, 0(s0)
    call delay

    li a0, 'C'
    call uart_write_byte
    li a0, 'F'
    call uart_write_byte
    li a0, 'G'
    call uart_write_byte
    li a0, '2'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    mv a0, s1
    call print_hex
    call print_newline

    # 验证配置2效果
    li s0, PE_INST_ADDR
    li s1, 0x00000020          # 路由测试指令2
    sw s1, 0(s0)
    call delay

    li s0, PE_DATA_ADDR
    lw s1, 0(s0)
    li a0, 'R'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    mv a0, s1
    call print_hex
    call print_newline

    # 7.3 测试配置3: 特殊路由配置
    li s0, PE_ROUTE_ADDR
    li s1, 0x00005555          # 测试配置3
    sw s1, 0(s0)
    call delay

    li a0, 'C'
    call uart_write_byte
    li a0, 'F'
    call uart_write_byte
    li a0, 'G'
    call uart_write_byte
    li a0, '3'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    mv a0, s1
    call print_hex
    call print_newline

    # 验证配置3效果
    li s0, PE_INST_ADDR
    li s1, 0x00000030          # 路由测试指令3
    sw s1, 0(s0)
    call delay

    li s0, PE_DATA_ADDR
    lw s1, 0(s0)
    li a0, 'R'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    mv a0, s1
    call print_hex
    call print_newline

    # 8. 关闭PE模块
    li s0, PE_CTRL_ADDR
    li s1, 0                   # 清除使能位
    sw s1, 0(s0)

    li a0, 'D'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, 'A'
    call uart_write_byte
    li a0, 'B'
    call uart_write_byte
    li a0, 'L'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    li a0, '0'
    call uart_write_byte
    call print_newline

    # 9. 测试完成
    # li a0, '\n'
    li a0, '!'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'P'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'C'
    call uart_write_byte
    li a0, 'O'
    call uart_write_byte
    li a0, 'M'
    call uart_write_byte
    li a0, 'P'
    call uart_write_byte
    li a0, 'L'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'D'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    call print_newline

    lw ra, 12(sp)
    lw s0, 8(sp)
    lw s1, 4(sp)
    lw s2, 0(sp)
    addi sp, sp, 16
    ret

# 打印十六进制数
# 参数: a0 = 要打印的32位数值
print_hex:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    sw s1, 4(sp)
    sw s2, 0(sp)

    mv s0, a0
    li s1, 8                   # 8个十六进制字符
    li s2, 28                  # 从最高位开始

print_hex_loop:
    srl a0, s0, s2
    andi a0, a0, 0xF
    call hex_to_ascii
    call uart_write_byte

    addi s2, s2, -4
    addi s1, s1, -1
    bnez s1, print_hex_loop

    lw ra, 12(sp)
    lw s0, 8(sp)
    lw s1, 4(sp)
    lw s2, 0(sp)
    addi sp, sp, 16
    ret

# 十六进制转ASCII
# 参数: a0 = 0-15的十六进制值
# 返回: a0 = ASCII字符
hex_to_ascii:
    li t0, 9
    ble a0, t0, hex_digit
    addi a0, a0, 55            # 'A'-'F'
    ret
hex_digit:
    addi a0, a0, 48            # '0'-'9'
    ret

# 打印换行符
print_newline:
    addi sp, sp, -8
    sw ra, 4(sp)

    li a0, '!'
    call uart_write_byte
    li a0, '!'
    call uart_write_byte

    # li a0, '\r'
    # call uart_write_byte
    # li a0, '\n'
    # call uart_write_byte

    lw ra, 4(sp)
    addi sp, sp, 8
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

# GPIO模块测试命令处理
gpio_test_command:
    li a0, 'G'
    call uart_write_byte
    li a0, 'P'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, ':'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte

    # 执行GPIO模块测试
    call test_gpio_module

    j process_end

# GPIO模块测试函数
test_gpio_module:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    sw s1, 4(sp)
    sw s2, 0(sp)

    # 打印测试标题
    li a0, '='
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'G'
    call uart_write_byte
    li a0, 'P'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    call print_newline

    # 1. 测试GPIO输出配置
    li a0, 'C'
    call uart_write_byte
    li a0, 'O'
    call uart_write_byte
    li a0, 'N'
    call uart_write_byte
    li a0, 'F'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, 'G'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'O'
    call uart_write_byte
    li a0, 'U'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, '='
    call uart_write_byte

    # 设置GPIO输出方向 (假设测试第0位)
    li s0, GPIO_IO_DIR
    li s1, 0x00000001  # 设置第0位为输出
    sw s1, 0(s0)

    mv a0, s1
    call print_hex
    call print_newline

    # 2. 测试GPIO输出数据
    li a0, 'O'
    call uart_write_byte
    li a0, 'U'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'D'
    call uart_write_byte
    li a0, 'A'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'A'
    call uart_write_byte
    li a0, '='
    call uart_write_byte

    # 设置GPIO输出数据
    li s0, GPIO_IO_DATA
    li s1, 0x00000001  # 设置第0位为高电平
    sw s1, 0(s0)

    mv a0, s1
    call print_hex
    call print_newline

    # 3. 读取GPIO输入数据
    li a0, 'I'
    call uart_write_byte
    li a0, 'N'
    call uart_write_byte
    li a0, 'D'
    call uart_write_byte
    li a0, 'A'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'A'
    call uart_write_byte
    li a0, '='
    call uart_write_byte

    # 读取GPIO输入数据
    li s0, GPIO_IN_DATA
    lw s1, 0(s0)

    mv a0, s1
    call print_hex
    call print_newline

    # 4. 测试完成
    # li a0, '\n'
    li a0, '!' # 使用感叹号标志结束测试
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'G'
    call uart_write_byte
    li a0, 'P'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'C'
    call uart_write_byte
    li a0, 'O'
    call uart_write_byte
    li a0, 'M'
    call uart_write_byte
    li a0, 'P'
    call uart_write_byte
    li a0, 'L'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'D'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    call print_newline

    lw ra, 12(sp)
    lw s0, 8(sp)
    lw s1, 4(sp)
    lw s2, 0(sp)
    addi sp, sp, 16
    ret

# SPI模块测试命令处理
spi_test_command:
    li a0, 'S'
    call uart_write_byte
    li a0, 'P'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, ':'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte

    # 执行SPI模块测试
    call test_spi_module

    j process_end

# SPI模块测试函数
test_spi_module:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    sw s1, 4(sp)
    sw s2, 0(sp)

    # 打印测试标题
    li a0, '='
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, 'P'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    call print_newline

    # 1. 配置SPI时钟分频
    li a0, 'C'
    call uart_write_byte
    li a0, 'L'
    call uart_write_byte
    li a0, 'K'
    call uart_write_byte
    li a0, 'D'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, 'V'
    call uart_write_byte
    li a0, '='
    call uart_write_byte

    # 设置SPI时钟分频值
    li s0, SPI_CLK_DIV
    li s1, 0x00000008  # 假设分频值为8
    sw s1, 0(s0)

    mv a0, s1
    call print_hex
    call print_newline

    # 2. 配置SPI控制寄存器
    li a0, 'C'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'R'
    call uart_write_byte
    li a0, 'L'
    call uart_write_byte
    li a0, '='
    call uart_write_byte

    # 设置SPI控制寄存器 (使能SPI)
    li s0, SPI_CONTROL
    li s1, 0x00000001  # 使能SPI
    sw s1, 0(s0)

    mv a0, s1
    call print_hex
    call print_newline

    # 3. 配置SPI片选
    li a0, 'C'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, '='
    call uart_write_byte

    # 设置SPI片选
    li s0, SPI_CS_SEL
    li s1, 0x00000001  # 选择第一个片选
    sw s1, 0(s0)

    mv a0, s1
    call print_hex
    call print_newline

    # 4. 写入SPI数据测试
    li a0, 'W'
    call uart_write_byte
    li a0, 'R'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, '='
    call uart_write_byte

    # 写入测试数据
    li s0, SPI_DATA
    li s1, 0x12345678  # 测试数据
    sw s1, 0(s0)

    mv a0, s1
    call print_hex
    call print_newline

    # 5. 读取SPI状态
    li a0, 'S'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'A'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'U'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, '='
    call uart_write_byte

    # 读取SPI状态寄存器
    li s0, SPI_STATUS
    lw s1, 0(s0)

    mv a0, s1
    call print_hex
    call print_newline

    # 6. 测试完成
    # li a0, '\n'
    li a0, '!'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, 'P'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'C'
    call uart_write_byte
    li a0, 'O'
    call uart_write_byte
    li a0, 'M'
    call uart_write_byte
    li a0, 'P'
    call uart_write_byte
    li a0, 'L'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'D'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    call print_newline

    lw ra, 12(sp)
    lw s0, 8(sp)
    lw s1, 4(sp)
    lw s2, 0(sp)
    addi sp, sp, 16
    ret

# Timer模块测试命令处理
timer_test_command:
    li a0, 'T'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, 'M'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'R'
    call uart_write_byte
    li a0, ':'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte

    # 执行Timer模块测试
    call test_timer_module

    j process_end

# Timer模块测试函数
test_timer_module:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    sw s1, 4(sp)
    sw s2, 0(sp)

    # 打印测试标题
    li a0, '='
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, 'M'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'R'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    call print_newline

    # 1. 复位Timer
    li a0, 'R'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, '='
    call uart_write_byte

    # 复位Timer (清除控制寄存器)
    li s0, TIMER_CTRL
    li s1, 0x00000000  # 清除控制寄存器
    sw s1, 0(s0)

    li a0, 'D'
    call uart_write_byte
    li a0, 'O'
    call uart_write_byte
    call print_newline

    # 2. 设置Timer最大值
    li a0, 'E'
    call uart_write_byte
    li a0, 'X'
    call uart_write_byte
    li a0, 'P'
    call uart_write_byte
    li a0, 'R'
    call uart_write_byte
    li a0, '='
    call uart_write_byte

    # 设置Timer最大值
    li s0, TIMER_EXPR
    li s1, 0x0000FFFF  # 设置最大值
    sw s1, 0(s0)

    mv a0, s1
    call print_hex
    call print_newline

    # 3. 启动Timer
    li a0, 'S'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'A'
    call uart_write_byte
    li a0, 'R'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, '='
    call uart_write_byte

    # 启动Timer (设置控制寄存器)
    li s0, TIMER_CTRL
    li s1, 0x00000003  # 启动Timer + 周期模式
    sw s1, 0(s0)

    mv a0, s1
    call print_hex
    call print_newline

    # 4. 读取Timer计数器
    call delay
    call delay

    li a0, 'C'
    call uart_write_byte
    li a0, 'O'
    call uart_write_byte
    li a0, 'U'
    call uart_write_byte
    li a0, 'N'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, '='
    call uart_write_byte

    # 读取Timer计数器
    li s0, TIMER_COUNTER
    lw s1, 0(s0)

    mv a0, s1
    call print_hex
    call print_newline

    # 5. 再次读取Timer计数器 (验证计数增加)
    call delay
    call delay

    li a0, 'N'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'W'
    call uart_write_byte
    li a0, 'C'
    call uart_write_byte
    li a0, 'O'
    call uart_write_byte
    li a0, 'U'
    call uart_write_byte
    li a0, 'N'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, '='
    call uart_write_byte

    # 读取Timer计数器
    lw s2, 0(s0)

    mv a0, s2
    call print_hex
    call print_newline

    # 6. 验证计数是否增加
    bgt s2, s1, timer_count_ok

    # 计数失败
    li a0, 'F'
    call uart_write_byte
    li a0, 'A'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, 'L'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'D'
    call uart_write_byte
    call print_newline
    j timer_test_end

    timer_count_ok:
    li a0, 'O'
    call uart_write_byte
    li a0, 'K'
    call uart_write_byte
    call print_newline

    timer_test_end:

    # 7. 停止Timer
    li a0, 'S'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'O'
    call uart_write_byte
    li a0, 'P'
    call uart_write_byte
    li a0, '='
    call uart_write_byte

    # 停止Timer
    li s0, TIMER_CTRL
    li s1, 0x00000000  # 停止Timer
    sw s1, 0(s0)

    li a0, 'D'
    call uart_write_byte
    li a0, 'O'
    call uart_write_byte
    call print_newline

    # 8. 测试完成
    # li a0, '\n'
    li a0, '!'
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, 'M'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'R'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'C'
    call uart_write_byte
    li a0, 'O'
    call uart_write_byte
    li a0, 'M'
    call uart_write_byte
    li a0, 'P'
    call uart_write_byte
    li a0, 'L'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'D'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, '='
    call uart_write_byte
    call print_newline

    lw ra, 12(sp)
    lw s0, 8(sp)
    lw s1, 4(sp)
    lw s2, 0(sp)
    addi sp, sp, 16
    ret

.section .data
# 数据段可以在这里定义
message:
    .string "RISC-V UART Test Program\n"

.section .bss
# 未初始化数据段
