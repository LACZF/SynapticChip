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
    output reg mem_req,
    output reg [63:0] mem_addr,
    input wire [63:0] mem_rdata,
    input wire mem_ready
);

    reg [63:0] pc_next;
    reg [2:0] state;

    localparam STATE_IDLE = 3'b000;
    localparam STATE_FETCH = 3'b001;
    localparam STATE_WAIT = 3'b010;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 64'h8000_0000; // 复位地址
            pc_next <= 64'h8000_0000;
            instr <= 32'h0000_0013; // NOP
            state <= STATE_IDLE;
            mem_req <= 1'b0;
        end else if (flush) begin
            pc <= branch_target;
            pc_next <= branch_target + 4;
            instr <= 32'h0000_0013; // 插入NOP
        end else if (!stall) begin
            if (branch_taken) begin
                pc <= branch_target;
                pc_next <= branch_target + 4;
            end else begin
                pc <= pc_next;
                pc_next <= pc_next + 4;
            end

            // 内存访问状态机
            case (state)
                STATE_IDLE: begin
                    mem_req <= 1'b1;
                    mem_addr <= branch_taken ? branch_target : pc_next;
                    state <= STATE_FETCH;
                end

                STATE_FETCH: begin
                    if (mem_ready) begin
                        instr <= mem_rdata[31:0];
                        mem_req <= 1'b0;
                        state <= STATE_IDLE;
                    end else begin
                        state <= STATE_WAIT;
                    end
                end

                STATE_WAIT: begin
                    if (mem_ready) begin
                        instr <= mem_rdata[31:0];
                        mem_req <= 1'b0;
                        state <= STATE_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
