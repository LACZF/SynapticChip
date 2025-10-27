`ifndef __UART_HEADER__
    `define __UART_HEADER__

    `define UART_DIV_RATE        9'd260
    `define UART_DIV_CNT_W       9
    `define UartDivCntBus        8:0

    `define UartAddrBus          3:0
    `define UART_ADDR_W          4
    `define UartAddrLoc          3:0

    // 标准UART 16550寄存器地址定义
    `define UART_ADDR_RBR        4'h0    // 接收缓冲寄存器 (读)
    `define UART_ADDR_THR        4'h0    // 发送保持寄存器 (写)
    `define UART_ADDR_IER        4'h1    // 中断使能寄存器
    `define UART_ADDR_IIR        4'h2    // 中断识别寄存器 (读)
    `define UART_ADDR_FCR        4'h2    // FIFO控制寄存器 (写)
    `define UART_ADDR_LCR        4'h3    // 线路控制寄存器
    `define UART_ADDR_MCR        4'h4    // 调制解调器控制寄存器
    `define UART_ADDR_LSR        4'h5    // 线路状态寄存器
    `define UART_ADDR_MSR        4'h6    // 调制解调器状态寄存器
    `define UART_ADDR_SCR        4'h7    // 暂存寄存器
    `define UART_ADDR_DLL        4'h0    // 除数锁存低字节 (LCR[7]=1时)
    `define UART_ADDR_DLH        4'h1    // 除数锁存高字节 (LCR[7]=1时)

    // 旧的寄存器定义（向后兼容）
    `define UART_ADDR_STATUS     4'h5    // 重定向到LSR寄存器
    `define UART_ADDR_DATA       4'h0    // 重定向到RBR/THR寄存器

    // IER寄存器位定义
    `define UART_IER_ERBFI       0       // 接收缓冲满中断使能
    `define UART_IER_ETBEI       1       // 发送保持寄存器空中断使能
    `define UART_IER_ELSI        2       // 接收线状态中断使能
    `define UART_IER_EDSSI       3       // 调制解调器状态中断使能

    // IIR寄存器位定义
    `define UART_IIR_NO_INT      0       // 无中断
    `define UART_IIR_INT_ID      3:1     // 中断ID
    `define UART_IIR_FIFO_STAT   7:6     // FIFO状态

    // FCR寄存器位定义
    `define UART_FCR_FIFO_EN     0       // FIFO使能
    `define UART_FCR_CLEAR_RCVR  1       // 清除接收FIFO
    `define UART_FCR_CLEAR_XMIT  2       // 清除发送FIFO
    `define UART_FCR_DMA_MODE    3       // DMA模式选择
    `define UART_FCR_FIFO_TRIG   7:6     // FIFO触发级别

    // LCR寄存器位定义
    `define UART_LCR_WLS         1:0     // 字长度选择
    `define UART_LCR_STB         2       // 停止位选择
    `define UART_LCR_PEN         3       // 奇偶校验使能
    `define UART_LCR_EPS         4       // 奇偶校验选择
    `define UART_LCR_SP          5       // 附加停止位
    `define UART_LCR_SBREAK      6       // 中止发送
    `define UART_LCR_DLAB        7       // 除数锁存访问位

    // MCR寄存器位定义
    `define UART_MCR_DTR         0       // 数据终端就绪
    `define UART_MCR_RTS         1       // 请求发送
    `define UART_MCR_OUT1        2       // 用户定义输出1
    `define UART_MCR_OUT2        3       // 用户定义输出2
    `define UART_MCR_LOOP        4       // 循环回送模式

    // LSR寄存器位定义
    `define UART_LSR_DR          0       // 数据就绪
    `define UART_LSR_OE          1       // 溢出错误
    `define UART_LSR_PE          2       // 奇偶校验错误
    `define UART_LSR_FE          3       // 帧错误
    `define UART_LSR_BI          4       // 中断检测
    `define UART_LSR_THRE        5       // 发送保持寄存器空
    `define UART_LSR_TEMT        6       // 发送器空
    `define UART_LSR_FIFO_ERR    7       // FIFO错误

    // MSR寄存器位定义
    `define UART_MSR_DCTS        0       // CTS变化
    `define UART_MSR_DDSR        1       // DSR变化
    `define UART_MSR_TERI        2       // RI变化
    `define UART_MSR_DDCD        3       // DCD变化
    `define UART_MSR_CTS         4       // 清除发送
    `define UART_MSR_DSR         5       // 数据设置就绪
    `define UART_MSR_RI          6       // 振铃指示
    `define UART_MSR_DCD         7       // 数据载波检测

    // 控制位定义
    `define UartCtrlIrqRx        0
    `define UartCtrlIrqTx        1
    `define UartCtrlBusyRx       2
    `define UartCtrlBusyTx       3

    // 状态位定义
    `define UartStateBus         0:0
    `define UART_STATE_IDLE      1'b0
    `define UART_STATE_TX        1'b1
    `define UART_STATE_RX        1'b1

    // 位计数定义
    `define UartBitCntBus        3:0
    `define UART_BIT_CNT_W       4
    `define UART_BIT_CNT_START   4'h0
    `define UART_BIT_CNT_MSB     4'h8
    `define UART_BIT_CNT_STOP    4'h9

    // 起始位和停止位定义
    `define UART_START_BIT       1'b0
    `define UART_STOP_BIT        1'b1

`endif