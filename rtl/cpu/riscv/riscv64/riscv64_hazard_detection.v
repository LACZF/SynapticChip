// riscv64_hazard_detection.v
module riscv64_hazard_detection #(
    parameter ADDR_WIDTH        = 64,
    parameter DATA_WIDTH        = 64
)(
    input wire [4:0] rs1_id,
    input wire [4:0] rs2_id,
    input wire [4:0] rd_ex,
    input wire [4:0] rd_mem,
    input wire [4:0] rd_wb,
    input wire reg_we_ex,
    input wire reg_we_mem,
    input wire reg_we_wb,
    input wire mem_read_ex,
    input wire branch_taken,
    output wire data_hazard,
    output wire control_hazard,
    output wire stall_if,
    output wire stall_id,
    output wire stall_ex,
    output wire stall_mem,
    output wire stall_wb,
    output wire flush_if,
    output wire flush_id,
    output wire flush_ex,
    output wire flush_mem
);

    // 数据冒险检测
    wire hazard_ex_rs1 = reg_we_ex && (rd_ex != 5'b0) && (rd_ex == rs1_id);
    wire hazard_ex_rs2 = reg_we_ex && (rd_ex != 5'b0) && (rd_ex == rs2_id);
    wire hazard_mem_rs1 = reg_we_mem && (rd_mem != 5'b0) && (rd_mem == rs1_id);
    wire hazard_mem_rs2 = reg_we_mem && (rd_mem != 5'b0) && (rd_mem == rs2_id);

    // 加载-使用冒险
    wire load_use_hazard = mem_read_ex && ((hazard_ex_rs1) || (hazard_ex_rs2));

    assign data_hazard = hazard_ex_rs1 || hazard_ex_rs2 || hazard_mem_rs1 || hazard_mem_rs2;
    assign control_hazard = branch_taken;

    // 冒险处理：暂停流水线
    assign stall_if = load_use_hazard;
    assign stall_id = load_use_hazard;
    assign stall_ex = 1'b0;
    assign stall_mem = 1'b0;
    assign stall_wb = 1'b0;

    // 控制冒险：清空流水线
    assign flush_if = branch_taken;
    assign flush_id = branch_taken;
    assign flush_ex = branch_taken;
    assign flush_mem = 1'b0;

endmodule