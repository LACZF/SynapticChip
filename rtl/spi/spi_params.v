// spi_params.v
// SPI控制器参数配置

// 数据宽度参数
`define SPI_DATA_WIDTH 32      // 数据宽度
`define SPI_ADDR_WIDTH 32      // 地址宽度
`define SPI_NODE_ID_WIDTH 5    // 节点ID宽度

// SPI寄存器地址偏移
`define SPI_REG_CONTROL  8'h00  // 控制寄存器
`define SPI_REG_STATUS   8'h04  // 状态寄存器
`define SPI_REG_DATA     8'h08  // 数据寄存器
`define SPI_REG_ADDR     8'h0C  // 地址寄存器
`define SPI_REG_CMD      8'h10  // 命令寄存器
`define SPI_REG_CLK_DIV  8'h14  // 时钟分频寄存器
`define SPI_REG_CONFIG   8'h18  // 配置寄存器
`define SPI_REG_CS_SEL   8'h1C  // 片选选择寄存器

// 控制寄存器位定义
`define SPI_CTRL_EN       0     // 使能位
`define SPI_CTRL_IRQ_EN   1     // 中断使能位
`define SPI_CTRL_BUSY     2     // 忙标志位
`define SPI_CTRL_READY    3     // 就绪标志位
`define SPI_CTRL_MASTER   4     // 主机模式位

// 状态寄存器位定义
`define SPI_STATUS_TX_READY  0     // 发送就绪
`define SPI_STATUS_RX_READY  1     // 接收就绪
`define SPI_STATUS_BUSY      2     // 忙状态
`define SPI_STATUS_ERROR     3     // 错误标志
`define SPI_STATUS_IRQ_PEND  4     // 中断挂起

// SPI操作模式
`define SPI_MODE_0 2'b00   // CPOL=0, CPHA=0
`define SPI_MODE_1 2'b01   // CPOL=0, CPHA=1
`define SPI_MODE_2 2'b10   // CPOL=1, CPHA=0
`define SPI_MODE_3 2'b11   // CPOL=1, CPHA=1

// 操作类型定义
`define SPI_OP_READ  1'b0
`define SPI_OP_WRITE 1'b1

// SPI命令定义
`define SPI_CMD_READ_DATA    8'h03  // 标准SPI读数据
`define SPI_CMD_FAST_READ    8'h0B  // 快速读
`define SPI_CMD_READ_DUAL    8'h3B  // 双线读
`define SPI_CMD_READ_QUAD    8'h6B  // 四线读
`define SPI_CMD_WRITE_ENABLE 8'h06  // 写使能
`define SPI_CMD_WRITE_DATA   8'h02  // 页编程

// 状态机状态定义
`define SPI_STATE_IDLE   3'b000
`define SPI_STATE_CMD    3'b001
`define SPI_STATE_ADDR   3'b010
`define SPI_STATE_DUMMY  3'b011
`define SPI_STATE_READ   3'b100
`define SPI_STATE_WRITE  3'b101
`define SPI_STATE_DONE   3'b110

// FIFO参数
`define SPI_FIFO_DEPTH    16    // FIFO深度
`define SPI_FIFO_ADDR_WIDTH 4   // FIFO地址宽度