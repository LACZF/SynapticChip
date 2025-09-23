// riscv_cpu.v
module riscv_cpu (
    input wire clk,
    input wire rst_n,

    // 指令存储器接口
    output wire [31:0] imem_addr,
    input wire [31:0] imem_data,
    output wire imem_req,
    input wire imem_ack,

    // 数据存储器接口
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_data_out,
    input wire [31:0] dmem_data_in,
    output wire dmem_we,
    output wire [3:0] dmem_sel,
    output wire dmem_req,
    input wire dmem_ack,

    // 中断输入
    input wire ext_interrupt,
    input wire timer_interrupt,
    input wire soft_interrupt,

    // 调试输出
    output reg [31:0] debug_pc,
    output reg [31:0] debug_instruction,
    /* TODO */
    // output wire [31:0] debug_registers [0:31],
    output reg [4:0] debug_state
);

    // 流水线寄存器
    // IF/ID寄存器
    reg [31:0] if_id_pc;
    reg [31:0] if_id_inst;
    reg if_id_valid;

    // ID/EX寄存器
    reg [31:0] id_ex_pc;
    reg [31:0] id_ex_inst;
    reg [31:0] id_ex_rs1_data;
    reg [31:0] id_ex_rs2_data;
    reg [31:0] id_ex_imm;
    reg [4:0] id_ex_rd;
    reg id_ex_reg_we;
    reg [2:0] id_ex_alu_op;
    reg id_ex_alu_src;
    reg id_ex_mem_we;
    reg id_ex_mem_re;
    reg [1:0] id_ex_wb_sel;
    reg id_ex_branch;
    reg id_ex_jump;
    reg id_ex_valid;

    // EX/WB寄存器
    reg [31:0] ex_wb_pc;
    reg [31:0] ex_wb_alu_result;
    reg [31:0] ex_wb_mem_data;
    reg [4:0] ex_wb_rd;
    reg ex_wb_reg_we;
    reg [1:0] ex_wb_wb_sel;
    reg ex_wb_valid;

    // 控制信号
    wire stall;
    wire flush;
    wire [31:0] new_pc;
    wire [31:0] branch_target;
    wire branch_taken;

    // 异常和中断信号
    wire exception_valid;
    wire [3:0] exception_cause;
    wire [31:0] exception_pc;
    wire [31:0] exception_tval;
    wire trap_taken;
    wire [31:0] trap_handler_addr;
    wire [31:0] return_addr;
    wire mret_exec;

    // 寄存器文件信号
    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [4:0] rd;
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    wire reg_we;
    wire [31:0] reg_wdata;

    // ALU信号
    wire [31:0] alu_src1;
    wire [31:0] alu_src2;
    wire [31:0] alu_result;
    wire alu_zero;

    // 立即数生成
    wire [31:0] imm_i;
    wire [31:0] imm_s;
    wire [31:0] imm_b;
    wire [31:0] imm_u;
    wire [31:0] imm_j;

    // 指令解码信号
    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;

    // ==================== 流水线阶段1: 取指(IF) ====================
    reg [31:0] pc;
    wire [31:0] next_pc;

    assign imem_addr = pc;
    assign imem_req = !stall && !flush;

    // PC更新逻辑
    assign next_pc = (trap_taken) ? trap_handler_addr :
                    (branch_taken) ? branch_target :
                    (flush) ? return_addr :
                    pc + 4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'h00000000;
        end else if (!stall) begin
            pc <= next_pc;
        end
    end

    // ==================== IF/ID流水线寄存器 ====================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_pc <= 32'h0;
            if_id_inst <= 32'h0;
            if_id_valid <= 1'b0;
        end else if (flush) begin
            if_id_pc <= 32'h0;
            if_id_inst <= 32'h0;
            if_id_valid <= 1'b0;
        end else if (!stall) begin
            if_id_pc <= pc;
            if_id_inst <= imem_data;
            if_id_valid <= imem_ack;
        end
    end

    // ==================== 流水线阶段2: 译码(ID) ====================
    // 指令解码
    assign opcode = if_id_inst[6:0];
    assign funct3 = if_id_inst[14:12];
    assign funct7 = if_id_inst[31:25];
    assign rs1 = if_id_inst[19:15];
    assign rs2 = if_id_inst[24:20];
    assign rd = if_id_inst[11:7];

    // 立即数生成
    assign imm_i = {{20{if_id_inst[31]}}, if_id_inst[31:20]};
    assign imm_s = {{20{if_id_inst[31]}}, if_id_inst[31:25], if_id_inst[11:7]};
    assign imm_b = {{19{if_id_inst[31]}}, if_id_inst[31], if_id_inst[7],
                   if_id_inst[30:25], if_id_inst[11:8], 1'b0};
    assign imm_u = {if_id_inst[31:12], 12'h0};
    assign imm_j = {{11{if_id_inst[31]}}, if_id_inst[31], if_id_inst[19:12],
                   if_id_inst[20], if_id_inst[30:21], 1'b0};

    // 控制单元
    wire [2:0] alu_op;
    wire alu_src;
    wire mem_we;
    wire mem_re;
    wire [1:0] wb_sel;
    wire branch;
    wire jump;
    wire reg_we_id;

    control_unit ctrl (
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .alu_op(alu_op),
        .alu_src(alu_src),
        .mem_we(mem_we),
        .mem_re(mem_re),
        .wb_sel(wb_sel),
        .branch(branch),
        .jump(jump),
        .reg_we(reg_we_id),
        .mret_exec(mret_exec)
    );

    // 寄存器文件
    regfile reg_file (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_addr(rs1),
        .rs2_addr(rs2),
        .rd_addr(ex_wb_rd),
        .rd_data(reg_wdata),
        .rd_we(ex_wb_reg_we && ex_wb_valid),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data)
    );

    // ==================== ID/EX流水线寄存器 ====================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex_pc <= 32'h0;
            id_ex_inst <= 32'h0;
            id_ex_rs1_data <= 32'h0;
            id_ex_rs2_data <= 32'h0;
            id_ex_imm <= 32'h0;
            id_ex_rd <= 5'h0;
            id_ex_reg_we <= 1'b0;
            id_ex_alu_op <= 3'h0;
            id_ex_alu_src <= 1'b0;
            id_ex_mem_we <= 1'b0;
            id_ex_mem_re <= 1'b0;
            id_ex_wb_sel <= 2'h0;
            id_ex_branch <= 1'b0;
            id_ex_jump <= 1'b0;
            id_ex_valid <= 1'b0;
        end else if (flush) begin
            id_ex_pc <= 32'h0;
            id_ex_inst <= 32'h0;
            id_ex_rs1_data <= 32'h0;
            id_ex_rs2_data <= 32'h0;
            id_ex_imm <= 32'h0;
            id_ex_rd <= 5'h0;
            id_ex_reg_we <= 1'b0;
            id_ex_alu_op <= 3'h0;
            id_ex_alu_src <= 1'b0;
            id_ex_mem_we <= 1'b0;
            id_ex_mem_re <= 1'b0;
            id_ex_wb_sel <= 2'h0;
            id_ex_branch <= 1'b0;
            id_ex_jump <= 1'b0;
            id_ex_valid <= 1'b0;
        end else if (!stall) begin
            id_ex_pc <= if_id_pc;
            id_ex_inst <= if_id_inst;
            id_ex_rs1_data <= rs1_data;
            id_ex_rs2_data <= rs2_data;
            id_ex_rd <= rd;
            id_ex_reg_we <= reg_we_id;
            id_ex_alu_op <= alu_op;
            id_ex_alu_src <= alu_src;
            id_ex_mem_we <= mem_we;
            id_ex_mem_re <= mem_re;
            id_ex_wb_sel <= wb_sel;
            id_ex_branch <= branch;
            id_ex_jump <= jump;
            id_ex_valid <= if_id_valid;

            // 选择正确的立即数
            case (opcode)
                7'b0010011: id_ex_imm <= imm_i;  // I-type
                7'b0100011: id_ex_imm <= imm_s;  // S-type
                7'b1100011: id_ex_imm <= imm_b;  // B-type
                7'b0110111: id_ex_imm <= imm_u;  // U-type
                7'b0010111: id_ex_imm <= imm_u;  // U-type
                7'b1101111: id_ex_imm <= imm_j;  // J-type
                default: id_ex_imm <= 32'h0;
            endcase
        end
    end

    // ==================== 流水线阶段3: 执行(EX) ====================
    // ALU输入选择
    assign alu_src1 = id_ex_rs1_data;
    assign alu_src2 = id_ex_alu_src ? id_ex_imm : id_ex_rs2_data;

    // ALU实例
    alu ex_alu (
        .a(alu_src1),
        .b(alu_src2),
        .alu_op(id_ex_alu_op),
        .result(alu_result),
        .zero(alu_zero)
    );

    // 分支判断
    branch_unit branch_ctl (
        .funct3(id_ex_inst[14:12]),
        .rs1_data(id_ex_rs1_data),
        .rs2_data(id_ex_rs2_data),
        .alu_zero(alu_zero),
        .branch(id_ex_branch),
        .branch_taken(branch_taken)
    );

    // 分支目标计算
    assign branch_target = id_ex_pc + id_ex_imm;

    // 数据存储器接口
    assign dmem_addr = alu_result;
    assign dmem_data_out = id_ex_rs2_data;
    assign dmem_we = id_ex_mem_we && id_ex_valid;
    assign dmem_req = (id_ex_mem_we || id_ex_mem_re) && id_ex_valid;

    // 字节选择信号
    assign dmem_sel = 4'b1111;  // 简化：总是字访问

    // ==================== EX/WB流水线寄存器 ====================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_wb_pc <= 32'h0;
            ex_wb_alu_result <= 32'h0;
            ex_wb_mem_data <= 32'h0;
            ex_wb_rd <= 5'h0;
            ex_wb_reg_we <= 1'b0;
            ex_wb_wb_sel <= 2'h0;
            ex_wb_valid <= 1'b0;
        end else if (!stall) begin
            ex_wb_pc <= id_ex_pc;
            ex_wb_alu_result <= alu_result;
            ex_wb_mem_data <= dmem_data_in;
            ex_wb_rd <= id_ex_rd;
            ex_wb_reg_we <= id_ex_reg_we;
            ex_wb_wb_sel <= id_ex_wb_sel;
            ex_wb_valid <= id_ex_valid;
        end
    end

    // ==================== 写回(WB)阶段 ====================
    // 写回数据选择
    assign reg_wdata = (ex_wb_wb_sel == 2'b00) ? ex_wb_alu_result :
                      (ex_wb_wb_sel == 2'b01) ? ex_wb_mem_data :
                      (ex_wb_wb_sel == 2'b10) ? (ex_wb_pc + 4) :
                      32'h0;

    // ==================== 异常和中断处理 ====================
    exception_handler exc_handler (
        .clk(clk),
        .rst_n(rst_n),
        .current_pc(id_ex_pc),
        .inst(id_ex_inst),
        .mem_addr(alu_result),
        .mem_write(id_ex_mem_we),
        .mem_read(id_ex_mem_re),
        .inst_valid(id_ex_valid),
        .mem_access_valid(dmem_req),
        .mret_exec(mret_exec),
        .ext_int(ext_interrupt),
        .timer_int(timer_interrupt),
        .soft_int(soft_interrupt),
        .trap_taken(trap_taken),
        .trap_handler_addr(trap_handler_addr),
        .return_addr(return_addr)
    );

    // ==================== 冒险检测单元 ====================
    hazard_detection hazard_unit (
        .id_ex_rd(id_ex_rd),
        .id_ex_mem_re(id_ex_mem_re),
        .if_id_rs1(rs1),
        .if_id_rs2(rs2),
        .stall(stall),
        .flush(flush)
    );

    // 流水线刷新信号（分支、跳转、异常）
    assign flush = branch_taken || id_ex_jump || trap_taken || mret_exec;

    always @(posedge clk) begin
        if (!rst_n) begin
            debug_pc <= 32'h0;
            debug_instruction <= 32'h0;
            debug_state <= 5'h0;
        end else begin
            debug_pc <= pc;
            debug_instruction <= if_id_inst;

            // 状态编码：流水线阶段 + 异常状态
            debug_state[0] <= if_id_valid;      // IF阶段有效
            debug_state[1] <= id_ex_valid;      // ID阶段有效
            debug_state[2] <= ex_wb_valid;      // EX阶段有效
            debug_state[3] <= trap_taken;       // 陷阱发生
            debug_state[4] <= stall;            // 流水线暂停
        end
    end

    // 寄存器文件调试访问
    // assign debug_registers = reg_file.registers;
endmodule
