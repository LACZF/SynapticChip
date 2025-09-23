// flash.v
module flash (
    input wire clk,
    input wire rst_n,

    // 存储器接口
    input wire [31:0] addr,
    input wire [31:0] data_in,
    output reg [31:0] data_out,
    input wire we,
    input wire req,
    output reg ack
);

    // Flash参数
    parameter SIZE = 16777216;  // 16MB
    parameter ADDR_WIDTH = 24;
    parameter ERASE_TIME = 10;  // 擦除周期数
    parameter WRITE_TIME = 5;   // 写入周期数

    // Flash存储体
    reg [31:0] memory [0:SIZE/4-1];
    reg [31:0] erase_buffer [0:255];  // 擦除块缓冲区

    // 内部信号
    reg [ADDR_WIDTH-1:0] word_addr;
    reg [ADDR_WIDTH-1:0] block_addr;
    reg ack_delay;
    reg [3:0] write_timer;
    reg [3:0] erase_timer;
    reg writing;
    reg erasing;

    // 地址计算
    assign word_addr = addr[ADDR_WIDTH-1:2];
    assign block_addr = word_addr[ADDR_WIDTH-1:8];  // 256字块

    // 状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 32'h0;
            ack <= 1'b0;
            ack_delay <= 1'b0;
            write_timer <= 4'h0;
            erase_timer <= 4'h0;
            writing <= 1'b0;
            erasing <= 1'b0;
        end else begin
            // 读操作（立即响应）
            if (req && !we && !writing && !erasing) begin
                data_out <= memory[word_addr];
                ack_delay <= 1'b1;
            end
            // 写操作（需要时间）
            else if (req && we && !writing && !erasing) begin
                writing <= 1'b1;
                write_timer <= WRITE_TIME;
                // 检查是否需要先擦除（简化：总是擦除）
                erasing <= 1'b1;
                erase_timer <= ERASE_TIME;
            end
            // 擦除计时
            else if (erasing) begin
                if (erase_timer > 0) begin
                    erase_timer <= erase_timer - 1;
                end else begin
                    erasing <= 1'b0;
                    // 擦除完成，开始写入
                end
            end
            // 写入计时
            else if (writing) begin
                if (write_timer > 0) begin
                    write_timer <= write_timer - 1;
                end else begin
                    // 写入完成
                    memory[word_addr] <= data_in;
                    writing <= 1'b0;
                    ack_delay <= 1'b1;
                end
            end else begin
                ack_delay <= 1'b0;
            end

            ack <= ack_delay;
        end
    end

    // 初始化Flash内容
    initial begin
        // 初始化一些测试数据
        memory[0] = 32'h00000013;  // nop
        memory[1] = 32'h00000013;  // nop
        memory[2] = 32'h00000013;  // nop
        memory[100] = 32'hdeadbeef;  // 测试数据
    end

endmodule
