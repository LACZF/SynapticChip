// CPU与Ring总线接口模块
// 负责连接cpu_top和ring总线，处理信号格式转换

`include "cache_params.v"
`include "cache_system_params.v"

module cpu_ring_interface #(
    parameter NUM_RINGS         = 2,
    parameter ADDR_WIDTH        = 64,
    parameter DATA_WIDTH        = 64,
    parameter NODE_ID_WIDTH     = 8,
    parameter NODE_ID           = 0,
    parameter OPCODE_WIDTH      = 8,
    parameter MATCH_TYPE_WIDTH  = 2
) (
    input clk,
    input rst_n,

    // CPU_TOP接口
    input wire                        cpu_mem_req,
    input wire [ADDR_WIDTH-1:0]       cpu_mem_addr,
    input wire [511:0]                cpu_mem_wdata,
    input wire                        cpu_mem_we,
    output wire                       cpu_mem_ready,
    output wire [511:0]               cpu_mem_rdata,

    // Ring总线接口
    // 发送请求
    output wire [NUM_RINGS-1:0]       tx_req_ring_mask_o,
    output wire [NUM_RINGS-1:0]       tx_req_ring_disable_o,
    output wire                       tx_req_valid_o,
    output wire                       tx_req_is_order_o,
    output wire [OPCODE_WIDTH-1:0]    tx_req_opcode_o,
    output wire [MATCH_TYPE_WIDTH-1:0] tx_req_match_type_o,
    output wire [NODE_ID_WIDTH-1:0]   tx_req_source_id_o,
    output wire [NODE_ID_WIDTH-1:0]   tx_req_target_id_o,
    output wire [ADDR_WIDTH-1:0]      tx_req_addr_o,
    output wire [DATA_WIDTH-1:0]      tx_req_data_o,

    // 接受请求
    input wire                        rx_req_valid_i,
    input wire                        rx_req_is_order_i,
    input wire [OPCODE_WIDTH-1:0]     rx_req_opcode_i,
    input wire [MATCH_TYPE_WIDTH-1:0] rx_req_match_type_i,
    input wire [NODE_ID_WIDTH-1:0]    rx_req_source_id_i,
    input wire [NODE_ID_WIDTH-1:0]    rx_req_target_id_i,
    input wire [ADDR_WIDTH-1:0]       rx_req_addr_i,
    input wire [DATA_WIDTH-1:0]       rx_req_data_i,

    // 接收响应
    input wire                        rsp_valid_i,
    input wire [NODE_ID_WIDTH-1:0]    rsp_source_id_i,
    input wire [NODE_ID_WIDTH-1:0]    rsp_target_id_i,
    input wire [ADDR_WIDTH-1:0]       rsp_addr_i,
    input wire [DATA_WIDTH-1:0]       rsp_data_i
);

    // 状态定义
    localparam IDLE = 2'b00;
    localparam WAITING_RESP = 2'b01;

    // 内部信号
    reg [1:0] state;
    reg [ADDR_WIDTH-1:0] pending_addr;

    // 默认ring总线参数设置
    assign tx_req_ring_mask_o = {NUM_RINGS{1'b1}};  // 使用所有ring
    assign tx_req_ring_disable_o = {NUM_RINGS{1'b0}};  // 不禁用任何ring
    assign tx_req_is_order_o = 1'b1;  // 请求是有序的
    assign tx_req_source_id_o = NODE_ID;  // 源ID为当前节点
    assign tx_req_target_id_o = {NODE_ID_WIDTH{1'b0}};  // 目标ID默认为0（内存控制器）
    assign tx_req_match_type_o = 2'b00;  // 默认匹配类型

    // CPU内存请求转换为Ring总线请求
    assign tx_req_valid_o = (state == IDLE) && cpu_mem_req;
    assign tx_req_opcode_o = cpu_mem_we ? {OPCODE_WIDTH{1'b1}} : {OPCODE_WIDTH{1'b0}};  // 写操作为全1，读操作为全0
    assign tx_req_addr_o = cpu_mem_addr;
    assign tx_req_data_o = cpu_mem_wdata[0+:DATA_WIDTH];  // 从512位中取出低64位

    // Ring总线响应转换为CPU内存响应
    // 注意：这里使用简化的响应处理逻辑，实际系统中应根据地址匹配进行更复杂的处理
    assign cpu_mem_ready = (state == WAITING_RESP) && rsp_valid_i && (rsp_target_id_i == NODE_ID);
    assign cpu_mem_rdata = cpu_mem_ready ? {512{1'b0}} | rsp_data_i : {512{1'b0}};  // 将64位响应扩展到512位

    // 状态机逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pending_addr <= {ADDR_WIDTH{1'b0}};
        end else begin
            case (state)
                IDLE:
                    if (cpu_mem_req) begin
                        state <= WAITING_RESP;
                        pending_addr <= cpu_mem_addr;
                    end
                WAITING_RESP:
                    if (rsp_valid_i && (rsp_target_id_i == NODE_ID)) begin
                        state <= IDLE;
                        pending_addr <= {ADDR_WIDTH{1'b0}};
                    end
            endcase
        end
    end

    // 调试信息
    always @(posedge clk) begin
        if (tx_req_valid_o) begin
            $display("[%0t ps] CPU_RING_INTERFACE: Sending request - Opcode=0x%h, Addr=0x%h, Data=0x%h",
                     $time, tx_req_opcode_o, tx_req_addr_o, tx_req_data_o);
        end
        if (cpu_mem_ready) begin
            $display("[%0t ps] CPU_RING_INTERFACE: Received response - Addr=0x%h, Data=0x%h",
                     $time, pending_addr, cpu_mem_rdata);
        end
    end

endmodule