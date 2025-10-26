
`include "stddef.v"
`include "global_config.v"

`include "bus.v"

module bus_top #(
    parameter MASTER_NUM = `BUS_MASTER_CH,
    parameter SLAVE_NUM  = `BUS_SLAVE_CH
) (
    input  wire                                      clk,
    input  wire                                      reset,

    /********** 总线主控信号 **********/
    // 总线主控共享信号
    output wire                 [`WordDataBus]       m_rd_data_o,    // 读出的数据
    output wire                                      m_rdy_n_o,      // 就绪
    // 总线主控数组信号
    input  wire [MASTER_NUM-1:0]                     m_req_n_i,      // 请求总线数组
    input  wire [MASTER_NUM-1:0][`WordAddrBus]       m_addr_i,       // 地址数组
    input  wire [MASTER_NUM-1:0]                     m_as_n_i,       // 地址选通数组
    input  wire [MASTER_NUM-1:0]                     m_rw_i,         // 读/写数组
    input  wire [MASTER_NUM-1:0][`WordDataBus]       m_wr_data_i,    // 写入的数据数组
    output wire [MASTER_NUM-1:0]                     m_grnt_n_o,     // 赋予总线数组
    /********** 总线从属信号 **********/
    // 总线从属共享信号
    output wire                [`WordAddrBus]        s_addr_o,       // 地址
    output wire                                      s_as_n_o,       // 地址选通
    output wire                                      s_rw_o,         // 读/写
    output wire                [`WordDataBus]        s_wr_data_o,    // 写入的数据
    // 总线从属数组信号
    input  wire [SLAVE_NUM-1:0][`WordDataBus]        s_rd_data_i,    // 读出的数据数组
    input  wire [SLAVE_NUM-1:0]                      s_rdy_n_i,      // 就绪数组
    output wire [SLAVE_NUM-1:0]                      s_cs_n_o        // 片选数组
);

    wire [MASTER_NUM-1:0]               m_grnt_n;

    // 总线主控信号数组 (调整维度顺序以匹配模块接口)
    wire [MASTER_NUM-1:0][`WordAddrBus] m_addr;
    wire [MASTER_NUM-1:0]               m_as_n;
    wire [MASTER_NUM-1:0]               m_rw;
    wire [MASTER_NUM-1:0][`WordDataBus] m_wr_data;

    /********** 总线仲裁器 **********/
    bus_arbiter #(
        .MASTER_NUM (MASTER_NUM)
    ) u_bus_arbiter (
        .clk           (clk),
        .reset         (reset),
        .m_req_n_i     (m_req_n_i),   // 请求总线数组
        .m_grnt_n_o    (m_grnt_n)     // 赋予总线数组
    );

    /********** 赋予总线信号分配 **********/
    assign m_grnt_n_o = m_grnt_n;

    /********** 总线主控信号数组维度调整 **********/
    generate
        genvar i;
        for (i = 0; i < MASTER_NUM; i = i + 1) begin : bus_master_assign
            assign m_addr[i]    = m_addr_i[i];
            assign m_as_n[i]    = m_as_n_i[i];
            assign m_rw[i]      = m_rw_i[i];
            assign m_wr_data[i] = m_wr_data_i[i];
        end
    endgenerate

    /********** 总线主控用多路复用器 **********/
    bus_master_mux #(
        .MASTER_NUM (MASTER_NUM)  // 设置总线主控数量
    ) u_bus_master_mux (
        .clk          (clk),
        .reset        (reset),

        /********** 总线主控信号 **********/
        .m_addr_i     (m_addr),         // 地址数组
        .m_as_n_i     (m_as_n),         // 地址选通数组
        .m_rw_i       (m_rw),           // 读/写数组
        .m_wr_data_i  (m_wr_data),      // 写入的数据数组
        .m_grnt_n_i   (m_grnt_n),       // 赋予总线数组

        /********** 总线从属共享信号 **********/
        .s_addr_o     (s_addr_o),       // 地址
        .s_as_n_o     (s_as_n_o),       // 地址选通
        .s_rw_o       (s_rw_o),         // 读/写
        .s_wr_data_o  (s_wr_data_o)     // 写入的数据
    );

    /********** 内部信号 **********/
    wire [SLAVE_NUM-1:0] slave_cs_n;  // 片选信号数组

    /********** 地址解码器 **********/
    bus_addr_dec u_bus_addr_dec (
        .clk          (clk),
        .reset        (reset),

        /********** 地址 **********/
        .s_addr_i     (s_addr_o),     // 地址
        /********** 片选 **********/
        .slave_cs_n_o (slave_cs_n)    // 片选信号数组
    );

    /********** 片选信号分配 **********/
    assign s_cs_n_o = slave_cs_n;

    /********** 总线从属信号数组直接连接 **********/
    // 由于外部接口已经是数组形式，这里不需要额外的信号分配
    // s_rd_data 和 s_rdy_n 已经通过参数传递给 bus_slave_mux 模块

    /********** 总线从属用多路复用器 **********/
    bus_slave_mux #(
        .SLAVE_NUM (SLAVE_NUM)  // 设置总线从属数量
    ) u_bus_slave_mux (
        .clk          (clk),
        .reset        (reset),

        /********** 片选 **********/
        .s_cs_n_i     (slave_cs_n),      // 片选信号数组
        /********** 总线从属信号 **********/
        .s_rd_data_i  (s_rd_data_i),     // 读出的数据数组 (直接使用外部端口)
        .s_rdy_n_i    (s_rdy_n_i),       // 就绪数组 (直接使用外部端口)
        /********** 总线主控共享信号 **********/
        .m_rd_data_o  (m_rd_data_o),     // 读出的数据
        .m_rdy_n_o    (m_rdy_n_o)        // 就绪
    );

endmodule