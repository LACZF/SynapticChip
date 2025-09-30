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
    parameter RX_FIFO_DEPTH     = 4         // 接收FIFO深度
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

    output wire                         next_req_valid_i,
    output wire                         next_req_is_order_i,
    output wire [OPCODE_WIDTH-1:0]      next_req_opcode_i,
    output wire [MATCH_TYPE_WIDTH-1:0]  next_req_match_type_i,
    output wire [NODE_ID_WIDTH-1:0]     next_req_source_id_i,
    output wire [NODE_ID_WIDTH-1:0]     next_req_target_id_i,
    output wire [ADDR_WIDTH-1:0]        next_req_addr_i,
    output wire [DATA_WIDTH-1:0]        next_req_data_i,

    // 发送请求
    input  wire                         tx_req_valid_i,
    input  wire                         tx_req_is_order_i,
    input  wire [OPCODE_WIDTH-1:0]      tx_req_opcode_i,
    input  wire [MATCH_TYPE_WIDTH-1:0]  tx_req_match_type_i,
    input  wire [NODE_ID_WIDTH-1:0]     tx_req_source_id_i, // 待审视后删除
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
    reg [NODE_ID_WIDTH-1:0] node_id = NODE_ID;

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

    reg                         rx_req_rd_en;
    reg                         rx_req_rd_done;
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

    reg                         rsp_valid,
    reg [NODE_ID_WIDTH-1:0]     rsp_source_id,
    reg [NODE_ID_WIDTH-1:0]     rsp_target_id,
    reg [ADDR_WIDTH-1:0]        rsp_addr,
    reg [DATA_WIDTH-1:0]        rsp_data,

    wire is_for_me;
    assign is_for_me = (pre_req_match_type_i == `RING_MATCH_TYPE_ID) ?
        (pre_req_target_id_i == node_id) :
        (node_start_addr <= pre_req_addr_i && pre_req_addr_i <= node_end_addr);

    /* 目的不是本节点的，转发到下一个节点 */
    always @(posedge clk or negedge rst_n) begin
        if (pre_req_valid_i && rsp_source_id == node_id) begin
            /*
             * TODO : 异常处理，源节点ID与本节点ID相同：
             * 1. 发送到时候指定源节点ID或目的节点错误；
             * 2. ring总线上所有节点均未匹配，换回到了起始的节点
             */
        end else if (!is_for_me && pre_req_valid_i) begin
            next_req_valid_i <= pre_req_valid_i;
            next_req_is_order_i <= pre_req_is_order_i;
            next_req_opcode_i <= pre_req_opcode_i;
            next_req_match_type_i <= pre_req_match_type_i;
            next_req_source_id_i <= pre_req_source_id_i;
            next_req_target_id_i <= pre_req_target_id_i;
            next_req_addr_i <= pre_req_addr_i;
            next_req_data_i <= pre_req_data_i;
        end
    end

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
        .rd_done(tx_req_rd_done);
        .data_out({tx_req_valid, tx_req_is_order, tx_req_opcode, tx_req_match_type, tx_req_source_id, tx_req_target_id, tx_req_addr, tx_req_data}),
        .full(tx_fifo_full),
        .empty(tx_fifo_empty)
    );

    simple_fifo #(
        .DATA_WIDTH(tx_fifo_data_width),
        .FIFO_DEPTH(TX_FIFO_DEPTH)
    ) rx_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(is_for_me && pre_req_valid_i),
        .data_in({pre_req_valid_i, pre_req_is_order_i, pre_req_opcode_i, pre_req_match_type_i, pre_req_source_id_i, pre_req_target_id_i, pre_req_addr_i, pre_req_data_i}),
        .rd_en(rx_req_rd_en),
        .rd_done(rx_req_rd_done);
        .data_out({rx_req_valid, rx_req_is_order, rx_req_opcode, rx_req_match_type, rx_req_source_id, rx_req_target_id, rx_req_addr, rx_req_data}),
        .full(rx_fifo_full),
        .empty(rx_fifo_empty)
    );

    reg [1:0] tx_state;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_state <= IDLE;
            tx_req_rd_en <= 0;
            tx_req_rd_done <= 0;
        end else begin
            case (tx_state)
                IDLE:
                    tx_req_rd_en <= 1;
                    if (tx_req_rd_done) begin
                        tx_req_rd_en <= 0;
                        tx_state <= PROCESS;
                    end
                PROCESS:
                    if (tx_req_rd_done) begin
                        /* TODO */
                        tx_state <= RESPOND;
                    end
                RESPOND:
                    tx_state <= IDLE;
            endcase
        end
    end

    reg [1:0] rx_state;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_state <= IDLE;
            rx_req_rd_en <= 0;
            rx_req_rd_done <= 0;
            rsp_valid = 0;
            rsp_source_id = 0;
            rsp_target_id = 0;
            rsp_addr = 0;
            rsp_data = 0;
        end else begin
            case (rx_state)
                IDLE:
                    rsp_valid <= 1`b0;
                    rx_req_rd_en <= 1`b1;
                    if (rx_req_rd_done) begin
                        rx_req_rd_en <= 1`b0;
                        rx_state <= PROCESS;
                    end
                PROCESS:
                    if (rx_req_rd_done) begin
                        if (rx_req_opcode == RING_OP_RESP) {
                            rsp_valid <= 1`b1;
                            rsp_source_id <= rx_req_source_id;
                            rsp_target_id <= rx_req_target_id;
                            rsp_addr <= rx_req_addr;
                            rsp_data <= rx_req_data;
                            rx_state <= RESPOND;
                        } else {
                            /* Do nothing. */
                        }
                    end
                RESPOND:
                    rx_state <= IDLE;
            endcase
        end
    end

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

endmodule
