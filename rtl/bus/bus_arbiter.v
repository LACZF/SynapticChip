
`include "stddef.v"
`include "global_config.v"

`include "bus.v"

module bus_arbiter (
    input  wire       clk,
    input  wire       reset,
    /********** 仲裁信号 **********/
    // 0号总线主控
    input  wire       m0_req_n_i,     // 请求总线
    output reg        m0_grnt_n_o,    // 赋予总线
    // 1号总线主控
    input  wire       m1_req_n_i,     // 请求总线
    output reg        m1_grnt_n_o,    // 赋予总线
    // 2号总线主控
    input  wire       m2_req_n_i,     // 请求总线
    output reg        m2_grnt_n_o,    // 赋予总线
    // 3号总线主控
    input  wire       m3_req_n_i,     // 请求总线
    output reg        m3_grnt_n_o     // 赋予总线
);

    /********** 内部信号 **********/
    reg [`BusOwnerBus] owner;     // 总线使用权所有者

    /********** 赋予总线使用权 **********/
    always @(*) begin
        /* 赋予总线使用权的初始化 */
        m0_grnt_n_o = `DISABLE_N;
        m1_grnt_n_o = `DISABLE_N;
        m2_grnt_n_o = `DISABLE_N;
        m3_grnt_n_o = `DISABLE_N;
        /* 赋予总线使用权 */
        case (owner)
            `BUS_OWNER_MASTER_0 : begin // 0号总线主控
                m0_grnt_n_o = `ENABLE_N;
            end
            `BUS_OWNER_MASTER_1 : begin // 1号总线主控
                m1_grnt_n_o = `ENABLE_N;
            end
            `BUS_OWNER_MASTER_2 : begin // 2号总线主控
                m2_grnt_n_o = `ENABLE_N;
            end
            `BUS_OWNER_MASTER_3 : begin // 3号总线主控
                m3_grnt_n_o = `ENABLE_N;
            end
        endcase
    end

    /********** 总线使用权的仲裁 **********/
    always @(posedge clk or `RESET_EDGE reset) begin
        if (reset == `RESET_ENABLE) begin
            /* 异步复位 */
            owner <= `BUS_OWNER_MASTER_0;
        end else begin
            /* 仲裁 */
            case (owner)
                `BUS_OWNER_MASTER_0 : begin // 总线使用权所有者：0号总线主控
                    /* 下一个获得总线使用权的主控 */
                    if (m0_req_n_i == `ENABLE_N) begin            // 0号总线主控
                        owner <= `BUS_OWNER_MASTER_0;
                    end else if (m1_req_n_i == `ENABLE_N) begin // 1号总线主控
                        owner <= `BUS_OWNER_MASTER_1;
                    end else if (m2_req_n_i == `ENABLE_N) begin // 2号总线主控
                        owner <= `BUS_OWNER_MASTER_2;
                    end else if (m3_req_n_i == `ENABLE_N) begin // 3号总线主控
                        owner <= `BUS_OWNER_MASTER_3;
                    end
                end
                `BUS_OWNER_MASTER_1 : begin // 总线使用权所有者：1号总线主控
                    /* 下一个获得总线使用权的主控 */
                    if (m1_req_n_i == `ENABLE_N) begin            // 1号总线主控
                        owner <= `BUS_OWNER_MASTER_1;
                    end else if (m2_req_n_i == `ENABLE_N) begin // 2号总线主控
                        owner <= `BUS_OWNER_MASTER_2;
                    end else if (m3_req_n_i == `ENABLE_N) begin // 3号总线主控
                        owner <= `BUS_OWNER_MASTER_3;
                    end else if (m0_req_n_i == `ENABLE_N) begin // 0号总线主控
                        owner <= `BUS_OWNER_MASTER_0;
                    end
                end
                `BUS_OWNER_MASTER_2 : begin // 总线使用权所有者：2号总线主控
                    /* 下一个获得总线使用权的主控 */
                    if (m2_req_n_i == `ENABLE_N) begin            // 2号总线主控
                        owner <= `BUS_OWNER_MASTER_2;
                    end else if (m3_req_n_i == `ENABLE_N) begin // 3号总线主控
                        owner <= `BUS_OWNER_MASTER_3;
                    end else if (m0_req_n_i == `ENABLE_N) begin // 0号总线主控
                        owner <= `BUS_OWNER_MASTER_0;
                    end else if (m1_req_n_i == `ENABLE_N) begin // 1号总线主控
                        owner <= `BUS_OWNER_MASTER_1;
                    end
                end
                `BUS_OWNER_MASTER_3 : begin // 总线使用权所有者：3号总线主控
                    /* 下一个获得总线使用权的主控 */
                    if (m3_req_n_i == `ENABLE_N) begin            // 3号总线主控
                        owner <= `BUS_OWNER_MASTER_3;
                    end else if (m0_req_n_i == `ENABLE_N) begin // 0号总线主控
                        owner <= `BUS_OWNER_MASTER_0;
                    end else if (m1_req_n_i == `ENABLE_N) begin // 1号总线主控
                        owner <= `BUS_OWNER_MASTER_1;
                    end else if (m2_req_n_i == `ENABLE_N) begin // 2号总线主控
                        owner <= `BUS_OWNER_MASTER_2;
                    end
                end
            endcase
        end
    end

endmodule