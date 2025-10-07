// gpio_module.v
// GPIO模块实现

`include "gpio_params.v"

module gpio_module #(
    parameter GPIO_WIDTH        = 32
) (
    input clk,
    input rst_n,

    // 控制接口
    input req,
    input we,
    input [`ADDR_WIDTH-1:0] addr,
    input [`DATA_WIDTH-1:0] data_in,
    output reg [`DATA_WIDTH-1:0] data_out,
    output reg ack,

    // GPIO引脚
    inout [GPIO_WIDTH-1:0] gpio_pins,

    // 中断输出
    output reg int_out
);

    // 内部寄存器
    reg [GPIO_WIDTH-1:0] data_reg;     // 数据寄存器
    reg [GPIO_WIDTH-1:0] dir_reg;      // 方向寄存器
    reg [GPIO_WIDTH-1:0] inten_reg;    // 中断使能寄存器
    reg [GPIO_WIDTH-1:0] intpol_reg;   // 中断极性寄存器
    reg [GPIO_WIDTH-1:0] inttype_reg;  // 中断类型寄存器
    reg [GPIO_WIDTH-1:0] intstat_reg;  // 中断状态寄存器
    reg [15:0] debounce_reg;            // 去抖周期寄存器

    // 输入同步和去抖逻辑
    reg [GPIO_WIDTH-1:0] gpio_sync0;
    reg [GPIO_WIDTH-1:0] gpio_sync1;
    reg [GPIO_WIDTH-1:0] gpio_debounced;
    reg [15:0] debounce_counter [GPIO_WIDTH-1:0];
    reg [GPIO_WIDTH-1:0] debounce_active;

    // 中断检测逻辑
    reg [GPIO_WIDTH-1:0] gpio_prev;
    wire [GPIO_WIDTH-1:0] gpio_rise;
    wire [GPIO_WIDTH-1:0] gpio_fall;

    // GPIO引脚控制
    genvar i;
    generate
        for (i = 0; i < GPIO_WIDTH; i = i + 1) begin : gpio_pin
            assign gpio_pins[i] = dir_reg[i] ? data_reg[i] : 1'bz;
        end
    endgenerate

    // 输入同步
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpio_sync0 <= {GPIO_WIDTH{1'b0}};
            gpio_sync1 <= {GPIO_WIDTH{1'b0}};
            gpio_prev <= {GPIO_WIDTH{1'b0}};
        end else begin
            gpio_sync0 <= gpio_pins;
            gpio_sync1 <= gpio_sync0;
            gpio_prev <= gpio_debounced;
        end
    end

    // 边沿检测
    assign gpio_rise = gpio_debounced & ~gpio_prev;
    assign gpio_fall = ~gpio_debounced & gpio_prev;

    // 去抖逻辑
    generate
        for (i = 0; i < GPIO_WIDTH; i = i + 1) begin : debounce
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n) begin
                    debounce_counter[i] <= 0;
                    debounce_active[i] <= 1'b0;
                    gpio_debounced[i] <= 1'b0;
                end else begin
                    if (gpio_sync1[i] != gpio_debounced[i] && !debounce_active[i]) begin
                        // 检测到变化，启动去抖计时器
                        debounce_active[i] <= 1'b1;
                        debounce_counter[i] <= debounce_reg;
                    end else if (debounce_active[i]) begin
                        if (debounce_counter[i] > 0) begin
                            debounce_counter[i] <= debounce_counter[i] - 1;
                        end else begin
                            // 去抖完成，更新去抖后值
                            debounce_active[i] <= 1'b0;
                            gpio_debounced[i] <= gpio_sync1[i];
                        end
                    end
                end
            end
        end
    endgenerate

    // 中断检测
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            intstat_reg <= {GPIO_WIDTH{1'b0}};
            int_out <= 1'b0;
        end else begin
            // 检测中断条件
            for (integer j = 0; j < GPIO_WIDTH; j = j + 1) begin
                if (inten_reg[j]) begin
                    if (inttype_reg[j]) begin
                        // 边沿中断
                        if ((intpol_reg[j] && gpio_rise[j]) || (!intpol_reg[j] && gpio_fall[j])) begin
                            intstat_reg[j] <= 1'b1;
                        end
                    end else begin
                        // 电平中断
                        if ((intpol_reg[j] && gpio_debounced[j]) || (!intpol_reg[j] && !gpio_debounced[j])) begin
                            intstat_reg[j] <= 1'b1;
                        end
                    end
                end
            end

            // 生成中断信号
            int_out <= |(intstat_reg & inten_reg);
        end
    end

    // 寄存器读写
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_reg <= {GPIO_WIDTH{1'b0}};
            dir_reg <= {GPIO_WIDTH{1'b0}};
            inten_reg <= {GPIO_WIDTH{1'b0}};
            intpol_reg <= {GPIO_WIDTH{1'b0}};
            inttype_reg <= {GPIO_WIDTH{1'b0}};
            debounce_reg <= 16'd1000; // 默认去抖周期
            ack <= 1'b0;
            data_out <= {`DATA_WIDTH{1'b0}};
        end else begin
            ack <= 1'b0;

            if (req) begin
                if (we) begin
                    // 写操作
                    case (addr)
                        `REG_DATA: data_reg <= data_in[GPIO_WIDTH-1:0];
                        `REG_DIR: dir_reg <= data_in[GPIO_WIDTH-1:0];
                        `REG_INTEN: inten_reg <= data_in[GPIO_WIDTH-1:0];
                        `REG_INTPOL: intpol_reg <= data_in[GPIO_WIDTH-1:0];
                        `REG_INTTYPE: inttype_reg <= data_in[GPIO_WIDTH-1:0];
                        `REG_INTSTAT: intstat_reg <= intstat_reg & ~data_in[GPIO_WIDTH-1:0]; // 写1清除
                        `REG_DEBOUNCE: debounce_reg <= data_in[15:0];
                    endcase
                end else begin
                    // 读操作
                    case (addr)
                        `REG_DATA: begin
                            // 逐位设置数据寄存器的值
                            for (integer k = 0; k < GPIO_WIDTH; k = k + 1) begin
                                data_out[k] <= dir_reg[k] ? data_reg[k] : gpio_debounced[k];
                            end
                            // 如果数据宽度大于GPIO宽度，高位填充0
                            if (`DATA_WIDTH > GPIO_WIDTH) begin
                                data_out[`DATA_WIDTH-1:GPIO_WIDTH] <= {(`DATA_WIDTH-GPIO_WIDTH){1'b0}};
                            end
                        end
                        `REG_DIR: data_out <= {{(`DATA_WIDTH-GPIO_WIDTH){1'b0}}, dir_reg};
                        `REG_INTEN: data_out <= {{(`DATA_WIDTH-GPIO_WIDTH){1'b0}}, inten_reg};
                        `REG_INTPOL: data_out <= {{(`DATA_WIDTH-GPIO_WIDTH){1'b0}}, intpol_reg};
                        `REG_INTTYPE: data_out <= {{(`DATA_WIDTH-GPIO_WIDTH){1'b0}}, inttype_reg};
                        `REG_INTSTAT: data_out <= {{(`DATA_WIDTH-GPIO_WIDTH){1'b0}}, intstat_reg};
                        `REG_DEBOUNCE: data_out <= {{(`DATA_WIDTH-16){1'b0}}, debounce_reg};
                        default: data_out <= {`DATA_WIDTH{1'b0}};
                    endcase
                end

                ack <= 1'b1;
            end
        end
    end

endmodule