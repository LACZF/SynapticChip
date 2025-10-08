// CPU与Ring总线接口模块
// 负责连接cpu_top和ring总线，处理信号格式转换

`include "top_system_params.v"

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
    localparam WAITING_SPI_RESP = 2'b10; // 等待SPI响应的新状态

    // 内部信号
    reg [1:0] state;
    reg [ADDR_WIDTH-1:0] pending_addr;
    reg is_instruction_read; // 标记是否为指令读取
    wire is_instruction_addr; // 判断地址是否为指令地址范围 (假设指令地址范围是 0x8000_0000 开始)
    reg is_cache_miss; // 标记是否为缓存未命中

    // 判断是否为指令地址（假设指令从0x8000_0000开始）
    assign is_instruction_addr = (cpu_mem_addr[31:28] == 4'h8);

    // 检测缓存未命中：当发出请求但在一段时间内没有收到响应时，认为是缓存未命中
    // 简单实现：使用计数器来检测超时
    reg [3:0] cache_response_timeout; // 缓存响应超时计数器

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cache_response_timeout <= 4'h0;
            is_cache_miss <= 1'b0;
        end else begin
            if (state == WAITING_RESP) begin
                cache_response_timeout <= cache_response_timeout + 1'b1;
                // 如果超时（这里简单使用4个周期），则认为是缓存未命中
                if (cache_response_timeout == 4'hF) begin
                    is_cache_miss <= 1'b1;
                end
            end else begin
                cache_response_timeout <= 4'h0;
                is_cache_miss <= 1'b0;
            end
        end
    end

    // 默认ring总线参数设置
    assign tx_req_ring_mask_o = {NUM_RINGS{1'b1}};  // 使用所有ring
    assign tx_req_ring_disable_o = {NUM_RINGS{1'b0}};  // 不禁用任何ring
    assign tx_req_is_order_o = 1'b1;  // 请求是有序的
    assign tx_req_source_id_o = NODE_ID;  // 源ID为当前节点
    assign tx_req_match_type_o = 2'b00;  // 默认匹配类型

    // 目标ID：正常情况下为内存控制器，当需要通过SPI读取指令时为SPI节点
    assign tx_req_target_id_o = (state == IDLE && is_instruction_addr && !cpu_mem_we) ?
                                `NODE_SPI : {NODE_ID_WIDTH{1'b0}};  // 0为内存控制器，`NODE_SPI为SPI节点

    // CPU内存请求转换为Ring总线请求
    assign tx_req_valid_o = (state == IDLE) && cpu_mem_req;
    assign tx_req_opcode_o = cpu_mem_we ? {OPCODE_WIDTH{1'b1}} : {OPCODE_WIDTH{1'b0}};  // 写操作为全1，读操作为全0
    assign tx_req_addr_o = cpu_mem_addr;
    assign tx_req_data_o = cpu_mem_wdata[0+:DATA_WIDTH];  // 从512位中取出低64位

    // Ring总线响应转换为CPU内存响应
    // 注意：这里使用简化的响应处理逻辑，实际系统中应根据地址匹配进行更复杂的处理
    assign cpu_mem_ready = ((state == WAITING_RESP) && rsp_valid_i && (rsp_target_id_i == NODE_ID)) ||
                          ((state == WAITING_SPI_RESP) && rsp_valid_i && (rsp_source_id_i == `NODE_SPI));
    assign cpu_mem_rdata = cpu_mem_ready ? {512{1'b0}} | rsp_data_i : {512{1'b0}};  // 将64位响应扩展到512位

    // 状态机逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pending_addr <= {ADDR_WIDTH{1'b0}};
            is_instruction_read <= 1'b0;
        end else begin
            case (state)
                IDLE:
                    if (cpu_mem_req) begin
                        state <= WAITING_RESP;
                        pending_addr <= cpu_mem_addr;
                        // 标记是否为指令读取
                        is_instruction_read <= is_instruction_addr && !cpu_mem_we;
                    end
                WAITING_RESP:
                    if (rsp_valid_i && (rsp_target_id_i == NODE_ID)) begin
                        // 正常内存响应
                        state <= IDLE;
                        pending_addr <= {ADDR_WIDTH{1'b0}};
                        is_instruction_read <= 1'b0;
                    end else if (is_instruction_read && is_cache_miss) begin
                        // 指令读取且缓存未命中，切换到SPI读取
                        state <= WAITING_SPI_RESP;
                        // 不需要重新发送请求，因为在tx_req_target_id_o中已经根据状态和地址类型设置了目标ID
                    end
                WAITING_SPI_RESP:
                    if (rsp_valid_i && (rsp_source_id_i == `NODE_SPI)) begin
                        // 收到SPI响应
                        state <= IDLE;
                        pending_addr <= {ADDR_WIDTH{1'b0}};
                        is_instruction_read <= 1'b0;
                    end
            endcase
        end
    end

    // 调试信息
`ifdef DEBUG
    always @(posedge clk) begin
        if (tx_req_valid_o) begin
            $display("[%0t ps] CPU_RING_INTERFACE: Sending request - Opcode=0x%h, Addr=0x%h, Data=0x%h, TargetID=0x%h",
                     $time, tx_req_opcode_o, tx_req_addr_o, tx_req_data_o, tx_req_target_id_o);
            if (tx_req_target_id_o == `NODE_SPI) begin
                $display("[%0t ps] CPU_RING_INTERFACE: Instruction read request directed to SPI flash", $time);
            end
        end
        if (is_cache_miss && is_instruction_read) begin
            $display("[%0t ps] CPU_RING_INTERFACE: Cache miss detected for instruction at address 0x%h, switching to SPI read",
                     $time, pending_addr);
        end
        if (cpu_mem_ready) begin
            if (state == WAITING_SPI_RESP) begin
                $display("[%0t ps] CPU_RING_INTERFACE: Received SPI response - Addr=0x%h, Data=0x%h",
                         $time, pending_addr, cpu_mem_rdata);
            end else begin
                $display("[%0t ps] CPU_RING_INTERFACE: Received memory response - Addr=0x%h, Data=0x%h",
                         $time, pending_addr, cpu_mem_rdata);
            end
        end
    end
`endif

endmodule