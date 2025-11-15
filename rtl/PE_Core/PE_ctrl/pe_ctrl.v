module pe_control #(
    parameter PE_ARRAY_X = 4,
    parameter PE_ARRAY_Y = 4,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16,
    parameter HIGH_BW_DW = 320  // 高带宽数据宽度
)(
    input  wire                                            clk,
    input  wire                                            rst_n,

    // OBI Bus Interface
    input  wire                                            req_i,
    input  wire                                            we_i,
    input  wire [31:0]                                     addr_i,
    input  wire [DATA_WIDTH-1:0]                           wdata_i,
    output reg                                             gnt_o,
    output reg                                             rvalid_o,
    output reg  [DATA_WIDTH-1:0]                           rdata_o,

    // Memory Interface
    output reg                                             mem_we,
    output reg  [ADDR_WIDTH-1:0]                           mem_addr,
    output reg  [DATA_WIDTH-1:0]                           mem_wdata,
    input  wire [DATA_WIDTH-1:0]                           mem_rdata,

    // PE Control
    output reg                                             start_computation,
    input  wire                                            computation_done,

    // 高带宽内存接口
    output reg                                             high_bw_req_o,
    output reg                                             high_bw_we_o,
    output reg  [31:0]                                     high_bw_addr_o,
    output reg  [HIGH_BW_DW-1:0]                           high_bw_data_o,
    input  wire                                            high_bw_ack_i,
    input  wire [HIGH_BW_DW-1:0]                           high_bw_data_i,

    // PE结果写回接口
    input wire [0:PE_ARRAY_X*PE_ARRAY_Y-1][DATA_WIDTH-1:0] pe_result,
    input wire [0:PE_ARRAY_X*PE_ARRAY_Y-1]                 pe_result_valid
);

    // Control registers
    reg [DATA_WIDTH-1:0] control_reg;
    reg [DATA_WIDTH-1:0] status_reg;

    // Address mapping
    localparam CONTROL_REG_ADDR   = 24'h100000;
    localparam STATUS_REG_ADDR    = 24'h100004;
    localparam PE_ENABLE_ADDR     = 24'h100008;
    localparam HIGH_BW_WRITE_ADDR = 24'h10000C;
    localparam HIGH_BW_READ_ADDR  = 24'h100010;

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

    // 地址拆分
    wire [15:0] addr_base       = addr_i[23:0];

    // Control register bits
    wire start_bit = control_reg[0];

    // Status register bits
    always @(*) begin
        status_reg = {31'b0, computation_done};
    end

    // OBI Bus FSM - 简化版本，移除复杂的突发传输
    typedef enum logic [1:0] {
        IDLE     = 2'b00,
        GRANT    = 2'b01,
        RESPONSE = 2'b10
    } obi_state_t;

    obi_state_t obi_state;

    // OBI Bus Control - 简化版本
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            obi_state   <= IDLE;
            gnt_o       <= 1'b0;
            rvalid_o    <= 1'b0;
            rdata_o     <= {DATA_WIDTH{1'b0}};
            mem_we      <= 1'b0;
            mem_addr    <= {ADDR_WIDTH{1'b0}};
            mem_wdata   <= {DATA_WIDTH{1'b0}};
            control_reg <= {DATA_WIDTH{1'b0}};
        end else begin
            case (obi_state)
                IDLE: begin
                    rvalid_o <= 1'b0;
                    mem_we   <= 1'b0;
                    gnt_o    <= 1'b0;

                    if (req_i) begin
                        gnt_o     <= 1'b1;
                        obi_state <= GRANT;
                    end
                end

                GRANT: begin
                    gnt_o <= 1'b0;

                    // 处理写入操作
                    if (we_i) begin
                        case (addr_base)
                            CONTROL_REG_ADDR: control_reg <= wdata_i;
                            HIGH_BW_WRITE_ADDR: begin
                                // 高带宽内存写入请求 - 使用wdata_i的低16bit作为地址，高16bit作为长度
                                high_bw_transfer_length <= wdata_i[31:16];  // 高16bit作为长度
                                high_bw_current_addr    <= wdata_i[15:0];   // 低16bit作为地址
                                high_bw_transfer_count  <= 16'b0;
                                high_bw_we_o            <= 1'b1;  // 写操作
                                high_bw_start           <= 1'b1;  // 启动高带宽传输
                            end
                            default: begin
                                // 普通内存写入
                                if (addr_base < (4 * PE_ARRAY_X * PE_ARRAY_Y)) begin
                                    mem_we    <= 1'b1;
                                    mem_addr  <= addr_base;
                                    mem_wdata <= wdata_i;
                                end
                            end
                        endcase
                    end

                    // 处理读取操作
                    if (!we_i) begin
                        case (addr_base)
                            CONTROL_REG_ADDR: rdata_o <= control_reg;
                            STATUS_REG_ADDR:  rdata_o <= status_reg;
                            HIGH_BW_READ_ADDR: begin
                                // 高带宽内存读取请求 - 使用wdata_i的低16bit作为地址，高16bit作为长度
                                high_bw_transfer_length <= wdata_i[31:16];  // 高16bit作为长度
                                high_bw_current_addr    <= wdata_i[15:0];   // 低16bit作为地址
                                high_bw_transfer_count  <= 16'b0;
                                high_bw_we_o            <= 1'b0;  // 读操作
                                high_bw_start           <= 1'b1;  // 启动高带宽传输
                            end
                            default: begin
                                // 普通内存读取
                                if (addr_base < (4 * PE_ARRAY_X * PE_ARRAY_Y)) begin
                                    mem_addr <= addr_base;
                                    rdata_o  <= mem_rdata;
                                end else begin
                                    rdata_o  <= {DATA_WIDTH{1'b0}};
                                end
                            end
                        endcase
                    end

                    obi_state <= RESPONSE;
                    rvalid_o <= 1'b1;
                end

                RESPONSE: begin
                    // 等待请求撤销
                    if (!req_i) begin
                        rvalid_o  <= 1'b0;
                        mem_we    <= 1'b0;
                        obi_state <= IDLE;
                    end
                    // 如果请求仍然有效，保持响应状态
                end
            endcase
        end
    end

    // 高带宽内存状态机控制
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            high_bw_state          <= HIGH_BW_IDLE;
            high_bw_req_o          <= 1'b0;
            high_bw_addr_o         <= 32'b0;
            high_bw_data_o         <= {HIGH_BW_DW{1'b0}};
            high_bw_transfer_count <= 16'b0;
            high_bw_start          <= 1'b0;
        end else begin
            case (high_bw_state)
                HIGH_BW_IDLE: begin
                    high_bw_req_o <= 1'b0;
                    // 等待高带宽请求启动信号
                    if (high_bw_start) begin
                        high_bw_state <= HIGH_BW_REQUEST;
                        high_bw_start <= 1'b0;  // 清除启动信号
                    end
                end

                HIGH_BW_REQUEST: begin
                    // 设置高带宽内存请求
                    high_bw_req_o  <= 1'b1;
                    high_bw_addr_o <= {16'b0, high_bw_current_addr + high_bw_transfer_count};

                    // 如果是写操作，准备数据
                    if (high_bw_we_o) begin
                        // 这里需要根据实际数据源准备高带宽数据
                        // 暂时使用固定模式数据
                        high_bw_data_o <= {HIGH_BW_DW{1'b1}};  // 全1模式
                    end

                    high_bw_state <= HIGH_BW_WAIT_ACK;
                end

                HIGH_BW_WAIT_ACK: begin
                    if (high_bw_ack_i) begin
                        high_bw_req_o          <= 1'b0;
                        high_bw_transfer_count <= high_bw_transfer_count + 1;

                        // 如果是读操作，处理返回数据
                        if (!high_bw_we_o) begin
                            // 这里可以处理读取的高带宽数据
                            // 暂时不处理具体数据
                        end

                        // 检查传输是否完成
                        if (high_bw_transfer_count >= high_bw_transfer_length) begin
                            high_bw_state <= HIGH_BW_DONE;
                        end else begin
                            high_bw_state <= HIGH_BW_REQUEST;
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
    always @(posedge clk or negedge rst_n) begin
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
                    high_bw_transfer_length <= PE_ARRAY_X * PE_ARRAY_Y;
                    high_bw_current_addr    <= pe_write_back_addr;
                    high_bw_transfer_count  <= 16'b0;
                    high_bw_we_o            <= 1'b1;  // 写操作
                    high_bw_start           <= 1'b1;  // 启动高带宽传输
                    write_back_state        <= WRITE_BACK_ACTIVE;
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
                            // 这里需要根据实际PE结果数据格式进行扩展
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

    // Computation control - 修复版本
    reg start_delay;
    always @(posedge clk or negedge rst_n) begin
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

endmodule