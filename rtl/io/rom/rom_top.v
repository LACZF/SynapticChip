

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

    /********** Xilinx FPGA Block RAM : 单端口ROM **********/
    x_s3e_sprom u_x_s3e_sprom (
        .clka  (clk),                       // 时钟
        .addra (addr_i),                    // 地址
        .douta (rd_data_o)                  // 读取的数据
    );

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
