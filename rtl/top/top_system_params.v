// top_system_params.v
// System-level parameter configuration

// Data width
`define DATA_WIDTH 64
`define ADDR_WIDTH 64

// Ring bus parameters
`define NODES 16
`define NODE_ID_WIDTH 5

// PE array parameters
`define PE_ARRAY_ROWS 2
`define PE_ARRAY_COLS 2
`define NUM_PES       4
`define PE_ID_WIDTH   4

// Instruction width
`define INST_WIDTH 32

// Memory parameters
`define RAM_SIZE 4096
`define ROM_SIZE 2048

// Address mapping
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
`define JTAG_BASE  32'h5000_0000
`define JTAG_END   32'h5000_00FF
`define SPI_BASE   32'h6000_0000
`define SPI_END    32'h6000_00FF

// Node ID allocation
`define NODE_RISCV 5'd0
`define NODE_RAM   5'd1
`define NODE_ROM   5'd2
`define NODE_GPIO  5'd3
`define NODE_UART  5'd4
`define NODE_PE    5'd5
`define NODE_JTAG  5'd6
`define NODE_SPI   5'd7

// Routing parameters
`define NUM_PORTS 5
`define PORT_ID_WIDTH 3

`define BUS_TYPE_RING 0    // Ring bus type
`define BUS_TYPE_DIRECT 1   // Direct connection type

// SPI parameters
`define SPI_CS_NUM 2        // Number of SPI chip select signals