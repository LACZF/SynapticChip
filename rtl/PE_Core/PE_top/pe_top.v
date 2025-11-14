
module pe_top #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter NUM_PES = 4,
    parameter INST_WIDTH = 32,
    parameter PE_ID_WIDTH = 4,
    parameter PE_ARRAY_ROWS = 2,
    parameter PE_ARRAY_COLS = 2
) (
    input                                     clk,
    input                                     rst_n,

    // OBI总线接口
    input                                     req_i,
    input                                     we_i,
    input  [ADDR_WIDTH-1:0]                   addr_i,
    input  [DATA_WIDTH-1:0]                   wr_data_i,
    output [DATA_WIDTH-1:0]                   rd_data_o,
    output                                    gnt_o,
    output                                    rvalid_o,

    // 直接内存接口（pe_top_new作为发起者，RAM作为响应者）
    output                                    mem_req_o,           // 内存请求信号（发起者）
    output                                    mem_we_o,            // 内存写使能（发起者）
    output [ADDR_WIDTH-1:0]                   mem_addr_o,          // 内存地址（发起者）
    output [(PE_ARRAY_ROWS+3)*PE_ARRAY_COLS*DATA_WIDTH-1:0] mem_data_o,          // 内存写入数据（发起者，与pe_mem完整位宽一致）
    input                                     mem_ack_i,           // 内存应答信号（响应者）
    input  [(PE_ARRAY_ROWS+3)*PE_ARRAY_COLS*DATA_WIDTH-1:0] mem_data_i,          // 内存读取数据（响应者，与pe_mem完整位宽一致）

    // IRQ interface
    output [NUM_PES-1:0]                      pe_irq_o,           // PE IRQ输出信号
    output [(NUM_PES*8)-1:0]                  pe_irq_id_o         // PE IRQ ID输出
);

    // 地址定义
    localparam int PE_CTRL_ADDR        = 32'h0000_0000;     // PE控制寄存器
    localparam int PE_STATUS_ADDR      = 32'h0000_0004;     // PE状态寄存器
    localparam int PE_MEM_ADDR         = 32'h0000_0008;     // PE内存访问地址
    localparam int PE_MEM_DMA_ADDR     = 32'h0000_000C;     // PE内存DMA控制寄存器
    localparam int PE_START_ADDR       = 32'h0000_0010;     // PE开始计算命令

    // 内存模块定义
    // mem模块：DATA_WIDTH位宽，PE_ARRAY_COLS列，PE_ARRAY_ROWS+3行
    localparam MEM_ROWS = PE_ARRAY_ROWS + 3;
    localparam MEM_COLS = PE_ARRAY_COLS;

    reg [DATA_WIDTH-1:0] pe_mem [0:MEM_ROWS-1][0:MEM_COLS-1];

    // PE控制信号
    reg  [NUM_PES-1:0]   pe_enable;
    reg  [NUM_PES-1:0]   pe_busy;
    wire [NUM_PES-1:0]   pe_done;
    reg                  start_computation;

    // PE状态寄存器
    reg [DATA_WIDTH-1:0] status_reg;

    // DMA控制寄存器
    reg [ADDR_WIDTH-1:0] dma_addr_reg;      // DMA起始地址（低16位）
    reg [13:0]           dma_length_reg;    // DMA传输长度（中间14位）
    reg [1:0]            dma_cmd_reg;       // DMA命令（高2位：00=空闲，01=读，10=写）
    reg [DATA_WIDTH-1:0] dma_status_reg;    // DMA状态寄存器

    // PE计算结果
    wire [NUM_PES*DATA_WIDTH-1:0] pe_results;

    // 路由数据
    wire [NUM_PES*DATA_WIDTH-1:0] routed_data;

    // 路由配置信号（来自内存的最后一行）
    wire [NUM_PES*DATA_WIDTH-1:0] route_config;

    // PE控制信号
    wire [NUM_PES-1:0] pe_start;
    wire [DATA_WIDTH-1:0] op1_ctrl [0:PE_ARRAY_COLS-1];
    wire [DATA_WIDTH-1:0] op2_ctrl [0:PE_ARRAY_COLS-1];
    wire [DATA_WIDTH-1:0] config_ctrl [0:PE_ARRAY_ROWS-1][0:PE_ARRAY_COLS-1];

    // OBI总线处理
    wire [7:0] reg_offset = addr_i[7:0];
    wire       cs_valid   = req_i;

    // 读数据多路选择器
    reg [DATA_WIDTH-1:0] rd_data_reg;
    always @(*) begin
        case (reg_offset)
            PE_CTRL_ADDR:   rd_data_reg = {{(DATA_WIDTH-NUM_PES-1){1'b0}}, start_computation, pe_enable};
            PE_STATUS_ADDR: rd_data_reg = status_reg;
            PE_MEM_ADDR:    rd_data_reg = pe_mem[addr_i[23:16]][addr_i[15:8]]; // 行地址[23:16], 列地址[15:8]
            PE_MEM_DMA_ADDR:rd_data_reg = dma_status_reg; // DMA状态寄存器
            default:        rd_data_reg = 32'b0;
        endcase
    end

    assign rd_data_o = rd_data_reg;

    // 写处理
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pe_enable <= {NUM_PES{1'b0}};
            start_computation <= 1'b0;
            status_reg <= 32'b0;
            dma_addr_reg <= 32'b0;
            dma_length_reg <= 14'b0;
            dma_cmd_reg <= 2'b00;
            dma_status_reg <= 32'b0;
            // 初始化内存
            for (integer i = 0; i < MEM_ROWS; i = i + 1) begin
                for (integer j = 0; j < MEM_COLS; j = j + 1) begin
                    pe_mem[i][j] <= 32'b0;
                end
            end
        end else begin
            start_computation <= 1'b0; // 单周期脉冲

            if (cs_valid && we_i) begin
                case (reg_offset)
                    PE_CTRL_ADDR: begin
                        pe_enable <= wr_data_i[NUM_PES-1:0];
                        start_computation <= wr_data_i[NUM_PES];
                    end
                    PE_MEM_ADDR: begin
                        pe_mem[addr_i[23:16]][addr_i[15:8]] <= wr_data_i;
                    end
                    PE_MEM_DMA_ADDR: begin
                        // 低16位作为DMA起始地址
                        dma_addr_reg <= {16'b0, wr_data_i[15:0]};
                        // 中间14位作为DMA传输长度
                        dma_length_reg <= wr_data_i[29:16];
                        // 高2位作为DMA命令
                        dma_cmd_reg <= wr_data_i[31:30];
                    end
                endcase
            end

            // 更新状态寄存器
            status_reg <= {pe_busy, pe_enable, {(DATA_WIDTH-NUM_PES*2){1'b0}}};
        end
    end

    // DMA状态机相关寄存器
    reg [2:0] dma_state;                   // DMA状态：0=空闲，1=传输中，2=完成

    // OBI协议信号
    assign gnt_o = req_i;

    reg rvalid_d;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rvalid_d <= 1'b0;
        end else begin
            // DMA完成后才将rvalid_d置位1，避免DMA期间CPU对RAM有其他操作
            rvalid_d <= req_i && (dma_state == 3'b000);
        end
    end
    assign rvalid_o = rvalid_d;
    reg [13:0] dma_counter;                 // DMA传输计数器
    reg [ADDR_WIDTH-1:0] dma_current_addr; // DMA当前地址

    // DMA内存接口信号
    reg dma_mem_req_reg;
    reg dma_mem_we_reg;
    reg [ADDR_WIDTH-1:0] dma_mem_addr_reg;
    reg dma_mem_pending;

    // 直接内存访问逻辑
    reg mem_req_reg;
    reg mem_we_reg;
    reg [ADDR_WIDTH-1:0] mem_addr_reg;
    reg mem_pending;

    // DMA状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dma_state <= 3'b000; // 空闲状态
            dma_counter <= 14'b0;
            dma_current_addr <= 32'b0;
            dma_status_reg <= 32'b0;
            dma_mem_req_reg <= 1'b0;
            dma_mem_we_reg <= 1'b0;
            dma_mem_addr_reg <= 32'b0;
            dma_mem_pending <= 1'b0;
        end else begin
            case (dma_state)
                3'b000: begin // 空闲状态
                    if (dma_cmd_reg != 2'b00) begin // 收到DMA命令
                        dma_state <= 3'b001; // 进入传输状态
                        dma_counter <= dma_length_reg;
                        dma_current_addr <= dma_addr_reg;
                        dma_status_reg <= {30'b0, 2'b01}; // 状态：传输中
                    end
                end

                3'b001: begin // 传输状态
                    if (dma_counter == 14'b0) begin
                        dma_state <= 3'b010; // 传输完成
                        dma_status_reg <= {30'b0, 2'b10}; // 状态：完成
                    end else if (!dma_mem_pending) begin // 可以发起新的DMA内存请求
                        // 发起DMA内存请求
                        dma_mem_req_reg <= 1'b1;
                        dma_mem_we_reg <= (dma_cmd_reg == 2'b10) ? 1'b1 : 1'b0; // 10=写，01=读
                        dma_mem_addr_reg <= dma_current_addr;

                        // 如果是写操作，将整个PE内存打包输出
                        // 数据直接通过pe_mem连接到mem_data_o，无需中间寄存器

                        dma_mem_pending <= 1'b1;
                    end
                end

                3'b010: begin // 完成状态
                    dma_cmd_reg <= 2'b00; // 清除DMA命令
                    dma_state <= 3'b000; // 返回空闲状态
                    dma_status_reg <= {30'b0, 2'b00}; // 状态：空闲
                end

                default: begin
                    dma_state <= 3'b000;
                end
            endcase

            // DMA内存访问完成处理
            if (mem_ack_i && dma_state == 3'b001 && dma_mem_pending) begin
                // 如果是读操作，将读取的数据写入整个PE内存
                if (dma_cmd_reg == 2'b01) begin
                    for (int row = 0; row < MEM_ROWS; row = row + 1) begin
                        for (int col = 0; col < MEM_COLS; col = col + 1) begin
                            // 使用位拼接和移位操作替代位选择
                            pe_mem[row][col] <= (mem_data_i >> ((row * MEM_COLS + col) * DATA_WIDTH)) & ((1 << DATA_WIDTH) - 1);
                        end
                    end
                end

                // 更新DMA计数器
                dma_counter <= dma_counter - 14'b1;
                dma_current_addr <= dma_current_addr + 4; // 每次传输32位数据，地址递增4字节

                dma_mem_req_reg <= 1'b0;
                dma_mem_pending <= 1'b0;
            end
        end
    end

    // OBI总线内存访问状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_req_reg <= 1'b0;
            mem_we_reg <= 1'b0;
            mem_addr_reg <= 32'b0;
            mem_pending <= 1'b0;
        end else begin
            // 如果有OBI总线内存访问请求且当前没有挂起的请求
            if (req_i && !mem_pending) begin
                mem_req_reg <= 1'b1;
                mem_we_reg <= we_i;
                mem_addr_reg <= addr_i;

                // 如果是写操作，将整个PE内存打包输出
                // 数据直接通过pe_mem连接到mem_data_o，无需中间寄存器

                mem_pending <= 1'b1;
            end

            // OBI总线内存访问完成
            if (mem_ack_i && mem_pending) begin
                // 如果是读操作，将读取的数据写入整个PE内存
                if (!mem_we_reg) begin
                    for (int row = 0; row < MEM_ROWS; row = row + 1) begin
                        for (int col = 0; col < MEM_COLS; col = col + 1) begin
                            // 使用位拼接和移位操作替代位选择
                            pe_mem[row][col] <= (mem_data_i >> ((row * MEM_COLS + col) * DATA_WIDTH)) & ((1 << DATA_WIDTH) - 1);
                        end
                    end
                end

                mem_req_reg <= 1'b0;
                mem_pending <= 1'b0;
            end
        end
    end

    // 内存接口仲裁逻辑
    // 优先级：DMA传输 > OBI总线访问
    assign mem_req_o  = dma_mem_req_reg ? dma_mem_req_reg  : mem_req_reg;
    assign mem_we_o   = dma_mem_req_reg ? dma_mem_we_reg   : mem_we_reg;
    assign mem_addr_o = dma_mem_req_reg ? dma_mem_addr_reg : mem_addr_reg;

    // mem_data_o直接与pe_mem对接，无需中间寄存器
    // 将PE内存打包输出到mem_data_o - 使用连接操作
    wire [MEM_ROWS*MEM_COLS*DATA_WIDTH-1:0] mem_data_o_temp;
    genvar m, n;
    generate
        for (m = 0; m < MEM_ROWS; m = m + 1) begin : mem_row
            for (n = 0; n < MEM_COLS; n = n + 1) begin : mem_col
                localparam idx = m * MEM_COLS + n;
                // 将每个pe_mem元素连接到临时信号的相应位置
                assign mem_data_o_temp[(idx+1)*DATA_WIDTH-1:idx*DATA_WIDTH] = pe_mem[m][n];
            end
        end
    endgenerate
    assign mem_data_o = mem_data_o_temp;

    // 路由配置：从内存的最后一行获取路由配置
    genvar k, l;
    generate
        for (k = 0; k < PE_ARRAY_ROWS; k = k + 1) begin : route_config_row
            for (l = 0; l < PE_ARRAY_COLS; l = l + 1) begin : route_config_col
                localparam pe_idx = k * PE_ARRAY_COLS + l;
                assign route_config[pe_idx*DATA_WIDTH +: DATA_WIDTH] = pe_mem[MEM_ROWS-1][l];
            end
        end
    endgenerate

    // PE控制模块实例化
    pe_ctrl #(
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_PES(NUM_PES),
        .PE_ARRAY_ROWS(PE_ARRAY_ROWS),
        .PE_ARRAY_COLS(PE_ARRAY_COLS)
    ) u_pe_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .pe_enable_i(pe_enable),
        .start_i(start_computation),
        .mem_data_i(pe_mem),
        .pe_start_o(pe_start),
        .op1_o(op1_ctrl),
        .op2_o(op2_ctrl),
        .config_o(config_ctrl)
    );

    // 路由模块实例化
    pe_router #(
        .DATA_WIDTH(DATA_WIDTH),
        .PE_ARRAY_ROWS(PE_ARRAY_ROWS),
        .PE_ARRAY_COLS(PE_ARRAY_COLS)
    ) u_pe_router (
        .clk(clk),
        .rst_n(rst_n),
        .pe_done_i(pe_done),
        .pe_result_i(pe_results),
        .route_config_i(route_config),
        .pe_data_o(routed_data)
    );

    // PE阵列实例化
    genvar i, j;
    generate
        for (i = 0; i < PE_ARRAY_ROWS; i = i + 1) begin : pe_row
            for (j = 0; j < PE_ARRAY_COLS; j = j + 1) begin : pe_col
                localparam pe_idx = i * PE_ARRAY_COLS + j;

                // PE输入信号 - 从控制模块获取（集中控制架构）
                wire [DATA_WIDTH-1:0] op1         = op1_ctrl[j];        // 操作数1
                wire [DATA_WIDTH-1:0] op2         = op2_ctrl[j];        // 操作数2
                wire [DATA_WIDTH-1:0] config_data = config_ctrl[i][j]; // 配置数据

                // PE输出信号
                wire [DATA_WIDTH-1:0] pe_result;
                wire pe_done_single;

                // 简化的PE模块
                pe #(
                    .DATA_WIDTH(DATA_WIDTH)
                ) u_simple_pe (
                    .clk(clk),
                    .rst_n(rst_n),
                    .enable_i(pe_enable[pe_idx]),
                    .start_i(pe_start[pe_idx]),
                    .op1_i(op1),
                    .op2_i(op2),
                    .config_i(config_data),
                    .result_o(pe_result),
                    .done_o(pe_done_single),
                    .busy_o(pe_busy[pe_idx])
                );

                // 连接PE输出
                assign pe_results[pe_idx*DATA_WIDTH +: DATA_WIDTH] = pe_result;
                assign pe_done[pe_idx] = pe_done_single;

                // 将路由后的结果写入内存最后一行
                always @(posedge clk) begin
                    if (pe_done) begin
                        pe_mem[MEM_ROWS-1][j] <= routed_data[pe_idx*DATA_WIDTH +: DATA_WIDTH];
                    end
                end

                // IRQ生成
                assign pe_irq_o[pe_idx] = pe_done;
                assign pe_irq_id_o[pe_idx*8 +: 8] = pe_idx;
            end
        end
    endgenerate

    // 支持PE间数据路由的数据传递架构
    // 当PE完成计算时，结果通过路由模块传输到目标PE
    // 路由后的数据写入内存，其他PE可以从内存读取路由后的数据

endmodule