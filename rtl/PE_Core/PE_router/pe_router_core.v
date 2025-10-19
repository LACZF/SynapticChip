// pe_router_core.v
// Router module core implementation

`include "pe_router_params.v"

module pe_router_core #(
    parameter ADDR_WIDTH                         = 64,
    parameter DATA_WIDTH                         = 64,
    parameter NUM_PORTS                          = 4
) (
    input                                         clk,
    input                                         rst_n,

    // Configuration interface
    input                                         cfg_valid_i,
    input       [ADDR_WIDTH-1:0]                  cfg_addr_i,
    input       [DATA_WIDTH-1:0]                  cfg_data_i,
    output                                        cfg_ack_o,

    // Data input interface (North, South, East, West, Local)
    input       [NUM_PORTS-1:0]                   data_in_valid_i,
    input       [(NUM_PORTS*DATA_WIDTH)-1:0]      data_in_i,
    output reg  [NUM_PORTS-1:0]                   data_in_ready_o,

    // Data output interface (North, South, East, West, Local)
    output reg  [NUM_PORTS-1:0]                   data_out_valid_o,
    output reg  [(NUM_PORTS*DATA_WIDTH)-1:0]      data_out_o,
    input       [NUM_PORTS-1:0]                   data_out_ready_i,

    // Status output
    output reg  [DATA_WIDTH-1:0]                  status_o
);

    // Configuration registers
    reg [1:0]                       route_algorithm;
    reg [(NUM_PORTS*NUM_PORTS)-1:0] route_table;
    reg [NUM_PORTS-1:0]             port_enable;

    // Input buffers
    reg [DATA_WIDTH-1:0] input_buffers_0 [0:`BUFFER_DEPTH-1];
    reg [DATA_WIDTH-1:0] input_buffers_1 [0:`BUFFER_DEPTH-1];
    reg [DATA_WIDTH-1:0] input_buffers_2 [0:`BUFFER_DEPTH-1];
    reg [DATA_WIDTH-1:0] input_buffers_3 [0:`BUFFER_DEPTH-1];
    reg [DATA_WIDTH-1:0] input_buffers_4 [0:`BUFFER_DEPTH-1];

    reg [`BUFFER_ADDR_WIDTH-1:0] write_ptr_0;
    reg [`BUFFER_ADDR_WIDTH-1:0] write_ptr_1;
    reg [`BUFFER_ADDR_WIDTH-1:0] write_ptr_2;
    reg [`BUFFER_ADDR_WIDTH-1:0] write_ptr_3;
    reg [`BUFFER_ADDR_WIDTH-1:0] write_ptr_4;

    reg [`BUFFER_ADDR_WIDTH-1:0] read_ptr_0;
    reg [`BUFFER_ADDR_WIDTH-1:0] read_ptr_1;
    reg [`BUFFER_ADDR_WIDTH-1:0] read_ptr_2;
    reg [`BUFFER_ADDR_WIDTH-1:0] read_ptr_3;
    reg [`BUFFER_ADDR_WIDTH-1:0] read_ptr_4;

    reg buffer_empty_0;
    reg buffer_empty_1;
    reg buffer_empty_2;
    reg buffer_empty_3;
    reg buffer_empty_4;

    reg buffer_full_0;
    reg buffer_full_1;
    reg buffer_full_2;
    reg buffer_full_3;
    reg buffer_full_4;

    // Output arbiters
    reg [2:0] arbiter_state_0;
    reg [2:0] arbiter_state_1;
    reg [2:0] arbiter_state_2;
    reg [2:0] arbiter_state_3;
    reg [2:0] arbiter_state_4;

    reg [`PORT_ID_WIDTH-1:0] current_grant_0;
    reg [`PORT_ID_WIDTH-1:0] current_grant_1;
    reg [`PORT_ID_WIDTH-1:0] current_grant_2;
    reg [`PORT_ID_WIDTH-1:0] current_grant_3;
    reg [`PORT_ID_WIDTH-1:0] current_grant_4;

    // Destination address extraction
    wire [ADDR_WIDTH-1:0] dest_addr_0 = data_in_i[0*DATA_WIDTH +: ADDR_WIDTH];
    wire [ADDR_WIDTH-1:0] dest_addr_1 = data_in_i[1*DATA_WIDTH +: ADDR_WIDTH];
    wire [ADDR_WIDTH-1:0] dest_addr_2 = data_in_i[2*DATA_WIDTH +: ADDR_WIDTH];
    wire [ADDR_WIDTH-1:0] dest_addr_3 = data_in_i[3*DATA_WIDTH +: ADDR_WIDTH];
    wire [ADDR_WIDTH-1:0] dest_addr_4 = data_in_i[4*DATA_WIDTH +: ADDR_WIDTH];

    // Routing decision signals
    reg [`PORT_ID_WIDTH-1:0] route_decision_0;
    reg [`PORT_ID_WIDTH-1:0] route_decision_1;
    reg [`PORT_ID_WIDTH-1:0] route_decision_2;
    reg [`PORT_ID_WIDTH-1:0] route_decision_3;
    reg [`PORT_ID_WIDTH-1:0] route_decision_4;

    // Configuration interface handling
    assign cfg_ack_o = cfg_valid_i;

    // Configuration register update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            route_algorithm <= `ROUTE_XY;
            route_table <= {(NUM_PORTS*NUM_PORTS){1'b0}};
            port_enable <= {NUM_PORTS{1'b1}};
        end else if (cfg_valid_i) begin
            case (cfg_addr_i)
                `REG_ROUTE_ALGO: route_algorithm <= cfg_data_i[1:0];
                `REG_ROUTE_TABLE: route_table <= cfg_data_i[(NUM_PORTS*NUM_PORTS)-1:0];
                `REG_PORT_CTRL: port_enable <= cfg_data_i[NUM_PORTS-1:0];
            endcase
        end
    end

    // Routing decision logic - replacing function
    always @(*) begin
        // Routing decision for port 0
        case (route_algorithm)
            `ROUTE_XY: route_decision_0 = route_table[0*NUM_PORTS +: NUM_PORTS];
            `ROUTE_WESTFIRST: route_decision_0 = route_table[0*NUM_PORTS +: NUM_PORTS];
            `ROUTE_NORTHLAST: route_decision_0 = route_table[0*NUM_PORTS +: NUM_PORTS];
            `ROUTE_CUSTOM: route_decision_0 = route_table[0*NUM_PORTS +: NUM_PORTS];
            default: route_decision_0 = `PORT_LOCAL;
        endcase

        // Routing decision for port 1
        case (route_algorithm)
            `ROUTE_XY: route_decision_1 = route_table[1*NUM_PORTS +: NUM_PORTS];
            `ROUTE_WESTFIRST: route_decision_1 = route_table[1*NUM_PORTS +: NUM_PORTS];
            `ROUTE_NORTHLAST: route_decision_1 = route_table[1*NUM_PORTS +: NUM_PORTS];
            `ROUTE_CUSTOM: route_decision_1 = route_table[1*NUM_PORTS +: NUM_PORTS];
            default: route_decision_1 = `PORT_LOCAL;
        endcase

        // Routing decision for port 2
        case (route_algorithm)
            `ROUTE_XY: route_decision_2 = route_table[2*NUM_PORTS +: NUM_PORTS];
            `ROUTE_WESTFIRST: route_decision_2 = route_table[2*NUM_PORTS +: NUM_PORTS];
            `ROUTE_NORTHLAST: route_decision_2 = route_table[2*NUM_PORTS +: NUM_PORTS];
            `ROUTE_CUSTOM: route_decision_2 = route_table[2*NUM_PORTS +: NUM_PORTS];
            default: route_decision_2 = `PORT_LOCAL;
        endcase

        // Routing decision for port 3
        case (route_algorithm)
            `ROUTE_XY: route_decision_3 = route_table[3*NUM_PORTS +: NUM_PORTS];
            `ROUTE_WESTFIRST: route_decision_3 = route_table[3*NUM_PORTS +: NUM_PORTS];
            `ROUTE_NORTHLAST: route_decision_3 = route_table[3*NUM_PORTS +: NUM_PORTS];
            `ROUTE_CUSTOM: route_decision_3 = route_table[3*NUM_PORTS +: NUM_PORTS];
            default: route_decision_3 = `PORT_LOCAL;
        endcase

        // Routing decision for port 4
        case (route_algorithm)
            `ROUTE_XY: route_decision_4 = route_table[4*NUM_PORTS +: NUM_PORTS];
            `ROUTE_WESTFIRST: route_decision_4 = route_table[4*NUM_PORTS +: NUM_PORTS];
            `ROUTE_NORTHLAST: route_decision_4 = route_table[4*NUM_PORTS +: NUM_PORTS];
            `ROUTE_CUSTOM: route_decision_4 = route_table[4*NUM_PORTS +: NUM_PORTS];
            default: route_decision_4 = `PORT_LOCAL;
        endcase
    end

    // Buffer management for port 0
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr_0 <= 0;
            read_ptr_0 <= 0;
            buffer_empty_0 <= 1'b1;
            buffer_full_0 <= 1'b0;
        end else begin
            // Write to buffer
            if (data_in_valid_i[0] && data_in_ready_o[0] && port_enable[0]) begin
                input_buffers_0[write_ptr_0] <= data_in_i[0*DATA_WIDTH +: DATA_WIDTH];
                write_ptr_0 <= write_ptr_0 + 1;
                buffer_empty_0 <= 1'b0;

                if (write_ptr_0 + 1 == read_ptr_0) begin
                    buffer_full_0 <= 1'b1;
                end
            end

            // Read from buffer
            if (!buffer_empty_0 && (arbiter_state_0 == `STATE_DATA)) begin
                read_ptr_0 <= read_ptr_0 + 1;
                if (read_ptr_0 + 1 == write_ptr_0) begin
                    buffer_empty_0 <= 1'b1;
                end
                buffer_full_0 <= 1'b0;
            end
        end
    end

    // Buffer management for port 1
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr_1 <= 0;
            read_ptr_1 <= 0;
            buffer_empty_1 <= 1'b1;
            buffer_full_1 <= 1'b0;
        end else begin
            // Write to buffer
            if (data_in_valid_i[1] && data_in_ready_o[1] && port_enable[1]) begin
                input_buffers_1[write_ptr_1] <= data_in_i[1*DATA_WIDTH +: DATA_WIDTH];
                write_ptr_1 <= write_ptr_1 + 1;
                buffer_empty_1 <= 1'b0;

                if (write_ptr_1 + 1 == read_ptr_1) begin
                    buffer_full_1 <= 1'b1;
                end
            end

            // Read from buffer
            if (!buffer_empty_1 && (arbiter_state_1 == `STATE_DATA)) begin
                read_ptr_1 <= read_ptr_1 + 1;
                if (read_ptr_1 + 1 == write_ptr_1) begin
                    buffer_empty_1 <= 1'b1;
                end
                buffer_full_1 <= 1'b0;
            end
        end
    end

    // Buffer management for port 2
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr_2 <= 0;
            read_ptr_2 <= 0;
            buffer_empty_2 <= 1'b1;
            buffer_full_2 <= 1'b0;
        end else begin
            // Write to buffer
            if (data_in_valid_i[2] && data_in_ready_o[2] && port_enable[2]) begin
                input_buffers_2[write_ptr_2] <= data_in_i[2*DATA_WIDTH +: DATA_WIDTH];
                write_ptr_2 <= write_ptr_2 + 1;
                buffer_empty_2 <= 1'b0;

                if (write_ptr_2 + 1 == read_ptr_2) begin
                    buffer_full_2 <= 1'b1;
                end
            end

            // Read from buffer
            if (!buffer_empty_2 && (arbiter_state_2 == `STATE_DATA)) begin
                read_ptr_2 <= read_ptr_2 + 1;
                if (read_ptr_2 + 1 == write_ptr_2) begin
                    buffer_empty_2 <= 1'b1;
                end
                buffer_full_2 <= 1'b0;
            end
        end
    end

    // Buffer management for port 3
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr_3 <= 0;
            read_ptr_3 <= 0;
            buffer_empty_3 <= 1'b1;
            buffer_full_3 <= 1'b0;
        end else begin
            // Write to buffer
            if (data_in_valid_i[3] && data_in_ready_o[3] && port_enable[3]) begin
                input_buffers_3[write_ptr_3] <= data_in_i[3*DATA_WIDTH +: DATA_WIDTH];
                write_ptr_3 <= write_ptr_3 + 1;
                buffer_empty_3 <= 1'b0;

                if (write_ptr_3 + 1 == read_ptr_3) begin
                    buffer_full_3 <= 1'b1;
                end
            end

            // Read from buffer
            if (!buffer_empty_3 && (arbiter_state_3 == `STATE_DATA)) begin
                read_ptr_3 <= read_ptr_3 + 1;
                if (read_ptr_3 + 1 == write_ptr_3) begin
                    buffer_empty_3 <= 1'b1;
                end
                buffer_full_3 <= 1'b0;
            end
        end
    end

    // Buffer management for port 4
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ptr_4 <= 0;
            read_ptr_4 <= 0;
            buffer_empty_4 <= 1'b1;
            buffer_full_4 <= 1'b0;
        end else begin
            // Write to buffer
            if (data_in_valid_i[4] && data_in_ready_o[4] && port_enable[4]) begin
                input_buffers_4[write_ptr_4] <= data_in_i[4*DATA_WIDTH +: DATA_WIDTH];
                write_ptr_4 <= write_ptr_4 + 1;
                buffer_empty_4 <= 1'b0;

                if (write_ptr_4 + 1 == read_ptr_4) begin
                    buffer_full_4 <= 1'b1;
                end
            end

            // Read from buffer
            if (!buffer_empty_4 && (arbiter_state_4 == `STATE_DATA)) begin
                read_ptr_4 <= read_ptr_4 + 1;
                if (read_ptr_4 + 1 == write_ptr_4) begin
                    buffer_empty_4 <= 1'b1;
                end
                buffer_full_4 <= 1'b0;
            end
        end
    end

    // Ready to receive data when buffer is not full
    always @(*) begin
        data_in_ready_o[0] = !buffer_full_0 && port_enable[0];
        data_in_ready_o[1] = !buffer_full_1 && port_enable[1];
        data_in_ready_o[2] = !buffer_full_2 && port_enable[2];
        data_in_ready_o[3] = !buffer_full_3 && port_enable[3];
        data_in_ready_o[4] = !buffer_full_4 && port_enable[4];
    end

    // Arbitration and data forwarding for output port 0
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            arbiter_state_0 <= `STATE_IDLE;
            current_grant_0 <= 0;
            data_out_valid_o[0] <= 1'b0;
            data_out_o[0*DATA_WIDTH +: DATA_WIDTH] <= 0;
        end else begin
            case (arbiter_state_0)
                `STATE_IDLE: begin
                    data_out_valid_o[0] <= 1'b0;

                    // Check if any input ports have data to send to current output port
                    if (!buffer_empty_0 && port_enable[0] && route_decision_0 == 0) begin
                        arbiter_state_0 <= `STATE_ARB;
                        current_grant_0 <= 0;
                    end else if (!buffer_empty_1 && port_enable[1] && route_decision_1 == 0) begin
                        arbiter_state_0 <= `STATE_ARB;
                        current_grant_0 <= 1;
                    end else if (!buffer_empty_2 && port_enable[2] && route_decision_2 == 0) begin
                        arbiter_state_0 <= `STATE_ARB;
                        current_grant_0 <= 2;
                    end else if (!buffer_empty_3 && port_enable[3] && route_decision_3 == 0) begin
                        arbiter_state_0 <= `STATE_ARB;
                        current_grant_0 <= 3;
                    end else if (!buffer_empty_4 && port_enable[4] && route_decision_4 == 0) begin
                        arbiter_state_0 <= `STATE_ARB;
                        current_grant_0 <= 4;
                    end
                end

                `STATE_ARB: begin
                    // Arbitration state, waiting for output port to be ready
                    if (data_out_ready_i[0]) begin
                        arbiter_state_0 <= `STATE_DATA;
                        data_out_valid_o[0] <= 1'b1;

                        // Select data based on granted port
                        case (current_grant_0)
                            0: data_out_o[0*DATA_WIDTH +: DATA_WIDTH] <= input_buffers_0[read_ptr_0];
                            1: data_out_o[0*DATA_WIDTH +: DATA_WIDTH] <= input_buffers_1[read_ptr_1];
                            2: data_out_o[0*DATA_WIDTH +: DATA_WIDTH] <= input_buffers_2[read_ptr_2];
                            3: data_out_o[0*DATA_WIDTH +: DATA_WIDTH] <= input_buffers_3[read_ptr_3];
                            4: data_out_o[0*DATA_WIDTH +: DATA_WIDTH] <= input_buffers_4[read_ptr_4];
                        endcase
                    end
                end

                `STATE_DATA: begin
                    // Data transfer state
                    if (data_out_ready_i[0]) begin
                        data_out_valid_o[0] <= 1'b0;
                        arbiter_state_0 <= `STATE_IDLE;
                    end
                end
            endcase
        end
    end

    // Arbitration and data forwarding for output port 1 (similar to port 0, omitted for brevity)
    // Arbitration and data forwarding for output port 2
    // Arbitration and data forwarding for output port 3
    // Arbitration and data forwarding for output port 4

    // Status monitoring
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            status_o <= 0;
        end else begin
            // Summarize status information
            status_o <= {
                buffer_empty_0, buffer_empty_1, buffer_empty_2, buffer_empty_3, buffer_empty_4,
                buffer_full_0, buffer_full_1, buffer_full_2, buffer_full_3, buffer_full_4,
                port_enable,
                4'b0
            };
        end
    end

endmodule