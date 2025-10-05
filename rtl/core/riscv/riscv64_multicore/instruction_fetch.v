// instruction_fetch.v
module instruction_fetch (
    input wire clk,
    input wire rst_n,
    input wire stall,
    input wire flush,
    input wire [63:0] branch_target,
    input wire branch_taken,
    output reg [63:0] pc,
    output reg [31:0] instr,
    output reg cache_req,
    output reg [63:0] cache_addr,
    input wire [31:0] cache_data,
    input wire cache_ready
);

    reg [63:0] pc_next;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 64'h8000_0000;
            pc_next <= 64'h8000_0000;
            instr <= 32'h0000_0013; // NOP
            cache_req <= 1'b0;
            cache_addr <= 64'h0;
        end else if (flush) begin
            pc <= branch_target;
            pc_next <= branch_target + 4;
            instr <= 32'h0000_0013;
            cache_req <= 1'b1; // 重新取指
            cache_addr <= branch_target;
        end else if (!stall) begin
            if (branch_taken) begin
                pc <= branch_target;
                pc_next <= branch_target + 4;
                cache_req <= 1'b1;
                cache_addr <= branch_target;
            end else if (cache_ready) begin
                pc <= pc_next;
                pc_next <= pc_next + 4;
                cache_req <= 1'b1;
                cache_addr <= pc_next;
                instr <= cache_data; // 从缓存中获取指令数据
            end

            if (cache_ready && cache_req) begin
                cache_req <= 1'b0;
            end
        end
    end

endmodule