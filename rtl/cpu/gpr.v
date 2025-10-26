
`include "global_config.v"
`include "stddef.v"

`include "cpu.v"

module gpr (
    input  wire                   clk,
    input  wire                   reset,

    /********** 读取端口 0 **********/
    input  wire [`RegAddrBus]     rd_addr0_i,           // 读取的地址
    output wire [`WordDataBus]    rd_data0_o,           // 读取的数据
    /********** 读取端口 1 **********/
    input  wire [`RegAddrBus]     rd_addr1_i,           // 读取的地址
    output wire [`WordDataBus]    rd_data1_o,           // 读取的数据
    /********** 写入端口 **********/
    input  wire                   we_n_i,               // 写入有效信号
    input  wire [`RegAddrBus]     wr_addr_i,            // 写入的地址
    input  wire [`WordDataBus]    wr_data_i,            // 写入的数据

    output wire                   gpr0,
    output wire                   gpr1,
    output wire                   gpr2,
    output wire                   gpr3,
    output wire                   gpr4,
    output wire                   gpr5,
    output wire                   gpr6,
    output wire                   gpr7,
    output wire                   gpr8,
    output wire                   gpr9,
    output wire                   gpr10,
    output wire                   gpr11,
    output wire                   gpr12,
    output wire                   gpr13,
    output wire                   gpr14,
    output wire                   gpr15,
    output wire                   gpr16,
    output wire                   gpr17,
    output wire                   gpr18,
    output wire                   gpr19,
    output wire                   gpr20,
    output wire                   gpr21,
    output wire                   gpr22,
    output wire                   gpr23,
    output wire                   gpr24,
    output wire                   gpr25,
    output wire                   gpr26,
    output wire                   gpr27,
    output wire                   gpr28,
    output wire                   gpr29,
    output wire                   gpr30,
    output wire                   gpr31
);

    /********** 内部信号 **********/
    reg [`WordDataBus]           gpr [`REG_NUM-1:0];    // 寄存器序列
    integer                      i;                     // 初始化用迭代器

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


    assign gpr0 = gpr[0];
    assign gpr0 = gpr[1];
    assign gpr0 = gpr[2];
    assign gpr0 = gpr[3];
    assign gpr0 = gpr[4];
    assign gpr0 = gpr[5];
    assign gpr0 = gpr[6];
    assign gpr0 = gpr[7];
    assign gpr0 = gpr[8];
    assign gpr0 = gpr[9];
    assign gpr0 = gpr[10];
    assign gpr0 = gpr[11];
    assign gpr0 = gpr[12];
    assign gpr0 = gpr[13];
    assign gpr0 = gpr[14];
    assign gpr0 = gpr[15];
    assign gpr0 = gpr[16];
    assign gpr0 = gpr[17];
    assign gpr0 = gpr[18];
    assign gpr0 = gpr[19];
    assign gpr0 = gpr[20];
    assign gpr0 = gpr[21];
    assign gpr0 = gpr[22];
    assign gpr0 = gpr[23];
    assign gpr0 = gpr[24];
    assign gpr0 = gpr[25];
    assign gpr0 = gpr[26];
    assign gpr0 = gpr[27];
    assign gpr0 = gpr[28];
    assign gpr0 = gpr[29];
    assign gpr0 = gpr[30];
    assign gpr0 = gpr[31];

endmodule