`include "top_system_params.v"

module ring_bus_top #(
    parameter NUM_RINGS                           = 2,        // Number of Ring buses (valid when BUS_TYPE is `BUS_TYPE_RING)
    parameter NUM_NODES                           = 4,        // Number of nodes per Ring (valid when BUS_TYPE is `BUS_TYPE_RING)
    parameter ADDR_WIDTH                          = 32,       // Address width
    parameter DATA_WIDTH                          = 64,       // Data width
    parameter OPCODE_WIDTH                        = 8,        // Width of operation type: read/write/response, etc.
    parameter RING_ID_WIDTH                       = 4,        // Ring ID width
    parameter NODE_ID_WIDTH                       = 8,        // Node ID width
    parameter TX_FIFO_DEPTH                       = 4,        // Transmit FIFO depth
    parameter RX_FIFO_DEPTH                       = 4,        // Receive FIFO depth
    parameter RSP_FIFO_DEPTH                      = 4,        // Response FIFO depth
    parameter NUM_CORES                           = 4,
    parameter GPIO_WIDTH                          = 32,
    parameter SPI_CS_NUM                          = 1,
    parameter MATCH_TYPE_WIDTH                    = 2,        // Match type width
    parameter NUM_PES                             = 4,
    parameter PE_ARRAY_ROWS                       = 2,
    parameter PE_ARRAY_COLS                       = 2,
    parameter INST_WIDTH                          = 32,       // Instruction width
    parameter PE_ID_WIDTH                         = 4         // PE ID width
) (
    input  wire                                   clk,
    input  wire                                   rst_n,

    input  wire [NUM_NODES*ADDR_WIDTH-1:0]        node_start_addr_i,
    input  wire [NUM_NODES*ADDR_WIDTH-1:0]        node_end_addr_i,

    // CPU
    output                                        cpu_ext_int_o,
    input  wire                                   cpu_mem_req_i,
    input  wire [ADDR_WIDTH-1:0]                  cpu_mem_addr_i,
    input  wire [511:0]                           cpu_mem_wdata_i,
    input  wire                                   cpu_mem_we_i,
    output wire                                   cpu_mem_ready_o,
    output wire [511:0]                           cpu_mem_rdata_o,

    // PE
    output reg  [NUM_PES-1:0]                     pe_enable_o,
    output reg  [NUM_PES-1:0]                     pe_reset_o,
    output reg  [(NUM_PES*INST_WIDTH)-1:0]        pe_instructions_o,
    output reg                                    pe_inst_valid_o,
    input       [(NUM_PES*DATA_WIDTH)-1:0]        pe_status_i,
    input       [(NUM_PES*DATA_WIDTH)-1:0]        pe_outputs_i,
    input       [NUM_PES-1:0]                     pe_busy_i,
    output reg  [(NUM_PES*4*PE_ID_WIDTH)-1:0]     pe_route_config_o,
    output reg                                    pe_route_cfg_valid_o,

    // GPIO
    output                                        gpio_req_o,
    output                                        gpio_we_o,
    output      [ADDR_WIDTH-1:0]                  gpio_addr_o,
    output      [DATA_WIDTH-1:0]                  gpio_data_in_o,
    input  reg  [DATA_WIDTH-1:0]                  gpio_data_out_i,
    input  reg                                    gpio_ack_i,
    inout       [GPIO_WIDTH-1:0]                  gpio_pins,
    input  reg                                    gpio_int_i,

    // JTAG interface
    output                                        jtag_tck_o,
    output                                        jtag_tms_o,
    output                                        jtag_tdi_o,
    input  reg                                    jtag_tdo_i,
    input  reg                                    jtag_tdo_en_i,
    output                                        jtag_req_o,
    output                                        jtag_we_o,
    output      [ADDR_WIDTH-1:0]                  jtag_addr_o,
    output      [DATA_WIDTH-1:0]                  jtag_data_in_o,
    input  reg  [DATA_WIDTH-1:0]                  jtag_data_out_i,
    input  reg                                    jtag_ack_i,
    input  reg  [DATA_WIDTH-1:0]                  jtag_debug_data_i,
    input  reg                                    jtag_debug_valid_i,

    // SPI
    output wire                                   spi_req_o,
    output wire                                   spi_we_o,
    output wire [ADDR_WIDTH-1:0]                  spi_addr_o,
    output wire [DATA_WIDTH-1:0]                  spi_data_in_o,
    input  reg  [DATA_WIDTH-1:0]                  spi_data_out_i,
    input  reg                                    spi_ack_i,
    input  reg  [SPI_CS_NUM-1:0]                  spi_cs_n_i,
    input  reg                                    spi_clk_i,
    input  reg                                    spi_mosi_i,
    output wire                                   spi_miso_o,

    // UART
    output                                        uart_req_o,
    output                                        uart_we_o,
    output      [ADDR_WIDTH-1:0]                  uart_addr_o,
    output      [DATA_WIDTH-1:0]                  uart_data_in_o,
    input  reg  [DATA_WIDTH-1:0]                  uart_data_out_i,
    input  reg                                    uart_ack_i,
    input  reg                                    uart_txd_i,
    output                                        uart_rxd_o,
    input  reg                                    uart_rts_i,
    output                                        uart_cts_o,
    input  reg                                    uart_int_i
);
    // Transmit request
    wire [NUM_NODES*NUM_RINGS-1:0]         tx_req_ring_mask;
    wire [NUM_NODES*NUM_RINGS-1:0]         tx_req_ring_disable;
    wire [NUM_NODES-1:0]                   tx_req_valid;
    wire [NUM_NODES-1:0]                   tx_req_is_order;
    wire [NUM_NODES*OPCODE_WIDTH-1:0]      tx_req_opcode;
    wire [NUM_NODES*MATCH_TYPE_WIDTH-1:0]  tx_req_match_type;
    wire [NUM_NODES*NODE_ID_WIDTH-1:0]     tx_req_source_id;
    wire [NUM_NODES*NODE_ID_WIDTH-1:0]     tx_req_target_id;
    wire [NUM_NODES*ADDR_WIDTH-1:0]        tx_req_addr;
    wire [NUM_NODES*DATA_WIDTH-1:0]        tx_req_data;

    // Receive request
    wire [NUM_NODES-1:0]                   rx_req_valid;
    wire [NUM_NODES-1:0]                   rx_req_is_order;
    wire [NUM_NODES*OPCODE_WIDTH-1:0]      rx_req_opcode;
    wire [NUM_NODES*MATCH_TYPE_WIDTH-1:0]  rx_req_match_type;
    wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rx_req_source_id;
    wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rx_req_target_id;
    wire [NUM_NODES*ADDR_WIDTH-1:0]        rx_req_addr;
    wire [NUM_NODES*DATA_WIDTH-1:0]        rx_req_data;
    wire [NUM_NODES-1:0]                   tx_req_ready;

    // Receive response
    wire [NUM_NODES-1:0]                   rsp_valid;
    wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rsp_source_id;
    wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rsp_target_id;
    wire [NUM_NODES*ADDR_WIDTH-1:0]        rsp_addr;
    wire [NUM_NODES*DATA_WIDTH-1:0]        rsp_data;

    // Ring bus status
    wire [NUM_RINGS*RING_ID_WIDTH-1:0]     ring_id;
    wire [NUM_RINGS-1:0]                   ring_busy;

    ring_bus #(
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
        .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH)
    ) u_ring_bus (
        .clk(clk),
        .rst_n(rst_n),

        .node_start_addr_i(node_start_addr_i),
        .node_end_addr_i(node_end_addr_i),

        .tx_req_ring_mask_i(tx_req_ring_mask),
        .tx_req_ring_disable_i(tx_req_ring_disable),
        .tx_req_valid_i(tx_req_valid),
        .tx_req_is_order_i(tx_req_is_order),
        .tx_req_opcode_i(tx_req_opcode),
        .tx_req_match_type_i(tx_req_match_type),
        .tx_req_source_id_i(tx_req_source_id),
        .tx_req_target_id_i(tx_req_target_id),
        .tx_req_addr_i(tx_req_addr),
        .tx_req_data_i(tx_req_data),
        .tx_req_ready_o(tx_req_ready),

        .rx_req_valid_o(rx_req_valid),
        .rx_req_is_order_o(rx_req_is_order),
        .rx_req_opcode_o(rx_req_opcode),
        .rx_req_match_type_o(rx_req_match_type),
        .rx_req_source_id_o(rx_req_source_id),
        .rx_req_target_id_o(rx_req_target_id),
        .rx_req_addr_o(rx_req_addr),
        .rx_req_data_o(rx_req_data),

        .rsp_valid_o(rsp_valid),
        .rsp_source_id_o(rsp_source_id),
        .rsp_target_id_o(rsp_target_id),
        .rsp_addr_o(rsp_addr),
        .rsp_data_o(rsp_data),

        .ring_id_o(ring_id),
        .ring_busy(ring_busy)
    );

    cpu_with_ring #(
        .NUM_RINGS(NUM_RINGS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NODE_ID_WIDTH(NODE_ID_WIDTH),
        .NODE_ID(`NODE_RISCV),
        .OPCODE_WIDTH(OPCODE_WIDTH),
        .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH),
        .INST_WIDTH(32),
        .NUM_CORES(NUM_CORES),
        .CPU_TYPE(0)  // 0: RISC-V, reserved for other CPU types
    ) u_cpu_ring_node (
        .clk(clk),
        .rst_n(rst_n),

        .cpu_ext_int_o(cpu_ext_int_o),
        .cpu_mem_req_i(cpu_mem_req_i),
        .cpu_mem_addr_i(cpu_mem_addr_i),
        .cpu_mem_wdata_i(cpu_mem_wdata_i),
        .cpu_mem_we_i(cpu_mem_we_i),
        .cpu_mem_ready_o(cpu_mem_ready_o),
        .cpu_mem_rdata_o(cpu_mem_rdata_o),

        .tx_req_ring_mask_o(tx_req_ring_mask[`NODE_RISCV*NUM_RINGS +: NUM_RINGS]),
        .tx_req_ring_disable_o(tx_req_ring_disable[`NODE_RISCV*NUM_RINGS +: NUM_RINGS]),
        .tx_req_valid_o(tx_req_valid[`NODE_RISCV]),
        .tx_req_is_order_o(tx_req_is_order[`NODE_RISCV]),
        .tx_req_opcode_o(tx_req_opcode[`NODE_RISCV*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .tx_req_match_type_o(tx_req_match_type[`NODE_RISCV*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH]),
        .tx_req_source_id_o(tx_req_source_id[`NODE_RISCV*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .tx_req_target_id_o(tx_req_target_id[`NODE_RISCV*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .tx_req_addr_o(tx_req_addr[`NODE_RISCV*ADDR_WIDTH +: ADDR_WIDTH]),
        .tx_req_data_o(tx_req_data[`NODE_RISCV*DATA_WIDTH +: DATA_WIDTH]),

        .rx_req_valid_i(rx_req_valid[`NODE_RISCV]),
        .rx_req_is_order_i(rx_req_is_order[`NODE_RISCV]),
        .rx_req_opcode_i(rx_req_opcode[`NODE_RISCV*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .rx_req_match_type_i(rx_req_match_type[`NODE_RISCV*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH]),
        .rx_req_source_id_i(rx_req_source_id[`NODE_RISCV*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rx_req_target_id_i(rx_req_target_id[`NODE_RISCV*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rx_req_addr_i(rx_req_addr[`NODE_RISCV*ADDR_WIDTH +: ADDR_WIDTH]),
        .rx_req_data_i(rx_req_data[`NODE_RISCV*DATA_WIDTH +: DATA_WIDTH]),

        .rsp_valid_i(rsp_valid[`NODE_RISCV]),
        .rsp_source_id_i(rsp_source_id[`NODE_RISCV*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rsp_target_id_i(rsp_target_id[`NODE_RISCV*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rsp_addr_i(rsp_addr[`NODE_RISCV*ADDR_WIDTH +: ADDR_WIDTH]),
        .rsp_data_i(rsp_data[`NODE_RISCV*DATA_WIDTH +: DATA_WIDTH])
    );

    pe_ctrl_node #(
        .NUM_RINGS(NUM_RINGS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NODE_ID_WIDTH(NODE_ID_WIDTH),
        .NODE_ID(`NODE_PE),
        .OPCODE_WIDTH(OPCODE_WIDTH),
        .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH),
        .NUM_PES(NUM_PES),
        .INST_WIDTH(INST_WIDTH),
        .PE_ID_WIDTH(PE_ID_WIDTH),
        .PE_ARRAY_ROWS(PE_ARRAY_ROWS),
        .PE_ARRAY_COLS(PE_ARRAY_COLS)
    ) u_pe_ring_node (
        .clk(clk),
        .rst_n(rst_n),

        .pe_enable_o(pe_enable_o),
        .pe_reset_o(pe_reset_o),
        .pe_instructions_o(pe_instructions_o),
        .pe_inst_valid_o(pe_inst_valid_o),
        .pe_status_i(pe_status_i),
        .pe_outputs_i(pe_outputs_i),
        .pe_busy_i(pe_busy_i),
        .pe_route_config_o(pe_route_config_o),
        .pe_route_cfg_valid_o(pe_route_cfg_valid_o),

        .tx_req_ring_mask_o(tx_req_ring_mask[`NODE_PE*NUM_RINGS +: NUM_RINGS]),
        .tx_req_ring_disable_o(tx_req_ring_disable[`NODE_PE*NUM_RINGS +: NUM_RINGS]),
        .tx_req_valid_o(tx_req_valid[`NODE_PE]),
        .tx_req_is_order_o(tx_req_is_order[`NODE_PE]),
        .tx_req_opcode_o(tx_req_opcode[`NODE_PE*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .tx_req_match_type_o(tx_req_match_type[`NODE_PE*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH]),
        .tx_req_source_id_o(tx_req_source_id[`NODE_PE*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .tx_req_target_id_o(tx_req_target_id[`NODE_PE*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .tx_req_addr_o(tx_req_addr[`NODE_PE*ADDR_WIDTH +: ADDR_WIDTH]),
        .tx_req_data_o(tx_req_data[`NODE_PE*DATA_WIDTH +: DATA_WIDTH]),

        .rx_req_valid_i(rx_req_valid[`NODE_PE]),
        .rx_req_is_order_i(rx_req_is_order[`NODE_PE]),
        .rx_req_opcode_i(rx_req_opcode[`NODE_PE*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .rx_req_match_type_i(rx_req_match_type[`NODE_PE*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH]),
        .rx_req_source_id_i(rx_req_source_id[`NODE_PE*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rx_req_target_id_i(rx_req_target_id[`NODE_PE*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rx_req_addr_i(rx_req_addr[`NODE_PE*ADDR_WIDTH +: ADDR_WIDTH]),
        .rx_req_data_i(rx_req_data[`NODE_PE*DATA_WIDTH +: DATA_WIDTH]),

        .rsp_valid_i(rsp_valid[`NODE_PE]),
        .rsp_source_id_i(rsp_source_id[`NODE_PE*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rsp_target_id_i(rsp_target_id[`NODE_PE*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rsp_addr_i(rsp_addr[`NODE_PE*ADDR_WIDTH +: ADDR_WIDTH]),
        .rsp_data_i(rsp_data[`NODE_PE*DATA_WIDTH +: DATA_WIDTH])
    );

    gpio_node #(
        .NUM_RINGS(NUM_RINGS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NODE_ID_WIDTH(NODE_ID_WIDTH),
        .NODE_ID(`NODE_GPIO),
        .OPCODE_WIDTH(OPCODE_WIDTH),
        .GPIO_WIDTH(GPIO_WIDTH),
        .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH)
    ) u_gpio_ring_node (
        .clk(clk),
        .rst_n(rst_n),

        .gpio_req_o(gpio_req_o),
        .gpio_we_o(gpio_we_o),
        .gpio_addr_o(gpio_addr_o),
        .gpio_data_in_o(gpio_data_in_o),
        .gpio_data_out_i(gpio_data_out_i),
        .gpio_ack_i(gpio_ack_i),
        .gpio_pins(gpio_pins),
        .gpio_int_i(gpio_int_i),

        .tx_req_ring_mask_o(tx_req_ring_mask[`NODE_GPIO*NUM_RINGS +: NUM_RINGS]),
        .tx_req_ring_disable_o(tx_req_ring_disable[`NODE_GPIO*NUM_RINGS +: NUM_RINGS]),
        .tx_req_valid_o(tx_req_valid[`NODE_GPIO]),
        .tx_req_is_order_o(tx_req_is_order[`NODE_GPIO]),
        .tx_req_opcode_o(tx_req_opcode[`NODE_GPIO*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .tx_req_match_type_o(tx_req_match_type[`NODE_GPIO*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH]),
        .tx_req_source_id_o(tx_req_source_id[`NODE_GPIO*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .tx_req_target_id_o(tx_req_target_id[`NODE_GPIO*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .tx_req_addr_o(tx_req_addr[`NODE_GPIO*ADDR_WIDTH +: ADDR_WIDTH]),
        .tx_req_data_o(tx_req_data[`NODE_GPIO*DATA_WIDTH +: DATA_WIDTH]),

        .rx_req_valid_i(rx_req_valid[`NODE_GPIO]),
        .rx_req_is_order_i(rx_req_is_order[`NODE_GPIO]),
        .rx_req_opcode_i(rx_req_opcode[`NODE_GPIO*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .rx_req_match_type_i(rx_req_match_type[`NODE_GPIO*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH]),
        .rx_req_source_id_i(rx_req_source_id[`NODE_GPIO*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rx_req_target_id_i(rx_req_target_id[`NODE_GPIO*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rx_req_addr_i(rx_req_addr[`NODE_GPIO*ADDR_WIDTH +: ADDR_WIDTH]),
        .rx_req_data_i(rx_req_data[`NODE_GPIO*DATA_WIDTH +: DATA_WIDTH]),

        .rsp_valid_i(rsp_valid[`NODE_GPIO]),
        .rsp_source_id_i(rsp_source_id[`NODE_GPIO*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rsp_target_id_i(rsp_target_id[`NODE_GPIO*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rsp_addr_i(rsp_addr[`NODE_GPIO*ADDR_WIDTH +: ADDR_WIDTH]),
        .rsp_data_i(rsp_data[`NODE_GPIO*DATA_WIDTH +: DATA_WIDTH])
    );

    jtag_node #(
        .NUM_RINGS(NUM_RINGS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NODE_ID_WIDTH(NODE_ID_WIDTH),
        .NODE_ID(`NODE_JTAG),
        .OPCODE_WIDTH(OPCODE_WIDTH),
        .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH)
    ) u_jtag_ring_node (
        .clk(clk),
        .rst_n(rst_n),

        .jtag_tck_o(jtag_tck_o),
        .jtag_tms_o(jtag_tms_o),
        .jtag_tdi_o(jtag_tdi_o),
        .jtag_tdo_i(jtag_tdo_i),
        .jtag_tdo_en_i(jtag_tdo_en_i),
        .jtag_req_o(jtag_req_o),
        .jtag_we_o(jtag_we_o),
        .jtag_addr_o(jtag_addr_o),
        .jtag_data_in_o(jtag_data_in_o),
        .jtag_data_out_i(jtag_data_out_i),
        .jtag_ack_i(jtag_ack_i),
        .jtag_debug_data_i(jtag_debug_data_i),
        .jtag_debug_valid_i(jtag_debug_valid_i),

        .tx_req_ring_mask_o(tx_req_ring_mask[`NODE_JTAG*NUM_RINGS +: NUM_RINGS]),
        .tx_req_ring_disable_o(tx_req_ring_disable[`NODE_JTAG*NUM_RINGS +: NUM_RINGS]),
        .tx_req_valid_o(tx_req_valid[`NODE_JTAG]),
        .tx_req_is_order_o(tx_req_is_order[`NODE_JTAG]),
        .tx_req_opcode_o(tx_req_opcode[`NODE_JTAG*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .tx_req_match_type_o(tx_req_match_type[`NODE_JTAG*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH]),
        .tx_req_source_id_o(tx_req_source_id[`NODE_JTAG*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .tx_req_target_id_o(tx_req_target_id[`NODE_JTAG*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .tx_req_addr_o(tx_req_addr[`NODE_JTAG*ADDR_WIDTH +: ADDR_WIDTH]),
        .tx_req_data_o(tx_req_data[`NODE_JTAG*DATA_WIDTH +: DATA_WIDTH]),

        .rx_req_valid_i(rx_req_valid[`NODE_JTAG]),
        .rx_req_is_order_i(rx_req_is_order[`NODE_JTAG]),
        .rx_req_opcode_i(rx_req_opcode[`NODE_JTAG*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .rx_req_match_type_i(rx_req_match_type[`NODE_JTAG*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH]),
        .rx_req_source_id_i(rx_req_source_id[`NODE_JTAG*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rx_req_target_id_i(rx_req_target_id[`NODE_JTAG*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rx_req_addr_i(rx_req_addr[`NODE_JTAG*ADDR_WIDTH +: ADDR_WIDTH]),
        .rx_req_data_i(rx_req_data[`NODE_JTAG*DATA_WIDTH +: DATA_WIDTH]),

        .rsp_valid_i(rsp_valid[`NODE_JTAG]),
        .rsp_source_id_i(rsp_source_id[`NODE_JTAG*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rsp_target_id_i(rsp_target_id[`NODE_JTAG*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rsp_addr_i(rsp_addr[`NODE_JTAG*ADDR_WIDTH +: ADDR_WIDTH]),
        .rsp_data_i(rsp_data[`NODE_JTAG*DATA_WIDTH +: DATA_WIDTH])
    );

    // Instantiate SPI module
    spi_ring_node #(
        .NUM_RINGS(NUM_RINGS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NODE_ID_WIDTH(NODE_ID_WIDTH),
        .NODE_ID(`NODE_SPI),
        .OPCODE_WIDTH(OPCODE_WIDTH),
        .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH),
        .SPI_CS_NUM(SPI_CS_NUM),
        .TX_FIFO_DEPTH(TX_FIFO_DEPTH),
        .RX_FIFO_DEPTH(RX_FIFO_DEPTH),
        .RSP_FIFO_DEPTH(RSP_FIFO_DEPTH)
    ) u_spi_ring_node (
        .clk(clk),
        .rst_n(rst_n),

        .spi_req_o(spi_req_o),
        .spi_we_o(spi_we_o),
        .spi_addr_o(spi_addr_o),
        .spi_data_in_o(spi_data_in_o),
        .spi_data_out_i(spi_data_out_i),
        .spi_ack_i(spi_ack_i),
        .spi_cs_n_i(spi_cs_n_i),
        .spi_clk_i(spi_clk_i),
        .spi_mosi_i(spi_mosi_i),
        .spi_miso_o(spi_miso_o),

        .tx_req_ring_mask_o(tx_req_ring_mask[`NODE_SPI*NUM_RINGS +: NUM_RINGS]),
        .tx_req_ring_disable_o(tx_req_ring_disable[`NODE_SPI*NUM_RINGS +: NUM_RINGS]),
        .tx_req_valid_o(tx_req_valid[`NODE_SPI]),
        .tx_req_is_order_o(tx_req_is_order[`NODE_SPI]),
        .tx_req_opcode_o(tx_req_opcode[`NODE_SPI*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .tx_req_match_type_o(tx_req_match_type[`NODE_SPI*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH]),
        .tx_req_source_id_o(tx_req_source_id[`NODE_SPI*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .tx_req_target_id_o(tx_req_target_id[`NODE_SPI*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .tx_req_addr_o(tx_req_addr[`NODE_SPI*ADDR_WIDTH +: ADDR_WIDTH]),
        .tx_req_data_o(tx_req_data[`NODE_SPI*DATA_WIDTH +: DATA_WIDTH]),

        .rx_req_valid_i(rx_req_valid[`NODE_SPI]),
        .rx_req_is_order_i(rx_req_is_order[`NODE_SPI]),
        .rx_req_opcode_i(rx_req_opcode[`NODE_SPI*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .rx_req_match_type_i(rx_req_match_type[`NODE_SPI*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH]),
        .rx_req_source_id_i(rx_req_source_id[`NODE_SPI*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rx_req_target_id_i(rx_req_target_id[`NODE_SPI*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rx_req_addr_i(rx_req_addr[`NODE_SPI*ADDR_WIDTH +: ADDR_WIDTH]),
        .rx_req_data_i(rx_req_data[`NODE_SPI*DATA_WIDTH +: DATA_WIDTH]),

        .rsp_valid_i(rsp_valid[`NODE_SPI]),
        .rsp_source_id_i(rsp_source_id[`NODE_SPI*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rsp_target_id_i(rsp_target_id[`NODE_SPI*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rsp_addr_i(rsp_addr[`NODE_SPI*ADDR_WIDTH +: ADDR_WIDTH]),
        .rsp_data_i(rsp_data[`NODE_SPI*DATA_WIDTH +: DATA_WIDTH])
    );

    // Instantiate UART module
    uart_node #(
        .NUM_RINGS(NUM_RINGS),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NODE_ID_WIDTH(NODE_ID_WIDTH),
        .NODE_ID(`NODE_UART),
        .OPCODE_WIDTH(OPCODE_WIDTH),
        .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH)
    ) u_uart_ring_node (
        .clk(clk),
        .rst_n(rst_n),

        .req_o(uart_req_o),
        .we_o(uart_we_o),
        .addr_o(uart_addr_o),
        .data_in_o(uart_data_in_o),
        .data_out_i(uart_data_out_i),
        .ack_i(uart_ack_i),
        .txd_i(uart_txd_i),
        .rxd_o(uart_rxd_o),
        .rts_i(uart_rts_i),
        .cts_o(uart_cts_o),
        .int_i(uart_int_i),

        .tx_req_ring_mask_o(tx_req_ring_mask[`NODE_UART*NUM_RINGS +: NUM_RINGS]),
        .tx_req_ring_disable_o(tx_req_ring_disable[`NODE_UART*NUM_RINGS +: NUM_RINGS]),
        .tx_req_valid_o(tx_req_valid[`NODE_UART]),
        .tx_req_is_order_o(tx_req_is_order[`NODE_UART]),
        .tx_req_opcode_o(tx_req_opcode[`NODE_UART*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .tx_req_match_type_o(tx_req_match_type[`NODE_UART*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH]),
        .tx_req_source_id_o(tx_req_source_id[`NODE_UART*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .tx_req_target_id_o(tx_req_target_id[`NODE_UART*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .tx_req_addr_o(tx_req_addr[`NODE_UART*ADDR_WIDTH +: ADDR_WIDTH]),
        .tx_req_data_o(tx_req_data[`NODE_UART*DATA_WIDTH +: DATA_WIDTH]),

        .rx_req_valid_i(rx_req_valid[`NODE_UART]),
        .rx_req_is_order_i(rx_req_is_order[`NODE_UART]),
        .rx_req_opcode_i(rx_req_opcode[`NODE_UART*OPCODE_WIDTH +: OPCODE_WIDTH]),
        .rx_req_match_type_i(rx_req_match_type[`NODE_UART*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH]),
        .rx_req_source_id_i(rx_req_source_id[`NODE_UART*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rx_req_target_id_i(rx_req_target_id[`NODE_UART*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rx_req_addr_i(rx_req_addr[`NODE_UART*ADDR_WIDTH +: ADDR_WIDTH]),
        .rx_req_data_i(rx_req_data[`NODE_UART*DATA_WIDTH +: DATA_WIDTH]),

        .rsp_valid_i(rsp_valid[`NODE_UART]),
        .rsp_source_id_i(rsp_source_id[`NODE_UART*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rsp_target_id_i(rsp_target_id[`NODE_UART*NODE_ID_WIDTH +: NODE_ID_WIDTH]),
        .rsp_addr_i(rsp_addr[`NODE_UART*ADDR_WIDTH +: ADDR_WIDTH]),
        .rsp_data_i(rsp_data[`NODE_UART*DATA_WIDTH +: DATA_WIDTH])
    );
endmodule