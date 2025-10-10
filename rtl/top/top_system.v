// top_system.v
// 顶层系统模块，集成所有组件

`include "top_system_params.v"

module top_system #(
    parameter BUS_TYPE         = `BUS_TYPE_DIRECT, // 总线类型：`BUS_TYPE_RING 或 `BUS_TYPE_DIRECT
    parameter NUM_RINGS        = 2,        // Ring总线数量
    parameter NUM_NODES        = 8,        // 每个Ring的节点数
    parameter ADDR_WIDTH       = 32,       // 地址宽度
    parameter DATA_WIDTH       = 64,       // 数据宽度
    parameter OPCODE_WIDTH     = 8,        // 操作类型的宽带：read/write/reponse等
    parameter RING_ID_WIDTH    = 4,        // ring ID宽度
    parameter NODE_ID_WIDTH    = 8,        // 节点ID宽度
    parameter TX_FIFO_DEPTH    = 4,        // 发送FIFO深度
    parameter RX_FIFO_DEPTH    = 4,        // 接收FIFO深度
    parameter RSP_FIFO_DEPTH   = 4,        // 响应FIFO深度
    parameter NUM_CORES        = 1,
    parameter MATCH_TYPE_WIDTH = 2,        // 匹配类型宽度
    parameter INST_WIDTH       = 32,      // 指令宽度
    parameter CORE_ID_WIDTH    = 2,        // 核心ID宽度
    parameter ENABLE_L2_CACHE  = 0,        // 启用L2缓存
    parameter ENABLE_L3_CACHE  = 0,        // 启用L3缓存
    parameter GPIO_WIDTH       = 32,
    parameter SPI_CS_NUM       = 1,
    parameter NUM_PES          = 4,
    parameter PE_ARRAY_ROWS    = 2,
    parameter PE_ARRAY_COLS    = 2,
    parameter PE_ID_WIDTH      = 4,
    parameter CPU_TYPE         = 0         // CPU类型
)(
    input clk,
    input rst_n,

    // UART接口
    output uart_txd,
    input uart_rxd,

    // GPIO接口
    inout [DATA_WIDTH-1:0] gpio_pins,

    // 外部中断
    input ext_int,

    // 状态输出
    output [DATA_WIDTH-1:0] system_status,

    // JTAG接口
    input jtag_tck,
    input jtag_tms,
    input jtag_tdi,
    output jtag_tdo,
    output jtag_tdo_en,

    // JTAG调试输出
    output [DATA_WIDTH-1:0] jtag_debug_data,
    output jtag_debug_valid,

    // SPI物理接口
    output [SPI_CS_NUM-1:0] spi_cs_n,
    output spi_clk,
    output spi_mosi,
    input spi_miso
);
    reg [NUM_NODES*ADDR_WIDTH-1:0]        node_start_addr;
    reg [NUM_NODES*ADDR_WIDTH-1:0]        node_end_addr;

    // CPU
    wire                                  cpu_mem_req;
    wire [ADDR_WIDTH-1:0]                 cpu_mem_addr;
    wire [511:0]                          cpu_mem_wdata;
    wire                                  cpu_mem_we;
    wire                                  cpu_mem_ready;
    wire [511:0]                          cpu_mem_rdata;

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
    wire                                  uart_int_out;

    // 实例化Ring总线
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
        .cpu_ext_int_o(ext_int),
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
        .jtag_tck_o(jtag_tck),
        .jtag_tms_o(jtag_tms),
        .jtag_tdi_o(jtag_tdi),
        .jtag_tdo_i(jtag_tdo),
        .jtag_tdo_en_i(jtag_tdo_en),
        .jtag_req_o(jtag_req),
        .jtag_we_o(jtag_we),
        .jtag_addr_o(jtag_addr),
        .jtag_data_in_o(jtag_data_in),
        .jtag_data_out_i(jtag_data_out),
        .jtag_ack_i(jtag_ack),
        .jtag_debug_data_i(jtag_debug_data),
        .jtag_debug_valid_i(jtag_debug_valid),

        // SPI
        .spi_req_o(spi_req),
        .spi_we_o(spi_we),
        .spi_addr_o(spi_addr),
        .spi_data_in_o(spi_data_in),
        .spi_data_out_i(spi_data_out),
        .spi_ack_i(spi_ack),
        .spi_cs_n_i(spi_cs_n),
        .spi_clk_i(spi_clk),
        .spi_mosi_i(spi_mosi),
        .spi_miso_o(spi_miso),

        // UART
        .uart_req_o(uart_req),
        .uart_we_o(uart_we),
        .uart_addr_o(uart_addr),
        .uart_data_in_o(uart_data_in),
        .uart_data_out_i(uart_data_out),
        .uart_ack_i(uart_ack),
        .uart_txd_i(uart_txd),
        .uart_rxd_o(uart_rxd),
        .uart_rts_i(uart_rts),
        .uart_cts_o(uart_cts),
        .uart_int_i(uart_int)
    );

    cpu_top #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .INST_WIDTH(INST_WIDTH),
        .NUM_CORES(NUM_CORES),
        .CORE_ID_WIDTH(CORE_ID_WIDTH),
        .ENABLE_L2_CACHE(ENABLE_L2_CACHE),
        .ENABLE_L3_CACHE(ENABLE_L3_CACHE),
        .CPU_TYPE(CPU_TYPE)
    ) cpu (
        .clk(clk),
        .rst_n(rst_n),

        .ext_int(ext_int),

        .mem_req(cpu_mem_req),
        .mem_addr(cpu_mem_addr),
        .mem_wdata(cpu_mem_wdata),
        .mem_we(cpu_mem_we),
        .mem_ready(cpu_mem_ready),
        .mem_rdata(cpu_mem_rdata)
    );

    // 实例化GPIO模块
    gpio_module #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .GPIO_WIDTH(GPIO_WIDTH)
    ) gpio (
        .clk(clk),
        .rst_n(rst_n),
        .req(gpio_req),
        .we(gpio_we),
        .addr(gpio_addr),
        .data_in(gpio_data_out),
        .data_out(gpio_data_in),
        .ack(gpio_ack),
        .gpio_pins(gpio_pins),
        .int_out(gpio_int)
    );

    // 实例化UART模块
    uart_core uart (
        .clk(clk),
        .rst_n(rst_n),

        .req(uart_req),
        .we(uart_we),
        .addr(uart_addr),
        .data_in(uart_data_in),
        .data_out(uart_data_out),
        .ack(uart_ack),
        .txd(uart_txd),
        .rxd(uart_rxd),
        .rts(uart_rts),
        .cts(uart_cts),
        .int_out(uart_int)
    );

    // 实例化JTAG
    jtag_top #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .INST_WIDTH(INST_WIDTH)
    ) jtag (
        .clk(clk),
        .rst_n(rst_n),

        .tck(jtag_tck),
        .tms(jtag_tms),
        .tdi(jtag_tdi),
        .tdo(jtag_tdo),
        .tdo_en(jtag_tdo_en),
        .req(jtag_req),
        .we(jtag_we),
        .addr(jtag_addr),
        .data_in(jtag_data_in),
        .data_out(jtag_data_out),
        .ack(jtag_ack),
        .debug_data(jtag_debug_data),
        .debug_valid(jtag_debug_valid)
    );

    reg [DATA_WIDTH-1:0] fabric_status;
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

        .pe_enable(pe_enable),
        .pe_reset(pe_reset),
        .pe_instructions(pe_instructions),
        .pe_inst_valid(pe_inst_valid),
        .pe_status(pe_status),
        .pe_outputs(pe_outputs),
        .pe_busy(pe_busy),
        .route_config(pe_route_config),
        .route_cfg_valid(pe_route_cfg_valid),

        .fabric_status(fabric_status)
    );

    // 实例化SPI核心控制器
    spi_core #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .CS_NUM(SPI_CS_NUM)
    ) spi (
        .clk(clk),
        .rst_n(rst_n),

        .req(spi_req),
        .we(spi_we),
        .addr(spi_addr),
        .data_in(spi_data_in),
        .data_out(spi_data_out),
        .ack(spi_ack),
        .spi_cs_n(spi_cs_n),
        .spi_clk(spi_clk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso)
    );

endmodule