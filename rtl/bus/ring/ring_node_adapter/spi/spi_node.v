// spi_node.v
// SPI节点实现，连接SPI控制器和Ring总线

`include "spi_params.v"

module spi_node #(
    parameter DATA_WIDTH = `SPI_DATA_WIDTH,
    parameter ADDR_WIDTH = `SPI_ADDR_WIDTH,
    parameter NODE_ID_WIDTH = `SPI_NODE_ID_WIDTH
) (
    input wire clk,
    input wire rst_n,

    // Ring总线接口
    input wire [NODE_ID_WIDTH-1:0] node_id,

    output reg                          spi_req_o,
    output reg                          spi_we_o,
    output reg [ADDR_WIDTH-1:0]         spi_addr_o,
    output reg [DATA_WIDTH-1:0]         spi_data_in_o,
    input  reg [DATA_WIDTH-1:0]         spi_data_out_i,
    input  reg                          spi_ack_i,
    input  reg                          spi_cs_n_i,
    input  reg                          spi_clk_i,
    input  reg                          spi_mosi_i,
    output wire                         spi_miso_o,

    // 请求接口
    input wire req_valid,
    input wire [NODE_ID_WIDTH-1:0] req_source_id,
    input wire [NODE_ID_WIDTH-1:0] req_target_id,
    input wire [ADDR_WIDTH-1:0] req_addr,
    input wire [DATA_WIDTH-1:0] req_data,
    input wire req_we,

    // 响应接口
    output reg rsp_valid,
    output reg [NODE_ID_WIDTH-1:0] rsp_source_id,
    output reg [NODE_ID_WIDTH-1:0] rsp_target_id,
    output reg [ADDR_WIDTH-1:0] rsp_addr,
    output reg [DATA_WIDTH-1:0] rsp_data
);
    // 内部状态
    localparam IDLE = 2'b00;
    localparam PROCESS = 2'b01;
    localparam RESPOND = 2'b10;

    reg [1:0] state;

    // 保存请求信息的寄存器
    reg [NODE_ID_WIDTH-1:0] saved_source_id;
    reg [NODE_ID_WIDTH-1:0] saved_target_id;
    reg [ADDR_WIDTH-1:0] saved_addr;

    // 节点状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            spi_req_o <= 1'b0;
            spi_we_o <= 1'b0;
            spi_addr_o <= 32'h0;
            spi_data_in_o <= 32'h0;
            rsp_valid <= 1'b0;
            rsp_source_id <= 0;
            rsp_target_id <= 0;
            rsp_addr <= 32'h0;
            rsp_data <= 32'h0;
        end else begin
            case (state)
                IDLE:
                    begin
                        rsp_valid <= 1'b0;
                        spi_req_o <= 1'b0;

                        // 检查是否有请求且目标是本节点
                        if (req_valid && (req_target_id == node_id)) begin
                            // 保存请求信息
                            saved_source_id <= req_source_id;
                            saved_target_id <= req_target_id;
                            saved_addr <= req_addr;

                            // 设置核心控制器信号
                            spi_we_o <= req_we;
                            spi_addr_o <= {24'h0, req_addr[7:0]}; // 只使用低8位作为寄存器地址
                            if (req_we) begin
                                spi_data_in_o <= req_data;
                            end

                            // 启动核心控制器操作
                            spi_req_o <= 1'b1;
                            state <= PROCESS;
                        end
                    end

                PROCESS:
                    begin
                        // 等待核心控制器完成操作
                        if (spi_ack_i) begin
                            spi_req_o <= 1'b0;

                            // 准备响应
                            rsp_source_id <= node_id;
                            rsp_target_id <= saved_source_id;
                            rsp_addr <= saved_addr;

                            // 如果是读操作，设置读取的数据
                            if (!spi_we_o) begin
                                rsp_data <= spi_data_out_i;
                            end else begin
                                rsp_data <= 32'h0; // 写操作返回0
                            end

                            state <= RESPOND;
                        end
                    end

                RESPOND:
                    begin
                        // 发送响应
                        rsp_valid <= 1'b1;
                        state <= IDLE;
                    end
            endcase
        end
    end

endmodule