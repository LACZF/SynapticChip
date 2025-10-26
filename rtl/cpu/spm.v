
`include "global_config.v"
`include "stddef.v"

`include "spm.v"

module spm (
    input  wire                clk,
    input  wire                reset,

    /********** A端口 : IF阶段 **********/
    input  wire [`SpmAddrBus]  if_spm_addr_i,
    input  wire                if_spm_as_n_i,
    input  wire                if_spm_rw_i,
    input  wire [`WordDataBus] if_spm_wr_data_i,
    output wire [`WordDataBus] if_spm_rd_data_o,
    /********** B端口 : MEM阶段 **********/
    input  wire [`SpmAddrBus]  mem_spm_addr_i,
    input  wire                mem_spm_as_n_i,
    input  wire                mem_spm_rw_i,
    input  wire [`WordDataBus] mem_spm_wr_data_i,
    output wire [`WordDataBus] mem_spm_rd_data_o
);

    /********** 写入有效 **********/
    reg                           wea;            // A端口
    reg                           web;            // B端口

    /********** 写入有效信号的生成 **********/
    always @(*) begin
        /* A端口 */
        if ((if_spm_as_n_i == `ENABLE_N) && (if_spm_rw_i == `WRITE)) begin
            wea = `MEM_ENABLE;    // 写入有效
        end else begin
            wea = `MEM_DISABLE;   // 写入无效
        end
        /* B端口 */
        if ((mem_spm_as_n_i == `ENABLE_N) && (mem_spm_rw_i == `WRITE)) begin
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
        .addrb (mem_spm_addr_i),    // 地址
        .dinb  (mem_spm_wr_data_i), // 写入的数据
        .web   (web),               // 写入有效
        .doutb (mem_spm_rd_data_o)  // 读取的数据
    );

endmodule