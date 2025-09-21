// ram_params.v
// RAM和总线参数配置

// RAM参数
`define RAM_DEPTH 1024    // RAM深度（字数）
`define ADDR_WIDTH 10     // 地址宽度
`define DATA_WIDTH 32     // 数据宽度

// 总线参数
`define NODES 4           // 总线节点数量
`define NODE_ID_WIDTH 2   // 节点ID宽度

// 总线状态定义
`define STATE_IDLE 2'b00
`define STATE_ARB  2'b01
`define STATE_DATA 2'b10
`define STATE_ACK  2'b11

// 操作类型定义
`define OP_READ  1'b0
`define OP_WRITE 1'b1
