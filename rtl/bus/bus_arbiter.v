
`include "stddef.v"
`include "global_config.v"

`include "bus.v"

module bus_arbiter # (
    parameter MASTER_NUM = `BUS_MASTER_CH
)(
    input  wire                   clk,
    input  wire                   reset,

    /********** 仲裁信号 **********/
    input  wire [MASTER_NUM-1:0]  m_req_n_i,     // 请求总线数组
    output reg  [MASTER_NUM-1:0]  m_grnt_n_o     // 赋予总线数组
);

    reg [`BusOwnerBus] owner;

    integer i;
    integer found;
    reg [`BusOwnerBus] next_owner;

    /********** 赋予总线使用权 **********/
    always @(*) begin
        /* 赋予总线使用权的初始化 */
        m_grnt_n_o = {MASTER_NUM{`DISABLE_N}};

        /* 赋予总线使用权 - 仅在所有者索引有效时 */
        if (owner < MASTER_NUM) begin
            m_grnt_n_o[owner] = `ENABLE_N;
        end
    end

    /********** 总线使用权的仲裁 **********/
    always @(posedge clk or `RESET_EDGE reset) begin
        if (reset == `RESET_ENABLE) begin
            /* 异步复位 */
            owner <= `BUS_OWNER_MASTER_0;
        end else begin
            /* 简化的轮转仲裁算法 */
            // 首先检查当前所有者是否仍在请求
            if (m_req_n_i[owner] == `ENABLE_N) begin
                // 当前所有者继续持有总线
                owner <= owner;
            end else begin
                // 从当前所有者的下一个开始查找
                next_owner = owner; // 默认保持当前所有者
                found = 0;

                for (i = 1; i < MASTER_NUM; i = i + 1) begin
                    if (!found && m_req_n_i[(owner + i) % MASTER_NUM] == `ENABLE_N) begin
                        next_owner = (owner + i) % MASTER_NUM;
                        found = 1;
                    end
                end

                owner <= next_owner;
            end
        end
    end

endmodule