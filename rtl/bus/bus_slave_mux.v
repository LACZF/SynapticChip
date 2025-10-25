

`include "stddef.v"
`include "global_config.v"

`include "bus.v"

module bus_slave_mux (
    /********** 芯片选择 **********/
    input  wire                   s0_cs_n_i,       // 0号总线从属
    input  wire                   s1_cs_n_i,       // 1号总线从属
    input  wire                   s2_cs_n_i,       // 2号总线从属
    input  wire                   s3_cs_n_i,       // 3号总线从属
    input  wire                   s4_cs_n_i,       // 4号总线从属
    input  wire                   s5_cs_n_i,       // 5号总线从属
    input  wire                   s6_cs_n_i,       // 6号总线从属
    input  wire                   s7_cs_n_i,       // 7号总线从属
    /********** 总线从属信号 **********/
    // 0号总线从属
    input  wire [`WordDataBus]    s0_rd_data_i,    // 读出的数据
    input  wire                   s0_rdy_n_i,      // 就绪
    // 1号总线从属
    input  wire [`WordDataBus]    s1_rd_data_i,    // 读出的数据
    input  wire                   s1_rdy_n_i,      // 就绪
    // 2号总线从属
    input  wire [`WordDataBus]    s2_rd_data_i,    // 读出的数据
    input  wire                   s2_rdy_n_i,      // 就绪
    // 3号总线从属
    input  wire [`WordDataBus]    s3_rd_data_i,    // 读出的数据
    input  wire                   s3_rdy_n_i,      // 就绪
    // 4号总线从属
    input  wire [`WordDataBus]    s4_rd_data_i,    // 读出的数据
    input  wire                   s4_rdy_n_i,      // 就绪
    // 5号总线从属
    input  wire [`WordDataBus]    s5_rd_data_i,    // 读出的数据
    input  wire                   s5_rdy_n_i,      // 就绪
    // 6号总线从属
    input  wire [`WordDataBus]    s6_rd_data_i,    // 读出的数据
    input  wire                   s6_rdy_n_i,      // 就绪
    // 7号总线从属
    input  wire [`WordDataBus]    s7_rd_data_i,    // 读出的数据
    input  wire                   s7_rdy_n_i,      // 就绪
    /********** 总线主控共享信号 **********/
    output reg    [`WordDataBus]  m_rd_data_o,     // 读出的数据
    output reg                    m_rdy_n_o        // 就绪
);

    /********** 总线从属用多路复用器 **********/
    always @(*) begin
        /* 选择片选信号对应的从属 */
        if (s0_cs_n_i == `ENABLE_N) begin       // 0号总线从属
            m_rd_data_o    = s0_rd_data_i;
            m_rdy_n_o      = s0_rdy_n_i;
        end else if (s1_cs_n_i == `ENABLE_N) begin // 1号总线从属
            m_rd_data_o    = s1_rd_data_i;
            m_rdy_n_o      = s1_rdy_n_i;
        end else if (s2_cs_n_i == `ENABLE_N) begin // 2号总线从属
            m_rd_data_o    = s2_rd_data_i;
            m_rdy_n_o      = s2_rdy_n_i;
        end else if (s3_cs_n_i == `ENABLE_N) begin // 3号总线从属
            m_rd_data_o    = s3_rd_data_i;
            m_rdy_n_o      = s3_rdy_n_i;
        end else if (s4_cs_n_i == `ENABLE_N) begin // 4号总线从属
            m_rd_data_o    = s4_rd_data_i;
            m_rdy_n_o      = s4_rdy_n_i;
        end else if (s5_cs_n_i == `ENABLE_N) begin // 5号总线从属
            m_rd_data_o    = s5_rd_data_i;
            m_rdy_n_o      = s5_rdy_n_i;
        end else if (s6_cs_n_i == `ENABLE_N) begin // 6号总线从属
            m_rd_data_o    = s6_rd_data_i;
            m_rdy_n_o      = s6_rdy_n_i;
        end else if (s7_cs_n_i == `ENABLE_N) begin // 7号总线从属
            m_rd_data_o    = s7_rd_data_i;
            m_rdy_n_o      = s7_rdy_n_i;
        end else begin               // 默认值
            m_rd_data_o    = `WORD_DATA_W'h0;
            m_rdy_n_o      = `DISABLE_N;
        end
    end

endmodule