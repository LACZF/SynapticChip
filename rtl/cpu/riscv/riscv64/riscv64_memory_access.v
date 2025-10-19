// riscv64_memory_access.v
`include "cache_params.v"

module riscv64_memory_access #(
    parameter ADDR_WIDTH                                 = 64,
    parameter DATA_WIDTH                                 = 64,
    parameter L1_DCACHE_DATA_WIDTH                       = 64,
    parameter ENABLE_MMU                                 = 1
)(
    input  wire                                          clk,
    input  wire                                          rst_n,
    input  wire                                          stall_i,
    input  wire                                          flush_i,
    input  wire [1:0]                                    priv_mode_i, // 特权模式 (M/S/U) - 从外部输入
    input  wire [63:0]                                   satp_i,      // 页表基址寄存器
    input  wire [63:0]                                   status_i,    // 状态寄存器

    // From execution stage
    input  wire [63:0]                                   pc_in_i,
    input  wire [31:0]                                   instr_in_i,
    input  wire [63:0]                                   alu_result_i,
    input  wire [63:0]                                   rs2_data_i,
    input  wire [15:0]                                   ctrl_in_i,

    // Cache interface
    output reg  [ADDR_WIDTH-1:0]                         cache_addr_o,
    output reg  [L1_DCACHE_DATA_WIDTH-1:0]               cache_wdata_o,
    input  wire [L1_DCACHE_DATA_WIDTH-1:0]               cache_rdata_i,
    output reg                                           cache_req_o,
    output reg                                           cache_we_o,
    output reg  [L1_DCACHE_DATA_WIDTH/8-1:0]             cache_byte_en_o,
    input  wire                                          cache_ready_i,

    // Output to write back stage
    output reg [63:0]                                    pc_out_o,
    output reg [31:0]                                    instr_out_o,
    output reg [63:0]                                    mem_result_o,
    output reg [15:0]                                    ctrl_out_o
);

    // Control signals
    // 修复：修正控制信号的位定义，与指令解码模块保持一致
    wire       mem_read        = ctrl_in_i[9];    // 内存读使能
    wire       mem_to_reg      = ctrl_in_i[8];    // 内存到寄存器
    wire       reg_write       = ctrl_in_i[7];    // 寄存器写使能
    wire [2:0] mem_width       = ctrl_in_i[4:2];  // 内存访问宽度 (从funct3获取)
    wire [6:0] opcode          = instr_in_i[6:0];
    wire [2:0] funct3          = instr_in_i[14:12];

    // MMU related signals
    wire [ADDR_WIDTH-1:0] phys_addr;
    wire page_fault;
    wire translation_ready;
    reg [ADDR_WIDTH-1:0] access_addr; // 最终使用的访问地址 (物理地址或虚拟地址)

    // Internal state
    reg [2:0]                  state;
    reg [63:0]                 saved_alu_result;
    reg [63:0]                 saved_rs2_data;
    reg [2:0]                  saved_mem_width;
    reg                        saved_is_load;
    reg                        saved_is_store;
    reg                        saved_page_fault;
    reg                        mmu_access_started;

    // State definitions
    localparam STATE_IDLE         = 3'b000;
    localparam STATE_CACHE_ACCESS = 3'b001;
    localparam STATE_WAIT_CACHE   = 3'b010;
    localparam STATE_COMPLETE     = 3'b011;
    localparam STATE_MMU_TRANSLATE = 3'b100;

    // 条件实例化MMU模块
    generate
        if (ENABLE_MMU) begin
            riscv64_mmu #(
                .ADDR_WIDTH(ADDR_WIDTH)
            ) u_mmu (
                .clk(clk),
                .rst_n(rst_n),
                .enable_i(status_i[0]), // MMU总使能（从status寄存器第0位获取）
                .virt_addr_i(alu_result_i), // 从ALU结果获取虚拟地址
                .priv_mode_i(priv_mode_i), // 特权模式
                .inst_access_i(1'b0), // 数据访问，非指令访问
                .write_access_i(mem_read ? 1'b0 : 1'b1), // 写访问标志
                .phys_addr_o(phys_addr), // 转换后的物理地址
                .page_fault_o(page_fault), // 页错误标志
                .translation_ready_o(translation_ready), // 转换完成标志
                // MMU控制寄存器接口
                .satp_i(satp_i), // 页表基址寄存器
                .status_i(status_i) // 状态寄存器
            );
        end else begin
            // 不启用MMU时，直接连接地址
            assign phys_addr = alu_result_i;
            assign page_fault = 1'b0;
            assign translation_ready = 1'b1;
        end
    endgenerate

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
                3'b000:  aligned = data;
                3'b001:  aligned = data >> 8;
                3'b010:  aligned = data >> 16;
                3'b011:  aligned = data >> 24;
                3'b100:  aligned = data >> 32;
                3'b101:  aligned = data >> 40;
                3'b110:  aligned = data >> 48;
                3'b111:  aligned = data >> 56;
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
        input [2:0]  width;
        input [2:0]  addr_low;
        reg   [63:0] aligned;
        begin
            case (width)
                3'b000:  aligned = {56'b0, data[7:0]}; // Byte
                3'b001:  aligned = {48'b0, data[15:0]}; // Half-word
                3'b010:  aligned = {32'b0, data[31:0]}; // Word
                3'b011:  aligned = data; // Double-word
                default: aligned = data;
            endcase

            // Shift left based on address offset
            case (addr_low)
                3'b000:  store_data_align = aligned;
                3'b001:  store_data_align = aligned << 8;
                3'b010:  store_data_align = aligned << 16;
                3'b011:  store_data_align = aligned << 24;
                3'b100:  store_data_align = aligned << 32;
                3'b101:  store_data_align = aligned << 40;
                3'b110:  store_data_align = aligned << 48;
                3'b111:  store_data_align = aligned << 56;
                default: store_data_align = aligned;
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            cache_req_o <= 1'b0;
            cache_we_o <= 1'b0;
            pc_out_o <= 64'b0;
            instr_out_o <= 32'h00000013; // NOP
            mem_result_o <= 64'b0;
            ctrl_out_o <= 16'b0;
            cache_addr_o <= 64'b0;
            cache_wdata_o <= {L1_DCACHE_DATA_WIDTH{1'b0}};
            cache_byte_en_o <= 8'b0;
            saved_page_fault <= 1'b0;
            mmu_access_started <= 1'b0;
        end else if (flush_i) begin
            state <= STATE_IDLE;
            cache_req_o <= 1'b0;
            cache_we_o <= 1'b0;
            instr_out_o <= 32'h00000013;
            ctrl_out_o <= 16'b0;
            saved_page_fault <= 1'b0;
            mmu_access_started <= 1'b0;
        end else if (stall_i) begin
            // 保持当前状态
        end else begin
            case (state)
                STATE_IDLE: begin
                    // Pass pipeline registers
                    pc_out_o <= pc_in_i;
                    instr_out_o <= instr_in_i;
                    ctrl_out_o <= ctrl_in_i;
                    saved_page_fault <= 1'b0;
                    mmu_access_started <= 1'b0;

                    if (mem_read || (ctrl_in_i[15] == 0 && opcode == 7'b0100011)) begin // 使用opcode判断store指令
                        // Memory access instruction
                        saved_alu_result <= alu_result_i;
                        saved_rs2_data <= rs2_data_i;
                        saved_mem_width <= mem_width;
                        saved_is_load <= mem_read;
                        saved_is_store <= (ctrl_in_i[15] == 0 && opcode == 7'b0100011); // 使用opcode设置store标志

                        if (ENABLE_MMU) begin
                            // MMU使能时，进入MMU转换状态
                            state <= STATE_MMU_TRANSLATE;
                            mmu_access_started <= 1'b1;
                        end else begin
                            // 不使用MMU时，直接访问缓存
                            cache_addr_o <= alu_result_i;
                            cache_byte_en_o <= gen_byte_enable(mem_width, alu_result_i[2:0]);

                            if (mem_read) begin
                                // Load instruction
                                cache_we_o <= 1'b0;
                                cache_req_o <= 1'b1;
                                state <= STATE_CACHE_ACCESS;
                            end else begin
                                // Store instruction
                                cache_we_o <= 1'b1;
                                cache_wdata_o <= store_data_align(rs2_data_i, mem_width, alu_result_i[2:0]);
                                cache_req_o <= 1'b1;
                                state <= STATE_CACHE_ACCESS;
                            end
                        end
                    end else begin
                        // Non-memory instruction, directly pass ALU result
                        mem_result_o <= alu_result_i;
                        state <= STATE_COMPLETE;
                    end
                end

                STATE_MMU_TRANSLATE: begin
                    if (translation_ready) begin
                        if (!page_fault) begin
                            // 地址转换成功，使用物理地址访问缓存
                            access_addr <= phys_addr;
                            cache_addr_o <= phys_addr;
                            cache_byte_en_o <= gen_byte_enable(saved_mem_width, phys_addr[2:0]);

                            if (saved_is_load) begin
                                cache_we_o <= 1'b0;
                                cache_req_o <= 1'b1;
                                state <= STATE_CACHE_ACCESS;
                            end else if (saved_is_store) begin
                                cache_we_o <= 1'b1;
                                cache_wdata_o <= store_data_align(saved_rs2_data, saved_mem_width, phys_addr[2:0]);
                                cache_req_o <= 1'b1;
                                state <= STATE_CACHE_ACCESS;
                            end
                        end else begin
                            // 页错误，记录并进入完成状态
                            saved_page_fault <= 1'b1;
                            state <= STATE_COMPLETE;
                        end
                    end
                    // 等待转换完成
                end

                STATE_CACHE_ACCESS: begin
                    if (cache_ready_i) begin
                        if (saved_is_load) begin
                            // Load completed
                            mem_result_o <= load_data_align(cache_rdata_i, saved_mem_width,
                                                        saved_alu_result[2:0],
                                                        funct3 != 3'b100); // Signed extension
                        end else begin
                            // Store completed, return store address
                            mem_result_o <= saved_alu_result;
                        end
                        cache_req_o <= 1'b0;
                        state <= STATE_COMPLETE;
                    end else begin
                        state <= STATE_WAIT_CACHE;
                    end
                end

                STATE_WAIT_CACHE: begin
                    if (cache_ready_i) begin
                        if (saved_is_load) begin
                            mem_result_o <= load_data_align(cache_rdata_i, saved_mem_width,
                                                        saved_alu_result[2:0],
                                                        funct3 != 3'b100);
                        end else begin
                            mem_result_o <= saved_alu_result;
                        end
                        cache_req_o <= 1'b0;
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