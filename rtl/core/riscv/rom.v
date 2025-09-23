// rom.v
module rom (
    input wire clk,
    input wire rst_n,

    // 存储器接口
    input wire [31:0] addr,
    output reg [31:0] data_out,
    input wire req,
    output reg ack
);

    // ROM参数
    parameter SIZE = 1048576;  // 1MB
    parameter ADDR_WIDTH = 20;

    // ROM存储体
    reg [31:0] memory [0:SIZE/4-1];

    // 内部信号
    wire [ADDR_WIDTH-1:0] word_addr;
    reg ack_delay;

    // 地址计算
    assign word_addr = addr[ADDR_WIDTH-1:2];

    // 读操作
    always @(posedge clk) begin
        if (req) begin
            data_out <= memory[word_addr];
            ack_delay <= 1'b1;
        end else begin
            ack_delay <= 1'b0;
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

    // 初始化ROM内容
    initial begin
        // 简单的测试程序
        memory[0] = 32'h00000293;  // addi x5, x0, 0
        memory[1] = 32'h00100313;  // addi x6, x0, 1
        memory[2] = 32'h00a00413;  // addi x8, x0, 10
        memory[3] = 32'h00000493;  // addi x9, x0, 0
        memory[4] = 32'h00532023;  // sw x5, 0(x6)
        memory[5] = 32'h0062a223;  // sw x6, 4(x5)
        memory[6] = 32'h00530333;  // add x6, x6, x5
        memory[7] = 32'h406282b3;  // sub x5, x5, x6
        memory[8] = 32'h00148493;  // addi x9, x9, 1
        memory[9] = 32'h00940863;  // beq x8, x9, 16
        memory[10] = 32'hff5ff06f; // jal x0, -12
        memory[11] = 32'h00000073; // ecall
    end

endmodule
