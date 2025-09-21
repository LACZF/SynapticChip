// rom_params.v
// ROM和总线参数配置

// ROM参数
`define ROM_DEPTH 1024     // ROM深度（字数）
`define ADDR_WIDTH 10      // 地址宽度
`define DATA_WIDTH 32      // 数据宽度

// Flash参数
`define FLASH_ADDR_WIDTH 20 // Flash地址宽度
`define FLASH_DATA_WIDTH 8  // Flash数据宽度

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

// Flash控制命令
`define FLASH_READ  2'b01
`define FLASH_WRITE 2'b10
`define FLASH_ERASE 2'b11
