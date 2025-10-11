// gpio_ring_node.v
// GPIO Ring bus node interface

`include "gpio_params.v"

module gpio_ring_node #(
    parameter NODE_ID_WIDTH           = 5,
    parameter ADDR_WIDTH              = 32,
    parameter DATA_WIDTH              = 32
) (
    input                             clk,
    input                             rst_n,
    input  [NODE_ID_WIDTH-1:0]        node_id,

    // Ring interface - Input
    input                             ring_in_valid,
    input  [NODE_ID_WIDTH-1:0]        ring_in_src,
    input  [NODE_ID_WIDTH-1:0]        ring_in_dest,
    input  [ADDR_WIDTH-1:0]           ring_in_addr,
    input  [DATA_WIDTH-1:0]           ring_in_data,
    input                             ring_in_we,
    input  [3:0]                      ring_in_be,
    input                             ring_in_ack,

    // Ring interface - Output
    output reg                        ring_out_valid,
    output reg [NODE_ID_WIDTH-1:0]    ring_out_src,
    output reg [NODE_ID_WIDTH-1:0]    ring_out_dest,
    output reg [ADDR_WIDTH-1:0]       ring_out_addr,
    output reg [DATA_WIDTH-1:0]       ring_out_data,
    output reg                        ring_out_we,
    output reg [3:0]                  ring_out_be,
    output reg                        ring_out_ack,

    // GPIO interface
    output reg                        gpio_req,
    output reg                        gpio_we,
    output reg [ADDR_WIDTH-1:0]       gpio_addr,
    input  reg [DATA_WIDTH-1:0]       gpio_data_out,
    output reg [DATA_WIDTH-1:0]       gpio_data_in,
    input                             gpio_ack,

    // Interrupt interface
    input                             gpio_int,
    output reg                        int_ack
);

    // Internal state registers
    reg [1:0]                         state;
    reg [DATA_WIDTH-1:0]              data_buffer;
    reg [ADDR_WIDTH-1:0]              addr_buffer;
    reg [NODE_ID_WIDTH-1:0]           src_buffer;
    reg                               we_buffer;

    // Determine if data is for this node
    wire is_for_me = (ring_in_dest == node_id) && ring_in_valid;

    // Interrupt state
    reg int_pending;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= `STATE_IDLE;
            ring_out_valid <= 1'b0;
            ring_out_ack <= 1'b0;
            gpio_req <= 1'b0;
            int_pending <= 1'b0;
            int_ack <= 1'b0;
        end else begin
            case (state)
                `STATE_IDLE: begin
                    ring_out_ack <= 1'b0;
                    gpio_req <= 1'b0;
                    int_ack <= 1'b0;

                    if (int_pending) begin
                        // Interrupt pending, send interrupt message
                        state <= `STATE_ARB;
                        ring_out_valid <= 1'b1;
                        ring_out_src <= node_id;
                        ring_out_dest <= 0; // Send to main controller
                        ring_out_addr <= `REG_INTSTAT;
                        ring_out_data <= {DATA_WIDTH{1'b1}}; // Interrupt flag
                        ring_out_we <= 1'b1;
                        int_pending <= 1'b0;
                    end else if (ring_in_valid) begin
                        // Process data on the ring
                        ring_out_valid <= ring_in_valid;
                        ring_out_src <= ring_in_src;
                        ring_out_dest <= ring_in_dest;
                        ring_out_addr <= ring_in_addr;
                        ring_out_data <= ring_in_data;
                        ring_out_we <= ring_in_we;
                        ring_out_be <= ring_in_be;

                        if (is_for_me) begin
                            // Data is for GPIO of this node
                            state <= `STATE_DATA;
                            gpio_req <= 1'b1;
                            gpio_addr <= ring_in_addr;
                            gpio_data_in <= ring_in_data;
                            gpio_we <= ring_in_we;

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
                    // GPIO data processing state
                    if (gpio_ack) begin
                        gpio_req <= 1'b0;

                        if (!we_buffer) begin
                            // Read operation complete, prepare to send reply
                            data_buffer <= gpio_data_out;
                            state <= `STATE_ARB;
                        end else begin
                            // Write operation complete, send confirmation
                            ring_out_ack <= 1'b1;
                            state <= `STATE_IDLE;
                        end
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

            // Detect interrupt
            if (gpio_int && !int_pending) begin
                int_pending <= 1'b1;
            end
        end
    end

endmodule