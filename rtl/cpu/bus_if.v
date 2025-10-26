
`include "global_config.v"
`include "stddef.v"

`include "cpu.v"
`include "bus.v"

module bus_if (
    input  wire                   clk,
    input  wire                   reset,

    /********** 流水线控制信号 **********/
    input  wire                   stall_i,
    input  wire                   flush_i,
    output reg                    busy_o,
    /********** CPU接口 **********/
    input  wire [`WordAddrBus]    addr_i,
    input  wire                   as_n_i,
    input  wire                   rw_i,
    input  wire [`WordDataBus]    wr_data_i,
    output reg  [`WordDataBus]    rd_data_o,
    /********** SPM接口 **********/
    input  wire [`WordDataBus]    spm_rd_data_i,
    output wire [`WordAddrBus]    spm_addr_o,
    output reg                    spm_as_n_o,
    output wire                   spm_rw_o,
    output wire [`WordDataBus]    spm_wr_data_o,
    /********** 总线接口 **********/
    input  wire [`WordDataBus]    bus_rd_data_i,
    input  wire                   bus_rdy_n_i,
    input  wire                   bus_grnt_n_i,
    output reg                    bus_req_n_o,
    output reg  [`WordAddrBus]    bus_addr_o,
    output reg                    bus_as_n_o,
    output reg                    bus_rw_o,
    output reg  [`WordDataBus]    bus_wr_data_o
);

    /********** 内部信号 **********/
    reg  [`BusIfStateBus]          state;             // 总线接口状态
    reg  [`WordDataBus]            rd_buf;            // 读取缓冲
    wire [`BusSlaveIndexBus]       s_index;           // 总线从属索引

    /********** 生成总线从属索引 **********/
    assign s_index           = addr_i[`BusSlaveIndexLoc];

    /********** 输出的赋值 **********/
    assign spm_addr_o       = addr_i;
    assign spm_rw_o         = rw_i;
    assign spm_wr_data_o    = wr_data_i;

    /********** 内存访问的控制 **********/
    always @(*) begin
        /* 默认值 */
        rd_data_o      = `WORD_DATA_W'h0;
        spm_as_n_o     = `DISABLE_N;
        busy_o         = `DISABLE;
        /* 总线接口的状态 */
        case (state)
            `BUS_IF_STATE_IDLE : begin // 空闲
                /* 内存访问 */
                if ((flush_i == `DISABLE) && (as_n_i == `ENABLE_N)) begin
                    /* 选择访问的目标 */
                    if (s_index == `BUS_SLAVE_1) begin // 访问SPM
                        if (stall_i == `DISABLE) begin // 检测延迟的发生
                            spm_as_n_o = `ENABLE_N;
                            if (rw_i == `READ) begin // 读取访问
                                rd_data_o = spm_rd_data_i;
                            end
                        end
                    end else begin               // 访问总线
                        busy_o = `ENABLE;
                    end
                end
            end
            `BUS_IF_STATE_REQ : begin // 请求总线
                busy_o = `ENABLE;
            end
            `BUS_IF_STATE_ACCESS : begin // 访问总线
                /* 等待就绪信号 */
                if (bus_rdy_n_i == `ENABLE_N) begin // 就绪信号到达
                    if (rw_i == `READ) begin // 读取访问
                        rd_data_o = bus_rd_data_i;
                    end
                end else begin                // 就绪信号未到达
                    busy_o = `ENABLE;
                end
            end
            `BUS_IF_STATE_STALL : begin // 延迟
                if (rw_i == `READ) begin // 读取访问
                    rd_data_o = rd_buf;
                end
            end
        endcase
    end

   /********** 总线接口的状态控制 **********/
   always @(posedge clk or `RESET_EDGE reset) begin
        if (reset == `RESET_ENABLE) begin
            /* 异步复位 */
            state           <= `BUS_IF_STATE_IDLE;
            bus_req_n_o     <= `DISABLE_N;
            bus_addr_o      <= `WORD_ADDR_W'h0;
            bus_as_n_o      <= `DISABLE_N;
            bus_rw_o        <= `READ;
            bus_wr_data_o   <= `WORD_DATA_W'h0;
            rd_buf          <= `WORD_DATA_W'h0;
        end else begin
            /* 总线接口的状态 */
            case (state)
                `BUS_IF_STATE_IDLE : begin // 空闲
                    /* 内存访问 */
                    if ((flush_i == `DISABLE) && (as_n_i == `ENABLE_N)) begin
                        /* 选择访问目标 */
                        if (s_index != `BUS_SLAVE_1) begin // 访问总线
                            state         <= `BUS_IF_STATE_REQ;
                            bus_req_n_o   <= `ENABLE_N;
                            bus_addr_o    <= addr_i;
                            bus_rw_o      <= rw_i;
                            bus_wr_data_o <= wr_data_i;
                        end
                    end
                end
                `BUS_IF_STATE_REQ : begin // 请求总线
                    /* 等待总线许可 */
                    if (bus_grnt_n_i == `ENABLE_N) begin // 获得总线使用权
                        state         <= `BUS_IF_STATE_ACCESS;
                        bus_as_n_o    <= `ENABLE_N;
                    end
                end
                `BUS_IF_STATE_ACCESS : begin // 访问总线
                    /* 使地址选通无效 */
                    bus_as_n_o    <= `DISABLE_N;
                    /* 等待就绪信号 */
                    if (bus_rdy_n_i   == `ENABLE_N) begin // 就绪信号到达
                        bus_req_n_o   <= `DISABLE_N;
                        bus_addr_o    <= `WORD_ADDR_W'h0;
                        bus_rw_o      <= `READ;
                        bus_wr_data_o <= `WORD_DATA_W'h0;
                        /* 保存读取到的数据 */
                        if (bus_rw_o == `READ) begin // 读取访问
                            rd_buf    <= bus_rd_data_i;
                        end
                        /* 检测是否发生延迟 */
                        if (stall_i == `ENABLE) begin // 发生延迟
                            state       <= `BUS_IF_STATE_STALL;
                        end else begin                // 未发生延迟
                            state       <= `BUS_IF_STATE_IDLE;
                        end
                    end
                end
                `BUS_IF_STATE_STALL : begin // 延迟
                    /* 检测是否发生延迟 */
                    if (stall_i == `DISABLE) begin // 解除延迟
                        state  <= `BUS_IF_STATE_IDLE;
                    end
                end
            endcase
        end
    end

endmodule