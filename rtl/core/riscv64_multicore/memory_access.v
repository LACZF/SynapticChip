// memory_access.v
`include "cache_params.v"

module memory_access (
    input wire clk,
    input wire rst_n,
    input wire stall,
    input wire flush,

    // 来自执行阶段
    input wire [63:0] pc_in,
    input wire [31:0] instr_in,
    input wire [63:0] alu_result,
    input wire [63:0] rs2_data,
    input wire [15:0] ctrl_in,

    // 缓存接口
    output reg cache_req,
    output reg [63:0] cache_addr,
    output reg [63:0] cache_wdata,
    input wire [63:0] cache_rdata,
    output reg cache_we,
    output reg [7:0] cache_byte_en,
    input wire cache_ready,

    // 输出到写回阶段
    output reg [63:0] pc_out,
    output reg [31:0] instr_out,
    output reg [63:0] mem_result,
    output reg [15:0] ctrl_out
);

    // 控制信号解码
    wire mem_read = ctrl_in[9];  // 内存读使能
    wire mem_write = ctrl_in[8]; // 内存写使能
    wire [2:0] mem_width = ctrl_in[7:5]; // 内存访问宽度
    wire is_load = ctrl_in[9];
    wire is_store = ctrl_in[8];
    wire [6:0] opcode = instr_in[6:0];

    // 内部状态机
    reg [2:0] state;
    reg [63:0] saved_alu_result;
    reg [63:0] saved_rs2_data;
    reg [2:0] saved_mem_width;
    reg is_load_saved;
    reg is_store_saved;

    localparam STATE_IDLE = 3'b000;
    localparam STATE_READ_REQ = 3'b001;
    localparam STATE_READ_WAIT = 3'b010;
    localparam STATE_WRITE_REQ = 3'b011;
    localparam STATE_WRITE_WAIT = 3'b100;
    localparam STATE_COMPLETE = 3'b101;

    // 字节使能生成
    function [7:0] generate_byte_en;
        input [2:0] width;
        input [2:0] offset;
        begin
            case (width)
                3'b000: generate_byte_en = 8'b00000001 << offset; // 字节访问
                3'b001: generate_byte_en = 8'b00000011 << offset; // 半字访问
                3'b010: generate_byte_en = 8'b00001111 << offset; // 字访问
                3'b011: generate_byte_en = 8'b11111111;          // 双字访问
                default: generate_byte_en = 8'b11111111;
            endcase
        end
    endfunction

    // 数据对齐和符号扩展
    function [63:0] align_and_extend;
        input [63:0] data;
        input [2:0] width;
        input [2:0] offset;
        input is_signed;
        reg [63:0] aligned_data;
        begin
            // 根据偏移量对齐数据
            aligned_data = data >> (offset * 8);

            case (width)
                3'b000: begin // LB, LBU
                    if (is_signed) begin
                        align_and_extend = {{56{aligned_data[7]}}, aligned_data[7:0]};
                    end else begin
                        align_and_extend = {56'b0, aligned_data[7:0]};
                    end
                end
                3'b001: begin // LH, LHU
                    if (is_signed) begin
                        align_and_extend = {{48{aligned_data[15]}}, aligned_data[15:0]};
                    end else begin
                        align_and_extend = {48'b0, aligned_data[15:0]};
                    end
                end
                3'b010: begin // LW, LWU
                    if (is_signed) begin
                        align_and_extend = {{32{aligned_data[31]}}, aligned_data[31:0]};
                    end else begin
                        align_and_extend = {32'b0, aligned_data[31:0]};
                    end
                end
                3'b011: begin // LD
                    align_and_extend = aligned_data;
                end
                default: align_and_extend = aligned_data;
            endcase
        end
    endfunction

    // 存储数据对齐
    function [63:0] align_store_data;
        input [63:0] data;
        input [2:0] width;
        input [2:0] offset;
        reg [63:0] aligned_data;
        begin
            aligned_data = data;
            case (width)
                3'b000: aligned_data = {56'b0, data[7:0]}; // 字节
                3'b001: aligned_data = {48'b0, data[15:0]}; // 半字
                3'b010: aligned_data = {32'b0, data[31:0]}; // 字
                3'b011: aligned_data = data; // 双字
                default: aligned_data = data;
            endcase

            // 左移到位
            align_store_data = aligned_data << (offset * 8);
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
        end else if (flush) begin
            state <= STATE_IDLE;
            cache_req <= 1'b0;
            cache_we <= 1'b0;
            instr_out <= 32'h00000013; // 插入NOP
            ctrl_out <= 16'b0;
        end else if (stall) begin
            // 保持状态
        end else begin
            case (state)
                STATE_IDLE: begin
                    pc_out <= pc_in;
                    instr_out <= instr_in;
                    ctrl_out <= ctrl_in;

                    if (is_load || is_store) begin
                        saved_alu_result <= alu_result;
                        saved_rs2_data <= rs2_data;
                        saved_mem_width <= mem_width;
                        is_load_saved <= is_load;
                        is_store_saved <= is_store;

                        cache_addr <= alu_result;
                        cache_byte_en <= generate_byte_en(mem_width, alu_result[2:0]);

                        if (is_load) begin
                            state <= STATE_READ_REQ;
                            cache_req <= 1'b1;
                            cache_we <= 1'b0;
                        end else begin // is_store
                            state <= STATE_WRITE_REQ;
                            cache_req <= 1'b1;
                            cache_we <= 1'b1;
                            cache_wdata <= align_store_data(rs2_data, mem_width, alu_result[2:0]);
                        end
                    end else begin
                        // 非内存指令，直接传递ALU结果
                        mem_result <= alu_result;
                        state <= STATE_COMPLETE;
                    end
                end

                STATE_READ_REQ: begin
                    if (cache_ready) begin
                        // 缓存就绪，处理读取数据
                        mem_result <= align_and_extend(cache_rdata, saved_mem_width,
                                                     saved_alu_result[2:0],
                                                     instr_out[14:12] != 3'b100); // 有符号扩展判断
                        cache_req <= 1'b0;
                        state <= STATE_COMPLETE;
                    end else begin
                        state <= STATE_READ_WAIT;
                    end
                end

                STATE_READ_WAIT: begin
                    if (cache_ready) begin
                        mem_result <= align_and_extend(cache_rdata, saved_mem_width,
                                                     saved_alu_result[2:0],
                                                     instr_out[14:12] != 3'b100);
                        cache_req <= 1'b0;
                        state <= STATE_COMPLETE;
                    end
                end

                STATE_WRITE_REQ: begin
                    if (cache_ready) begin
                        // 存储完成
                        mem_result <= saved_alu_result; // 存储指令返回地址
                        cache_req <= 1'b0;
                        cache_we <= 1'b0;
                        state <= STATE_COMPLETE;
                    end else begin
                        state <= STATE_WRITE_WAIT;
                    end
                end

                STATE_WRITE_WAIT: begin
                    if (cache_ready) begin
                        mem_result <= saved_alu_result;
                        cache_req <= 1'b0;
                        cache_we <= 1'b0;
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
