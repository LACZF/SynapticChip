
`include "stddef.v"
`include "global_config.v"

`include "bus.v"

module bus_addr_dec #(
    parameter ADDR_WIDTH             = 30,
    parameter SLAVE_NUM              = `BUS_SLAVE_CH
)(
    input  wire                      clk,
    input  wire                      reset,

    input  wire [ADDR_WIDTH-1:0]     s_addr_i,
    output reg  [SLAVE_NUM-1:0]      slave_cs_n_o
);

    /********** 总线从属的索引 **********/
    wire [`BusSlaveIndexBus] s_index = s_addr_i[`BusSlaveIndexLoc];

    /********** 总线从属多路复用器 **********/
    always @(*) begin
        /* 初始化片选信号 - 所有从属默认不选中 */
        slave_cs_n_o = {SLAVE_NUM{`DISABLE_N}};

        /* 选择地址对应的从属，如果索引在有效范围内 */
        if (s_index < SLAVE_NUM) begin
            slave_cs_n_o[s_index] = `ENABLE_N;
        end
    end

endmodule