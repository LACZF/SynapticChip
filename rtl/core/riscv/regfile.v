// regfile.v
module regfile (
    input wire clk,
    input wire rst_n,
    input wire [4:0] rs1_addr,
    input wire [4:0] rs2_addr,
    input wire [4:0] rd_addr,
    input wire [31:0] rd_data,
    input wire rd_we,

    output reg [31:0] rs1_data,
    output reg [31:0] rs2_data
);

    reg [31:0] registers [0:31];
    integer i;

    // 读端口
    always @(*) begin
        rs1_data = (rs1_addr == 5'h0) ? 32'h0 : registers[rs1_addr];
        rs2_data = (rs2_addr == 5'h0) ? 32'h0 : registers[rs2_addr];
    end

    // 写端口
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'h0;
            end
        end else if (rd_we && (rd_addr != 5'h0)) begin
            registers[rd_addr] <= rd_data;
        end
    end

endmodule
