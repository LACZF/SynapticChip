// jtag_tap.v
// JTAG TAP控制器实现

`include "jtag_params.v"

module jtag_tap (
    input clk,
    input rst_n,

    // JTAG接口
    input tck,      // JTAG测试时钟
    input tms,      // JTAG测试模式选择
    input tdi,      // JTAG测试数据输入
    output reg tdo, // JTAG测试数据输出
    output reg tdo_en, // JTAG测试数据输出使能

    // 控制接口
    input req,
    input we,
    input [`ADDR_WIDTH-1:0] addr,
    input [`DATA_WIDTH-1:0] data_in,
    output reg [`DATA_WIDTH-1:0] data_out,
    output reg ack,

    // 调试接口
    output reg [`DATA_WIDTH-1:0] debug_data,
    output reg debug_valid
);

    // TAP状态机状态寄存器
    reg [3:0] tap_state;
    reg [3:0] next_tap_state;

    // 指令寄存器
    reg [`INSTR_WIDTH-1:0] instruction_reg;
    reg [`INSTR_WIDTH-1:0] next_instruction;

    // 数据寄存器
    reg [`DATA_WIDTH-1:0] data_reg;
    reg [`DATA_WIDTH-1:0] next_data;

    // 移位寄存器
    reg [`DATA_WIDTH-1:0] shift_reg;
    reg [`DATA_WIDTH-1:0] next_shift_reg;

    // 计数器
    reg [5:0] bit_count;
    reg [5:0] next_bit_count;

    // IDCODE值
    parameter IDCODE_VALUE = 32'h12345678;

    // TAP状态机转换
    always @(posedge tck or negedge rst_n) begin
        if (!rst_n) begin
            tap_state <= `TEST_LOGIC_RESET;
        end else begin
            tap_state <= next_tap_state;
        end
    end

    // TAP状态机组合逻辑
    always @(*) begin
        next_tap_state = tap_state;

        case (tap_state)
            `TEST_LOGIC_RESET: next_tap_state = tms ? `TEST_LOGIC_RESET : `RUN_TEST_IDLE;
            `RUN_TEST_IDLE:    next_tap_state = tms ? `SELECT_DR_SCAN : `RUN_TEST_IDLE;
            `SELECT_DR_SCAN:   next_tap_state = tms ? `SELECT_IR_SCAN : `CAPTURE_DR;
            `CAPTURE_DR:       next_tap_state = tms ? `EXIT1_DR : `SHIFT_DR;
            `SHIFT_DR:         next_tap_state = tms ? `EXIT1_DR : `SHIFT_DR;
            `EXIT1_DR:         next_tap_state = tms ? `UPDATE_DR : `PAUSE_DR;
            `PAUSE_DR:         next_tap_state = tms ? `EXIT2_DR : `PAUSE_DR;
            `EXIT2_DR:         next_tap_state = tms ? `UPDATE_DR : `SHIFT_DR;
            `UPDATE_DR:        next_tap_state = tms ? `SELECT_DR_SCAN : `RUN_TEST_IDLE;
            `SELECT_IR_SCAN:   next_tap_state = tms ? `TEST_LOGIC_RESET : `CAPTURE_IR;
            `CAPTURE_IR:       next_tap_state = tms ? `EXIT1_IR : `SHIFT_IR;
            `SHIFT_IR:         next_tap_state = tms ? `EXIT1_IR : `SHIFT_IR;
            `EXIT1_IR:         next_tap_state = tms ? `UPDATE_IR : `PAUSE_IR;
            `PAUSE_IR:         next_tap_state = tms ? `EXIT2_IR : `PAUSE_IR;
            `EXIT2_IR:         next_tap_state = tms ? `UPDATE_IR : `SHIFT_IR;
            `UPDATE_IR:        next_tap_state = tms ? `SELECT_DR_SCAN : `RUN_TEST_IDLE;
        endcase
    end

    // 指令寄存器更新
    always @(posedge tck or negedge rst_n) begin
        if (!rst_n) begin
            instruction_reg <= `BYPASS;
        end else if (tap_state == `UPDATE_IR) begin
            instruction_reg <= next_instruction;
        end
    end

    // 数据寄存器更新
    always @(posedge tck or negedge rst_n) begin
        if (!rst_n) begin
            data_reg <= 0;
        end else if (tap_state == `UPDATE_DR) begin
            data_reg <= next_data;
        end
    end

    // 移位寄存器处理
    always @(posedge tck or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= 0;
            bit_count <= 0;
        end else begin
            shift_reg <= next_shift_reg;
            bit_count <= next_bit_count;
        end
    end

    // 移位逻辑
    always @(*) begin
        next_shift_reg = shift_reg;
        next_bit_count = bit_count;
        next_instruction = instruction_reg;
        next_data = data_reg;
        tdo = 1'b0;
        tdo_en = 1'b0;

        case (tap_state)
            `CAPTURE_DR: begin
                // 捕获数据阶段
                case (instruction_reg)
                    `IDCODE: next_shift_reg = IDCODE_VALUE;
                    `BYPASS: next_shift_reg = 1'b0;
                    default: next_shift_reg = data_reg;
                endcase
                next_bit_count = 0;
            end

            `SHIFT_DR: begin
                // 移位数据阶段
                tdo = shift_reg[0];
                tdo_en = 1'b1;
                next_shift_reg = {tdi, shift_reg[`DATA_WIDTH-1:1]};
                next_bit_count = bit_count + 1;
            end

            `UPDATE_DR: begin
                // 更新数据阶段
                next_data = shift_reg;
            end

            `CAPTURE_IR: begin
                // 捕获指令阶段
                next_shift_reg = {4'b0001, {(`DATA_WIDTH-4){1'b0}}}; // 固定模式
                next_bit_count = 0;
            end

            `SHIFT_IR: begin
                // 移位指令阶段
                tdo = shift_reg[0];
                tdo_en = 1'b1;
                next_shift_reg = {tdi, shift_reg[`DATA_WIDTH-1:1]};
                next_bit_count = bit_count + 1;
            end

            `UPDATE_IR: begin
                // 更新指令阶段
                next_instruction = shift_reg[`INSTR_WIDTH-1:0];
            end
        endcase
    end

    // 总线接口处理
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 0;
            ack <= 0;
            debug_data <= 0;
            debug_valid <= 0;
        end else begin
            ack <= 0;
            debug_valid <= 0;

            if (req) begin
                ack <= 1;

                if (we) begin
                    // 写操作
                    case (addr)
                        `REG_JTAG_CTRL: begin
                            // 控制寄存器写入
                            // 这里可以添加控制逻辑
                        end
                        `REG_JTAG_DATA: begin
                            // 数据寄存器写入
                            data_reg <= data_in;
                            debug_data <= data_in;
                            debug_valid <= 1;
                        end
                    endcase
                end else begin
                    // 读操作
                    case (addr)
                        `REG_JTAG_CTRL: data_out <= {28'b0, tap_state}; // 返回TAP状态
                        `REG_JTAG_DATA: data_out <= data_reg; // 返回数据寄存器值
                        `REG_JTAG_STAT: data_out <= {31'b0, tdo_en}; // 返回状态
                    endcase
                end
            end
        end
    end

endmodule
