// pe_core.v
// PE核心模块实现

`include "pe_params.v"

module pe_core #(
    parameter ADDR_WIDTH        = 32,
    parameter DATA_WIDTH        = 64,
    parameter NUM_PES           = 4,
    parameter INST_WIDTH        = 128,
    parameter PE_ID_WIDTH       = 3,
    parameter PE_ARRAY_ROWS     = 2,
    parameter PE_ARRAY_COLS     = 2
) (
    input clk,
    input rst_n,
    input enable,

    // 指令接口
    input [INST_WIDTH-1:0] instruction,
    input inst_valid,

    // 数据存储器接口
    output mem_req,
    output mem_we,
    output [ADDR_WIDTH-1:0] mem_addr,
    output [DATA_WIDTH-1:0] mem_data_out,
    input [DATA_WIDTH-1:0] mem_data_in,
    input mem_ack,

    // 邻居PE通信接口
    input north_valid,
    input [DATA_WIDTH-1:0] north_data,
    output north_ready,

    input south_valid,
    input [DATA_WIDTH-1:0] south_data,
    output south_ready,

    input east_valid,
    input [DATA_WIDTH-1:0] east_data,
    output east_ready,

    input west_valid,
    input [DATA_WIDTH-1:0] west_data,
    output west_ready,

    output reg out_valid,
    output reg [DATA_WIDTH-1:0] out_data,

    // 状态输出
    output reg [DATA_WIDTH-1:0] status,
    output reg busy
);

    // 内部寄存器文件
    reg [DATA_WIDTH-1:0] reg_file [0:`NUM_REGS-1];

    // 指令解码
    wire [`OPCODE_WIDTH-1:0] opcode = instruction[31:26];
    wire [`REG_ADDR_WIDTH-1:0] rd = instruction[25:22];
    wire [`REG_ADDR_WIDTH-1:0] rs1 = instruction[21:18];
    wire [`REG_ADDR_WIDTH-1:0] rs2 = instruction[17:14];
    wire [13:0] immediate = instruction[13:0];

    // 内部信号
    reg [DATA_WIDTH-1:0] alu_out;
    reg [DATA_WIDTH-1:0] alu_a, alu_b;
    reg alu_zero, alu_neg;

    // 状态寄存器
    reg [1:0] mode;
    reg [DATA_WIDTH-1:0] pc; // 程序计数器
    reg [DATA_WIDTH-1:0] mar; // 存储器地址寄存器
    reg [DATA_WIDTH-1:0] mdr; // 存储器数据寄存器

    // 通信缓冲区
    reg [DATA_WIDTH-1:0] comm_buffer [0:3]; // 0:北, 1:南, 2:东, 3:西
    reg comm_ready [0:3];

    // 状态机
    reg [2:0] state;
    parameter S_IDLE = 3'b000;
    parameter S_FETCH = 3'b001;
    parameter S_DECODE = 3'b010;
    parameter S_EXECUTE = 3'b011;
    parameter S_MEMORY = 3'b100;
    parameter S_COMM = 3'b101;

    // ALU操作
    always @(*) begin
        alu_zero = 0;
        alu_neg = 0;

        case (opcode)
            `OP_ADD: alu_out = alu_a + alu_b;
            `OP_SUB: alu_out = alu_a - alu_b;
            `OP_MUL: alu_out = alu_a * alu_b;
            `OP_AND: alu_out = alu_a & alu_b;
            `OP_OR:  alu_out = alu_a | alu_b;
            `OP_XOR: alu_out = alu_a ^ alu_b;
            `OP_NOT: alu_out = ~alu_a;
            `OP_SHL: alu_out = alu_a << alu_b[3:0];
            `OP_SHR: alu_out = alu_a >> alu_b[3:0];
            default: alu_out = 0;
        endcase

        if (alu_out == 0) alu_zero = 1;
        if (alu_out[DATA_WIDTH-1]) alu_neg = 1;
    end

    // 主状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            mode <= `MODE_IDLE;
            pc <= 0;
            mar <= 0;
            mdr <= 0;
            out_valid <= 0;
            out_data <= 0;
            busy <= 0;
            status <= 0;

            // 初始化寄存器文件
            for (integer i = 0; i < `NUM_REGS; i = i + 1) begin
                reg_file[i] <= 0;
            end

            // 初始化通信缓冲区
            for (integer j = 0; j < 4; j = j + 1) begin
                comm_buffer[j] <= 0;
                comm_ready[j] <= 0;
            end
        end else if (enable) begin
            case (state)
                S_IDLE: begin
                    busy <= 0;
                    if (inst_valid) begin
                        state <= S_FETCH;
                        busy <= 1;
                    end
                end

                S_FETCH: begin
                    // 指令已输入，直接解码
                    state <= S_DECODE;
                end

                S_DECODE: begin
                    // 准备操作数
                    alu_a <= reg_file[rs1];
                    alu_b <= (opcode == `OP_LOAD || opcode == `OP_STORE ||
                             opcode == `OP_JUMP || opcode[5:4] == 2'b01) ?
                             {{(DATA_WIDTH-14){immediate[13]}}, immediate} :
                             reg_file[rs2];

                    // 设置存储器地址（用于LOAD/STORE）
                    if (opcode == `OP_LOAD || opcode == `OP_STORE) begin
                        mar <= reg_file[rs1] + {{(DATA_WIDTH-14){immediate[13]}}, immediate};
                    end

                    state <= S_EXECUTE;
                end

                S_EXECUTE: begin
                    case (opcode)
                        `OP_ADD, `OP_SUB, `OP_MUL, `OP_AND, `OP_OR, `OP_XOR,
                        `OP_NOT, `OP_SHL, `OP_SHR: begin
                            // 算术/逻辑运算
                            reg_file[rd] <= alu_out;
                            state <= S_IDLE;
                        end

                        `OP_LOAD: begin
                            // 存储器读取
                            mdr <= mem_data_in;
                            if (mem_ack) begin
                                reg_file[rd] <= mem_data_in;
                                state <= S_IDLE;
                            end else begin
                                state <= S_MEMORY;
                            end
                        end

                        `OP_STORE: begin
                            // 存储器写入
                            mdr <= reg_file[rs2];
                            if (mem_ack) begin
                                state <= S_IDLE;
                            end else begin
                                state <= S_MEMORY;
                            end
                        end

                        `OP_MOVE: begin
                            // 寄存器间移动
                            reg_file[rd] <= reg_file[rs1];
                            state <= S_IDLE;
                        end

                        `OP_JUMP: begin
                            // 无条件跳转
                            pc <= reg_file[rs1] + {{(DATA_WIDTH-14){immediate[13]}}, immediate};
                            state <= S_IDLE;
                        end

                        `OP_BEQ: begin
                            // 条件跳转：相等
                            if (alu_zero) begin
                                pc <= reg_file[rs1] + {{(DATA_WIDTH-14){immediate[13]}}, immediate};
                            end
                            state <= S_IDLE;
                        end

                        `OP_BNE: begin
                            // 条件跳转：不相等
                            if (!alu_zero) begin
                                pc <= reg_file[rs1] + {{(DATA_WIDTH-14){immediate[13]}}, immediate};
                            end
                            state <= S_IDLE;
                        end

                        `OP_BLT: begin
                            // 条件跳转：小于
                            if (alu_neg) begin
                                pc <= reg_file[rs1] + {{(DATA_WIDTH-14){immediate[13]}}, immediate};
                            end
                            state <= S_IDLE;
                        end

                        `OP_BGT: begin
                            // 条件跳转：大于
                            if (!alu_neg && !alu_zero) begin
                                pc <= reg_file[rs1] + {{(DATA_WIDTH-14){immediate[13]}}, immediate};
                            end
                            state <= S_IDLE;
                        end

                        default: begin
                            // NOP或其他未定义操作
                            state <= S_IDLE;
                        end
                    endcase
                end

                S_MEMORY: begin
                    // 处理存储器访问
                    if (mem_ack) begin
                        if (opcode == `OP_LOAD) begin
                            reg_file[rd] <= mdr;
                        end
                        state <= S_IDLE;
                    end
                end

                S_COMM: begin
                    // 处理通信
                    // 这里简化处理，实际实现会更复杂
                    state <= S_IDLE;
                end
            endcase

            // 处理通信输入
            if (north_valid && north_ready) begin
                comm_buffer[0] <= north_data;
                comm_ready[0] <= 1;
            end

            if (south_valid && south_ready) begin
                comm_buffer[1] <= south_data;
                comm_ready[1] <= 1;
            end

            if (east_valid && east_ready) begin
                comm_buffer[2] <= east_data;
                comm_ready[2] <= 1;
            end

            if (west_valid && west_ready) begin
                comm_buffer[3] <= west_data;
                comm_ready[3] <= 1;
            end
        end
    end

    // 存储器接口
    assign mem_req = (state == S_EXECUTE && (opcode == `OP_LOAD || opcode == `OP_STORE)) ||
                    (state == S_MEMORY);
    assign mem_we = (opcode == `OP_STORE);
    assign mem_addr = mar[ADDR_WIDTH-1:0];
    assign mem_data_out = mdr;

    // 通信接口
    assign north_ready = !comm_ready[0];
    assign south_ready = !comm_ready[1];
    assign east_ready = !comm_ready[2];
    assign west_ready = !comm_ready[3];

endmodule
