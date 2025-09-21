// pe_router_params.v
// 路由模块参数配置

// 数据宽度
`define DATA_WIDTH 32
`define ADDR_WIDTH 16

// 路由参数
`define NUM_PORTS 5
`define PORT_ID_WIDTH 3

// 端口定义
`define PORT_NORTH 3'b000
`define PORT_SOUTH 3'b001
`define PORT_EAST  3'b010
`define PORT_WEST  3'b011
`define PORT_LOCAL 3'b100

// 路由算法
`define ROUTE_XY      2'b00  // XY维度路由
`define ROUTE_WESTFIRST 2'b01  // 西向优先
`define ROUTE_NORTHLAST 2'b10  // 北向最后
`define ROUTE_CUSTOM  2'b11  // 自定义路由

// 缓冲区深度
`define BUFFER_DEPTH 4
`define BUFFER_ADDR_WIDTH 2

// 配置寄存器地址
`define REG_ROUTE_ALGO 16'h0000  // 路由算法配置
`define REG_ROUTE_TABLE 16'h0004 // 路由表配置
`define REG_PORT_CTRL  16'h0008  // 端口控制
`define REG_PORT_STAT  16'h000C  // 端口状态

// 状态定义
`define STATE_IDLE 2'b00
`define STATE_ARB  2'b01
`define STATE_DATA 2'b10
`define STATE_ACK  2'b11
