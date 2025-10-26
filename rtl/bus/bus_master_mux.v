
`include "stddef.v"
`include "global_config.v"

`include "bus.v"

module bus_master_mux #(
    parameter MASTER_NUM = `BUS_MASTER_CH  // 总线主控数量
) (
    input  wire                                   clk,
    input  wire                                   reset,

    /********** 总线主控信号 **********/
    input  wire [MASTER_NUM-1:0][`WordAddrBus]    m_addr_i,    // 地址数组
    input  wire [MASTER_NUM-1:0]                  m_as_n_i,    // 地址选通数组
    input  wire [MASTER_NUM-1:0]                  m_rw_i,      // 读/写数组
    input  wire [MASTER_NUM-1:0][`WordDataBus]    m_wr_data_i, // 写入的数据数组
    input  wire [MASTER_NUM-1:0]                  m_grnt_n_i,  // 赋予总线数组

    /********** 共享信号总线从属 **********/
    output reg  [`WordAddrBus]                    s_addr_o,        // 地址
    output reg                                    s_as_n_o,        // 地址选通
    output reg                                    s_rw_o,          // 读/写
    output reg  [`WordDataBus]                    s_wr_data_o      // 写入的数据
);

    integer i;
    integer found;

    /********** 总线主控多路复用器 **********/
    always @(*) begin
        /* 默认值设置 */
        s_addr_o    = `WORD_ADDR_W'h0;
        s_as_n_o    = `DISABLE_N;
        s_rw_o      = `READ;
        s_wr_data_o = `WORD_DATA_W'h0;
        found       = `DISABLE;

        /* 选择持有总线使用权的主控 */
        for (i = 0; i < MASTER_NUM; i = i + 1) begin
            if (m_grnt_n_i[i] == `ENABLE_N && !found) begin
                s_addr_o      = m_addr_i[i];
                s_as_n_o      = m_as_n_i[i];
                s_rw_o        = m_rw_i[i];
                s_wr_data_o   = m_wr_data_i[i];
                found         = `ENABLE;
            end
        end
    end

endmodule