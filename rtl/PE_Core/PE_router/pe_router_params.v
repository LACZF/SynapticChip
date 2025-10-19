// pe_router_params.v
// Router module parameter configuration

// Data width
`define DATA_WIDTH 64
`define ADDR_WIDTH 64

// Routing parameters
`define NUM_PORTS 5
`define PORT_ID_WIDTH 3

// Port definitions
`define PORT_NORTH 3'b000
`define PORT_SOUTH 3'b001
`define PORT_EAST  3'b010
`define PORT_WEST  3'b011
`define PORT_LOCAL 3'b100

// Routing algorithms
`define ROUTE_XY      2'b00  // XY dimension routing
`define ROUTE_WESTFIRST 2'b01  // West-first
`define ROUTE_NORTHLAST 2'b10  // North-last
`define ROUTE_CUSTOM  2'b11  // Custom routing

// Buffer depth
`define BUFFER_DEPTH 4
`define BUFFER_ADDR_WIDTH 2

// Configuration register addresses
`define REG_ROUTE_ALGO 16'h0000  // Routing algorithm configuration
`define REG_ROUTE_TABLE 16'h0004 // Routing table configuration
`define REG_PORT_CTRL  16'h0008  // Port control
`define REG_PORT_STAT  16'h000C  // Port status

// State definitions
`define STATE_IDLE 2'b00
`define STATE_ARB  2'b01
`define STATE_DATA 2'b10
`define STATE_ACK  2'b11