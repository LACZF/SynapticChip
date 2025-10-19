// riscv64_memory_access.v
`include "cache_params.v"
`include "riscv64_instruction_defs.v"

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
    input  wire                                          ex_valid_i,

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
    output reg [15:0]                                    ctrl_out_o,
    output reg                                           mem_valid_o
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

    // 数据大小处理函数 - 处理不同宽度的内存访问
    function [63:0] process_data;
        input [L1_DCACHE_DATA_WIDTH-1:0] data;
        input [2:0] width;
        input [2:0] addr_offset;
        input is_signed;
        begin
            case (width)
                3'b000: begin // Byte
                    if (is_signed) begin
                        case (addr_offset[2:0])
                            3'b000: process_data = {{56{data[7]}}, data[7:0]};
                            3'b001: process_data = {{56{data[15]}}, data[15:8]};
                            3'b010: process_data = {{56{data[23]}}, data[23:16]};
                            3'b011: process_data = {{56{data[31]}}, data[31:24]};
                            3'b100: process_data = {{56{data[39]}}, data[39:32]};
                            3'b101: process_data = {{56{data[47]}}, data[47:40]};
                            3'b110: process_data = {{56{data[55]}}, data[55:48]};
                            3'b111: process_data = {{56{data[63]}}, data[63:56]};
                        endcase
                    end else begin
                        case (addr_offset[2:0])
                            3'b000: process_data = {56'b0, data[7:0]};
                            3'b001: process_data = {56'b0, data[15:8]};
                            3'b010: process_data = {56'b0, data[23:16]};
                            3'b011: process_data = {56'b0, data[31:24]};
                            3'b100: process_data = {56'b0, data[39:32]};
                            3'b101: process_data = {56'b0, data[47:40]};
                            3'b110: process_data = {56'b0, data[55:48]};
                            3'b111: process_data = {56'b0, data[63:56]};
                        endcase
                    end
                end
                3'b001: begin // Half-word
                    if (is_signed) begin
                        case (addr_offset[2:1])
                            2'b00: process_data = {{48{data[15]}}, data[15:0]};
                            2'b01: process_data = {{48{data[31]}}, data[31:16]};
                            2'b10: process_data = {{48{data[47]}}, data[47:32]};
                            2'b11: process_data = {{48{data[63]}}, data[63:48]};
                        endcase
                    end else begin
                        case (addr_offset[2:1])
                            2'b00: process_data = {48'b0, data[15:0]};
                            2'b01: process_data = {48'b0, data[31:16]};
                            2'b10: process_data = {48'b0, data[47:32]};
                            2'b11: process_data = {48'b0, data[63:48]};
                        endcase
                    end
                end
                3'b010: begin // Word
                    if (is_signed) begin
                        case (addr_offset[2])
                            1'b0: process_data = {{32{data[31]}}, data[31:0]};
                            1'b1: process_data = {{32{data[63]}}, data[63:32]};
                        endcase
                    end else begin
                        case (addr_offset[2])
                            1'b0: process_data = {32'b0, data[31:0]};
                            1'b1: process_data = {32'b0, data[63:32]};
                        endcase
                    end
                end
                3'b011: begin // Double-word
                    process_data = data;
                end
                default: begin
                    process_data = 64'b0;
                end
            endcase
        end
    endfunction

    // 内存访问状态机 - 处理加载和存储操作
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            cache_req_o <= 1'b0;
            cache_we_o <= 1'b0;
            cache_byte_en_o <= 8'b0;
            cache_addr_o <= 64'b0;
            cache_wdata_o <= 64'b0;
            mem_result_o <= 64'b0;
            pc_out_o <= 64'b0;
            instr_out_o <= 32'h0000_0013;
            ctrl_out_o <= 16'b0;
            saved_alu_result <= 64'b0;
            saved_rs2_data <= 64'b0;
            saved_mem_width <= 3'b0;
            saved_is_load <= 1'b0;
            saved_is_store <= 1'b0;
            saved_page_fault <= 1'b0;
            mmu_access_started <= 1'b0;
            mem_valid_o <= 1'b0; // 初始化为无效
        end else if (flush_i) begin
            state <= STATE_IDLE;
            cache_req_o <= 1'b0;
            cache_we_o <= 1'b0;
            cache_byte_en_o <= 8'b0;
            mem_result_o <= 64'b0;
            instr_out_o <= 32'h0000_0013;
            // 保持PC值不变，只修改指令为NOP
            // 不修改pc_out_o，保持其当前值
            ctrl_out_o <= 16'b0;
            mem_valid_o <= 1'b0; // 刷新时设置为无效
        end else if (!stall_i) begin
            case (state)
                STATE_IDLE: begin
                    if (ex_valid_i) begin // 只有当上一级输入有效时才处理指令
                        pc_out_o <= pc_in_i;
                        instr_out_o <= instr_in_i;
                        ctrl_out_o <= ctrl_in_i;
                        mem_valid_o <= 1'b1; // 当前级设置为有效

                        // 检查是否需要内存访问
                        if (mem_read || (opcode == `OPCODE_STORE)) begin
                            // 处理内存访问
                            if (ENABLE_MMU && status_i[0]) begin
                                // 使用MMU进行地址转换
                                if (!mmu_access_started) begin
                                    mmu_access_started <= 1'b1;
                                    state <= STATE_MMU_TRANSLATE;
                                end else if (translation_ready) begin
                                    if (page_fault) begin
                                        // 页错误处理
                                        saved_page_fault <= 1'b1;
                                        state <= STATE_COMPLETE;
                                    end else begin
                                        // 转换完成，使用物理地址
                                        access_addr <= phys_addr;
                                        state <= STATE_CACHE_ACCESS;
                                    end
                                    mmu_access_started <= 1'b0;
                                end
                            end else begin
                                // 不使用MMU，直接使用ALU结果作为地址
                                access_addr <= alu_result_i;
                                state <= STATE_CACHE_ACCESS;
                            end

                            // 保存当前操作需要的信息
                            saved_alu_result <= alu_result_i;
                            saved_rs2_data <= rs2_data_i;
                            saved_mem_width <= mem_width;
                            saved_is_load <= mem_read;
                            saved_is_store <= (opcode == `OPCODE_STORE);
                        end else begin
                            // 不需要内存访问，直接传递ALU结果
                            mem_result_o <= alu_result_i;
                            state <= STATE_COMPLETE;
                        end
                    end else begin
                        // 当上一级输入无效时，输出NOP指令
                        instr_out_o <= 32'h0000_0013;
                        ctrl_out_o <= 16'b0;
                        mem_valid_o <= 1'b0;
                        state <= STATE_IDLE;
                    end
                end

                STATE_MMU_TRANSLATE: begin
                    if (translation_ready) begin
                        if (page_fault) begin
                            // 页错误处理
                            saved_page_fault <= 1'b1;
                            state <= STATE_COMPLETE;
                        end else begin
                            // 转换完成，使用物理地址
                            access_addr <= phys_addr;
                            state <= STATE_CACHE_ACCESS;
                        end
                        mmu_access_started <= 1'b0;
                    end
                end

                STATE_CACHE_ACCESS: begin
                    if (saved_is_load) begin
                        // 加载操作
                        cache_req_o <= 1'b1;
                        cache_we_o <= 1'b0;
                        cache_addr_o <= access_addr;
                        // 根据访问宽度设置字节使能
                        case (saved_mem_width)
                            3'b000: // Byte
                                case (access_addr[2:0])
                                    3'b000: cache_byte_en_o <= 8'b00000001;
                                    3'b001: cache_byte_en_o <= 8'b00000010;
                                    3'b010: cache_byte_en_o <= 8'b00000100;
                                    3'b011: cache_byte_en_o <= 8'b00001000;
                                    3'b100: cache_byte_en_o <= 8'b00010000;
                                    3'b101: cache_byte_en_o <= 8'b00100000;
                                    3'b110: cache_byte_en_o <= 8'b01000000;
                                    3'b111: cache_byte_en_o <= 8'b10000000;
                                endcase
                            3'b001: // Half-word
                                case (access_addr[2:1])
                                    2'b00: cache_byte_en_o <= 8'b00000011;
                                    2'b01: cache_byte_en_o <= 8'b00001100;
                                    2'b10: cache_byte_en_o <= 8'b00110000;
                                    2'b11: cache_byte_en_o <= 8'b11000000;
                                endcase
                            3'b010: // Word
                                case (access_addr[2])
                                    1'b0: cache_byte_en_o <= 8'b00001111;
                                    1'b1: cache_byte_en_o <= 8'b11110000;
                                endcase
                            3'b011: // Double-word
                                cache_byte_en_o <= 8'b11111111;
                            default:
                                cache_byte_en_o <= 8'b0;
                        endcase
                        state <= STATE_WAIT_CACHE;
                    end else if (saved_is_store) begin
                        // 存储操作
                        cache_req_o <= 1'b1;
                        cache_we_o <= 1'b1;
                        cache_addr_o <= access_addr;

                        // 根据访问宽度设置字节使能和数据
                        case (saved_mem_width)
                            3'b000: begin // Byte
                                case (access_addr[2:0])
                                    3'b000: begin
                                        cache_byte_en_o <= 8'b00000001;
                                        cache_wdata_o <= {56'b0, saved_rs2_data[7:0]};
                                    end
                                    3'b001: begin
                                        cache_byte_en_o <= 8'b00000010;
                                        cache_wdata_o <= {48'b0, saved_rs2_data[7:0], 8'b0};
                                    end
                                    3'b010: begin
                                        cache_byte_en_o <= 8'b00000100;
                                        cache_wdata_o <= {40'b0, saved_rs2_data[7:0], 16'b0};
                                    end
                                    3'b011: begin
                                        cache_byte_en_o <= 8'b00001000;
                                        cache_wdata_o <= {32'b0, saved_rs2_data[7:0], 24'b0};
                                    end
                                    3'b100: begin
                                        cache_byte_en_o <= 8'b00010000;
                                        cache_wdata_o <= {24'b0, saved_rs2_data[7:0], 32'b0};
                                    end
                                    3'b101: begin
                                        cache_byte_en_o <= 8'b00100000;
                                        cache_wdata_o <= {16'b0, saved_rs2_data[7:0], 40'b0};
                                    end
                                    3'b110: begin
                                        cache_byte_en_o <= 8'b01000000;
                                        cache_wdata_o <= {8'b0, saved_rs2_data[7:0], 48'b0};
                                    end
                                    3'b111: begin
                                        cache_byte_en_o <= 8'b10000000;
                                        cache_wdata_o <= {saved_rs2_data[7:0], 56'b0};
                                    end
                                endcase
                            end
                            3'b001: begin // Half-word
                                case (access_addr[2:1])
                                    2'b00: begin
                                        cache_byte_en_o <= 8'b00000011;
                                        cache_wdata_o <= {48'b0, saved_rs2_data[15:0]};
                                    end
                                    2'b01: begin
                                        cache_byte_en_o <= 8'b00001100;
                                        cache_wdata_o <= {32'b0, saved_rs2_data[15:0], 16'b0};
                                    end
                                    2'b10: begin
                                        cache_byte_en_o <= 8'b00110000;
                                        cache_wdata_o <= {16'b0, saved_rs2_data[15:0], 32'b0};
                                    end
                                    2'b11: begin
                                        cache_byte_en_o <= 8'b11000000;
                                        cache_wdata_o <= {saved_rs2_data[15:0], 48'b0};
                                    end
                                endcase
                            end
                            3'b010: begin // Word
                                case (access_addr[2])
                                    1'b0: begin
                                        cache_byte_en_o <= 8'b00001111;
                                        cache_wdata_o <= {32'b0, saved_rs2_data[31:0]};
                                    end
                                    1'b1: begin
                                        cache_byte_en_o <= 8'b11110000;
                                        cache_wdata_o <= {saved_rs2_data[31:0], 32'b0};
                                    end
                                endcase
                            end
                            3'b011: begin // Double-word
                                cache_byte_en_o <= 8'b11111111;
                                cache_wdata_o <= saved_rs2_data;
                            end
                            default:
                                cache_byte_en_o <= 8'b0;
                        endcase
                        state <= STATE_WAIT_CACHE;
                    end else begin
                        // 既不是加载也不是存储，直接完成
                        state <= STATE_COMPLETE;
                    end
                end

                STATE_WAIT_CACHE: begin
                    if (cache_ready_i) begin
                        if (saved_is_load) begin
                            // 加载操作，处理缓存返回的数据
                            mem_result_o <= process_data(cache_rdata_i, saved_mem_width, access_addr[2:0], (funct3[2] == 1'b0));
                        end
                        // 清除缓存请求信号
                        cache_req_o <= 1'b0;
                        cache_we_o <= 1'b0;
                        cache_byte_en_o <= 8'b0;
                        state <= STATE_COMPLETE;
                    end
                end

                STATE_COMPLETE: begin
                    // 内存访问完成，准备进入下一个状态
                    if (saved_page_fault) begin
                        // 处理页错误
                        // 这里可以添加页错误异常处理逻辑
                        saved_page_fault <= 1'b0;
                    end
                    state <= STATE_IDLE;
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end else begin
            // 当流水线停滞时，保持当前状态
            // valid信号保持不变
        end
    end

endmodule