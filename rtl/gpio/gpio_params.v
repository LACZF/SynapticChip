// gpio_params.v
// GPIO和总线参数配置

// GPIO参数
`define GPIO_WIDTH 32      // GPIO引脚数量
`define ADDR_WIDTH 32      // 地址宽度
`define DATA_WIDTH 32      // 数据宽度

// 寄存器地址偏移
`define REG_DATA   8'h00   // 数据寄存器
`define REG_DIR    8'h04   // 方向寄存器 (0=输入, 1=输出)
`define REG_INTEN  8'h08   // 中断使能寄存器
`define REG_INTPOL 8'h0C   // 中断极性寄存器 (0=低电平/下降沿, 1=高电平/上升沿)
`define REG_INTTYPE 8'h10  // 中断类型寄存器 (0=电平, 1=边沿)
`define REG_INTSTAT 8'h14  // 中断状态寄存器
`define REG_DEBOUNCE 8'h18 // 去抖周期寄存器

// 总线参数
`define NODES 16            // 总线节点数量
`define NODE_ID_WIDTH 5    // 节点ID宽度

// 总线状态定义
`define STATE_IDLE 2'b00
`define STATE_ARB  2'b01
`define STATE_DATA 2'b10
`define STATE_ACK  2'b11

// 操作类型定义
`define OP_READ  1'b0
`define OP_WRITE 1'b1
