
`include "global_config.v"
`include "stddef.v"

`include "isa.v"
`include "cpu.v"
`include "bus.v"

module mem_ctrl (
    input  wire                   clk,
    input  wire                   reset,

    /********** EX/MEM流水线寄存器 **********/
    input  wire                   ex_en_i,            // 流水线数据是否有效
    input  wire [`WordAddrBus]    ex_pc_i,
    input  wire [`WordDataBus]    ex_insn_i,
    input  wire [`MemOpBus]       ex_mem_op_i,        // 内存操作
    input  wire [`WordDataBus]    ex_mem_wr_data_i,   // 内存写入数据
    input  wire [`WordDataBus]    ex_out_i,           // 处理结果
    /********** 内存访问接口 **********/
    input  wire [`WordDataBus]    rd_data_i,          // 读取的数据
    output wire [`WordAddrBus]    addr_o,             // 地址
    output reg                    as_n_o,             // 地址选通
    output reg                    rw_o,               // 读/写
    output wire [`WordDataBus]    wr_data_o,          // 写入的数据
    /********** 内存访问结果 **********/
    output reg [`WordDataBus]     result_o,           // 内存访问结果
    output reg                    miss_align_o        // 未对齐
);

    /********** 内部信号 **********/
    wire [`ByteOffsetBus]       offset;

    /********** 输出的赋值 **********/
    assign wr_data_o  = ex_mem_wr_data_i;         // 写入数据
    assign addr_o     = ex_out_i[`WordAddrLoc];   // 地址
    assign offset     = ex_out_i[`ByteOffsetLoc]; // 偏移

    /********** 内存访问控制 **********/
    always @(*) begin
        /* 默认值 */
        miss_align_o   = `DISABLE;
        result_o       = `WORD_DATA_W'h0;
        as_n_o         = `DISABLE_N;
        rw_o           = `READ;
        /* 内存访问 */
        if (ex_en_i == `ENABLE) begin
            case (ex_mem_op_i)
                `MEM_OP_LDW : begin // 字读取
                    /* 字节偏移的检测 */
                    if (offset == `BYTE_OFFSET_WORD) begin // 对齐
                        result_o       = rd_data_i;
                        as_n_o         = `ENABLE_N;
                    end else begin                           // 未对齐
                        miss_align_o   = `ENABLE;
                    end
                end
                `MEM_OP_STW : begin // 字写入
                    /* 字节偏移的检测 */
                    if (offset == `BYTE_OFFSET_WORD) begin // 对齐
                        rw_o           = `WRITE;
                        as_n_o         = `ENABLE_N;
                    end else begin                           // 未对齐
                        miss_align_o   = `ENABLE;
                    end
                end
                default : begin // 无内存访问
                    result_o            = ex_out_i;
                end
            endcase
        end
    end

endmodule