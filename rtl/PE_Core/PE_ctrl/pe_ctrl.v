module ip4_pe_control #(
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

    integer k;
    always @(posedge clk) begin
        if (!rst_n) begin
            obi_state               <= IDLE;
            gnt_o                   <= 1'b0;
            rvalid_o                <= 1'b0;
            rdata_o                 <= {DATA_WIDTH{1'b0}};
            control_reg             <= {DATA_WIDTH{1'b0}};
            read_addr_reg           <= {ADDR_WIDTH{1'b0}};
            memory                  <= {MEM_DEPTH*DATA_WIDTH{1'b0}};
        end else begin
            if (start_computation) begin
                memory[3*PE_ARRAY_X*PE_ARRAY_Y +: PE_ARRAY_X*PE_ARRAY_Y] <= {PE_ARRAY_X*PE_ARRAY_Y*DATA_WIDTH{1'b0}};
            end else begin
                for (k = 0; k < PE_ARRAY_X * PE_ARRAY_Y; k = k + 1) begin
                    if (pe_result_valid[k]) begin
                        memory[3*PE_ARRAY_X*PE_ARRAY_Y + k] <= pe_result[k];
                    end
                end
            end

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

    always @(*) begin
        for (k = 0; k < PE_ARRAY_X * PE_ARRAY_Y; k = k + 1) begin
            pe_operand1[k] = memory[k];
            pe_operand2[k] = memory[PE_ARRAY_X*PE_ARRAY_Y + k];
            pe_config[k]   = memory[2*PE_ARRAY_X*PE_ARRAY_Y + k];
        end
    end

endmodule