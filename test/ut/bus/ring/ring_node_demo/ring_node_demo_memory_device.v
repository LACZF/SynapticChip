
// 简单的内存设备模型
module memory_device #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 64,
    parameter MEM_SIZE = 1024
) (
    input  wire                         clk,
    input  wire                         rst_n,

    // 设备接口
    input  wire                         dev_req_valid,
    input  wire                         dev_req_type,       // 0:读, 1:写
    input  wire [ADDR_WIDTH-1:0]        dev_req_addr,
    input  wire [DATA_WIDTH-1:0]        dev_req_data,
    output wire                         dev_req_ready,

    output wire                         dev_rsp_valid,
    output wire [DATA_WIDTH-1:0]        dev_rsp_data,
    output wire                         dev_rsp_error,
    input  wire                         dev_rsp_ready,

    // 状态输出
    output wire                         mem_busy
);

    localparam MEM_ADDR_WIDTH = $clog2(MEM_SIZE);

    // 内存阵列
    reg [DATA_WIDTH-1:0] memory [0:MEM_SIZE-1];

    // 内部信号
    reg                         processing;
    reg                         req_type;
    reg [MEM_ADDR_WIDTH-1:0]    req_addr;
    reg [DATA_WIDTH-1:0]        req_data;
    reg [DATA_WIDTH-1:0]        rsp_data;
    reg                         rsp_error;

    // 初始化内存
    integer i;
    initial begin
        for (i = 0; i < MEM_SIZE; i = i + 1) begin
            memory[i] = i;
        end
    end

    // 请求处理
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            processing <= 1'b0;
            req_type <= 1'b0;
            req_addr <= {MEM_ADDR_WIDTH{1'b0}};
            req_data <= {DATA_WIDTH{1'b0}};
            rsp_data <= {DATA_WIDTH{1'b0}};
            rsp_error <= 1'b0;
        end else begin
            if (dev_req_valid && dev_req_ready && !processing) begin
                processing <= 1'b1;
                req_type <= dev_req_type;
                req_addr <= dev_req_addr[MEM_ADDR_WIDTH-1:0];
                req_data <= dev_req_data;

                // 模拟处理延迟
                #1; // 模拟组合逻辑延迟

                if (dev_req_type) begin
                    // 写操作
                    if (req_addr < MEM_SIZE) begin
                        memory[req_addr] <= dev_req_data;
                        rsp_data <= dev_req_data;
                        rsp_error <= 1'b0;
                    end else begin
                        rsp_data <= {DATA_WIDTH{1'b0}};
                        rsp_error <= 1'b1;
                    end
                end else begin
                    // 读操作
                    if (req_addr < MEM_SIZE) begin
                        rsp_data <= memory[req_addr];
                        rsp_error <= 1'b0;
                    end else begin
                        rsp_data <= {DATA_WIDTH{1'b0}};
                        rsp_error <= 1'b1;
                    end
                end
            end else if (processing && dev_rsp_valid && dev_rsp_ready) begin
                processing <= 1'b0;
            end
        end
    end

    // 接口控制
    assign dev_req_ready = !processing;
    assign dev_rsp_valid = processing;
    assign dev_rsp_data = rsp_data;
    assign dev_rsp_error = rsp_error;

    assign mem_busy = processing;

endmodule
