// ram.v
module ram (
    input wire clk,
    input wire rst_n,

    // 存储器接口
    input wire [31:0] addr,
    input wire [31:0] data_in,
    output reg [31:0] data_out,
    input wire we,
    input wire [3:0] sel,
    input wire req,
    output reg ack
);

    // RAM参数
    parameter SIZE = 65536;  // 64KB
    parameter ADDR_WIDTH = 16;

    // RAM存储体
    reg [7:0] memory_0 [0:SIZE/4-1];  // 字节0
    reg [7:0] memory_1 [0:SIZE/4-1];  // 字节1
    reg [7:0] memory_2 [0:SIZE/4-1];  // 字节2
    reg [7:0] memory_3 [0:SIZE/4-1];  // 字节3

    // 内部信号
    reg [ADDR_WIDTH-1:0] word_addr;
    reg ack_delay;

    // 地址计算（字地址）
    assign word_addr = addr[ADDR_WIDTH-1:2];

    // 读操作
    always @(posedge clk) begin
        if (req && !we) begin
            data_out[7:0]   <= memory_0[word_addr];
            data_out[15:8]  <= memory_1[word_addr];
            data_out[23:16] <= memory_2[word_addr];
            data_out[31:24] <= memory_3[word_addr];
            ack_delay <= 1'b1;
        end else begin
            ack_delay <= 1'b0;
        end
    end

    // 写操作
    always @(posedge clk) begin
        if (req && we) begin
            if (sel[0]) memory_0[word_addr] <= data_in[7:0];
            if (sel[1]) memory_1[word_addr] <= data_in[15:8];
            if (sel[2]) memory_2[word_addr] <= data_in[23:16];
            if (sel[3]) memory_3[word_addr] <= data_in[31:24];
            ack_delay <= 1'b1;
        end
    end

    // 响应信号
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ack <= 1'b0;
        end else begin
            ack <= ack_delay;
        end
    end

    // 初始化RAM内容
    initial begin
        // 初始化一些测试数据
        memory_0[0] = 8'h93;  // ADDI x1, x0, 1
        memory_1[0] = 8'h00;
        memory_2[0] = 8'h01;
        memory_3[0] = 8'h00;

        memory_0[1] = 8'h13;  // ADDI x2, x0, 2
        memory_1[1] = 8'h01;
        memory_2[1] = 8'h02;
        memory_3[1] = 8'h00;

        memory_0[2] = 8'h33;  // ADD x3, x1, x2
        memory_1[2] = 8'h82;
        memory_2[2] = 8'h00;
        memory_3[2] = 8'h00;
    end

endmodule
