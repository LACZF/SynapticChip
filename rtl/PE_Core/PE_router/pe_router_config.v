
`include "pe_router.v"

module router_config #(
    parameter ADDR_WIDTH             = 64,
    parameter DATA_WIDTH             = 64,
    parameter NUM_PORTS              = 4
) (
    input                            clk,
    input                            rst_n,

    // Configuration bus interface
    input                            cfg_valid_i,
    input       [ADDR_WIDTH-1:0]     cfg_addr_i,
    input       [DATA_WIDTH-1:0]     cfg_data_i,
    output                           cfg_ack_o,

    // Configuration outputs to router core
    output reg                       route_cfg_valid_o,
    output reg  [ADDR_WIDTH-1:0]     route_cfg_addr_o,
    output reg  [DATA_WIDTH-1:0]     route_cfg_data_o,
    input                            route_cfg_ack_i,

    // Status inputs
    input       [DATA_WIDTH-1:0]     route_status_i,
    output reg  [DATA_WIDTH-1:0]     status_out_o
);

    // Configuration registers
    reg [DATA_WIDTH-1:0] config_registers_0;
    reg [DATA_WIDTH-1:0] config_registers_1;
    reg [DATA_WIDTH-1:0] config_registers_2;
    reg [DATA_WIDTH-1:0] config_registers_3;
    reg [DATA_WIDTH-1:0] config_registers_4;
    reg [DATA_WIDTH-1:0] config_registers_5;
    reg [DATA_WIDTH-1:0] config_registers_6;
    reg [DATA_WIDTH-1:0] config_registers_7;
    reg [DATA_WIDTH-1:0] config_registers_8;
    reg [DATA_WIDTH-1:0] config_registers_9;
    reg [DATA_WIDTH-1:0] config_registers_10;
    reg [DATA_WIDTH-1:0] config_registers_11;
    reg [DATA_WIDTH-1:0] config_registers_12;
    reg [DATA_WIDTH-1:0] config_registers_13;
    reg [DATA_WIDTH-1:0] config_registers_14;
    reg [DATA_WIDTH-1:0] config_registers_15;

    // State machine
    reg [1:0] state;

    // Configuration interface handling
    assign cfg_ack_o = (state == `STATE_ACK);

    // Configuration interface state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= `STATE_IDLE;
            route_cfg_valid_o <= 1'b0;
            route_cfg_addr_o <= 0;
            route_cfg_data_o <= 0;
            status_out_o <= 0;

            // Initialize configuration registers
            config_registers_0 <= 0;
            config_registers_1 <= 0;
            config_registers_2 <= 0;
            config_registers_3 <= 0;
            config_registers_4 <= 0;
            config_registers_5 <= 0;
            config_registers_6 <= 0;
            config_registers_7 <= 0;
            config_registers_8 <= 0;
            config_registers_9 <= 0;
            config_registers_10 <= 0;
            config_registers_11 <= 0;
            config_registers_12 <= 0;
            config_registers_13 <= 0;
            config_registers_14 <= 0;
            config_registers_15 <= 0;
        end else begin
            case (state)
                `STATE_IDLE: begin
                    route_cfg_valid_o <= 1'b0;

                    if (cfg_valid_i) begin
                        if (cfg_addr_i < 16) begin
                            // Local configuration register access
                            case (cfg_addr_i)
                                0: config_registers_0 <= cfg_data_i;
                                1: config_registers_1 <= cfg_data_i;
                                2: config_registers_2 <= cfg_data_i;
                                3: config_registers_3 <= cfg_data_i;
                                4: config_registers_4 <= cfg_data_i;
                                5: config_registers_5 <= cfg_data_i;
                                6: config_registers_6 <= cfg_data_i;
                                7: config_registers_7 <= cfg_data_i;
                                8: config_registers_8 <= cfg_data_i;
                                9: config_registers_9 <= cfg_data_i;
                                10: config_registers_10 <= cfg_data_i;
                                11: config_registers_11 <= cfg_data_i;
                                12: config_registers_12 <= cfg_data_i;
                                13: config_registers_13 <= cfg_data_i;
                                14: config_registers_14 <= cfg_data_i;
                                15: config_registers_15 <= cfg_data_i;
                            endcase
                            state <= `STATE_ACK;
                        end else begin
                            // Router core configuration access
                            route_cfg_valid_o <= 1'b1;
                            route_cfg_addr_o <= cfg_addr_i;
                            route_cfg_data_o <= cfg_data_i;
                            state <= `STATE_DATA;
                        end
                    end

                    // Update status output
                    status_out_o <= route_status_i;
                end

                `STATE_DATA: begin
                    if (route_cfg_ack_i) begin
                        route_cfg_valid_o <= 1'b0;
                        state <= `STATE_ACK;
                    end
                end

                `STATE_ACK: begin
                    state <= `STATE_IDLE;
                end
            endcase
        end
    end

endmodule