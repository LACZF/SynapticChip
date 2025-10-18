`include "riscv64_instruction_defs.v"

module riscv64_a_extension #(
    parameter DATA_WIDTH = 64
)(
    input wire                  funct7_30,
    input wire [2:0]            funct3,
    input wire [6:0]            opcode,
    input wire [DATA_WIDTH-1:0] rs1_data_i,
    input wire [DATA_WIDTH-1:0] rs2_data_i,
    input wire [DATA_WIDTH-1:0] mem_data_i,  // 从内存读取的数据
    output wire [DATA_WIDTH-1:0] alu_result_o,
    output wire [DATA_WIDTH-1:0] mem_data_o,  // 要写入内存的数据
    output wire                 is_a_extension,
    output wire                 load_reserved,
    output wire                 store_conditional
);

    // 信号定义
    reg [DATA_WIDTH-1:0] a_result;
    reg [DATA_WIDTH-1:0] a_mem_data;
    reg                  a_load_reserved;
    reg                  a_store_conditional;

    // 判断是否为A扩展指令（原子操作指令）
    assign is_a_extension = (opcode == `OPCODE_ATOMIC);

    // 原子操作处理
    always @(*) begin
        if (is_a_extension) begin
            a_load_reserved = 1'b0;
            a_store_conditional = 1'b0;

            case (funct3)
                // LR.D (原子加载保留双字)
                `FUNCT3_LR_D: begin
                    a_result = mem_data_i; // 返回从内存读取的值
                    a_mem_data = 64'b0;    // 不需要写入内存
                    a_load_reserved = 1'b1;
                end

                // SC.D (原子条件存储双字)
                `FUNCT3_SC_D: begin
                    a_result = 64'b0;      // 默认成功
                    a_mem_data = rs2_data_i; // 要存储的数据
                    a_store_conditional = 1'b1;
                end

                // AMOSWAP.D (原子交换双字)
                `FUNCT3_AMOSWAP_D: begin
                    a_result = mem_data_i; // 返回原来的值
                    a_mem_data = rs2_data_i; // 存储新值
                end

                // AMOADD.D (原子加法双字)
                `FUNCT3_AMOADD_D: begin
                    a_result = mem_data_i; // 返回原来的值
                    a_mem_data = mem_data_i + rs2_data_i; // 存储新值
                end

                // AMOXOR.D (原子异或双字)
                `FUNCT3_AMOXOR_D: begin
                    a_result = mem_data_i; // 返回原来的值
                    a_mem_data = mem_data_i ^ rs2_data_i; // 存储新值
                end

                // AMOAND.D (原子与双字)
                `FUNCT3_AMOAND_D: begin
                    a_result = mem_data_i; // 返回原来的值
                    a_mem_data = mem_data_i & rs2_data_i; // 存储新值
                end

                // AMOOR.D (原子或双字)
                `FUNCT3_AMOOR_D: begin
                    a_result = mem_data_i; // 返回原来的值
                    a_mem_data = mem_data_i | rs2_data_i; // 存储新值
                end

                // AMOMIN.D (原子取最小值双字，有符号)
                `FUNCT3_AMOMIN_D: begin
                    a_result = mem_data_i; // 返回原来的值
                    a_mem_data = ($signed(mem_data_i) < $signed(rs2_data_i)) ? mem_data_i : rs2_data_i; // 存储较小的值
                end

                // AMOMINU.D (原子取最小值双字，无符号)
                `FUNCT3_AMOMINU_D: begin
                    a_result = mem_data_i; // 返回原来的值
                    a_mem_data = (mem_data_i < rs2_data_i) ? mem_data_i : rs2_data_i; // 存储较小的值
                end

                // AMOMAX.D (原子取最大值双字，有符号)
                `FUNCT3_AMOMAX_D: begin
                    a_result = mem_data_i; // 返回原来的值
                    a_mem_data = ($signed(mem_data_i) > $signed(rs2_data_i)) ? mem_data_i : rs2_data_i; // 存储较大的值
                end

                // AMOMAXU.D (原子取最大值双字，无符号)
                `FUNCT3_AMOMAXU_D: begin
                    a_result = mem_data_i; // 返回原来的值
                    a_mem_data = (mem_data_i > rs2_data_i) ? mem_data_i : rs2_data_i; // 存储较大的值
                end

                default: begin
                    a_result = 64'b0;
                    a_mem_data = 64'b0;
                end
            endcase
        end else begin
            a_result = 64'b0;
            a_mem_data = 64'b0;
            a_load_reserved = 1'b0;
            a_store_conditional = 1'b0;
        end
    end

    // 输出结果
    assign alu_result_o = a_result;
    assign mem_data_o = a_mem_data;
    assign load_reserved = a_load_reserved;
    assign store_conditional = a_store_conditional;

`ifdef DEBUG
    always @(*) begin
        if (is_a_extension) begin
            $display("[A-Extension] Handling instruction: Opcode=%h, funct3=%h, rs1=%h, rs2=%h",
                     opcode, funct3, rs1_data_i, rs2_data_i);
            $display("[A-Extension] Memory Data In: %h", mem_data_i);
            $display("[A-Extension] ALU Result: %h", a_result);
            $display("[A-Extension] Memory Data Out: %h", a_mem_data);
            $display("[A-Extension] Load Reserved: %b, Store Conditional: %b", a_load_reserved, a_store_conditional);
        end
    end
`endif

endmodule