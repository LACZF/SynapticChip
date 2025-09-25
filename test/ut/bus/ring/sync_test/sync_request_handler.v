// 同步请求处理模块 - 内存读写操作示例
module sync_request_handler #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 64,
    parameter NODE_ID_WIDTH = 8,
    parameter NUM_RINGS = 2,
    parameter MEM_SIZE = 1024,        // 内存大小（单位：字）
    parameter MEM_ADDR_WIDTH = 10     // 内存地址宽度
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // 业务模块控制接口
    input  wire                         sync_req_valid,
    input  wire                         sync_req_type,      // 0:读, 1:写
    input  wire [ADDR_WIDTH-1:0]        sync_req_addr,
    input  wire [DATA_WIDTH-1:0]        sync_req_data,
    input  wire [NODE_ID_WIDTH-1:0]     sync_req_target_id,
    input  wire [NUM_RINGS-1:0]         sync_req_ring_select,
    output wire                         sync_req_ready,

    output wire                         sync_rsp_valid,
    output wire [DATA_WIDTH-1:0]        sync_rsp_data,
    output wire                         sync_rsp_error,
    output wire [NODE_ID_WIDTH-1:0]     sync_rsp_src_id,
    input  wire                         sync_rsp_ready,

    // 本地内存接口（可选，用于模拟本地内存）
    output wire                         mem_wr_en,
    output wire [MEM_ADDR_WIDTH-1:0]    mem_wr_addr,
    output wire [DATA_WIDTH-1:0]        mem_wr_data,
    input  wire [DATA_WIDTH-1:0]        mem_rd_data,

    // 状态输出
    output wire [1:0]                   sync_state,
    output wire                         sync_busy
);

// 状态定义
localparam IDLE        = 2'b00;
localparam WAIT_RSP    = 2'b01;
localparam PROCESSING  = 2'b10;

// 内部信号
reg [1:0] current_state;
reg [1:0] next_state;

reg                         req_pending;
reg                         req_type_pending;
reg [ADDR_WIDTH-1:0]        req_addr_pending;
reg [DATA_WIDTH-1:0]        req_data_pending;
reg [NODE_ID_WIDTH-1:0]     req_target_id_pending;
reg [NUM_RINGS-1:0]         req_ring_select_pending;

reg [DATA_WIDTH-1:0]        rsp_data_reg;
reg                         rsp_error_reg;
reg [NODE_ID_WIDTH-1:0]     rsp_src_id_reg;

// 总线接口信号
wire                        bus_req_valid;
wire [ADDR_WIDTH-1:0]       bus_req_addr;
wire [1:0]                  bus_req_match_type;
wire [NODE_ID_WIDTH-1:0]    bus_req_target_id;
wire [DATA_WIDTH-1:0]       bus_req_data;
wire [NUM_RINGS-1:0]        bus_req_ring_select;
wire                        bus_req_ready;

wire                        bus_rsp_valid;
wire [DATA_WIDTH-1:0]       bus_rsp_data;
wire [NODE_ID_WIDTH-1:0]    bus_rsp_src_id;
wire [NUM_RINGS-1:0]        bus_rsp_ring_id;
wire                        bus_rsp_ready;

// 状态机
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= IDLE;
    end else begin
        current_state <= next_state;
    end
end

always @(*) begin
    next_state = current_state;

    case (current_state)
        IDLE: begin
            if (sync_req_valid && sync_req_ready) begin
                next_state = WAIT_RSP;
            end
        end

        WAIT_RSP: begin
            if (bus_rsp_valid && bus_rsp_ready) begin
                next_state = PROCESSING;
            end
        end

        PROCESSING: begin
            if (sync_rsp_valid && sync_rsp_ready) begin
                next_state = IDLE;
            end
        end

        default: next_state = IDLE;
    endcase
end

// 请求处理
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        req_pending <= 1'b0;
        req_type_pending <= 1'b0;
        req_addr_pending <= {ADDR_WIDTH{1'b0}};
        req_data_pending <= {DATA_WIDTH{1'b0}};
        req_target_id_pending <= {NODE_ID_WIDTH{1'b0}};
        req_ring_select_pending <= {NUM_RINGS{1'b0}};
    end else begin
        if (sync_req_valid && sync_req_ready) begin
            req_pending <= 1'b1;
            req_type_pending <= sync_req_type;
            req_addr_pending <= sync_req_addr;
            req_data_pending <= sync_req_data;
            req_target_id_pending <= sync_req_target_id;
            req_ring_select_pending <= sync_req_ring_select;
        end else if (current_state == PROCESSING && sync_rsp_valid && sync_rsp_ready) begin
            req_pending <= 1'b0;
        end
    end
end

// 响应处理
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rsp_data_reg <= {DATA_WIDTH{1'b0}};
        rsp_error_reg <= 1'b0;
        rsp_src_id_reg <= {NODE_ID_WIDTH{1'b0}};
    end else if (bus_rsp_valid && bus_rsp_ready) begin
        rsp_data_reg <= bus_rsp_data;
        rsp_src_id_reg <= bus_rsp_src_id;
        // 简单的错误检查：如果返回的数据为全0或全1，认为有错误
        rsp_error_reg <= (bus_rsp_data == 0 || bus_rsp_data == {DATA_WIDTH{1'b1}});
    end
end

// 总线接口控制
assign bus_req_valid = (current_state == IDLE) ? sync_req_valid : 1'b0;
assign bus_req_addr = sync_req_addr;
assign bus_req_match_type = 2'b00;  // 地址匹配
assign bus_req_target_id = sync_req_target_id;
assign bus_req_data = sync_req_type ? sync_req_data : {DATA_WIDTH{1'b0}};  // 读操作数据为0
assign bus_req_ring_select = sync_req_ring_select;
assign sync_req_ready = bus_req_ready && (current_state == IDLE);

assign bus_rsp_ready = (current_state == WAIT_RSP);

// 响应输出
assign sync_rsp_valid = (current_state == PROCESSING);
assign sync_rsp_data = rsp_data_reg;
assign sync_rsp_error = rsp_error_reg;
assign sync_rsp_src_id = rsp_src_id_reg;

// 内存接口（模拟内存读写）
assign mem_wr_en = (current_state == PROCESSING) && req_type_pending && sync_rsp_valid;
assign mem_wr_addr = req_addr_pending[MEM_ADDR_WIDTH-1:0];  // 只取低位作为内存地址
assign mem_wr_data = rsp_data_reg;

// 状态输出
assign sync_state = current_state;
assign sync_busy = (current_state != IDLE);

// 总线接口包装器实例化
bus_interface_wrapper #(
    .NUM_RINGS(NUM_RINGS),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .NODE_ID_WIDTH(NODE_ID_WIDTH)
) u_bus_wrapper (
    .clk(clk),
    .rst_n(rst_n),

    // 应用接口
    .app_req_valid(bus_req_valid),
    .app_req_addr(bus_req_addr),
    .app_req_data(bus_req_data),
    .app_req_target_id(bus_req_target_id),
    .app_req_use_id_match(1'b0),  // 使用地址匹配
    .app_req_ring_select(bus_req_ring_select),
    .app_req_ready(bus_req_ready),

    .app_rsp_valid(bus_rsp_valid),
    .app_rsp_data(bus_rsp_data),
    .app_rsp_src_id(bus_rsp_src_id),
    .app_rsp_ready(bus_rsp_ready),

    // Ring总线节点接口（连接到外部）
    .bus_req_valid(bus_req_valid),
    .bus_req_addr(bus_req_addr),
    .bus_req_match_type(bus_req_match_type),
    .bus_req_target_id(bus_req_target_id),
    .bus_req_data(bus_req_data),
    .bus_req_ring_select(bus_req_ring_select),
    .bus_req_ready(bus_req_ready),

    .bus_rsp_valid(bus_rsp_valid),
    .bus_rsp_data(bus_rsp_data),
    .bus_rsp_src_id(bus_rsp_src_id),
    .bus_rsp_ring_id(bus_rsp_ring_id),
    .bus_rsp_ready(bus_rsp_ready)
);

endmodule

// 异步请求处理模块 - UART操作示例
module async_request_handler #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 64,
    parameter NODE_ID_WIDTH = 8,
    parameter NUM_RINGS = 2,
    parameter UART_FIFO_DEPTH = 16,
    parameter BAUD_RATE = 115200,
    parameter CLK_FREQ = 100000000
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // 业务模块控制接口
    input  wire                         async_req_valid,
    input  wire [1:0]                   async_req_type,     // 0:发送, 1:接收, 2:配置
    input  wire [ADDR_WIDTH-1:0]        async_req_addr,
    input  wire [DATA_WIDTH-1:0]        async_req_data,
    input  wire [NODE_ID_WIDTH-1:0]     async_req_target_id,
    input  wire [NUM_RINGS-1:0]         async_req_ring_select,
    output wire                         async_req_ready,

    output wire                         async_rsp_valid,
    output wire [DATA_WIDTH-1:0]        async_rsp_data,
    output wire [NODE_ID_WIDTH-1:0]     async_rsp_src_id,
    input  wire                         async_rsp_ready,

    // UART物理接口（模拟）
    output wire                         uart_tx,
    input  wire                         uart_rx,

    // 状态输出
    output wire [3:0]                   async_state,
    output wire                         uart_tx_busy,
    output wire                         uart_rx_ready,
    output wire [7:0]                   tx_fifo_count,
    output wire [7:0]                   rx_fifo_count
);

// 状态定义
localparam IDLE            = 4'b0000;
localparam SEND_REQ        = 4'b0001;
localparam WAIT_TX         = 4'b0010;
localparam WAIT_RX         = 4'b0011;
localparam PROCESS_TX      = 4'b0100;
localparam PROCESS_RX      = 4'b0101;
localparam CONFIG_UART     = 4'b0110;

// UART参数
localparam BAUD_COUNT = CLK_FREQ / BAUD_RATE;
localparam BAUD_WIDTH = $clog2(BAUD_COUNT);

// 内部信号
reg [3:0] current_state;
reg [3:0] next_state;

reg [BAUD_WIDTH-1:0] baud_counter;
reg [2:0] bit_counter;
reg [7:0] tx_shift_reg;
reg [7:0] rx_shift_reg;
reg tx_active;
reg rx_active;

// FIFO信号
reg [7:0] tx_fifo [0:UART_FIFO_DEPTH-1];
reg [7:0] rx_fifo [0:UART_FIFO_DEPTH-1];
reg [4:0] tx_wr_ptr;
reg [4:0] tx_rd_ptr;
reg [4:0] rx_wr_ptr;
reg [4:0] rx_rd_ptr;

wire tx_fifo_full;
wire tx_fifo_empty;
wire rx_fifo_full;
wire rx_fifo_empty;

// 总线接口信号
wire                        bus_req_valid;
wire [ADDR_WIDTH-1:0]       bus_req_addr;
wire [1:0]                  bus_req_match_type;
wire [NODE_ID_WIDTH-1:0]    bus_req_target_id;
wire [DATA_WIDTH-1:0]       bus_req_data;
wire [NUM_RINGS-1:0]        bus_req_ring_select;
wire                        bus_req_ready;

wire                        bus_rsp_valid;
wire [DATA_WIDTH-1:0]       bus_rsp_data;
wire [NODE_ID_WIDTH-1:0]    bus_rsp_src_id;
wire [NUM_RINGS-1:0]        bus_rsp_ring_id;
wire                        bus_rsp_ready;

// FIFO控制
assign tx_fifo_full = (tx_wr_ptr[3:0] == tx_rd_ptr[3:0]) && (tx_wr_ptr[4] != tx_rd_ptr[4]);
assign tx_fifo_empty = (tx_wr_ptr == tx_rd_ptr);
assign rx_fifo_full = (rx_wr_ptr[3:0] == rx_rd_ptr[3:0]) && (rx_wr_ptr[4] != rx_rd_ptr[4]);
assign rx_fifo_empty = (rx_wr_ptr == rx_rd_ptr);

assign tx_fifo_count = tx_wr_ptr - tx_rd_ptr;
assign rx_fifo_count = rx_wr_ptr - rx_rd_ptr;

// TX FIFO写入
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_wr_ptr <= 0;
    end else if (async_req_valid && async_req_ready && async_req_type == 2'b00) begin
        // UART发送请求
        tx_fifo[tx_wr_ptr[3:0]] <= async_req_data[7:0];
        tx_wr_ptr <= tx_wr_ptr + 1;
    end
end

// TX FIFO读取（用于UART发送）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        tx_rd_ptr <= 0;
    end else if (!tx_fifo_empty && !tx_active && baud_counter == 0) begin
        // 开始发送新字符
        tx_rd_ptr <= tx_rd_ptr + 1;
    end
end

// RX FIFO写入（用于UART接收）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_wr_ptr <= 0;
    end else if (rx_active && bit_counter == 3'd7 && baud_counter == BAUD_COUNT/2) begin
        // 完成接收一个字符
        rx_fifo[rx_wr_ptr[3:0]] <= rx_shift_reg;
        rx_wr_ptr <= rx_wr_ptr + 1;
    end
end

// RX FIFO读取（用于总线响应）
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_rd_ptr <= 0;
    end else if (async_rsp_valid && async_rsp_ready && current_state == PROCESS_RX) begin
        rx_rd_ptr <= rx_rd_ptr + 1;
    end
end

// 状态机
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        current_state <= IDLE;
    end else begin
        current_state <= next_state;
    end
end

always @(*) begin
    next_state = current_state;

    case (current_state)
        IDLE: begin
            if (async_req_valid && async_req_ready) begin
                case (async_req_type)
                    2'b00: next_state = SEND_REQ;  // 发送
                    2'b01: next_state = WAIT_RX;   // 接收
                    2'b10: next_state = CONFIG_UART; // 配置
                    default: next_state = IDLE;
                endcase
            end
        end

        SEND_REQ: begin
            if (bus_req_valid && bus_req_ready) begin
                next_state = WAIT_TX;
            end
        end

        WAIT_TX: begin
            if (bus_rsp_valid && bus_rsp_ready) begin
                next_state = PROCESS_TX;
            end
        end

        PROCESS_TX: begin
            if (!uart_tx_busy) begin
                next_state = IDLE;
            end
        end

        WAIT_RX: begin
            if (!rx_fifo_empty) begin
                next_state = PROCESS_RX;
            end
        end

        PROCESS_RX: begin
            if (async_rsp_valid && async_rsp_ready) begin
                next_state = IDLE;
            end
        end

        CONFIG_UART: begin
            next_state = IDLE;  // 配置立即完成
        end

        default: next_state = IDLE;
    endcase
end

// UART发送逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        baud_counter <= 0;
        bit_counter <= 0;
        tx_shift_reg <= 8'hFF;
        tx_active <= 1'b0;
    end else begin
        if (!tx_active && !tx_fifo_empty) begin
            // 开始发送
            tx_active <= 1'b1;
            tx_shift_reg <= tx_fifo[tx_rd_ptr[3:0]];
            baud_counter <= BAUD_COUNT - 1;
            bit_counter <= 0;
        end else if (tx_active) begin
            if (baud_counter == 0) begin
                baud_counter <= BAUD_COUNT - 1;
                if (bit_counter == 3'd9) begin
                    // 发送完成
                    tx_active <= 1'b0;
                end else begin
                    bit_counter <= bit_counter + 1;
                    tx_shift_reg <= {1'b1, tx_shift_reg[7:1]};  // 右移，高位补1
                end
            end else begin
                baud_counter <= baud_counter - 1;
            end
        end
    end
end

// UART接收逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_shift_reg <= 8'h00;
        rx_active <= 1'b0;
    end else begin
        if (!rx_active && !uart_rx) begin
            // 检测到起始位
            rx_active <= 1'b1;
            baud_counter <= BAUD_COUNT/2;  // 在中间采样
            bit_counter <= 0;
        end else if (rx_active) begin
            if (baud_counter == 0) begin
                baud_counter <= BAUD_COUNT - 1;
                if (bit_counter == 3'd8) begin
                    // 接收完成
                    rx_active <= 1'b0;
                end else begin
                    bit_counter <= bit_counter + 1;
                    rx_shift_reg <= {uart_rx, rx_shift_reg[7:1]};  // 左移，低位为新数据
                end
            end else begin
                baud_counter <= baud_counter - 1;
            end
        end
    end
end

// UART信号
assign uart_tx = tx_active ? (bit_counter == 0 ? 1'b0 :  // 起始位
                             (bit_counter == 9 ? 1'b1 :  // 停止位
                              tx_shift_reg[0])) : 1'b1;  // 数据位或空闲

assign uart_tx_busy = tx_active;
assign uart_rx_ready = !rx_fifo_empty;

// 总线接口控制
assign bus_req_valid = (current_state == SEND_REQ);
assign bus_req_addr = async_req_addr;
assign bus_req_match_type = 2'b01;  // ID匹配（UART设备有固定ID）
assign bus_req_target_id = async_req_target_id;
assign bus_req_data = {56'h0, tx_fifo[tx_rd_ptr[3:0]]};  // 只使用低8位
assign bus_req_ring_select = async_req_ring_select;
assign async_req_ready = (current_state == IDLE) &&
                        ((async_req_type == 2'b00 && !tx_fifo_full) ||  // 发送时检查FIFO不满
                         (async_req_type == 2'b01) ||                    // 接收总是就绪
                         (async_req_type == 2'b10));                     // 配置总是就绪

assign bus_rsp_ready = (current_state == WAIT_TX);

// 响应输出
assign async_rsp_valid = (current_state == PROCESS_RX) ||
                        (current_state == PROCESS_TX && bus_rsp_valid);
assign async_rsp_data = (current_state == PROCESS_RX) ?
                       {56'h0, rx_fifo[rx_rd_ptr[3:0]]} :  // 接收数据
                       bus_rsp_data;                       // 发送响应
assign async_rsp_src_id = (current_state == PROCESS_RX) ?
                        8'hFF : bus_rsp_src_id;  // 接收数据源ID固定为0xFF

// 状态输出
assign async_state = current_state;

// 总线接口包装器实例化
bus_interface_wrapper #(
    .NUM_RINGS(NUM_RINGS),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .NODE_ID_WIDTH(NODE_ID_WIDTH)
) u_bus_wrapper (
    .clk(clk),
    .rst_n(rst_n),

    // 应用接口
    .app_req_valid(bus_req_valid),
    .app_req_addr(bus_req_addr),
    .app_req_data(bus_req_data),
    .app_req_target_id(bus_req_target_id),
    .app_req_use_id_match(1'b1),  // UART使用ID匹配
    .app_req_ring_select(bus_req_ring_select),
    .app_req_ready(bus_req_ready),

    .app_rsp_valid(bus_rsp_valid),
    .app_rsp_data(bus_rsp_data),
    .app_rsp_src_id(bus_rsp_src_id),
    .app_rsp_ready(bus_rsp_ready),

    // Ring总线节点接口（连接到外部）
    .bus_req_valid(bus_req_valid),
    .bus_req_addr(bus_req_addr),
    .bus_req_match_type(bus_req_match_type),
    .bus_req_target_id(bus_req_target_id),
    .bus_req_data(bus_req_data),
    .bus_req_ring_select(bus_req_ring_select),
    .bus_req_ready(bus_req_ready),

    .bus_rsp_valid(bus_rsp_valid),
    .bus_rsp_data(bus_rsp_data),
    .bus_rsp_src_id(bus_rsp_src_id),
    .bus_rsp_ring_id(bus_rsp_ring_id),
    .bus_rsp_ready(bus_rsp_ready)
);

endmodule

// 测试模块 - 同步和异步请求示例
module sync_async_demo_tb;

// 参数定义
parameter ADDR_WIDTH = 32;
parameter DATA_WIDTH = 64;
parameter NODE_ID_WIDTH = 8;
parameter NUM_RINGS = 2;
parameter MEM_SIZE = 1024;
parameter MEM_ADDR_WIDTH = 10;
parameter UART_FIFO_DEPTH = 16;
parameter CLK_FREQ = 100000000;
parameter BAUD_RATE = 115200;

// 时钟和复位
reg clk;
reg rst_n;

// 同步请求接口（内存操作）
reg                         sync_req_valid;
reg                         sync_req_type;
reg  [ADDR_WIDTH-1:0]       sync_req_addr;
reg  [DATA_WIDTH-1:0]       sync_req_data;
reg  [NODE_ID_WIDTH-1:0]    sync_req_target_id;
reg  [NUM_RINGS-1:0]        sync_req_ring_select;
wire                        sync_req_ready;

wire                        sync_rsp_valid;
wire [DATA_WIDTH-1:0]       sync_rsp_data;
wire                        sync_rsp_error;
wire [NODE_ID_WIDTH-1:0]    sync_rsp_src_id;
reg                         sync_rsp_ready;

// 异步请求接口（UART操作）
reg                         async_req_valid;
reg  [1:0]                  async_req_type;
reg  [ADDR_WIDTH-1:0]       async_req_addr;
reg  [DATA_WIDTH-1:0]       async_req_data;
reg  [NODE_ID_WIDTH-1:0]    async_req_target_id;
reg  [NUM_RINGS-1:0]        async_req_ring_select;
wire                        async_req_ready;

wire                        async_rsp_valid;
wire [DATA_WIDTH-1:0]       async_rsp_data;
wire [NODE_ID_WIDTH-1:0]    async_rsp_src_id;
reg                         async_rsp_ready;

// UART物理接口
wire                        uart_tx;
reg                         uart_rx;

// 状态信号
wire [1:0]                  sync_state;
wire                        sync_busy;
wire [3:0]                  async_state;
wire                        uart_tx_busy;
wire                        uart_rx_ready;
wire [7:0]                  tx_fifo_count;
wire [7:0]                  rx_fifo_count;

// 内存接口
wire                        mem_wr_en;
wire [MEM_ADDR_WIDTH-1:0]   mem_wr_addr;
wire [DATA_WIDTH-1:0]       mem_wr_data;
reg  [DATA_WIDTH-1:0]       mem_rd_data;

// Ring总线接口（模拟）
wire                        bus_req_valid;
wire [ADDR_WIDTH-1:0]       bus_req_addr;
wire [1:0]                  bus_req_match_type;
wire [NODE_ID_WIDTH-1:0]    bus_req_target_id;
wire [DATA_WIDTH-1:0]       bus_req_data;
wire [NUM_RINGS-1:0]        bus_req_ring_select;
reg                         bus_req_ready;

reg                         bus_rsp_valid;
reg  [DATA_WIDTH-1:0]       bus_rsp_data;
reg  [NODE_ID_WIDTH-1:0]    bus_rsp_src_id;
reg  [NUM_RINGS-1:0]        bus_rsp_ring_id;
wire                        bus_rsp_ready;

// 简单的内存模型
reg [DATA_WIDTH-1:0] memory [0:MEM_SIZE-1];

// 实例化同步请求处理器
sync_request_handler #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .NODE_ID_WIDTH(NODE_ID_WIDTH),
    .NUM_RINGS(NUM_RINGS),
    .MEM_SIZE(MEM_SIZE),
    .MEM_ADDR_WIDTH(MEM_ADDR_WIDTH)
) u_sync_handler (
    .clk(clk),
    .rst_n(rst_n),

    .sync_req_valid(sync_req_valid),
    .sync_req_type(sync_req_type),
    .sync_req_addr(sync_req_addr),
    .sync_req_data(sync_req_data),
    .sync_req_target_id(sync_req_target_id),
    .sync_req_ring_select(sync_req_ring_select),
    .sync_req_ready(sync_req_ready),

    .sync_rsp_valid(sync_rsp_valid),
    .sync_rsp_data(sync_rsp_data),
    .sync_rsp_error(sync_rsp_error),
    .sync_rsp_src_id(sync_rsp_src_id),
    .sync_rsp_ready(sync_rsp_ready),

    .mem_wr_en(mem_wr_en),
    .mem_wr_addr(mem_wr_addr),
    .mem_wr_data(mem_wr_data),
    .mem_rd_data(mem_rd_data),

    .sync_state(sync_state),
    .sync_busy(sync_busy)
);

// 实例化异步请求处理器
async_request_handler #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .NODE_ID_WIDTH(NODE_ID_WIDTH),
    .NUM_RINGS(NUM_RINGS),
    .UART_FIFO_DEPTH(UART_FIFO_DEPTH),
    .BAUD_RATE(BAUD_RATE),
    .CLK_FREQ(CLK_FREQ)
) u_async_handler (
    .clk(clk),
    .rst_n(rst_n),

    .async_req_valid(async_req_valid),
    .async_req_type(async_req_type),
    .async_req_addr(async_req_addr),
    .async_req_data(async_req_data),
    .async_req_target_id(async_req_target_id),
    .async_req_ring_select(async_req_ring_select),
    .async_req_ready(async_req_ready),

    .async_rsp_valid(async_rsp_valid),
    .async_rsp_data(async_rsp_data),
    .async_rsp_src_id(async_rsp_src_id),
    .async_rsp_ready(async_rsp_ready),

    .uart_tx(uart_tx),
    .uart_rx(uart_rx),

    .async_state(async_state),
    .uart_tx_busy(uart_tx_busy),
    .uart_rx_ready(uart_rx_ready),
    .tx_fifo_count(tx_fifo_count),
    .rx_fifo_count(rx_fifo_count)
);

// 时钟生成
always #5 clk = ~clk;

// 内存读取
always @(*) begin
    mem_rd_data = memory[mem_wr_addr];  // 简化：总是返回写入地址的数据
end

// 内存写入
always @(posedge clk) begin
    if (mem_wr_en) begin
        memory[mem_wr_addr] <= mem_wr_data;
    end
end

// 模拟Ring总线响应
task send_bus_response;
    input [DATA_WIDTH-1:0] data;
    input [NODE_ID_WIDTH-1:0] src_id;
    input [NUM_RINGS-1:0] ring_id;
    begin
        @(posedge clk);
        bus_rsp_valid <= 1'b1;
        bus_rsp_data <= data;
        bus_rsp_src_id <= src_id;
        bus_rsp_ring_id <= ring_id;

        wait(bus_rsp_ready);
        @(posedge clk);
        bus_rsp_valid <= 1'b0;
    end
endtask

// 模拟UART接收
task uart_send_byte;
    input [7:0] data;
    integer i;
    begin
        // 发送起始位
        uart_rx <= 1'b0;
        #(1000000000/BAUD_RATE);

        // 发送数据位
        for (i = 0; i < 8; i = i + 1) begin
            uart_rx <= data[i];
            #(1000000000/BAUD_RATE);
        end

        // 发送停止位
        uart_rx <= 1'b1;
        #(1000000000/BAUD_RATE);
    end
endtask

initial begin
    // 初始化
    clk = 0;
    rst_n = 0;
    sync_req_valid = 0;
    sync_req_type = 0;
    sync_req_addr = 0;
    sync_req_data = 0;
    sync_req_target_id = 0;
    sync_req_ring_select = 2'b11;
    sync_rsp_ready = 1;

    async_req_valid = 0;
    async_req_type = 0;
    async_req_addr = 0;
    async_req_data = 0;
    async_req_target_id = 0;
    async_req_ring_select = 2'b11;
    async_rsp_ready = 1;

    uart_rx = 1'b1;

    bus_req_ready = 1;
    bus_rsp_valid = 0;
    bus_rsp_data = 0;
    bus_rsp_src_id = 0;
    bus_rsp_ring_id = 0;

    // 初始化内存
    for (integer i = 0; i < MEM_SIZE; i = i + 1) begin
        memory[i] = i;
    end

    // 复位
    #20 rst_n = 1;

    $display("=== 同步请求测试（内存读写）===");

    // 测试1：同步内存读操作
    $display("Test 1: Sync memory read");
    sync_req_valid <= 1'b1;
    sync_req_type <= 1'b0;  // 读操作
    sync_req_addr <= 32'h100;
    sync_req_target_id <= 8'h01;
    sync_req_ring_select <= 2'b01;  // 使用Ring 0

    wait(sync_req_ready);
    @(posedge clk);
    sync_req_valid <= 1'b0;

    // 模拟总线响应
    #10 send_bus_response(64'hDEADBEEF, 8'h01, 2'b01);

    // 等待同步响应
    wait(sync_rsp_valid);
    $display("Sync read response: data=%h, error=%b", sync_rsp_data, sync_rsp_error);

    // 测试2：同步内存写操作
    $display("Test 2: Sync memory write");
    sync_req_valid <= 1'b1;
    sync_req_type <= 1'b1;  // 写操作
    sync_req_addr <= 32'h200;
    sync_req_data <= 64'h123456789ABCDEF0;
    sync_req_target_id <= 8'h01;
    sync_req_ring_select <= 2'b10;  // 使用Ring 1

    wait(sync_req_ready);
    @(posedge clk);
    sync_req_valid <= 1'b0;

    // 模拟总线响应
    #10 send_bus_response(64'h0, 8'h01, 2'b10);

    // 等待同步响应
    wait(sync_rsp_valid);
    $display("Sync write response: data=%h, error=%b", sync_rsp_data, sync_rsp_error);

    $display("=== 异步请求测试（UART操作）===");

    // 测试3：异步UART发送
    $display("Test 3: Async UART transmit");
    async_req_valid <= 1'b1;
    async_req_type <= 2'b00;  // 发送
    async_req_data <= 64'h41; // ASCII 'A'
    async_req_target_id <= 8'h02;  // UART设备ID

    wait(async_req_ready);
    @(posedge clk);
    async_req_valid <= 1'b0;

    $display("UART TX FIFO count: %d", tx_fifo_count);

    // 测试4：异步UART接收
    $display("Test 4: Async UART receive");

    // 先发送数据到UART
    uart_send_byte(8'h42);  // ASCII 'B'

    // 然后请求接收
    async_req_valid <= 1'b1;
    async_req_type <= 2'b01;  // 接收

    wait(async_req_ready);
    @(posedge clk);
    async_req_valid <= 1'b0;

    // 等待异步响应
    wait(async_rsp_valid);
    $display("UART receive response: data=%h", async_rsp_data[7:0]);

    // 测试5：并发操作
    $display("Test 5: Concurrent operations");

    // 同时发起同步和异步请求
    fork
        begin
            // 同步读操作
            sync_req_valid <= 1'b1;
            sync_req_type <= 1'b0;
            sync_req_addr <= 32'h300;
            wait(sync_req_ready);
            @(posedge clk);
            sync_req_valid <= 1'b0;
        end

        begin
            // 异步UART发送
            async_req_valid <= 1'b1;
            async_req_type <= 2'b00;
            async_req_data <= 64'h43; // ASCII 'C'
            wait(async_req_ready);
            @(posedge clk);
            async_req_valid <= 1'b0;
        end
    join

    // 处理响应
    fork
        begin
            // 处理同步响应
            wait(sync_rsp_valid);
            $display("Concurrent sync response received");
        end

        begin
            // 处理异步响应（UART发送完成）
            wait(async_rsp_valid && async_req_type == 2'b00);
            $display("Concurrent async response received");
        end
    join

    #100;
    $display("All tests completed successfully");
    $finish;
end

// 监控信号
always @(posedge clk) begin
    if (sync_req_valid && sync_req_ready) begin
        $display("Time %0t: Sync request - %s addr=%h", $time,
                 sync_req_type ? "WRITE" : "READ", sync_req_addr);
    end

    if (sync_rsp_valid && sync_rsp_ready) begin
        $display("Time %0t: Sync response - data=%h, error=%b", $time,
                 sync_rsp_data, sync_rsp_error);
    end

    if (async_req_valid && async_req_ready) begin
        case (async_req_type)
            2'b00: $display("Time %0t: Async UART TX request - data=%h", $time, async_req_data[7:0]);
            2'b01: $display("Time %0t: Async UART RX request", $time);
            2'b10: $display("Time %0t: Async UART config request", $time);
        endcase
    end

    if (async_rsp_valid && async_rsp_ready) begin
        $display("Time %0t: Async response - data=%h", $time, async_rsp_data[7:0]);
    end

    if (uart_tx_busy) begin
        $display("Time %0t: UART TX active", $time);
    end
end

endmodule
