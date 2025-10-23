module riscv64_cpu_core (
    input  wire        clk,
    input  wire        rst_n,

    // 指令存储器接口
    input  wire [31:0] inst_data,      // 指令数据输入
    output wire [63:0] inst_addr,      // 指令地址输出

    // 数据存储器接口
    input  wire [63:0] mem_data_in,    // 内存数据输入
    output wire [63:0] mem_addr,       // 内存地址输出
    output wire [63:0] mem_data_out,   // 内存数据输出
    output wire        mem_write_en,   // 内存写使能
    output wire        mem_read_en,    // 内存读使能
    output wire [7:0]  mem_byte_en,    // 字节使能

    // 调试接口
    output wire [63:0] debug_pc,
    output wire [31:0] debug_inst,
    output wire        debug_stall,
    output wire        debug_flush
);

// ============================================================================
// 流水线寄存器定义
// ============================================================================

// IF/ID 寄存器
reg [63:0] if_id_pc;
reg [31:0] if_id_inst;
reg        if_id_valid;

// ID/EX 寄存器
reg [63:0] id_ex_pc;
reg [63:0] id_ex_imm;
reg [63:0] id_ex_rs1_data;
reg [63:0] id_ex_rs2_data;
reg [4:0]  id_ex_rd;
reg [4:0]  id_ex_rs1;
reg [4:0]  id_ex_rs2;
reg        id_ex_reg_write;
reg [2:0]  id_ex_alu_op;
reg        id_ex_alu_src;
reg        id_ex_mem_read;
reg        id_ex_mem_write;
reg [1:0]  id_ex_mem_to_reg;
reg        id_ex_branch;
reg        id_ex_jump;
reg [2:0]  id_ex_funct3;
reg [6:0]  id_ex_funct7;
reg        id_ex_valid;

// EX/MEM 寄存器
reg [63:0] ex_mem_alu_result;
reg [63:0] ex_mem_rs2_data;
reg [4:0]  ex_mem_rd;
reg        ex_mem_reg_write;
reg        ex_mem_mem_read;
reg        ex_mem_mem_write;
reg [1:0]  ex_mem_mem_to_reg;
reg [2:0]  ex_mem_funct3;
reg        ex_mem_valid;

// MEM/WB 寄存器
reg [63:0] mem_wb_mem_data;
reg [63:0] mem_wb_alu_result;
reg [4:0]  mem_wb_rd;
reg        mem_wb_reg_write;
reg [1:0]  mem_wb_mem_to_reg;
reg        mem_wb_valid;

// ============================================================================
// 内部信号定义
// ============================================================================

// PC控制
wire [63:0] next_pc;
wire [63:0] branch_target;
wire [63:0] jump_target;
wire        pc_enable;

// 冒险检测信号
wire [2:0]  hazard_type;
wire        stall;
wire        flush;
wire [1:0]  forward_a;
wire [1:0]  forward_b;
wire [3:0]  raw_conflicts;
wire        has_waw;
wire        has_war;

// 分支控制
wire        branch_taken;
wire        jump_taken;
wire [63:0] alu_result;

// 寄存器文件
reg [63:0] reg_file [0:31];

// 指令解码信号
wire [6:0] opcode;
wire [4:0] rs1, rs2, rd;
wire [2:0] funct3;
wire [6:0] funct7;
wire [63:0] imm_extended;

// 前向数据选择
wire [63:0] rs1_data_forwarded;
wire [63:0] rs2_data_forwarded;

// ============================================================================
// IF阶段：指令取指
// ============================================================================

reg [63:0] pc_reg;

assign inst_addr = pc_reg;
assign debug_pc = pc_reg;

// PC更新逻辑
assign pc_enable = ~stall;
assign next_pc = (branch_taken & id_ex_branch) ? branch_target :
                 (jump_taken) ? jump_target :
                 pc_reg + 4;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pc_reg <= 64'h8000_0000; // 复位地址
    end else if (pc_enable) begin
        pc_reg <= next_pc;
    end
end

// IF/ID流水线寄存器
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        if_id_pc <= 64'h0;
        if_id_inst <= 32'h0;
        if_id_valid <= 1'b0;
    end else if (flush) begin
        // 刷新：插入空指令
        if_id_pc <= 64'h0;
        if_id_inst <= 32'h00000013; // NOP: addi x0, x0, 0
        if_id_valid <= 1'b0;
    end else if (stall) begin
        // 暂停：保持当前值
        if_id_pc <= if_id_pc;
        if_id_inst <= if_id_inst;
        if_id_valid <= if_id_valid;
    end else begin
        // 正常推进
        if_id_pc <= pc_reg;
        if_id_inst <= inst_data;
        if_id_valid <= 1'b1;
    end
end

// ============================================================================
// ID阶段：指令译码
// ============================================================================

// 指令字段提取
assign opcode = if_id_inst[6:0];
assign rd = if_id_inst[11:7];
assign rs1 = if_id_inst[19:15];
assign rs2 = if_id_inst[24:20];
assign funct3 = if_id_inst[14:12];
assign funct7 = if_id_inst[31:25];

// 立即数扩展
imm_extend imm_extend_unit (
    .inst(if_id_inst),
    .imm_out(imm_extended)
);

// 寄存器文件读取
wire [63:0] rs1_data = (rs1 != 5'b0) ? reg_file[rs1] : 64'h0;
wire [63:0] rs2_data = (rs2 != 5'b0) ? reg_file[rs2] : 64'h0;

// 控制单元
control_unit ctrl_unit (
    .opcode(opcode),
    .funct3(funct3),
    .funct7(funct7),
    .reg_write(id_reg_write),
    .alu_op(id_alu_op),
    .alu_src(id_alu_src),
    .mem_read(id_mem_read),
    .mem_write(id_mem_write),
    .mem_to_reg(id_mem_to_reg),
    .branch(id_branch),
    .jump(id_jump)
);

// ID/EX流水线寄存器
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        id_ex_pc <= 64'h0;
        id_ex_imm <= 64'h0;
        id_ex_rs1_data <= 64'h0;
        id_ex_rs2_data <= 64'h0;
        id_ex_rd <= 5'h0;
        id_ex_rs1 <= 5'h0;
        id_ex_rs2 <= 5'h0;
        id_ex_reg_write <= 1'b0;
        id_ex_alu_op <= 3'b0;
        id_ex_alu_src <= 1'b0;
        id_ex_mem_read <= 1'b0;
        id_ex_mem_write <= 1'b0;
        id_ex_mem_to_reg <= 2'b0;
        id_ex_branch <= 1'b0;
        id_ex_jump <= 1'b0;
        id_ex_funct3 <= 3'b0;
        id_ex_funct7 <= 7'b0;
        id_ex_valid <= 1'b0;
    end else if (flush) begin
        // 刷新：插入空操作
        {id_ex_reg_write, id_ex_alu_op, id_ex_alu_src,
         id_ex_mem_read, id_ex_mem_write, id_ex_mem_to_reg,
         id_ex_branch, id_ex_jump} <= 13'b0;
        id_ex_rd <= 5'b0;
        id_ex_valid <= 1'b0;
    end else if (stall) begin
        // 暂停：保持当前值
        id_ex_pc <= id_ex_pc;
        id_ex_imm <= id_ex_imm;
        id_ex_rs1_data <= id_ex_rs1_data;
        id_ex_rs2_data <= id_ex_rs2_data;
        id_ex_rd <= id_ex_rd;
        id_ex_rs1 <= id_ex_rs1;
        id_ex_rs2 <= id_ex_rs2;
        id_ex_reg_write <= id_ex_reg_write;
        id_ex_alu_op <= id_ex_alu_op;
        id_ex_alu_src <= id_ex_alu_src;
        id_ex_mem_read <= id_ex_mem_read;
        id_ex_mem_write <= id_ex_mem_write;
        id_ex_mem_to_reg <= id_ex_mem_to_reg;
        id_ex_branch <= id_ex_branch;
        id_ex_jump <= id_ex_jump;
        id_ex_funct3 <= id_ex_funct3;
        id_ex_funct7 <= id_ex_funct7;
        id_ex_valid <= id_ex_valid;
    end else begin
        // 正常推进
        id_ex_pc <= if_id_pc;
        id_ex_imm <= imm_extended;
        id_ex_rs1_data <= rs1_data;
        id_ex_rs2_data <= rs2_data;
        id_ex_rd <= rd;
        id_ex_rs1 <= rs1;
        id_ex_rs2 <= rs2;
        id_ex_reg_write <= id_reg_write;
        id_ex_alu_op <= id_alu_op;
        id_ex_alu_src <= id_alu_src;
        id_ex_mem_read <= id_mem_read;
        id_ex_mem_write <= id_mem_write;
        id_ex_mem_to_reg <= id_mem_to_reg;
        id_ex_branch <= id_branch;
        id_ex_jump <= id_jump;
        id_ex_funct3 <= funct3;
        id_ex_funct7 <= funct7;
        id_ex_valid <= if_id_valid;
    end
end

// ============================================================================
// EX阶段：执行
// ============================================================================

// ALU操作数选择
wire [63:0] alu_operand_a = rs1_data_forwarded;
wire [63:0] alu_operand_b = id_ex_alu_src ? id_ex_imm : rs2_data_forwarded;

// ALU实例化
alu alu_unit (
    .a(alu_operand_a),
    .b(alu_operand_b),
    .alu_op(id_ex_alu_op),
    .funct3(id_ex_funct3),
    .funct7(id_ex_funct7),
    .result(alu_result)
);

// 分支目标计算
assign branch_target = id_ex_pc + id_ex_imm;
assign jump_target = alu_result & ~64'h1; // JALR目标，最低位置0

// 分支判断
branch_unit branch_check (
    .rs1_data(rs1_data_forwarded),
    .rs2_data(rs2_data_forwarded),
    .branch_type(id_ex_funct3),
    .branch_taken(branch_taken)
);

assign jump_taken = id_ex_jump;

// EX/MEM流水线寄存器
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        ex_mem_alu_result <= 64'h0;
        ex_mem_rs2_data <= 64'h0;
        ex_mem_rd <= 5'h0;
        ex_mem_reg_write <= 1'b0;
        ex_mem_mem_read <= 1'b0;
        ex_mem_mem_write <= 1'b0;
        ex_mem_mem_to_reg <= 2'b0;
        ex_mem_funct3 <= 3'b0;
        ex_mem_valid <= 1'b0;
    end else if (flush) begin
        // 刷新：插入空操作
        ex_mem_reg_write <= 1'b0;
        ex_mem_mem_read <= 1'b0;
        ex_mem_mem_write <= 1'b0;
        ex_mem_valid <= 1'b0;
    end else begin
        // 正常推进
        ex_mem_alu_result <= alu_result;
        ex_mem_rs2_data <= rs2_data_forwarded;
        ex_mem_rd <= id_ex_rd;
        ex_mem_reg_write <= id_ex_reg_write;
        ex_mem_mem_read <= id_ex_mem_read;
        ex_mem_mem_write <= id_ex_mem_write;
        ex_mem_mem_to_reg <= id_ex_mem_to_reg;
        ex_mem_funct3 <= id_ex_funct3;
        ex_mem_valid <= id_ex_valid;
    end
end

// ============================================================================
// MEM阶段：内存访问
// ============================================================================

// 内存接口
assign mem_addr = ex_mem_alu_result;
assign mem_data_out = ex_mem_rs2_data;
assign mem_write_en = ex_mem_mem_write & ex_mem_valid;
assign mem_read_en = ex_mem_mem_read & ex_mem_valid;

// 字节使能生成
mem_byte_enable byte_enable_gen (
    .addr(ex_mem_alu_result[2:0]),
    .funct3(ex_mem_funct3),
    .byte_en(mem_byte_en)
);

// MEM/WB流水线寄存器
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        mem_wb_mem_data <= 64'h0;
        mem_wb_alu_result <= 64'h0;
        mem_wb_rd <= 5'h0;
        mem_wb_reg_write <= 1'b0;
        mem_wb_mem_to_reg <= 2'b0;
        mem_wb_valid <= 1'b0;
    end else begin
        // 正常推进
        mem_wb_mem_data <= mem_data_in;
        mem_wb_alu_result <= ex_mem_alu_result;
        mem_wb_rd <= ex_mem_rd;
        mem_wb_reg_write <= ex_mem_reg_write;
        mem_wb_mem_to_reg <= ex_mem_mem_to_reg;
        mem_wb_valid <= ex_mem_valid;
    end
end

// ============================================================================
// WB阶段：写回
// ============================================================================

// 写回数据选择
wire [63:0] wb_data;
assign wb_data = (mem_wb_mem_to_reg == 2'b00) ? mem_wb_alu_result :  // ALU结果
                 (mem_wb_mem_to_reg == 2'b01) ? mem_wb_mem_data :    // 内存数据
                 (mem_wb_mem_to_reg == 2'b10) ? (mem_wb_alu_result + 4) : // PC+4 (JAL)
                 64'h0;

// 寄存器文件写回
always @(posedge clk) begin
    if (mem_wb_reg_write && mem_wb_valid && (mem_wb_rd != 5'b0)) begin
        reg_file[mem_wb_rd] <= wb_data;
    end
end

// 初始化寄存器文件（用于仿真）
integer i;
initial begin
    for (i = 0; i < 32; i = i + 1) begin
        reg_file[i] = 64'h0;
    end
end

// ============================================================================
// 冒险检测单元集成
// ============================================================================

riscv64_enhanced_hazard_detection_unit hazard_detector (
    .if_id_inst(if_id_inst),
    .id_ex_inst({id_ex_funct7, id_ex_rs2, id_ex_rs1, id_ex_funct3, id_ex_rd, 7'b0}), // 重构指令
    .ex_mem_inst({25'b0, ex_mem_funct3, ex_mem_rd, 7'b0}), // 简化重构

    .id_rs1(rs1),
    .id_rs2(rs2),
    .id_rd(rd),
    .id_reg_write(id_reg_write),

    .ex_rd(id_ex_rd),
    .ex_reg_write(id_ex_reg_write),
    .ex_mem_to_reg(id_ex_mem_to_reg),

    .mem_rd(ex_mem_rd),
    .mem_reg_write(ex_mem_reg_write),
    .mem_mem_to_reg(ex_mem_mem_to_reg),

    .wb_rd(mem_wb_rd),
    .wb_reg_write(mem_wb_reg_write),

    .branch_taken(branch_taken & id_ex_branch),
    .jump_taken(jump_taken),

    .hazard_type(hazard_type),
    .stall(stall),
    .flush(flush),
    .forward_a(forward_a),
    .forward_b(forward_b),

    .raw_conflicts(raw_conflicts),
    .has_waw(has_waw),
    .has_war(has_war)
);

// ============================================================================
// 前向数据选择逻辑
// ============================================================================

// 操作数A前向选择
assign rs1_data_forwarded =
    (forward_a == 2'b00) ? id_ex_rs1_data :                    // 无前向
    (forward_a == 2'b01) ? mem_data_in :                       // 从MEM阶段内存数据前向
    (forward_a == 2'b10) ? ex_mem_alu_result :                 // 从EX阶段ALU结果前向
    (forward_a == 2'b11) ? (ex_mem_mem_to_reg == 2'b01 ? mem_data_in : ex_mem_alu_result) : // 从MEM阶段前向
    64'h0;

// 操作数B前向选择
assign rs2_data_forwarded =
    (forward_b == 2'b00) ? id_ex_rs2_data :                    // 无前向
    (forward_b == 2'b01) ? mem_data_in :                       // 从MEM阶段内存数据前向
    (forward_b == 2'b10) ? ex_mem_alu_result :                 // 从EX阶段ALU结果前向
    (forward_b == 2'b11) ? (ex_mem_mem_to_reg == 2'b01 ? mem_data_in : ex_mem_alu_result) : // 从MEM阶段前向
    64'h0;

// ============================================================================
// 调试信号
// ============================================================================

assign debug_inst = if_id_inst;
assign debug_stall = stall;
assign debug_flush = flush;

endmodule

// ============================================================================
// 子模块实现
// ============================================================================

// 立即数扩展模块
module imm_extend (
    input  wire [31:0] inst,
    output wire [63:0] imm_out
);
    reg [63:0] imm;

    always @(*) begin
        case (inst[6:0])
            // I-type
            7'b0010011, 7'b0000011, 7'b1100111:
                imm = {{52{inst[31]}}, inst[31:20]};
            // S-type
            7'b0100011:
                imm = {{52{inst[31]}}, inst[31:25], inst[11:7]};
            // B-type
            7'b1100011:
                imm = {{52{inst[31]}}, inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
            // U-type
            7'b0110111, 7'b0010111:
                imm = {inst[31:12], 12'b0};
            // J-type
            7'b1101111:
                imm = {{44{inst[31]}}, inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
            default:
                imm = 64'h0;
        endcase
    end

    assign imm_out = imm;
endmodule

// 控制单元模块
module control_unit (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg        reg_write,
    output reg [2:0]  alu_op,
    output reg        alu_src,
    output reg        mem_read,
    output reg        mem_write,
    output reg [1:0]  mem_to_reg,
    output reg        branch,
    output reg        jump
);
    always @(*) begin
        // 默认值
        {reg_write, alu_op, alu_src, mem_read, mem_write, mem_to_reg, branch, jump} = 13'b0;

        case (opcode)
            // R-type
            7'b0110011: begin
                reg_write = 1'b1;
                alu_op = 3'b000; // 由funct3和funct7进一步确定
                alu_src = 1'b0;
                mem_to_reg = 2'b00;
            end
            // I-type (ALU)
            7'b0010011: begin
                reg_write = 1'b1;
                alu_op = 3'b001;
                alu_src = 1'b1;
                mem_to_reg = 2'b00;
            end
            // Load
            7'b0000011: begin
                reg_write = 1'b1;
                alu_op = 3'b010;
                alu_src = 1'b1;
                mem_read = 1'b1;
                mem_to_reg = 2'b01;
            end
            // Store
            7'b0100011: begin
                alu_op = 3'b011;
                alu_src = 1'b1;
                mem_write = 1'b1;
            end
            // Branch
            7'b1100011: begin
                alu_op = 3'b100;
                branch = 1'b1;
            end
            // JAL
            7'b1101111: begin
                reg_write = 1'b1;
                alu_op = 3'b101;
                jump = 1'b1;
                mem_to_reg = 2'b10;
            end
            // JALR
            7'b1100111: begin
                reg_write = 1'b1;
                alu_op = 3'b110;
                alu_src = 1'b1;
                jump = 1'b1;
                mem_to_reg = 2'b10;
            end
            // LUI
            7'b0110111: begin
                reg_write = 1'b1;
                alu_op = 3'b111;
                alu_src = 1'b1;
                mem_to_reg = 2'b00;
            end
            // AUIPC
            7'b0010111: begin
                reg_write = 1'b1;
                alu_op = 3'b000;
                alu_src = 1'b1;
                mem_to_reg = 2'b00;
            end
        endcase
    end
endmodule

// ALU模块
module alu (
    input  wire [63:0] a,
    input  wire [63:0] b,
    input  wire [2:0]  alu_op,
    input  wire [2:0]  funct3,
    input  wire [6:0]  funct7,
    output reg  [63:0] result
);
    wire [63:0] add_sub_result;
    wire [63:0] shift_result;

    // 加减法
    assign add_sub_result = (alu_op == 3'b000 && funct7[5]) ? (a - b) : (a + b);

    // 移位操作
    assign shift_result = (funct3 == 3'b001) ? (a << b[5:0]) :        // SLL
                         (funct3 == 3'b101 && funct7[5]) ? ($signed(a) >>> b[5:0]) : // SRA
                         (a >> b[5:0]);                              // SRL

    always @(*) begin
        case (alu_op)
            3'b000: result = add_sub_result;                    // ADD/SUB
            3'b001: result = add_sub_result;                    // ADDI
            3'b010: result = add_sub_result;                    // Load/Store地址计算
            3'b011: result = add_sub_result;                    // Store地址计算
            default: begin
                case (funct3)
                    3'b000: result = add_sub_result;            // ADD/SUB
                    3'b001: result = shift_result;              // Shift
                    3'b010: result = ($signed(a) < $signed(b)) ? 64'h1 : 64'h0; // SLT
                    3'b011: result = (a < b) ? 64'h1 : 64'h0;   // SLTU
                    3'b100: result = a ^ b;                     // XOR
                    3'b101: result = shift_result;              // Shift
                    3'b110: result = a | b;                     // OR
                    3'b111: result = a & b;                     // AND
                    default: result = 64'h0;
                endcase
            end
        endcase
    end
endmodule

// 分支判断模块
module branch_unit (
    input  wire [63:0] rs1_data,
    input  wire [63:0] rs2_data,
    input  wire [2:0]  branch_type,
    output reg         branch_taken
);
    always @(*) begin
        case (branch_type)
            3'b000: branch_taken = (rs1_data == rs2_data);  // BEQ
            3'b001: branch_taken = (rs1_data != rs2_data);  // BNE
            3'b100: branch_taken = ($signed(rs1_data) < $signed(rs2_data)); // BLT
            3'b101: branch_taken = ($signed(rs1_data) >= $signed(rs2_data)); // BGE
            3'b110: branch_taken = (rs1_data < rs2_data);   // BLTU
            3'b111: branch_taken = (rs1_data >= rs2_data);  // BGEU
            default: branch_taken = 1'b0;
        endcase
    end
endmodule

// 内存字节使能生成模块
module mem_byte_enable (
    input  wire [2:0]  addr,
    input  wire [2:0]  funct3,
    output reg  [7:0]  byte_en
);
    always @(*) begin
        case (funct3)
            // Byte
            3'b000, 3'b001: byte_en = 8'b0000_0001 << addr;
            // Halfword
            3'b010, 3'b011: byte_en = (addr[1] ? 8'b1111_0000 : 8'b0000_1111);
            // Word (RV64)
            3'b100, 3'b101: byte_en = (addr[2] ? 8'b1111_0000 : 8'b0000_1111);
            // Doubleword
            default: byte_en = 8'b1111_1111;
        endcase
    end
endmodule
