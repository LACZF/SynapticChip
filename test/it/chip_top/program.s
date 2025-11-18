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
.equ UART_BDV_VALUE_L,   0x2           # 仿真场景下速率较慢，设置为2分频
.equ UART_BDV_VALUE_H,   0x0
.equ UART_SIMPLE_CYCLES, 0x4           # 仿真场景下速率较慢，配置采样率为4倍

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

# 中断控制器地址定义
.equ IRQ_CTRL_BASE,      IO_BASE    + 0x00060000
.equ IRQ_CTRL_ENABLE,    IRQ_CTRL_BASE + 0x00  # 中断使能寄存器
.equ IRQ_CTRL_PENDING,   IRQ_CTRL_BASE + 0x04  # 中断挂起寄存器
.equ IRQ_CTRL_PRIORITY0, IRQ_CTRL_BASE + 0x08 # 优先级寄存器0
.equ IRQ_CTRL_PRIORITY1, IRQ_CTRL_BASE + 0x0C # 优先级寄存器1

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

# PE模块地址定义 - 重构后使用PE_control模块的地址映射
.equ PE_TOP_BASE,           0x30000000
.equ PE_CTRL_ADDR,          PE_TOP_BASE + 0x100000   # 控制寄存器
.equ PE_STATUS_ADDR,        PE_TOP_BASE + 0x100004   # 状态寄存器
.equ PE_ENABLE_ADDR,        PE_TOP_BASE + 0x100008   # PE使能寄存器
.equ PE_HIGH_BW_WRITE_ADDR, PE_TOP_BASE + 0x10000C   # 高带宽写入地址
.equ PE_HIGH_BW_READ_ADDR,  PE_TOP_BASE + 0x100010   # 高带宽读取地址

# PE阵列尺寸定义
.equ PE_ARRAY_X,            10                         # PE阵列X方向尺寸
.equ PE_ARRAY_Y,            10                         # PE阵列Y方向尺寸
.equ PE_TOTAL_COUNT,        PE_ARRAY_X * PE_ARRAY_Y    # PE总数

# PE内存映射 - 操作数和配置存储在PE_mem中
.equ PE_MEM_BASE,           PE_TOP_BASE + 0x000000                    # PE内存基地址
.equ PE_OPERAND1_BASE,      PE_MEM_BASE + 0x0000                      # 操作数1区域 (每个PE 4字节)
.equ PE_OPERAND2_BASE,      PE_OPERAND1_BASE + (PE_TOTAL_COUNT * 4)   # 操作数2区域 (每个PE 4字节)
.equ PE_CONFIG_BASE,        PE_OPERAND2_BASE + (PE_TOTAL_COUNT * 4)   # 配置区域 (每个PE 4字节)
.equ PE_OUTPUT_BASE,        PE_CONFIG_BASE + (PE_TOTAL_COUNT * 4)     # 输出区域 (每个PE 4字节)

# PE控制寄存器位定义 - 默认使能，无需复位和使能控制

# PE配置位定义 - 重构后配置格式
.equ PE_OPCODE_SHIFT, 0        # 操作码在配置字中的位置
.equ PE_SRC1_SEL_SHIFT, 8      # 输入源1选择位
.equ PE_SRC2_SEL_SHIFT, 11     # 输入源2选择位
.equ PE_ROUTE_NORTH_SHIFT, 16  # 北向路由输出
.equ PE_ROUTE_SOUTH_SHIFT, 17  # 南向路由输出
.equ PE_ROUTE_EAST_SHIFT, 18   # 东向路由输出
.equ PE_ROUTE_WEST_SHIFT, 19   # 西向路由输出
.equ PE_STORE_MEM_SHIFT, 20    # 存储到内存

# PE操作码定义 - 与pe.v保持一致
.equ PE_OP_PASS,  0x00         # PASS (直接传递src1)
.equ PE_OP_ADD,   0x01         # 加法
.equ PE_OP_SUB,   0x02         # 减法
.equ PE_OP_AND,   0x03         # 与运算
.equ PE_OP_OR,    0x04         # 或运算
.equ PE_OP_XOR,   0x05         # 异或运算
.equ PE_OP_MUL,   0x06         # 乘法
.equ PE_OP_MIN,   0x07         # 最小值
.equ PE_OP_MAX,   0x08         # 最大值
.equ PE_OP_SHL,   0x09         # 逻辑左移
.equ PE_OP_SHR,   0x0A         # 逻辑右移
.equ PE_OP_ASHR,  0x0B         # 算术右移
.equ PE_OP_EQ,    0x0C         # 等于比较
.equ PE_OP_LT,    0x0D         # 小于比较

# PE输入源选择定义 - 与pe.v保持一致（3位编码）
.equ PE_SRC_EAST,      0x1     # 东方向输入  (3'b001)
.equ PE_SRC_SOUTH,     0x2     # 南方向输入  (3'b010)
.equ PE_SRC_WEST,      0x3     # 西方向输入  (3'b011)
.equ PE_SRC_NORTH,     0x4     # 北方向输入  (3'b100)
.equ PE_SRC_OPERAND1,  0x5     # 外部操作数1 (3'b101)
.equ PE_SRC_OPERAND2,  0x6     # 外部操作数2 (3'b110)

# 栈指针初始地址
.equ STACK_TOP,      RAM_BASE + 0x1000

# 中断向量表
# RISC-V中断向量表索引规则：
# - 索引0-15：异常处理（mcause[31]=0）
# - 索引16-31：中断处理（mcause[31]=1）
# 注意：实际硬件中断号需要加上0x80000000
.section .text.vector
.align 4
.global vector_table

_start:
    # 初始化栈指针
    li sp, STACK_TOP

    # 初始化中断控制器
    call irq_init

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

    li a0, UART_SMPR
    li a1, UART_SIMPLE_CYCLES
    sb a1, 0(a0)

    li a0, UART_BDV_L
    li a1, UART_BDV_VALUE_L
    sb a1, 0(a0)

    li a0, UART_BDV_H
    li a1, UART_BDV_VALUE_H
    sb a1, 0(a0)

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
    li a0, '!'
    call uart_write_byte
    li a0, 0x04
    call uart_write_byte
    call print_newline

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
    call print_newline

    # 执行PE模块测试
    call test_pe_module

    j process_end

# PE模块测试函数
test_pe_module:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    sw s2, 16(sp)
    sw s3, 12(sp)
    sw s4, 8(sp)
    sw s5, 4(sp)
    sw s6, 0(sp)

    # 打印测试标题
    # li a0, '-'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, 'P'
    # call uart_write_byte
    # li a0, 'E'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, 'T'
    # call uart_write_byte
    # li a0, 'E'
    # call uart_write_byte
    # li a0, 'S'
    # call uart_write_byte
    # li a0, 'T'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, '-'
    # call uart_write_byte
    # call print_newline

    # # PE模块默认使能，无需复位和使能操作
    # li a0, 'P'
    # call uart_write_byte
    # li a0, 'E'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, 'R'
    # call uart_write_byte
    # li a0, 'E'
    # call uart_write_byte
    # li a0, 'A'
    # call uart_write_byte
    # li a0, 'D'
    # call uart_write_byte
    # li a0, 'Y'
    # call uart_write_byte
    # call print_newline
#
    # # 3. 从数据段加载PE测试数据到PE内存
    # li a0, 'L'
    # call uart_write_byte
    # li a0, 'O'
    # call uart_write_byte
    # li a0, 'A'
    # call uart_write_byte
    # li a0, 'D'
    # call uart_write_byte
    # li a0, 'I'
    # call uart_write_byte
    # li a0, 'N'
    # call uart_write_byte
    # li a0, 'G'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, 'P'
    # call uart_write_byte
    # li a0, 'E'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, 'D'
    # call uart_write_byte
    # li a0, 'A'
    # call uart_write_byte
    # li a0, 'T'
    # call uart_write_byte
    # li a0, 'A'
    # call uart_write_byte
    # call print_newline

    # 3.1 加载源操作数1数据
    la s0, pe_operand1_data    # 源操作数1数据地址
    li s1, PE_OPERAND1_BASE    # PE操作数1基地址
    li s2, 16                  # 16个PE
load_operand1_loop:
    lw s3, 0(s0)               # 从数据段读取操作数1
    sw s3, 0(s1)               # 写入PE操作数1内存
    addi s0, s0, 4             # 下一个数据段地址
    addi s1, s1, 4             # 下一个PE内存地址
    addi s2, s2, -1            # 计数器减1
    bnez s2, load_operand1_loop

    # 3.2 加载源操作数2数据
    la s0, pe_operand2_data    # 源操作数2数据地址
    li s1, PE_OPERAND2_BASE    # PE操作数2基地址
    li s2, 16                  # 16个PE
load_operand2_loop:
    lw s3, 0(s0)               # 从数据段读取操作数2
    sw s3, 0(s1)               # 写入PE操作数2内存
    addi s0, s0, 4             # 下一个数据段地址
    addi s1, s1, 4             # 下一个PE内存地址
    addi s2, s2, -1            # 计数器减1
    bnez s2, load_operand2_loop

    # 3.3 加载配置与路由数据
    la s0, pe_config_data      # 配置数据地址
    li s1, PE_CONFIG_BASE      # PE配置基地址
    li s2, 16                  # 16个PE
load_config_loop:
    lw s3, 0(s0)               # 从数据段读取配置
    sw s3, 0(s1)               # 写入PE配置内存
    addi s0, s0, 4             # 下一个数据段地址
    addi s1, s1, 4             # 下一个PE内存地址
    addi s2, s2, -1            # 计数器减1
    bnez s2, load_config_loop

    # li a0, 'D'
    # call uart_write_byte
    # li a0, 'A'
    # call uart_write_byte
    # li a0, 'T'
    # call uart_write_byte
    # li a0, 'A'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, 'L'
    # call uart_write_byte
    # li a0, 'O'
    # call uart_write_byte
    # li a0, 'A'
    # call uart_write_byte
    # li a0, 'D'
    # call uart_write_byte
    # li a0, 'E'
    # call uart_write_byte
    # li a0, 'D'
    # call uart_write_byte
    # call print_newline
#
    # # 4. 启动PE计算
    # li a0, 'S'
    # call uart_write_byte
    # li a0, 'T'
    # call uart_write_byte
    # li a0, 'A'
    # call uart_write_byte
    # li a0, 'R'
    # call uart_write_byte
    # li a0, 'T'
    # call uart_write_byte
    # li a0, 'I'
    # call uart_write_byte
    # li a0, 'N'
    # call uart_write_byte
    # li a0, 'G'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, 'P'
    # call uart_write_byte
    # li a0, 'E'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, 'C'
    # call uart_write_byte
    # li a0, 'O'
    # call uart_write_byte
    # li a0, 'M'
    # call uart_write_byte
    # li a0, 'P'
    # call uart_write_byte
    # li a0, 'U'
    # call uart_write_byte
    # li a0, 'T'
    # call uart_write_byte
    # li a0, 'E'
    # call uart_write_byte
    # call print_newline

    li s0, PE_CTRL_ADDR
    li s1, 1 << 0  # 启动PE计算（PE默认使能）
    sw s1, 0(s0)
    call delay                 # 等待计算完成
    # call delay
    # call delay

    # 5. 从结果内存读取结果并进行判断
    # li a0, 'C'
    # call uart_write_byte
    # li a0, 'H'
    # call uart_write_byte
    # li a0, 'E'
    # call uart_write_byte
    # li a0, 'C'
    # call uart_write_byte
    # li a0, 'K'
    # call uart_write_byte
    # li a0, 'I'
    # call uart_write_byte
    # li a0, 'N'
    # call uart_write_byte
    # li a0, 'G'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, 'R'
    # call uart_write_byte
    # li a0, 'E'
    # call uart_write_byte
    # li a0, 'S'
    # call uart_write_byte
    # li a0, 'U'
    # call uart_write_byte
    # li a0, 'L'
    # call uart_write_byte
    # li a0, 'T'
    # call uart_write_byte
    # li a0, 'S'
    # call uart_write_byte
    # call print_newline

    # 初始化测试结果标志为成功
    li s6, 1                   # s6 = 测试结果 (1=成功, 0=失败)

    # 检查前4个PE的结果
    li s0, PE_OUTPUT_BASE      # PE0结果地址
    la s1, pe_expected_results # 期望结果地址
    li s2, 4                   # 检查前4个PE

check_results_loop:
    lw s3, 0(s0)               # 读取PE实际结果
    lw s4, 0(s1)               # 读取期望结果

    # 打印PE编号和结果
    li a0, 'P'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    mv a0, s2
    li a1, 4
    sub a0, a1, a0             # 计算PE编号
    addi a0, a0, 1
    call print_dec
    li a0, ':'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    mv a0, s3
    call print_hex
    li a0, ' '
    call uart_write_byte
    li a0, '('
    call uart_write_byte
    mv a0, s4
    call print_hex
    li a0, ')'
    call uart_write_byte

    # 比较结果
    bne s3, s4, result_mismatch

    li a0, ' '
    call uart_write_byte
    li a0, 'O'
    call uart_write_byte
    li a0, 'K'
    call uart_write_byte
    j result_ok

result_mismatch:
    li a0, ' '
    call uart_write_byte
    li a0, 'F'
    call uart_write_byte
    li a0, 'A'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, 'L'
    call uart_write_byte
    li s6, 0                   # 标记测试失败

result_ok:
    call print_newline

    addi s0, s0, 4             # 下一个PE结果地址
    addi s1, s1, 4             # 下一个期望结果地址
    addi s2, s2, -1            # 计数器减1
    bnez s2, check_results_loop

    # 6. 输出最终测试结果
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
    li a0, 'R'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, 'U'
    call uart_write_byte
    li a0, 'L'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, ':'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte

    beqz s6, test_failed

    li a0, 'P'
    call uart_write_byte
    li a0, 'A'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'D'
    call uart_write_byte
    j test_end

test_failed:
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

test_end:
    call print_newline

    # 恢复寄存器并返回
    lw s6, 0(sp)
    lw s5, 4(sp)
    lw s4, 8(sp)
    lw s3, 12(sp)
    lw s2, 16(sp)
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
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

# 打印十进制数
# 参数: a0 = 要打印的32位整数
print_dec:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    sw s2, 16(sp)
    sw s3, 12(sp)
    sw s4, 8(sp)
    sw s5, 4(sp)
    sw s6, 0(sp)

    mv s0, a0                  # 保存原始值
    li s1, 0                   # 数字计数器
    li s2, 10                  # 除数
    li s3, 0                   # 是否为负数标志

    # 检查是否为负数
    bgez s0, positive_number
    li s3, 1                   # 标记为负数
    neg s0, s0                 # 取绝对值

positive_number:
    # 特殊情况：如果数字为0，直接打印'0'
    bnez s0, convert_loop
    li a0, '0'
    call uart_write_byte
    j print_dec_end

convert_loop:
    # 除以10，获取余数
    remu s4, s0, s2            # 余数
    divu s0, s0, s2            # 商

    # 将余数转换为ASCII并压栈
    addi s4, s4, 48            # 转换为ASCII
    addi sp, sp, -1
    sb s4, 0(sp)
    addi s1, s1, 1             # 计数器加1

    # 如果商不为0，继续循环
    bnez s0, convert_loop

    # 如果是负数，打印负号
    beqz s3, print_digits
    li a0, '-'
    call uart_write_byte

print_digits:
    # 从栈中弹出并打印数字
    li s5, 0
print_digits_loop:
    lb a0, 0(sp)
    call uart_write_byte
    addi sp, sp, 1
    addi s5, s5, 1
    blt s5, s1, print_digits_loop

print_dec_end:
    lw ra, 28(sp)
    lw s0, 24(sp)
    lw s1, 20(sp)
    lw s2, 16(sp)
    lw s3, 12(sp)
    lw s4, 8(sp)
    lw s5, 4(sp)
    lw s6, 0(sp)
    addi sp, sp, 32
    ret

# 打印换行符
print_newline:
    addi sp, sp, -8
    sw ra, 4(sp)

    li a0, '\r'
    call uart_write_byte
    li a0, '\n'
    call uart_write_byte

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
    li a0, 'O'
    call uart_write_byte
    li a0, ':'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    call print_newline

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
    # li a0, '-'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, 'G'
    # call uart_write_byte
    # li a0, 'P'
    # call uart_write_byte
    # li a0, 'I'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, 'T'
    # call uart_write_byte
    # li a0, 'E'
    # call uart_write_byte
    # li a0, 'S'
    # call uart_write_byte
    # li a0, 'T'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, '-'
    # call uart_write_byte
    # call print_newline

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

    li s0, GPIO_OUT_DATA
    li s1, 0x00000010  # 设置第4位为高电平
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
    # call uart_write_byte
    # li a0, '-'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, 'G'
    # call uart_write_byte
    # li a0, 'P'
    # call uart_write_byte
    # li a0, 'I'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, 'T'
    # call uart_write_byte
    # li a0, 'E'
    # call uart_write_byte
    # li a0, 'S'
    # call uart_write_byte
    # li a0, 'T'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, 'C'
    # call uart_write_byte
    # li a0, 'O'
    # call uart_write_byte
    # li a0, 'M'
    # call uart_write_byte
    # li a0, 'P'
    # call uart_write_byte
    # li a0, 'L'
    # call uart_write_byte
    # li a0, 'E'
    # call uart_write_byte
    # li a0, 'T'
    # call uart_write_byte
    # li a0, 'E'
    # call uart_write_byte
    # li a0, 'D'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, '-'
    # call uart_write_byte
    # call print_newline

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
    call print_newline

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
    # li a0, '-'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, 'S'
    # call uart_write_byte
    # li a0, 'P'
    # call uart_write_byte
    # li a0, 'I'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, 'T'
    # call uart_write_byte
    # li a0, 'E'
    # call uart_write_byte
    # li a0, 'S'
    # call uart_write_byte
    # li a0, 'T'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, '-'
    # call uart_write_byte
    # call print_newline

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
    li s1, 0x00000000  # 选择第一个片选
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

    # 5. 写入SPI命令寄存器以启动SPI操作
    li a0, 'C'
    call uart_write_byte
    li a0, 'M'
    call uart_write_byte
    li a0, 'D'
    call uart_write_byte
    li a0, '='
    call uart_write_byte

    # 写入SPI命令寄存器
    li s0, SPI_CMD
    li s1, 0x00000001  # 写入任意值以触发SPI操作
    mv a0, s1
    call print_hex
    call print_newline
    call print_newline
    sw s1, 0(s0)

    # 6. 读取SPI状态
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

    # 7. 读取SPI接收的数据并通过UART发送
    li a0, 'R'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'C'
    call uart_write_byte
    li a0, 'V'
    call uart_write_byte
    li a0, '='
    call uart_write_byte

    # 读取SPI数据寄存器（接收数据）
    li s0, SPI_DATA
    lw s1, 0(s0)

    mv a0, s1
    call print_hex
    call print_newline

    # 测试第二个SPI从机
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, 'P'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, 'L'
    call uart_write_byte
    li a0, 'A'
    call uart_write_byte
    li a0, 'V'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, '2'
    call uart_write_byte
    li a0, ':'
    call uart_write_byte
    call print_newline

    # 1. 选择第二个SPI片选
    li a0, 'C'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, '='
    call uart_write_byte

    # 设置第二个片选
    li s0, SPI_CS_SEL
    li s1, 0x00000001  # 选择第二个片选
    sw s1, 0(s0)

    mv a0, s1
    call print_hex
    call print_newline

    # 2. 写入不同的SPI测试数据
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

    # 写入第二个从机的测试数据
    li s0, SPI_DATA
    li s1, 0x87654321  # 不同的测试数据，用于区分第二个从机
    sw s1, 0(s0)

    mv a0, s1
    call print_hex
    call print_newline

    # 3. 写入SPI命令寄存器以启动SPI操作
    li a0, 'C'
    call uart_write_byte
    li a0, 'M'
    call uart_write_byte
    li a0, 'D'
    call uart_write_byte
    li a0, '='
    call uart_write_byte

    # 写入SPI命令寄存器
    li s0, SPI_CMD
    li s1, 0x00000001  # 写入任意值以触发SPI操作
    mv a0, s1
    call print_hex
    call print_newline
    call print_newline
    sw s1, 0(s0)

    # 4. 读取SPI状态
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

    # 5. 读取SPI接收的数据并通过UART发送（第二个从机）
    li a0, 'R'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, 'C'
    call uart_write_byte
    li a0, 'V'
    call uart_write_byte
    li a0, '='
    call uart_write_byte

    # 读取SPI数据寄存器（接收数据）
    li s0, SPI_DATA
    lw s1, 0(s0)

    mv a0, s1
    call print_hex
    call print_newline

    # 5. 第二个从机测试完成
    li a0, '\n'
    call uart_write_byte
    li a0, '-'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, 'P'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, 'S'
    call uart_write_byte
    li a0, 'L'
    call uart_write_byte
    li a0, 'A'
    call uart_write_byte
    li a0, 'V'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, '2'
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
    li a0, '-'
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
    call print_newline

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
    # li a0, '-'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, 'T'
    # call uart_write_byte
    # li a0, 'I'
    # call uart_write_byte
    # li a0, 'M'
    # call uart_write_byte
    # li a0, 'E'
    # call uart_write_byte
    # li a0, 'R'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, 'T'
    # call uart_write_byte
    # li a0, 'E'
    # call uart_write_byte
    # li a0, 'S'
    # call uart_write_byte
    # li a0, 'T'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, '-'
    # call uart_write_byte
    # call print_newline

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
    li s1, 0x00001000  # 设置最大值
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
    li s1, 0x00000003  # 启动Timer + 周期模式 + 中断使能
    sw s1, 0(s0)

    mv a0, s1
    call print_hex
    call print_newline

    # 4. 等待Timer中断发生
    li a0, 'W'
    call uart_write_byte
    li a0, 'A'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, 'N'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, '='
    call uart_write_byte

    # 初始化中断计数器
    la s0, timer_interrupt_count
    li s1, 0
    sw s1, 0(s0)

    # 等待中断发生（最多等待一定时间）
    li s2, 1000  # 最大等待循环次数
wait_for_interrupt:
    # 检查中断计数器是否增加
    lw s1, 0(s0)
    bnez s1, interrupt_occurred

    # 延迟一段时间
    call delay

    # 减少等待计数器
    addi s2, s2, -1
    bnez s2, wait_for_interrupt

    # 超时，中断未发生
    j interrupt_timeout

interrupt_occurred:
    li a0, 'O'
    call uart_write_byte
    li a0, 'K'
    call uart_write_byte
    call print_newline
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

    # 打印中断发生次数
    lw a0, 0(s0)
    call print_hex
    call print_newline
    j timer_test_end

interrupt_timeout:
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
    li a0, '\n'
    call uart_write_byte
    li a0, '-'
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
    li a0, '-'
    call uart_write_byte
    call print_newline

    lw ra, 12(sp)
    lw s0, 8(sp)
    lw s1, 4(sp)
    lw s2, 0(sp)
    addi sp, sp, 16
    ret

/* 异常和中断总入口 */
trap_entry:
    addi sp, sp, -32*17
    sw x1,   0*4(sp)
    sw x5,   1*4(sp)
    sw x6,   2*4(sp)
    sw x7,   3*4(sp)
    sw x10,  4*4(sp)
    sw x11,  5*4(sp)
    sw x12,  6*4(sp)
    sw x13,  7*4(sp)
    sw x14,  8*4(sp)
    sw x15,  9*4(sp)
    sw x16, 10*4(sp)
    sw x17, 11*4(sp)
    sw x28, 12*4(sp)
    sw x29, 13*4(sp)
    sw x30, 14*4(sp)
    sw x31, 15*4(sp)

    /* 保存异常(中断)返回地址 */
    csrr x10, mepc
    sw x10, 16*4(sp)

    /* 使能全局中断 */
    csrsi mstatus, 0x8

    /* 读取异常(中断)号 */
    csrr a1, mcause

    /* 直接判断timer中断（中断号18） */
    li a0, 18
    beq a1, a0, timer_interrupt

    /* 判断UART RX中断（中断号21） */
    li a0, 21
    beq a1, a0, uart_interrupt

    /* 判断UART TX中断（中断号22） */
    li a0, 22
    beq a1, a0, uart_interrupt

    /* 判断SPI中断（中断号23） */
    li a0, 23
    beq a1, a0, spi_interrupt

    /* 判断GPIO中断（中断号24） */
    li a0, 24
    beq a1, a0, gpio_interrupt

    /* 判断PE中断（中断号25） */
    li a0, 25
    beq a1, a0, pe_interrupt

    /* 如果不是上述中断，跳转到默认异常处理 */
    j exception_handler

timer_interrupt:
    /* 调用timer中断处理函数 */
    call timer_interrupt_handler
    j trap_return

uart_interrupt:
    /* 调用uart中断处理函数 */
    call uart_interrupt_handler
    j trap_return

spi_interrupt:
    /* 调用spi中断处理函数 */
    call spi_interrupt_handler
    j trap_return

gpio_interrupt:
    /* 调用gpio中断处理函数 */
    call gpio_interrupt_handler
    j trap_return

pe_interrupt:
    /* 调用pe中断处理函数 */
    call pe_interrupt_handler
    j trap_return

trap_return:
    /* 恢复异常(中断)返回地址 */
    lw x10,  16*4(sp)
    csrw mepc, x10
    lw x1,   0*4(sp)
    lw x5,   1*4(sp)
    lw x6,   2*4(sp)
    lw x7,   3*4(sp)
    lw x10,  4*4(sp)
    lw x11,  5*4(sp)
    lw x12,  6*4(sp)
    lw x13,  7*4(sp)
    lw x14,  8*4(sp)
    lw x15,  9*4(sp)
    lw x16, 10*4(sp)
    lw x17, 11*4(sp)
    lw x28, 12*4(sp)
    lw x29, 13*4(sp)
    lw x30, 14*4(sp)
    lw x31, 15*4(sp)
    addi sp, sp, 32*17
    mret

# 中断控制器初始化
irq_init:
    addi sp, sp, -8
    sw ra, 4(sp)

    # 配置mtvec寄存器，指向中断向量表（向量模式）
    la a0, trap_entry
    csrw mtvec, a0

    # 启用全局中断（设置mstatus.MIE位）
    csrsi mstatus, 0x8

    # 清除所有中断挂起状态
    li a0, IRQ_CTRL_PENDING
    li a1, 0xFFFFFFFF
    sw a1, 0(a0)

    # 设置中断使能寄存器（使能定时器中断）
    li a0, IRQ_CTRL_ENABLE
    li a1, 0xFFFFFFFF
    sw a1, 0(a0)

    # li a0, 'I'
    # call uart_write_byte
    # li a0, 'R'
    # call uart_write_byte
    # li a0, 'Q'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, 'I'
    # call uart_write_byte
    # li a0, 'n'
    # call uart_write_byte
    # li a0, 'i'
    # call uart_write_byte
    # li a0, 't'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, 'O'
    # call uart_write_byte
    # li a0, 'K'
    # call uart_write_byte
    # li a0, '!'
    # call uart_write_byte
    # call print_newline

    lw ra, 4(sp)
    addi sp, sp, 8
    ret



# 定时器中断处理函数
timer_interrupt_handler:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw a0, 8(sp)
    sw a1, 4(sp)
    sw a2, 0(sp)

    # 打印定时器中断信息
    # li a0, 'T'
    # call uart_write_byte
    # li a0, 'i'
    # call uart_write_byte
    # li a0, 'm'
    # call uart_write_byte
    # li a0, 'e'
    # call uart_write_byte
    # li a0, 'r'
    # call uart_write_byte
    # li a0, ' '
    # call uart_write_byte
    # li a0, 'I'
    # call uart_write_byte
    # li a0, 'n'
    # call uart_write_byte
    # li a0, 't'
    # call uart_write_byte
    # li a0, '!'
    # call uart_write_byte
    # call print_newline

    # 增加中断计数器
    la a0, timer_interrupt_count
    lw a1, 0(a0)
    addi a1, a1, 1
    sw a1, 0(a0)

    # 清除Timer中断（写入Timer中断寄存器）
    li a0, TIMER_INTR
    li a1, 0x00000000  # 清除中断
    sw a1, 0(a0)

    # 应答中断控制器（通过写入挂起寄存器清除中断）
    li a0, IRQ_CTRL_PENDING
    li a1, 0x00000400  # 写入1到位10（Timer中断）以清除挂起位
    sw a1, 0(a0)

    lw ra, 12(sp)
    lw a0, 8(sp)
    lw a1, 4(sp)
    lw a2, 0(sp)
    addi sp, sp, 16
    ret

# UART中断处理函数
uart_interrupt_handler:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw a0, 8(sp)
    sw a1, 4(sp)
    sw a2, 0(sp)

    # 打印UART中断信息
    li a0, 'U'
    call uart_write_byte
    li a0, 'A'
    call uart_write_byte
    li a0, 'R'
    call uart_write_byte
    li a0, 'T'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, 'n'
    call uart_write_byte
    li a0, 't'
    call uart_write_byte
    li a0, '!'
    call uart_write_byte
    call print_newline

    # 应答中断控制器（通过写入挂起寄存器清除中断）
    li a0, IRQ_CTRL_PENDING
    li a1, 0x00002000  # 写入1到位13（UART中断）以清除挂起位
    sw a1, 0(a0)

    lw ra, 12(sp)
    lw a0, 8(sp)
    lw a1, 4(sp)
    lw a2, 0(sp)
    addi sp, sp, 16
    ret

# GPIO中断处理函数
gpio_interrupt_handler:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw a0, 8(sp)
    sw a1, 4(sp)
    sw a2, 0(sp)

    # 打印GPIO中断信息
    li a0, 'G'
    call uart_write_byte
    li a0, 'P'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, 'O'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, 'n'
    call uart_write_byte
    li a0, 't'
    call uart_write_byte
    li a0, '!'
    call uart_write_byte
    call print_newline

    # 应答中断控制器（通过写入挂起寄存器清除中断）
    li a0, IRQ_CTRL_PENDING
    li a1, 0x00010000  # 写入1到位16（GPIO中断）以清除挂起位
    sw a1, 0(a0)

    lw ra, 12(sp)
    lw a0, 8(sp)
    lw a1, 4(sp)
    lw a2, 0(sp)
    addi sp, sp, 16
    ret

# SPI中断处理函数
spi_interrupt_handler:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw a0, 8(sp)
    sw a1, 4(sp)
    sw a2, 0(sp)

    # 打印SPI中断信息
    li a0, 'S'
    call uart_write_byte
    li a0, 'P'
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, 'n'
    call uart_write_byte
    li a0, 't'
    call uart_write_byte
    li a0, '!'
    call uart_write_byte
    call print_newline

    # 应答中断控制器（通过写入挂起寄存器清除中断）
    li a0, IRQ_CTRL_PENDING
    li a1, 0x00008000  # 写入1到位15（SPI中断）以清除挂起位
    sw a1, 0(a0)

    lw ra, 12(sp)
    lw a0, 8(sp)
    lw a1, 4(sp)
    lw a2, 0(sp)
    addi sp, sp, 16
    ret

# PE中断处理函数
pe_interrupt_handler:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw a0, 8(sp)
    sw a1, 4(sp)
    sw a2, 0(sp)

    # 打印PE中断信息
    li a0, 'P'
    call uart_write_byte
    li a0, 'E'
    call uart_write_byte
    li a0, ' '
    call uart_write_byte
    li a0, 'I'
    call uart_write_byte
    li a0, 'n'
    call uart_write_byte
    li a0, 't'
    call uart_write_byte
    li a0, '!'
    call uart_write_byte
    call print_newline

    # 应答中断控制器（通过写入挂起寄存器清除中断）
    li a0, IRQ_CTRL_PENDING
    li a1, 0x00020000  # 写入1到位17（PE中断）以清除挂起位
    sw a1, 0(a0)

    lw ra, 12(sp)
    lw a0, 8(sp)
    lw a1, 4(sp)
    lw a2, 0(sp)
    addi sp, sp, 16
    ret

# 异常处理程序
exception_handler:
    addi sp, sp, -8
    sw ra, 4(sp)

    li a0, 'E'
    call uart_write_byte
    li a0, 'x'
    call uart_write_byte
    li a0, 'c'
    call uart_write_byte
    li a0, 'e'
    call uart_write_byte
    li a0, 'p'
    call uart_write_byte
    li a0, 't'
    call uart_write_byte
    li a0, 'i'
    call uart_write_byte
    li a0, 'o'
    call uart_write_byte
    li a0, 'n'
    call uart_write_byte
    li a0, '!'
    call uart_write_byte
    call print_newline

    # 无限循环，等待复位
    j exception_handler

    lw ra, 4(sp)
    addi sp, sp, 8
    ret

vector_table:
    # RISC-V标准异常向量表（索引0-15为异常，16-31为中断）
    .word exception_handler         # 0: 指令地址不对齐
    .word exception_handler         # 1: 非法指令
    .word exception_handler         # 2: 断点
    .word exception_handler         # 3: 加载地址不对齐
    .word exception_handler         # 4: 存储地址不对齐
    .word exception_handler         # 5: 环境调用
    .word exception_handler         # 6: 保留
    .word exception_handler         # 7: 保留
    .word exception_handler         # 8: 保留
    .word exception_handler         # 9: 保留
    .word exception_handler         # 10: 保留
    .word exception_handler         # 11: 保留
    .word exception_handler         # 12: 保留
    .word exception_handler         # 13: 保留
    .word exception_handler         # 14: 保留
    .word exception_handler         # 15: 保留
    .word exception_handler         # 16: 机器模式软件中断
    .word exception_handler         # 17: 保留
    .word timer_interrupt_handler   # 18: 机器模式定时器中断
    .word exception_handler         # 19: 保留
    .word exception_handler         # 20: 机器模式外部中断
    .word uart_interrupt_handler    # 21: UART RX
    .word uart_interrupt_handler    # 22: UART TX
    .word spi_interrupt_handler     # 23: SPI中断
    .word gpio_interrupt_handler    # 24: GPIO中断
    .word pe_interrupt_handler      # 25: PE中断
    .word exception_handler         # 26: 保留
    .word exception_handler         # 27: 保留
    .word exception_handler         # 28: 保留
    .word exception_handler         # 29: 保留
    .word exception_handler         # 30: 保留
    .word exception_handler         # 31: 保留

.section .data

# PE测试数据 - 源操作数1 (4x4 PE阵列，每个PE一个32位操作数)
pe_operand1_data:
    .word 0x0000000A, 0x0000000B, 0x0000000C, 0x0000000D  # PE0-PE3
    .word 0x0000000E, 0x0000000F, 0x00000010, 0x00000011  # PE4-PE7
    .word 0x00000012, 0x00000013, 0x00000014, 0x00000015  # PE8-PE11
    .word 0x00000016, 0x00000017, 0x00000018, 0x00000019  # PE12-PE15

# PE测试数据 - 源操作数2 (4x4 PE阵列，每个PE一个32位操作数)
pe_operand2_data:
    .word 0x00000005, 0x00000006, 0x00000007, 0x00000008  # PE0-PE3
    .word 0x00000009, 0x0000000A, 0x0000000B, 0x0000000C  # PE4-PE7
    .word 0x0000000D, 0x0000000E, 0x0000000F, 0x00000010  # PE8-PE11
    .word 0x00000011, 0x00000012, 0x00000013, 0x00000014  # PE12-PE15

# PE测试数据 - 配置与路由 (4x4 PE阵列，每个PE一个32位配置字)
pe_config_data:
    # PE0: ADD运算，从外部操作数1和2读取，输出到北向和存储到内存
    .word (PE_OP_ADD << PE_OPCODE_SHIFT) | (PE_SRC_OPERAND1 << PE_SRC1_SEL_SHIFT) | (PE_SRC_OPERAND2 << PE_SRC2_SEL_SHIFT) | (1 << PE_ROUTE_NORTH_SHIFT) | (1 << PE_STORE_MEM_SHIFT)
    # PE1: SUB运算，从外部操作数1和2读取，输出到南向
    .word (PE_OP_SUB << PE_OPCODE_SHIFT) | (PE_SRC_OPERAND1 << PE_SRC1_SEL_SHIFT) | (PE_SRC_OPERAND2 << PE_SRC2_SEL_SHIFT) | (1 << PE_ROUTE_SOUTH_SHIFT)
    # PE2: MUL运算，从外部操作数1和2读取，输出到东向
    .word (PE_OP_MUL << PE_OPCODE_SHIFT) | (PE_SRC_OPERAND1 << PE_SRC1_SEL_SHIFT) | (PE_SRC_OPERAND2 << PE_SRC2_SEL_SHIFT) | (1 << PE_ROUTE_EAST_SHIFT)
    # PE3: AND运算，从外部操作数1和2读取，输出到西向
    .word (PE_OP_AND << PE_OPCODE_SHIFT) | (PE_SRC_OPERAND1 << PE_SRC1_SEL_SHIFT) | (PE_SRC_OPERAND2 << PE_SRC2_SEL_SHIFT) | (1 << PE_ROUTE_WEST_SHIFT)
    # PE4-PE15: 使用默认配置
    .word 0x00000000, 0x00000000, 0x00000000, 0x00000000
    .word 0x00000000, 0x00000000, 0x00000000, 0x00000000
    .word 0x00000000, 0x00000000, 0x00000000, 0x00000000

# PE期望结果数据 (4x4 PE阵列，每个PE一个32位期望结果)
pe_expected_results:
    # PE0: 0x0000000A + 0x00000005 = 0x0000000F
    .word 0x0000000F
    # PE1: 0x0000000B - 0x00000006 = 0x00000005
    .word 0x00000005
    # PE2: 0x0000000C * 0x00000007 = 0x00000054
    .word 0x00000054
    # PE3: 0x0000000D & 0x00000008 = 0x00000008
    .word 0x00000008
    # PE4-PE15: 默认期望结果
    .word 0x00000000, 0x00000000, 0x00000000, 0x00000000
    .word 0x00000000, 0x00000000, 0x00000000, 0x00000000
    .word 0x00000000, 0x00000000, 0x00000000, 0x00000000

# 测试结果标志
pe_test_result:
    .word 0x00000000  # 0=测试中, 1=成功, 2=失败

.section .bss
# 未初始化数据段
timer_interrupt_count:
    .word 0  # Timer中断计数器
