
// This is the bus top module

`include "top_system_params.v"

module bus_top #(
    parameter BUS_TYPE         = `BUS_TYPE_RING, // 总线类型：`BUS_TYPE_RING 或 `BUS_TYPE_DIRECT
    parameter NUM_RINGS        = 2,        // Ring总线数量 (当BUS_TYPE为`BUS_TYPE_RING时有效)
    parameter NUM_NODES        = 4,        // 每个Ring的节点数 (当BUS_TYPE为`BUS_TYPE_RING时有效)
    parameter ADDR_WIDTH       = 32,       // 地址宽度
    parameter DATA_WIDTH       = 64,       // 数据宽度
    parameter OPCODE_WIDTH     = 8,        // 操作类型的宽带：read/write/reponse等
    parameter RING_ID_WIDTH    = 4,        // ring ID宽度
    parameter NODE_ID_WIDTH    = 8,        // 节点ID宽度
    parameter TX_FIFO_DEPTH    = 4,        // 发送FIFO深度
    parameter RX_FIFO_DEPTH    = 4,        // 接收FIFO深度
    parameter RSP_FIFO_DEPTH   = 4,        // 响应FIFO深度
    parameter NUM_CORES        = 4,
    parameter GPIO_WIDTH       = 32,
    parameter SPI_CS_NUM       = 1,
    parameter NUM_PES          = 4,
    parameter PE_ARRAY_ROWS    = 2,
    parameter PE_ARRAY_COLS    = 2,
    parameter INST_WIDTH       = 32,
    parameter PE_ID_WIDTH      = 4,
    parameter MATCH_TYPE_WIDTH = 2         // 匹配类型宽度
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

    // JTAG接口
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
    input  reg  [SPI_CS_NUM-1:0]                 spi_cs_n_i,
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
    // 内部信号定义
    wire                                          req_valid;
    wire [ADDR_WIDTH-1:0]                         req_addr;
    wire [MATCH_TYPE_WIDTH-1:0]                   req_match_type;
    wire [NODE_ID_WIDTH-1:0]                      req_target_id;
    wire [DATA_WIDTH-1:0]                         req_data;
    wire [NUM_RINGS-1:0]                          req_ring_mask;
    wire [NUM_RINGS-1:0]                          req_ring_disable;
    wire                                          req_ready;

    wire [NUM_RINGS-1:0]                          ring_req_valid;
    wire [NUM_RINGS-1:0]                          ring_req_ready;
    wire [NUM_RINGS*ADDR_WIDTH-1:0]               ring_req_addr;
    wire [NUM_RINGS*MATCH_TYPE_WIDTH-1:0]         ring_req_match_type;
    wire [NUM_RINGS*NODE_ID_WIDTH-1:0]            ring_req_target_id;
    wire [NUM_RINGS*DATA_WIDTH-1:0]               ring_req_data;

    wire                                          cpu_req;
    wire [ADDR_WIDTH-1:0]                         cpu_addr;
    wire [DATA_WIDTH-1:0]                         cpu_wdata;
    wire [DATA_WIDTH-1:0]                         cpu_rdata;
    wire                                          cpu_we;
    wire [7:0]                                    cpu_byte_en;
    wire                                          cpu_ready;

    wire [ADDR_WIDTH-1:0]                         sys_addr;
    wire [DATA_WIDTH-1:0]                         sys_wdata;
    wire [DATA_WIDTH-1:0]                         sys_rdata;
    wire                                          sys_we;
    wire [7:0]                                    sys_byte_en;
    wire                                          sys_req;
    wire                                          sys_ready;
    wire [1:0]                                    sys_master_id;

    wire                                          flash_req;
    wire [ADDR_WIDTH-1:0]                         flash_addr;
    wire [DATA_WIDTH-1:0]                         flash_wdata;
    wire [DATA_WIDTH-1:0]                         flash_rdata;
    wire                                          flash_we;
    wire                                          flash_ready;

    wire                                          sram_req;
    wire [ADDR_WIDTH-1:0]                         sram_addr;
    wire [DATA_WIDTH-1:0]                         sram_wdata;
    wire [DATA_WIDTH-1:0]                         sram_rdata;
    wire                                          sram_we;
    wire                                          sram_ready;

    wire                                          mmio_req;
    wire [ADDR_WIDTH-1:0]                         mmio_addr;
    wire [DATA_WIDTH-1:0]                         mmio_wdata;
    wire [DATA_WIDTH-1:0]                         mmio_rdata;
    wire                                          mmio_we;
    wire [7:0]                                    mmio_byte_en;
    wire                                          mmio_ready;

    // 扩展总线接口信号
    wire [ADDR_WIDTH-1:0]                         ext_bus_addr;
    wire [DATA_WIDTH-1:0]                         ext_bus_wdata;
    wire [DATA_WIDTH-1:0]                         ext_bus_rdata;
    wire                                          ext_bus_we;
    wire [7:0]                                    ext_bus_byte_en;
    wire                                          ext_bus_req;
    wire                                          ext_bus_ready;
    wire [OPCODE_WIDTH-1:0]                       ext_bus_opcode;
    // 根据总线类型选择实例化方式
    generate
        if (BUS_TYPE == `BUS_TYPE_RING) begin : ring_bus_instance
            // Ring总线模式
            ring_bus_top #(
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
            ) u_ring_bus (
                .clk(clk),
                .rst_n(rst_n),

                .node_start_addr_i(node_start_addr_i),
                .node_end_addr_i(node_end_addr_i),

                // CPU
                .cpu_ext_int_o(cpu_ext_int_o),
                .cpu_mem_req_i(cpu_mem_req_i),
                .cpu_mem_addr_i(cpu_mem_addr_i),
                .cpu_mem_wdata_i(cpu_mem_wdata_i),
                .cpu_mem_we_i(cpu_mem_we_i),
                .cpu_mem_ready_o(cpu_mem_ready_o),
                .cpu_mem_rdata_o(cpu_mem_rdata_o),

                // PE
                .pe_enable_o(pe_enable_o),
                .pe_reset_o(pe_reset_o),
                .pe_instructions_o(pe_instructions_o),
                .pe_inst_valid_o(pe_inst_valid_o),
                .pe_status_i(pe_status_i),
                .pe_outputs_i(pe_outputs_i),
                .pe_busy_i(pe_busy_i),
                .pe_route_config_o(pe_route_config_o),
                .pe_route_cfg_valid_o(pe_route_cfg_valid_o),

                // GPIO
                .gpio_req_o(gpio_req_o),
                .gpio_we_o(gpio_we_o),
                .gpio_addr_o(gpio_addr_o),
                .gpio_data_in_o(gpio_data_in_o),
                .gpio_data_out_i(gpio_data_out_i),
                .gpio_ack_i(gpio_ack_i),
                .gpio_pins(gpio_pins),
                .gpio_int_i(gpio_int_i),

                // JTAG接口
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

                // SPI
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

                // UART
                .uart_req_o(uart_req_o),
                .uart_we_o(uart_we_o),
                .uart_addr_o(uart_addr_o),
                .uart_data_in_o(uart_data_in_o),
                .uart_data_out_i(uart_data_out_i),
                .uart_ack_i(uart_ack_i),
                .uart_txd_i(uart_txd_i),
                .uart_rxd_o(uart_rxd_o),
                .uart_rts_i(uart_rts_i),
                .uart_cts_o(uart_cts_o),
                .uart_int_i(uart_int_i)
            );
        end else if (BUS_TYPE == `BUS_TYPE_DIRECT) begin : direct_bus
            direct_bus_top #(
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
            ) u_direct_bus (
                .clk(clk),
                .rst_n(rst_n),

                .node_start_addr_i(node_start_addr_i),
                .node_end_addr_i(node_end_addr_i),

                // CPU
                .cpu_ext_int_o(cpu_ext_int_o),
                .cpu_mem_req_i(cpu_mem_req_i),
                .cpu_mem_addr_i(cpu_mem_addr_i),
                .cpu_mem_wdata_i(cpu_mem_wdata_i),
                .cpu_mem_we_i(cpu_mem_we_i),
                .cpu_mem_ready_o(cpu_mem_ready_o),
                .cpu_mem_rdata_o(cpu_mem_rdata_o),

                // PE
                .pe_enable_o(pe_enable_o),
                .pe_reset_o(pe_reset_o),
                .pe_instructions_o(pe_instructions_o),
                .pe_inst_valid_o(pe_inst_valid_o),
                .pe_status_i(pe_status_i),
                .pe_outputs_i(pe_outputs_i),
                .pe_busy_i(pe_busy_i),
                .pe_route_config_o(pe_route_config_o),
                .pe_route_cfg_valid_o(pe_route_cfg_valid_o),

                // GPIO
                .gpio_req_o(gpio_req_o),
                .gpio_we_o(gpio_we_o),
                .gpio_addr_o(gpio_addr_o),
                .gpio_data_in_o(gpio_data_in_o),
                .gpio_data_out_i(gpio_data_out_i),
                .gpio_ack_i(gpio_ack_i),
                .gpio_pins(gpio_pins),
                .gpio_int_i(gpio_int_i),

                // JTAG接口
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

                // SPI
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

                // UART
                .uart_req_o(uart_req_o),
                .uart_we_o(uart_we_o),
                .uart_addr_o(uart_addr_o),
                .uart_data_in_o(uart_data_in_o),
                .uart_data_out_i(uart_data_out_i),
                .uart_ack_i(uart_ack_i),
                .uart_txd_i(uart_txd_i),
                .uart_rxd_o(uart_rxd_o),
                .uart_rts_i(uart_rts_i),
                .uart_cts_o(uart_cts_o),
                .uart_int_i(uart_int_i)
            );
        end
    endgenerate
endmodule