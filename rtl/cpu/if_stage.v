
`include "global_config.v"
`include "stddef.v"

`include "cpu.v"

module if_stage (
    input  wire                   clk,
    input  wire                   reset,
    /********** SPM接口 **********/
    input  wire [`WordDataBus]    spm_rd_data_i,   // 读取的数据
    output wire [`WordAddrBus]    spm_addr_o,      // 地址
    output wire                   spm_as_n_o,      // 地址选通
    output wire                   spm_rw_o,        // 读/写
    output wire [`WordDataBus]    spm_wr_data_o,   // 写入的数据
    /********** 总线接口 **********/
    input  wire [`WordDataBus]    bus_rd_data_i,    // 读取的数据
    input  wire                   bus_rdy_n_i,      // 就绪
    input  wire                   bus_grnt_n_i,     // 许可
    output wire                   bus_req_n_o,      // 请求
    output wire [`WordAddrBus]    bus_addr_o,       // 地址
    output wire                   bus_as_n_o,       // 地址选通
    output wire                   bus_rw_o,         // 读/写
    output wire [`WordDataBus]    bus_wr_data_o,    // 写入的数据
    /********** 流水线控制信号 **********/
    input  wire                   stall_i,          // 延迟
    input  wire                   flush_i,          // 刷新
    input  wire [`WordAddrBus]    new_pc_i,         // 新程序计数器值
    input  wire                   br_taken_i,       // 分支成立
    input  wire [`WordAddrBus]    br_addr_i,        // 分支目标地址
    output wire                   busy_o,           // 总线忙信号
    /********** IF/ID流水线寄存器 **********/
    output wire [`WordAddrBus]    if_pc_o,          // 程序计数器
    output wire [`WordDataBus]    if_insn_o,        // 指令
    output wire                   if_en_o           // 流水线数据有效标志位
);

    /********** 内部连接信号 **********/
    wire [`WordDataBus]    insn;

    /********** 总线接口 **********/
    bus_if bus_if (
        .clk              (clk),
        .reset            (reset),
        /********** 流水线控制信号 **********/
        .stall_i          (stall_i),              // 延迟信号
        .flush_i          (flush_i),              // 刷新信号
        .busy_o           (busy_o),               // 总线忙信号
        /********** CPU接口 **********/
        .addr_i           (if_pc_o),              // 地址
        .as_n_i           (`ENABLE_N),            // 地址有效
        .rw_i             (`READ),                // 读/写
        .wr_data_i        (`WORD_DATA_W'h0),      // 写入的数据
        .rd_data_o        (insn),                 // 读取的数据
        /********** 便笺式存储器接口 **********/
        .spm_rd_data_i    (spm_rd_data_i),        // 读取的数据
        .spm_addr_o       (spm_addr_o),           // 地址
        .spm_as_n_o       (spm_as_n_o),           // 地址选通
        .spm_rw_o         (spm_rw_o),             // 读/写
        .spm_wr_data_o    (spm_wr_data_o),        // 写入的数据
        /********** 总线接口 **********/
        .bus_rd_data_i    (bus_rd_data_i),        // 读出的数据
        .bus_rdy_n_i      (bus_rdy_n_i),          // 就绪
        .bus_grnt_n_i     (bus_grnt_n_i),         // 许可
        .bus_req_n_o      (bus_req_n_o),          // 总线请求
        .bus_addr_o       (bus_addr_o),           // 地址
        .bus_as_n_o       (bus_as_n_o),           // 地址选通
        .bus_rw_o         (bus_rw_o),             // 读/写
        .bus_wr_data_o    (bus_wr_data_o)         // 写入的数据
    );

    /********** IF阶段流水线寄存器 **********/
    if_reg if_reg (
        .clk         (clk),
        .reset       (reset),
        /********** 获取数据 **********/
        .insn_i      (insn),               // 取指令
        /********** 流水线控制信号 **********/
        .stall_i     (stall_i),            // 延迟
        .flush_i     (flush_i),            // 刷新
        .new_pc_i    (new_pc_i),           // 新程序计数器值
        .br_taken_i  (br_taken_i),         // 分支成立
        .br_addr_i   (br_addr_i),          // 分支目标地址
        /********** IF/ID流水线寄存器 **********/
        .if_pc_o     (if_pc_o),            // 程序计数器
        .if_insn_o   (if_insn_o),          // 指令
        .if_en_o     (if_en_o)             // 流水线数据有效标志位
    );

endmodule