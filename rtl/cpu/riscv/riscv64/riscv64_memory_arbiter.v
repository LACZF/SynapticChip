// riscv64_memory_arbiter.v
// 简化可靠版内存仲裁器实现
module riscv64_memory_arbiter #(
    parameter NUM_MASTERS                        = 2,
    parameter ADDR_WIDTH                         = 64,
    parameter DATA_WIDTH                         = 64
) (
    input wire                                   clk,
    input wire                                   rst_n,

    // 主设备接口
    input  wire [NUM_MASTERS-1:0]                master_req_i,
    input  wire [NUM_MASTERS*ADDR_WIDTH-1:0]     master_addr_i,
    input  wire [NUM_MASTERS*DATA_WIDTH-1:0]     master_wdata_i,
    input  wire [NUM_MASTERS-1:0]                master_we_i,
    input  wire [NUM_MASTERS*8-1:0]              master_byte_en_i,
    output wire [NUM_MASTERS-1:0]                master_grant_o,

    // 内存接口
    output reg  [ADDR_WIDTH-1:0]                 mem_addr_o,
    output reg  [DATA_WIDTH-1:0]                 mem_wdata_o,
    input  wire [DATA_WIDTH-1:0]                 mem_rdata_i,
    output reg                                   mem_we_o,
    output reg [7:0]                             mem_byte_en_o,
    output reg                                   mem_req_o,
    input  wire                                  mem_ready_i
);

    // 内部信号定义
    reg [NUM_MASTERS-1:0] grant_reg;   // 授权寄存器
    reg [2:0]             state;       // 状态寄存器

    // 状态定义
    localparam STATE_IDLE      = 3'b000; // 空闲状态
    localparam STATE_ARBITRATE = 3'b001; // 仲裁状态
    localparam STATE_ACCESS    = 3'b010; // 访问状态

    // 简化可靠版固定优先级仲裁器实现
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 异步复位，清除所有寄存器
            state <= STATE_IDLE;
            grant_reg <= {NUM_MASTERS{1'b0}};
            mem_req_o <= 1'b0;
            mem_addr_o <= {ADDR_WIDTH{1'b0}};
            mem_wdata_o <= {DATA_WIDTH{1'b0}};
            mem_we_o <= 1'b0;
            mem_byte_en_o <= 8'b0;
        end else begin
            case (state)
                // 空闲状态：等待主设备请求
                STATE_IDLE: begin
                    // 清除授权寄存器和内存请求信号
                    grant_reg <= {NUM_MASTERS{1'b0}};
                    mem_req_o <= 1'b0;

                    // 当有主设备请求时，进入仲裁状态
                    if (|master_req_i) begin
                        state <= STATE_ARBITRATE;
                    end
                end

                // 仲裁状态：选择一个主设备授予访问权
                STATE_ARBITRATE: begin
                    // 清除授权寄存器
                    grant_reg <= {NUM_MASTERS{1'b0}};

                    // 固定优先级仲裁 - j=0优先级最高
                    if (master_req_i[0]) begin
                        // 授予Master 0访问权
                        grant_reg[0] <= 1'b1;
                        mem_addr_o <= master_addr_i[0*ADDR_WIDTH +: ADDR_WIDTH];
                        mem_wdata_o <= master_wdata_i[0*DATA_WIDTH +: DATA_WIDTH];
                        mem_we_o <= master_we_i[0];
                        mem_byte_en_o <= master_byte_en_i[0*8 +: 8];
                        mem_req_o <= 1'b1;
                        state <= STATE_ACCESS;
                    end else if (master_req_i[1]) begin
                        // 授予Master 1访问权
                        grant_reg[1] <= 1'b1;
                        mem_addr_o <= master_addr_i[1*ADDR_WIDTH +: ADDR_WIDTH];
                        mem_wdata_o <= master_wdata_i[1*DATA_WIDTH +: DATA_WIDTH];
                        mem_we_o <= master_we_i[1];
                        mem_byte_en_o <= master_byte_en_i[1*8 +: 8];
                        mem_req_o <= 1'b1;
                        state <= STATE_ACCESS;
                    end else begin
                        // 如果没有请求，返回空闲状态
                        state <= STATE_IDLE;
                    end
                end

                // 访问状态：等待内存访问完成
                STATE_ACCESS: begin
                    if (mem_ready_i) begin
                        // 内存访问完成，清除所有相关信号
                        mem_req_o <= 1'b0;
                        state <= STATE_IDLE;
                        grant_reg <= {NUM_MASTERS{1'b0}};
                    end else begin
                        // 确保在访问状态中保持内存请求信号为1
                        mem_req_o <= 1'b1;
                        // 确保保持授权信号为1
                        // 如果主设备撤销了请求，我们仍然完成当前的访问
                    end
                end

                // 默认状态：安全处理
                default: begin
                    // 如果进入未知状态，重置到空闲状态
                    state <= STATE_IDLE;
                    grant_reg <= {NUM_MASTERS{1'b0}};
                    mem_req_o <= 1'b0;
                end
            endcase
        end
    end

    // 输出授权信号
    assign master_grant_o = grant_reg;

endmodule