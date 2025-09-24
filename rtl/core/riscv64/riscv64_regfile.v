// riscv64_regfile.v
module riscv64_regfile (
    input wire clk,
    input wire rst_n,
    input wire [4:0] rs1_addr,
    input wire [4:0] rs2_addr,
    input wire [4:0] rd_addr,
    input wire [63:0] rd_data,
    input wire rd_we,
    input wire word_op,  // 32位写操作标志

    output reg [63:0] rs1_data,
    output reg [63:0] rs2_data
);

    // 64位寄存器文件（x0-x31）
    reg [63:0] registers [0:31];
    integer i;

    // 读端口（组合逻辑）
    always @(*) begin
        // x0始终为0
        rs1_data = (rs1_addr == 5'h0) ? 64'h0 : registers[rs1_addr];
        rs2_data = (rs2_addr == 5'h0) ? 64'h0 : registers[rs2_addr];
    end

    // 写端口（时序逻辑）
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 64'h0;
            end
        end else if (rd_we && (rd_addr != 5'h0)) begin
            if (word_op) begin
                // 32位操作：符号扩展至64位
                registers[rd_addr] <= {{32{rd_data[31]}}, rd_data[31:0]};
            end else begin
                // 64位操作
                registers[rd_addr] <= rd_data;
            end
        end
    end

endmodule
