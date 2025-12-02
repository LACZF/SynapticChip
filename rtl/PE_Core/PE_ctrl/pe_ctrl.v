module ip0_pe_control #(
    parameter PE_ARRAY_X = 4,
    parameter PE_ARRAY_Y = 4,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16,
    parameter HIGH_BW_DW = 320
)(
    input  wire                                             clk,
    input  wire                                             rst_n,

    input  wire                                             req_i,
    input  wire                                             we_i,
    input  wire [31:0]                                      addr_i,
    input  wire [DATA_WIDTH-1:0]                            wdata_i,
    output reg                                              gnt_o,
    output reg                                              rvalid_o,
    output reg  [DATA_WIDTH-1:0]                            rdata_o,

    // PE Control - 集成控制逻辑
    output reg                                              start_computation,
    input  wire                                             computation_done,

    // 高带宽内存接口
    output reg                                              high_bw_req_o,
    output reg                                              high_bw_we_o,
    output reg  [31:0]                                      high_bw_addr_o,
    output reg  [HIGH_BW_DW-1:0]                            high_bw_data_o,
    input  wire                                             high_bw_ack_i,
    input  wire [HIGH_BW_DW-1:0]                            high_bw_data_i,

    // PE结果接口 - 直接写入内存
    input  wire [0:PE_ARRAY_X*PE_ARRAY_Y-1][DATA_WIDTH-1:0] pe_result,
    input  wire [0:PE_ARRAY_X*PE_ARRAY_Y-1]                 pe_result_valid,

    // PE操作数和配置输出 - 直接从内存读取
    output reg  [0:PE_ARRAY_X*PE_ARRAY_Y-1][DATA_WIDTH-1:0] pe_operand1,
    output reg  [0:PE_ARRAY_X*PE_ARRAY_Y-1][DATA_WIDTH-1:0] pe_operand2,
    output reg  [0:PE_ARRAY_X*PE_ARRAY_Y-1][DATA_WIDTH-1:0] pe_config
);

    // Memory organization:
    // [0:PE_ARRAY_X*PE_ARRAY_Y-1] - operand1
    // [PE_ARRAY_X*PE_ARRAY_Y:2*PE_ARRAY_X*PE_ARRAY_Y-1] - operand2
    // [2*PE_ARRAY_X*PE_ARRAY_Y:3*PE_ARRAY_X*PE_ARRAY_Y-1] - config
    // [3*PE_ARRAY_X*PE_ARRAY_Y:4*PE_ARRAY_X*PE_ARRAY_Y-1] - output

    localparam MEM_DEPTH = 4 * PE_ARRAY_X * PE_ARRAY_Y;
    reg [0:MEM_DEPTH-1][DATA_WIDTH-1:0] memory;

    // Control registers
    reg [DATA_WIDTH-1:0] control_reg;
    reg [DATA_WIDTH-1:0] status_reg;

    // Address mapping
    localparam CONTROL_REG_ADDR   = 24'h100000 >> 2;
    localparam STATUS_REG_ADDR    = 24'h100004 >> 2;
    localparam PE_ENABLE_ADDR     = 24'h100008 >> 2;
    localparam HIGH_BW_WRITE_ADDR = 24'h10000C >> 2;
    localparam HIGH_BW_READ_ADDR  = 24'h100010 >> 2;

    // 高带宽内存控制状态机
    typedef enum logic [1:0] {
        HIGH_BW_IDLE     = 2'b00,
        HIGH_BW_REQUEST  = 2'b01,
        HIGH_BW_WAIT_ACK = 2'b10,
        HIGH_BW_DONE     = 2'b11
    } high_bw_state_t;

    high_bw_state_t high_bw_state;

    // PE结果写回状态机
    typedef enum logic [1:0] {
        WRITE_BACK_IDLE   = 2'b00,
        WRITE_BACK_START  = 2'b01,
        WRITE_BACK_ACTIVE = 2'b10,
        WRITE_BACK_DONE   = 2'b11
    } write_back_state_t;

    write_back_state_t write_back_state;

    // PE结果写回计数器
    reg  [7:0]  pe_write_back_index;
    reg  [15:0] pe_write_back_addr;

    // 高带宽内存传输控制
    reg  [15:0] high_bw_transfer_length;
    reg  [15:0] high_bw_current_addr;
    reg  [15:0] high_bw_transfer_count;
    reg         high_bw_start;

    // 高带宽启动请求信号
    reg         high_bw_start_request;
    reg         high_bw_start_we;
    reg  [15:0] high_bw_start_length;
    reg  [15:0] high_bw_start_addr;

    // 地址拆分
    wire [23:0] addr_base       = (addr_i[23:0] >> 2);

    // Control register bits
    wire start_bit = control_reg[0];

    // Status register bits
    always @(*) begin
        status_reg = {31'b0, computation_done};
    end

    // OBI Bus FSM - 优化版本：单周期内存访问
    typedef enum logic [1:0] {
        IDLE      = 2'b00,
        GRANT     = 2'b01,
        RESPONSE  = 2'b10
    } obi_state_t;

    obi_state_t obi_state;

    // 地址寄存器，用于保持读取地址
    reg [ADDR_WIDTH-1:0] read_addr_reg;

    // OBI Bus Control - 优化版本：单周期完成内存访问
    always @(posedge clk) begin
        if (!rst_n) begin
            obi_state               <= IDLE;
            gnt_o                   <= 1'b0;
            rvalid_o                <= 1'b0;
            rdata_o                 <= {DATA_WIDTH{1'b0}};
            control_reg             <= {DATA_WIDTH{1'b0}};
            read_addr_reg           <= {ADDR_WIDTH{1'b0}};
            high_bw_we_o            <= 1'b0;
            high_bw_transfer_length <= 16'b0;
            high_bw_current_addr    <= 16'b0;
            high_bw_transfer_count  <= 16'b0;
            high_bw_start           <= 1'b0;
        end else begin
            case (obi_state)
                IDLE: begin
                    rvalid_o <= 1'b0;
                    gnt_o    <= 1'b0;

                    if (req_i) begin
                        gnt_o     <= 1'b1;
                        obi_state <= GRANT;

                        // 在GRANT状态立即处理读取操作
                        if (!we_i) begin
                            read_addr_reg <= addr_base;
                        end
                    end
                end

                GRANT: begin
                    gnt_o <= 1'b0;

                    // 处理写入操作 - 单周期完成
                    if (we_i) begin
                        case (addr_base)
                            CONTROL_REG_ADDR: control_reg <= wdata_i;
                            HIGH_BW_WRITE_ADDR: begin
                                // 高带宽内存写入请求
                                high_bw_start_request <= 1'b1;
                                high_bw_start_we      <= 1'b1;
                                high_bw_start_length  <= wdata_i[31:16];
                                high_bw_start_addr    <= wdata_i[15:0];
                            end
                            default: begin
                                // 直接写入内存
                                if (addr_base < MEM_DEPTH) begin
                                    memory[addr_base] <= wdata_i;
                                end
                            end
                        endcase

                        rdata_o <= {DATA_WIDTH{1'b0}};  // 写入操作返回0
                    end

                    // 处理读取操作 - 单周期完成
                    else begin
                        case (addr_base)
                            CONTROL_REG_ADDR: rdata_o <= control_reg;
                            STATUS_REG_ADDR:  rdata_o <= status_reg;
                            HIGH_BW_READ_ADDR: begin
                                // 高带宽内存读取请求
                                high_bw_start_request <= 1'b1;
                                high_bw_start_we      <= 1'b0;
                                high_bw_start_length  <= wdata_i[31:16];
                                high_bw_start_addr    <= wdata_i[15:0];
                                rdata_o <= {DATA_WIDTH{1'b0}};  // 高带宽读取返回0
                            end
                            default: begin
                                // 内存读取 - 直接读取当前值
                                if (addr_base < MEM_DEPTH) begin
                                    rdata_o <= memory[addr_base];
                                end else begin
                                    rdata_o <= {DATA_WIDTH{1'b0}};
                                end
                            end
                        endcase
                    end

                    // 所有操作在GRANT状态完成，直接进入RESPONSE
                    obi_state <= RESPONSE;
                    rvalid_o <= 1'b1;
                end

                RESPONSE: begin
                    // 等待请求撤销
                    if (!req_i) begin
                        rvalid_o  <= 1'b0;
                        obi_state <= IDLE;
                    end
                    // 如果请求仍然有效，保持响应状态
                end
            endcase
        end
    end

    // 高带宽启动请求处理 - 统一控制逻辑
    always @(posedge clk) begin
        if (!rst_n) begin
            high_bw_start          <= 1'b0;
            high_bw_we_o           <= 1'b0;
            high_bw_transfer_length <= 16'b0;
            high_bw_current_addr    <= 16'b0;
            high_bw_transfer_count <= 16'b0;
        end else begin
            // 清除启动信号，除非有新的请求
            high_bw_start <= 1'b0;

            // 处理高带宽启动请求
            if (high_bw_start_request) begin
                high_bw_start          <= 1'b1;
                high_bw_we_o           <= high_bw_start_we;
                high_bw_transfer_length <= high_bw_start_length;
                high_bw_current_addr    <= high_bw_start_addr;
                high_bw_transfer_count  <= 16'b0;
                high_bw_start_request   <= 1'b0;  // 清除请求
            end
        end
    end

    // 高带宽内存状态机控制 - 优化版本
    // 流水线化处理，提高传输效率
    always @(posedge clk) begin
        if (!rst_n) begin
            high_bw_state          <= HIGH_BW_IDLE;
            high_bw_req_o          <= 1'b0;
            high_bw_addr_o         <= 32'b0;
            high_bw_data_o         <= {HIGH_BW_DW{1'b0}};
        end else begin
            case (high_bw_state)
                HIGH_BW_IDLE: begin
                    high_bw_req_o <= 1'b0;
                    // 等待高带宽请求启动信号
                    if (high_bw_start) begin
                        high_bw_state <= HIGH_BW_REQUEST;

                        // 预计算第一个地址
                        high_bw_addr_o <= {16'b0, high_bw_current_addr};
                    end
                end

                HIGH_BW_REQUEST: begin
                    // 设置高带宽内存请求
                    high_bw_req_o  <= 1'b1;

                    // 如果是写操作，准备数据
                    if (high_bw_we_o) begin
                        // 从PE结果或内存准备数据
                        if (high_bw_transfer_count < PE_ARRAY_X * PE_ARRAY_Y) begin
                            high_bw_data_o <= {HIGH_BW_DW/DATA_WIDTH{pe_result[high_bw_transfer_count]}};
                        end else begin
                            high_bw_data_o <= {HIGH_BW_DW{1'b1}};  // 默认数据
                        end
                    end

                    high_bw_state <= HIGH_BW_WAIT_ACK;
                end

                HIGH_BW_WAIT_ACK: begin
                    if (high_bw_ack_i) begin
                        high_bw_req_o          <= 1'b0;
                        high_bw_transfer_count <= high_bw_transfer_count + 1;

                        // 如果是读操作，处理返回数据
                        if (!high_bw_we_o) begin
                            // 将读取的数据写入内存对应位置
                            // 这里可以扩展为处理高带宽数据
                        end

                        // 检查传输是否完成
                        if (high_bw_transfer_count >= high_bw_transfer_length) begin
                            high_bw_state <= HIGH_BW_DONE;
                        end else begin
                            high_bw_state <= HIGH_BW_REQUEST;
                            // 预计算下一个地址 - 修复宽度不确定问题
                            high_bw_addr_o <= {16'b0, (high_bw_current_addr + high_bw_transfer_count + 16'd1)};
                        end
                    end
                end

                HIGH_BW_DONE: begin
                    high_bw_state <= HIGH_BW_IDLE;
                end
            endcase
        end
    end

    // PE结果写回控制
    always @(posedge clk) begin
        if (!rst_n) begin
            write_back_state    <= WRITE_BACK_IDLE;
            pe_write_back_index <= 8'b0;
            pe_write_back_addr  <= 16'b0;
        end else begin
            case (write_back_state)
                WRITE_BACK_IDLE: begin
                    // 当所有PE计算完成时启动结果写回
                    if (computation_done) begin
                        write_back_state    <= WRITE_BACK_START;
                        pe_write_back_index <= 8'b0;
                        pe_write_back_addr  <= 16'h8000;  // PE结果写回起始地址
                    end
                end

                WRITE_BACK_START: begin
                    // 启动高带宽内存写入请求
                    high_bw_start_request <= 1'b1;
                    high_bw_start_we      <= 1'b1;  // 写操作
                    high_bw_start_length <= PE_ARRAY_X * PE_ARRAY_Y;
                    high_bw_start_addr    <= pe_write_back_addr;
                    write_back_state      <= WRITE_BACK_ACTIVE;
                end

                WRITE_BACK_ACTIVE: begin
                    // 监控高带宽传输状态
                    if (high_bw_state == HIGH_BW_DONE) begin
                        write_back_state <= WRITE_BACK_DONE;
                    end

                    // 在传输过程中准备PE结果数据
                    if (high_bw_state == HIGH_BW_REQUEST && high_bw_we_o) begin
                        // 准备当前PE的结果数据
                        if (pe_write_back_index < PE_ARRAY_X * PE_ARRAY_Y) begin
                            // 将PE结果扩展到高带宽数据宽度
                            high_bw_data_o      <= {HIGH_BW_DW/DATA_WIDTH{pe_result[pe_write_back_index]}};
                            pe_write_back_index <= pe_write_back_index + 1;
                        end
                    end
                end

                WRITE_BACK_DONE: begin
                    write_back_state <= WRITE_BACK_IDLE;
                end
            endcase
        end
    end

    // Computation control - 产生启动脉冲
    reg start_delay;
    always @(posedge clk) begin
        if (!rst_n) begin
            start_computation <= 1'b0;
            start_delay       <= 1'b0;
        end else begin
            start_delay       <= start_bit;

            // 产生一个时钟周期的启动脉冲
            if (start_bit && !start_delay) begin
                start_computation <= 1'b1;
            end else begin
                start_computation <= 1'b0;
            end
        end
    end

    // 内存初始化
    integer k;
    always @(posedge clk) begin
        if (!rst_n) begin
            // 初始化内存为0 - 使用简单赋值避免复杂循环
            // 注意：这里简化了复位逻辑，实际使用时需要确保MEM_DEPTH大小合理
            memory <= {MEM_DEPTH*DATA_WIDTH{1'b0}};
        end
    end

    // PE输出写入内存逻辑 - 优化版本
    // 使用并行写入和条件更新，提高效率
    always @(posedge clk) begin
        if (!rst_n) begin
            // 复位时清零PE输出区域 - 使用简单赋值避免复杂循环
            // 注意：这里简化了复位逻辑，实际使用时需要确保PE_ARRAY_X*PE_ARRAY_Y大小合理
            memory[3*PE_ARRAY_X*PE_ARRAY_Y +: PE_ARRAY_X*PE_ARRAY_Y] <= {PE_ARRAY_X*PE_ARRAY_Y*DATA_WIDTH{1'b0}};
        end else begin
            // 在PE开始计算之前清零PE输出区域
            if (start_computation) begin
                memory[3*PE_ARRAY_X*PE_ARRAY_Y +: PE_ARRAY_X*PE_ARRAY_Y] <= {PE_ARRAY_X*PE_ARRAY_Y*DATA_WIDTH{1'b0}};
            end else begin
                // 并行写入有效的PE结果
                for (k = 0; k < PE_ARRAY_X * PE_ARRAY_Y; k = k + 1) begin
                    if (pe_result_valid[k]) begin
                        memory[3*PE_ARRAY_X*PE_ARRAY_Y + k] <= pe_result[k];
                    end
                    // 如果PE结果无效，保持当前值不变，避免不必要的写入
                end
            end
        end
    end

    // PE操作数和配置输出 - 优化版本
    // 使用组合逻辑直接映射，零延迟输出
    always @(*) begin
        for (k = 0; k < PE_ARRAY_X * PE_ARRAY_Y; k = k + 1) begin
            pe_operand1[k] = memory[k];
            pe_operand2[k] = memory[PE_ARRAY_X*PE_ARRAY_Y + k];
            pe_config[k]   = memory[2*PE_ARRAY_X*PE_ARRAY_Y + k];
        end
    end

endmodule