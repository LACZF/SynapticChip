// riscv64_hazard_detection.v
module riscv64_hazard_detection #(
    parameter ADDR_WIDTH        = 64,
    parameter DATA_WIDTH        = 64
)(
    input wire                  clk,
    input wire                  rst_n,

    input  wire [4:0]           rs1_id_i,
    input  wire [4:0]           rs2_id_i,
    input  wire [4:0]           rd_ex_i,
    input  wire [4:0]           rd_mem_i,
    input  wire [4:0]           rd_wb_i,
    input  wire                 reg_we_ex_i,
    input  wire                 reg_we_mem_i,
    input  wire                 reg_we_wb_i,
    input  wire                 mem_read_ex_i,
    input  wire                 branch_taken_i,
    output wire                 data_hazard_o,
    output wire                 control_hazard_o,
    output wire                 stall_if_o,
    output wire                 stall_id_o,
    output wire                 stall_ex_o,
    output wire                 stall_mem_o,
    output wire                 stall_wb_o,
    output wire                 flush_if_o,
    output wire                 flush_id_o,
    output wire                 flush_ex_o,
    output wire                 flush_mem_o
);

    // Data hazard detection
    wire hazard_ex_rs1  = reg_we_ex_i && (rd_ex_i != 5'b0) && (rd_ex_i == rs1_id_i);
    wire hazard_ex_rs2  = reg_we_ex_i && (rd_ex_i != 5'b0) && (rd_ex_i == rs2_id_i);
    wire hazard_mem_rs1 = reg_we_mem_i && (rd_mem_i != 5'b0) && (rd_mem_i == rs1_id_i);
    wire hazard_mem_rs2 = reg_we_mem_i && (rd_mem_i != 5'b0) && (rd_mem_i == rs2_id_i);

    // Load-use hazard
    wire load_use_hazard = mem_read_ex_i && ((hazard_ex_rs1) || (hazard_ex_rs2));

    assign data_hazard_o    = hazard_ex_rs1 || hazard_ex_rs2 || hazard_mem_rs1 || hazard_mem_rs2;
    assign control_hazard_o = branch_taken_i;

    // Hazard handling: Pipeline stall
    assign stall_if_o  = load_use_hazard;
    assign stall_id_o  = load_use_hazard;
    assign stall_ex_o  = 1'b0;
    assign stall_mem_o = 1'b0;
    assign stall_wb_o  = 1'b0;

    // Control hazard: Pipeline flush
    assign flush_if_o  = branch_taken_i;
    assign flush_id_o  = branch_taken_i;
    assign flush_ex_o  = branch_taken_i;
    assign flush_mem_o = 1'b0;

endmodule