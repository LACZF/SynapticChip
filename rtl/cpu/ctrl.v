
`include "global_config.v"
`include "stddef.v"

`include "isa.v"
`include "cpu.v"
`include "rom.v"
`include "spm.v"

module ctrl (
    input  wire                       clk,
    input  wire                       reset,

    /********** 控制寄存器接口 **********/
    input  wire [`RegAddrBus]         creg_rd_addr_i,   // 读取地址
    output reg    [`WordDataBus]      creg_rd_data_o,   // 读取数据
    output reg    [`CpuExeModeBus]    exe_mode_o,       // 执行模式
    /********** 中断 **********/
    input  wire [`CPU_IRQ_CH-1:0]     irq_i,            // 中断请求
    output reg                        int_detect_o,     // 中断检测
    /********** ID/EX流水线寄存器 **********/
    input  wire [`WordAddrBus]        id_pc_i,          // ID阶段的程序计数器
    /********** MEM/WB流水线寄存器 **********/
    input  wire [`WordAddrBus]        mem_pc_i,         // MEM阶段的程序计数器
    input  wire                       mem_en_i,         // 流水线数据是否有效
    input  wire                       mem_br_flag_i,    // 分支标志位
    input  wire [`CtrlOpBus]          mem_ctrl_op_i,    // 控制寄存器操作
    input  wire [`RegAddrBus]         mem_dst_addr_i,   // 通用寄存器写入地址
    input  wire [`IsaExpBus]          mem_exp_code_i,   // 异常代码
    input  wire [`WordDataBus]        mem_out_i,        // 处理结果
    /********** 流水线控制信号 **********/
    // 流水线的状态
    input  wire                       if_busy_i,        // IF阶段忙信号
    input  wire                       ld_hazard_i,      // Load冒险
    input  wire                       mem_busy_i,       // MEM阶段忙信号
    // 延迟信号
    output wire                       if_stall_o,       // IF阶段延迟
    output wire                       id_stall_o,       // ID阶段延迟
    output wire                       ex_stall_o,       // EX阶段延迟
    output wire                       mem_stall_o,      // MEM阶段延迟
    // 刷新信号
    output wire                       if_flush_o,       // IF阶段刷新
    output wire                       id_flush_o,       // ID阶段刷新
    output wire                       ex_flush_o,       // EX阶段刷新
    output wire                       mem_flush_o,      // MEM阶段刷新
    output reg  [`WordAddrBus]        new_pc_o          // 新程序计数器
);

    /********** 控制寄存器 **********/
    reg                               int_en;           // 0号控制寄存器 : 中断有效
    reg     [`CpuExeModeBus]          pre_exe_mode;     // 1号控制寄存器 : 执行模式
    reg                               pre_int_en;       // 1号控制寄存器 : 中断有效
    reg     [`WordAddrBus]            epc;              // 3号控制寄存器 : 异常程序计数器
    reg     [`WordAddrBus]            exp_vector;       // 4号控制寄存器 : 异常向量
    reg     [`IsaExpBus]              exp_code;         // 5号控制寄存器 : 异常代码
    reg                               dly_flag;         // 6号控制寄存器 : 延迟间隙标志位
    reg     [`CPU_IRQ_CH-1:0]         mask;             // 7号控制寄存器 : 中断屏蔽

    /********** 内部信号 **********/
    reg [`WordAddrBus]                pre_pc;           // 前一个程序寄存器
    reg                               br_flag;          // 分支标志位

    /********** 流水线控制信号 **********/
    // 延迟信号
    wire   stall         = if_busy_i | mem_busy_i;
    assign if_stall_o    = stall | ld_hazard_i;
    assign id_stall_o    = stall;
    assign ex_stall_o    = stall;
    assign mem_stall_o   = stall;
    // 刷新信号
    reg    flush;
    assign if_flush_o    = flush;
    assign id_flush_o    = flush | ld_hazard_i;
    assign ex_flush_o    = flush;
    assign mem_flush_o   = flush;

    /********** 流水线刷新控制 **********/
    always @(*) begin
        /* 默认值 */
        new_pc_o = `WORD_ADDR_W'h0;
        flush  = `DISABLE;
        /* 流水线刷新 */
        if (mem_en_i == `ENABLE) begin // 流水线数据有效
            if (mem_exp_code_i != `ISA_EXP_NO_EXP) begin       // 发生异常
                new_pc_o = exp_vector;
                flush    = `ENABLE;
            end else if (mem_ctrl_op_i == `CTRL_OP_EXRT) begin // EXRT指令
                new_pc_o = epc;
                flush    = `ENABLE;
            end else if (mem_ctrl_op_i == `CTRL_OP_WRCR) begin // WRCR指令
                new_pc_o = mem_pc_i;
                flush    = `ENABLE;
            end
        end
    end

    /********** 中断检测 **********/
    always @(*) begin
        if ((int_en == `ENABLE) && ((|((~mask) & irq_i)) == `ENABLE)) begin
            int_detect_o = `ENABLE;
        end else begin
            int_detect_o = `DISABLE;
        end
    end

    /********** 读取访问 **********/
    always @(*) begin
        case (creg_rd_addr_i)
           `CREG_ADDR_STATUS     : begin // 0号 :状态
               creg_rd_data_o = {{`WORD_DATA_W-2{1'b0}}, int_en, exe_mode_o};
           end
           `CREG_ADDR_PRE_STATUS : begin // 1号 :异常发生前的状态
               creg_rd_data_o = {{`WORD_DATA_W-2{1'b0}},
                   pre_int_en, pre_exe_mode};
           end
           `CREG_ADDR_PC         : begin // 2号 :程序计数器
               creg_rd_data_o = {id_pc_i, `BYTE_OFFSET_W'h0};
           end
           `CREG_ADDR_EPC         : begin // 3号 :异常程序计数器
               creg_rd_data_o = {epc, `BYTE_OFFSET_W'h0};
           end
           `CREG_ADDR_EXP_VECTOR : begin // 4号:异常向量
               creg_rd_data_o = {exp_vector, `BYTE_OFFSET_W'h0};
           end
           `CREG_ADDR_CAUSE         : begin // 5号 :异常原因
               creg_rd_data_o = {{`WORD_DATA_W-1-`ISA_EXP_W{1'b0}},
                   dly_flag, exp_code};
           end
           `CREG_ADDR_INT_MASK     : begin // 6号 :中断屏蔽
               creg_rd_data_o = {{`WORD_DATA_W-`CPU_IRQ_CH{1'b0}}, mask};
           end
           `CREG_ADDR_IRQ         : begin // 6号:中断原因
               creg_rd_data_o = {{`WORD_DATA_W-`CPU_IRQ_CH{1'b0}}, irq_i};
           end
           `CREG_ADDR_ROM_SIZE     : begin // 7号:ROM容量
               creg_rd_data_o = $unsigned(`ROM_SIZE);
           end
           `CREG_ADDR_SPM_SIZE     : begin // 8号:SPM容量
               creg_rd_data_o = $unsigned(`SPM_SIZE);
           end
           `CREG_ADDR_CPU_INFO     : begin // 9号:CPU信息
               creg_rd_data_o = {`RELEASE_YEAR, `RELEASE_MONTH,
                   `RELEASE_VERSION, `RELEASE_REVISION};
           end
           default             : begin // 默认值
               creg_rd_data_o = `WORD_DATA_W'h0;
           end
        endcase
    end

    /********** CPU的控制 **********/
    always @(posedge clk or `RESET_EDGE reset) begin
        if (reset == `RESET_ENABLE) begin
            /* 异步复位 */
            exe_mode_o     <= `CPU_KERNEL_MODE;
            int_en         <= `DISABLE;
            pre_exe_mode   <= `CPU_KERNEL_MODE;
            pre_int_en     <= `DISABLE;
            exp_code       <= `ISA_EXP_NO_EXP;
            mask           <= {`CPU_IRQ_CH{`ENABLE}};
            dly_flag       <= `DISABLE;
            epc            <= `WORD_ADDR_W'h0;
            exp_vector     <= `WORD_ADDR_W'h0;
            pre_pc         <= `WORD_ADDR_W'h0;
            br_flag        <= `DISABLE;
        end else begin
            /* 更新CPU的状态 */
            if ((mem_en_i == `ENABLE) && (stall == `DISABLE)) begin
                /* PC和分支标志位的保存 */
                pre_pc          <= mem_pc_i;
                br_flag         <= mem_br_flag_i;
                /* CPU状态控制 */
                if (mem_exp_code_i != `ISA_EXP_NO_EXP) begin         // 发生异常
                    exe_mode_o     <= `CPU_KERNEL_MODE;
                    int_en         <= `DISABLE;
                    pre_exe_mode   <= exe_mode_o;
                    pre_int_en     <= int_en;
                    exp_code       <= mem_exp_code_i;
                    dly_flag       <= br_flag;
                    epc            <= pre_pc;
                end else if (mem_ctrl_op_i == `CTRL_OP_EXRT) begin // EXRT命令
                    exe_mode_o     <= pre_exe_mode;
                    int_en         <= pre_int_en;
                end else if (mem_ctrl_op_i == `CTRL_OP_WRCR) begin // WRCR命令
                   /* 写入控制寄存器 */
                    case (mem_dst_addr_i)
                        `CREG_ADDR_STATUS      : begin // 状态
                            exe_mode_o     <= mem_out_i[`CregExeModeLoc];
                            int_en         <= mem_out_i[`CregIntEnableLoc];
                        end
                        `CREG_ADDR_PRE_STATUS : begin // 异常发生前的状态
                            pre_exe_mode   <= mem_out_i[`CregExeModeLoc];
                            pre_int_en     <= mem_out_i[`CregIntEnableLoc];
                        end
                        `CREG_ADDR_EPC          : begin // 异常程序计数器
                            epc             <= mem_out_i[`WordAddrLoc];
                        end
                        `CREG_ADDR_EXP_VECTOR : begin // 异常向量
                            exp_vector     <= mem_out_i[`WordAddrLoc];
                        end
                        `CREG_ADDR_CAUSE      : begin // 异常原因
                            dly_flag     <= mem_out_i[`CregDlyFlagLoc];
                            exp_code     <= mem_out_i[`CregExpCodeLoc];
                        end
                        `CREG_ADDR_INT_MASK      : begin // 中断屏蔽
                            mask         <= mem_out_i[`CPU_IRQ_CH-1:0];
                        end
                    endcase
                end
            end
        end
    end

endmodule