// riscv64_register_file.v
module riscv64_register_file #(
    parameter ADDR_WIDTH        = 64,
    parameter DATA_WIDTH        = 64
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire [4:0]           rs1_i,
    input  wire [4:0]           rs2_i,
    input  wire [4:0]           rd_i,
    input  wire                 we_i,
    input  wire [63:0]          wdata_i,
    output reg  [63:0]          rs1_data_o,
    output reg  [63:0]          rs2_data_o
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
        end else if (we_i && (rd_i != 5'b0)) begin
            registers[rd_i] <= wdata_i;
        end
    end

    // Read operation (combinational logic)
    always @(*) begin
        if (rs1_i == 5'b0) begin
            rs1_data_o = 64'b0;
        end else if ((rs1_i == rd_i) && we_i) begin
            rs1_data_o = wdata_i; // Forwarding
        end else begin
            rs1_data_o = registers[rs1_i];
        end

        if (rs2_i == 5'b0) begin
            rs2_data_o = 64'b0;
        end else if ((rs2_i == rd_i) && we_i) begin
            rs2_data_o = wdata_i; // Forwarding
        end else begin
            rs2_data_o = registers[rs2_i];
        end
    end

endmodule