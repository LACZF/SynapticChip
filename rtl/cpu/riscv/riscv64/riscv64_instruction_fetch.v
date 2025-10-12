// riscv64_instruction_fetch.v
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
        end
    end
`endif

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
        `ifdef DEBUG
            $display("[%0t ps] IF: Reset, initializing PC=0x%h", $time, 64'h8000_0000);
        `endif
            pc_o <= 64'h8000_0000;
            pc_next <= 64'h8000_0000;
            instr_o <= 32'h0000_0013; // NOP
            cache_req_o <= 1'b1; // Request instruction immediately after reset
            cache_addr_o <= 64'h8000_0000;
        end else if (flush_i) begin
        `ifdef DEBUG
            $display("[%0t ps] IF: Flush, new PC=0x%h", $time, branch_target_i);
        `endif
            pc_o <= branch_target_i;
            pc_next <= branch_target_i + 4;
            instr_o <= 32'h0000_0013;
            cache_req_o <= 1'b1; // Re-fetch instruction
            cache_addr_o <= branch_target_i;
        end else if (!stall_i) begin
            if (branch_taken_i) begin
            `ifdef DEBUG
                $display("[%0t ps] IF: Branch taken, new PC=0x%h", $time, branch_target_i);
            `endif
                pc_o <= branch_target_i;
                pc_next <= branch_target_i + 4;
                cache_req_o <= 1'b1;
                cache_addr_o <= branch_target_i;
            end else if (cache_ready_i) begin
            `ifdef DEBUG
                $display("[%0t ps] IF: Cache ready, PC updated to 0x%h, fetching next instr at 0x%h",
                         $time, pc_next, pc_next + 4);
            `endif
                // Ensure correct instruction loading
                if (cache_data_i !== {L1_ICACHE_DATA_WIDTH{1'bz}} && cache_data_i !== {L1_ICACHE_DATA_WIDTH{1'bx}}) begin
                    instr_o <= cache_data_i[0 +: 32];; // Fetch instruction data from cache
                `ifdef DEBUG
                    $display("[%0t ps] IF: Loading instruction from cache: 0x%h", $time, cache_data_i);
                `endif
                end else begin
                    instr_o <= 32'h0000_0013; // Use NOP instruction as alternative
                `ifdef DEBUG
                    $display("[%0t ps] IF: Cache data invalid, using NOP instead", $time);
                `endif
                end
                // Update PC and next fetch address
                pc_o <= pc_next;
                pc_next <= pc_next + 4;
                // Continue requesting next instruction
                cache_req_o <= 1'b1;
                cache_addr_o <= pc_next + 4;
            end
        end else begin
        `ifdef DEBUG
            $display("[%0t ps] IF: Pipeline stalled", $time);
        `endif
        end
    end

endmodule