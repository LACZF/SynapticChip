

`include "stddef.v"
`include "global_config.v"

`include "rom.v"

module rom_top (
    input  wire                   clk,
    input  wire                   reset,

    /********** 总线接口 **********/
    input  wire                   cs_n_i,       // 片选信号
    input  wire                   as_n_i,       // 地址选通
    input  wire [`RomAddrBus]     addr_i,       // 地址
    output wire [`WordDataBus]    rd_data_o,    // 读取的数据
    output reg                    rdy_n_o       // 就绪信号
);

    /********** 内部信号 **********/
    wire [`RomAddrBus]            aligned_addr;  // 对齐后的地址
    wire [`ByteOffsetBus]         byte_offset;   // 字节偏移
    wire [`WordDataBus]           temp_rd_data;  // 临时读取数据
    reg  [`WordDataBus]           shifted_data;  // 移位后的数据

    /********** 计算对齐地址和字节偏移 **********/
    assign aligned_addr = {addr_i[`ROM_ADDR_W-1:2], 2'b00}; // 4字节对齐
    assign byte_offset  = addr_i[1:0]; // 字节偏移

    /********** Xilinx FPGA Block RAM : 单端口ROM **********/
    x_s3e_sprom u_x_s3e_sprom (
        .clka  (clk),                       // 时钟
        .addra (aligned_addr),              // 对齐后的地址
        .douta (temp_rd_data)               // 临时读取的数据
    );

    /********** 非对齐读取处理 **********/
    // 根据字节偏移进行移位处理，支持非对齐字读取
    always @(*) begin
        case (byte_offset)
            2'b00:   shifted_data = temp_rd_data;                // 对齐地址，无需移位
            2'b01:   shifted_data = {temp_rd_data[23:0], 8'b0};  // 偏移1字节
            2'b10:   shifted_data = {temp_rd_data[15:0], 16'b0}; // 偏移2字节
            2'b11:   shifted_data = {temp_rd_data[7:0], 24'b0};  // 偏移3字节
            default: shifted_data = temp_rd_data;
        endcase
    end

    // 输出处理后的数据
    assign rd_data_o = shifted_data;

    /********** 生成就绪信号 **********/
    always @(posedge clk or `RESET_EDGE reset) begin
        if (reset == `RESET_ENABLE) begin
            /* 异步复位 */
            rdy_n_o <= `DISABLE_N;
        end else begin
            /* 生成就绪信号 */
            if ((cs_n_i == `ENABLE_N) && (as_n_i == `ENABLE_N)) begin
                rdy_n_o <= `ENABLE_N;
            end else begin
                rdy_n_o <= `DISABLE_N;
            end
        end
    end

endmodule