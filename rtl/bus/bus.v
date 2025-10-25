
`include "stddef.v"
`include "global_config.v"

`include "bus.v"

module bus (
    input  wire                   clk,
    input  wire                   reset,
    /********** 总线主控信号 **********/
    // 总线主控共享信号
    output wire [`WordDataBus]    m_rd_data_o,    // 读出的数据
    output wire                   m_rdy_n_o,      // 就绪
    // 0号总线主控
    input  wire                   m0_req_n_i,     // 请求总线
    input  wire [`WordAddrBus]    m0_addr_i,      // 地址
    input  wire                   m0_as_n_i,      // 地址选通
    input  wire                   m0_rw_i,        // 读/写
    input  wire [`WordDataBus]    m0_wr_data_i,   // 写入的数据
    output wire                   m0_grnt_n_o,    // 赋予总线
    // 1号总线主控
    input  wire                   m1_req_n_i,     // 请求总线
    input  wire [`WordAddrBus]    m1_addr_i,      // 地址
    input  wire                   m1_as_n_i,      // 地址选通
    input  wire                   m1_rw_i,        // 读/写
    input  wire [`WordDataBus]    m1_wr_data_i,   // 写入的数据
    output wire                   m1_grnt_n_o,    // 赋予总线
    // 2号总线主控
    input  wire                   m2_req_n_i,     // 请求总线
    input  wire [`WordAddrBus]    m2_addr_i,      // 地址
    input  wire                   m2_as_n_i,      // 地址选通
    input  wire                   m2_rw_i,        // 读/写
    input  wire [`WordDataBus]    m2_wr_data_i,   // 写入的数据
    output wire                   m2_grnt_n_o,    // 赋予总线
    // 3号总线主控
    input  wire                   m3_req_n_i,     // 请求总线
    input  wire [`WordAddrBus]    m3_addr_i,      // 地址
    input  wire                   m3_as_n_i,      // 地址选通
    input  wire                   m3_rw_i,        // 读/写
    input  wire [`WordDataBus]    m3_wr_data_i,   // 写入的数据
    output wire                   m3_grnt_n_o,    // 赋予总线
    /********** 总线从属信号 **********/
    // 总线从属共享信号
    output wire [`WordAddrBus]    s_addr_o,       // 地址
    output wire                   s_as_n_o,       // 地址选通
    output wire                   s_rw_o,         // 读/写
    output wire [`WordDataBus]    s_wr_data_o,    // 写入的数据
    // 0号总线从属
    input  wire [`WordDataBus]    s0_rd_data_i,   // 读出的数据
    input  wire                   s0_rdy_n_i,     // 就绪
    output wire                   s0_cs_n_o,      // 片选
    // 1号总线从属
    input  wire [`WordDataBus]    s1_rd_data_i,   // 读出的数据
    input  wire                   s1_rdy_n_i,     // 就绪
    output wire                   s1_cs_n_o,      // 片选
    // 2号总线从属
    input  wire [`WordDataBus]    s2_rd_data_i,   // 读出的数据
    input  wire                   s2_rdy_n_i,     // 就绪
    output wire                   s2_cs_n_o,      // 片选
    // 3号总线从属
    input  wire [`WordDataBus]    s3_rd_data_i,   // 读出的数据
    input  wire                   s3_rdy_n_i,     // 就绪
    output wire                   s3_cs_n_o,      // 片选
    // 4号总线从属
    input  wire [`WordDataBus]    s4_rd_data_i,   // 读出的数据
    input  wire                   s4_rdy_n_i,     // 就绪
    output wire                   s4_cs_n_o,      // 片选
    // 5号总线从属
    input  wire [`WordDataBus]    s5_rd_data_i,   // 读出的数据
    input  wire                   s5_rdy_n_i,     // 就绪
    output wire                   s5_cs_n_o,      // 片选
    // 6号总线从属
    input  wire [`WordDataBus]    s6_rd_data_i,   // 读出的数据
    input  wire                   s6_rdy_n_i,     // 就绪
    output wire                   s6_cs_n_o,      // 片选
    // 7号总线从属
    input  wire [`WordDataBus]    s7_rd_data_i,   // 读出的数据
    input  wire                   s7_rdy_n_i,     // 就绪
    output wire                   s7_cs_n_o       // 片选
);

    /********** 总线仲裁器 **********/
    bus_arbiter u_bus_arbiter (
        /********** 时钟 & 复位 **********/
        .clk            (clk),          // 时钟
        .reset          (reset),        // 异步复位
        /********** 仲裁信号 **********/
        // 0号总线主控
        .m0_req_n_i     (m0_req_n_i),   // 请求总线
        .m0_grnt_n_o    (m0_grnt_n_o),  // 赋予总线
        // 1号总线主控
        .m1_req_n_i     (m1_req_n_i),   // 请求总线
        .m1_grnt_n_o    (m1_grnt_n_o),  // 赋予总线
        // 2号总线主控
        .m2_req_n_i     (m2_req_n_i),   // 请求总线
        .m2_grnt_n_o    (m2_grnt_n_o),  // 赋予总线
        // 3号总线主控
        .m3_req_n_i     (m3_req_n_i),   // 请求总线
        .m3_grnt_n_o    (m3_grnt_n_o)   // 赋予总线
    );

    /********** 总线主控用多路复用器 **********/
    bus_master_mux u_bus_master_mux (
        /********** 总线主控信号 **********/
        // 0号总线主控
        .m0_addr_i    (m0_addr_i),      // 地址
        .m0_as_n_i    (m0_as_n_i),      // 地址选通
        .m0_rw_i      (m0_rw_i),        // 读/写
        .m0_wr_data_i (m0_wr_data_i),   // 写入的数据
        .m0_grnt_n_i  (m0_grnt_n_o),    // 赋予总线
        // 1号总线主控
        .m1_addr_i    (m1_addr_i),      // 地址
        .m1_as_n_i    (m1_as_n_i),      // 地址选通
        .m1_rw_i      (m1_rw_i),        // 读/写
        .m1_wr_data_i (m1_wr_data_i),   // 写入的数据
        .m1_grnt_n_i  (m1_grnt_n_o),    // 赋予总线
        // 2号总线主控
        .m2_addr_i    (m2_addr_i),      // 地址
        .m2_as_n_i    (m2_as_n_i),      // 地址选通
        .m2_rw_i      (m2_rw_i),        // 读/写
        .m2_wr_data_i (m2_wr_data_i),   // 写入的数据
        .m2_grnt_n_i  (m2_grnt_n_o),    // 赋予总线
        // 3号总线主控
        .m3_addr_i    (m3_addr_i),      // 地址
        .m3_as_n_i    (m3_as_n_i),      // 地址选通
        .m3_rw_i      (m3_rw_i),        // 读/写
        .m3_wr_data_i (m3_wr_data_i),   // 写入的数据
        .m3_grnt_n_i  (m3_grnt_n_o),    // 赋予总线
        /********** 总线从属共享信号 **********/
        .s_addr_o    (s_addr_o),        // 地址
        .s_as_n_o    (s_as_n_o),        // 地址选通
        .s_rw_o      (s_rw_o),          // 读/写
        .s_wr_data_o (s_wr_data_o)      // 写入的数据
    );

    /********** 地址解码器 **********/
    bus_addr_dec u_bus_addr_dec (
        /********** 地址 **********/
        .s_addr_i     (s_addr_o),     // 地址
        /********** 片选 **********/
        .s0_cs_n_o    (s0_cs_n_o),    // 0号总线从属
        .s1_cs_n_o    (s1_cs_n_o),    // 1号总线从属
        .s2_cs_n_o    (s2_cs_n_o),    // 2号总线从属
        .s3_cs_n_o    (s3_cs_n_o),    // 3号总线从属
        .s4_cs_n_o    (s4_cs_n_o),    // 4号总线从属
        .s5_cs_n_o    (s5_cs_n_o),    // 5号总线从属
        .s6_cs_n_o    (s6_cs_n_o),    // 6号总线从属
        .s7_cs_n_o    (s7_cs_n_o)     // 7号总线从属
    );

    /********** 总线从属用多路复用器 **********/
    bus_slave_mux u_bus_slave_mux (
        /********** 片选 **********/
        .s0_cs_n_i    (s0_cs_n_o),      // 0号总线从属
        .s1_cs_n_i    (s1_cs_n_o),      // 1号总线从属
        .s2_cs_n_i    (s2_cs_n_o),      // 2号总线从属
        .s3_cs_n_i    (s3_cs_n_o),      // 3号总线从属
        .s4_cs_n_i    (s4_cs_n_o),      // 4号总线从属
        .s5_cs_n_i    (s5_cs_n_o),      // 5号总线从属
        .s6_cs_n_i    (s6_cs_n_o),      // 6号总线从属
        .s7_cs_n_i    (s7_cs_n_o),      // 7号总线从属
        /********** 总线从属信号 **********/
        // 0号总线从属
        .s0_rd_data_i  (s0_rd_data_i),    // 读出的数据
        .s0_rdy_n_i    (s0_rdy_n_i),      // 就绪
        // 1号总线从属
        .s1_rd_data_i  (s1_rd_data_i),    // 读出的数据
        .s1_rdy_n_i    (s1_rdy_n_i),      // 就绪
        // 2号总线从属
        .s2_rd_data_i  (s2_rd_data_i),    // 读出的数据
        .s2_rdy_n_i    (s2_rdy_n_i),      // 就绪
        // 3号总线从属
        .s3_rd_data_i  (s3_rd_data_i),    // 读出的数据
        .s3_rdy_n_i    (s3_rdy_n_i),      // 就绪
        // 4号总线从属
        .s4_rd_data_i  (s4_rd_data_i),    // 读出的数据
        .s4_rdy_n_i    (s4_rdy_n_i),      // 就绪
        // 5号总线从属
        .s5_rd_data_i  (s5_rd_data_i),    // 读出的数据
        .s5_rdy_n_i    (s5_rdy_n_i),      // 就绪
        // 6号总线从属
        .s6_rd_data_i  (s6_rd_data_i),    // 读出的数据
        .s6_rdy_n_i    (s6_rdy_n_i),      // 就绪
        // 7号总线从属
        .s7_rd_data_i  (s7_rd_data_i),    // 读出的数据
        .s7_rdy_n_i    (s7_rdy_n_i),      // 就绪
        /********** 总线主控共享信号 **********/
        .m_rd_data_o   (m_rd_data_o),     // 读出的数据
        .m_rdy_n_o     (m_rdy_n_o)        // 就绪
    );

endmodule