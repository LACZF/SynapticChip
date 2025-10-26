
`include "global_config.v"
`include "stddef.v"

`include "cpu.v"

module gpr (
    input  wire                   clk,
    input  wire                   reset,

    input  wire [`WordAddrBus]    mem_pc_i,
    input  wire [`WordDataBus]    mem_insn_i,
    input  wire                   mem_en_i,

    /********** 读取端口 0 **********/
    input  wire [`RegAddrBus]     rd_addr0_i,           // 读取的地址
    output wire [`WordDataBus]    rd_data0_o,           // 读取的数据
    /********** 读取端口 1 **********/
    input  wire [`RegAddrBus]     rd_addr1_i,           // 读取的地址
    output wire [`WordDataBus]    rd_data1_o,           // 读取的数据
    /********** 写入端口 **********/
    input  wire                   we_n_i,               // 写入有效信号
    input  wire [`RegAddrBus]     wr_addr_i,            // 写入的地址
    input  wire [`WordDataBus]    wr_data_i             // 写入的数据

`ifdef DEBUG
    , output wire [`WordDataBus]  gpr0
    , output wire [`WordDataBus]  gpr1
    , output wire [`WordDataBus]  gpr2
    , output wire [`WordDataBus]  gpr3
    , output wire [`WordDataBus]  gpr4
    , output wire [`WordDataBus]  gpr5
    , output wire [`WordDataBus]  gpr6
    , output wire [`WordDataBus]  gpr7
    , output wire [`WordDataBus]  gpr8
    , output wire [`WordDataBus]  gpr9
    , output wire [`WordDataBus]  gpr10
    , output wire [`WordDataBus]  gpr11
    , output wire [`WordDataBus]  gpr12
    , output wire [`WordDataBus]  gpr13
    , output wire [`WordDataBus]  gpr14
    , output wire [`WordDataBus]  gpr15
    , output wire [`WordDataBus]  gpr16
    , output wire [`WordDataBus]  gpr17
    , output wire [`WordDataBus]  gpr18
    , output wire [`WordDataBus]  gpr19
    , output wire [`WordDataBus]  gpr20
    , output wire [`WordDataBus]  gpr21
    , output wire [`WordDataBus]  gpr22
    , output wire [`WordDataBus]  gpr23
    , output wire [`WordDataBus]  gpr24
    , output wire [`WordDataBus]  gpr25
    , output wire [`WordDataBus]  gpr26
    , output wire [`WordDataBus]  gpr27
    , output wire [`WordDataBus]  gpr28
    , output wire [`WordDataBus]  gpr29
    , output wire [`WordDataBus]  gpr30
    , output wire [`WordDataBus]  gpr31
`endif
);

    /********** 内部信号 **********/
    reg [`WordDataBus][`REG_NUM-1:0]           gpr;    // 寄存器序列
    integer                                    i;      // 初始化用迭代器

    /********** 读取访问 (Write After Read) **********/
    // 读取端口 0
    assign rd_data0_o = ((we_n_i == `ENABLE_N) && (wr_addr_i == rd_addr0_i)) ?
               wr_data_i : gpr[rd_addr0_i];
    // 读取端口 1
    assign rd_data1_o = ((we_n_i == `ENABLE_N) && (wr_addr_i == rd_addr1_i)) ?
               wr_data_i : gpr[rd_addr1_i];

    /********** 写入访问 **********/
    always @ (posedge clk or `RESET_EDGE reset) begin
        if (reset == `RESET_ENABLE) begin
            /* 异步复位 */
            for (i = 0; i < `REG_NUM; i = i + 1) begin
                gpr[i] <= `WORD_DATA_W'h0;
            end
        end else begin
            /* 写入访问 */
            if (we_n_i == `ENABLE_N) begin
                gpr[wr_addr_i] <= wr_data_i;
            end
        end
    end

`ifdef DEBUG
    assign gpr0  = gpr[0];
    assign gpr1  = gpr[1];
    assign gpr2  = gpr[2];
    assign gpr3  = gpr[3];
    assign gpr4  = gpr[4];
    assign gpr5  = gpr[5];
    assign gpr6  = gpr[6];
    assign gpr7  = gpr[7];
    assign gpr8  = gpr[8];
    assign gpr9  = gpr[9];
    assign gpr10 = gpr[10];
    assign gpr11 = gpr[11];
    assign gpr12 = gpr[12];
    assign gpr13 = gpr[13];
    assign gpr14 = gpr[14];
    assign gpr15 = gpr[15];
    assign gpr16 = gpr[16];
    assign gpr17 = gpr[17];
    assign gpr18 = gpr[18];
    assign gpr19 = gpr[19];
    assign gpr20 = gpr[20];
    assign gpr21 = gpr[21];
    assign gpr22 = gpr[22];
    assign gpr23 = gpr[23];
    assign gpr24 = gpr[24];
    assign gpr25 = gpr[25];
    assign gpr26 = gpr[26];
    assign gpr27 = gpr[27];
    assign gpr28 = gpr[28];
    assign gpr29 = gpr[29];
    assign gpr30 = gpr[30];
    assign gpr31 = gpr[31];
`endif

endmodule