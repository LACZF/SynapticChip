// pe_ctrl.v
// PE Control Module Implementation

`include "pe_ctrl_params.v"

module pe_ctrl_ring_node #(
    parameter NODE_ID_WIDTH                      = 5,
    parameter ADDR_WIDTH                         = 64,
    parameter DATA_WIDTH                         = 64,
    parameter NUM_PES                            = 4,
    parameter INST_WIDTH                         = 32,
    parameter PE_ID_WIDTH                        = 4
) (
    input                                        clk,
    input                                        rst_n,

    // Ring bus interface
    input                                        ring_in_valid_i,
    input       [NODE_ID_WIDTH-1:0]              ring_in_src_i,
    input       [NODE_ID_WIDTH-1:0]              ring_in_dest_i,
    input       [ADDR_WIDTH-1:0]                 ring_in_addr_i,
    input       [DATA_WIDTH-1:0]                 ring_in_data_i,
    input                                        ring_in_we_i,
    input       [3:0]                            ring_in_be_i,
    input                                        ring_in_ack_i,

    output reg                                   ring_out_valid_o,
    output reg  [NODE_ID_WIDTH-1:0]              ring_out_src_o,
    output reg  [NODE_ID_WIDTH-1:0]              ring_out_dest_o,
    output reg  [ADDR_WIDTH-1:0]                 ring_out_addr_o,
    output reg  [DATA_WIDTH-1:0]                 ring_out_data_o,
    output reg                                   ring_out_we_o,
    output reg  [3:0]                            ring_out_be_o,
    output reg                                   ring_out_ack_o,

    // PE array control interface
    output reg  [NUM_PES-1:0]                     pe_enable_o,
    output reg  [NUM_PES-1:0]                     pe_reset_o,
    output reg  [(NUM_PES*INST_WIDTH)-1:0]        pe_instructions_o,
    output reg                                    pe_inst_valid_o,

    // PE status inputs
    input       [(NUM_PES*DATA_WIDTH)-1:0]        pe_status_i,
    input       [(NUM_PES*DATA_WIDTH)-1:0]        pe_outputs_i,
    input       [NUM_PES-1:0]                     pe_busy_i,

    // Route configuration interface
    output reg  [(NUM_PES*4*PE_ID_WIDTH)-1:0]     route_config_o, // Each PE has 4-direction routing configuration
    output reg                                    route_cfg_valid_o
);

    // Internal registers
    reg [DATA_WIDTH-1:0]                          control_reg;
    reg [DATA_WIDTH-1:0]                          status_reg;
    reg [(NUM_PES*INST_WIDTH)-1:0]                inst_buffer;
    reg [(NUM_PES*4*PE_ID_WIDTH)-1:0]             route_buffer;

    // State machine
    reg [1:0] state;
    reg [DATA_WIDTH-1:0]                          data_buffer;
    reg [ADDR_WIDTH-1:0]                          addr_buffer;
    reg [NODE_ID_WIDTH-1:0]                       src_buffer;
    reg                                           we_buffer;

    // Determine if data is for this node
    wire is_for_me = (ring_in_dest_i == {NODE_ID_WIDTH{1'b0}}) && ring_in_valid_i; // Assuming controller node ID is 0

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= `STATE_IDLE;
            ring_out_valid_o <= 1'b0;
            ring_out_ack_o <= 1'b0;
            pe_enable_o <= {NUM_PES{1'b0}};
            pe_reset_o <= {NUM_PES{1'b0}};
            pe_inst_valid_o <= 1'b0;
            route_cfg_valid_o <= 1'b0;
            control_reg <= {DATA_WIDTH{1'b0}};
            status_reg <= {DATA_WIDTH{1'b0}};
        end else begin
            case (state)
                `STATE_IDLE: begin
                    ring_out_ack_o <= 1'b0;
                    pe_inst_valid_o <= 1'b0;
                    route_cfg_valid_o <= 1'b0;

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
                            // Data is for this controller
                            state <= `STATE_DATA;

                            // Save source information for reply
                            src_buffer <= ring_in_src_i;
                            we_buffer <= ring_in_we_i;
                            addr_buffer <= ring_in_addr_i;
                            data_buffer <= ring_in_data_i;

                            // Handle write operation
                            if (ring_in_we_i) begin
                                case (ring_in_addr_i)
                                    `REG_PE_CTRL: begin
                                        control_reg <= ring_in_data_i;
                                        // Parse control register
                                        pe_enable_o <= ring_in_data_i[NUM_PES-1:0];
                                        pe_reset_o <= ring_in_data_i[31:NUM_PES];
                                    end

                                    `REG_PE_INST: begin
                                        // Store instruction to buffer
                                        inst_buffer <= ring_in_data_i;
                                    end

                                    `REG_PE_DATA: begin

                                        // Simplified handling here, actual implementation may need more complex logic
                                    end

                                    `REG_ROUTE_CFG: begin
                                        // Route configuration
                                        route_buffer <= ring_in_data_i;
                                        route_cfg_valid_o <= 1'b1;
                                    end
                                endcase
                            end
                        end
                    end else begin
                        ring_out_valid_o <= 1'b0;
                    end
                end

                `STATE_DATA: begin
                    // Data processing state
                    if (!we_buffer) begin
                        // Read operation, prepare data
                        case (addr_buffer)
                            `REG_PE_CTRL: ring_out_data_o <= control_reg;
                            `REG_PE_STAT: begin
                                // Summarize PE status
                                status_reg <= {
                                    pe_busy_i,
                                    pe_status_i[(DATA_WIDTH-NUM_PES-1):0]
                                };
                                ring_out_data_o <= status_reg;
                            end
                            `REG_PE_DATA: begin
                                // Read PE output data
                                ring_out_data_o <= pe_outputs_i[DATA_WIDTH-1:0]; // Only return output of the first PE
                            end
                            default: ring_out_data_o <= {DATA_WIDTH{1'b0}};
                        endcase

                        state <= `STATE_ARB;
                    end else begin
                        // Write operation completed, send acknowledgment
                        ring_out_ack_o <= 1'b1;
                        state <= `STATE_IDLE;
                    end
                end

                `STATE_ARB: begin
                    // Arbitration state, wait for opportunity to send reply
                    if (!ring_in_valid_i) begin
                        // Ring is idle, can send reply
                        ring_out_valid_o <= 1'b1;
                        ring_out_src_o <= {NODE_ID_WIDTH{1'd0}}; // Controller node ID
                        ring_out_dest_o <= src_buffer;       // Reply to requester
                        ring_out_addr_o <= addr_buffer;
                        ring_out_data_o <= data_buffer;
                        ring_out_we_o <= 1'b0;               // Indicates this is a read response
                        ring_out_be_o <= 4'b1111;
                        state <= `STATE_ACK;
                    end
                end

                `STATE_ACK: begin
                    // Wait for acknowledgment
                    if (ring_in_ack_i && (ring_in_dest_i == src_buffer)) begin
                        ring_out_valid_o <= 1'b0;
                        ring_out_ack_o <= 1'b0;
                        state <= `STATE_IDLE;
                    end
                end
            endcase
        end
    end

    // Distribute instruction buffer to each PE
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pe_instructions_o <= {(NUM_PES*INST_WIDTH){1'b0}};
        end else if (control_reg[0]) begin // If instruction broadcasting is enabled
            for (integer i = 0; i < NUM_PES; i = i + 1) begin
                pe_instructions_o[i*INST_WIDTH +: INST_WIDTH] <= inst_buffer;
            end
            pe_inst_valid_o <= 1'b1;
        end else begin
                    // Can send instructions to specific PEs based on address
                    // Simplified handling here, actual implementation is more complex
            pe_inst_valid_o <= 1'b0;
        end
    end

    // Distribute route configuration to each PE
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            route_config_o <= {(NUM_PES*4*PE_ID_WIDTH){1'b0}};
        end else if (route_cfg_valid_o) begin
            for (integer i = 0; i < NUM_PES; i = i + 1) begin
                // 4-direction routing configuration for each PE
                route_config_o[i*4*PE_ID_WIDTH +: 4*PE_ID_WIDTH] <= route_buffer;
            end
        end
    end

endmodule