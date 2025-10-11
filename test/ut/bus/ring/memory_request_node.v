module memory_request_node #(
    parameter NODE_ID                   = 0,
    parameter TARGET_NODE_ID            = 3,  // Target node ID (memory response node)
    parameter ADDR_WIDTH                = 32,
    parameter DATA_WIDTH                = 64
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // Ring bus interface
    output reg                          ring_req_valid_o,
    input  wire                         ring_req_ready_i,
    output reg  [ADDR_WIDTH-1:0]        ring_req_addr_o,
    output reg  [DATA_WIDTH-1:0]        ring_req_data_o,
    output reg                          ring_req_wr_o,
    output reg  [7:0]                   ring_req_dest_o,

    input  wire                         ring_resp_valid_i,
    output reg                          ring_resp_ready_o,
    input  wire [DATA_WIDTH-1:0]        ring_resp_data_i,
    input  wire                         ring_resp_error_i,

    // External request interface (from CPU)
    input  wire                         ext_req_enable_i,
    input  wire [ADDR_WIDTH-1:0]        ext_req_addr_i,
    input  wire [DATA_WIDTH-1:0]        ext_req_data_i,
    input  wire                         ext_req_wr_i,
    output reg  [DATA_WIDTH-1:0]        ext_req_data_o,
    output reg                          ext_req_ready_o
);

    // State machine
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        SEND_REQUEST = 2'b01,
        WAIT_RESPONSE = 2'b10
    } state_t;

    state_t current_state;

    // Request information registers
    reg [ADDR_WIDTH-1:0] saved_addr;
    reg [DATA_WIDTH-1:0] saved_data;
    reg saved_wr;

    // Timeout counter
    reg [31:0] timeout_counter;
    localparam TIMEOUT_CYCLES = 1000; // 1000 clock cycles timeout

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            ring_req_valid_o <= 1'b0;
            ext_req_ready_o <= 1'b1;
            ring_resp_ready_o <= 1'b0;
            ext_req_data_o <= {DATA_WIDTH{1'b0}};
            timeout_counter <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    timeout_counter <= 0;
                    if (ext_req_enable_i && ext_req_ready_o) begin
                        // Save request information
                        saved_addr <= ext_req_addr_i;
                        saved_data <= ext_req_data_i;
                        saved_wr <= ext_req_wr_i;

                        // Prepare to send request to Ring bus
                        ring_req_valid_o <= 1'b1;
                        ring_req_addr_o <= ext_req_addr_i;
                        ring_req_data_o <= ext_req_data_i;
                        ring_req_wr_o <= ext_req_wr_i;
                        ring_req_dest_o <= TARGET_NODE_ID;

                        ext_req_ready_o <= 1'b0;
                        current_state <= SEND_REQUEST;
                    end
                end

                SEND_REQUEST: begin
                    if (ring_req_ready_i) begin
                        ring_req_valid_o <= 1'b0;
                        ring_resp_ready_o <= 1'b1;
                        timeout_counter <= 0;
                        current_state <= WAIT_RESPONSE;
                    end
                end

                WAIT_RESPONSE: begin
                    // Increment timeout counter
                    timeout_counter <= timeout_counter + 1;

                    if (ring_resp_valid_i) begin
                        // Receive response and return to CPU
                        ext_req_data_o <= ring_resp_data_i;
                        ext_req_ready_o <= 1'b1;
                        ring_resp_ready_o <= 1'b0;
                        current_state <= IDLE;
                    end else if (timeout_counter >= TIMEOUT_CYCLES) begin
                        // Timeout handling
                        $display("Memory Request Node: Timeout waiting for response!");
                        ext_req_data_o <= {DATA_WIDTH{1'b1}}; // Timeout flag
                        ext_req_ready_o <= 1'b1;
                        ring_resp_ready_o <= 1'b0;
                        current_state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule