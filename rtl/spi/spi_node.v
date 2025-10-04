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
    input wire [ADDR_WIDTH-1:0] node_start_addr,
    input wire [ADDR_WIDTH-1:0] node_end_addr,

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
    output reg [DATA_WIDTH-1:0] rsp_data,

    // SPI物理接口
    output reg spi_cs_n,
    output reg spi_clk,
    output reg spi_mosi,
    input wire spi_miso
);
    // 内部状态
    localparam IDLE = 2'b00;
    localparam PROCESS = 2'b01;
    localparam RESPOND = 2'b10;

    reg [1:0] state;
    reg core_req;
    reg core_we;
    reg [ADDR_WIDTH-1:0] core_addr;
    reg [DATA_WIDTH-1:0] core_data_in;
    wire [DATA_WIDTH-1:0] core_data_out;
    wire core_ack;

    // 保存请求信息的寄存器
    reg [NODE_ID_WIDTH-1:0] saved_source_id;
    reg [NODE_ID_WIDTH-1:0] saved_target_id;
    reg [ADDR_WIDTH-1:0] saved_addr;

    // 实例化SPI核心控制器
    spi_core #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_spi_core (
        .clk(clk),
        .rst_n(rst_n),
        .req(core_req),
        .we(core_we),
        .addr(core_addr),
        .data_in(core_data_in),
        .data_out(core_data_out),
        .ack(core_ack),
        .spi_cs_n(spi_cs_n),
        .spi_clk(spi_clk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso)
    );

    // 节点状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            core_req <= 1'b0;
            core_we <= 1'b0;
            core_addr <= 32'h0;
            core_data_in <= 32'h0;
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
                        core_req <= 1'b0;

                        // 检查是否有请求且目标是本节点
                        if (req_valid && (req_target_id == node_id)) begin
                            // 保存请求信息
                            saved_source_id <= req_source_id;
                            saved_target_id <= req_target_id;
                            saved_addr <= req_addr;

                            // 设置核心控制器信号
                            core_we <= req_we;
                            core_addr <= {24'h0, req_addr[7:0]}; // 只使用低8位作为寄存器地址
                            if (req_we) begin
                                core_data_in <= req_data;
                            end

                            // 启动核心控制器操作
                            core_req <= 1'b1;
                            state <= PROCESS;
                        end
                    end

                PROCESS:
                    begin
                        // 等待核心控制器完成操作
                        if (core_ack) begin
                            core_req <= 1'b0;

                            // 准备响应
                            rsp_source_id <= node_id;
                            rsp_target_id <= saved_source_id;
                            rsp_addr <= saved_addr;

                            // 如果是读操作，设置读取的数据
                            if (!core_we) begin
                                rsp_data <= core_data_out;
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