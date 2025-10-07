`include "top_system_params.v"

module direct_bus_top #(
    parameter NUM_RINGS        = 2,
    parameter NUM_NODES        = 4,
    parameter ADDR_WIDTH       = 32,
    parameter DATA_WIDTH       = 64,
    parameter OPCODE_WIDTH     = 8,
    parameter RING_ID_WIDTH    = 4,
    parameter NODE_ID_WIDTH    = 8,
    parameter TX_FIFO_DEPTH    = 4,
    parameter RX_FIFO_DEPTH    = 4,
    parameter RSP_FIFO_DEPTH   = 4,
    parameter NUM_CORES        = 4,
    parameter GPIO_WIDTH       = 32,
    parameter MATCH_TYPE_WIDTH = 2
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
    input  reg                                    spi_cs_n_i,
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
    // wire [ADDR_WIDTH-1:0]                          sys_addr; // 从bus_top传递的地址
    wire [DATA_WIDTH-1:0]                         sys_wdata; // 从bus_top传递的写数据
    wire [DATA_WIDTH-1:0]                         sys_rdata; // 返回给bus_top的读数据
    wire                                          sys_we; // 写使能信号
    wire [7:0]                                    sys_byte_en; // 字节使能信号
    wire                                          sys_req; // 请求有效信号
    wire                                          sys_ready; // 响应就绪信号
    reg [2:0] state;
    reg [ADDR_WIDTH-1:0] saved_addr;
    reg [DATA_WIDTH-1:0] saved_wdata;
    reg saved_we;
    reg [7:0] saved_byte_en;
    reg [NODE_ID_WIDTH-1:0] target_device;

    // 内部信号定义
    wire [ADDR_WIDTH-1:0] effective_addr; // 实际使用的地址
    wire [DATA_WIDTH-1:0] cpu_rdata; // CPU读取的数据
    reg cpu_ready; // CPU请求就绪信号

    // 状态机定义
    localparam STATE_IDLE = 3'b000;
    localparam STATE_DECODE = 3'b001;
    localparam STATE_ACCESS = 3'b010;
    localparam STATE_RESPONSE = 3'b011;

    // 地址范围解码
    always @(*) begin
        if (cpu_mem_addr_i >= `GPIO_BASE && cpu_mem_addr_i <= `GPIO_END) begin
            target_device = `NODE_GPIO;
        end else if (cpu_mem_addr_i >= `UART_BASE && cpu_mem_addr_i <= `UART_END) begin
            target_device = `NODE_UART;
        end else if (cpu_mem_addr_i >= `FABRIC_BASE && cpu_mem_addr_i <= `FABRIC_END) begin
            target_device = `NODE_PE;
        end else if (cpu_mem_addr_i >= `RAM_BASE && cpu_mem_addr_i <= `RAM_END) begin
            target_device = `NODE_RAM;
        end else if (cpu_mem_addr_i >= `ROM_BASE && cpu_mem_addr_i <= `ROM_END) begin
            target_device = `NODE_ROM;
        end else begin
            target_device = {NODE_ID_WIDTH{1'b1}}; // 未定义地址
        end
    end

    // 计算有效地址（去除基地址）
    assign effective_addr = cpu_mem_addr_i - (
        target_device == `NODE_GPIO ? `GPIO_BASE :
        target_device == `NODE_UART ? `UART_BASE :
        target_device == `NODE_PE ? `FABRIC_BASE :
        target_device == `NODE_RAM ? `RAM_BASE :
        target_device == `NODE_ROM ? `ROM_BASE : 0
    );

    // 状态机实现
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            cpu_ready <= 1'b0;
            uart_req_o <= 1'b0;
            gpio_req_o <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    cpu_ready <= 1'b0;
                    uart_req_o <= 1'b0;
                    gpio_req_o <= 1'b0;

                    if (cpu_mem_req_i) begin
                        state <= STATE_DECODE;
                        saved_addr <= effective_addr;
                        saved_wdata <= cpu_mem_wdata_i;
                        saved_we <= cpu_mem_we_i;
                    end
                end

                STATE_DECODE: begin
                    case (target_device)
                        `NODE_UART: begin // UART模块
                            uart_req_o <= 1'b1;
                            uart_we_o <= saved_we;
                            uart_addr_o <= saved_addr;
                            uart_data_in_o <= saved_wdata;
                            state <= STATE_ACCESS;
                        end
                        `NODE_GPIO: begin // GPIO模块
                            gpio_req_o <= 1'b1;
                            gpio_we_o <= saved_we;
                            gpio_addr_o <= saved_addr;
                            gpio_data_in_o <= saved_wdata;
                            state <= STATE_ACCESS;
                        end
                        `NODE_PE: begin // PE阵列
                            // 处理PE控制请求
                            // 这里假设已经有相关逻辑处理PE控制
                            cpu_ready <= 1'b1;
                            state <= STATE_IDLE;
                        end
                        default: begin // 未定义地址或其他模块
                            cpu_ready <= 1'b1; // 立即返回，读操作返回0，写操作忽略
                            state <= STATE_IDLE;
                        end
                    endcase
                end

                STATE_ACCESS: begin
                    case (target_device)
                        `NODE_UART: begin
                            if (uart_ack_i) begin
                                cpu_ready <= 1'b1;
                                uart_req_o <= 1'b0;
                                state <= STATE_IDLE;
                            end
                        end
                        `NODE_GPIO: begin
                            if (gpio_ack_i) begin
                                cpu_ready <= 1'b1;
                                gpio_req_o <= 1'b0;
                                state <= STATE_IDLE;
                            end
                        end
                        default: begin
                            state <= STATE_IDLE;
                        end
                    endcase
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

    // 连接CPU接口
    assign cpu_mem_ready_o = cpu_ready;
    assign cpu_mem_rdata_o = (
        target_device == `NODE_UART ? uart_data_out_i :
        target_device == `NODE_GPIO ? gpio_data_out_i :
        0
    );

    // 其他接口连接
    assign cpu_ext_int_o = uart_int_i || gpio_int_i;

    // 初始化输出信号
    initial begin
        pe_enable_o = 0;
        pe_reset_o = 0;
        pe_inst_valid_o = 0;
        pe_route_cfg_valid_o = 0;
    end

endmodule