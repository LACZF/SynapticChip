`include "jtag.v"
module jtag #(
    parameter ADDR_WIDTH            = 64,
    parameter DATA_WIDTH            = 64,
    parameter INST_WIDTH            = 32
)(
    input                           clk,
    input                           rst_n,

    // JTAG interface
    input                           tck_i,      // JTAG test clock
    input                           tms_i,      // JTAG test mode select
    input                           tdi_i,      // JTAG test data input
    output reg                      tdo_o,      // JTAG test data output
    output reg                      tdo_en_o,   // JTAG test data output enable

    // Control interface
    input                           req_i,
    input                           we_i,
    input       [ADDR_WIDTH-1:0]    addr_i,
    input       [DATA_WIDTH-1:0]    data_in_i,
    output reg  [DATA_WIDTH-1:0]    data_out_o,
    output reg                      ack_o,

    // Debug interface
    output reg  [DATA_WIDTH-1:0]    debug_data_o,
    output reg                      debug_valid_o
);

    // TAP state machine state register
    reg [3:0] tap_state;
    reg [3:0] next_tap_state;

    // Instruction register
    reg [INST_WIDTH-1:0] instruction_reg;
    reg [INST_WIDTH-1:0] next_instruction;

    // Data register
    reg [DATA_WIDTH-1:0] data_reg;
    reg [DATA_WIDTH-1:0] next_data;

    // Shift register
    reg [DATA_WIDTH-1:0] shift_reg;
    reg [DATA_WIDTH-1:0] next_shift_reg;

    // Counter
    reg [5:0] bit_count;
    reg [5:0] next_bit_count;

    // IDCODE value
    parameter IDCODE_VALUE = 32'h12345678;

    // TAP state machine transitions
    always @(posedge tck_i or negedge rst_n) begin
        if (!rst_n) begin
            tap_state <= `TEST_LOGIC_RESET;
        end else begin
            tap_state <= next_tap_state;
        end
    end

    // TAP state machine combinational logic
    always @(*) begin
        next_tap_state = tap_state;

        case (tap_state)
            `TEST_LOGIC_RESET: next_tap_state = tms_i ? `TEST_LOGIC_RESET : `RUN_TEST_IDLE;
            `RUN_TEST_IDLE:    next_tap_state = tms_i ? `SELECT_DR_SCAN : `RUN_TEST_IDLE;
            `SELECT_DR_SCAN:   next_tap_state = tms_i ? `SELECT_IR_SCAN : `CAPTURE_DR;
            `CAPTURE_DR:       next_tap_state = tms_i ? `EXIT1_DR : `SHIFT_DR;
            `SHIFT_DR:         next_tap_state = tms_i ? `EXIT1_DR : `SHIFT_DR;
            `EXIT1_DR:         next_tap_state = tms_i ? `UPDATE_DR : `PAUSE_DR;
            `PAUSE_DR:         next_tap_state = tms_i ? `EXIT2_DR : `PAUSE_DR;
            `EXIT2_DR:         next_tap_state = tms_i ? `UPDATE_DR : `SHIFT_DR;
            `UPDATE_DR:        next_tap_state = tms_i ? `SELECT_DR_SCAN : `RUN_TEST_IDLE;
            `SELECT_IR_SCAN:   next_tap_state = tms_i ? `TEST_LOGIC_RESET : `CAPTURE_IR;
            `CAPTURE_IR:       next_tap_state = tms_i ? `EXIT1_IR : `SHIFT_IR;
            `SHIFT_IR:         next_tap_state = tms_i ? `EXIT1_IR : `SHIFT_IR;
            `EXIT1_IR:         next_tap_state = tms_i ? `UPDATE_IR : `PAUSE_IR;
            `PAUSE_IR:         next_tap_state = tms_i ? `EXIT2_IR : `PAUSE_IR;
            `EXIT2_IR:         next_tap_state = tms_i ? `UPDATE_IR : `SHIFT_IR;
            `UPDATE_IR:        next_tap_state = tms_i ? `SELECT_DR_SCAN : `RUN_TEST_IDLE;
        endcase
    end

    // Instruction register update
    always @(posedge tck_i or negedge rst_n) begin
        if (!rst_n) begin
            instruction_reg <= `BYPASS;
        end else if (tap_state == `UPDATE_IR) begin
            instruction_reg <= next_instruction;
        end
    end

    // Data register update
    always @(posedge tck_i or negedge rst_n) begin
        if (!rst_n) begin
            data_reg <= 0;
        end else if (tap_state == `UPDATE_DR) begin
            data_reg <= next_data;
        end
    end

    // Shift register handling
    always @(posedge tck_i or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 0;
            bit_count <= 0;
        end else begin
            shift_reg <= next_shift_reg;
            bit_count <= next_bit_count;
        end
    end

    // Shift logic
    always @(*) begin
        next_shift_reg = shift_reg;
        next_bit_count = bit_count;
        next_instruction = instruction_reg;
        next_data = data_reg;
        tdo_o = 1'b0;
        tdo_en_o = 1'b0;

        case (tap_state)
            `CAPTURE_DR: begin
                // Capture data stage
                case (instruction_reg)
                    `IDCODE: next_shift_reg = IDCODE_VALUE;
                    `BYPASS: next_shift_reg = 1'b0;
                    default: next_shift_reg = data_reg;
                endcase
                next_bit_count = 0;
            end

            `SHIFT_DR: begin
                // Shift data stage
                tdo_o = shift_reg[0];
                tdo_en_o = 1'b1;
                next_shift_reg = {tdi_i, shift_reg[DATA_WIDTH-1:1]};
                next_bit_count = bit_count + 1;
            end

            `UPDATE_DR: begin
                // Update data stage
                next_data = shift_reg;
            end

            `CAPTURE_IR: begin
                // Capture instruction stage
                next_shift_reg = {4'b0001, {(DATA_WIDTH-4){1'b0}}}; // Fixed pattern
                next_bit_count = 0;
            end

            `SHIFT_IR: begin
                // Shift instruction stage
                tdo_o = shift_reg[0];
                tdo_en_o = 1'b1;
                next_shift_reg = {tdi_i, shift_reg[DATA_WIDTH-1:1]};
                next_bit_count = bit_count + 1;
            end

            `UPDATE_IR: begin
                // Update instruction stage
                next_instruction = shift_reg[INST_WIDTH-1:0];
            end
        endcase
    end

    // Bus interface handling
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out_o <= 0;
            ack_o <= 0;
            debug_data_o <= 0;
            debug_valid_o <= 0;
        end else begin
            ack_o <= 0;
            debug_valid_o <= 0;

            if (req_i) begin
                ack_o <= 1;

                if (we_i) begin
                    // Write operation
                    case (addr_i)
                        `REG_JTAG_CTRL: begin
                            // Control register write
                            // Control logic can be added here
                        end
                        `REG_JTAG_DATA: begin
                            // Data register write
                            data_reg <= data_in_i;
                            debug_data_o <= data_in_i;
                            debug_valid_o <= 1;
                        end
                    endcase
                end else begin
                    // Read operation
                    case (addr_i)
                        `REG_JTAG_CTRL: data_out_o <= {28'b0, tap_state}; // Return TAP state
                        `REG_JTAG_DATA: data_out_o <= data_reg; // Return data register value
                        `REG_JTAG_STAT: data_out_o <= {31'b0, tdo_en_o}; // Return status
                    endcase
                end
            end
        end
    end

endmodule