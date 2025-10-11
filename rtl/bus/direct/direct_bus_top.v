`include "top_system_params.v"

module direct_bus_top #(
    parameter NUM_RINGS                           = 2,
    parameter NUM_NODES                           = 4,
    parameter ADDR_WIDTH                          = 32,
    parameter DATA_WIDTH                          = 64,
    parameter OPCODE_WIDTH                        = 8,
    parameter RING_ID_WIDTH                       = 4,
    parameter NODE_ID_WIDTH                       = 8,
    parameter TX_FIFO_DEPTH                       = 4,
    parameter RX_FIFO_DEPTH                       = 4,
    parameter RSP_FIFO_DEPTH                      = 4,
    parameter NUM_CORES                           = 4,
    parameter GPIO_WIDTH                          = 32,
    parameter SPI_CS_NUM                          = 1,
    parameter MATCH_TYPE_WIDTH                    = 2,
    parameter NUM_PES                             = 4,
    parameter PE_ARRAY_ROWS                       = 2,
    parameter PE_ARRAY_COLS                       = 2,
    parameter INST_WIDTH                          = 32,
    parameter PE_ID_WIDTH                         = 4
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
    output reg                                    gpio_req_o,
    output reg                                    gpio_we_o,
    output reg  [ADDR_WIDTH-1:0]                  gpio_addr_o,
    output reg  [DATA_WIDTH-1:0]                  gpio_data_in_o,
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
    output reg                                    jtag_req_o,
    output reg                                    jtag_we_o,
    output reg  [ADDR_WIDTH-1:0]                  jtag_addr_o,
    output reg  [DATA_WIDTH-1:0]                  jtag_data_in_o,
    input  reg  [DATA_WIDTH-1:0]                  jtag_data_out_i,
    input  reg                                    jtag_ack_i,
    input  reg  [DATA_WIDTH-1:0]                  jtag_debug_data_i,
    input  reg                                    jtag_debug_valid_i,

    // SPI
    output reg                                    spi_req_o,
    output reg                                    spi_we_o,
    output reg  [ADDR_WIDTH-1:0]                  spi_addr_o,
    output reg  [DATA_WIDTH-1:0]                  spi_data_in_o,
    input  reg  [DATA_WIDTH-1:0]                  spi_data_out_i,
    input  reg                                    spi_ack_i,
    input  reg  [SPI_CS_NUM-1:0]                  spi_cs_n_i,
    input  reg                                    spi_clk_i,
    input  reg                                    spi_mosi_i,
    output wire                                   spi_miso_o,

    // UART
    output reg                                    uart_req_o,
    output reg                                    uart_we_o,
    output reg  [ADDR_WIDTH-1:0]                  uart_addr_o,
    output reg  [DATA_WIDTH-1:0]                  uart_data_in_o,
    input  reg  [DATA_WIDTH-1:0]                  uart_data_out_i,
    input  reg                                    uart_ack_i,
    input  reg                                    uart_txd_i,
    output                                        uart_rxd_o,
    input  reg                                    uart_rts_i,
    output                                        uart_cts_o,
    input  reg                                    uart_int_i
);

    // Internal signal definition
    // wire [ADDR_WIDTH-1:0]                          sys_addr; // Address passed from bus_top
    wire [DATA_WIDTH-1:0]                         sys_wdata; // Write data passed from bus_top
    wire [DATA_WIDTH-1:0]                         sys_rdata; // Read data returned to bus_top
    wire                                          sys_we; // Write enable signal
    wire [7:0]                                    sys_byte_en; // Byte enable signals
    wire                                          sys_req; // Request valid signal
    wire                                          sys_ready; // Response ready signal
    reg  [2:0]                                    state;
    reg  [ADDR_WIDTH-1:0]                         saved_addr;
    reg  [DATA_WIDTH-1:0]                         saved_wdata;
    reg                                           saved_we;
    reg  [7:0]                                    saved_byte_en;
    reg  [NODE_ID_WIDTH-1:0]                      target_device;

    // Internal signal definition
    wire [ADDR_WIDTH-1:0]                         effective_addr; // Effective address used
    wire [DATA_WIDTH-1:0]                         cpu_rdata; // Data read by CPU
    reg                                           cpu_ready; // CPU request ready signal

    // State machine definition
    localparam STATE_IDLE         = 3'b000;
    localparam STATE_DECODE       = 3'b001;
    localparam STATE_ACCESS       = 3'b010;
    localparam STATE_RESPONSE     = 3'b011;

    // Address range decoding
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
        end else if (cpu_mem_addr_i >= `JTAG_BASE && cpu_mem_addr_i <= `JTAG_END) begin
            target_device = `NODE_JTAG;
        end else if (cpu_mem_addr_i >= `SPI_BASE && cpu_mem_addr_i <= `SPI_END) begin
            target_device = `NODE_SPI;
        end else begin
            target_device = {NODE_ID_WIDTH{1'b1}}; // Undefined address
        end
    end

    // Calculate effective address (remove base address)
    assign effective_addr = cpu_mem_addr_i - (
        target_device == `NODE_GPIO ? `GPIO_BASE :
        target_device == `NODE_UART ? `UART_BASE :
        target_device == `NODE_PE ? `FABRIC_BASE :
        target_device == `NODE_RAM ? `RAM_BASE :
        target_device == `NODE_ROM ? `ROM_BASE :
        target_device == `NODE_JTAG ? `JTAG_BASE :
        target_device == `NODE_SPI ? `SPI_BASE : 0
    );

    // State machine implementation
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
                        `NODE_UART: begin // UART module
                            uart_req_o <= 1'b1;
                            uart_we_o <= saved_we;
                            uart_addr_o <= saved_addr;
                            uart_data_in_o <= saved_wdata;
                            state <= STATE_ACCESS;
                        end
                        `NODE_GPIO: begin // GPIO module
                            gpio_req_o <= 1'b1;
                            gpio_we_o <= saved_we;
                            gpio_addr_o <= saved_addr;
                            gpio_data_in_o <= saved_wdata;
                            state <= STATE_ACCESS;
                        end
                        `NODE_PE: begin // PE array
                            // Handle PE control requests
                            // Assuming relevant logic for PE control already exists
                            cpu_ready <= 1'b1;
                            state <= STATE_IDLE;
                        end
                        `NODE_JTAG: begin // JTAG module
                            jtag_req_o <= 1'b1;
                            jtag_we_o <= saved_we;
                            jtag_addr_o <= saved_addr;
                            jtag_data_in_o <= saved_wdata;
                            state <= STATE_ACCESS;
                        end
                        `NODE_SPI: begin // SPI module
                            spi_req_o <= 1'b1;
                            spi_we_o <= saved_we;
                            spi_addr_o <= saved_addr;
                            spi_data_in_o <= saved_wdata;
                            state <= STATE_ACCESS;
                        end
                        default: begin // Undefined address or other modules
                            cpu_ready <= 1'b1; // Return immediately, read returns 0, write is ignored
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
                        `NODE_JTAG: begin
                            if (jtag_ack_i) begin
                                cpu_ready <= 1'b1;
                                jtag_req_o <= 1'b0;
                                state <= STATE_IDLE;
                            end
                        end
                        `NODE_SPI: begin
                            if (spi_ack_i) begin
                                cpu_ready <= 1'b1;
                                spi_req_o <= 1'b0;
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

    // Connect CPU interface
    assign cpu_mem_ready_o = cpu_ready;
    assign cpu_mem_rdata_o = (
        target_device == `NODE_UART ? uart_data_out_i :
        target_device == `NODE_GPIO ? gpio_data_out_i :
        target_device == `NODE_JTAG ? jtag_data_out_i :
        target_device == `NODE_SPI ? spi_data_out_i :
        0
    );

    // Other interface connections
    assign cpu_ext_int_o = uart_int_i || gpio_int_i;

    // Initialize output signals
    initial begin
        pe_enable_o = 0;
        pe_reset_o = 0;
        pe_inst_valid_o = 0;
        pe_route_cfg_valid_o = 0;
    end

endmodule