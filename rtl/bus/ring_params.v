// ring_params.v
// 总线参数配置

// 通过修改NODES宏可以配置节点数量
`define NODES 16

// 数据宽度
`define DATA_WIDTH 32

// 地址宽度
`define ADDR_WIDTH 32

// 节点ID宽度
`define NODE_ID_WIDTH 5

// 总线状态定义
`define STATE_IDLE 2'b00
`define STATE_ARB  2'b01
`define STATE_DATA 2'b10
`define STATE_ACK  2'b11
