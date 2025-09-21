// riscv_core.v
// 简化的RISC-V核心实现

`include "riscv_core_params.v"

module riscv_core (
    input clk,
    input rst_n,

    // 指令存储器接口
    output reg [`ADDR_WIDTH-1:0] inst_addr,
    input [`INST_WIDTH-1:0] inst_data,
    output inst_req,
    input inst_ack,

    // 数据存储器接口（通过Ring总线）
    output reg data_req,
    output reg [`ADDR_WIDTH-1:0] data_addr,
    output reg [`DATA_WIDTH-1:0] data_out,
    input [`DATA_WIDTH-1:0] data_in,
    input data_ack,
    output reg data_we,
    output reg [3:0] data_be  // 字节使能
);

    // 寄存器文件
    reg [`XLEN-1:0] reg_file [0:`REG_COUNT-1];

    // 程序计数器
    reg [`ADDR_WIDTH-1:0] pc;
    reg [`ADDR_WIDTH-1:0] next_pc;

    // 指令寄存器
    reg [`INST_WIDTH-1:0] instruction;

    // 控制信号
    wire [6:0] opcode = instruction[6:0];
    wire [2:0] funct3 = instruction[14:12];
    wire [6:0] funct7 = instruction[31:25];
    wire [4:0] rs1 = instruction[19:15];
    wire [4:0] rs2 = instruction[24:20];
    wire [4:0] rd = instruction[11:7];

    // 立即数
    wire [`XLEN-1:0] i_imm = {{21{instruction[31]}}, instruction[30:20]};
    wire [`XLEN-1:0] s_imm = {{21{instruction[31]}}, instruction[30:25], instruction[11:7]};
    wire [`XLEN-1:0] b_imm = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
    wire [`XLEN-1:0] u_imm = {instruction[31:12], 12'b0};
    wire [`XLEN-1:0] j_imm = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};

    // 寄存器值
    wire [`XLEN-1:0] rs1_val = (rs1 != 0) ? reg_file[rs1] : 0;
    wire [`XLEN-1:0] rs2_val = (rs2 != 0) ? reg_file[rs2] : 0;

    // ALU操作
    reg [`XLEN-1:0] alu_out;
    reg alu_zero;

    // 状态机
    reg [2:0] state;
    parameter S_FETCH = 3'b000;
    parameter S_DECODE = 3'b001;
    parameter S_EXECUTE = 3'b010;
    parameter S_MEM = 3'b011;
    parameter S_WRITEBACK = 3'b100;

    // 指令请求
    assign inst_req = (state == S_FETCH);

    // 状态转移
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_FETCH;
            pc <= `MEM_BASE;
            inst_addr <= `MEM_BASE;
            data_req <= 0;
            data_we <= 0;
        end else begin
            case (state)
                S_FETCH: begin
                    if (inst_ack) begin
                        instruction <= inst_data;
                        state <= S_DECODE;
                    end
                    inst_addr <= pc;
                end

                S_DECODE: begin
                    state <= S_EXECUTE;
                end

                S_EXECUTE: begin
                    case (opcode)
                        `OPCODE_LOAD, `OPCODE_STORE: begin
                            data_addr <= rs1_val + (opcode == `OPCODE_LOAD ? i_imm : s_imm);
                            data_we <= (opcode == `OPCODE_STORE);
                            data_req <= 1;
                            data_out <= rs2_val;

                            // 设置字节使能
                            case (funct3)
                                3'b000: data_be <= 4'b0001; // LB/SB
                                3'b001: data_be <= 4'b0011; // LH/SH
                                3'b010: data_be <= 4'b1111; // LW/SW
                                default: data_be <= 4'b1111;
                            endcase

                            state <= S_MEM;
                        end

                        `OPCODE_OP, `OPCODE_OP_IMM: begin
                            // ALU操作
                            case (funct3)
                                `FUNCT3_ADD_SUB:
                                    if (opcode == `OPCODE_OP_IMM)
                                        alu_out <= rs1_val + i_imm;
                                    else if (funct7[5])
                                        alu_out <= rs1_val - rs2_val;
                                    else
                                        alu_out <= rs1_val + rs2_val;

                                `FUNCT3_SLL:
                                    alu_out <= rs1_val << (opcode == `OPCODE_OP_IMM ? i_imm[4:0] : rs2_val[4:0]);

                                `FUNCT3_SLT:
                                    alu_out <= ($signed(rs1_val) < $signed(opcode == `OPCODE_OP_IMM ? i_imm : rs2_val)) ? 1 : 0;

                                `FUNCT3_SLTU:
                                    alu_out <= (rs1_val < (opcode == `OPCODE_OP_IMM ? i_imm : rs2_val)) ? 1 : 0;

                                `FUNCT3_XOR:
                                    alu_out <= rs1_val ^ (opcode == `OPCODE_OP_IMM ? i_imm : rs2_val);

                                `FUNCT3_SRL_SRA:
                                    if (funct7[5] && opcode == `OPCODE_OP)
                                        alu_out <= $signed(rs1_val) >>> (rs2_val[4:0]); // SRA
                                    else
                                        alu_out <= rs1_val >> (opcode == `OPCODE_OP_IMM ? i_imm[4:0] : rs2_val[4:0]); // SRL

                                `FUNCT3_OR:
                                    alu_out <= rs1_val | (opcode == `OPCODE_OP_IMM ? i_imm : rs2_val);

                                `FUNCT3_AND:
                                    alu_out <= rs1_val & (opcode == `OPCODE_OP_IMM ? i_imm : rs2_val);
                            endcase

                            state <= S_WRITEBACK;
                        end

                        `OPCODE_BRANCH: begin
                            // 分支指令
                            case (funct3)
                                3'b000: alu_zero = (rs1_val == rs2_val); // BEQ
                                3'b001: alu_zero = (rs1_val != rs2_val); // BNE
                                3'b100: alu_zero = ($signed(rs1_val) < $signed(rs2_val)); // BLT
                                3'b101: alu_zero = ($signed(rs1_val) >= $signed(rs2_val)); // BGE
                                3'b110: alu_zero = (rs1_val < rs2_val); // BLTU
                                3'b111: alu_zero = (rs1_val >= rs2_val); // BGEU
                            endcase

                            next_pc = alu_zero ? pc + b_imm : pc + 4;
                            state <= S_FETCH;
                        end

                        `OPCODE_JAL: begin
                            // 跳转并链接
                            reg_file[rd] <= pc + 4;
                            next_pc <= pc + j_imm;
                            state <= S_FETCH;
                        end

                        `OPCODE_JALR: begin
                            // 跳转并链接寄存器
                            reg_file[rd] <= pc + 4;
                            next_pc <= (rs1_val + i_imm) & ~1;
                            state <= S_FETCH;
                        end

                        `OPCODE_AUIPC: begin
                            // 加上高位立即数到PC
                            alu_out <= pc + u_imm;
                            state <= S_WRITEBACK;
                        end

                        `OPCODE_LUI: begin
                            // 加载高位立即数
                            alu_out <= u_imm;
                            state <= S_WRITEBACK;
                        end
                    endcase
                end

                S_MEM: begin
                    if (data_ack) begin
                        data_req <= 0;

                        if (opcode == `OPCODE_LOAD) begin
                            // 加载指令处理
                            case (funct3)
                                3'b000: reg_file[rd] <= {{24{data_in[7]}}, data_in[7:0]}; // LB
                                3'b001: reg_file[rd] <= {{16{data_in[15]}}, data_in[15:0]}; // LH
                                3'b010: reg_file[rd] <= data_in; // LW
                                3'b100: reg_file[rd] <= {24'b0, data_in[7:0]}; // LBU
                                3'b101: reg_file[rd] <= {16'b0, data_in[15:0]}; // LHU
                                default: reg_file[rd] <= data_in;
                            endcase
                        end

                        state <= S_FETCH;
                        next_pc <= pc + 4;
                    end
                end

                S_WRITEBACK: begin
                    if (rd != 0) begin
                        reg_file[rd] <= alu_out;
                    end

                    state <= S_FETCH;
                    next_pc <= pc + 4;
                end
            endcase

            // 更新PC
            if (state == S_FETCH) begin
                pc <= next_pc;
            end
        end
    end

endmodule
