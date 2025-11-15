`include "common.v"

// DMA控制器模块
// 负责CPU和PE之间的直接内存数据传递
module dma_controller #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter NUM_PES = 4,
    parameter DMA_FIFO_DEPTH = 16
) (
    input  wire                        clk,
    input  wire                        rst_n,

    // OBI总线接口（从设备接口，用于配置DMA）
    input  wire                        req_i,
    input  wire                        we_i,
    input  wire [ADDR_WIDTH-1:0]       addr_i,
    input  wire [DATA_WIDTH-1:0]       wr_data_i,
    output reg  [DATA_WIDTH-1:0]       data_out_o,
    output reg                         gnt_o,
    output reg                         rvalid_o,

    // OBI总线接口（主设备接口，用于内存访问）
    output wire                        mem_req_o,
    output wire                        mem_we_o,
    output wire [ADDR_WIDTH-1:0]       mem_addr_o,
    output wire [DATA_WIDTH-1:0]       mem_data_out_o,
    input  wire [DATA_WIDTH-1:0]       mem_data_in_i,
    input  wire                        mem_gnt_i,
    input  wire                        mem_rvalid_i,

    // PE接口（用于PE数据传递）
    output wire                        pe_dma_req_o,      // DMA请求到PE
    output wire                        pe_dma_we_o,       // DMA写使能到PE
    output wire [ADDR_WIDTH-1:0]       pe_dma_addr_o,     // DMA地址到PE
    output wire [DATA_WIDTH-1:0]       pe_dma_data_o,     // DMA数据到PE
    input  wire                        pe_dma_ack_i,      // PE DMA应答
    input  wire [DATA_WIDTH-1:0]       pe_dma_data_i,     // PE数据到DMA

    // 中断接口
    output wire                        dma_irq_o          // DMA完成中断
);

    // DMA寄存器地址定义
    localparam DMA_CTRL_ADDR        = 8'h00;  // DMA控制寄存器
    localparam DMA_SRC_ADDR_ADDR    = 8'h04;  // 源地址寄存器
    localparam DMA_DST_ADDR_ADDR    = 8'h08;  // 目标地址寄存器
    localparam DMA_LENGTH_ADDR      = 8'h0C;  // 传输长度寄存器
    localparam DMA_STATUS_ADDR      = 8'h10;  // 状态寄存器
    localparam DMA_PE_SEL_ADDR      = 8'h14;  // PE选择寄存器

    // DMA控制寄存器位定义
    localparam DMA_CTRL_START_BIT   = 0;      // 启动传输
    localparam DMA_CTRL_DIR_BIT     = 1;      // 传输方向 (0: CPU->PE, 1: PE->CPU)
    localparam DMA_CTRL_IE_BIT      = 2;      // 中断使能
    localparam DMA_CTRL_BURST_BIT   = 3;      // 突发传输模式

    // DMA状态寄存器位定义
    localparam DMA_STATUS_BUSY_BIT  = 0;      // DMA忙状态
    localparam DMA_STATUS_DONE_BIT  = 1;      // 传输完成
    localparam DMA_STATUS_ERROR_BIT = 2;      // 传输错误

    // 内部寄存器
    reg [DATA_WIDTH-1:0] dma_ctrl_reg;        // DMA控制寄存器
    reg [ADDR_WIDTH-1:0] dma_src_addr_reg;    // 源地址寄存器
    reg [ADDR_WIDTH-1:0] dma_dst_addr_reg;    // 目标地址寄存器
    reg [DATA_WIDTH-1:0] dma_length_reg;      // 传输长度寄存器
    reg [DATA_WIDTH-1:0] dma_status_reg;      // 状态寄存器
    reg [NUM_PES-1:0]    dma_pe_sel_reg;      // PE选择寄存器

    // DMA状态机状态定义
    localparam DMA_IDLE     = 2'b00;
    localparam DMA_READ     = 2'b01;
    localparam DMA_WRITE    = 2'b10;
    localparam DMA_DONE     = 2'b11;

    reg [1:0] dma_state;
    reg [ADDR_WIDTH-1:0] current_addr;
    reg [DATA_WIDTH-1:0] remaining_length;
    reg [NUM_PES-1:0]    current_pe;

    // FIFO相关信号
    wire [DATA_WIDTH-1:0] fifo_data_in;
    wire [DATA_WIDTH-1:0] fifo_data_out;
    wire                  fifo_wr_en;
    wire                  fifo_rd_en;
    wire                  fifo_full;
    wire                  fifo_empty;

    // 寄存器访问控制
    wire [7:0] reg_addr = addr_i[7:0];
    wire       cs_valid = req_i;

    // DMA控制逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dma_ctrl_reg     <= 0;
            dma_src_addr_reg <= 0;
            dma_dst_addr_reg <= 0;
            dma_length_reg   <= 0;
            dma_status_reg   <= 0;
            dma_pe_sel_reg   <= 0;
            dma_state        <= DMA_IDLE;
            current_addr     <= 0;
            remaining_length <= 0;
            current_pe       <= 0;
        end else begin
            // 寄存器写入
            if (cs_valid && we_i) begin
                case (reg_addr)
                    DMA_CTRL_ADDR: begin
                        dma_ctrl_reg <= wr_data_i;
                        // 如果设置了START位，启动DMA传输
                        if (wr_data_i[DMA_CTRL_START_BIT] && !dma_status_reg[DMA_STATUS_BUSY_BIT]) begin
                            dma_state                           <= DMA_READ;
                            current_addr                        <= dma_src_addr_reg;
                            remaining_length                    <= dma_length_reg;
                            current_pe                          <= dma_pe_sel_reg;
                            dma_status_reg[DMA_STATUS_BUSY_BIT] <= 1'b1;
                            dma_status_reg[DMA_STATUS_DONE_BIT] <= 1'b0;
                        end
                    end
                    DMA_SRC_ADDR_ADDR: dma_src_addr_reg <= wr_data_i;
                    DMA_DST_ADDR_ADDR: dma_dst_addr_reg <= wr_data_i;
                    DMA_LENGTH_ADDR:   dma_length_reg   <= wr_data_i;
                    DMA_PE_SEL_ADDR:   dma_pe_sel_reg   <= wr_data_i[NUM_PES-1:0];
                endcase
            end

            // DMA状态机
            case (dma_state)
                DMA_IDLE: begin
                    // 等待启动
                end

                DMA_READ: begin
                    if (mem_gnt_i && !fifo_full) begin
                        // 发起内存读取
                        if (remaining_length > 0) begin
                            current_addr     <= current_addr + 4; // 32位地址递增
                            remaining_length <= remaining_length - 1;
                        end else begin
                            dma_state <= DMA_WRITE;
                        end
                    end
                end

                DMA_WRITE: begin
                    if (mem_rvalid_i && !fifo_empty) begin
                        // 写入到PE或内存
                        if (dma_ctrl_reg[DMA_CTRL_DIR_BIT]) begin
                            // PE->CPU方向：从PE读取数据写入内存
                            if (remaining_length > 0) begin
                                current_addr     <= current_addr + 4;
                                remaining_length <= remaining_length - 1;
                            end else begin
                                dma_state <= DMA_DONE;
                            end
                        end else begin
                            // CPU->PE方向：从内存读取数据写入PE
                            if (remaining_length > 0) begin
                                current_addr     <= current_addr + 4;
                                remaining_length <= remaining_length - 1;
                            end else begin
                                dma_state <= DMA_DONE;
                            end
                        end
                    end
                end

                DMA_DONE: begin
                    dma_status_reg[DMA_STATUS_BUSY_BIT] <= 1'b0;
                    dma_status_reg[DMA_STATUS_DONE_BIT] <= 1'b1;
                    dma_state                           <= DMA_IDLE;
                end
            endcase

            // 清除完成标志
            if (cs_valid && we_i && reg_addr == DMA_CTRL_ADDR && wr_data_i[DMA_CTRL_START_BIT]) begin
                dma_status_reg[DMA_STATUS_DONE_BIT] <= 1'b0;
            end
        end
    end

    // 寄存器读取
    always @(*) begin
        if (cs_valid && !we_i) begin
            case (reg_addr)
                DMA_CTRL_ADDR:     data_out_o = dma_ctrl_reg;
                DMA_SRC_ADDR_ADDR: data_out_o = dma_src_addr_reg;
                DMA_DST_ADDR_ADDR: data_out_o = dma_dst_addr_reg;
                DMA_LENGTH_ADDR:   data_out_o = dma_length_reg;
                DMA_STATUS_ADDR:   data_out_o = dma_status_reg;
                DMA_PE_SEL_ADDR:   data_out_o = {{(DATA_WIDTH-NUM_PES){1'b0}}, dma_pe_sel_reg};
                default:           data_out_o = 32'h0;
            endcase
        end else begin
            data_out_o = 32'h0;
        end
    end

    // OBI协议信号
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gnt_o    <= 1'b0;
            rvalid_o <= 1'b0;
        end else begin
            gnt_o    <= req_i; // 立即授权
            rvalid_o <= req_i && !we_i; // 读操作时设置rvalid
        end
    end

    // 内存接口控制
    assign mem_req_o      = (dma_state == DMA_READ || dma_state == DMA_WRITE) && remaining_length > 0;
    assign mem_we_o       = dma_ctrl_reg[DMA_CTRL_DIR_BIT] && (dma_state == DMA_WRITE); // PE->CPU方向时写内存
    assign mem_addr_o     = current_addr;
    assign mem_data_out_o = fifo_data_out;

    // PE接口控制
    assign pe_dma_req_o  = (dma_state == DMA_READ || dma_state == DMA_WRITE) &&
                         remaining_length > 0 && |current_pe;
    assign pe_dma_we_o   = !dma_ctrl_reg[DMA_CTRL_DIR_BIT] && (dma_state == DMA_WRITE); // CPU->PE方向时写PE
    assign pe_dma_addr_o = current_addr;
    assign pe_dma_data_o = fifo_data_out;

    // FIFO实例化（用于数据缓冲）
    fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(DMA_FIFO_DEPTH)
    ) u_dma_fifo (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en_i(fifo_wr_en),
        .rd_en_i(fifo_rd_en),
        .data_in_i(fifo_data_in),
        .data_out_o(fifo_data_out),
        .full_o(fifo_full),
        .empty_o(fifo_empty)
    );

    // FIFO控制逻辑
    assign fifo_wr_en   = (dma_state == DMA_READ && mem_rvalid_i) ||
                       (dma_state == DMA_WRITE && pe_dma_ack_i);
    assign fifo_rd_en   = (dma_state == DMA_WRITE && mem_gnt_i) ||
                       (dma_state == DMA_READ && pe_dma_ack_i);
    assign fifo_data_in = (dma_state == DMA_READ) ? mem_data_in_i :
                          (dma_state == DMA_WRITE) ? pe_dma_data_i : 0;

    // 中断生成
    assign dma_irq_o = dma_status_reg[DMA_STATUS_DONE_BIT] && dma_ctrl_reg[DMA_CTRL_IE_BIT];

endmodule