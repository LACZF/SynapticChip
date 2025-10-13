// CPU and Ring Bus Interface Module
// Responsible for connecting cpu_top and ring bus, handling signal format conversion

`include "top_system_params.v"

module cpu_ring_interface #(
    parameter NUM_RINGS                       = 2,
    parameter ADDR_WIDTH                      = 64,
    parameter DATA_WIDTH                      = 64,
    parameter NODE_ID_WIDTH                   = 8,
    parameter NODE_ID                         = 0,
    parameter OPCODE_WIDTH                    = 8,
    parameter MATCH_TYPE_WIDTH                = 2
) (
    input                                     clk,
    input                                     rst_n,

    // CPU_TOP interface
    input wire                                cpu_mem_req_i,
    input wire [ADDR_WIDTH-1:0]               cpu_mem_addr_i,
    input wire [511:0]                        cpu_mem_wdata_i,
    input wire                                cpu_mem_we_i,
    output wire                               cpu_mem_ready_o,
    output wire [511:0]                       cpu_mem_rdata_o,

    // Ring bus interface
    // Send requests
    output wire [NUM_RINGS-1:0]               tx_req_ring_mask_o,
    output wire [NUM_RINGS-1:0]               tx_req_ring_disable_o,
    output wire                               tx_req_valid_o,
    output wire                               tx_req_is_order_o,
    output wire [OPCODE_WIDTH-1:0]            tx_req_opcode_o,
    output wire [MATCH_TYPE_WIDTH-1:0]        tx_req_match_type_o,
    output wire [NODE_ID_WIDTH-1:0]           tx_req_source_id_o,
    output wire [NODE_ID_WIDTH-1:0]           tx_req_target_id_o,
    output wire [ADDR_WIDTH-1:0]              tx_req_addr_o,
    output wire [DATA_WIDTH-1:0]              tx_req_data_o,

    // Receive requests
    input wire                                rx_req_valid_i,
    input wire                                rx_req_is_order_i,
    input wire [OPCODE_WIDTH-1:0]             rx_req_opcode_i,
    input wire [MATCH_TYPE_WIDTH-1:0]         rx_req_match_type_i,
    input wire [NODE_ID_WIDTH-1:0]            rx_req_source_id_i,
    input wire [NODE_ID_WIDTH-1:0]            rx_req_target_id_i,
    input wire [ADDR_WIDTH-1:0]               rx_req_addr_i,
    input wire [DATA_WIDTH-1:0]               rx_req_data_i,

    // Receive responses
    input wire                                rsp_valid_i,
    input wire [NODE_ID_WIDTH-1:0]            rsp_source_id_i,
    input wire [NODE_ID_WIDTH-1:0]            rsp_target_id_i,
    input wire [ADDR_WIDTH-1:0]               rsp_addr_i,
    input wire [DATA_WIDTH-1:0]               rsp_data_i
);

    // State definitions
    localparam IDLE             = 2'b00;
    localparam WAITING_RESP     = 2'b01;
    localparam WAITING_SPI_RESP = 2'b10; // New state for waiting SPI response

    // Internal signals
    reg  [1:0]               state;
    reg  [ADDR_WIDTH-1:0]    pending_addr;
    reg                      is_instruction_read; // Flag indicating if it's an instruction read
    wire                     is_instruction_addr; // Determine if address is in instruction address range (assuming instruction address range starts at 0x8000_0000)
    reg                      is_cache_miss;       // Flag indicating cache miss

    // Determine if address is an instruction address (assuming instructions start at 0x8000_0000)
    assign is_instruction_addr = (cpu_mem_addr_i[31:28] == 4'h8);

    // Detect cache miss: Considered a cache miss when a request is sent but no response is received within a certain time
    // Simple implementation: Use counter to detect timeout
    reg [3:0] cache_response_timeout; // Cache response timeout counter

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cache_response_timeout <= 4'h0;
            is_cache_miss <= 1'b0;
        end else begin
            if (state == WAITING_RESP) begin
                cache_response_timeout <= cache_response_timeout + 1'b1;
                // If timeout (simply using 4 cycles here), consider it a cache miss
                if (cache_response_timeout == 4'hF) begin
                    is_cache_miss <= 1'b1;
                end
            end else begin
                cache_response_timeout <= 4'h0;
                is_cache_miss <= 1'b0;
            end
        end
    end

    // Default ring bus parameter settings
    assign tx_req_ring_mask_o = {NUM_RINGS{1'b1}};  // Use all rings
    assign tx_req_ring_disable_o = {NUM_RINGS{1'b0}};  // Don't disable any rings
    assign tx_req_is_order_o = 1'b1;  // Requests are ordered
    assign tx_req_source_id_o = NODE_ID;  // Source ID is current node
    assign tx_req_match_type_o = 2'b00;  // Default match type

    // Target ID: Memory controller under normal circumstances, SPI node when SPI instruction read is needed
    assign tx_req_target_id_o = (state == IDLE && is_instruction_addr && !cpu_mem_we_i) ?
                                `NODE_SPI : {NODE_ID_WIDTH{1'b0}};  // 0 is memory controller, `NODE_SPI is SPI node

    // Convert CPU memory request to Ring bus request
    assign tx_req_valid_o = (state == IDLE) && cpu_mem_req_i;
    assign tx_req_opcode_o = cpu_mem_we_i ? {OPCODE_WIDTH{1'b1}} : {OPCODE_WIDTH{1'b0}};  // Write operation is all 1s, read operation is all 0s
    assign tx_req_addr_o = cpu_mem_addr_i;
    assign tx_req_data_o = cpu_mem_wdata_i[0+:DATA_WIDTH];  // Extract lower 64 bits from 512 bits

    // Convert Ring bus response to CPU memory response
    // Note: Simplified response handling logic is used here; more complex processing based on address matching should be implemented in actual systems
    assign cpu_mem_ready_o = ((state == WAITING_RESP) && rsp_valid_i && (rsp_target_id_i == NODE_ID)) ||
                            ((state == WAITING_SPI_RESP) && rsp_valid_i && (rsp_source_id_i == `NODE_SPI));
    assign cpu_mem_rdata_o = cpu_mem_ready_o ? {512{1'b0}} | rsp_data_i : {512{1'b0}};  // Extend 64-bit response to 512 bits

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pending_addr <= {ADDR_WIDTH{1'b0}};
            is_instruction_read <= 1'b0;
        end else begin
            case (state)
                IDLE:
                    if (cpu_mem_req_i) begin
                            state <= WAITING_RESP;
                            pending_addr <= cpu_mem_addr_i;
                            // Flag indicating if it's an instruction read
                            is_instruction_read <= is_instruction_addr && !cpu_mem_we_i;
                        end
                WAITING_RESP:
                    if (rsp_valid_i && (rsp_target_id_i == NODE_ID)) begin
                        // Normal memory response
                        state <= IDLE;
                        pending_addr <= {ADDR_WIDTH{1'b0}};
                        is_instruction_read <= 1'b0;
                    end else if (is_instruction_read && is_cache_miss) begin
                        // Instruction read with cache miss, switch to SPI read
                        state <= WAITING_SPI_RESP;
                        // No need to resend request, as target ID has already been set based on state and address type in tx_req_target_id_o
                    end
                WAITING_SPI_RESP:
                    if (rsp_valid_i && (rsp_source_id_i == `NODE_SPI)) begin
                        // Received SPI response
                        state <= IDLE;
                        pending_addr <= {ADDR_WIDTH{1'b0}};
                        is_instruction_read <= 1'b0;
                    end
            endcase
        end
    end

    // Debug information
`ifdef DEBUG
    always @(posedge clk) begin
        if (tx_req_valid_o) begin
            $display("[%0t ps] CPU_RING_INTERFACE: Sending request - Opcode=0x%h, Addr=0x%h, Data=0x%h, TargetID=0x%h",
                     $time, tx_req_opcode_o, tx_req_addr_o, tx_req_data_o, tx_req_target_id_o);
            if (tx_req_target_id_o == `NODE_SPI) begin
                $display("[%0t ps] CPU_RING_INTERFACE: Instruction read request directed to SPI flash", $time);
            end
        end
        if (is_cache_miss && is_instruction_read) begin
            $display("[%0t ps] CPU_RING_INTERFACE: Cache miss detected for instruction at address 0x%h, switching to SPI read",
                     $time, pending_addr);
        end
        if (cpu_mem_ready_o) begin
            if (state == WAITING_SPI_RESP) begin
                $display("[%0t ps] CPU_RING_INTERFACE: Received SPI response - Addr=0x%h, Data=0x%h",
                         $time, pending_addr, cpu_mem_rdata_o);
            end else begin
                $display("[%0t ps] CPU_RING_INTERFACE: Received memory response - Addr=0x%h, Data=0x%h",
                         $time, pending_addr, cpu_mem_rdata_o);
            end
        end
    end
`endif

endmodule