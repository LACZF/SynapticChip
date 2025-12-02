module ip4_fifo #(
    parameter DATA_WIDTH                = 32,
    parameter FIFO_DEPTH                = 8
)(
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         wr_en_i,
    input  wire [DATA_WIDTH-1:0]        data_in_i,
    input  wire                         rd_en_i,
    output wire                         rd_done_o,
    output wire [DATA_WIDTH-1:0]        data_out_o,
    output wire                         full_o,
    output wire                         empty_o
);

    reg [DATA_WIDTH-1:0] fifo [FIFO_DEPTH-1:0];
    reg [$clog2(FIFO_DEPTH)-1:0] wr_ptr;
    reg [$clog2(FIFO_DEPTH)-1:0] rd_ptr;

    reg [$clog2(FIFO_DEPTH+1)-1:0] count;

    // 内部寄存器用于存储输出信号
    reg                            rd_done_reg;
    reg [DATA_WIDTH-1:0]           data_out_reg;
    reg                            full_reg;
    reg                            empty_reg;

    // 连接内部寄存器到输出端口
    assign rd_done_o  = rd_done_reg;
    assign data_out_o = data_out_reg;
    assign full_o     = full_reg;
    assign empty_o    = empty_reg;

    // FIFO write logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr <= 0;
            // 复位FIFO数组
            for (integer i = 0; i < FIFO_DEPTH; i = i + 1) begin
                fifo[i] <= {DATA_WIDTH{1'b0}};
            end
        end else if (wr_en_i && !full_o) begin
            fifo[wr_ptr] <= data_in_i;
            wr_ptr       <= (wr_ptr + 1) % FIFO_DEPTH;
        end
    end

    // FIFO read logic - 零延迟读取设计
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr <= 0;
            rd_done_reg <= 0;
        end else if (rd_en_i && !empty_reg) begin
            rd_ptr <= (rd_ptr + 1) % FIFO_DEPTH;
            rd_done_reg <= 1;
        end else begin
            rd_done_reg <= 0;
        end
    end

    // 零延迟数据输出：直接从FIFO数组读取，无需等待下一拍
    always @(*) begin
        if (empty_reg) begin
            data_out_reg = {DATA_WIDTH{1'b0}};
        end else begin
            data_out_reg = fifo[rd_ptr];
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 0;
        end else begin
            if (wr_en_i && !full_o) begin
                if (rd_en_i && (count > 0)) begin
                    count <= count;
                end else begin
                    count <= count + 1;
                end
            end else if (rd_en_i && (count > 0)) begin
                count <= count - 1;
            end else begin
                count <= count;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            full_reg  <= 0;
            empty_reg <= 1;
        end else begin
            full_reg  <= (count == FIFO_DEPTH);
            empty_reg <= (count == 0);
        end
    end

endmodule