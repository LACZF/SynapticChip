// cpu_top.v
// CPU顶层模块，连接top_system和具体的CPU实现
// 预留了与多种CPU对接的能力

`include "riscv_core_params.v"

module cpu_top #(
    parameter NUM_RINGS         = 2,
    parameter ADDR_WIDTH        = 32,
    parameter DATA_WIDTH        = 64,
    parameter NODE_ID_WIDTH     = 8,
    parameter NODE_ID           = 0,
    parameter OPCODE_WIDTH      = 8,
    parameter MATCH_TYPE_WIDTH  = 2,
    parameter INST_WIDTH        = 32,
    parameter CPU_TYPE          = 0  // 0: RISC-V, 1: 预留其他CPU类型
) (
    input clk,
    input rst_n,

    // 外部中断
    input ext_int,

    // 发送请求
    input wire [NUM_RINGS-1:0]         tx_req_ring_mask_i,
    input wire [NUM_RINGS-1:0]         tx_req_ring_disable_i,
    input wire                         tx_req_valid_i,
    input wire                         tx_req_is_order_i,
    input wire [OPCODE_WIDTH-1:0]      tx_req_opcode_i,
    input wire [MATCH_TYPE_WIDTH-1:0]  tx_req_match_type_i,
    input wire [NODE_ID_WIDTH-1:0]     tx_req_source_id_i,
    input wire [NODE_ID_WIDTH-1:0]     tx_req_target_id_i,
    input wire [ADDR_WIDTH-1:0]        tx_req_addr_i,
    input wire [DATA_WIDTH-1:0]        tx_req_data_i,

    // 接受请求
    output wire                        rx_req_valid_o,
    output wire                        rx_req_is_order_o,
    output wire [OPCODE_WIDTH-1:0]     rx_req_opcode_o,
    output wire [MATCH_TYPE_WIDTH-1:0] rx_req_match_type_o,
    output wire [NODE_ID_WIDTH-1:0]    rx_req_source_id_o,
    output wire [NODE_ID_WIDTH-1:0]    rx_req_target_id_o,
    output wire [ADDR_WIDTH-1:0]       rx_req_addr_o,
    output wire [DATA_WIDTH-1:0]       rx_req_data_o,

    // 接收响应
    output wire                        rsp_valid_o,
    output wire [NODE_ID_WIDTH-1:0]    rsp_source_id_o,
    output wire [NODE_ID_WIDTH-1:0]    rsp_target_id_o,
    output wire [ADDR_WIDTH-1:0]       rsp_addr_o,
    output wire [DATA_WIDTH-1:0]       rsp_data_o
);

    // 根据CPU类型选择不同的实现
    generate
        if (CPU_TYPE == 0) begin : riscv_implementation
            // RISC-V实现
            // 创建内部wire信号用于连接riscv_system的output端口
            wire [NUM_RINGS-1:0]         riscv_tx_req_ring_mask;
            wire [NUM_RINGS-1:0]         riscv_tx_req_ring_disable;
            wire                         riscv_tx_req_valid;
            wire                         riscv_tx_req_is_order;
            wire [OPCODE_WIDTH-1:0]      riscv_tx_req_opcode;
            wire [MATCH_TYPE_WIDTH-1:0]  riscv_tx_req_match_type;
            wire [NODE_ID_WIDTH-1:0]     riscv_tx_req_source_id;
            wire [NODE_ID_WIDTH-1:0]     riscv_tx_req_target_id;
            wire [ADDR_WIDTH-1:0]        riscv_tx_req_addr;
            wire [DATA_WIDTH-1:0]        riscv_tx_req_data;

            // 为解决端口方向冲突，使用assign语句连接信号
            assign riscv_tx_req_ring_mask = 0;
            assign riscv_tx_req_ring_disable = 0;
            assign riscv_tx_req_valid = 0;
            assign riscv_tx_req_is_order = 0;
            assign riscv_tx_req_opcode = 0;
            assign riscv_tx_req_match_type = 0;
            assign riscv_tx_req_source_id = NODE_ID;
            assign riscv_tx_req_target_id = tx_req_target_id_i;
            assign riscv_tx_req_addr = tx_req_addr_i;
            assign riscv_tx_req_data = tx_req_data_i;

            riscv_system #(
                .NUM_RINGS(NUM_RINGS),
                .ADDR_WIDTH(ADDR_WIDTH),
                .DATA_WIDTH(DATA_WIDTH),
                .NODE_ID_WIDTH(NODE_ID_WIDTH),
                .NODE_ID(NODE_ID),
                .OPCODE_WIDTH(OPCODE_WIDTH),
                .MATCH_TYPE_WIDTH(MATCH_TYPE_WIDTH),
                .INST_WIDTH(INST_WIDTH)
            ) riscv (
                .clk(clk),
                .rst_n(rst_n),

                .ext_int(ext_int),

                // 发送请求
                .tx_req_ring_mask_i(riscv_tx_req_ring_mask),
                .tx_req_ring_disable_i(riscv_tx_req_ring_disable),
                .tx_req_valid_i(riscv_tx_req_valid),
                .tx_req_is_order_i(riscv_tx_req_is_order),
                .tx_req_opcode_i(riscv_tx_req_opcode),
                .tx_req_match_type_i(riscv_tx_req_match_type),
                .tx_req_source_id_i(riscv_tx_req_source_id),
                .tx_req_target_id_i(riscv_tx_req_target_id),
                .tx_req_addr_i(riscv_tx_req_addr),
                .tx_req_data_i(riscv_tx_req_data),

                // 接受请求
                .rx_req_valid_o(rx_req_valid_o),
                .rx_req_is_order_o(rx_req_is_order_o),
                .rx_req_opcode_o(rx_req_opcode_o),
                .rx_req_match_type_o(rx_req_match_type_o),
                .rx_req_source_id_o(rx_req_source_id_o),
                .rx_req_target_id_o(rx_req_target_id_o),
                .rx_req_addr_o(rx_req_addr_o),
                .rx_req_data_o(rx_req_data_o),

                // 接收响应
                .rsp_valid_o(rsp_valid_o),
                .rsp_source_id_o(rsp_source_id_o),
                .rsp_target_id_o(rsp_target_id_o),
                .rsp_addr_o(rsp_addr_o),
                .rsp_data_o(rsp_data_o)
            );
        end
        // 预留其他CPU类型的实现
        else if (CPU_TYPE == 1) begin : other_cpu_implementation
            // 其他CPU类型的实现可以在这里添加
            // 当前只是占位，实际实现需要根据具体的CPU架构来编写
            assign rx_req_valid_o = 1'b0;
            assign rx_req_is_order_o = 1'b0;
            assign rx_req_opcode_o = {OPCODE_WIDTH{1'b0}};
            assign rx_req_match_type_o = {MATCH_TYPE_WIDTH{1'b0}};
            assign rx_req_source_id_o = {NODE_ID_WIDTH{1'b0}};
            assign rx_req_target_id_o = {NODE_ID_WIDTH{1'b0}};
            assign rx_req_addr_o = {ADDR_WIDTH{1'b0}};
            assign rx_req_data_o = {DATA_WIDTH{1'b0}};
            assign rsp_valid_o = 1'b0;
            assign rsp_source_id_o = {NODE_ID_WIDTH{1'b0}};
            assign rsp_target_id_o = {NODE_ID_WIDTH{1'b0}};
            assign rsp_addr_o = {ADDR_WIDTH{1'b0}};
            assign rsp_data_o = {DATA_WIDTH{1'b0}};
        end
    endgenerate

    // CPU配置和状态寄存器
    reg [31:0] cpu_config_reg;
    reg [31:0] cpu_status_reg;
    reg [31:0] cpu_version_reg;

    // 初始化版本和配置信息
    initial begin
        cpu_version_reg = 32'h00010000;  // 版本号: 1.0.0
        cpu_config_reg = {28'b0, CPU_TYPE};  // 配置信息，低4位表示CPU类型
    end

    // 监控CPU状态
    always @(posedge clk) begin
        if (!rst_n) begin
            cpu_status_reg <= 32'h0;
        end else begin
            // 可以在这里添加CPU状态监控逻辑
            // 例如：检测中断、异常等
            cpu_status_reg <= {30'b0, ext_int, 1'b1};
        end
    end

endmodule