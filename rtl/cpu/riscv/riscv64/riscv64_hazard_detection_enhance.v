`timescale 1ns/1ps

module riscv64_enhanced_hazard_detection_unit (
    input wire         clk,
    input wire         rst_n,

    // 输入：当前指令信息
    input  wire [31:0] if_id_inst_i,     // IF/ID阶段的指令
    input  wire [31:0] id_ex_inst_i,     // ID/EX阶段的指令
    input  wire [31:0] ex_mem_inst_i,    // EX/MEM阶段的指令

    // 输入：寄存器信息
    input  wire [4:0]  id_rs1_i,
    input  wire [4:0]  id_rs2_i,
    input  wire [4:0]  id_rd_i,
    input  wire        id_reg_write_i,

    input  wire [4:0]  ex_rd_i,
    input  wire        ex_reg_write_i,
    input  wire [1:0]  ex_mem_to_reg_i,

    input  wire [4:0]  mem_rd_i,
    input  wire        mem_reg_write_i,
    input  wire [1:0]  mem_mem_to_reg_i,

    input  wire [4:0]  wb_rd_i,
    input  wire        wb_reg_write_i,

    // 输入：控制信号
    input  wire        branch_taken_i,   // 分支跳转发生
    input  wire        jump_taken_i,     // 跳转发生

    // 输出：精细化的流水线控制信号
    output reg         stall_if_o,       // 暂停IF阶段
    output reg         stall_id_o,       // 暂停ID阶段
    output reg         stall_ex_o,       // 暂停EX阶段
    output reg         stall_mem_o,      // 暂停MEM阶段
    output reg         stall_wb_o,       // 暂停WB阶段

    output reg         flush_if_o,       // 刷新IF阶段
    output reg         flush_id_o,       // 刷新ID阶段
    output reg         flush_ex_o,       // 刷新EX阶段
    output reg         flush_mem_o,      // 刷新MEM阶段

    // 输出：前向控制信号
    output reg  [1:0]  forward_a_o,      // 操作数A的前向控制
    output reg  [1:0]  forward_b_o,      // 操作数B的前向控制

    // 输出：调试信息
    output reg  [3:0]  hazard_type_o,    // 冒险类型详细编码
    output wire [3:0]  raw_conflicts_o,  // RAW冲突统计
    output wire        has_waw_o,        // WAW冲突标志
    output wire        has_war_o         // WAR冲突标志
);

    // ============================================================================
    // 内部信号定义
    // ============================================================================

    // 指令解码
    wire [6:0] id_opcode = if_id_inst_i[6:0];
    wire [6:0] ex_opcode = id_ex_inst_i[6:0];
    wire [6:0] mem_opcode = ex_mem_inst_i[6:0];

    wire [4:0] ex_rs1 = id_ex_inst_i[19:15];
    wire [4:0] ex_rs2 = id_ex_inst_i[24:20];

    // RAW冲突检测
    wire raw_ex_id_rs1, raw_ex_id_rs2, raw_mem_id_rs1, raw_mem_id_rs2;
    wire raw_wb_id_rs1, raw_wb_id_rs2;

    assign raw_ex_id_rs1 = (id_rs1_i != 5'b0) && (ex_reg_write_i) && (ex_rd_i == id_rs1_i);
    assign raw_ex_id_rs2 = (id_rs2_i != 5'b0) && (ex_reg_write_i) && (ex_rd_i == id_rs2_i);
    assign raw_mem_id_rs1 = (id_rs1_i != 5'b0) && (mem_reg_write_i) && (mem_rd_i == id_rs1_i);
    assign raw_mem_id_rs2 = (id_rs2_i != 5'b0) && (mem_reg_write_i) && (mem_rd_i == id_rs2_i);
    assign raw_wb_id_rs1 = (id_rs1_i != 5'b0) && (wb_reg_write_i) && (wb_rd_i == id_rs1_i);
    assign raw_wb_id_rs2 = (id_rs2_i != 5'b0) && (wb_reg_write_i) && (wb_rd_i == id_rs2_i);

    assign raw_conflicts_o = {raw_ex_id_rs1, raw_ex_id_rs2, raw_mem_id_rs1, raw_mem_id_rs2};

    // Load-Use冒险检测
    wire load_use_rs1, load_use_rs2;
    assign load_use_rs1 = (id_rs1_i != 5'b0) && (ex_reg_write_i) && (ex_rd_i == id_rs1_i) &&
                          (ex_mem_to_reg_i == 2'b01); // EX阶段是load指令
    assign load_use_rs2 = (id_rs2_i != 5'b0) && (ex_reg_write_i) && (ex_rd_i == id_rs2_i) &&
                          (ex_mem_to_reg_i == 2'b01); // EX阶段是load指令
    wire load_use_hazard = load_use_rs1 || load_use_rs2;

    // 控制冒险检测
    wire control_hazard = branch_taken_i || jump_taken_i;

    // WAW冲突检测
    wire waw_ex_id, waw_mem_id, waw_wb_id;
    assign waw_ex_id = (id_rd_i != 5'b0) && (ex_reg_write_i) && (ex_rd_i == id_rd_i);
    assign waw_mem_id = (id_rd_i != 5'b0) && (mem_reg_write_i) && (mem_rd_i == id_rd_i);
    assign waw_wb_id = (id_rd_i != 5'b0) && (wb_reg_write_i) && (wb_rd_i == id_rd_i);
    assign has_waw_o = waw_ex_id || waw_mem_id || waw_wb_id;

    // WAR冲突检测
    wire war_id_ex, war_id_mem, war_id_wb;
    assign war_id_ex = (ex_rd_i != 5'b0) && (id_reg_write_i) &&
                      ((id_rd_i == ex_rs1) || (id_rd_i == ex_rs2));
    assign war_id_mem = (mem_rd_i != 5'b0) && (id_reg_write_i) &&
                       ((id_rd_i == ex_mem_inst_i[19:15]) || (id_rd_i == ex_mem_inst_i[24:20]));
    assign war_id_wb = (wb_rd_i != 5'b0) && (id_reg_write_i);
    assign has_war_o = war_id_ex || war_id_mem || war_id_wb;

    // 结构冒险检测（内存端口冲突）
    wire structural_hazard_mem = (ex_mem_inst_i[6:0] == 7'b0000011 ||  // EX阶段有load
                                 ex_mem_inst_i[6:0] == 7'b0100011) &&  // 或store
                                (if_id_inst_i[6:0] == 7'b0000011 ||    // ID阶段有load
                                 if_id_inst_i[6:0] == 7'b0100011);     // 或store

    // ============================================================================
    // 前向控制逻辑
    // ============================================================================

    always @(*) begin
        // 默认值：无前向
        forward_a_o = 2'b00;
        forward_b_o = 2'b00;

        // 操作数A的前向控制
        if (raw_ex_id_rs1) begin
            // 从EX阶段前向（ALU结果）
            forward_a_o = 2'b10;
        end else if (raw_mem_id_rs1) begin
            // 从MEM阶段前向
            if (mem_mem_to_reg_i == 2'b01) // 如果是load指令的结果
                forward_a_o = 2'b01;       // 从内存数据前向
            else
                forward_a_o = 2'b11;       // 从ALU结果前向
        end

        // 操作数B的前向控制
        if (raw_ex_id_rs2) begin
            // 从EX阶段前向（ALU结果）
            forward_b_o = 2'b10;
        end else if (raw_mem_id_rs2) begin
            // 从MEM阶段前向
            if (mem_mem_to_reg_i == 2'b01) // 如果是load指令的结果
                forward_b_o = 2'b01;       // 从内存数据前向
            else
                forward_b_o = 2'b11;       // 从ALU结果前向
        end
    end

    // ============================================================================
    // 精细化的流水线控制逻辑
    // ============================================================================

    // 冒险类型编码
    localparam NO_HAZARD         = 4'b0000;
    localparam LOAD_USE_HAZARD   = 4'b0001;
    localparam CONTROL_HAZARD    = 4'b0010;
    localparam STRUCTURAL_HAZARD = 4'b0011;
    localparam RAW_HAZARD        = 4'b0100;
    localparam WAW_HAZARD        = 4'b0101;
    localparam WAR_HAZARD        = 4'b0110;

    always @(*) begin
        // 默认值：无暂停，无刷新
        stall_if_o = 1'b0;
        stall_id_o = 1'b0;
        stall_ex_o = 1'b0;
        stall_mem_o = 1'b0;
        stall_wb_o = 1'b0;

        flush_if_o = 1'b0;
        flush_id_o = 1'b0;
        flush_ex_o = 1'b0;
        flush_mem_o = 1'b0;

        hazard_type_o = NO_HAZARD;

        // 优先级：控制冒险 > Load-Use冒险 > 结构冒险 > 数据冒险

        // 情况1: 控制冒险（最高优先级）
        if (control_hazard) begin
            hazard_type_o = CONTROL_HAZARD;

            // 控制冒险：刷新错误的指令路径
            flush_if_o = 1'b1;  // 刷新IF阶段（重新取指）
            flush_id_o = 1'b1;  // 刷新ID阶段（清除已译码的错误指令）
            flush_ex_o = 1'b1;  // 刷新EX阶段（清除正在执行的分支指令）

            // 不需要暂停任何阶段

        end
        // 情况2: Load-Use冒险（需要暂停流水线）
        else if (load_use_hazard) begin
            hazard_type_o = LOAD_USE_HAZARD;

            // Load-Use冒险：暂停IF和ID阶段，插入气泡
            stall_if_o = 1'b1;  // 暂停取指
            stall_id_o = 1'b1;  // 暂停译码
            flush_ex_o = 1'b1;  // 刷新EX阶段（插入气泡）

            // EX、MEM、WB阶段继续执行

        end
        // 情况3: 结构冒险（内存端口冲突）
        else if (structural_hazard_mem) begin
            hazard_type_o = STRUCTURAL_HAZARD;

            // 内存结构冒险：暂停IF阶段
            stall_if_o = 1'b1;  // 暂停取指

            // 其他阶段继续执行

        end
        // 情况4: WAW冲突（通常通过流水线调度解决）
        else if (has_waw_o) begin
            hazard_type_o = WAW_HAZARD;

            // WAW冲突：通常不需要暂停，可以通过寄存器重命名或编译器调度解决
            // 在简单实现中，可以暂停ID阶段
            stall_id_o = 1'b1;  // 暂停译码，等待前面的写操作完成

        end
        // 情况5: RAW冲突（通常通过前向解决，不需要暂停）
        else if (raw_ex_id_rs1 || raw_ex_id_rs2 || raw_mem_id_rs1 || raw_mem_id_rs2) begin
            hazard_type_o = RAW_HAZARD;

            // RAW冲突已通过前向解决，不需要暂停
            // 前向逻辑已经在前面处理

        end
        // 情况6: WAR冲突（在按序流水线中通常不会发生）
        else if (has_war_o) begin
            hazard_type_o = WAR_HAZARD;

            // WAR冲突：在按序流水线中通常不会造成问题
            // 不需要特殊处理

        end

        // 特殊情况：多周期操作需要暂停后续阶段
        // 这里可以根据具体指令类型添加更精细的控制

    end

    // ============================================================================
    // 辅助功能：冒险详细分析
    // ============================================================================

    // 冒险严重程度分析
    function [1:0] get_hazard_severity;
        input [3:0] h_type;
        begin
            case (h_type)
                CONTROL_HAZARD:    get_hazard_severity = 2'b11; // 严重
                LOAD_USE_HAZARD:   get_hazard_severity = 2'b10; // 中等
                STRUCTURAL_HAZARD: get_hazard_severity = 2'b01; // 轻微
                default:           get_hazard_severity = 2'b00; // 无
            endcase
        end
    endfunction

    // 冒险解决周期估计
    function [2:0] get_resolution_cycles;
        input [3:0] h_type;
        begin
            case (h_type)
                LOAD_USE_HAZARD:   get_resolution_cycles = 3'd1; // 通常1周期
                CONTROL_HAZARD:    get_resolution_cycles = 3'd2; // 2周期（刷新+重取）
                STRUCTURAL_HAZARD: get_resolution_cycles = 3'd1; // 1周期
                default:           get_resolution_cycles = 3'd0; // 立即
            endcase
        end
    endfunction

endmodule