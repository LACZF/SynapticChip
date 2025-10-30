`include "stddef.v"

module gpio_top #(
    parameter GPIO_IN_CH   = 1,
    parameter GPIO_OUT_CH  = 1,
    parameter GPIO_IO_CH   = 1
) (
    // 时钟和复位信号
    input  wire                        clk,
    input  wire                        rst_n,

    // OBI总线接口
    input  wire                        req_i,
    input  wire                        we_i,
    input  wire [31:0]                 addr_i,
    input  wire [31:0]                 wr_data_i,
    output wire [31:0]                 data_out_o,
    output wire                        gnt_o,
    output wire                        rvalid_o,

    // GPIO接口
    input  wire [GPIO_IN_CH-1:0]       gpio_in,
    output wire [GPIO_OUT_CH-1:0]      gpio_out,
    inout  wire [GPIO_IO_CH-1:0]       gpio_io
);

    // 寄存器地址定义
    localparam GPIO_IN_REG_ADDR    = 32'h00;  // 输入寄存器 (只读)
    localparam GPIO_OUT_REG_ADDR   = 32'h04;  // 输出寄存器
    localparam GPIO_DIR_REG_ADDR   = 32'h08;  // 方向寄存器
    localparam GPIO_IO_REG_ADDR    = 32'h0C;  // IO数据寄存器

    // 内部寄存器定义
    reg [GPIO_OUT_CH-1:0]  out_reg;           // 输出数据寄存器
    reg [GPIO_IO_CH-1:0]   dir_reg;           // 方向寄存器 (0:输入, 1:输出)
    reg [GPIO_IO_CH-1:0]   io_data_reg;       // IO数据寄存器

    // OBI总线信号
    reg                    gnt_o_reg;         // 授予信号寄存器
    reg                    rvalid_o_reg;      // 读有效信号寄存器
    reg [31:0]             data_out_o_reg;    // 数据输出寄存器

    // 双向IO控制
    reg [GPIO_IO_CH-1:0]   io_out;            // IO输出数据

    // 双向IO引脚连接
    generate
        genvar i;
        for (i = 0; i < GPIO_IO_CH; i = i + 1) begin : io_bidir_gen
            assign gpio_io[i] = dir_reg[i] ? io_out[i] : 1'bz;
        end
    endgenerate

    // 输出寄存器连接到输出引脚
    assign gpio_out = out_reg;

    // OBI总线输出信号
    assign gnt_o = gnt_o_reg;
    assign rvalid_o = rvalid_o_reg;
    assign data_out_o = data_out_o_reg;

    // OBI总线接口处理
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 复位状态
            out_reg        <= {GPIO_OUT_CH{1'b0}};
            dir_reg        <= {GPIO_IO_CH{1'b0}}; // 默认输入
            io_data_reg    <= {GPIO_IO_CH{1'b0}};
            gnt_o_reg      <= `DISABLE;
            rvalid_o_reg   <= `DISABLE;
            data_out_o_reg <= `WORD_DATA_W'h0;
            io_out         <= {GPIO_IO_CH{1'b0}};
        end else begin
            // 处理总线请求
            if (req_i && !gnt_o_reg) begin
                // 授予请求
                gnt_o_reg <= `ENABLE;

                // 处理写操作
                if (we_i) begin
                    case (addr_i)
                        GPIO_OUT_REG_ADDR: begin
                            out_reg <= wr_data_i[GPIO_OUT_CH-1:0];
                        end
                        GPIO_DIR_REG_ADDR: begin
                            dir_reg <= wr_data_i[GPIO_IO_CH-1:0];
                        end
                        GPIO_IO_REG_ADDR: begin
                            io_data_reg <= wr_data_i[GPIO_IO_CH-1:0];
                            io_out <= wr_data_i[GPIO_IO_CH-1:0];
                        end
                    endcase

                    // 写操作的rvalid_o信号
                    rvalid_o_reg <= `ENABLE;
                end else if (gnt_o_reg) begin
                    // 确保rvalid_o_reg在操作完成后被重置
                    rvalid_o_reg <= `DISABLE;
                    gnt_o_reg <= `DISABLE;
                end else begin
                    // 处理读操作
                    case (addr_i)
                        GPIO_IN_REG_ADDR: begin
                            data_out_o_reg[GPIO_IN_CH-1:0] <= gpio_in;
                            if (GPIO_IN_CH < 32) begin
                                data_out_o_reg[31:GPIO_IN_CH] <= {(32-GPIO_IN_CH){1'b0}};
                            end
                        end
                        GPIO_OUT_REG_ADDR: begin
                            data_out_o_reg[GPIO_OUT_CH-1:0] <= out_reg;
                            if (GPIO_OUT_CH < 32) begin
                                data_out_o_reg[31:GPIO_OUT_CH] <= {(32-GPIO_OUT_CH){1'b0}};
                            end
                        end
                        GPIO_DIR_REG_ADDR: begin
                            data_out_o_reg[GPIO_IO_CH-1:0] <= dir_reg;
                            if (GPIO_IO_CH < 32) begin
                                data_out_o_reg[31:GPIO_IO_CH] <= {(32-GPIO_IO_CH){1'b0}};
                            end
                        end
                        GPIO_IO_REG_ADDR: begin
                            // 读取IO寄存器时，根据方向读取相应的值
                            data_out_o_reg[GPIO_IO_CH-1:0] <= dir_reg ? io_data_reg : gpio_io;
                            if (GPIO_IO_CH < 32) begin
                                data_out_o_reg[31:GPIO_IO_CH] <= {(32-GPIO_IO_CH){1'b0}};
                            end
                        end
                        default: begin
                            data_out_o_reg <= `WORD_DATA_W'h0;
                        end
                    endcase

                    // 读操作的rvalid_o信号
                    rvalid_o_reg <= `ENABLE;
                end
            end else begin
                // 清除rvalid_o信号
                if (rvalid_o_reg) begin
                    rvalid_o_reg <= `DISABLE;
                end

                // 清除gnt_o信号
                if (gnt_o_reg && !req_i) begin
                    gnt_o_reg <= `DISABLE;
                end
            end
        end
    end

endmodule