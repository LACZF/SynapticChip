module ip4_obi_to_apb_bridge (
    // OBI接口信号
    input  wire        clk,
    input  wire        rst_n,

    // OBI主设备接口
    input  wire        obi_req_i,
    input  wire [31:0] obi_addr_i,
    input  wire        obi_we_i,
    input  wire [31:0] obi_wdata_i,
    input  wire [3:0]  obi_be_i,
    output wire        obi_gnt_o,
    output wire        obi_rvalid_o,
    output wire [31:0] obi_rdata_o,

    // APB从设备接口
    output wire        apb_psel_o,
    output wire        apb_penable_o,
    output wire [31:0] apb_paddr_o,
    output wire        apb_pwrite_o,
    output wire [31:0] apb_pwdata_o,
    input  wire [31:0] apb_prdata_i,
    input  wire        apb_pready_i
);

    // 状态定义
    localparam IDLE  = 2'b00;
    localparam SETUP = 2'b01;
    localparam ACCESS = 2'b10;

    reg [1:0] state;
    reg [31:0] addr_reg;
    reg we_reg;
    reg [31:0] wdata_reg;
    reg [3:0] be_reg;

    // OBI响应信号
    reg rvalid_reg;
    reg [31:0] rdata_reg;
    reg gnt_reg;
    reg transaction_in_progress;

    // 状态机逻辑 - 简单直接的实现
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            addr_reg <= 32'b0;
            we_reg <= 1'b0;
            wdata_reg <= 32'b0;
            be_reg <= 4'b0;
            rvalid_reg <= 1'b0;
            rdata_reg <= 32'b0;
            gnt_reg <= 1'b0;
            transaction_in_progress <= 1'b0;
        end else begin
            // 默认清除rvalid和gnt
            rvalid_reg <= 1'b0;
            gnt_reg <= 1'b0;

            case (state)
                IDLE: begin
                    // 在IDLE状态，检查新请求
                    if (obi_req_i && !transaction_in_progress) begin
                        // 立即授权
                        gnt_reg <= 1'b1;
                        // 锁存请求信号
                        addr_reg <= obi_addr_i;
                        we_reg <= obi_we_i;
                        wdata_reg <= obi_wdata_i;
                        be_reg <= obi_be_i;
                        // 标记事务开始
                        transaction_in_progress <= 1'b1;
                        // 进入SETUP状态
                        state <= SETUP;
                    end
                end
                SETUP: begin
                    // 直接进入ACCESS状态
                    state <= ACCESS;
                end
                ACCESS: begin
                    // 当从设备就绪时完成事务
                    if (apb_pready_i) begin
                        // 生成rvalid响应
                        rvalid_reg <= 1'b1;
                        // 对于读操作，采样当前的prdata
                        rdata_reg <= apb_prdata_i;
                        // 标记事务完成
                        transaction_in_progress <= 1'b0;
                        // 回到IDLE状态
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

    // APB信号直接根据当前状态生成
    assign apb_psel_o = (state == SETUP) || (state == ACCESS);
    assign apb_penable_o = (state == ACCESS);
    assign apb_paddr_o = addr_reg;
    assign apb_pwrite_o = we_reg;
    assign apb_pwdata_o = wdata_reg;

    // OBI输出
    assign obi_gnt_o = gnt_reg;
    assign obi_rvalid_o = rvalid_reg;
    assign obi_rdata_o = rdata_reg;

endmodule