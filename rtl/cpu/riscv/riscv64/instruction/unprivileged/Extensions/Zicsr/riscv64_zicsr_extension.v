`include "riscv64_instruction_defs.v"

module riscv64_zicsr_extension #(
    parameter DATA_WIDTH = 64,
    parameter CSR_ADDR_WIDTH = 12
)(
    input  wire                                       clk,
    input  wire                                       rst_n,
    input  wire [DATA_WIDTH-1:0]                      pc_in_i,
    input  wire [31:0]                                instr_in_i,
    input  wire [15:0]                                ctrl_in_i,
    input  wire [2:0]                                 funct3,
    input  wire [6:0]                                 opcode,
    input  wire [CSR_ADDR_WIDTH-1:0]                  csr_addr_i,
    input  wire [DATA_WIDTH-1:0]                      rs1_data_i,
    input  wire [4:0]                                 rs1_addr_i,
    input  wire [4:0]                                 rs2_addr_i,
    input  wire [4:0]                                 rd_addr_i,
    output wire [DATA_WIDTH-1:0]                      alu_result_o,
    output wire                                       is_zicsr_extension
);

    // 判断是否为Zicsr扩展指令
    assign is_zicsr_extension = (opcode == `CSRRW_OPCODE ||
                                 opcode == `CSRRS_OPCODE ||
                                 opcode == `CSRRC_OPCODE ||
                                 opcode == `CSRRWI_OPCODE ||
                                 opcode == `CSRRSI_OPCODE ||
                                 opcode == `CSRRCI_OPCODE) &&
                                ((funct3 == `CSRRW_FUNCT3) ||
                                 (funct3 == `CSRRS_FUNCT3) ||
                                 (funct3 == `CSRRC_FUNCT3) ||
                                 (funct3 == `CSRRWI_FUNCT3) ||
                                 (funct3 == `CSRRSI_FUNCT3) ||
                                 (funct3 == `CSRRCI_FUNCT3));

    // CSR指令处理
    // 注意：实际实现中需要连接到CSR寄存器文件
    // 此处仅提供基本框架，具体实现需根据处理器架构调整
    reg [DATA_WIDTH-1:0] csr_read_data;
    reg [DATA_WIDTH-1:0] csr_write_data;
    reg                  csr_write_enable;

    // 模拟CSR读取（实际实现中需要连接到CSR寄存器文件）
    always @(csr_addr_i) begin
        // 默认返回0，实际实现中需要根据csr_addr_i读取对应的CSR寄存器
        csr_read_data = 64'b0;
    end

    // 确定CSR写入数据
    always @(*) begin
        csr_write_enable = 1'b0;
        csr_write_data = 64'b0;

        case (funct3)
            `CSRRW_FUNCT3: begin // CSRRW指令
                csr_write_enable = (rd_addr_i != 5'b0);
                csr_write_data = rs1_data_i;
            end
            `CSRRS_FUNCT3: begin // CSRRS指令
                csr_write_enable = (rs1_data_i != 64'b0) && (rd_addr_i != 5'b0);
                csr_write_data = csr_read_data | rs1_data_i;
            end
            `CSRRC_FUNCT3: begin // CSRRC指令
                csr_write_enable = (rs1_data_i != 64'b0) && (rd_addr_i != 5'b0);
                csr_write_data = csr_read_data & (~rs1_data_i);
            end
            `CSRRWI_FUNCT3: begin // CSRRWI指令
                csr_write_enable = (rd_addr_i != 5'b0);
                csr_write_data = {59'b0, rs1_addr_i};
            end
            `CSRRSI_FUNCT3: begin // CSRRSI指令
                csr_write_enable = (rs1_addr_i != 5'b0) && (rd_addr_i != 5'b0);
                csr_write_data = csr_read_data | {59'b0, rs1_addr_i};
            end
            `CSRRCI_FUNCT3: begin // CSRRCI指令
                csr_write_enable = (rs1_addr_i != 5'b0) && (rd_addr_i != 5'b0);
                csr_write_data = csr_read_data & (~{59'b0, rs1_addr_i});
            end
            default: begin
                csr_write_enable = 1'b0;
                csr_write_data = 64'b0;
            end
        endcase
    end

    // 输出ALU结果（CSR的原始值）
    assign alu_result_o = csr_read_data;

    // DEBUG信息输出
    `ifdef DEBUG
        always @(posedge clk) begin
            if (is_zicsr_extension) begin
                $display("[Zicsr-Extension] Handling CSR instruction: opcode=%b funct3=%b csr_addr=%h", opcode, funct3, csr_addr_i);
                if (csr_write_enable) begin
                    $display("[Zicsr-Extension] CSR Write: addr=%h data=%h", csr_addr_i, csr_write_data);
                end
                if (rd_addr_i != 5'b0) begin
                    $display("[Zicsr-Extension] CSR Read: addr=%h data=%h", csr_addr_i, csr_read_data);
                end
            end
        end
    `endif

endmodule