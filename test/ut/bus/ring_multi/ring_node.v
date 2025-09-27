module ring_node #(
    parameter NODE_ID       = 0,
    parameter ADDR_WIDTH    = 32,
    parameter DATA_WIDTH    = 64,
    parameter NODE_ID_WIDTH = 8
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // 上游接口
    input  wire                         up_req_valid_i,
    output wire                         up_req_ready_o,
    input  wire [ADDR_WIDTH-1:0]        up_req_addr_i,
    input  wire [DATA_WIDTH-1:0]        up_req_data_i,
    input  wire                         up_req_wr_i,
    input  wire [NODE_ID_WIDTH-1:0]     up_req_dest_i,

    // 下游接口
    output wire                         dn_req_valid_o,
    input  wire                         dn_req_ready_i,
    output wire [ADDR_WIDTH-1:0]        dn_req_addr_o,
    output wire [DATA_WIDTH-1:0]        dn_req_data_o,
    output wire                         dn_req_wr_o,
    output wire [NODE_ID_WIDTH-1:0]     dn_req_dest_o,

    // 响应接口
    output wire                         resp_valid_o,
    input  wire                         resp_ready_i,
    output wire [DATA_WIDTH-1:0]        resp_data_o,
    output wire                         resp_error_o
);

    // 本地匹配判断
    wire is_local = (up_req_dest_i == NODE_ID);
    reg resp_valid;

    // 流控
    assign up_req_ready_o = dn_req_ready_i;
    assign dn_req_valid_o = up_req_valid_i;
    assign dn_req_addr_o = up_req_addr_i;
    assign dn_req_data_o = up_req_data_i;
    assign dn_req_wr_o = up_req_wr_i;
    assign dn_req_dest_o = up_req_dest_i;

    // 本地处理
    reg processing;
    reg [DATA_WIDTH-1:0] response_data;
    reg response_error;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            processing <= 1'b0;
            resp_valid <= 1'b0;
        end else begin
            if (up_req_valid_i && is_local && !processing) begin
                processing <= 1'b1;
                // 模拟处理延迟
                response_data <= up_req_wr_i ?
                    {up_req_data_i[DATA_WIDTH-1:32], 32'hACCE_55ED} :
                    {up_req_addr_i, 32'h1234_5678};
                response_error <= 1'b0;
            end else if (processing) begin
                resp_valid <= 1'b1;
                if (resp_ready_i && resp_valid_o) begin
                    processing <= 1'b0;
                    resp_valid <= 1'b0;
                end
            end
        end
    end

    assign resp_valid_o = resp_valid;
    assign resp_data_o = response_data;
    assign resp_error_o = response_error;

endmodule
