// cache_system_external_flash.v
module cache_system_external_flash (
    input wire clk,
    input wire rst_n,

    // CPU接口
    input wire [31:0] cpu_imem_addr,
    output wire [31:0] cpu_imem_data,
    input wire cpu_imem_req,
    output wire cpu_imem_ack,

    input wire [31:0] cpu_dmem_addr,
    input wire [31:0] cpu_dmem_data_out,
    output wire [31:0] cpu_dmem_data_in,
    input wire cpu_dmem_we,
    input wire [3:0] cpu_dmem_sel,
    input wire cpu_dmem_req,
    output wire cpu_dmem_ack,

    // 外部Flash物理接口
    output wire flash_cs_n,
    output wire flash_clk,
    output wire flash_mosi,
    input wire flash_miso,
    output wire [3:0] flash_dq_o,
    input wire [3:0] flash_dq_i,
    output wire flash_dq_oe,

    // 性能统计
    output wire [31:0] perf_icache_hits,
    output wire [31:0] perf_icache_misses,
    output wire [31:0] perf_dcache_hits,
    output wire [31:0] perf_dcache_misses,
    output wire [31:0] perf_l2cache_hits,
    output wire [31:0] perf_l2cache_misses,
    output wire [31:0] perf_flash_reads,
    output wire [31:0] perf_flash_writes,

    // 调试信号
    output wire [3:0] cache_state,
    output wire [2:0] flash_state
);

    // ==================== 内部信号定义 ====================

    // L1缓存到L2缓存的接口
    wire [31:0] l2_req_addr;
    wire [31:0] l2_req_data;
    wire [31:0] l2_resp_data;
    wire l2_req_we;
    wire [3:0] l2_req_sel;
    wire l2_req_valid;
    wire l2_resp_valid;
    wire l2_busy;

    // L1指令缓存接口
    wire icache_req_valid;
    wire icache_req_ready;
    wire [31:0] icache_req_addr;
    wire [31:0] icache_resp_data;
    wire icache_resp_valid;
    wire icache_miss;

    // L1数据缓存接口
    wire dcache_req_valid;
    wire dcache_req_ready;
    wire [31:0] dcache_req_addr;
    wire [31:0] dcache_req_data;
    wire [31:0] dcache_resp_data;
    wire dcache_req_we;
    wire [3:0] dcache_req_sel;
    wire dcache_resp_valid;
    wire dcache_miss;

    // Flash接口控制器信号
    wire [31:0] flash_ctrl_addr;
    wire [31:0] flash_ctrl_data_out;
    wire [31:0] flash_ctrl_data_in;
    wire flash_ctrl_req;
    wire flash_ctrl_we;
    wire flash_ctrl_ack;
    wire flash_ctrl_busy;

    // 仲裁信号
    wire l2_arb_grant_icache;
    wire l2_arb_grant_dcache;

    // 性能计数器
    reg [31:0] flash_read_count;
    reg [31:0] flash_write_count;

    reg [31:0] cache_data_out;
    wire [31:0] cache_data_in;

    // ==================== 模块实例化 ====================

    // L1指令缓存
    l1_icache #(
        .CACHE_SIZE(8192),
        .LINE_SIZE(16),
        .ASSOCIATIVITY(2)
    ) l1_icache_inst (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_addr(cpu_imem_addr),
        .cpu_data(cpu_imem_data),
        .cpu_req(cpu_imem_req),
        .cpu_ack(cpu_imem_ack),
        .l2_req_valid(icache_req_valid),
        .l2_req_ready(icache_req_ready),
        .l2_req_addr(icache_req_addr),
        .l2_resp_data(icache_resp_data),
        .l2_resp_valid(icache_resp_valid),
        .cache_hits(perf_icache_hits),
        .cache_misses(perf_icache_misses),
        .cache_miss(icache_miss)
    );

    // L1数据缓存
    l1_dcache #(
        .CACHE_SIZE(8192),
        .LINE_SIZE(16),
        .ASSOCIATIVITY(2)
    ) l1_dcache_inst (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_addr(cpu_dmem_addr),
        .cpu_data_in(cpu_dmem_data_out),
        .cpu_data_out(cpu_dmem_data_in),
        .cpu_req(cpu_dmem_req),
        .cpu_ack(cpu_dmem_ack),
        .cpu_we(cpu_dmem_we),
        .cpu_sel(cpu_dmem_sel),
        .l2_req_valid(dcache_req_valid),
        .l2_req_ready(dcache_req_ready),
        .l2_req_addr(dcache_req_addr),
        .l2_req_data(dcache_req_data),
        .l2_resp_data(dcache_resp_data),
        .l2_req_we(dcache_req_we),
        .l2_req_sel(dcache_req_sel),
        .l2_resp_valid(dcache_resp_valid),
        .cache_hits(perf_dcache_hits),
        .cache_misses(perf_dcache_misses),
        .cache_miss(dcache_miss)
    );

    // L2缓存仲裁器
    cache_arbiter l2_arbiter (
        .clk(clk),
        .rst_n(rst_n),
        .icache_req(icache_req_valid),
        .dcache_req(dcache_req_valid),
        .grant_icache(l2_arb_grant_icache),
        .grant_dcache(l2_arb_grant_dcache),
        .icache_busy(icache_miss),
        .dcache_busy(dcache_miss)
    );

    // L2共享缓存（支持外部Flash）
    l2_cache_external_flash #(
        .CACHE_SIZE(32768),
        .LINE_SIZE(32),
        .ASSOCIATIVITY(4)
    ) l2_cache_inst (
        .clk(clk),
        .rst_n(rst_n),
        .l1_req_addr(l2_req_addr),
        .l1_req_data(l2_req_data),
        .l1_resp_data(l2_resp_data),
        .l1_req_we(l2_req_we),
        .l1_req_sel(l2_req_sel),
        .l1_req_valid(l2_req_valid),
        .l1_resp_valid(l2_resp_valid),
        .l1_busy(l2_busy),
        .flash_addr(flash_ctrl_addr),
        .flash_data_out(flash_ctrl_data_out),
        .flash_data_in(flash_ctrl_data_in),
        .flash_req(flash_ctrl_req),
        .flash_we(flash_ctrl_we),
        .flash_ack(flash_ctrl_ack),
        .flash_busy(flash_ctrl_busy),
        .cache_hits(perf_l2cache_hits),
        .cache_misses(perf_l2cache_misses),
        .state_out(cache_state)
    );

    // 外部Flash接口控制器
    flash_interface flash_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .cache_addr(flash_ctrl_addr),
        .cache_data_in(flash_ctrl_data_out),
        .cache_data_out(flash_ctrl_data_in),
        .cache_req(flash_ctrl_req),
        .cache_we(flash_ctrl_we),
        .cache_ack(flash_ctrl_ack),
        .cache_busy(flash_ctrl_busy),
        .flash_cs_n(flash_cs_n),
        .flash_clk(flash_clk),
        .flash_mosi(flash_mosi),
        .flash_miso(flash_miso),
        .flash_dq_o(flash_dq_o),
        .flash_dq_i(flash_dq_i),
        .flash_dq_oe(flash_dq_oe),
        .state_out(flash_state)
    );

    // ==================== 接口连接逻辑 ====================

    // L2缓存请求多路选择
    assign l2_req_valid = (l2_arb_grant_icache && icache_req_valid) ||
                         (l2_arb_grant_dcache && dcache_req_valid);

    assign l2_req_addr = l2_arb_grant_icache ? icache_req_addr : dcache_req_addr;
    assign l2_req_data = dcache_req_data;
    assign l2_req_we = l2_arb_grant_dcache ? dcache_req_we : 1'b0;
    assign l2_req_sel = l2_arb_grant_dcache ? dcache_req_sel : 4'b1111;

    // L2缓存响应分发
    assign icache_resp_data = l2_resp_data;
    assign icache_resp_valid = l2_resp_valid && l2_arb_grant_icache;
    assign icache_req_ready = l2_arb_grant_icache && !l2_busy;

    assign dcache_resp_data = l2_resp_data;
    assign dcache_resp_valid = l2_resp_valid && l2_arb_grant_dcache;
    assign dcache_req_ready = l2_arb_grant_dcache && !l2_busy;

    // 性能统计
    assign perf_flash_reads = flash_read_count;
    assign perf_flash_writes = flash_write_count;

    // Flash访问计数
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            flash_read_count <= 32'h0;
            flash_write_count <= 32'h0;
        end else begin
            if (flash_ctrl_req && !flash_ctrl_we && flash_ctrl_ack) begin
                flash_read_count <= flash_read_count + 1;
            end
            if (flash_ctrl_req && flash_ctrl_we && flash_ctrl_ack) begin
                flash_write_count <= flash_write_count + 1;
            end
        end
    end

endmodule
