// write_back.v
module write_back (
    input wire clk,
    input wire rst_n,
    input wire stall,

    // 来自内存访问阶段
    input wire [63:0] pc_in,
    input wire [31:0] instr_in,
    input wire [63:0] alu_result,    // ALU运算结果
    input wire [63:0] mem_result,    // 内存读取结果
    input wire [15:0] ctrl_in,

    // 输出到寄存器文件
    output reg [4:0] rd,
    output reg reg_we,
    output reg [63:0] reg_wdata,

    // 流水线传递（用于调试）
    output reg [63:0] pc_out
);

    // 控制信号解码
    wire reg_write = ctrl_in[10];    // 寄存器写使能
    wire mem_to_reg = ctrl_in[4];    // 内存到寄存器
    wire pc_to_reg = ctrl_in[3];     // PC到寄存器（用于JAL/JALR）
    wire alu_src_pc = ctrl_in[2];    // ALU源为PC（用于AUIPC）

    // 指令字段
    wire [4:0] instr_rd = instr_in[11:7];
    wire [6:0] opcode = instr_in[6:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd <= 5'b0;
            reg_we <= 1'b0;
            reg_wdata <= 64'b0;
            pc_out <= 64'b0;
        end else if (!stall) begin
            pc_out <= pc_in;

            // 设置写回数据
            if (pc_to_reg) begin
                // JAL/JALR指令：写回PC+4
                reg_wdata <= pc_in + 4;
            end else if (alu_src_pc) begin
                // AUIPC指令：写回PC+立即数
                reg_wdata <= alu_result;
            end else if (mem_to_reg) begin
                // 加载指令：写回内存数据
                reg_wdata <= mem_result;
            end else begin
                // 其他指令：写回ALU结果
                reg_wdata <= alu_result;
            end

            // 设置写回地址和使能
            rd <= instr_rd;
            reg_we <= reg_write && (instr_rd != 5'b0); // x0寄存器不写

            // 特殊指令处理
            case (opcode)
                7'b0110111: begin // LUI
                    reg_wdata <= {instr_in[31:12], 12'b0};
                end
                7'b0010111: begin // AUIPC
                    reg_wdata <= pc_in + {instr_in[31:12], 12'b0};
                end
                // 其他指令已经在上面处理
            endcase
        end
    end

endmodule
