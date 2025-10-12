// riscv64_core.v
`include "cache_params.v"
`include "cache_system_params.v"

module riscv64_core #(
    parameter ADDR_WIDTH                             = 64,
    parameter DATA_WIDTH                             = 64,
    parameter L1_ICACHE_DATA_WIDTH                   = 32,
    parameter L1_DCACHE_DATA_WIDTH                   = 64,
    parameter CORE_ID                                = 0
)(
    input wire                                       clk,
    input wire                                       rst_n,

    // Instruction cache interface - now connected to L1 cache in cpu_top
    output wire                                      icache_req_o,
    output wire [ADDR_WIDTH-1:0]                     icache_addr_o,
    input  wire [L1_ICACHE_DATA_WIDTH-1:0]           icache_data_i,
    input  wire                                      icache_ready_i,

    // Data cache interface - now connected to L1 cache in cpu_top
    output wire                                      dcache_req_o,
    output wire [ADDR_WIDTH-1:0]                     dcache_addr_o,
    output wire [L1_DCACHE_DATA_WIDTH-1:0]           dcache_wdata_o,
    input  wire [L1_DCACHE_DATA_WIDTH-1:0]           dcache_rdata_i,
    output wire                                      dcache_we_o,
    output wire [L1_DCACHE_DATA_WIDTH/8-1:0]         dcache_byte_en_o,
    input  wire                                      dcache_ready_i,

    // Snoop interface
    input  wire                                      snoop_valid_i,
    input  wire [ADDR_WIDTH-1:0]                     snoop_addr_i,
    input  wire [1:0]                                snoop_req_type_i,
    output wire                                      snoop_ready_o,
    output wire                                      snoop_hit_o,
    output wire [1:0]                                snoop_state_o,
    output wire [511:0]                              snoop_data_o,

    // Interrupt and debugging
    input  wire                                      timer_interrupt_i,
    input  wire                                      external_interrupt_i,
    input  wire                                      software_interrupt_i,

    // Debug interface
    output wire [63:0]                               debug_pc_o,
    output wire [31:0]                               debug_instr_o,
    output wire                                      debug_wb_valid_o,
    output wire [4:0]                                debug_wb_rd_o,
    output wire [63:0]                               debug_wb_value_o
);

    // Internal signal definition
    wire [2:0] icache_coh_rsp_state;
    wire [2:0] dcache_coh_rsp_state;
    wire [2:0] snoop_state_internal;
    wire       icache_mem_req_rw;
    assign icache_mem_req_rw = 1'b0;  // Instruction cache is always read operation

    // Pipeline registers
    wire [63:0] pc_if, pc_id, pc_ex, pc_mem, pc_wb;
    wire [31:0] instr_if, instr_id, instr_ex, instr_mem, instr_wb;
    wire [15:0] ctrl_id, ctrl_ex, ctrl_mem, ctrl_wb;

    // Control signals
    wire [6:0] opcode = instr_id[6:0];
    wire [4:0] rd, rs1, rs2;
    wire [2:0] funct3;
    wire [6:0] funct7;

    assign rd = instr_id[11:7];
    assign rs1 = instr_id[19:15];
    assign rs2 = instr_id[24:20];
    assign funct3 = instr_id[14:12];
    assign funct7 = instr_id[31:25];

    wire [4:0] rd_wb;
    wire [4:0] rd_mem;
    wire [4:0] rd_ex;

    wire [63:0] reg_wdata;
    wire [63:0] rs1_data;
    wire [63:0] rs2_data;

    wire [63:0] imm_id;

    // Hazard detection signals
    wire stall_if, stall_id, stall_ex, stall_mem, stall_wb;
    wire flush_if, flush_id, flush_ex, flush_mem;

    // Execution stage signals
    wire [63:0] alu_result;
    wire branch_taken;
    wire [63:0] branch_target;

    // Memory access signals
    wire [63:0] mem_result;

    // Write back signals
    wire [4:0] wb_rd;
    wire wb_reg_we;
    wire [63:0] wb_reg_wdata;

    // L1-L2 interface signals
    wire l1_l2_ready;

    // When L1 cache is instantiated in cpu_top, these L1-L2 signals are directly connected to L1 cache in cpu_top
    assign l1_icache_req = icache_req_o;
    assign l1_icache_addr = icache_addr_o;
    assign l1_dcache_req = dcache_req_o;
    assign l1_dcache_addr = dcache_addr_o;
    assign l1_dcache_wdata = {{448{1'b0}}, dcache_wdata_o};
    assign l1_dcache_we = dcache_we_o;
    assign l1_dcache_req_type = 2'b00;

    // Coherence state handling
    assign snoop_state_o = dcache_coh_rsp_state[1:0];
    assign snoop_hit_o = 1'b0;
    assign snoop_ready_o = 1'b1;
    assign snoop_data_o = 512'd0;

    // Instruction fetch stage
    riscv64_instruction_fetch #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .L1_ICACHE_DATA_WIDTH(L1_ICACHE_DATA_WIDTH)
    ) u_if (
        .clk(clk),
        .rst_n(rst_n),
        .stall_i(stall_if),
        .flush_i(flush_if),
        .branch_target_i(branch_target),
        .branch_taken_i(branch_taken),
        .pc_o(pc_if),
        .instr_o(instr_if),
        .cache_req_o(icache_req_o),
        .cache_addr_o(icache_addr_o),
        .cache_data_i(icache_data_i),
        .cache_ready_i(icache_ready_i)
    );

    // Instruction decode stage
    riscv64_instruction_decode #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_id (
        .clk(clk),
        .rst_n(rst_n),
        .stall_i(stall_id),
        .flush_i(flush_id),
        .pc_in_i(pc_if),
        .instr_in_i(instr_if),
        .pc_out_o(pc_id),
        .instr_out_o(instr_id),
        .rs1_o(rs1),
        .rs2_o(rs2),
        .imm_o(imm_id),
        .ctrl_signals_o(ctrl_id)
    );

    // Execution stage
    riscv64_execution #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_ex (
        .clk(clk),
        .rst_n(rst_n),
        .stall_i(stall_ex),
        .flush_i(flush_ex),
        .pc_in_i(pc_id),
        .instr_in_i(instr_id),
        .rs1_data_i(rs1_data),
        .rs2_data_i(rs2_data),
        .imm_i(imm_id),
        .ctrl_in_i(ctrl_id),
        .pc_out_o(pc_ex),
        .instr_out_o(instr_ex),
        .alu_result_o(alu_result),
        .branch_taken_o(branch_taken),
        .branch_target_o(branch_target),
        .ctrl_out_o(ctrl_ex)
    );

    // Memory access stage
    riscv64_memory_access #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .L1_DCACHE_DATA_WIDTH(L1_DCACHE_DATA_WIDTH)
    ) u_mem (
        .clk(clk),
        .rst_n(rst_n),
        .stall_i(stall_mem),
        .flush_i(flush_mem),
        .pc_in_i(pc_ex),
        .instr_in_i(instr_ex),
        .alu_result_i(alu_result),
        .rs2_data_i(rs2_data),
        .ctrl_in_i(ctrl_ex),
        .cache_addr_o(dcache_addr_o),
        .cache_wdata_o(dcache_wdata_o),
        .cache_rdata_i(dcache_rdata_i),
        .cache_req_o(dcache_req_o),
        .cache_we_o(dcache_we_o),
        .cache_byte_en_o(dcache_byte_en_o),
        .cache_ready_i(dcache_ready_i),
        .pc_out_o(pc_mem),
        .instr_out_o(instr_mem),
        .mem_result_o(mem_result),
        .ctrl_out_o(ctrl_mem)
    );

    // Write back stage
    riscv64_write_back #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_wb (
        .clk(clk),
        .rst_n(rst_n),
        .stall_i(stall_wb),
        .pc_in_i(pc_mem),
        .instr_in_i(instr_mem),
        .alu_result_i(alu_result),
        .mem_result_i(mem_result),
        .ctrl_in_i(ctrl_mem),
        .rd_o(wb_rd),
        .reg_we_o(wb_reg_we),
        .reg_wdata_o(wb_reg_wdata),
        .pc_out_o(pc_wb),
        .instr_out_o(instr_wb),
        .wb_valid_o(debug_wb_valid_o)
    );

    // Register file
    riscv64_register_file #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_regfile (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_i(instr_id[19:15]),
        .rs2_i(instr_id[24:20]),
        .rd_i(wb_rd),
        .we_i(wb_reg_we),
        .wdata_i(wb_reg_wdata),
        .rs1_data_o(rs1_data),
        .rs2_data_o(rs2_data)
    );

    // Hazard detection unit
    riscv64_hazard_detection #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) u_hazard (
        .rs1_id_i(instr_id[19:15]),
        .rs2_id_i(instr_id[24:20]),
        .rd_ex_i(instr_ex[11:7]),
        .rd_mem_i(instr_mem[11:7]),
        .rd_wb_i(wb_rd),
        .reg_we_ex_i(ctrl_ex[10]),
        .reg_we_mem_i(ctrl_mem[10]),
        .reg_we_wb_i(wb_reg_we),
        .mem_read_ex_i(ctrl_ex[9]),
        .branch_taken_i(branch_taken),
        .data_hazard_o(),
        .control_hazard_o(),
        .stall_if_o(stall_if),
        .stall_id_o(stall_id),
        .stall_ex_o(stall_ex),
        .stall_mem_o(stall_mem),
        .stall_wb_o(stall_wb),
        .flush_if_o(flush_if),
        .flush_id_o(flush_id),
        .flush_ex_o(flush_ex),
        .flush_mem_o(flush_mem)
    );

    // Debug output
    assign debug_pc_o = pc_wb;
    assign debug_instr_o = instr_wb;
    assign debug_wb_rd_o = wb_rd;
    assign debug_wb_value_o = wb_reg_wdata;

endmodule