// riscv64_instruction_fetch.v
`timescale 1ns / 1ps

module riscv64_instruction_fetch #(
    parameter ADDR_WIDTH                              = 64,
    parameter DATA_WIDTH                              = 64,
    parameter L1_ICACHE_DATA_WIDTH                    = 32
)(
    input  wire                                       clk,
    input  wire                                       rst_n,
    input  wire                                       stall_i,
    input  wire                                       flush_i,
    input  wire [63:0]                                branch_target_i,
    input  wire                                       branch_taken_i,
    output reg  [63:0]                                pc_o,
    output reg  [31:0]                                instr_o,
    output reg                                        cache_req_o,
    output reg  [ADDR_WIDTH-1:0]                      cache_addr_o,
    input  wire [L1_ICACHE_DATA_WIDTH-1:0]            cache_data_i,
    input  wire                                       cache_ready_i
);

    reg [63:0] pc_next;
    reg [63:0] next_pc_value;
    reg [31:0] fetched_instr;

`ifdef DEBUG
    reg cache_req_prev; // Register for detecting cache_req changes

    // Track previous state of cache_req
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cache_req_prev <= 1'b0;
        end else begin
            cache_req_prev <= cache_req_o;
        end
    end

    // Debug information
    always @(posedge clk) begin
        if (rst_n) begin
            // Print information when cache_req signal state changes
            if (cache_req_o !== cache_req_prev) begin
                $display("[%0t ps] IF: cache_req changed to %b, pc=%0h, cache_addr=%0h",
                         $time, cache_req_o, pc_o, cache_addr_o);
            end
            // Print information when cache_ready is high
            if (cache_ready_i) begin
                $display("[%0t ps] IF: cache_ready asserted, received instr=0x%h",
                         $time, cache_data_i);
            end
            // Print information about fetched instruction
            if (fetched_instr != 32'h0000_0013) begin
                $display("[%0t ps] IF: Fetched non-NOP instruction: 0x%h at PC=0x%h",
                         $time, fetched_instr, pc_o);
            end
        end
    end
`endif

    // 修复：简化PC和指令获取逻辑，确保时序一致性
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_o <= 64'h8000_0000;
            pc_next <= 64'h8000_0004;
            instr_o <= 32'h0000_0013; // NOP
            cache_req_o <= 1'b1; // Request instruction immediately after reset
            cache_addr_o <= 64'h8000_0000;
            fetched_instr <= 32'h0000_0013;
        end else if (flush_i) begin
            pc_o <= branch_target_i;
            pc_next <= branch_target_i + 4;
            instr_o <= 32'h0000_0013; // NOP
            cache_req_o <= 1'b1;
            cache_addr_o <= branch_target_i;
        end else if (!stall_i) begin
            if (branch_taken_i) begin
                // Branch taken, update PC to branch target
                pc_o <= branch_target_i;
                pc_next <= branch_target_i + 4;
                cache_req_o <= 1'b1;
                cache_addr_o <= branch_target_i;
                // 不立即设置为NOP，让缓存数据有机会更新instr_o
            end else begin
                // Normal execution, update PC sequentially
                pc_o <= pc_next;
                pc_next <= pc_next + 4;
                cache_req_o <= 1'b1;
                cache_addr_o <= pc_next;
            end

            // Update instruction only when cache is ready
            if (cache_ready_i) begin
                // Load instruction from cache
                if (L1_ICACHE_DATA_WIDTH >= 32) begin
                    fetched_instr <= cache_data_i[31:0];
                    instr_o <= cache_data_i[31:0];
                end else begin
                    fetched_instr <= {24'b0, cache_data_i};
                    instr_o <= {24'b0, cache_data_i};
                end
            end
        end
    end


endmodule