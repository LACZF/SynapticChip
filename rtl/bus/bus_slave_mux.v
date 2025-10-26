

`include "stddef.v"
`include "global_config.v"

`include "bus.v"

module bus_slave_mux #(
    parameter SLAVE_NUM = `BUS_SLAVE_CH  // 总线从属数量
) (
    input  wire                                   clk,
    input  wire                                   reset,

    /********** 芯片选择 **********/
    input  wire [SLAVE_NUM-1:0]                   s_cs_n_i,        // 片选信号数组
    /********** 总线从属信号 **********/
    input  wire [SLAVE_NUM-1:0][`WordDataBus]     s_rd_data_i,     // 读出的数据数组
    input  wire [SLAVE_NUM-1:0]                   s_rdy_n_i,       // 就绪数组
    /********** 总线主控共享信号 **********/
    output reg                 [`WordDataBus]     m_rd_data_o,     // 读出的数据
    output reg                                    m_rdy_n_o        // 就绪
);

    integer i;
    reg     found;

    /********** 总线从属用多路复用器 **********/
    always @(*) begin
        /* 默认值设置 */
        m_rd_data_o    = `WORD_DATA_W'h0;
        m_rdy_n_o      = `DISABLE_N;
        found          = `DISABLE;

        /* 选择片选信号对应的从属 */
        for (i = 0; i < SLAVE_NUM; i = i + 1) begin
            if (s_cs_n_i[i] == `ENABLE_N && !found) begin
                m_rd_data_o = s_rd_data_i[i];
                m_rdy_n_o   = s_rdy_n_i[i];
                found       = `ENABLE;
            end
        end
    end

endmodule