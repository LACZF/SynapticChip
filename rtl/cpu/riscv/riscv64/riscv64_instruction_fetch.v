// riscv64_instruction_fetch.v
module riscv64_instruction_fetch #(
    parameter ADDR_WIDTH                    = 64,
    parameter DATA_WIDTH                    = 64,
    parameter L1_ICACHE_DATA_WIDTH          = 32
)(
    input  wire                                       clk,
    input  wire                                       rst_n,
    input  wire                                       stall,
    input  wire                                       flush,
    input  wire [63:0]                                branch_target,
    input  wire                                       branch_taken,
    output reg  [63:0]                                pc,
    output reg  [31:0]                                instr,
    output reg                                        cache_req,
    output reg  [ADDR_WIDTH-1:0]                      cache_addr,
    input  wire [L1_ICACHE_DATA_WIDTH-1:0]           cache_data,
    input  wire                                       cache_ready
);

    reg [63:0] pc_next;
    reg cache_req_prev; // 用于检测cache_req变化的寄存器

    // 跟踪cache_req的前一个状态
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cache_req_prev <= 1'b0;
        end else begin
            cache_req_prev <= cache_req;
        end
    end

`ifdef DEBUG
    // 调试信息
    always @(posedge clk) begin
        if (rst_n) begin
            // 当cache_req信号状态变化时打印信息
            if (cache_req !== cache_req_prev) begin
                $display("[%0t ps] IF: cache_req changed to %b, pc=%0h, cache_addr=%0h",
                         $time, cache_req, pc, cache_addr);
            end
            // 当cache_ready为高时打印信息
            if (cache_ready) begin
                $display("[%0t ps] IF: cache_ready asserted, received instr=0x%h",
                         $time, cache_data);
            end
        end
    end
`endif

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
        `ifdef DEBUG
            $display("[%0t ps] IF: Reset, initializing PC=0x%h", $time, 64'h8000_0000);
        `endif
            pc <= 64'h8000_0000;
            pc_next <= 64'h8000_0000;
            instr <= 32'h0000_0013; // NOP
            cache_req <= 1'b1; // 复位后立即请求指令
            cache_addr <= 64'h8000_0000;
        end else if (flush) begin
        `ifdef DEBUG
            $display("[%0t ps] IF: Flush, new PC=0x%h", $time, branch_target);
        `endif
            pc <= branch_target;
            pc_next <= branch_target + 4;
            instr <= 32'h0000_0013;
            cache_req <= 1'b1; // 重新取指
            cache_addr <= branch_target;
        end else if (!stall) begin
            if (branch_taken) begin
            `ifdef DEBUG
                $display("[%0t ps] IF: Branch taken, new PC=0x%h", $time, branch_target);
            `endif
                pc <= branch_target;
                pc_next <= branch_target + 4;
                cache_req <= 1'b1;
                cache_addr <= branch_target;
            end else if (cache_ready) begin
            `ifdef DEBUG
                $display("[%0t ps] IF: Cache ready, PC updated to 0x%h, fetching next instr at 0x%h",
                         $time, pc_next, pc_next + 4);
            `endif
                // 确保指令正确加载
                if (cache_data !== {L1_ICACHE_DATA_WIDTH{1'bz}} && cache_data !== {L1_ICACHE_DATA_WIDTH{1'bx}}) begin
                    instr <= cache_data[0 +: 31];; // 从缓存中获取指令数据
                `ifdef DEBUG
                    $display("[%0t ps] IF: Loading instruction from cache: 0x%h", $time, cache_data);
                `endif
                end else begin
                    instr <= 32'h0000_0013; // NOP指令作为备选
                `ifdef DEBUG
                    $display("[%0t ps] IF: Cache data invalid, using NOP instead", $time);
                `endif
                end
                // 更新PC和下一个取指地址
                pc <= pc_next;
                pc_next <= pc_next + 4;
                // 继续请求下一条指令
                cache_req <= 1'b1;
                cache_addr <= pc_next + 4;
            end
        end else begin
        `ifdef DEBUG
            $display("[%0t ps] IF: Pipeline stalled", $time);
        `endif
        end
    end

endmodule