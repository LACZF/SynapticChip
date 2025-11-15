module pe_mem #(
    parameter PE_ARRAY_X = 4,
    parameter PE_ARRAY_Y = 4,
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16,
    parameter HIGH_BW_DW = 320
)(
    input  wire                                             clk,
    input  wire                                             rst_n,
    input  wire                                             we,
    input  wire [ADDR_WIDTH-1:0]                            addr,
    input  wire [DATA_WIDTH-1:0]                            wdata,
    output reg  [DATA_WIDTH-1:0]                            rdata,
    output reg  [0:PE_ARRAY_X*PE_ARRAY_Y-1][DATA_WIDTH-1:0] pe_operand1,
    output reg  [0:PE_ARRAY_X*PE_ARRAY_Y-1][DATA_WIDTH-1:0] pe_operand2,
    output reg  [0:PE_ARRAY_X*PE_ARRAY_Y-1][DATA_WIDTH-1:0] pe_config,
    input  wire [0:PE_ARRAY_X*PE_ARRAY_Y-1][DATA_WIDTH-1:0] pe_output,
    input  wire                                             start_computation,  // PE开始计算信号

    // 高带宽内存接口
    input  wire [HIGH_BW_DW-1:0]                            mem_data_i,
    input  wire                                             mem_ack_i,
    output reg                                              mem_req_o,
    output reg                                              mem_we_o,
    output reg  [31:0]                                      mem_addr_o,
    output reg  [HIGH_BW_DW-1:0]                            mem_data_o
);

    // Memory organization:
    // [0:PE_ARRAY_X*PE_ARRAY_Y-1] - operand1
    // [PE_ARRAY_X*PE_ARRAY_Y:2*PE_ARRAY_X*PE_ARRAY_Y-1] - operand2
    // [2*PE_ARRAY_X*PE_ARRAY_Y:3*PE_ARRAY_X*PE_ARRAY_Y-1] - config
    // [3*PE_ARRAY_X*PE_ARRAY_Y:4*PE_ARRAY_X*PE_ARRAY_Y-1] - output

    localparam MEM_DEPTH = 4 * PE_ARRAY_X * PE_ARRAY_Y;
    reg [0:MEM_DEPTH-1][DATA_WIDTH-1:0] memory;

    // 高带宽内存访问状态机
    localparam IDLE     = 2'b00;
    localparam REQUEST  = 2'b01;
    localparam WAIT_ACK = 2'b10;
    localparam DONE     = 2'b11;

    reg [1:0]            mem_access_state;
    reg [31:0]           mem_access_addr;
    reg [HIGH_BW_DW-1:0] mem_access_data;
    reg                  mem_access_we;
    reg                  mem_access_active;

    integer k;

    // Read memory content to PE connections
    always @(*) begin
        for (k = 0; k < PE_ARRAY_X * PE_ARRAY_Y; k = k + 1) begin
            pe_operand1[k] = memory[k];
            pe_operand2[k] = memory[PE_ARRAY_X*PE_ARRAY_Y + k];
            pe_config[k]   = memory[2*PE_ARRAY_X*PE_ARRAY_Y + k];
        end
    end

    // Write PE outputs to memory
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < PE_ARRAY_X * PE_ARRAY_Y; k = k + 1) begin
                memory[3*PE_ARRAY_X*PE_ARRAY_Y + k] <= {DATA_WIDTH{1'b0}};
            end
        end else begin
            // 在PE开始计算之前清零PE输出区域
            if (start_computation) begin
                for (k = 0; k < PE_ARRAY_X * PE_ARRAY_Y; k = k + 1) begin
                    memory[3*PE_ARRAY_X*PE_ARRAY_Y + k] <= {DATA_WIDTH{1'b0}};
                end
            end else begin
                // 正常写入PE输出结果
                for (k = 0; k < PE_ARRAY_X * PE_ARRAY_Y; k = k + 1) begin
                    memory[3*PE_ARRAY_X*PE_ARRAY_Y + k] <= pe_output[k];
                end
            end
        end
    end

    // Memory read/write operations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata <= {DATA_WIDTH{1'b0}};
            // Initialize memory to zeros
            for (k = 0; k < MEM_DEPTH; k = k + 1) begin
                memory[k] <= {DATA_WIDTH{1'b0}};
            end
        end else begin
            if (we && addr < MEM_DEPTH) begin
                memory[addr] <= wdata;
            end
            if (addr < MEM_DEPTH) begin
                rdata <= memory[addr];
            end else begin
                rdata <= {DATA_WIDTH{1'b0}};
            end
        end
    end

    // 高带宽内存访问状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_access_state  <= IDLE;
            mem_req_o         <= 1'b0;
            mem_we_o          <= 1'b0;
            mem_addr_o        <= 32'b0;
            mem_data_o        <= {HIGH_BW_DW{1'b0}};
            mem_access_addr   <= 32'b0;
            mem_access_data   <= {HIGH_BW_DW{1'b0}};
            mem_access_we     <= 1'b0;
            mem_access_active <= 1'b0;
        end else begin
            case (mem_access_state)
                IDLE: begin
                    mem_req_o         <= 1'b0;
                    mem_we_o          <= 1'b0;
                    mem_access_active <= 1'b0;

                    // 检测是否需要发起高带宽内存访问
                    // 这里可以根据PE配置或控制信号来触发
                    // 暂时使用简单的触发条件：当有写操作时触发
                    if (we) begin
                        mem_access_state  <= REQUEST;
                        mem_access_active <= 1'b1;
                    end
                end

                REQUEST: begin
                    mem_req_o        <= 1'b1;
                    mem_we_o         <= mem_access_we;
                    mem_addr_o       <= mem_access_addr;
                    mem_data_o       <= mem_access_data;
                    mem_access_state <= WAIT_ACK;
                end

                WAIT_ACK: begin
                    if (mem_ack_i) begin
                        mem_req_o        <= 1'b0;
                        mem_we_o         <= 1'b0;
                        mem_access_state <= DONE;

                        // 如果是读操作，处理返回的数据
                        if (!mem_access_we) begin
                            // 这里可以处理读取的高带宽数据
                            // 例如：将数据分发到PE操作数或配置中
                        end
                    end
                end

                DONE: begin
                    mem_access_active <= 1'b0;
                    mem_access_state  <= IDLE;
                end
            endcase
        end
    end

    // 高带宽内存访问触发逻辑
    // 这里可以根据PE配置或控制信号来设置访问参数
    always @(*) begin
        // 默认值
        mem_access_addr = 32'b0;
        mem_access_data = {HIGH_BW_DW{1'b0}};
        mem_access_we   = 1'b0;

        // 根据PE配置或控制信号设置访问参数
        // 例如：当PE配置的特定位被设置时，触发高带宽内存访问
        // 暂时使用简单的触发条件：当有写操作时触发
        if (we) begin
            // 设置访问地址和数据
            mem_access_addr = {16'b0, addr}; // 扩展地址到32位
            mem_access_data = {HIGH_BW_DW/DATA_WIDTH{wdata}}; // 扩展数据到高带宽宽度
            mem_access_we   = 1'b1; // 写使能
        end
    end

endmodule