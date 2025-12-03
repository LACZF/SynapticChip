
// 中断控制器模块
// 负责将各个外设的中断信号转换为CPU可识别的中断请求和中断号
// 支持OBI总线接口，用于软件配置中断使能、优先级等
module ip4_irq_controller #(
    parameter NUM_IRQ_SOURCES = 32  // 支持的最大中断源数量
) (
    input  wire                       clk,
    input  wire                       rst_n,

    // 中断源输入
    input  wire [NUM_IRQ_SOURCES-1:0] irq_sources_i,  // 各个外设的中断信号

    // CPU中断接口
    output wire                       int_req_o,        // 中断请求信号
    output wire [7:0]                 int_id_o,          // 中断号

    // OBI总线接口
    input  wire                       req_i,           // 总线请求信号
    input  wire                       we_i,            // 写使能信号
    input  wire [31:0]                addr_i,          // 地址总线
    input  wire [31:0]                wr_data_i,       // 写入数据总线
    output reg  [31:0]                data_out_o,       // 读出数据总线
    output reg                        gnt_o,            // 授权信号
    output reg                        rvalid_o          // 读有效信号
);

    // OBI总线握手信号
    wire [7:0] reg_addr;       // 寄存器地址

    // 中断使能寄存器
    reg [NUM_IRQ_SOURCES-1:0] irq_enable;

    // 中断挂起寄存器
    reg [NUM_IRQ_SOURCES-1:0] irq_pending;

    // 中断优先级寄存器（每个中断源4位优先级）
    reg [NUM_IRQ_SOURCES*4-1:0] irq_priority;

    // 当前活动的中断
    reg [7:0] current_irq_id;
    reg       current_irq_valid;

    // 中断源同步寄存器（避免亚稳态）
    reg [NUM_IRQ_SOURCES-1:0] irq_sources_sync0;
    reg [NUM_IRQ_SOURCES-1:0] irq_sources_sync1;

    // 边沿检测
    reg [NUM_IRQ_SOURCES-1:0] irq_sources_prev;
    wire [NUM_IRQ_SOURCES-1:0] irq_rising_edge;

    // 寄存器地址提取
    assign reg_addr = addr_i[7:0];

    // OBI总线握手逻辑
    reg                             rvalid_q;
    assign gnt_o = req_i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rvalid_q <= 1'b0;
        end else begin
            rvalid_q <= req_i;
        end
    end

    assign rvalid_o = rvalid_q;

    // 同步中断源信号
    always @(posedge clk) begin
        if (!rst_n) begin
            irq_sources_sync0 <= {NUM_IRQ_SOURCES{1'b0}};
            irq_sources_sync1 <= {NUM_IRQ_SOURCES{1'b0}};
            irq_sources_prev  <= {NUM_IRQ_SOURCES{1'b0}};
        end else begin
            irq_sources_sync0 <= irq_sources_i;
            irq_sources_sync1 <= irq_sources_sync0;
            irq_sources_prev  <= irq_sources_sync1;
        end
    end

    // 检测上升沿
    assign irq_rising_edge = irq_sources_sync1 & ~irq_sources_prev;

    // 中断挂起逻辑 - 修复Yosys综合错误（合并到单一always块中）
    wire [NUM_IRQ_SOURCES-1:0] new_irq_mask;
    assign new_irq_mask = irq_rising_edge & irq_enable;

    // 中断仲裁逻辑 - 选择最高优先级的中断
    integer i;
    reg found;
    always @(*) begin
        current_irq_id = 8'h00;
        current_irq_valid = 1'b0;
        found = 1'b0;

        // 简单的固定优先级仲裁（低编号中断优先级高）
        for (i = 0; i < NUM_IRQ_SOURCES; i = i + 1) begin
            if (!found && irq_pending[i] && irq_enable[i]) begin
                current_irq_id = i[7:0];
                current_irq_valid = 1'b1;
                found = 1'b1;
            end
        end
    end

    // 输出中断请求和中断号
    assign int_req_o = current_irq_valid;
    assign int_id_o = current_irq_id;

    // 合并的寄存器控制和中断挂起逻辑 - 修复Yosys综合错误
    always @(posedge clk) begin
        if (!rst_n) begin
            irq_enable <= {NUM_IRQ_SOURCES{1'b0}};
            irq_priority <= {NUM_IRQ_SOURCES*4{1'b0}};
            irq_pending <= {NUM_IRQ_SOURCES{1'b0}};
        end else begin
            irq_pending <= irq_pending | new_irq_mask;
            if (req_i) begin
                if (we_i) begin
                    case (reg_addr)
                        8'h00: irq_enable <= wr_data_i[NUM_IRQ_SOURCES-1:0];  // 中断使能寄存器
                        8'h04: irq_pending <= irq_pending & (~wr_data_i[NUM_IRQ_SOURCES-1:0]); // 中断挂起寄存器（清除指定的挂起位）
                        8'h08: irq_priority[31:0] <= wr_data_i;              // 优先级寄存器0
                        8'h0C: irq_priority[63:32] <= wr_data_i;              // 优先级寄存器1
                        // 可以继续添加更多优先级寄存器
                    endcase
                end else begin
                    case (reg_addr)
                        8'h00: data_out_o = {{(32-NUM_IRQ_SOURCES){1'b0}}, irq_enable};  // 中断使能寄存器
                        8'h04: data_out_o = {{(32-NUM_IRQ_SOURCES){1'b0}}, irq_pending}; // 中断挂起寄存器
                        8'h08: data_out_o = irq_priority[31:0];                          // 优先级寄存器0
                        8'h0C: data_out_o = irq_priority[63:32];                          // 优先级寄存器1
                        default: data_out_o = 32'h0;
                    endcase
                end
            end
        end
    end
endmodule