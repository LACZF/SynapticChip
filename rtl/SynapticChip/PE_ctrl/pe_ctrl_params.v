// pe_ctrl_params.v
// Fabric参数配置

// 系统参数
`define DATA_WIDTH 32
`define ADDR_WIDTH 16
`define PE_ID_WIDTH 4

// PE阵列尺寸
`define ARRAY_ROWS 4
`define ARRAY_COLS 4
`define NUM_PES 16

// 指令宽度和字段
`define INST_WIDTH 32
`define OPCODE_WIDTH 6
`define REG_ADDR_WIDTH 4

// 操作码定义
`define OP_NOP   6'b000000
`define OP_CFG_PE 6'b010000  // 配置PE
`define OP_CFG_ROUTE 6'b010001  // 配置路由
`define OP_READ_STAT 6'b010010  // 读取状态
`define OP_START_PE 6'b010011   // 启动PE
`define OP_STOP_PE 6'b010100    // 停止PE
`define OP_RESET_PE 6'b010101   // 复位PE

// 寄存器地址映射
`define REG_PE_CTRL 16'h0000  // PE控制寄存器
`define REG_PE_STAT 16'h0004  // PE状态寄存器
`define REG_ROUTE_CFG 16'h0008 // 路由配置寄存器
`define REG_PE_INST 16'h000C   // PE指令寄存器
`define REG_PE_DATA 16'h0010   // PE数据寄存器

// Ring总线参数
`define NODES 8
`define NODE_ID_WIDTH 3

// 总线状态定义
`define STATE_IDLE 2'b00
`define STATE_ARB  2'b01
`define STATE_DATA 2'b10
`define STATE_ACK  2'b11
