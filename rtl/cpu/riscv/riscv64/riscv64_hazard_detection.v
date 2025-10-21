// riscv64_hazard_detection.v
// 改进版冒险检测模块，支持多周期操作和流水线暂停
`include "cache_params.v"

module riscv64_hazard_detection #(
    parameter ADDR_WIDTH        = 64,
    parameter DATA_WIDTH        = 64
)(
    input wire                  clk,
    input wire                  rst_n,

    // 寄存器操作相关信号
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
    input  wire                 cache_ready_i,
    input  wire                 mem_valid_i,
    input  wire                 ex_valid_i,

    // 控制信号输出
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

    // 内部状态寄存器，用于跟踪多周期操作
    reg [2:0] mem_access_state;
    reg multi_cycle_mem_op;
    reg [4:0] pending_rd;
    reg pending_reg_we;
    reg [3:0] pending_cycles;

    // 状态定义
    localparam MEM_STATE_IDLE     = 3'b000;
    localparam MEM_STATE_BUSY     = 3'b001;
    localparam MEM_STATE_COMPLETE = 3'b010;

    // 数据冒险检测
    wire hazard_ex_rs1  = reg_we_ex_i && (rd_ex_i != 5'b0) && (rd_ex_i == rs1_id_i);
    wire hazard_ex_rs2  = reg_we_ex_i && (rd_ex_i != 5'b0) && (rd_ex_i == rs2_id_i);
    wire hazard_mem_rs1 = reg_we_mem_i && (rd_mem_i != 5'b0) && (rd_mem_i == rs1_id_i);
    wire hazard_mem_rs2 = reg_we_mem_i && (rd_mem_i != 5'b0) && (rd_mem_i == rs2_id_i);

    // 检测正在进行的多周期内存操作是否会导致数据冒险
    wire pending_hazard_rs1 = multi_cycle_mem_op && pending_reg_we && (pending_rd == rs1_id_i);
    wire pending_hazard_rs2 = multi_cycle_mem_op && pending_reg_we && (pending_rd == rs2_id_i);

    // Load-use hazard
    wire load_use_hazard = mem_read_ex_i && ((hazard_ex_rs1) || (hazard_ex_rs2));

    // 总的数据冒险信号
    assign data_hazard_o    = hazard_ex_rs1 || hazard_ex_rs2 || hazard_mem_rs1 || hazard_mem_rs2 || pending_hazard_rs1 || pending_hazard_rs2;
    assign control_hazard_o = branch_taken_i;

    // 跟踪内存访问状态的状态机 - 修复版，确保正确处理多周期操作
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_access_state <= MEM_STATE_IDLE;
            multi_cycle_mem_op <= 1'b0;
            pending_rd <= 5'b0;
            pending_reg_we <= 1'b0;
            pending_cycles <= 4'b0;
        end else begin
            if (branch_taken_i) begin
                // 分支预测失败时重置状态
                mem_access_state <= MEM_STATE_IDLE;
                multi_cycle_mem_op <= 1'b0;
                pending_rd <= 5'b0;
                pending_reg_we <= 1'b0;
                pending_cycles <= 4'b0;
            end else begin
                case (mem_access_state)
                    MEM_STATE_IDLE:
                        // 检测是否有新的内存访问开始
                        if (mem_valid_i && mem_read_ex_i) begin
                            mem_access_state <= MEM_STATE_BUSY;
                            multi_cycle_mem_op <= 1'b1;
                            pending_rd <= rd_ex_i;
                            pending_reg_we <= reg_we_ex_i;
                            pending_cycles <= 4'b0;
                        end

                    MEM_STATE_BUSY:
                        // 等待缓存操作完成，支持多周期等待
                        if (cache_ready_i) begin
                            mem_access_state <= MEM_STATE_COMPLETE;
                        end else begin
                            // 即使cache_ready_i未置位，也继续保持BUSY状态
                            pending_cycles <= pending_cycles + 1;
                        end

                    MEM_STATE_COMPLETE:
                        begin
                        // 操作完成，清除状态
                        mem_access_state <= MEM_STATE_IDLE;
                        multi_cycle_mem_op <= 1'b0;
                        pending_rd <= 5'b0;
                        pending_reg_we <= 1'b0;
                        pending_cycles <= 4'b0;
                        end
                endcase
            end
        end
    end

    // 流水线暂停信号生成 - 修复版，确保正确处理多周期操作
    wire mem_stall = (mem_access_state == MEM_STATE_BUSY) && (pending_hazard_rs1 || pending_hazard_rs2);
    wire load_stall = load_use_hazard;
    wire total_stall = mem_stall || load_stall;

    // 逐级暂停信号 - 确保流水线正确暂停
    assign stall_if_o  = total_stall;
    assign stall_id_o  = total_stall;
    assign stall_ex_o  = (mem_access_state == MEM_STATE_BUSY) || total_stall;
    assign stall_mem_o = 1'b0;
    assign stall_wb_o  = 1'b0;

    // 控制冒险：流水线刷新
    assign flush_if_o  = branch_taken_i;
    assign flush_id_o  = branch_taken_i;
    assign flush_ex_o  = branch_taken_i;
    assign flush_mem_o = branch_taken_i;

`ifdef DEBUG
    // Debug: 监测内存操作状态和暂停信号
    always @(posedge clk) begin
        if (rst_n) begin
            // 监测内存操作状态变化
            if (mem_access_state != $past(mem_access_state)) begin
                $display("Hazard Detection: Memory Access State changed to %d, pending_rd=%d, pending_reg_we=%b",
                         mem_access_state, pending_rd, pending_reg_we);
            end
            // 监测暂停信号
            if (total_stall) begin
                $display("Hazard Detection: Pipeline stalled - mem_stall=%b, load_stall=%b, pending_hazards=%b/%b",
                         mem_stall, load_stall, pending_hazard_rs1, pending_hazard_rs2);
            end
            // 监测数据冒险
            if (data_hazard_o) begin
                $display("Hazard Detection: Data hazard detected - hazard_ex=%b/%b, hazard_mem=%b/%b, pending_hazard=%b/%b",
                         hazard_ex_rs1, hazard_ex_rs2, hazard_mem_rs1, hazard_mem_rs2, pending_hazard_rs1, pending_hazard_rs2);
            end
        end
    end
`endif

endmodule