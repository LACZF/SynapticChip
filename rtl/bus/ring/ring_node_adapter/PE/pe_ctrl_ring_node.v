// pe_ctrl.v
// PE Control Module Implementation

`include "pe_ctrl_params.v"

module pe_ctrl_ring_node #(
    parameter NODE_ID_WIDTH                      = 5,
    parameter ADDR_WIDTH                         = 32,
    parameter DATA_WIDTH                         = 32,
    parameter NUM_PES                            = 4,
    parameter INST_WIDTH                         = 32,
    parameter PE_ID_WIDTH                        = 4
) (
    input                                        clk,
    input                                        rst_n,

    // Ring bus interface
    input                                        ring_in_valid,
    input       [NODE_ID_WIDTH-1:0]              ring_in_src,
    input       [NODE_ID_WIDTH-1:0]              ring_in_dest,
    input       [ADDR_WIDTH-1:0]                 ring_in_addr,
    input       [DATA_WIDTH-1:0]                 ring_in_data,
    input                                        ring_in_we,
    input       [3:0]                            ring_in_be,
    input                                        ring_in_ack,

    output reg                                   ring_out_valid,
    output reg  [NODE_ID_WIDTH-1:0]              ring_out_src,
    output reg  [NODE_ID_WIDTH-1:0]              ring_out_dest,
    output reg  [ADDR_WIDTH-1:0]                 ring_out_addr,
    output reg  [DATA_WIDTH-1:0]                 ring_out_data,
    output reg                                   ring_out_we,
    output reg  [3:0]                            ring_out_be,
    output reg                                   ring_out_ack,

    // PE array control interface
    output reg  [NUM_PES-1:0]                     pe_enable,
    output reg  [NUM_PES-1:0]                     pe_reset,
    output reg  [(NUM_PES*INST_WIDTH)-1:0]        pe_instructions,
    output reg                                    pe_inst_valid,

    // PE status inputs
    input       [(NUM_PES*DATA_WIDTH)-1:0]        pe_status,
    input       [(NUM_PES*DATA_WIDTH)-1:0]        pe_outputs,
    input       [NUM_PES-1:0]                     pe_busy,

    // Route configuration interface
    output reg  [(NUM_PES*4*PE_ID_WIDTH)-1:0]     route_config, // Each PE has 4-direction routing configuration
    output reg                                    route_cfg_valid
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
    wire is_for_me = (ring_in_dest == {NODE_ID_WIDTH{1'b0}}) && ring_in_valid; // Assuming controller node ID is 0

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= `STATE_IDLE;
            ring_out_valid <= 1'b0;
            ring_out_ack <= 1'b0;
            pe_enable <= {NUM_PES{1'b0}};
            pe_reset <= {NUM_PES{1'b0}};
            pe_inst_valid <= 1'b0;
            route_cfg_valid <= 1'b0;
            control_reg <= {DATA_WIDTH{1'b0}};
            status_reg <= {DATA_WIDTH{1'b0}};
        end else begin
            case (state)
                `STATE_IDLE: begin
                    ring_out_ack <= 1'b0;
                    pe_inst_valid <= 1'b0;
                    route_cfg_valid <= 1'b0;

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
                            // Data is for this controller
                            state <= `STATE_DATA;

                            // Save source information for reply
                            src_buffer <= ring_in_src;
                            we_buffer <= ring_in_we;
                            addr_buffer <= ring_in_addr;
                            data_buffer <= ring_in_data;

                            // Handle write operation
                            if (ring_in_we) begin
                                case (ring_in_addr)
                                    `REG_PE_CTRL: begin
                                        control_reg <= ring_in_data;
                                        // Parse control register
                                        pe_enable <= ring_in_data[NUM_PES-1:0];
                                        pe_reset <= ring_in_data[31:NUM_PES];
                                    end

                                    `REG_PE_INST: begin
                                        // Store instruction to buffer
                                        inst_buffer <= ring_in_data;
                                    end

                                    `REG_PE_DATA: begin

                                        // Simplified handling here, actual implementation may need more complex logic
                                    end

                                    `REG_ROUTE_CFG: begin
                                        // Route configuration
                                        route_buffer <= ring_in_data;
                                        route_cfg_valid <= 1'b1;
                                    end
                                endcase
                            end
                        end
                    end else begin
                        ring_out_valid <= 1'b0;
                    end
                end

                `STATE_DATA: begin
                    // Data processing state
                    if (!we_buffer) begin
                        // Read operation, prepare data
                        case (addr_buffer)
                            `REG_PE_CTRL: ring_out_data <= control_reg;
                            `REG_PE_STAT: begin
                                // Summarize PE status
                                status_reg <= {
                                    pe_busy,
                                    pe_status[(DATA_WIDTH-NUM_PES-1):0]
                                };
                                ring_out_data <= status_reg;
                            end
                            `REG_PE_DATA: begin
                                // Read PE output data
                                ring_out_data <= pe_outputs[DATA_WIDTH-1:0]; // Only return output of the first PE
                            end
                            default: ring_out_data <= {DATA_WIDTH{1'b0}};
                        endcase

                        state <= `STATE_ARB;
                    end else begin
                        // Write operation completed, send acknowledgment
                        ring_out_ack <= 1'b1;
                        state <= `STATE_IDLE;
                    end
                end

                `STATE_ARB: begin
                    // Arbitration state, wait for opportunity to send reply
                    if (!ring_in_valid) begin
                        // Ring is idle, can send reply
                        ring_out_valid <= 1'b1;
                        ring_out_src <= {NODE_ID_WIDTH{1'd0}}; // Controller node ID
                        ring_out_dest <= src_buffer;       // Reply to requester
                        ring_out_addr <= addr_buffer;
                        ring_out_data <= data_buffer;
                        ring_out_we <= 1'b0;               // Indicates this is a read response
                        ring_out_be <= 4'b1111;
                        state <= `STATE_ACK;
                    end
                end

                `STATE_ACK: begin
                    // Wait for acknowledgment
                    if (ring_in_ack && (ring_in_dest == src_buffer)) begin
                        ring_out_valid <= 1'b0;
                        ring_out_ack <= 1'b0;
                        state <= `STATE_IDLE;
                    end
                end
            endcase
        end
    end

    // Distribute instruction buffer to each PE
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pe_instructions <= {(NUM_PES*INST_WIDTH){1'b0}};
        end else if (control_reg[0]) begin // If instruction broadcasting is enabled
            for (integer i = 0; i < NUM_PES; i = i + 1) begin
                pe_instructions[i*INST_WIDTH +: INST_WIDTH] <= inst_buffer;
            end
            pe_inst_valid <= 1'b1;
        end else begin
                    // Can send instructions to specific PEs based on address
                    // Simplified handling here, actual implementation is more complex
            pe_inst_valid <= 1'b0;
        end
    end

    // Distribute route configuration to each PE
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            route_config <= {(NUM_PES*4*PE_ID_WIDTH){1'b0}};
        end else if (route_cfg_valid) begin
            for (integer i = 0; i < NUM_PES; i = i + 1) begin
                // 4-direction routing configuration for each PE
                route_config[i*4*PE_ID_WIDTH +: 4*PE_ID_WIDTH] <= route_buffer;
            end
        end
    end

endmodule