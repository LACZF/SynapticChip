
`include "global_config.v"
`include "stddef.v"

`include "spm.v"

module spm_top (
    input  wire                clk,
    input  wire                reset,

    /********** A端口 : IF阶段 **********/
    input  wire [`WordAddrBus] if_pc_i,
    input  wire [`WordDataBus] if_insn_i,
    input  wire                if_en_i,
    input  wire [`SpmAddrBus]  if_spm_addr_i,
    input  wire                if_spm_as_n_i,
    input  wire                if_spm_rw_i,
    input  wire [`WordDataBus] if_spm_wr_data_i,
    output wire [`WordDataBus] if_spm_rd_data_o,
    /********** B端口 : MEM阶段 **********/
    input  wire [`WordAddrBus] mem_pc_i,
    input  wire [`WordDataBus] mem_insn_i,
    input  wire                mem_en_i,
    input  wire [`SpmAddrBus]  mem_spm_addr_i,
    input  wire                mem_spm_as_n_i,
    input  wire                mem_spm_rw_i,
    input  wire [`WordDataBus] mem_spm_wr_data_i,
    output wire [`WordDataBus] mem_spm_rd_data_o
);

    /********** 内部信号 **********/
    reg                           wea;            // A端口
    reg                           web;            // B端口
    wire [`SpmAddrBus]            aligned_addr_b; // 对齐后的地址B
    wire [`ByteOffsetBus]         byte_offset_b;  // 字节偏移B
    reg  [`WordDataBus]           shifted_data_b; // 移位后的数据B
    wire [`WordDataBus]           rd_data_b; // 临时读取数据B

    /********** 计算对齐地址和字节偏移 **********/
    /* IF阶段通常只进行指令读取，不需要非对齐处理 */
    assign aligned_addr_b = {mem_spm_addr_i[`SPM_ADDR_W-1:2], 2'b00}; // 4字节对齐
    assign byte_offset_b  = mem_spm_addr_i[1:0]; // 字节偏移

    /********** 写入有效信号的生成 **********/
    always @(*) begin
        /* A端口 */
        /* TODO: 暂时未使用片选信号 */
        if ((if_spm_rw_i == `WRITE)) begin
            wea = `MEM_ENABLE;    // 写入有效
        end else begin
            wea = `MEM_DISABLE;   // 写入无效
        end
        /* B端口 */
        /* TODO: 暂时未使用片选信号 */
        if ((mem_spm_rw_i == `WRITE)) begin
            web = `MEM_ENABLE;    // 写入有效
        end else begin
            web = `MEM_DISABLE;   // 写入无效
        end
    end

    /********** Xilinx FPGA Block RAM : 双端口RAM **********/
    x_s3e_dpram u_x_s3e_dpram (
        /********** A端口 : IF阶段 **********/
        .clka  (clk),               // 时钟
        .addra (if_spm_addr_i),     // 地址
        .dina  (if_spm_wr_data_i),  // 写入的数据
        .wea   (wea),               // 写入有效
        .douta (if_spm_rd_data_o),  // 读取的数据
        /********** B端口 : MEM阶段 **********/
        .clkb  (clk),               // 时钟
        .addrb (aligned_addr_b),    // 对齐后的地址
        .dinb  (mem_spm_wr_data_i), // 写入的数据
        .web   (web),               // 写入有效
        .doutb (rd_data_b)          // 临时读取的数据
    );

    /********** 非对齐读取处理 - B端口(MEM阶段) **********/
    // 根据字节偏移进行移位处理，支持非对齐字读取
    always @(*) begin
        case (byte_offset_b)
            2'b00:   shifted_data_b = rd_data_b;                // 对齐地址，无需移位
            2'b01:   shifted_data_b = {rd_data_b[23:0], 8'b0};  // 偏移1字节
            2'b10:   shifted_data_b = {rd_data_b[15:0], 16'b0}; // 偏移2字节
            2'b11:   shifted_data_b = {rd_data_b[7:0], 24'b0};  // 偏移3字节
            default: shifted_data_b = rd_data_b;
        endcase
    end

    // 输出处理后的数据
    assign mem_spm_rd_data_o = shifted_data_b;

endmodule