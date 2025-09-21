// pe_node.v
// PE顶层模块，包含存储器和接口逻辑

`include "pe_params.v"

module pe_node (
    input clk,
    input rst_n,
    input enable,

    // 指令接口
    input [`INST_WIDTH-1:0] instruction,
    input inst_valid,

    // 数据存储器接口（连接到共享内存或上级存储器）
    output ext_mem_req,
    output ext_mem_we,
    output [`ADDR_WIDTH-1:0] ext_mem_addr,
    output [`DATA_WIDTH-1:0] ext_mem_data_out,
    input [`DATA_WIDTH-1:0] ext_mem_data_in,
    input ext_mem_ack,

    // 邻居PE通信接口
    input north_valid,
    input [`DATA_WIDTH-1:0] north_data,
    output north_ready,

    input south_valid,
    input [`DATA_WIDTH-1:0] south_data,
    output south_ready,

    input east_valid,
    input [`DATA_WIDTH-1:0] east_data,
    output east_ready,

    input west_valid,
    input [`DATA_WIDTH-1:0] west_data,
    output west_ready,

    output out_valid,
    output [`DATA_WIDTH-1:0] out_data,

    // 状态输出
    output [`DATA_WIDTH-1:0] status,
    output busy
);

    // 本地存储器
    reg [`DATA_WIDTH-1:0] local_mem [0:`MEM_DEPTH-1];
    reg local_mem_ack;

    // 存储器接口信号
    wire mem_req;
    wire mem_we;
    wire [`ADDR_WIDTH-1:0] mem_addr;
    wire [`DATA_WIDTH-1:0] mem_data_out;
    wire [`DATA_WIDTH-1:0] mem_data_in;
    wire mem_ack;

    // 地址解码
    wire local_access = (mem_addr < `MEM_DEPTH);
    wire ext_access = !local_access;

    // 本地存储器访问
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            local_mem_ack <= 0;
            // 初始化本地存储器
            for (integer i = 0; i < `MEM_DEPTH; i = i + 1) begin
                local_mem[i] <= 0;
            end
        end else begin
            local_mem_ack <= 0;

            if (mem_req && local_access) begin
                if (mem_we) begin
                    local_mem[mem_addr] <= mem_data_out;
                end
                local_mem_ack <= 1;
            end
        end
    end

    // 存储器数据选择
    assign mem_data_in = local_access ? local_mem[mem_addr] : ext_mem_data_in;
    assign mem_ack = local_access ? local_mem_ack : ext_mem_ack;

    // 外部存储器接口
    assign ext_mem_req = mem_req && ext_access;
    assign ext_mem_we = mem_we;
    assign ext_mem_addr = mem_addr;
    assign ext_mem_data_out = mem_data_out;

    // PE核心实例化
    pe_core core_inst (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .instruction(instruction),
        .inst_valid(inst_valid),
        .mem_req(mem_req),
        .mem_we(mem_we),
        .mem_addr(mem_addr),
        .mem_data_out(mem_data_out),
        .mem_data_in(mem_data_in),
        .mem_ack(mem_ack),
        .north_valid(north_valid),
        .north_data(north_data),
        .north_ready(north_ready),
        .south_valid(south_valid),
        .south_data(south_data),
        .south_ready(south_ready),
        .east_valid(east_valid),
        .east_data(east_data),
        .east_ready(east_ready),
        .west_valid(west_valid),
        .west_data(west_data),
        .west_ready(west_ready),
        .out_valid(out_valid),
        .out_data(out_data),
        .status(status),
        .busy(busy)
    );

endmodule
