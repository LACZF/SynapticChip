// top_system.v
// Top-level system module, integrating all components

`include "top_system_params.v"

module top_system #(
    parameter BUS_TYPE                        = `BUS_TYPE_DIRECT,
    parameter NUM_RINGS                       = 2,
    parameter NUM_NODES                       = 8,
    parameter ADDR_WIDTH                      = 64,
    parameter DATA_WIDTH                      = 64,
    parameter L1_ICACHE_DATA_WIDTH            = 32,
    parameter L1_DCACHE_DATA_WIDTH            = 64,
    parameter L2_CACHE_DATA_WIDTH             = 512,
    parameter L3_CACHE_DATA_WIDTH             = 512,
    parameter MEM_WIDTH                       = 512,
    parameter OPCODE_WIDTH                    = 8,
    parameter RING_ID_WIDTH                   = 4,
    parameter NODE_ID_WIDTH                   = 8,
    parameter TX_FIFO_DEPTH                   = 4,
    parameter RX_FIFO_DEPTH                   = 4,
    parameter RSP_FIFO_DEPTH                  = 4,
    parameter NUM_CORES                       = 1,
    parameter MATCH_TYPE_WIDTH                = 2,
    parameter INST_WIDTH                      = 32,
    parameter CORE_ID_WIDTH                   = 2,
    parameter ENABLE_L2_CACHE                 = 0,
    parameter ENABLE_L3_CACHE                 = 0,
    parameter GPIO_WIDTH                      = 32,
    parameter SPI_CS_NUM                      = 1,
    parameter NUM_PES                         = 4,
    parameter PE_ARRAY_ROWS                   = 2,
    parameter PE_ARRAY_COLS                   = 2,
    parameter PE_ID_WIDTH                     = 4,
    parameter CPU_TYPE                        = 0,
    parameter ENABLE_MMU                      = 1
)(
    input                                     clk,
    input                                     rst_n,

    // UART interface
    output                                    uart_txd_o,
    input                                     uart_rxd_i,

    // GPIO interface
    inout  [GPIO_WIDTH-1:0]                   gpio_pins,

    // External interrupt
    input                                     ext_int_i,

    // Status output
    output [DATA_WIDTH-1:0]                   system_status_o,

    // JTAG interface
    input                                     jtag_tck_i,
    input                                     jtag_tms_i,
    input                                     jtag_tdi_i,
    output                                    jtag_tdo_o,
    output                                    jtag_tdo_en_o,

    // JTAG debug outputs
    output [DATA_WIDTH-1:0]                   jtag_debug_data_o,
    output                                    jtag_debug_valid_o,

    // SPI physical interface
    output [SPI_CS_NUM-1:0]                   spi_cs_n_o,
    output                                    spi_clk_o,
    output                                    spi_mosi_o,
    input                                     spi_miso_i
);
    reg [NUM_NODES*ADDR_WIDTH-1:0]        node_start_addr;
    reg [NUM_NODES*ADDR_WIDTH-1:0]        node_end_addr;

    // CPU
    wire                                  cpu_mem_req;
    wire [ADDR_WIDTH-1:0]                 cpu_mem_addr;
    wire [MEM_WIDTH-1:0]                  cpu_mem_wdata;
    wire                                  cpu_mem_we;
    wire                                  cpu_mem_ready;
    wire [MEM_WIDTH-1:0]                  cpu_mem_rdata;

    // PE
    wire [NUM_PES-1:0]                    pe_enable;
    wire [NUM_PES-1:0]                    pe_reset;
    wire [(NUM_PES*INST_WIDTH)-1:0]       pe_instructions;
    wire                                  pe_inst_valid;
    wire [(NUM_PES*DATA_WIDTH)-1:0]       pe_status;
    wire [(NUM_PES*DATA_WIDTH)-1:0]       pe_outputs;
    wire [NUM_PES-1:0]                    pe_busy;
    wire [(NUM_PES*4*PE_ID_WIDTH)-1:0]    pe_route_config;
    wire                                  pe_route_cfg_valid;

    // GPIO
    wire                                  gpio_req;
    wire                                  gpio_we;
    wire [ADDR_WIDTH-1:0]                 gpio_addr;
    wire [DATA_WIDTH-1:0]                 gpio_data_in;
    reg [DATA_WIDTH-1:0]                  gpio_data_out;
    reg                                   gpio_ack;
    reg                                   gpio_int;

    // JTAG
    wire                                  jtag_req;
    wire                                  jtag_we;
    wire [ADDR_WIDTH-1:0]                 jtag_addr;
    wire [DATA_WIDTH-1:0]                 jtag_data_in;
    wire [DATA_WIDTH-1:0]                 jtag_data_out;
    wire                                  jtag_ack;

    // SPI
    wire                                  spi_req;
    wire                                  spi_we;
    wire [ADDR_WIDTH-1:0]                 spi_addr;
    wire [DATA_WIDTH-1:0]                 spi_data_in;
    wire [DATA_WIDTH-1:0]                 spi_data_out;
    wire                                  spi_ack;

    // UART
    wire                                  uart_req;
    wire                                  uart_we;
    wire [ADDR_WIDTH-1:0]                 uart_addr;
    wire [DATA_WIDTH-1:0]                 uart_data_in;
    wire [DATA_WIDTH-1:0]                 uart_data_out;
    wire                                  uart_ack;
    wire                                  uart_rts;
    wire                                  uart_cts;
    wire                                  uart_int;

    // Instantiate Ring bus
    bus_top #(
        .BUS_TYPE(BUS_TYPE),
        .NUM_RINGS(NUM_RINGS),
        .NUM_NODES(NUM_NODES),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .OPCODE_WIDTH(OPCODE_WIDTH),
        .RING_ID_WIDTH(RING_ID_WIDTH),
        .NODE_ID_WIDTH(NODE_ID_WIDTH),
        .TX_FIFO_DEPTH(TX_FIFO_DEPTH),
        .RX_FIFO_DEPTH(RX_FIFO_DEPTH),
        .RSP_FIFO_DEPTH(RSP_FIFO_DEPTH),
        .NUM_CORES(NUM_CORES),
        .GPIO_WIDTH(GPIO_WIDTH),
        .SPI_CS_NUM(SPI_CS_NUM),
        .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH),
        .NUM_PES(NUM_PES),
        .PE_ARRAY_ROWS(PE_ARRAY_ROWS),
        .PE_ARRAY_COLS(PE_ARRAY_COLS),
        .INST_WIDTH(INST_WIDTH),
        .PE_ID_WIDTH(PE_ID_WIDTH)
    ) bus (
        .clk(clk),
        .rst_n(rst_n),

        .node_start_addr_i(node_start_addr),
        .node_end_addr_i(node_end_addr),

        // CPU
        .cpu_ext_int_o(ext_int_i),
        .cpu_mem_req_i(cpu_mem_req),
        .cpu_mem_addr_i(cpu_mem_addr),
        .cpu_mem_wdata_i(cpu_mem_wdata),
        .cpu_mem_we_i(cpu_mem_we),
        .cpu_mem_ready_o(cpu_mem_ready),
        .cpu_mem_rdata_o(cpu_mem_rdata),

        // PE
        .pe_enable_o(pe_enable),
        .pe_reset_o(pe_reset),
        .pe_instructions_o(pe_instructions),
        .pe_inst_valid_o(pe_inst_valid),
        .pe_status_i(pe_status),
        .pe_outputs_i(pe_outputs),
        .pe_busy_i(pe_busy),
        .pe_route_config_o(pe_route_config),
        .pe_route_cfg_valid_o(pe_route_cfg_valid),

        // GPIO
        .gpio_req_o(gpio_req),
        .gpio_we_o(gpio_we),
        .gpio_addr_o(gpio_addr),
        .gpio_data_in_o(gpio_data_in),
        .gpio_data_out_i(gpio_data_out),
        .gpio_ack_i(gpio_ack),
        .gpio_pins(gpio_pins),
        .gpio_int_i(gpio_int),

        // JTAG
        .jtag_tck_o(jtag_tck_i),
        .jtag_tms_o(jtag_tms_i),
        .jtag_tdi_o(jtag_tdi_i),
        .jtag_tdo_i(jtag_tdo_o),
        .jtag_tdo_en_i(jtag_tdo_en_o),
        .jtag_req_o(jtag_req),
        .jtag_we_o(jtag_we),
        .jtag_addr_o(jtag_addr),
        .jtag_data_in_o(jtag_data_in),
        .jtag_data_out_i(jtag_data_out),
        .jtag_ack_i(jtag_ack),
        .jtag_debug_data_i(jtag_debug_data_o),
        .jtag_debug_valid_i(jtag_debug_valid_o),

        // SPI
        .spi_req_o(spi_req),
        .spi_we_o(spi_we),
        .spi_addr_o(spi_addr),
        .spi_data_in_o(spi_data_in),
        .spi_data_out_i(spi_data_out),
        .spi_ack_i(spi_ack),
        .spi_cs_n_i(spi_cs_n_o),
        .spi_clk_i(spi_clk_o),
        .spi_mosi_i(spi_miso_i),
        .spi_miso_o(spi_mosi_o),

        // UART
        .uart_req_o(uart_req),
        .uart_we_o(uart_we),
        .uart_addr_o(uart_addr),
        .uart_data_in_o(uart_data_in),
        .uart_data_out_i(uart_data_out),
        .uart_ack_i(uart_ack),
        .uart_txd_i(uart_txd_o),
        .uart_rxd_o(uart_rxd_i),
        .uart_rts_i(uart_rts),
        .uart_cts_o(uart_cts),
        .uart_int_i(uart_int)
    );

    cpu_top #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .ENABLE_MMU(ENABLE_MMU),
        .L1_ICACHE_DATA_WIDTH(L1_ICACHE_DATA_WIDTH),
        .L1_DCACHE_DATA_WIDTH(L1_DCACHE_DATA_WIDTH),
        .L2_CACHE_DATA_WIDTH(L2_CACHE_DATA_WIDTH),
        .L3_CACHE_DATA_WIDTH(L3_CACHE_DATA_WIDTH),
        .INST_WIDTH(INST_WIDTH),
        .MEM_WIDTH(MEM_WIDTH),
        .NUM_CORES(NUM_CORES),
        .CORE_ID_WIDTH(CORE_ID_WIDTH),
        .ENABLE_L2_CACHE(ENABLE_L2_CACHE),
        .ENABLE_L3_CACHE(ENABLE_L3_CACHE),
        .CPU_TYPE(CPU_TYPE)
    ) cpu (
        .clk(clk),
        .rst_n(rst_n),

        .ext_int_i(ext_int_i),

        .mem_req_o(cpu_mem_req),
        .mem_addr_o(cpu_mem_addr),
        .mem_wdata_o(cpu_mem_wdata),
        .mem_we_o(cpu_mem_we),
        .mem_ready_i(cpu_mem_ready),
        .mem_rdata_i(cpu_mem_rdata)
    );

    // Instantiate GPIO module
    gpio_module #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .GPIO_WIDTH(GPIO_WIDTH)
    ) gpio (
        .clk(clk),
        .rst_n(rst_n),
        .req_i(gpio_req),
        .we_i(gpio_we),
        .addr_i(gpio_addr),
        .data_out_o(gpio_data_out),
        .data_in_i(gpio_data_in),
        .ack_o(gpio_ack),
        .gpio_pins(gpio_pins),
        .int_out_o(gpio_int)
    );

    // Instantiate UART module
    uart_core uart (
        .clk(clk),
        .rst_n(rst_n),

        .req_i(uart_req),
        .we_i(uart_we),
        .addr_i(uart_addr),
        .data_out_o(uart_data_out),
        .data_in_i(uart_data_in),
        .ack_o(uart_ack),
        .txd_o(uart_txd_o),
        .rxd_i(uart_rxd_i),
        .rts_o(uart_rts),
        .cts_i(uart_cts),
        .int_out_o(uart_int)
    );

    // Instantiate JTAG
    jtag_top #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .INST_WIDTH(INST_WIDTH)
    ) jtag (
        .clk(clk),
        .rst_n(rst_n),

        .tck_i(jtag_tck_i),
        .tms_i(jtag_tms_i),
        .tdi_i(jtag_tdi_i),
        .tdo_o(jtag_tdo_o),
        .tdo_en_o(jtag_tdo_en_o),
        .req_i(jtag_req),
        .we_i(jtag_we),
        .addr_i(jtag_addr),
        .data_out_o(jtag_data_out),
        .data_in_i(jtag_data_in),
        .ack_o(jtag_ack),
        .debug_data_o(jtag_debug_data_o),
        .debug_valid_o(jtag_debug_valid_o)
    );

    reg [DATA_WIDTH-1:0] fabric_status;
    assign system_status_o = fabric_status;
    pe_top #(
        .NUM_RINGS(NUM_RINGS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NODE_ID_WIDTH(NODE_ID_WIDTH),
        .OPCODE_WIDTH(OPCODE_WIDTH),
        .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH),
        .NUM_PES(NUM_PES),
        .INST_WIDTH(INST_WIDTH),
        .PE_ID_WIDTH(PE_ID_WIDTH),
        .PE_ARRAY_ROWS(PE_ARRAY_ROWS),
        .PE_ARRAY_COLS(PE_ARRAY_COLS)
    ) pe (
        .clk(clk),
        .rst_n(rst_n),

        .pe_enable_i(pe_enable),
        .pe_reset_i(pe_reset),
        .pe_instructions_i(pe_instructions),
        .pe_inst_valid_i(pe_inst_valid),
        .pe_status_o(pe_status),
        .pe_outputs_o(pe_outputs),
        .pe_busy_o(pe_busy),
        .route_config_i(pe_route_config),
        .route_cfg_valid_i(pe_route_cfg_valid),

        .fabric_status_o(fabric_status)
    );

    // Instantiate SPI core controller
    spi_core #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .CS_NUM(SPI_CS_NUM)
    ) spi (
        .clk(clk),
        .rst_n(rst_n),

        .req_i(spi_req),
        .we_i(spi_we),
        .addr_i(spi_addr),
        .data_out_o(spi_data_out),
        .data_in_i(spi_data_in),
        .ack_o(spi_ack),
        .spi_cs_n_o(spi_cs_n_o),
        .spi_clk_o(spi_clk_o),
        .spi_mosi_o(spi_mosi_o),
        .spi_miso_i(spi_miso_i)
    );

endmodule