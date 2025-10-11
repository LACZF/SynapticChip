// jtag_ring_node.v
// JTAG Ring bus node interface

`include "jtag_params.v"

module jtag_ring_node #(
    parameter NUM_RINGS                 = 2,
    parameter ADDR_WIDTH                = `ADDR_WIDTH,
    parameter DATA_WIDTH                = `DATA_WIDTH,
    parameter NODE_ID_WIDTH             = `NODE_ID_WIDTH,
    parameter NODE_ID                   = 0,
    parameter OPCODE_WIDTH              = 8,
    parameter MATCH_TYPE_WIDTH          = 2
) (
    input                               clk,
    input                               rst_n,
    input [NODE_ID_WIDTH-1:0]           node_id,

    // Ring interface - Input
    input                               ring_in_valid,
    input [NODE_ID_WIDTH-1:0]           ring_in_src,
    input [NODE_ID_WIDTH-1:0]           ring_in_dest,
    input [ADDR_WIDTH-1:0]              ring_in_addr,
    input [DATA_WIDTH-1:0]              ring_in_data,
    input                               ring_in_we,
    input [3:0]                         ring_in_be,
    input                               ring_in_ack,

    // Ring interface - Output
    output reg                          ring_out_valid,
    output reg [NODE_ID_WIDTH-1:0]      ring_out_src,
    output reg [NODE_ID_WIDTH-1:0]      ring_out_dest,
    output reg [ADDR_WIDTH-1:0]         ring_out_addr,
    output reg [DATA_WIDTH-1:0]         ring_out_data,
    output reg                          ring_out_we,
    output reg [3:0]                    ring_out_be,
    output reg                          ring_out_ack,

    // JTAG interface
    output reg                          jtag_req,
    output reg                          jtag_we,
    output reg [ADDR_WIDTH-1:0]         jtag_addr,
    output reg [DATA_WIDTH-1:0]         jtag_data_out,
    input      [DATA_WIDTH-1:0]         jtag_data_in,
    input                               jtag_ack,

    // Debug interface
    input      [DATA_WIDTH-1:0]         jtag_debug_data,
    input                               jtag_debug_valid
);

    // Internal state registers
    reg [1:0]                           state;
    reg [DATA_WIDTH-1:0]                data_buffer;
    reg [ADDR_WIDTH-1:0]                addr_buffer;
    reg [NODE_ID_WIDTH-1:0]             src_buffer;
    reg                                 we_buffer;

    // Determine if data is for this node
    wire is_for_me = (ring_in_dest == node_id) && ring_in_valid;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= `STATE_IDLE;
            ring_out_valid <= 1'b0;
            ring_out_ack <= 1'b0;
            jtag_req <= 1'b0;
        end else begin
            case (state)
                `STATE_IDLE: begin
                    ring_out_ack <= 1'b0;
                    jtag_req <= 1'b0;

                    if (ring_in_valid) begin
                        // Process data on the ring
                        ring_out_valid <= ring_in_valid;
                        ring_out_src <= ring_in_src;
                        ring_out_dest <= ring_in_dest;
                        ring_out_addr <= ring_in_addr;
                        ring_out_data <= ring_in_data;
                        ring_out_we <= ring_in_we;
                        ring_out_be <= ring_in_be;

                        if (is_for_me) begin
                            // Data is for JTAG of this node
                            state <= `STATE_DATA;
                            jtag_req <= 1'b1;
                            jtag_addr <= ring_in_addr;
                            jtag_data_out <= ring_in_data;
                            jtag_we <= ring_in_we;

                            // Save source information for reply
                            src_buffer <= ring_in_src;
                            we_buffer <= ring_in_we;
                            addr_buffer <= ring_in_addr;
                        end
                    end else begin
                        ring_out_valid <= 1'b0;
                    end
                end

                `STATE_DATA: begin
                    // JTAG data processing state
                    if (jtag_ack) begin
                        jtag_req <= 1'b0;

                        if (!we_buffer) begin
                            // Read operation complete, prepare to send reply
                            data_buffer <= jtag_data_in;
                            state <= `STATE_ARB;
                        end else begin
                            // Write operation complete, send confirmation
                            ring_out_ack <= 1'b1;
                            state <= `STATE_IDLE;
                        end
                    end

                    // Process debug data
                    if (jtag_debug_valid) begin
                        // Debug data processing logic can be added here
                        // For example, send debug data to other nodes
                    end
                end

                `STATE_ARB: begin
                    // Arbitration state, wait for opportunity to send reply
                    if (!ring_in_valid) begin
                        // Ring is idle, can send reply
                        ring_out_valid <= 1'b1;
                        ring_out_src <= node_id;
                        ring_out_dest <= src_buffer;  // Reply to requester
                        ring_out_addr <= addr_buffer;
                        ring_out_data <= data_buffer;
                        ring_out_we <= 1'b0;  // Indicates this is a read reply
                        ring_out_be <= 4'b1111;
                        state <= `STATE_ACK;
                    end
                end

                `STATE_ACK: begin
                    // Wait for confirmation
                    if (ring_in_ack && (ring_in_dest == src_buffer)) begin
                        ring_out_valid <= 1'b0;
                        ring_out_ack <= 1'b0;
                        state <= `STATE_IDLE;
                    end
                end
            endcase
        end
    end

endmodule