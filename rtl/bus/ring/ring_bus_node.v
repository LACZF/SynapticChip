`include "ring_bus_params.v"

module ring_bus_node #(
    parameter NUM_RINGS         = 2,        // Ring总线数量
    parameter ADDR_WIDTH        = 32,       // 地址宽度
    parameter DATA_WIDTH        = 64,       // 数据宽度
    parameter NODE_ID_WIDTH     = 8,        // 节点ID宽度
    parameter NODE_ID           = 0,        // 节点ID
    parameter OPCODE_WIDTH      = 8,        // 操作类型的宽带：read/write/reponse等
    parameter MATCH_TYPE_WIDTH  = 2,        // 匹配类型宽度
    parameter TX_FIFO_DEPTH     = 4,        // 发送FIFO深度
    parameter RX_FIFO_DEPTH     = 4,        // 接收FIFO深度
    parameter RSP_FIFO_DEPTH    = 4         // 响应FIFO深度
) (
    input  wire                         clk,
    input  wire                         rst_n,

    input  wire [ADDR_WIDTH-1:0]        node_start_addr_i,
    input  wire [ADDR_WIDTH-1:0]        node_end_addr_i,

    input  wire                         pre_req_valid_i,
    input  wire                         pre_req_is_order_i,
    input  wire [OPCODE_WIDTH-1:0]      pre_req_opcode_i,
    input  wire [MATCH_TYPE_WIDTH-1:0]  pre_req_match_type_i,
    input  wire [NODE_ID_WIDTH-1:0]     pre_req_source_id_i,
    input  wire [NODE_ID_WIDTH-1:0]     pre_req_target_id_i,
    input  wire [ADDR_WIDTH-1:0]        pre_req_addr_i,
    input  wire [DATA_WIDTH-1:0]        pre_req_data_i,

    output wire                         next_req_valid_o,
    output wire                         next_req_is_order_o,
    output wire [OPCODE_WIDTH-1:0]      next_req_opcode_o,
    output wire [MATCH_TYPE_WIDTH-1:0]  next_req_match_type_o,
    output wire [NODE_ID_WIDTH-1:0]     next_req_source_id_o,
    output wire [NODE_ID_WIDTH-1:0]     next_req_target_id_o,
    output wire [ADDR_WIDTH-1:0]        next_req_addr_o,
    output wire [DATA_WIDTH-1:0]        next_req_data_o,

    // 发送请求
    input  wire                         tx_req_valid_i,
    input  wire                         tx_req_is_order_i,
    input  wire [OPCODE_WIDTH-1:0]      tx_req_opcode_i,
    input  wire [MATCH_TYPE_WIDTH-1:0]  tx_req_match_type_i,
    input  wire [NODE_ID_WIDTH-1:0]     tx_req_target_id_i,
    input  wire [ADDR_WIDTH-1:0]        tx_req_addr_i,
    input  wire [DATA_WIDTH-1:0]        tx_req_data_i,

    // 接受请求
    output wire                         rx_req_valid_o,
    output wire                         rx_req_is_order_o,
    output wire [OPCODE_WIDTH-1:0]      rx_req_opcode_o,
    output wire [MATCH_TYPE_WIDTH-1:0]  rx_req_match_type_o,
    output wire [NODE_ID_WIDTH-1:0]     rx_req_source_id_o,
    output wire [NODE_ID_WIDTH-1:0]     rx_req_target_id_o,
    output wire [ADDR_WIDTH-1:0]        rx_req_addr_o,
    output wire [DATA_WIDTH-1:0]        rx_req_data_o,

    // 接收响应
    output wire                         rsp_valid_o,
    output wire [NODE_ID_WIDTH-1:0]     rsp_source_id_o,
    output wire [NODE_ID_WIDTH-1:0]     rsp_target_id_o,
    output wire [ADDR_WIDTH-1:0]        rsp_addr_o,
    output wire [DATA_WIDTH-1:0]        rsp_data_o
);
    localparam IDLE = 2'b00;
    localparam PROCESS = 2'b01;
    localparam RESPOND = 2'b10;

    localparam tx_fifo_data_width = OPCODE_WIDTH + MATCH_TYPE_WIDTH + NODE_ID_WIDTH + NODE_ID_WIDTH + ADDR_WIDTH + DATA_WIDTH + 1 + 1;
    localparam rx_fifo_data_width = OPCODE_WIDTH + MATCH_TYPE_WIDTH + NODE_ID_WIDTH + NODE_ID_WIDTH + ADDR_WIDTH + DATA_WIDTH + 1 + 1;
    localparam rsp_fifo_data_width = NODE_ID_WIDTH + NODE_ID_WIDTH + ADDR_WIDTH + DATA_WIDTH;
    reg [NODE_ID_WIDTH-1:0] node_id = NODE_ID;

    // 发送FIFO信号
    reg                         tx_req_rd_en;
    reg                         tx_req_rd_done;
    reg                         tx_fifo_full;
    reg                         tx_fifo_empty;
    reg                         tx_req_valid;
    reg                         tx_req_is_order;
    reg [OPCODE_WIDTH-1:0]      tx_req_opcode;
    reg [MATCH_TYPE_WIDTH-1:0]  tx_req_match_type;
    reg [NODE_ID_WIDTH-1:0]     tx_req_source_id;
    reg [NODE_ID_WIDTH-1:0]     tx_req_target_id;
    reg [ADDR_WIDTH-1:0]        tx_req_addr;
    reg [DATA_WIDTH-1:0]        tx_req_data;

    // 接收FIFO信号
    reg                         rx_req_rd_en;
    wire                        rx_req_rd_done;
    reg                         rx_fifo_full;
    reg                         rx_fifo_empty;
    reg                         rx_req_valid;
    reg                         rx_req_is_order;
    reg [OPCODE_WIDTH-1:0]      rx_req_opcode;
    reg [MATCH_TYPE_WIDTH-1:0]  rx_req_match_type;
    reg [NODE_ID_WIDTH-1:0]     rx_req_source_id;
    reg [NODE_ID_WIDTH-1:0]     rx_req_target_id;
    reg [ADDR_WIDTH-1:0]        rx_req_addr;
    reg [DATA_WIDTH-1:0]        rx_req_data;

    // 响应FIFO信号
    reg                         rsp_rd_en;
    wire                        rsp_rd_done;
    wire                        rsp_fifo_full;
    wire                        rsp_fifo_empty;
    reg                         rsp_valid;
    reg [NODE_ID_WIDTH-1:0]     rsp_source_id;
    reg [NODE_ID_WIDTH-1:0]     rsp_target_id;
    reg [ADDR_WIDTH-1:0]        rsp_addr;
    reg [DATA_WIDTH-1:0]        rsp_data;
    wire [NODE_ID_WIDTH-1:0]    rsp_source_id_fifo;
    wire [NODE_ID_WIDTH-1:0]    rsp_target_id_fifo;
    wire [ADDR_WIDTH-1:0]       rsp_addr_fifo;
    wire [DATA_WIDTH-1:0]       rsp_data_fifo; // 中间wire变量，连接FIFO输出

    // 目标匹配逻辑
    wire is_for_me;
    assign is_for_me = ((pre_req_match_type_i == `RING_MATCH_TYPE_ID) || (pre_req_opcode_i == `RING_OP_RESP)) ?
        (pre_req_target_id_i == node_id) :
        (node_start_addr_i <= pre_req_addr_i && pre_req_addr_i <= node_end_addr_i);

    // 新增：用于转发请求的内部寄存器
    reg                         next_req_valid;
    reg                         next_req_is_order;
    reg [OPCODE_WIDTH-1:0]      next_req_opcode;
    reg [MATCH_TYPE_WIDTH-1:0]  next_req_match_type;
    reg [NODE_ID_WIDTH-1:0]     next_req_source_id;
    reg [NODE_ID_WIDTH-1:0]     next_req_target_id;
    reg [ADDR_WIDTH-1:0]        next_req_addr;
    reg [DATA_WIDTH-1:0]        next_req_data;

    /* 目的不是本节点的，转发到下一个节点 */
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            next_req_valid <= 1'b0;
            next_req_is_order <= 1'b0;
            next_req_opcode <= 0;
            next_req_match_type <= 0;
            next_req_source_id <= 0;
            next_req_target_id <= 0;
            next_req_addr <= 0;
            next_req_data <= 0;
        end else if (pre_req_valid_i && pre_req_source_id_i == node_id) begin
            // 异常处理：请求回到了源节点，说明没有节点匹配
            next_req_valid <= 1'b0;
        end else if (!is_for_me && pre_req_valid_i) begin
            // 转发请求
            next_req_valid <= pre_req_valid_i;
            next_req_is_order <= pre_req_is_order_i;
            next_req_opcode <= pre_req_opcode_i;
            next_req_match_type <= pre_req_match_type_i;
            next_req_source_id <= pre_req_source_id_i;
            next_req_target_id <= pre_req_target_id_i;
            next_req_addr <= pre_req_addr_i;
            next_req_data <= pre_req_data_i;
        end else begin
            next_req_valid <= 1'b0;
        end
    end

    // 发送FIFO实例化
    simple_fifo #(
        .DATA_WIDTH(tx_fifo_data_width),
        .FIFO_DEPTH(TX_FIFO_DEPTH)
    ) tx_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(tx_req_valid_i),
        /* TX时本节点即为源节点 */
        .data_in({tx_req_valid_i, tx_req_is_order_i, tx_req_opcode_i, tx_req_match_type_i, node_id, tx_req_target_id_i, tx_req_addr_i, tx_req_data_i}),
        .rd_en(tx_req_rd_en),
        .rd_done(tx_req_rd_done),
        .data_out({tx_req_valid, tx_req_is_order, tx_req_opcode, tx_req_match_type, tx_req_source_id, tx_req_target_id, tx_req_addr, tx_req_data}),
        .full(tx_fifo_full),
        .empty(tx_fifo_empty)
    );

    // 接收FIFO实例化 - 用于rx方向的接收缓存
    simple_fifo #(
        .DATA_WIDTH(rx_fifo_data_width),
        .FIFO_DEPTH(RX_FIFO_DEPTH)
    ) rx_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(is_for_me && pre_req_valid_i),
        .data_in({pre_req_valid_i, pre_req_is_order_i, pre_req_opcode_i, pre_req_match_type_i, pre_req_source_id_i, pre_req_target_id_i, pre_req_addr_i, pre_req_data_i}),
        .rd_en(rx_req_rd_en),
        .rd_done(rx_req_rd_done),
        .data_out({rx_req_valid, rx_req_is_order, rx_req_opcode, rx_req_match_type, rx_req_source_id, rx_req_target_id, rx_req_addr, rx_req_data}),
        .full(rx_fifo_full),
        .empty(rx_fifo_empty)
    );

    // 响应FIFO实例化 - 用于rsp的接收缓存
    simple_fifo #(
        .DATA_WIDTH(rsp_fifo_data_width),
        .FIFO_DEPTH(RSP_FIFO_DEPTH)
    ) rsp_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en((rx_req_opcode == `RING_OP_READ || rx_req_opcode == `RING_OP_WRITE) && rx_req_valid),
        .data_in({node_id, rx_req_source_id, rx_req_addr, rx_req_data}),
        .rd_en(rsp_rd_en),
        .rd_done(rsp_rd_done),
        .data_out({rsp_source_id_fifo, rsp_target_id_fifo, rsp_addr_fifo, rsp_data_fifo}),
        .full(rsp_fifo_full),
        .empty(rsp_fifo_empty)
    );

    // 发送状态机
    reg [1:0] tx_state;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state <= IDLE;
            tx_req_rd_en <= 0;
        end else begin
            case (tx_state)
                IDLE: begin
                    if (!tx_fifo_empty) begin
                        tx_req_rd_en <= 1;
                        tx_state <= PROCESS;
                    end
                end
                PROCESS: begin
                    if (tx_req_rd_done) begin
                        tx_req_rd_en <= 0;
                        tx_state <= RESPOND;
                    end
                end
                RESPOND: begin
                    // 清除请求信号
                    tx_state <= IDLE;
                end
            endcase
        end
    end

    // 接收状态机
    reg [1:0] rx_state;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state <= IDLE;
            rx_req_rd_en <= 0;
            rsp_valid <= 1'b0;
        end else begin
            case (rx_state)
                IDLE: begin
                    rsp_valid <= 1'b0;
                    if (!rx_fifo_empty) begin
                        rx_req_rd_en <= 1;
                        rx_state <= PROCESS;
                    end
                end
                PROCESS: begin
                    if (rx_req_rd_done) begin
                        rx_req_rd_en <= 0;
                        // 处理请求
                        if (rx_req_opcode == `RING_OP_RESP) begin
                            // 直接输出响应
                            rsp_valid <= 1'b1;
                            rsp_source_id <= rx_req_source_id;
                            rsp_target_id <= rx_req_target_id;
                            rsp_addr <= rx_req_addr;
                            rsp_data <= rx_req_data;
                            rx_state <= RESPOND;
                        end else begin
                            // 写入响应FIFO等待处理
                            rx_state <= IDLE;
                        end
                    end
                end
                RESPOND: begin
                    rsp_valid <= 1'b0;
                    rx_state <= IDLE;
                end
            endcase
        end
    end

    // 响应处理状态机
    reg [1:0] rsp_state;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rsp_state <= IDLE;
            rsp_rd_en <= 0;
        end else begin
            case (rsp_state)
                IDLE: begin
                    if (!rsp_fifo_empty) begin
                        rsp_rd_en <= 1;
                        rsp_state <= PROCESS;
                    end
                end
                PROCESS: begin
                    if (rsp_rd_done) begin
                        rsp_rd_en <= 0;
                        // 处理响应
                        rsp_valid <= 1'b1;
                        rsp_source_id <= rsp_source_id_fifo;
                        rsp_target_id <= rsp_target_id_fifo;
                        rsp_addr <= rsp_addr_fifo;
                        rsp_data <= rsp_data_fifo;
                        rsp_state <= RESPOND;
                    end
                end
                RESPOND: begin
                    rsp_valid <= 1'b0;
                    rsp_state <= IDLE;
                end
            endcase
        end
    end

    // 输出信号赋值
    assign rsp_valid_o = rsp_valid;
    assign rsp_source_id_o = rsp_source_id;
    assign rsp_target_id_o = rsp_target_id;
    assign rsp_addr_o = rsp_addr;
    assign rsp_data_o = rsp_data;

    assign rx_req_valid_o = rx_req_valid;
    assign rx_req_is_order_o = rx_req_is_order;
    assign rx_req_opcode_o = rx_req_opcode;
    assign rx_req_match_type_o = rx_req_match_type;
    assign rx_req_source_id_o = rx_req_source_id;
    assign rx_req_target_id_o = rx_req_target_id;
    assign rx_req_addr_o = rx_req_addr;
    assign rx_req_data_o = rx_req_data;

    // 转发请求输出赋值
    assign next_req_valid_o = next_req_valid;
    assign next_req_is_order_o = next_req_is_order;
    assign next_req_opcode_o = next_req_opcode;
    assign next_req_match_type_o = next_req_match_type;
    assign next_req_source_id_o = next_req_source_id;
    assign next_req_target_id_o = next_req_target_id;
    assign next_req_addr_o = next_req_addr;
    assign next_req_data_o = next_req_data;

endmodule