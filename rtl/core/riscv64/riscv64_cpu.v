// riscv64_cpu.v
module riscv64_cpu (
    input wire clk,
    input wire rst_n,

    // 指令存储器接口
    output wire [63:0] imem_addr,
    input wire [63:0] imem_data,
    output wire imem_req,
    input wire imem_ack,

    // 数据存储器接口
    output wire [63:0] dmem_addr,
    output wire [63:0] dmem_data_out,
    input wire [63:0] dmem_data_in,
    output wire dmem_we,
    output wire [7:0] dmem_sel,  // 64位需要8字节选择
    output wire dmem_req,
    input wire dmem_ack,

    // 中断输入
    input wire ext_interrupt,
    input wire timer_interrupt,
    input wire soft_interrupt,

    // 调试输出
    output wire [63:0] debug_pc,
    output wire [31:0] debug_instruction,
    output wire [4:0] debug_state
);

    // ==================== RV64I指令集扩展 ====================

    // 流水线寄存器
    // IF/ID寄存器
    reg [63:0] if_id_pc;
    reg [31:0] if_id_inst;  // 指令仍然是32位
    reg if_id_valid;

    // ID/EX寄存器
    reg [63:0] id_ex_pc;
    reg [31:0] id_ex_inst;
    reg [63:0] id_ex_rs1_data;
    reg [63:0] id_ex_rs2_data;
    reg [63:0] id_ex_imm;
    reg [4:0] id_ex_rd;
    reg id_ex_reg_we;
    reg [3:0] id_ex_alu_op;  // 扩展ALU操作码
    reg id_ex_alu_src;
    reg id_ex_mem_we;
    reg id_ex_mem_re;
    reg [1:0] id_ex_wb_sel;
    reg id_ex_branch;
    reg id_ex_jump;
    reg [2:0] id_ex_mem_size;  // 内存访问大小
    reg id_ex_word_op;         // 32位操作标志
    reg id_ex_valid;

    // EX/WB寄存器
    reg [63:0] ex_wb_pc;
    reg [63:0] ex_wb_alu_result;
    reg [63:0] ex_wb_mem_data;
    reg [4:0] ex_wb_rd;
    reg ex_wb_reg_we;
    reg [1:0] ex_wb_wb_sel;
    reg ex_wb_word_op;
    reg ex_wb_valid;

    // 控制信号
    wire stall;
    wire flush;
    wire [63:0] new_pc;
    wire [63:0] branch_target;
    wire branch_taken;

    // 64位寄存器文件信号
    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [4:0] rd;
    wire [63:0] rs1_data;
    wire [63:0] rs2_data;
    wire reg_we;
    wire [63:0] reg_wdata;

    // 64位ALU信号
    wire [63:0] alu_src1;
    wire [63:0] alu_src2;
    wire [63:0] alu_result;
    wire alu_zero;

    // 64位立即数生成
    wire [63:0] imm_i;
    wire [63:0] imm_s;
    wire [63:0] imm_b;
    wire [63:0] imm_u;
    wire [63:0] imm_j;

    // 指令解码信号
    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;

    // ==================== 流水线阶段1: 取指(IF) ====================
    reg [63:0] pc;
    wire [63:0] next_pc;

    assign imem_addr = pc;
    assign imem_req = !stall && !flush;
    assign debug_pc = pc;

    wire trap_taken;
    wire [63:0] trap_handler_addr;
    wire [63:0] return_addr;

    // PC更新逻辑
    assign next_pc = (trap_taken) ? trap_handler_addr :
                    (branch_taken) ? branch_target :
                    (flush) ? return_addr :
                    pc + 8;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 64'h0000000000000000;
        end else if (!stall) begin
            pc <= next_pc;
        end
    end

    // ==================== IF/ID流水线寄存器 ====================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_pc <= 64'h0;
            if_id_inst <= 32'h0;
            if_id_valid <= 1'b0;
        end else if (flush) begin
            if_id_pc <= 64'h0;
            if_id_inst <= 32'h0;
            if_id_valid <= 1'b0;
        end else if (!stall) begin
            if_id_pc <= pc;
            if_id_inst <= imem_data[31:0];  // 取低32位指令
            if_id_valid <= imem_ack;
        end
    end

    // ==================== 流水线阶段2: 译码(ID) ====================
    // 指令解码（RV64I）
    assign opcode = if_id_inst[6:0];
    assign funct3 = if_id_inst[14:12];
    assign funct7 = if_id_inst[31:25];
    assign rs1 = if_id_inst[19:15];
    assign rs2 = if_id_inst[24:20];
    assign rd = if_id_inst[11:7];

    // 64位立即数生成
    assign imm_i = {{52{if_id_inst[31]}}, if_id_inst[31:20]};
    assign imm_s = {{52{if_id_inst[31]}}, if_id_inst[31:25], if_id_inst[11:7]};
    assign imm_b = {{51{if_id_inst[31]}}, if_id_inst[31], if_id_inst[7],
                   if_id_inst[30:25], if_id_inst[11:8], 1'b0};
    assign imm_u = {{32{if_id_inst[31]}}, if_id_inst[31:12], 12'h0};
    assign imm_j = {{43{if_id_inst[31]}}, if_id_inst[31], if_id_inst[19:12],
                   if_id_inst[20], if_id_inst[30:21], 1'b0};

    // 64位控制单元
    wire [3:0] alu_op;
    wire alu_src;
    wire mem_we;
    wire mem_re;
    wire [1:0] wb_sel;
    wire branch;
    wire jump;
    wire reg_we_id;
    wire [2:0] mem_size;
    wire word_op;

    riscv64_control_unit ctrl (
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
        .mem_size(mem_size),
        .word_op(word_op),
        .mret_exec(mret_exec)
    );

    // 64位寄存器文件
    riscv64_regfile reg_file (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_addr(rs1),
        .rs2_addr(rs2),
        .rd_addr(ex_wb_rd),
        .rd_data(reg_wdata),
        .rd_we(ex_wb_reg_we && ex_wb_valid),
        .word_op(ex_wb_word_op),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data)
    );

    // ==================== ID/EX流水线寄存器 ====================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex_pc <= 64'h0;
            id_ex_inst <= 32'h0;
            id_ex_rs1_data <= 64'h0;
            id_ex_rs2_data <= 64'h0;
            id_ex_imm <= 64'h0;
            id_ex_rd <= 5'h0;
            id_ex_reg_we <= 1'b0;
            id_ex_alu_op <= 4'h0;
            id_ex_alu_src <= 1'b0;
            id_ex_mem_we <= 1'b0;
            id_ex_mem_re <= 1'b0;
            id_ex_wb_sel <= 2'h0;
            id_ex_branch <= 1'b0;
            id_ex_jump <= 1'b0;
            id_ex_mem_size <= 3'h0;
            id_ex_word_op <= 1'b0;
            id_ex_valid <= 1'b0;
        end else if (flush) begin
            id_ex_pc <= 64'h0;
            id_ex_inst <= 32'h0;
            id_ex_rs1_data <= 64'h0;
            id_ex_rs2_data <= 64'h0;
            id_ex_imm <= 64'h0;
            id_ex_rd <= 5'h0;
            id_ex_reg_we <= 1'b0;
            id_ex_alu_op <= 4'h0;
            id_ex_alu_src <= 1'b0;
            id_ex_mem_we <= 1'b0;
            id_ex_mem_re <= 1'b0;
            id_ex_wb_sel <= 2'h0;
            id_ex_branch <= 1'b0;
            id_ex_jump <= 1'b0;
            id_ex_mem_size <= 3'h0;
            id_ex_word_op <= 1'b0;
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
            id_ex_mem_size <= mem_size;
            id_ex_word_op <= word_op;
            id_ex_valid <= if_id_valid;

            // 选择正确的立即数
            case (opcode)
                7'b0010011: id_ex_imm <= imm_i;  // I-type
                7'b0100011: id_ex_imm <= imm_s;  // S-type
                7'b1100011: id_ex_imm <= imm_b;  // B-type
                7'b0110111: id_ex_imm <= imm_u;  // U-type
                7'b0010111: id_ex_imm <= imm_u;  // U-type (AUIPC)
                7'b1101111: id_ex_imm <= imm_j;  // J-type
                default: id_ex_imm <= 64'h0;
            endcase
        end
    end

    // ==================== 流水线阶段3: 执行(EX) ====================
    // ALU输入选择
    assign alu_src1 = id_ex_rs1_data;
    assign alu_src2 = id_ex_alu_src ? id_ex_imm : id_ex_rs2_data;

    // 64位ALU实例
    riscv64_alu ex_alu (
        .a(alu_src1),
        .b(alu_src2),
        .alu_op(id_ex_alu_op),
        .word_op(id_ex_word_op),
        .result(alu_result),
        .zero(alu_zero)
    );

    // 分支判断
    riscv64_branch_unit branch_ctl (
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

    // 字节选择信号生成
    riscv64_mem_sel mem_sel_gen (
        .addr(alu_result[2:0]),
        .mem_size(id_ex_mem_size),
        .mem_sel(dmem_sel)
    );

    // ==================== EX/WB流水线寄存器 ====================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_wb_pc <= 64'h0;
            ex_wb_alu_result <= 64'h0;
            ex_wb_mem_data <= 64'h0;
            ex_wb_rd <= 5'h0;
            ex_wb_reg_we <= 1'b0;
            ex_wb_wb_sel <= 2'h0;
            ex_wb_word_op <= 1'b0;
            ex_wb_valid <= 1'b0;
        end else if (!stall) begin
            ex_wb_pc <= id_ex_pc;
            ex_wb_alu_result <= alu_result;
            ex_wb_mem_data <= dmem_data_in;
            ex_wb_rd <= id_ex_rd;
            ex_wb_reg_we <= id_ex_reg_we;
            ex_wb_wb_sel <= id_ex_wb_sel;
            ex_wb_word_op <= id_ex_word_op;
            ex_wb_valid <= id_ex_valid;
        end
    end

    // ==================== 写回(WB)阶段 ====================
    // 写回数据选择
    assign reg_wdata = (ex_wb_wb_sel == 2'b00) ? ex_wb_alu_result :
                      (ex_wb_wb_sel == 2'b01) ? ex_wb_mem_data :
                      (ex_wb_wb_sel == 2'b10) ? (ex_wb_pc + 4) :
                      64'h0;

    // ==================== 异常和中断处理（64位扩展） ====================
    // 注意：异常处理模块也需要相应修改为64位
    // riscv64_exception_handler exc_handler (
    //     .clk(clk),
    //     .rst_n(rst_n),
    //     .current_pc(id_ex_pc),
    //     .inst(id_ex_inst),
    //     .mem_addr(alu_result),
    //     .mem_write(id_ex_mem_we),
    //     .mem_read(id_ex_mem_re),
    //     .mem_size(id_ex_mem_size),
    //     .inst_valid(id_ex_valid),
    //     .mem_access_valid(dmem_req),
    //     .mret_exec(mret_exec),
    //     .ext_int(ext_interrupt),
    //     .timer_int(timer_interrupt),
    //     .soft_int(soft_interrupt),
    //     .trap_taken(trap_taken),
    //     .trap_handler_addr(trap_handler_addr),
    //     .return_addr(return_addr)
    // );

    // ==================== 冒险检测单元 ====================
    hazard_detection hazard_unit (
        .id_ex_rd(id_ex_rd),
        .id_ex_mem_re(id_ex_mem_re),
        .if_id_rs1(rs1),
        .if_id_rs2(rs2),
        .stall(stall),
        .flush(flush)
    );

    // 流水线刷新信号
    assign flush = branch_taken || id_ex_jump || trap_taken || mret_exec;

    // 调试信号
    assign debug_instruction = if_id_inst;
    assign debug_state = {stall, flush, branch_taken, trap_taken, mret_exec};

endmodule
