
// This is the bus top module

`include "ring_bus_params.v"
`include "top_system_params.v"

module bus_top #(
    parameter BUS_TYPE         = `BUS_TYPE_RING, // 总线类型：`BUS_TYPE_RING 或 `BUS_TYPE_DIRECT
    parameter NUM_RINGS        = 2,        // Ring总线数量 (当BUS_TYPE为`BUS_TYPE_RING时有效)
    parameter NUM_NODES        = 4,        // 每个Ring的节点数 (当BUS_TYPE为`BUS_TYPE_RING时有效)
    parameter ADDR_WIDTH       = 32,       // 地址宽度
    parameter DATA_WIDTH       = 64,       // 数据宽度
    parameter OPCODE_WIDTH     = 8,        // 操作类型的宽带：read/write/reponse等
    parameter RING_ID_WIDTH    = 4,        // ring ID宽度
    parameter NODE_ID_WIDTH    = 8,        // 节点ID宽度
    parameter TX_FIFO_DEPTH    = 4,        // 发送FIFO深度
    parameter RX_FIFO_DEPTH    = 4,        // 接收FIFO深度
    parameter RSP_FIFO_DEPTH   = 4,        // 响应FIFO深度
    parameter NUM_CORES        = 4,
    parameter MATCH_TYPE_WIDTH = 2         // 匹配类型宽度
) (
    input  wire                                   clk,
    input  wire                                   rst_n,

    input  wire [NUM_NODES*ADDR_WIDTH-1:0]        node_start_addr_i,
    input  wire [NUM_NODES*ADDR_WIDTH-1:0]        node_end_addr_i,

    // 发送请求
    input  wire [NUM_NODES*NUM_RINGS-1:0]         tx_req_ring_mask_i,      // 指定使用的Ring
    input  wire [NUM_NODES*NUM_RINGS-1:0]         tx_req_ring_disable_i,   // 禁用的Ring
    input  wire [NUM_NODES-1:0]                   tx_req_valid_i,
    input  wire [NUM_NODES-1:0]                   tx_req_is_order_i,
    input  wire [NUM_NODES*OPCODE_WIDTH-1:0]      tx_req_opcode_i,
    input  wire [NUM_NODES*MATCH_TYPE_WIDTH-1:0]  tx_req_match_type_i,
    input  wire [NUM_NODES*NODE_ID_WIDTH-1:0]     tx_req_source_id_i,
    input  wire [NUM_NODES*NODE_ID_WIDTH-1:0]     tx_req_target_id_i,
    input  wire [NUM_NODES*ADDR_WIDTH-1:0]        tx_req_addr_i,
    input  wire [NUM_NODES*DATA_WIDTH-1:0]        tx_req_data_i,
    output wire [NUM_NODES-1:0]                   tx_req_ready_o,

    // 接受请求
    output wire [NUM_NODES-1:0]                   rx_req_valid_o,
    output wire [NUM_NODES-1:0]                   rx_req_is_order_o,
    output wire [NUM_NODES*OPCODE_WIDTH-1:0]      rx_req_opcode_o,
    output wire [NUM_NODES*MATCH_TYPE_WIDTH-1:0]  rx_req_match_type_o,
    output wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rx_req_source_id_o,
    output wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rx_req_target_id_o,
    output wire [NUM_NODES*ADDR_WIDTH-1:0]        rx_req_addr_o,
    output wire [NUM_NODES*DATA_WIDTH-1:0]        rx_req_data_o,

    // 接收响应
    output wire [NUM_NODES-1:0]                   rsp_valid_o,
    output wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rsp_source_id_o,
    output wire [NUM_NODES*NODE_ID_WIDTH-1:0]     rsp_target_id_o,
    output wire [NUM_NODES*ADDR_WIDTH-1:0]        rsp_addr_o,
    output wire [NUM_NODES*DATA_WIDTH-1:0]        rsp_data_o,

    // Ring总线状态
    output wire [NUM_RINGS*RING_ID_WIDTH-1:0]     ring_id_o,
    output wire [NUM_RINGS-1:0]                   ring_busy,

    // 外设接口
    output wire                                   uart_txd,
    input  wire                                   uart_rxd,
    input  wire [15:0]                            gpio_in,
    output wire [15:0]                            gpio_out,
    input  wire [3:0]                             dip_switch,
    output wire [3:0]                             led,

    // 中断接口
    output wire [(NUM_CORES*16)-1:0]              core_irq,
    output wire [NUM_CORES-1:0]                   timer_irq,
    output wire [NUM_CORES-1:0]                   external_irq,
    output wire [NUM_CORES-1:0]                   software_irq
);
    // 内部信号定义
    wire                                          req_valid;
    wire [ADDR_WIDTH-1:0]                         req_addr;
    wire [MATCH_TYPE_WIDTH-1:0]                   req_match_type;
    wire [NODE_ID_WIDTH-1:0]                      req_target_id;
    wire [DATA_WIDTH-1:0]                         req_data;
    wire [NUM_RINGS-1:0]                          req_ring_mask;
    wire [NUM_RINGS-1:0]                          req_ring_disable;
    wire                                          req_ready;

    wire [NUM_RINGS-1:0]                          ring_req_valid;
    wire [NUM_RINGS-1:0]                          ring_req_ready;
    wire [NUM_RINGS*ADDR_WIDTH-1:0]               ring_req_addr;
    wire [NUM_RINGS*MATCH_TYPE_WIDTH-1:0]         ring_req_match_type;
    wire [NUM_RINGS*NODE_ID_WIDTH-1:0]            ring_req_target_id;
    wire [NUM_RINGS*DATA_WIDTH-1:0]               ring_req_data;

    wire                                          cpu_req;
    wire [ADDR_WIDTH-1:0]                         cpu_addr;
    wire [DATA_WIDTH-1:0]                         cpu_wdata;
    wire [DATA_WIDTH-1:0]                         cpu_rdata;
    wire                                          cpu_we;
    wire [7:0]                                    cpu_byte_en;
    wire                                          cpu_ready;

    wire [ADDR_WIDTH-1:0]                         sys_addr;
    wire [DATA_WIDTH-1:0]                         sys_wdata;
    wire [DATA_WIDTH-1:0]                         sys_rdata;
    wire                                          sys_we;
    wire [7:0]                                    sys_byte_en;
    wire                                          sys_req;
    wire                                          sys_ready;
    wire [1:0]                                    sys_master_id;

    wire                                          flash_req;
    wire [ADDR_WIDTH-1:0]                         flash_addr;
    wire [DATA_WIDTH-1:0]                         flash_wdata;
    wire [DATA_WIDTH-1:0]                         flash_rdata;
    wire                                          flash_we;
    wire                                          flash_ready;

    wire                                          sram_req;
    wire [ADDR_WIDTH-1:0]                         sram_addr;
    wire [DATA_WIDTH-1:0]                         sram_wdata;
    wire [DATA_WIDTH-1:0]                         sram_rdata;
    wire                                          sram_we;
    wire                                          sram_ready;

    wire                                          mmio_req;
    wire [ADDR_WIDTH-1:0]                         mmio_addr;
    wire [DATA_WIDTH-1:0]                         mmio_wdata;
    wire [DATA_WIDTH-1:0]                         mmio_rdata;
    wire                                          mmio_we;
    wire [7:0]                                    mmio_byte_en;
    wire                                          mmio_ready;

    // 扩展总线接口信号
    wire [ADDR_WIDTH-1:0]                         ext_bus_addr;
    wire [DATA_WIDTH-1:0]                         ext_bus_wdata;
    wire [DATA_WIDTH-1:0]                         ext_bus_rdata;
    wire                                          ext_bus_we;
    wire [7:0]                                    ext_bus_byte_en;
    wire                                          ext_bus_req;
    wire                                          ext_bus_ready;
    wire [OPCODE_WIDTH-1:0]                       ext_bus_opcode;
    // 根据总线类型选择实例化方式
    generate
        if (BUS_TYPE == `BUS_TYPE_RING) begin : ring_bus_instance
            // Ring总线模式
            ring_bus #(
                .NUM_RINGS(NUM_RINGS),
                .NUM_NODES(NUM_NODES),
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .OPCODE_WIDTH(OPCODE_WIDTH),
                .RING_ID_WIDTH(RING_ID_WIDTH),
                .NODE_ID_WIDTH(NODE_ID_WIDTH),
                .TX_FIFO_DEPTH(TX_FIFO_DEPTH),
                .RX_FIFO_DEPTH(RX_FIFO_DEPTH),
                .RSP_FIFO_DEPTH(RSP_FIFO_DEPTH),
                .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH)
            ) u_ring_bus (
                .clk(clk),
                .rst_n(rst_n),

                .node_start_addr_i(node_start_addr_i),
                .node_end_addr_i(node_end_addr_i),

                .tx_req_ring_mask_i(tx_req_ring_mask_i),
                .tx_req_ring_disable_i(tx_req_ring_disable_i),
                .tx_req_valid_i(tx_req_valid_i),
                .tx_req_is_order_i(tx_req_is_order_i),
                .tx_req_opcode_i(tx_req_opcode_i),
                .tx_req_match_type_i(tx_req_match_type_i),
                .tx_req_source_id_i(tx_req_source_id_i),
                .tx_req_target_id_i(tx_req_target_id_i),
                .tx_req_addr_i(tx_req_addr_i),
                .tx_req_data_i(tx_req_data_i),
                .tx_req_ready_o(tx_req_ready_o),

                .rx_req_valid_o(rx_req_valid_o),
                .rx_req_is_order_o(rx_req_is_order_o),
                .rx_req_opcode_o(rx_req_opcode_o),
                .rx_req_match_type_o(rx_req_match_type_o),
                .rx_req_source_id_o(rx_req_source_id_o),
                .rx_req_target_id_o(rx_req_target_id_o),
                .rx_req_addr_o(rx_req_addr_o),
                .rx_req_data_o(rx_req_data_o),

                .rsp_valid_o(rsp_valid_o),
                .rsp_source_id_o(rsp_source_id_o),
                .rsp_target_id_o(rsp_target_id_o),
                .rsp_addr_o(rsp_addr_o),
                .rsp_data_o(rsp_data_o),

                .ring_id_o(ring_id_o),
                .ring_busy(ring_busy)
            );
        end else if (BUS_TYPE == `BUS_TYPE_DIRECT) begin : direct_connect_instance
            // 直接连接模式 - 使用地址解码分发请求
            // 内部信号定义
            wire [NUM_NODES-1:0]                        decoded_req_valid;
            wire [NUM_NODES*OPCODE_WIDTH-1:0]           decoded_req_opcode;
            wire [NUM_NODES*MATCH_TYPE_WIDTH-1:0]       decoded_req_match_type;
            wire [NUM_NODES*NODE_ID_WIDTH-1:0]          decoded_req_source_id;
            wire [NUM_NODES*NODE_ID_WIDTH-1:0]          decoded_req_target_id;
            wire [NUM_NODES*ADDR_WIDTH-1:0]             decoded_req_addr;
            wire [NUM_NODES*DATA_WIDTH-1:0]             decoded_req_data;
            wire [NUM_NODES-1:0]                        decoded_req_is_order;

            // 地址解码器 - 根据请求的地址范围将请求分发到对应的目标节点
            // 每个节点监控所有其他节点的请求，并根据地址范围决定是否处理
            genvar i, j;
            for (i = 0; i < NUM_NODES; i = i + 1) begin : address_decoder_gen
                // 初始化节点i的接收信号为0
                assign decoded_req_valid[i] = 1'b0;
                assign decoded_req_opcode[i*OPCODE_WIDTH +: OPCODE_WIDTH] = {OPCODE_WIDTH{1'b0}};
                assign decoded_req_match_type[i*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH] = {MATCH_TYPE_WIDTH{1'b0}};
                assign decoded_req_source_id[i*NODE_ID_WIDTH +: NODE_ID_WIDTH] = {NODE_ID_WIDTH{1'b0}};
                assign decoded_req_target_id[i*NODE_ID_WIDTH +: NODE_ID_WIDTH] = {NODE_ID_WIDTH{1'b0}};
                assign decoded_req_addr[i*ADDR_WIDTH +: ADDR_WIDTH] = {ADDR_WIDTH{1'b0}};
                assign decoded_req_data[i*DATA_WIDTH +: DATA_WIDTH] = {DATA_WIDTH{1'b0}};
                assign decoded_req_is_order[i] = 1'b0;

                // 处理来自其他节点的请求
                for (j = 0; j < NUM_NODES; j = j + 1) begin : node_request_process
                    if (i != j) begin : cross_node_requests
                        wire [ADDR_WIDTH-1:0] req_addr = tx_req_addr_i[j*ADDR_WIDTH +: ADDR_WIDTH];
                        wire [NODE_ID_WIDTH-1:0] req_target_id = tx_req_target_id_i[j*NODE_ID_WIDTH +: NODE_ID_WIDTH];
                        wire [MATCH_TYPE_WIDTH-1:0] req_match_type = tx_req_match_type_i[j*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH];
                        wire target_match;
                        wire addr_range_match;

                        // 目标ID匹配逻辑
                        assign target_match = (req_match_type == `RING_MATCH_TYPE_ID) && (req_target_id == i);

                        // 地址范围匹配逻辑 - 检查请求地址是否在节点i的地址范围内
                        assign addr_range_match = (req_match_type == `RING_MATCH_TYPE_ADDR) &&
                                                  (req_addr >= node_start_addr_i[i*ADDR_WIDTH +: ADDR_WIDTH]) &&
                                                  (req_addr <= node_end_addr_i[i*ADDR_WIDTH +: ADDR_WIDTH]);

                        // 当请求有效的情况下，如果目标匹配或地址范围匹配，则将请求转发到节点i
                        always @(*) begin
                            if (tx_req_valid_i[j] && (target_match || addr_range_match)) begin
                                decoded_req_valid[i] = 1'b1;
                                decoded_req_opcode[i*OPCODE_WIDTH +: OPCODE_WIDTH] = tx_req_opcode_i[j*OPCODE_WIDTH +: OPCODE_WIDTH];
                                decoded_req_match_type[i*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH] = req_match_type;
                                decoded_req_source_id[i*NODE_ID_WIDTH +: NODE_ID_WIDTH] = tx_req_source_id_i[j*NODE_ID_WIDTH +: NODE_ID_WIDTH];
                                decoded_req_target_id[i*NODE_ID_WIDTH +: NODE_ID_WIDTH] = i;
                                decoded_req_addr[i*ADDR_WIDTH +: ADDR_WIDTH] = req_addr;
                                decoded_req_data[i*DATA_WIDTH +: DATA_WIDTH] = tx_req_data_i[j*DATA_WIDTH +: DATA_WIDTH];
                                decoded_req_is_order[i] = tx_req_is_order_i[j];
                            end
                        end
                    end
                end
            end

            // 连接解码后的请求到接收端口
            for (i = 0; i < NUM_NODES; i = i + 1) begin : connect_decoded_requests
                assign rx_req_valid_o[i] = decoded_req_valid[i];
                assign rx_req_is_order_o[i] = decoded_req_is_order[i];
                assign rx_req_opcode_o[i*OPCODE_WIDTH +: OPCODE_WIDTH] = decoded_req_opcode[i*OPCODE_WIDTH +: OPCODE_WIDTH];
                assign rx_req_match_type_o[i*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH] = decoded_req_match_type[i*MATCH_TYPE_WIDTH +: MATCH_TYPE_WIDTH];
                assign rx_req_source_id_o[i*NODE_ID_WIDTH +: NODE_ID_WIDTH] = decoded_req_source_id[i*NODE_ID_WIDTH +: NODE_ID_WIDTH];
                assign rx_req_target_id_o[i*NODE_ID_WIDTH +: NODE_ID_WIDTH] = decoded_req_target_id[i*NODE_ID_WIDTH +: NODE_ID_WIDTH];
                assign rx_req_addr_o[i*ADDR_WIDTH +: ADDR_WIDTH] = decoded_req_addr[i*ADDR_WIDTH +: ADDR_WIDTH];
                assign rx_req_data_o[i*DATA_WIDTH +: DATA_WIDTH] = decoded_req_data[i*DATA_WIDTH +: DATA_WIDTH];

                // 返回ready信号
                assign tx_req_ready_o[i] = 1'b1; // 简化处理，总是返回ready
            end

            // 默认响应信号
            assign rsp_valid_o = {NUM_NODES{1'b0}};
            assign rsp_source_id_o = {NUM_NODES*NODE_ID_WIDTH{1'b0}};
            assign rsp_target_id_o = {NUM_NODES*NODE_ID_WIDTH{1'b0}};
            assign rsp_addr_o = {NUM_NODES*ADDR_WIDTH{1'b0}};
            assign rsp_data_o = {NUM_NODES*DATA_WIDTH{1'b0}};

            // Ring相关信号
            assign ring_id_o = {NUM_RINGS*RING_ID_WIDTH{1'b0}};
            assign ring_busy = {NUM_RINGS{1'b0}};
        end else begin : extended_bus_instance
            // 扩展总线接口 - 提供连接其他总线类型的能力
            // 这里仅提供基础框架，具体实现需要根据实际扩展的总线类型添加
            // 默认返回未连接状态
            assign tx_req_ready_o = {NUM_NODES{1'b0}};
            assign rx_req_valid_o = {NUM_NODES{1'b0}};
            assign rx_req_is_order_o = {NUM_NODES{1'b0}};
            assign rx_req_opcode_o = {NUM_NODES*OPCODE_WIDTH{1'b0}};
            assign rx_req_match_type_o = {NUM_NODES*MATCH_TYPE_WIDTH{1'b0}};
            assign rx_req_source_id_o = {NUM_NODES*NODE_ID_WIDTH{1'b0}};
            assign rx_req_target_id_o = {NUM_NODES*NODE_ID_WIDTH{1'b0}};
            assign rx_req_addr_o = {NUM_NODES*ADDR_WIDTH{1'b0}};
            assign rx_req_data_o = {NUM_NODES*DATA_WIDTH{1'b0}};

            assign rsp_valid_o = {NUM_NODES{1'b0}};
            assign rsp_source_id_o = {NUM_NODES*NODE_ID_WIDTH{1'b0}};
            assign rsp_target_id_o = {NUM_NODES*NODE_ID_WIDTH{1'b0}};
            assign rsp_addr_o = {NUM_NODES*ADDR_WIDTH{1'b0}};
            assign rsp_data_o = {NUM_NODES*DATA_WIDTH{1'b0}};

            assign ring_id_o = {NUM_RINGS*RING_ID_WIDTH{1'b0}};
            assign ring_busy = {NUM_RINGS{1'b0}};
        end
    endgenerate

    // 根据总线类型决定是否实例化Ring仲裁器
    generate
        if (BUS_TYPE == `BUS_TYPE_RING) begin : ring_arbiter_instance
            // Ring总线模式下实例化仲裁器
            ring_arbiter #(
                .NUM_RINGS(NUM_RINGS),
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .NODE_ID_WIDTH(NODE_ID_WIDTH),
                .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH)
            ) u_ring_arbiter (
                .clk(clk),
                .rst_n(rst_n),

                // 主请求接口
                .req_valid(req_valid),
                .req_addr(req_addr),
                .req_match_type(req_match_type),
                .req_target_id(req_target_id),
                .req_data(req_data),
                .req_ring_mask(req_ring_mask),
                .req_ring_disable(req_ring_disable),
                .req_ready(req_ready),

                // Ring总线接口
                .ring_req_valid(ring_req_valid),
                .ring_req_ready(ring_req_ready),
                .ring_req_addr(ring_req_addr),
                .ring_req_match_type(ring_req_match_type),
                .ring_req_target_id(ring_req_target_id),
                .ring_req_data(ring_req_data),

                // 状态输出
                .ring_busy(ring_busy)
            );
        end else begin : no_arbiter
            // 非Ring总线模式下不实例化仲裁器，而是驱动相关信号到默认值
            assign ring_req_valid = {NUM_RINGS{1'b0}};
            assign ring_req_addr = {NUM_RINGS*ADDR_WIDTH{1'b0}};
            assign ring_req_match_type = {NUM_RINGS*MATCH_TYPE_WIDTH{1'b0}};
            assign ring_req_target_id = {NUM_RINGS*NODE_ID_WIDTH{1'b0}};
            assign ring_req_data = {NUM_RINGS*DATA_WIDTH{1'b0}};
        end
    endgenerate
endmodule