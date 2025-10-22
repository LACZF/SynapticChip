// riscv64_register_file.v
module riscv64_register_file #(
    parameter ADDR_WIDTH        = 64,
    parameter DATA_WIDTH        = 64
)(
    input  wire                 clk,
    input  wire                 rst_n,
    input  wire [63:0]          pc_in_i,
    input  wire [31:0]          instr_wr_i,
    input  wire [31:0]          instr_rd_i,

`ifdef DEBUG
    output wire [63:0]          reg0,
    output wire [63:0]          reg1,
    output wire [63:0]          reg2,
    output wire [63:0]          reg3,
    output wire [63:0]          reg4,
    output wire [63:0]          reg5,
    output wire [63:0]          reg6,
    output wire [63:0]          reg7,
    output wire [63:0]          reg8,
    output wire [63:0]          reg9,
    output wire [63:0]          reg10,
    output wire [63:0]          reg11,
    output wire [63:0]          reg12,
    output wire [63:0]          reg13,
    output wire [63:0]          reg14,
    output wire [63:0]          reg15,
    output wire [63:0]          reg16,
    output wire [63:0]          reg17,
    output wire [63:0]          reg18,
    output wire [63:0]          reg19,
    output wire [63:0]          reg20,
    output wire [63:0]          reg21,
    output wire [63:0]          reg22,
    output wire [63:0]          reg23,
    output wire [63:0]          reg24,
    output wire [63:0]          reg25,
    output wire [63:0]          reg26,
    output wire [63:0]          reg27,
    output wire [63:0]          reg28,
    output wire [63:0]          reg29,
    output wire [63:0]          reg30,
    output wire [63:0]          reg31,
`endif

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
            rs1_data_o = wdata_i; // Forwarding from write-back stage
        end else begin
            rs1_data_o = registers[rs1_i];
        end

        if (rs2_i == 5'b0) begin
            rs2_data_o = 64'b0;
        end else if ((rs2_i == rd_i) && we_i) begin
            rs2_data_o = wdata_i; // Forwarding from write-back stage
        end else begin
            rs2_data_o = registers[rs2_i];
        end
    end

`ifdef DEBUG
    assign reg0  = registers[0];
    assign reg1  = registers[1];
    assign reg2  = registers[2];
    assign reg3  = registers[3];
    assign reg4  = registers[4];
    assign reg5  = registers[5];
    assign reg6  = registers[6];
    assign reg7  = registers[7];
    assign reg8  = registers[8];
    assign reg9  = registers[9];
    assign reg10 = registers[10];
    assign reg11 = registers[11];
    assign reg12 = registers[12];
    assign reg13 = registers[13];
    assign reg14 = registers[14];
    assign reg15 = registers[15];
    assign reg16 = registers[16];
    assign reg17 = registers[17];
    assign reg18 = registers[18];
    assign reg19 = registers[19];
    assign reg20 = registers[20];
    assign reg21 = registers[21];
    assign reg22 = registers[22];
    assign reg23 = registers[23];
    assign reg24 = registers[24];
    assign reg25 = registers[25];
    assign reg26 = registers[26];
    assign reg27 = registers[27];
    assign reg28 = registers[28];
    assign reg29 = registers[29];
    assign reg30 = registers[30];
    assign reg31 = registers[31];
`endif

endmodule