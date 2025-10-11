// riscv64_register_file.v
module riscv64_register_file #(
    parameter ADDR_WIDTH        = 64,
    parameter DATA_WIDTH        = 64
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire [4:0]           rs1,
    input  wire [4:0]           rs2,
    input  wire [4:0]           rd,
    input  wire                 we,
    input  wire [63:0]          wdata,
    output reg  [63:0]          rs1_data,
    output reg  [63:0]          rs2_data
);

    reg [63:0] registers [0:31];
    integer i;

    // Initialize registers
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            registers[i] = 64'b0;
        end
    end

    // Write operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 64'b0;
            end
        end else if (we && (rd != 5'b0)) begin
            registers[rd] <= wdata;
        end
    end

    // Read operation (combinational logic)
    always @(*) begin
        if (rs1 == 5'b0) begin
            rs1_data = 64'b0;
        end else if ((rs1 == rd) && we) begin
            rs1_data = wdata; // Forwarding
        end else begin
            rs1_data = registers[rs1];
        end

        if (rs2 == 5'b0) begin
            rs2_data = 64'b0;
        end else if ((rs2 == rd) && we) begin
            rs2_data = wdata; // Forwarding
        end else begin
            rs2_data = registers[rs2];
        end
    end

endmodule