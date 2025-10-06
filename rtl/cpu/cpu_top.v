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
    parameter NUM_CORES = 4,
    parameter CORE_ID_WIDTH = 2,
    parameter ENABLE_L3_CACHE = 1, // 使能L3缓存，默认为1
    parameter CPU_TYPE          = 0  // 0: RISC-V, 1: 预留其他CPU类型
) (
    input clk,
    input rst_n,

    // 外部中断
    input ext_int,

    // 发送请求
    input wire [NUM_RINGS-1:0]         tx_req_ring_mask_i,
    input wire [NUM_RINGS-1:0]         tx_req_ring_disable_i,
    input wire                         tx_req_valid_i,
    input wire                         tx_req_is_order_i,
    input wire [OPCODE_WIDTH-1:0]      tx_req_opcode_i,
    input wire [MATCH_TYPE_WIDTH-1:0]  tx_req_match_type_i,
    input wire [NODE_ID_WIDTH-1:0]     tx_req_source_id_i,
    input wire [NODE_ID_WIDTH-1:0]     tx_req_target_id_i,
    input wire [ADDR_WIDTH-1:0]        tx_req_addr_i,
    input wire [DATA_WIDTH-1:0]        tx_req_data_i,

    // 接受请求
    output wire                        rx_req_valid_o,
    output wire                        rx_req_is_order_o,
    output wire [OPCODE_WIDTH-1:0]     rx_req_opcode_o,
    output wire [MATCH_TYPE_WIDTH-1:0] rx_req_match_type_o,
    output wire [NODE_ID_WIDTH-1:0]    rx_req_source_id_o,
    output wire [NODE_ID_WIDTH-1:0]    rx_req_target_id_o,
    output wire [ADDR_WIDTH-1:0]       rx_req_addr_o,
    output wire [DATA_WIDTH-1:0]       rx_req_data_o,

    // 接收响应
    output wire                        rsp_valid_o,
    output wire [NODE_ID_WIDTH-1:0]    rsp_source_id_o,
    output wire [NODE_ID_WIDTH-1:0]    rsp_target_id_o,
    output wire [ADDR_WIDTH-1:0]       rsp_addr_o,
    output wire [DATA_WIDTH-1:0]       rsp_data_o
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

    // 中间信号用于L2缓存一致性状态
    wire [2:0] l2_coh_rsp_state;

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
    generate
        for (i = 0; i < NUM_CORES; i = i + 1) begin : l2_response_gen
            assign l1_dcache_data[i*512 +: 512] = core_l2_data[0*512 +: 512];
            assign l1_icache_data[i*512 +: 512] = core_l2_data[0*512 +: 512];
            assign l1_dcache_ready[i] = core_l2_ready[0];
            assign l1_icache_ready[i] = core_l2_ready[0];
        end
    endgenerate

    // L3缓存实例（使用通用cache模块，可选）
    generate
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
        end else begin : direct_mem_access
            // 直接连接L2到内存
            assign mem_req = l2_l3_req;
            assign mem_addr = l2_l3_addr;
            assign mem_wdata = l2_l3_wdata;
            assign mem_we = l2_l3_we;
            assign l2_l3_rdata = mem_rdata;
            assign l2_l3_ready = mem_ready;
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
                wire [63:0] snoop_addr_64;

                // 零扩展：将32位地址信号扩展到64位
                assign l1_icache_addr_64 = {{32{1'b0}}, l1_icache_addr[i*32 +: 32]};
                assign l1_dcache_addr_64 = {{32{1'b0}}, l1_dcache_addr[i*32 +: 32]};
                assign snoop_addr_64 = {{32{1'b0}}, snoop_addr[i*32 +: 32]};
                riscv64_core #(
                    .CORE_ID(i[CORE_ID_WIDTH-1:0])
                ) u_core (
                    .clk(clk),
                    .rst_n(rst_n),

                    // L1指令缓存接口
                .l1_icache_req(l1_icache_req[i]),
                .l1_icache_addr(l1_icache_addr_64),
                .l1_icache_data(l1_icache_data[i*512 +: 512]),
                .l1_icache_ready(l1_icache_ready[i]),

                // L1数据缓存接口
                .l1_dcache_req(l1_dcache_req[i]),
                .l1_dcache_addr(l1_dcache_addr_64),
                .l1_dcache_wdata(l1_dcache_wdata[i*512 +: 512]),
                .l1_dcache_data(l1_dcache_data[i*512 +: 512]),
                .l1_dcache_we(l1_dcache_we[i]),
                .l1_dcache_req_type(l1_dcache_req_type[i*2 +: 2]),
                .l1_dcache_ready(l1_dcache_ready[i]),

                // 监听接口
                .snoop_valid(snoop_valid[i]),
                .snoop_addr(snoop_addr_64),
                    .snoop_req_type(snoop_req_type[i*2 +: 2]),
                    .snoop_ready(snoop_ready[i]),
                    .snoop_hit(snoop_hit[i]),
                    .snoop_state(snoop_state[i*2 +: 2]),
                    .snoop_data(snoop_data[i*512 +: 512]),

                    // 中断和调试
                    // 中断接口
                    .timer_interrupt(1'b0),
                    .external_interrupt(1'b0),
                    .software_interrupt(1'b0),

                    // Debug interface
                    .debug_pc(),
                    .debug_instr(),
                    .debug_wb_valid(),
                    .debug_wb_rd(),
                    .debug_wb_value()
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