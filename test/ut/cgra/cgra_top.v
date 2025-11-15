module cgra_top #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16,
    parameter PE_ARRAY_X = 2,
    parameter PE_ARRAY_Y = 2,
    parameter CONFIG_WIDTH = 64,
    parameter NUM_CONTEXTS = 4
)(
    input wire clk,
    input wire rst_n,

    // OBI Bus Interface
    input wire obi_req,
    input wire obi_we,
    input wire [ADDR_WIDTH-1:0] obi_addr,
    input wire [DATA_WIDTH-1:0] obi_wdata,
    output wire obi_gnt,
    output wire obi_rvalid,
    output wire [DATA_WIDTH-1:0] obi_rdata,

    // Status
    output wire ready
);

// 计算总的PE数量
localparam TOTAL_PES = PE_ARRAY_X * PE_ARRAY_Y;

// Internal signals
wire config_req;
wire config_we;
wire [ADDR_WIDTH-1:0] config_addr;
wire [DATA_WIDTH-1:0] config_wdata;
wire config_ready;

// PE配置存储
reg [CONFIG_WIDTH-1:0] pe_config [0:TOTAL_PES-1];
wire [1:0] current_context;
wire context_switch;

// PE Interconnect signals with valid
wire [DATA_WIDTH-1:0] pe_out [0:PE_ARRAY_X-1][0:PE_ARRAY_Y-1];
wire pe_valid_out [0:PE_ARRAY_X-1][0:PE_ARRAY_Y-1];
wire pe_busy [0:PE_ARRAY_X-1][0:PE_ARRAY_Y-1];

wire [DATA_WIDTH-1:0] pe_north_in [0:PE_ARRAY_X-1][0:PE_ARRAY_Y-1];
wire pe_north_valid_in [0:PE_ARRAY_X-1][0:PE_ARRAY_Y-1];
wire [DATA_WIDTH-1:0] pe_south_in [0:PE_ARRAY_X-1][0:PE_ARRAY_Y-1];
wire pe_south_valid_in [0:PE_ARRAY_X-1][0:PE_ARRAY_Y-1];
wire [DATA_WIDTH-1:0] pe_east_in [0:PE_ARRAY_X-1][0:PE_ARRAY_Y-1];
wire pe_east_valid_in [0:PE_ARRAY_X-1][0:PE_ARRAY_Y-1];
wire [DATA_WIDTH-1:0] pe_west_in [0:PE_ARRAY_X-1][0:PE_ARRAY_Y-1];
wire pe_west_valid_in [0:PE_ARRAY_X-1][0:PE_ARRAY_Y-1];
wire [DATA_WIDTH-1:0] pe_reg_in [0:PE_ARRAY_X-1][0:PE_ARRAY_Y-1];
wire pe_reg_valid_in [0:PE_ARRAY_X-1][0:PE_ARRAY_Y-1];

// 数据存储器
reg [DATA_WIDTH-1:0] data_memory [0:255];
reg data_memory_valid [0:255]; // 数据有效性标志

// OBI数据存储器接口
wire data_mem_we;
wire [7:0] data_mem_addr;
wire [DATA_WIDTH-1:0] data_mem_wdata;
wire [DATA_WIDTH-1:0] data_mem_rdata;

// 全局启动信号
reg global_start;
reg [DATA_WIDTH-1:0] start_data [0:TOTAL_PES-1];

// 调试信号
wire [DATA_WIDTH-1:0] debug_pe00_config = pe_config[0][31:0];
wire [DATA_WIDTH-1:0] debug_pe00_out = pe_out[0][0];
wire debug_pe00_valid = pe_valid_out[0][0];
wire [DATA_WIDTH-1:0] debug_data_mem0 = data_memory[0];
wire debug_data_mem0_valid = data_memory_valid[0];

// OBI Interface Controller
obi_interface #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
) obi_if (
    .clk(clk),
    .rst_n(rst_n),
    .obi_req(obi_req),
    .obi_we(obi_we),
    .obi_addr(obi_addr),
    .obi_wdata(obi_wdata),
    .obi_gnt(obi_gnt),
    .obi_rvalid(obi_rvalid),
    .obi_rdata(obi_rdata),
    .config_req(config_req),
    .config_we(config_we),
    .config_addr(config_addr),
    .config_wdata(config_wdata),
    .config_ready(config_ready),
    .data_mem_we(data_mem_we),
    .data_mem_addr(data_mem_addr),
    .data_mem_wdata(data_mem_wdata),
    .data_mem_rdata(data_mem_rdata),
    .ready(ready)
);

// Configuration Manager
config_manager #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .TOTAL_PES(TOTAL_PES),
    .CONFIG_WIDTH(CONFIG_WIDTH),
    .NUM_CONTEXTS(NUM_CONTEXTS)
) cfg_mgr (
    .clk(clk),
    .rst_n(rst_n),
    .config_req(config_req),
    .config_we(config_we),
    .config_addr(config_addr),
    .config_wdata(config_wdata),
    .config_ready(config_ready),
    .pe_config(pe_config),
    .current_context(current_context),
    .context_switch(context_switch)
);

// PE阵列和Router实例化
genvar x, y;
generate
    for (x = 0; x < PE_ARRAY_X; x = x + 1) begin : pe_x_loop
        for (y = 0; y < PE_ARRAY_Y; y = y + 1) begin : pe_y_loop
            // 计算PE在一维数组中的索引
            localparam PE_INDEX = x * PE_ARRAY_Y + y;

            // PE实例
            processing_element #(
                .DATA_WIDTH(DATA_WIDTH),
                .CONFIG_WIDTH(CONFIG_WIDTH),
                .NUM_CONTEXTS(NUM_CONTEXTS)
            ) pe_inst (
                .clk(clk),
                .rst_n(rst_n),
                .config_context(current_context),
                .config_in(pe_config[PE_INDEX]),
                .north_in(pe_north_in[x][y]),
                .north_valid_in(pe_north_valid_in[x][y]),
                .south_in(pe_south_in[x][y]),
                .south_valid_in(pe_south_valid_in[x][y]),
                .east_in(pe_east_in[x][y]),
                .east_valid_in(pe_east_valid_in[x][y]),
                .west_in(pe_west_in[x][y]),
                .west_valid_in(pe_west_valid_in[x][y]),
                .reg_in(pe_reg_in[x][y]),
                .reg_valid_in(pe_reg_valid_in[x][y]),
                .data_out(pe_out[x][y]),
                .data_valid_out(pe_valid_out[x][y]),
                .pe_busy(pe_busy[x][y])
            );

            // Router实例
            router #(
                .DATA_WIDTH(DATA_WIDTH)
            ) router_inst (
                .clk(clk),
                .rst_n(rst_n),
                .local_data(pe_out[x][y]),
                .local_valid(pe_valid_out[x][y]),
                .config_in(pe_config[PE_INDEX][15:0]),
                .north_out(pe_north_in[x][y]),
                .north_valid_out(pe_north_valid_in[x][y]),
                .south_out(pe_south_in[x][y]),
                .south_valid_out(pe_south_valid_in[x][y]),
                .east_out(pe_east_in[x][y]),
                .east_valid_out(pe_east_valid_in[x][y]),
                .west_out(pe_west_in[x][y]),
                .west_valid_out(pe_west_valid_in[x][y]),
                .reg_out(pe_reg_in[x][y]),
                .reg_valid_out(pe_reg_valid_in[x][y]),
                .data_out_port(), // 暂时不使用外部输出
                .data_valid_out_port()
            );
        end
    end
endgenerate

// 互联网络连接 - 使用数据存储器作为边界输入
generate
    for (x = 0; x < PE_ARRAY_X; x = x + 1) begin : connect_x
        for (y = 0; y < PE_ARRAY_Y; y = y + 1) begin : connect_y
            // 计算数据存储器地址偏移
            localparam MEM_OFFSET = x * PE_ARRAY_Y + y;

            // North connections - 边界连接到数据存储器
            if (x == 0) begin
                assign pe_north_in[x][y] = data_memory[MEM_OFFSET];
                assign pe_north_valid_in[x][y] = data_memory_valid[MEM_OFFSET] && global_start;
            end else begin
                assign pe_north_in[x][y] = pe_out[x-1][y];
                assign pe_north_valid_in[x][y] = pe_valid_out[x-1][y];
            end

            // South connections
            if (x == PE_ARRAY_X-1) begin
                assign pe_south_in[x][y] = data_memory[MEM_OFFSET + 16];
                assign pe_south_valid_in[x][y] = data_memory_valid[MEM_OFFSET + 16] && global_start;
            end else begin
                assign pe_south_in[x][y] = pe_out[x+1][y];
                assign pe_south_valid_in[x][y] = pe_valid_out[x+1][y];
            end

            // West connections
            if (y == 0) begin
                assign pe_west_in[x][y] = data_memory[MEM_OFFSET + 32];
                assign pe_west_valid_in[x][y] = data_memory_valid[MEM_OFFSET + 32] && global_start;
            end else begin
                assign pe_west_in[x][y] = pe_out[x][y-1];
                assign pe_west_valid_in[x][y] = pe_valid_out[x][y-1];
            end

            // East connections
            if (y == PE_ARRAY_Y-1) begin
                assign pe_east_in[x][y] = data_memory[MEM_OFFSET + 48];
                assign pe_east_valid_in[x][y] = data_memory_valid[MEM_OFFSET + 48] && global_start;
            end else begin
                assign pe_east_in[x][y] = pe_out[x][y+1];
                assign pe_east_valid_in[x][y] = pe_valid_out[x][y+1];
            end
        end
    end
endgenerate

// 数据存储器管理和PE输出捕获
integer i, j;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // 初始化数据存储器
        global_start <= 1'b0;
        for (i = 0; i < 256; i = i + 1) begin
            data_memory[i] <= {DATA_WIDTH{1'b0}};
            data_memory_valid[i] <= 1'b0;
        end
        for (i = 0; i < TOTAL_PES; i = i + 1) begin
            start_data[i] <= {DATA_WIDTH{1'b0}};
        end
    end else begin
        // 来源1: OBI总线写入数据存储器
        if (data_mem_we) begin
            data_memory[data_mem_addr] <= data_mem_wdata;
            data_memory_valid[data_mem_addr] <= 1'b1;
            $display("Data Memory Write: addr=0x%h, data=0x%h, valid=1", data_mem_addr, data_mem_wdata);

            // 如果写入启动地址，设置全局启动
            if (data_mem_addr == 8'hFF) begin
                global_start <= data_mem_wdata[0];
                $display("Global Start: %b", data_mem_wdata[0]);
            end
        end

        // 来源2: PE输出写入数据存储器的高位区域（用于读取结果）
        for (i = 0; i < PE_ARRAY_X; i = i + 1) begin
            for (j = 0; j < PE_ARRAY_Y; j = j + 1) begin
                data_memory[128 + i * PE_ARRAY_Y + j] <= pe_out[i][j];
                data_memory_valid[128 + i * PE_ARRAY_Y + j] <= pe_valid_out[i][j];
            end
        end
    end
end

// 数据存储器读取
assign data_mem_rdata = data_memory[data_mem_addr];

endmodule