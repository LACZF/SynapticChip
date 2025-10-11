// riscv64_memory_access.v
`include "cache_params.v"

module riscv64_memory_access #(
    parameter ADDR_WIDTH                                 = 64,
    parameter DATA_WIDTH                                 = 64,
    parameter L1_DCACHE_DATA_WIDTH                       = 64
)(
    input  wire                                          clk,
    input  wire                                          rst_n,
    input  wire                                          stall,
    input  wire                                          flush,

    // From execution stage
    input  wire [63:0]                                   pc_in,
    input  wire [31:0]                                   instr_in,
    input  wire [63:0]                                   alu_result,
    input  wire [63:0]                                   rs2_data,
    input  wire [15:0]                                   ctrl_in,

    // Cache interface
    output reg  [ADDR_WIDTH-1:0]                         cache_addr,
    output reg  [L1_DCACHE_DATA_WIDTH-1:0]               cache_wdata,
    input  wire [L1_DCACHE_DATA_WIDTH-1:0]               cache_rdata,
    output reg                                           cache_req,
    output reg                                           cache_we,
    output reg  [L1_DCACHE_DATA_WIDTH/8-1:0]             cache_byte_en,
    input  wire                                          cache_ready,

    // Output to write back stage
    output reg [63:0]                                    pc_out,
    output reg [31:0]                                    instr_out,
    output reg [63:0]                                    mem_result,
    output reg [15:0]                                    ctrl_out
);

    // Control signals
    wire       mem_read        = ctrl_in[9];
    wire       mem_write       = ctrl_in[8];
    wire [2:0] mem_width       = ctrl_in[7:5];
    wire [6:0] opcode          = instr_in[6:0];
    wire [2:0] funct3          = instr_in[14:12];

    // Internal state
    reg [2:0]                  state;
    reg [63:0]                 saved_alu_result;
    reg [63:0]                 saved_rs2_data;
    reg [2:0]                  saved_mem_width;
    reg                        saved_is_load;
    reg                        saved_is_store;

    localparam STATE_IDLE         = 3'b000;
    localparam STATE_CACHE_ACCESS = 3'b001;
    localparam STATE_WAIT_CACHE   = 3'b010;
    localparam STATE_COMPLETE     = 3'b011;

    // Byte enable generation function
    function [7:0] gen_byte_enable;
        input [2:0] width;
        input [2:0] addr_low;
        begin
            case (width)
                3'b000: begin // Byte (8-bit)
                    case (addr_low)
                        3'b000: gen_byte_enable = 8'b00000001;
                        3'b001: gen_byte_enable = 8'b00000010;
                        3'b010: gen_byte_enable = 8'b00000100;
                        3'b011: gen_byte_enable = 8'b00001000;
                        3'b100: gen_byte_enable = 8'b00010000;
                        3'b101: gen_byte_enable = 8'b00100000;
                        3'b110: gen_byte_enable = 8'b01000000;
                        3'b111: gen_byte_enable = 8'b10000000;
                        default: gen_byte_enable = 8'b00000001;
                    endcase
                end
                3'b001: begin // Half-word (16-bit)
                    case (addr_low[2:1])
                        2'b00: gen_byte_enable = 8'b00000011;
                        2'b01: gen_byte_enable = 8'b00001100;
                        2'b10: gen_byte_enable = 8'b00110000;
                        2'b11: gen_byte_enable = 8'b11000000;
                        default: gen_byte_enable = 8'b00000011;
                    endcase
                end
                3'b010: begin // Word (32-bit)
                    case (addr_low[2])
                        1'b0: gen_byte_enable = 8'b00001111;
                        1'b1: gen_byte_enable = 8'b11110000;
                        default: gen_byte_enable = 8'b00001111;
                    endcase
                end
                3'b011: begin // Double-word (64-bit)
                    gen_byte_enable = 8'b11111111;
                end
                default: gen_byte_enable = 8'b11111111;
            endcase
        end
    endfunction

    // Load data alignment and sign extension
    function [63:0] load_data_align;
        input [63:0] data;
        input [2:0] width;
        input [2:0] addr_low;
        input is_signed;
        reg [63:0] aligned;
        begin
            // Select data based on the lower 3 bits of the address
            case (addr_low)
                3'b000: aligned = data;
                3'b001: aligned = data >> 8;
                3'b010: aligned = data >> 16;
                3'b011: aligned = data >> 24;
                3'b100: aligned = data >> 32;
                3'b101: aligned = data >> 40;
                3'b110: aligned = data >> 48;
                3'b111: aligned = data >> 56;
                default: aligned = data;
            endcase

            case (width)
                3'b000: begin // LB/LBU
                    if (is_signed) begin
                        load_data_align = {{56{aligned[7]}}, aligned[7:0]};
                    end else begin
                        load_data_align = {56'b0, aligned[7:0]};
                    end
                end
                3'b001: begin // LH/LHU
                    if (is_signed) begin
                        load_data_align = {{48{aligned[15]}}, aligned[15:0]};
                    end else begin
                        load_data_align = {48'b0, aligned[15:0]};
                    end
                end
                3'b010: begin // LW/LWU
                    if (is_signed) begin
                        load_data_align = {{32{aligned[31]}}, aligned[31:0]};
                    end else begin
                        load_data_align = {32'b0, aligned[31:0]};
                    end
                end
                3'b011: begin // LD
                    load_data_align = aligned;
                end
                default: load_data_align = aligned;
            endcase
        end
    endfunction

    // Store data alignment
    function [63:0] store_data_align;
        input [63:0] data;
        input [2:0] width;
        input [2:0] addr_low;
        reg [63:0] aligned;
        begin
            case (width)
                3'b000: aligned = {56'b0, data[7:0]}; // Byte
                3'b001: aligned = {48'b0, data[15:0]}; // Half-word
                3'b010: aligned = {32'b0, data[31:0]}; // Word
                3'b011: aligned = data; // Double-word
                default: aligned = data;
            endcase

            // Shift left based on address offset
            case (addr_low)
                3'b000: store_data_align = aligned;
                3'b001: store_data_align = aligned << 8;
                3'b010: store_data_align = aligned << 16;
                3'b011: store_data_align = aligned << 24;
                3'b100: store_data_align = aligned << 32;
                3'b101: store_data_align = aligned << 40;
                3'b110: store_data_align = aligned << 48;
                3'b111: store_data_align = aligned << 56;
                default: store_data_align = aligned;
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            cache_req <= 1'b0;
            cache_we <= 1'b0;
            pc_out <= 64'b0;
            instr_out <= 32'h00000013; // NOP
            mem_result <= 64'b0;
            ctrl_out <= 16'b0;
            cache_addr <= 64'b0;
            cache_wdata <= {L1_DCACHE_DATA_WIDTH{1'b0}};
            cache_byte_en <= 8'b0;
        end else if (flush) begin
            state <= STATE_IDLE;
            cache_req <= 1'b0;
            cache_we <= 1'b0;
            instr_out <= 32'h00000013;
            ctrl_out <= 16'b0;
        end else if (stall) begin
            // Hold state
        end else begin
            case (state)
                STATE_IDLE: begin
                    // Pass pipeline registers
                    pc_out <= pc_in;
                    instr_out <= instr_in;
                    ctrl_out <= ctrl_in;

                    if (mem_read || mem_write) begin
                        // Memory access instruction
                        saved_alu_result <= alu_result;
                        saved_rs2_data <= rs2_data;
                        saved_mem_width <= mem_width;
                        saved_is_load <= mem_read;
                        saved_is_store <= mem_write;

                        cache_addr <= alu_result;
                        cache_byte_en <= gen_byte_enable(mem_width, alu_result[2:0]);

                        if (mem_read) begin
                            // Load instruction
                            cache_we <= 1'b0;
                            cache_req <= 1'b1;
                            state <= STATE_CACHE_ACCESS;
                        end else begin
                            // Store instruction
                            cache_we <= 1'b1;
                            cache_wdata <= store_data_align(rs2_data, mem_width, alu_result[2:0]);
                            cache_req <= 1'b1;
                            state <= STATE_CACHE_ACCESS;
                        end
                    end else begin
                        // Non-memory instruction, directly pass ALU result
                        mem_result <= alu_result;
                        state <= STATE_COMPLETE;
                    end
                end

                STATE_CACHE_ACCESS: begin
                    if (cache_ready) begin
                        if (saved_is_load) begin
                            // Load completed
                            mem_result <= load_data_align(cache_rdata, saved_mem_width,
                                                        saved_alu_result[2:0],
                                                        funct3 != 3'b100); // Signed extension
                        end else begin
                            // Store completed, return store address
                            mem_result <= saved_alu_result;
                        end
                        cache_req <= 1'b0;
                        state <= STATE_COMPLETE;
                    end else begin
                        state <= STATE_WAIT_CACHE;
                    end
                end

                STATE_WAIT_CACHE: begin
                    if (cache_ready) begin
                        if (saved_is_load) begin
                            mem_result <= load_data_align(cache_rdata, saved_mem_width,
                                                        saved_alu_result[2:0],
                                                        funct3 != 3'b100);
                        end else begin
                            mem_result <= saved_alu_result;
                        end
                        cache_req <= 1'b0;
                        state <= STATE_COMPLETE;
                    end
                end

                STATE_COMPLETE: begin
                    state <= STATE_IDLE;
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule