module riscv64_cpu_core_optimized (
    input  wire        clk,
    input  wire        rst_n,

    // 指令存储器接口
    input  wire [31:0] inst_data,
    output wire [63:0] inst_addr,

    // 数据存储器接口
    input  wire [63:0] mem_data_in,
    output wire [63:0] mem_addr,
    output wire [63:0] mem_data_out,
    output wire        mem_write_en,
    output wire        mem_read_en,
    output wire [7:0]  mem_byte_en,

    // 调试接口
    output wire [63:0] debug_pc,
    output wire [31:0] debug_inst,
    output wire [3:0]  debug_hazard_type,
    output wire        debug_stall_if,
    output wire        debug_stall_id
);

    // 流水线寄存器
    reg [63:0] if_id_pc;
    reg [31:0] if_id_inst;
    reg        if_id_valid;

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

    reg [63:0] ex_mem_alu_result;
    reg [63:0] ex_mem_rs2_data;
    reg [4:0]  ex_mem_rd;
    reg        ex_mem_reg_write;
    reg        ex_mem_mem_read;
    reg        ex_mem_mem_write;
    reg [1:0]  ex_mem_mem_to_reg;
    reg [2:0]  ex_mem_funct3;
    reg        ex_mem_valid;

    reg [63:0] mem_wb_mem_data;
    reg [63:0] mem_wb_alu_result;
    reg [4:0]  mem_wb_rd;
    reg        mem_wb_reg_write;
    reg [1:0]  mem_wb_mem_to_reg;
    reg        mem_wb_valid;

    // 冒险检测信号
    wire        stall_if, stall_id, stall_ex, stall_mem, stall_wb;
    wire        flush_if, flush_id, flush_ex, flush_mem;
    wire [1:0]  forward_a, forward_b;
    wire [3:0]  hazard_type;
    wire [3:0]  raw_conflicts;
    wire        has_waw, has_war;

    // 其他内部信号...

    // 冒险检测单元实例化
    enhanced_hazard_detection_unit hazard_detector (
        .if_id_inst(if_id_inst),
        .id_ex_inst(id_ex_inst),
        .ex_mem_inst(ex_mem_inst),

        .id_rs1(if_id_inst[19:15]),
        .id_rs2(if_id_inst[24:20]),
        .id_rd(if_id_inst[11:7]),
        .id_reg_write(id_reg_write), // 从控制单元获取

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

        .stall_if(stall_if),
        .stall_id(stall_id),
        .stall_ex(stall_ex),
        .stall_mem(stall_mem),
        .stall_wb(stall_wb),

        .flush_if(flush_if),
        .flush_id(flush_id),
        .flush_ex(flush_ex),
        .flush_mem(flush_mem),

        .forward_a(forward_a),
        .forward_b(forward_b),

        .hazard_type(hazard_type),
        .raw_conflicts(raw_conflicts),
        .has_waw(has_waw),
        .has_war(has_war)
    );

    // ============================================================================
    // 精细化的流水线控制
    // ============================================================================

    // IF阶段：指令取指
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_pc <= 64'h0;
            if_id_inst <= 32'h0;
            if_id_valid <= 1'b0;
        end else if (flush_if) begin
            // 刷新IF阶段
            if_id_pc <= 64'h0;
            if_id_inst <= 32'h00000013; // 插入NOP
            if_id_valid <= 1'b0;
        end else if (stall_if) begin
            // 暂停IF阶段：保持当前值
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

    // ID阶段：指令译码
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 复位所有ID/EX寄存器
            {id_ex_pc, id_ex_imm, id_ex_rs1_data, id_ex_rs2_data} <= 0;
            {id_ex_rd, id_ex_rs1, id_ex_rs2} <= 15'b0;
            {id_ex_reg_write, id_ex_alu_op, id_ex_alu_src, id_ex_mem_read,
             id_ex_mem_write, id_ex_mem_to_reg, id_ex_branch, id_ex_jump} <= 0;
            {id_ex_funct3, id_ex_funct7} <= 10'b0;
            id_ex_valid <= 1'b0;
        end else if (flush_id) begin
            // 刷新ID阶段：插入空操作
            {id_ex_reg_write, id_ex_alu_op, id_ex_alu_src, id_ex_mem_read,
             id_ex_mem_write, id_ex_mem_to_reg, id_ex_branch, id_ex_jump} <= 0;
            id_ex_rd <= 5'b0;
            id_ex_valid <= 1'b0;
        end else if (stall_id) begin
            // 暂停ID阶段：保持当前值
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
            id_ex_rd <= if_id_inst[11:7];
            id_ex_rs1 <= if_id_inst[19:15];
            id_ex_rs2 <= if_id_inst[24:20];
            id_ex_reg_write <= id_reg_write;
            id_ex_alu_op <= id_alu_op;
            id_ex_alu_src <= id_alu_src;
            id_ex_mem_read <= id_mem_read;
            id_ex_mem_write <= id_mem_write;
            id_ex_mem_to_reg <= id_mem_to_reg;
            id_ex_branch <= id_branch;
            id_ex_jump <= id_jump;
            id_ex_funct3 <= if_id_inst[14:12];
            id_ex_funct7 <= if_id_inst[31:25];
            id_ex_valid <= if_id_valid;
        end
    end

    // EX阶段：执行
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {ex_mem_alu_result, ex_mem_rs2_data} <= 0;
            ex_mem_rd <= 5'b0;
            {ex_mem_reg_write, ex_mem_mem_read, ex_mem_mem_write, ex_mem_mem_to_reg} <= 0;
            ex_mem_funct3 <= 3'b0;
            ex_mem_valid <= 1'b0;
        end else if (flush_ex) begin
            // 刷新EX阶段：插入空操作
            ex_mem_reg_write <= 1'b0;
            ex_mem_mem_read <= 1'b0;
            ex_mem_mem_write <= 1'b0;
            ex_mem_valid <= 1'b0;
        end else if (stall_ex) begin
            // 暂停EX阶段：保持当前值
            ex_mem_alu_result <= ex_mem_alu_result;
            ex_mem_rs2_data <= ex_mem_rs2_data;
            ex_mem_rd <= ex_mem_rd;
            ex_mem_reg_write <= ex_mem_reg_write;
            ex_mem_mem_read <= ex_mem_mem_read;
            ex_mem_mem_write <= ex_mem_mem_write;
            ex_mem_mem_to_reg <= ex_mem_mem_to_reg;
            ex_mem_funct3 <= ex_mem_funct3;
            ex_mem_valid <= ex_mem_valid;
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

    // MEM阶段：内存访问
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            {mem_wb_mem_data, mem_wb_alu_result} <= 0;
            mem_wb_rd <= 5'b0;
            {mem_wb_reg_write, mem_wb_mem_to_reg} <= 0;
            mem_wb_valid <= 1'b0;
        end else if (flush_mem) begin
            // 刷新MEM阶段：插入空操作
            mem_wb_reg_write <= 1'b0;
            mem_wb_valid <= 1'b0;
        end else if (stall_mem) begin
            // 暂停MEM阶段：保持当前值
            mem_wb_mem_data <= mem_wb_mem_data;
            mem_wb_alu_result <= mem_wb_alu_result;
            mem_wb_rd <= mem_wb_rd;
            mem_wb_reg_write <= mem_wb_reg_write;
            mem_wb_mem_to_reg <= mem_wb_mem_to_reg;
            mem_wb_valid <= mem_wb_valid;
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

    // WB阶段：写回（通常不需要暂停）
    always @(posedge clk) begin
        if (mem_wb_reg_write && mem_wb_valid && (mem_wb_rd != 5'b0) && !stall_wb) begin
            reg_file[mem_wb_rd] <= wb_data;
        end
    end

    // ============================================================================
    // 调试信号分配
    // ============================================================================

    assign debug_pc = if_id_pc;
    assign debug_inst = if_id_inst;
    assign debug_hazard_type = hazard_type;
    assign debug_stall_if = stall_if;
    assign debug_stall_id = stall_id;

    // 其他CPU逻辑...

endmodule
