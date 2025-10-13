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
    input [NODE_ID_WIDTH-1:0]           node_id_i,

    // Ring interface - Input
    input                               ring_in_valid_i,
    input [NODE_ID_WIDTH-1:0]           ring_in_src_i,
    input [NODE_ID_WIDTH-1:0]           ring_in_dest_i,
    input [ADDR_WIDTH-1:0]              ring_in_addr_i,
    input [DATA_WIDTH-1:0]              ring_in_data_i,
    input                               ring_in_we_i,
    input [3:0]                         ring_in_be_i,
    input                               ring_in_ack_i,

    // Ring interface - Output
    output reg                          ring_out_valid_o,
    output reg [NODE_ID_WIDTH-1:0]      ring_out_src_o,
    output reg [NODE_ID_WIDTH-1:0]      ring_out_dest_o,
    output reg [ADDR_WIDTH-1:0]         ring_out_addr_o,
    output reg [DATA_WIDTH-1:0]         ring_out_data_o,
    output reg                          ring_out_we_o,
    output reg [3:0]                    ring_out_be_o,
    output reg                          ring_out_ack_o,

    // JTAG interface
    output reg                          jtag_req_o,
    output reg                          jtag_we_o,
    output reg [ADDR_WIDTH-1:0]         jtag_addr_o,
    output reg [DATA_WIDTH-1:0]         jtag_data_out_o,
    input      [DATA_WIDTH-1:0]         jtag_data_in_i,
    input                               jtag_ack_i,

    // Debug interface
    input      [DATA_WIDTH-1:0]         jtag_debug_data_i,
    input                               jtag_debug_valid_i
);

    // Internal state registers
    reg [1:0]                           state;
    reg [DATA_WIDTH-1:0]                data_buffer;
    reg [ADDR_WIDTH-1:0]                addr_buffer;
    reg [NODE_ID_WIDTH-1:0]             src_buffer;
    reg                                 we_buffer;

    // Determine if data is for this node
    wire is_for_me = (ring_in_dest_i == node_id_i) && ring_in_valid_i;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= `STATE_IDLE;
            ring_out_valid_o <= 1'b0;
            ring_out_ack_o <= 1'b0;
            jtag_req_o <= 1'b0;
        end else begin
            case (state)
                `STATE_IDLE: begin
                    ring_out_ack_o <= 1'b0;
                    jtag_req_o <= 1'b0;

                    if (ring_in_valid_i) begin
                        // Process data on the ring
                        ring_out_valid_o <= ring_in_valid_i;
                        ring_out_src_o <= ring_in_src_i;
                        ring_out_dest_o <= ring_in_dest_i;
                        ring_out_addr_o <= ring_in_addr_i;
                        ring_out_data_o <= ring_in_data_i;
                        ring_out_we_o <= ring_in_we_i;
                        ring_out_be_o <= ring_in_be_i;

                        if (is_for_me) begin
                            // Data is for JTAG of this node
                            state <= `STATE_DATA;
                            jtag_req_o <= 1'b1;
                            jtag_addr_o <= ring_in_addr_i;
                            jtag_data_out_o <= ring_in_data_i;
                            jtag_we_o <= ring_in_we_i;

                            // Save source information for reply
                            src_buffer <= ring_in_src_i;
                            we_buffer <= ring_in_we_i;
                            addr_buffer <= ring_in_addr_i;
                        end
                    end else begin
                        ring_out_valid_o <= 1'b0;
                    end
                end

                `STATE_DATA: begin
                    // JTAG data processing state
                    if (jtag_ack_i) begin
                        jtag_req_o <= 1'b0;

                        if (!we_buffer) begin
                            // Read operation complete, prepare to send reply
                            data_buffer <= jtag_data_in_i;
                            state <= `STATE_ARB;
                        end else begin
                            // Write operation complete, send confirmation
                            ring_out_ack_o <= 1'b1;
                            state <= `STATE_IDLE;
                        end
                    end

                    // Process debug data
                    if (jtag_debug_valid_i) begin
                        // Debug data processing logic can be added here
                        // For example, send debug data to other nodes
                    end
                end

                `STATE_ARB: begin
                    // Arbitration state, wait for opportunity to send reply
                    if (!ring_in_valid_i) begin
                        // Ring is idle, can send reply
                        ring_out_valid_o <= 1'b1;
                        ring_out_src_o <= node_id_i;
                        ring_out_dest_o <= src_buffer;  // Reply to requester
                        ring_out_addr_o <= addr_buffer;
                        ring_out_data_o <= data_buffer;
                        ring_out_we_o <= 1'b0;  // Indicates this is a read reply
                        ring_out_be_o <= 4'b1111;
                        state <= `STATE_ACK;
                    end
                end

                `STATE_ACK: begin
                    // Wait for confirmation
                    if (ring_in_ack_i && (ring_in_dest_i == src_buffer)) begin
                        ring_out_valid_o <= 1'b0;
                        ring_out_ack_o <= 1'b0;
                        state <= `STATE_IDLE;
                    end
                end
            endcase
        end
    end

endmodule