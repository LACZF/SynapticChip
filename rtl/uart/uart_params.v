// uart_params.v
// UART和总线参数配置

// UART参数
`define DATA_WIDTH 32      // 数据宽度
`define ADDR_WIDTH 8       // 地址宽度

// 寄存器地址偏移
`define REG_RBR 8'h00      // 接收缓冲寄存器 (只读)
`define REG_THR 8'h00      // 发送保持寄存器 (只写)
`define REG_IER 8'h04      // 中断使能寄存器
`define REG_IIR 8'h08      // 中断标识寄存器 (只读)
`define REG_FCR 8'h08      // FIFO控制寄存器 (只写)
`define REG_LCR 8'h0C      // 线控制寄存器
`define REG_MCR 8'h10      // Modem控制寄存器
`define REG_LSR 8'h14      // 线状态寄存器 (只读)
`define REG_MSR 8'h18      // Modem状态寄存器 (只读)
`define REG_SCR 8'h1C      // Scratch寄存器
`define REG_DLL 8'h00      // 分频器锁存器低字节 (当LCR[7]=1)
`define REG_DLM 8'h04      // 分频器锁存器高字节 (当LCR[7]=1)

// 中断类型
`define INT_NONE 4'b0000   // 无中断
`define INT_RX   4'b0100   // 接收数据可用
`define INT_TX   4'b0010   // 发送保持寄存器空
`define INT_LS   4'b0110   // 接收线状态
`define INT_MS   4'b0000   // Modem状态 (通常不使用)

// 总线参数
`define NODES 4            // 总线节点数量
`define NODE_ID_WIDTH 2    // 节点ID宽度

// 总线状态定义
`define STATE_IDLE 2'b00
`define STATE_ARB  2'b01
`define STATE_DATA 2'b10
`define STATE_ACK  2'b11

// 操作类型定义
`define OP_READ  1'b0
`define OP_WRITE 1'b1

// FIFO参数
`define FIFO_DEPTH 16      // FIFO深度
`define FIFO_ADDR_WIDTH 4  // FIFO地址宽度
