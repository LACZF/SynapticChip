// Direct bus top module

`include "top_system_params.v"

module direct_bus_top #(
    parameter NUM_RINGS                           = 2,        // Number of Ring buses
    parameter NUM_NODES                           = 4,        // Number of nodes per Ring
    parameter ADDR_WIDTH                          = 64,       // Address width
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
    parameter NUM_PES                             = 4,
    parameter PE_ARRAY_ROWS                       = 2,
    parameter PE_ARRAY_COLS                       = 2,
    parameter INST_WIDTH                          = 32,
    parameter PE_ID_WIDTH                         = 4,
    parameter MATCH_TYPE_WIDTH                    = 2         // Match type width
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

    // Internal signal definitions
    wire [ADDR_WIDTH-1:0]                         sys_addr;
    wire [DATA_WIDTH-1:0]                         sys_wdata;
    wire [DATA_WIDTH-1:0]                         sys_rdata;
    wire                                          sys_we;
    wire [7:0]                                    sys_byte_en;
    wire                                          sys_req;
    wire                                          sys_ready;
    wire [1:0]                                    sys_master_id;

    // State machine definitions
    localparam                                    STATE_IDLE   = 2'b00;
    localparam                                    STATE_DECODE = 2'b01;
    localparam                                    STATE_ACCESS = 2'b10;
    localparam                                    STATE_RESP   = 2'b11;

    // State register
    reg [1:0]                                     state;
    reg [1:0]                                     next_state;

    // Decode signals
    reg                                           cpu_request_valid;
    reg [ADDR_WIDTH-1:0]                          cpu_request_addr;
    reg [DATA_WIDTH-1:0]                          cpu_request_wdata;
    reg                                           cpu_request_we;
    reg [7:0]                                     cpu_request_byte_en;

    // GPIO signals
    reg                                           gpio_request_valid;
    reg [ADDR_WIDTH-1:0]                          gpio_request_addr;
    reg [DATA_WIDTH-1:0]                          gpio_request_wdata;
    reg                                           gpio_request_we;

    // UART signals
    reg                                           uart_request_valid;
    reg [ADDR_WIDTH-1:0]                          uart_request_addr;
    reg [DATA_WIDTH-1:0]                          uart_request_wdata;
    reg                                           uart_request_we;

    // PE signals
    reg                                           pe_request_valid;
    reg [ADDR_WIDTH-1:0]                          pe_request_addr;
    reg [DATA_WIDTH-1:0]                          pe_request_wdata;
    reg                                           pe_request_we;

    // JTAG signals
    reg                                           jtag_request_valid;
    reg [ADDR_WIDTH-1:0]                          jtag_request_addr;
    reg [DATA_WIDTH-1:0]                          jtag_request_wdata;
    reg                                           jtag_request_we;

    // SPI signals
    reg                                           spi_request_valid;
    reg [ADDR_WIDTH-1:0]                          spi_request_addr;
    reg [DATA_WIDTH-1:0]                          spi_request_wdata;
    reg                                           spi_request_we;

    // Address range definitions
    localparam                                    GPIO_ADDR_START   = 32'h0000_1000;
    localparam                                    GPIO_ADDR_END     = 32'h0000_1FFF;
    localparam                                    UART_ADDR_START   = 32'h0000_2000;
    localparam                                    UART_ADDR_END     = 32'h0000_2FFF;
    localparam                                    PE_ADDR_START     = 32'h0000_3000;
    localparam                                    PE_ADDR_END       = 32'h0000_3FFF;
    localparam                                    JTAG_ADDR_START   = 32'h0000_4000;
    localparam                                    JTAG_ADDR_END     = 32'h0000_4FFF;
    localparam                                    SPI_ADDR_START    = 32'h0000_5000;
    localparam                                    SPI_ADDR_END      = 32'h0000_5FFF;

    // Address decode logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpio_request_valid <= 1'b0;
            uart_request_valid <= 1'b0;
            pe_request_valid <= 1'b0;
            jtag_request_valid <= 1'b0;
            spi_request_valid <= 1'b0;
        end else if (state == STATE_DECODE && cpu_request_valid) begin
            // Decode address range
            if (cpu_request_addr >= GPIO_ADDR_START && cpu_request_addr <= GPIO_ADDR_END) begin
                gpio_request_valid <= 1'b1;
                gpio_request_addr <= cpu_request_addr;
                gpio_request_wdata <= cpu_request_wdata;
                gpio_request_we <= cpu_request_we;
            end else if (cpu_request_addr >= UART_ADDR_START && cpu_request_addr <= UART_ADDR_END) begin
                uart_request_valid <= 1'b1;
                uart_request_addr <= cpu_request_addr;
                uart_request_wdata <= cpu_request_wdata;
                uart_request_we <= cpu_request_we;
            end else if (cpu_request_addr >= PE_ADDR_START && cpu_request_addr <= PE_ADDR_END) begin
                pe_request_valid <= 1'b1;
                pe_request_addr <= cpu_request_addr;
                pe_request_wdata <= cpu_request_wdata;
                pe_request_we <= cpu_request_we;
            end else if (cpu_request_addr >= JTAG_ADDR_START && cpu_request_addr <= JTAG_ADDR_END) begin
                jtag_request_valid <= 1'b1;
                jtag_request_addr <= cpu_request_addr;
                jtag_request_wdata <= cpu_request_wdata;
                jtag_request_we <= cpu_request_we;
            end else if (cpu_request_addr >= SPI_ADDR_START && cpu_request_addr <= SPI_ADDR_END) begin
                spi_request_valid <= 1'b1;
                spi_request_addr <= cpu_request_addr;
                spi_request_wdata <= cpu_request_wdata;
                spi_request_we <= cpu_request_we;
            end
        end else begin
            gpio_request_valid <= 1'b0;
            uart_request_valid <= 1'b0;
            pe_request_valid <= 1'b0;
            jtag_request_valid <= 1'b0;
            spi_request_valid <= 1'b0;
        end
    end

    // State machine implementation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            STATE_IDLE:
                if (cpu_mem_req_i) begin
                    next_state = STATE_DECODE;
                end
            STATE_DECODE:
                next_state = STATE_ACCESS;
            STATE_ACCESS:
                if (gpio_ack_i || uart_ack_i || jtag_ack_i || spi_ack_i) begin
                    next_state = STATE_RESP;
                end
            STATE_RESP:
                next_state = STATE_IDLE;
            default:
                next_state = STATE_IDLE;
        endcase
    end

    // Register CPU requests
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cpu_request_valid <= 1'b0;
        end else if (state == STATE_IDLE && cpu_mem_req_i) begin
            cpu_request_valid <= 1'b1;
            cpu_request_addr <= cpu_mem_addr_i;
            cpu_request_wdata <= cpu_mem_wdata_i[63:0];
            cpu_request_we <= cpu_mem_we_i;
        end else if (state == STATE_RESP) begin
            cpu_request_valid <= 1'b0;
        end
    end

    // CPU interface connections
    assign cpu_mem_ready_o = (state == STATE_RESP);
    assign cpu_mem_rdata_o = {
        448'h0,
        gpio_ack_i ? gpio_data_out_i :
        uart_ack_i ? uart_data_out_i :
        jtag_ack_i ? jtag_data_out_i :
        spi_ack_i ? spi_data_out_i :
        64'h0
    };

    // Interrupt connections
    assign cpu_ext_int_o = gpio_int_i | uart_int_i;

    // GPIO connections
    assign gpio_req_o = gpio_request_valid;
    assign gpio_we_o = gpio_request_we;
    assign gpio_addr_o = gpio_request_addr;
    assign gpio_data_in_o = gpio_request_wdata;

    // UART connections
    assign uart_req_o = uart_request_valid;
    assign uart_we_o = uart_request_we;
    assign uart_addr_o = uart_request_addr;
    assign uart_data_in_o = uart_request_wdata;

    // PE connections
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pe_enable_o <= {NUM_PES{1'b0}};
            pe_reset_o <= {NUM_PES{1'b0}};
            pe_instructions_o <= {NUM_PES*INST_WIDTH{1'b0}};
            pe_inst_valid_o <= 1'b0;
            pe_route_config_o <= {NUM_PES*4*PE_ID_WIDTH{1'b0}};
            pe_route_cfg_valid_o <= 1'b0;
        end else if (state == STATE_ACCESS && pe_request_valid) begin
            // Handle PE specific commands
            // For simplicity, just implement basic enable/disable functionality
            if (pe_request_addr == PE_ADDR_START) begin
                pe_enable_o <= pe_request_wdata[NUM_PES-1:0];
            end else if (pe_request_addr == PE_ADDR_START + 4) begin
                pe_reset_o <= pe_request_wdata[NUM_PES-1:0];
            end else if (pe_request_addr == PE_ADDR_START + 8) begin
                pe_instructions_o <= cpu_mem_wdata_i[NUM_PES*INST_WIDTH-1:0];
                pe_inst_valid_o <= 1'b1;
            end else if (pe_request_addr == PE_ADDR_START + 12) begin
                pe_route_config_o <= cpu_mem_wdata_i[NUM_PES*4*PE_ID_WIDTH-1:0];
                pe_route_cfg_valid_o <= 1'b1;
            end
        end else begin
            pe_inst_valid_o <= 1'b0;
            pe_route_cfg_valid_o <= 1'b0;
        end
    end

    // JTAG connections
    assign jtag_req_o = jtag_request_valid;
    assign jtag_we_o = jtag_request_we;
    assign jtag_addr_o = jtag_request_addr;
    assign jtag_data_in_o = jtag_request_wdata;

    // SPI connections
    assign spi_req_o = spi_request_valid;
    assign spi_we_o = spi_request_we;
    assign spi_addr_o = spi_request_addr;
    assign spi_data_in_o = spi_request_wdata;

    // Default assignments for unused signals
    // These signals are part of the interface but not used in this simplified model
    assign jtag_tck_o = 1'b0;
    assign jtag_tms_o = 1'b0;
    assign jtag_tdi_o = 1'b0;
    assign spi_miso_o = 1'b0;
    assign uart_rxd_o = 1'b0;
    assign uart_cts_o = 1'b0;

endmodule