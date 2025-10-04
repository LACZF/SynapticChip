// top_system_params.v
// 系统级参数配置

// 数据宽度
`define DATA_WIDTH 32
`define ADDR_WIDTH 32

// Ring总线参数
`define NODES 16
`define NODE_ID_WIDTH 5

// PE阵列参数
`define PE_ARRAY_ROWS 2
`define PE_ARRAY_COLS 2
`define NUM_PES 16
`define PE_ID_WIDTH 4

// 指令宽度
`define INST_WIDTH 32

// 存储器参数
`define RAM_SIZE 4096
`define ROM_SIZE 2048

// 地址映射
`define RAM_BASE   32'h0000_0000
`define RAM_END    32'h0000_FFFF
`define ROM_BASE   32'h1000_0000
`define ROM_END    32'h1000_7FFF
`define GPIO_BASE  32'h2000_0000
`define GPIO_END   32'h2000_00FF
`define UART_BASE  32'h3000_0000
`define UART_END   32'h3000_00FF
`define FABRIC_BASE 32'h4000_0000
`define FABRIC_END  32'h4000_FFFF

// 节点ID分配
`define NODE_RISCV 5'd0
`define NODE_RAM   5'd1
`define NODE_ROM   5'd2
`define NODE_GPIO  5'd3
`define NODE_UART  5'd4
`define NODE_FABRIC 5'd5
`define NODE_JTAG 5'd6
`define NODE_SPI 5'd7

// 路由参数
`define NUM_PORTS 5
`define PORT_ID_WIDTH 3