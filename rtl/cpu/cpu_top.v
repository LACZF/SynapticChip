// cpu_top.v
// CPU顶层模块，连接top_system和具体的CPU实现
// 预留了与多种CPU对接的能力

`include "cache_params.v"
`include "cache_system_params.v"

module cpu_top #(
    parameter NUM_RINGS         = 2,
    parameter ADDR_WIDTH        = 64,  // 与64位RISC-V架构保持一致
    parameter DATA_WIDTH        = 64,
    parameter NODE_ID_WIDTH     = 8,
    parameter NODE_ID           = 0,
    parameter OPCODE_WIDTH      = 8,
    parameter MATCH_TYPE_WIDTH  = 2,
    parameter INST_WIDTH        = 32,
    parameter NUM_CORES         = 4,
    parameter CORE_ID_WIDTH     = 2,
    parameter ENABLE_L2_CACHE   = 1, // 使能L2缓存，默认为1
    parameter ENABLE_L3_CACHE   = 1, // 使能L3缓存，默认为1
    parameter CPU_TYPE          = 0  // 0: RISC-V, 1: 预留其他CPU类型
) (
    input clk,
    input rst_n,

    // 外部中断
    input ext_int,

    // 发送请求
    input wire [NUM_RINGS-1:0]         tx_req_ring_mask_o,
    input wire [NUM_RINGS-1:0]         tx_req_ring_disable_o,
    input wire                         tx_req_valid_o,
    input wire                         tx_req_is_order_o,
    input wire [OPCODE_WIDTH-1:0]      tx_req_opcode_o,
    input wire [MATCH_TYPE_WIDTH-1:0]  tx_req_match_type_o,
    input wire [NODE_ID_WIDTH-1:0]     tx_req_source_id_o,
    input wire [NODE_ID_WIDTH-1:0]     tx_req_target_id_o,
    input wire [ADDR_WIDTH-1:0]        tx_req_addr_o,
    input wire [DATA_WIDTH-1:0]        tx_req_data_o,

    // 接受请求
    output wire                        rx_req_valid_i,
    output wire                        rx_req_is_order_i,
    output wire [OPCODE_WIDTH-1:0]     rx_req_opcode_i,
    output wire [MATCH_TYPE_WIDTH-1:0] rx_req_match_type_i,
    output wire [NODE_ID_WIDTH-1:0]    rx_req_source_id_i,
    output wire [NODE_ID_WIDTH-1:0]    rx_req_target_id_i,
    output wire [ADDR_WIDTH-1:0]       rx_req_addr_i,
    output wire [DATA_WIDTH-1:0]       rx_req_data_i,

    // 接收响应
    output wire                        rsp_valid_i,
    output wire [NODE_ID_WIDTH-1:0]    rsp_source_id_i,
    output wire [NODE_ID_WIDTH-1:0]    rsp_target_id_i,
    output wire [ADDR_WIDTH-1:0]       rsp_addr_i,
    output wire [DATA_WIDTH-1:0]       rsp_data_i
);

    // L1缓存接口信号
    wire [NUM_CORES-1:0] l1_icache_req;
    wire [NUM_CORES*ADDR_WIDTH-1:0] l1_icache_addr;
    wire [NUM_CORES*512-1:0] l1_icache_data;
    wire [NUM_CORES-1:0] l1_icache_ready;

    wire [NUM_CORES-1:0] l1_dcache_req;
    wire [NUM_CORES*ADDR_WIDTH-1:0] l1_dcache_addr;
    wire [NUM_CORES*512-1:0] l1_dcache_wdata;
    wire [NUM_CORES*512-1:0] l1_dcache_data;
    wire [NUM_CORES-1:0] l1_dcache_we;
    wire [NUM_CORES*2-1:0] l1_dcache_req_type;
    wire [NUM_CORES-1:0] l1_dcache_ready;

    // 监听接口信号
    wire [NUM_CORES-1:0] snoop_valid;
    wire [NUM_CORES*ADDR_WIDTH-1:0] snoop_addr;
    wire [NUM_CORES*2-1:0] snoop_req_type;
    wire [NUM_CORES-1:0] snoop_ready;
    wire [NUM_CORES-1:0] snoop_hit;
    wire [NUM_CORES*2-1:0] snoop_state;
    wire [NUM_CORES*512-1:0] snoop_data;

    // L2-L3接口信号
    wire l2_l3_req;
    wire [ADDR_WIDTH-1:0] l2_l3_addr;
    wire [511:0] l2_l3_wdata;
    wire [511:0] l2_l3_rdata;
    wire l2_l3_we;
    wire l2_l3_ready;

    // 核心与L2缓存之间的接口信号
    wire [NUM_CORES-1:0] core_l2_ready;
    wire [NUM_CORES*512-1:0] core_l2_data;

    // 内存接口信号
    wire mem_req;
    wire [ADDR_WIDTH-1:0] mem_addr;
    wire [511:0] mem_wdata;
    wire [511:0] mem_rdata;
    wire mem_we;
    wire mem_ready;

    // 缓存层次结构连接逻辑
    generate
        // 当有L2缓存时
        if (ENABLE_L2_CACHE) begin : l2_cache_gen
            // 中间信号用于L2缓存一致性状态
            wire [2:0] l2_coh_rsp_state;

            // 共享L2缓存实例（使用通用cache模块）
            cache #(
                .CACHE_LINE_SIZE(`L2_CACHE_LINE_SIZE),
                .CACHE_SIZE(`L2_CACHE_SIZE),
                .ASSOCIATIVITY(`L2_CACHE_ASSOCIATIVITY),
                .ADDR_WIDTH(ADDR_WIDTH),
                // 使用正确的L2缓存数据宽度（512位）
                .DATA_WIDTH(`L2_CACHE_DATA_WIDTH),
                .SUPPORT_COHERENCY(1),
                .CACHE_LEVEL(`CACHE_LEVEL_L2),
                .REPLACEMENT_POLICY(`REPLACEMENT_LRU)
            ) u_l2_cache (
                .clk(clk),
                .rst_n(rst_n),

                // CPU接口（简化为单一请求，实际应添加仲裁逻辑）
                .cpu_req_valid(|l1_dcache_req || |l1_icache_req),
                .cpu_req_addr(|l1_dcache_req ? l1_dcache_addr[0*ADDR_WIDTH +: ADDR_WIDTH] : l1_icache_addr[0*ADDR_WIDTH +: ADDR_WIDTH]),
                .cpu_req_rw(|l1_dcache_req && l1_dcache_we[0]),
                // 使用完整的512位缓存行宽度
                .cpu_req_data(l1_dcache_wdata[0*512 +: 512]),
                .cpu_req_strb(64'hFFFFFFFFFFFFFFFF),
                .cpu_rsp_valid(core_l2_ready[0]),
                // 使用完整的512位缓存行宽度
                .cpu_rsp_data(core_l2_data[0*512 +: 512]),
                .cpu_rsp_error(),

                // 内存接口
                .mem_req_valid(l2_l3_req),
                .mem_req_addr(l2_l3_addr),
                .mem_req_rw(l2_l3_we),
                // 注意：cache模块定义中存在设计错误，CACHE_LINE_SIZE是字节但被用作位宽
                // 因此我们只使用缓存行的低64位
                .mem_req_data(l2_l3_wdata[0*64 +: 64]),
                .mem_rsp_valid(l2_l3_ready),
                // 注意：cache模块定义中存在设计错误，CACHE_LINE_SIZE是字节但被用作位宽
                // 因此我们只使用缓存行的低64位
                .mem_rsp_data(l2_l3_rdata[0*64 +: 64]),
                .mem_rsp_error(),

                // 一致性接口
                .coh_req_addr(snoop_addr[0*ADDR_WIDTH +: ADDR_WIDTH]),
                .coh_req_valid(snoop_valid[0]),
                .coh_req_type({1'b0, snoop_req_type[0*2 +: 2]}),
                .coh_rsp_valid(snoop_ready[0]),
                .coh_rsp_state(l2_coh_rsp_state)
            );

            // 将L2缓存的一致性状态转换为2位宽并连接到snoop_state
            assign snoop_state[0*2 +: 2] = l2_coh_rsp_state[1:0];

            // 简化版：将L2的响应连接到所有核心（实际应根据请求源进行分发）
            // 使用非阻塞赋值实现连接
            assign l1_dcache_data[0*512 +: 512] = core_l2_data[0*512 +: 512];
            assign l1_icache_data[0*512 +: 512] = core_l2_data[0*512 +: 512];
            assign l1_dcache_ready[0] = core_l2_ready[0];
            assign l1_icache_ready[0] = core_l2_ready[0];

            // 对于多核情况，直接连接其他核心到同一L2响应
            `ifdef NUM_CORES
                // 移除嵌套的generate块，改用条件编译+简单if语句
                if (NUM_CORES > 1) begin
                    assign l1_dcache_data[1*512 +: 512] = core_l2_data[0*512 +: 512];
                    assign l1_icache_data[1*512 +: 512] = core_l2_data[0*512 +: 512];
                    assign l1_dcache_ready[1] = core_l2_ready[0];
                    assign l1_icache_ready[1] = core_l2_ready[0];
                end
            `endif

            // L3缓存实例（使用通用cache模块，可选）
            if (ENABLE_L3_CACHE) begin : l3_cache_gen
                cache #(
                    .CACHE_LINE_SIZE(`L3_CACHE_LINE_SIZE),
                    .CACHE_SIZE(`L3_CACHE_SIZE),
                    .ASSOCIATIVITY(`L3_CACHE_ASSOCIATIVITY),
                    .ADDR_WIDTH(ADDR_WIDTH),
                    // 使用正确的L3缓存数据宽度（512位）
                    .DATA_WIDTH(`L3_CACHE_DATA_WIDTH),
                    .SUPPORT_COHERENCY(1),
                    .CACHE_LEVEL(`CACHE_LEVEL_L3),
                    .REPLACEMENT_POLICY(`REPLACEMENT_LRU)
                ) u_l3_cache (
                    .clk(clk),
                    .rst_n(rst_n),

                    // CPU接口（连接L2）
                    .cpu_req_valid(l2_l3_req),
                    .cpu_req_addr(l2_l3_addr),
                    .cpu_req_rw(l2_l3_we),
                    .cpu_req_data(l2_l3_wdata[0*512 +: 512]),
                    .cpu_req_strb(64'hFFFFFFFFFFFFFFFF),
                    .cpu_rsp_valid(l2_l3_ready),
                    .cpu_rsp_data(l2_l3_rdata),
                    .cpu_rsp_error(),

                    // 内存接口
                    .mem_req_valid(mem_req),
                    .mem_req_addr(mem_addr),
                    .mem_req_rw(mem_we),
                    // 注意：cache模块定义中存在设计错误，CACHE_LINE_SIZE是字节但被用作位宽
                    // 因此我们只使用缓存行的低64位
                    .mem_req_data(mem_wdata[0*64 +: 64]),
                    .mem_rsp_valid(mem_ready),
                    // 注意：cache模块定义中存在设计错误，CACHE_LINE_SIZE是字节但被用作位宽
                    // 因此我们只使用缓存行的低64位
                    .mem_rsp_data(mem_rdata[0*64 +: 64]),
                    .mem_rsp_error(),

                    // 一致性接口
                    .coh_req_addr({ADDR_WIDTH{1'b0}}),
                    .coh_req_valid(1'b0),
                    .coh_req_type(3'd0),
                    .coh_rsp_valid(),
                    .coh_rsp_state()
                );
            end else begin : direct_l2_to_mem
                // 直接连接L2到内存
                assign mem_req = l2_l3_req;
                assign mem_addr = l2_l3_addr;
                assign mem_wdata = l2_l3_wdata;
                assign mem_we = l2_l3_we;
                assign l2_l3_rdata = mem_rdata;
                assign l2_l3_ready = mem_ready;
            end
        end else begin : direct_l1_to_mem
            // 没有L2缓存时，L1直接连接到内存
            // 为每个核心创建请求仲裁逻辑
            wire [NUM_CORES-1:0] core_mem_req;
            wire [NUM_CORES*ADDR_WIDTH-1:0] core_mem_addr;
            wire [NUM_CORES*512-1:0] core_mem_wdata;
            wire [NUM_CORES-1:0] core_mem_we;
            wire [NUM_CORES-1:0] core_mem_ready;
            wire [NUM_CORES*512-1:0] core_mem_rdata;

            // 简化的仲裁逻辑，仅连接第一个核心到内存
            // 实际应用中应实现更复杂的仲裁器
            assign mem_req = core_mem_req[0];
            assign mem_addr = core_mem_addr[0*ADDR_WIDTH +: ADDR_WIDTH];
            assign mem_wdata = core_mem_wdata[0*512 +: 512];
            assign mem_we = core_mem_we[0];
            assign core_mem_rdata[0*512 +: 512] = mem_rdata;
            assign core_mem_ready[0] = mem_ready;

            // 直接连接L1缓存到内存接口
            genvar i;
            for (i = 0; i < NUM_CORES; i = i + 1) begin : l1_to_mem_conn
                assign core_mem_req[i] = l1_dcache_req[i] || l1_icache_req[i];
                assign core_mem_addr[i*ADDR_WIDTH +: ADDR_WIDTH] =
                    l1_dcache_req[i] ? l1_dcache_addr[i*ADDR_WIDTH +: ADDR_WIDTH] : l1_icache_addr[i*ADDR_WIDTH +: ADDR_WIDTH];
                assign core_mem_we[i] = l1_dcache_req[i] && l1_dcache_we[i];
                assign core_mem_wdata[i*512 +: 512] = l1_dcache_wdata[i*512 +: 512];

                // 连接响应信号
                assign l1_dcache_data[i*512 +: 512] = core_mem_rdata[i*512 +: 512];
                assign l1_icache_data[i*512 +: 512] = core_mem_rdata[i*512 +: 512];
                assign l1_dcache_ready[i] = core_mem_ready[i];
                assign l1_icache_ready[i] = core_mem_ready[i];

                // 不使用监听接口，设置默认值
                assign snoop_ready[i] = 1'b1;
                assign snoop_state[i*2 +: 2] = 2'b00;
            end

            // 对于多核情况，将其他核心的响应连接到相同的内存响应
            // 注意：这是一个简化实现，实际系统中应该有完整的仲裁机制
            `ifdef NUM_CORES
                if (NUM_CORES > 1) begin
                    for (i = 1; i < NUM_CORES; i = i + 1) begin : multi_core_conn
                        assign core_mem_rdata[i*512 +: 512] = mem_rdata;
                        assign core_mem_ready[i] = mem_ready;
                    end
                end
            `endif
        end
    endgenerate

    // 生成多个带L1缓存的CPU核
    generate
        genvar i;
        for (i = 0; i < NUM_CORES; i = i + 1) begin : core_gen
            if (CPU_TYPE == 0) begin : riscv_implementation
                // 创建中间信号，用于32位到64位的零扩展
                wire [63:0] l1_icache_addr_64;
                wire [63:0] l1_dcache_addr_64;
                wire icache_mem_req_rw;

                // CPU核心与L1缓存之间的中间信号
                wire icache_req;
                wire [63:0] icache_addr;
                wire [31:0] icache_data;
                wire icache_ready;
                wire dcache_req;
                wire [63:0] dcache_addr;
                wire [63:0] dcache_wdata;
                wire [63:0] dcache_rdata;
                wire dcache_we;
                wire [7:0] dcache_byte_en;
                wire dcache_ready;

                // 零扩展：将32位地址信号扩展到64位
                assign l1_icache_addr_64 = {{32{1'b0}}, l1_icache_addr[i*32 +: 32]};
                assign l1_dcache_addr_64 = {{32{1'b0}}, l1_dcache_addr[i*32 +: 32]};
                assign icache_mem_req_rw = 1'b0;  // 指令缓存始终是读操作

                // L1指令缓存实例（使用通用cache模块）
                cache #(
                    .CACHE_LINE_SIZE(`L1_ICACHE_LINE_SIZE),
                    .CACHE_SIZE(`L1_ICACHE_SIZE),
                    .ASSOCIATIVITY(`L1_ICACHE_ASSOCIATIVITY),
                    .ADDR_WIDTH(`L1_ICACHE_ADDR_WIDTH),
                    .DATA_WIDTH(`L1_ICACHE_DATA_WIDTH),
                    .SUPPORT_COHERENCY(0),  // L1缓存是核心独享的，不需要一致性
                    .CACHE_LEVEL(`CACHE_LEVEL_L1),
                    .REPLACEMENT_POLICY(`REPLACEMENT_LRU)
                ) u_l1_icache (
                    .clk(clk),
                    .rst_n(rst_n),

                    // CPU接口
                    .cpu_req_valid(icache_req),
                    .cpu_req_addr(icache_addr),
                    .cpu_req_rw(1'b0),
                    .cpu_req_data(32'd0),
                    .cpu_req_strb(4'hF),
                    .cpu_rsp_valid(icache_ready),
                    .cpu_rsp_data(icache_data),
                    .cpu_rsp_error(),

                    // 内存接口（连接L2）
                    .mem_req_valid(l1_icache_req[i]),
                    .mem_req_addr(l1_icache_addr_64),
                    .mem_req_rw(icache_mem_req_rw),
                    .mem_req_data(l1_dcache_wdata[i*512 +: 64]),
                    .mem_rsp_valid(l1_icache_ready[i]),
                    .mem_rsp_data(l1_icache_data[i*512 +: 64]),
                    .mem_rsp_error(),

                    // 一致性接口（不使用，连接到0）
                    .coh_req_addr(64'd0),
                    .coh_req_valid(1'b0),
                    .coh_req_type(3'd0),
                    .coh_rsp_valid(),
                    .coh_rsp_state()
                );

                // L1数据缓存实例（使用通用cache模块）
                cache #(
                    .CACHE_LINE_SIZE(`L1_DCACHE_LINE_SIZE),
                    .CACHE_SIZE(`L1_DCACHE_SIZE),
                    .ASSOCIATIVITY(`L1_DCACHE_ASSOCIATIVITY),
                    .ADDR_WIDTH(`L1_DCACHE_ADDR_WIDTH),
                    .DATA_WIDTH(`L1_DCACHE_DATA_WIDTH),
                    .SUPPORT_COHERENCY(0),  // L1缓存是核心独享的，不需要一致性
                    .CACHE_LEVEL(`CACHE_LEVEL_L1),
                    .REPLACEMENT_POLICY(`REPLACEMENT_LRU)
                ) u_l1_dcache (
                    .clk(clk),
                    .rst_n(rst_n),

                    // CPU接口
                    .cpu_req_valid(dcache_req),
                    .cpu_req_addr(dcache_addr),
                    .cpu_req_rw(dcache_we),
                    .cpu_req_data(dcache_wdata),
                    .cpu_req_strb(dcache_byte_en),
                    .cpu_rsp_valid(dcache_ready),
                    .cpu_rsp_data(dcache_rdata),
                    .cpu_rsp_error(),

                    // 内存接口（连接L2）
                    .mem_req_valid(l1_dcache_req[i]),
                    .mem_req_addr(l1_dcache_addr_64),
                    .mem_req_rw(l1_dcache_we[i]),
                    .mem_req_data(l1_dcache_wdata[i*512 +: 64]),
                    .mem_rsp_valid(l1_dcache_ready[i]),
                    .mem_rsp_data(l1_dcache_data[i*512 +: 64]),
                    .mem_rsp_error(),

                    // 一致性接口（不使用，连接到0）
                    .coh_req_addr(64'd0),
                    .coh_req_valid(1'b0),
                    .coh_req_type(3'd0),
                    .coh_rsp_valid(),
                    .coh_rsp_state()
                );
            end
            // 预留其他CPU类型的实现
            else if (CPU_TYPE == 1) begin : other_cpu_implementation
                // 其他CPU类型的实现可以在这里添加
                // 当前只是占位，实际实现需要根据具体的CPU架构来编写
                assign rx_req_valid_o = 1'b0;
                assign rx_req_is_order_o = 1'b0;
                assign rx_req_opcode_o = {OPCODE_WIDTH{1'b0}};
                assign rx_req_match_type_o = {MATCH_TYPE_WIDTH{1'b0}};
                assign rx_req_source_id_o = {NODE_ID_WIDTH{1'b0}};
                assign rx_req_target_id_o = {NODE_ID_WIDTH{1'b0}};
                assign rx_req_addr_o = {ADDR_WIDTH{1'b0}};
                assign rx_req_data_o = {DATA_WIDTH{1'b0}};
                assign rsp_valid_o = 1'b0;
                assign rsp_source_id_o = {NODE_ID_WIDTH{1'b0}};
                assign rsp_target_id_o = {NODE_ID_WIDTH{1'b0}};
                assign rsp_addr_o = {ADDR_WIDTH{1'b0}};
                assign rsp_data_o = {DATA_WIDTH{1'b0}};
            end
        end
    endgenerate

endmodule