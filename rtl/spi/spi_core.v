// spi_core.v
// SPI控制器核心实现

`include "spi_params.v"

module spi_core #(
    parameter DATA_WIDTH = `SPI_DATA_WIDTH,
    parameter ADDR_WIDTH = `SPI_ADDR_WIDTH
) (
    input wire clk,
    input wire rst_n,

    // 控制接口
    input wire req,
    input wire we,
    input wire [ADDR_WIDTH-1:0] addr,
    input wire [DATA_WIDTH-1:0] data_in,
    output reg [DATA_WIDTH-1:0] data_out,
    output reg ack,

    // SPI物理接口
    output reg spi_cs_n,
    output reg spi_clk,
    output reg spi_mosi,
    input wire spi_miso
);
    // 内部寄存器
    reg [DATA_WIDTH-1:0] control_reg;
    reg [DATA_WIDTH-1:0] status_reg;
    reg [DATA_WIDTH-1:0] data_reg;
    reg [DATA_WIDTH-1:0] addr_reg;
    reg [DATA_WIDTH-1:0] cmd_reg;
    reg [DATA_WIDTH-1:0] clk_div_reg;
    reg [DATA_WIDTH-1:0] config_reg;

    // SPI状态机变量
    reg [2:0] state;
    reg [7:0] bit_counter;
    reg [7:0] byte_counter;
    reg [7:0] current_cmd;
    reg [23:0] current_addr;
    reg [DATA_WIDTH-1:0] tx_data;
    reg [DATA_WIDTH-1:0] rx_data;
    reg [3:0] clk_divider;
    reg clk_gen;

    // 控制信号
    wire spi_en = control_reg[`SPI_CTRL_EN];
    wire irq_en = control_reg[`SPI_CTRL_IRQ_EN];
    wire master_mode = control_reg[`SPI_CTRL_MASTER];
    wire [1:0] spi_mode = config_reg[1:0];
    wire [7:0] clk_div = clk_div_reg[7:0];

    // SPI时钟生成
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_divider <= 4'h0;
            clk_gen <= 1'b0;
            spi_clk <= 1'b0;
        end else if (spi_en) begin
            clk_divider <= clk_divider + 1;
            if (clk_divider == clk_div) begin
                clk_divider <= 4'h0;
                clk_gen <= ~clk_gen;

                // 根据SPI模式设置时钟相位和极性
                case (spi_mode)
                    `SPI_MODE_0: spi_clk <= clk_gen;
                    `SPI_MODE_1: spi_clk <= ~clk_gen;
                    `SPI_MODE_2: spi_clk <= ~clk_gen;
                    `SPI_MODE_3: spi_clk <= clk_gen;
                endcase
            end
        end else begin
            clk_divider <= 4'h0;
            clk_gen <= 1'b0;
            spi_clk <= 1'b0;
        end
    end
    wire spi_clk_edge = (spi_mode == `SPI_MODE_0 || spi_mode == `SPI_MODE_2) ?
                        (clk_divider == clk_div && !clk_gen) :
                        (clk_divider == clk_div && clk_gen);

    // 寄存器读写逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            control_reg <= 32'h0;
            status_reg <= 32'h0;
            data_reg <= 32'h0;
            addr_reg <= 32'h0;
            cmd_reg <= 32'h0;
            clk_div_reg <= 32'h00000007; // 默认分频值
            config_reg <= 32'h0; // 默认SPI模式0
            ack <= 1'b0;
            data_out <= 32'h0;
        end else begin
            ack <= 1'b0;

            if (req && !ack) begin
                if (we) begin
                    // 写操作
                    case (addr[7:0])
                        `SPI_REG_CONTROL: begin
                            control_reg <= data_in;
                            ack <= 1'b1;
                        end
                        `SPI_REG_DATA: begin
                            data_reg <= data_in;
                            ack <= 1'b1;
                        end
                        `SPI_REG_ADDR: begin
                            addr_reg <= data_in;
                            ack <= 1'b1;
                        end
                        `SPI_REG_CMD: begin
                            cmd_reg <= data_in;
                            ack <= 1'b1;
                            // 启动SPI操作
                            if (spi_en) begin
                                current_cmd <= data_in[7:0];
                                current_addr <= addr_reg[23:0];
                                tx_data <= data_reg;
                                state <= `SPI_STATE_CMD;
                                bit_counter <= 8'h0;
                                byte_counter <= 8'h0;
                                spi_cs_n <= 1'b0;
                                status_reg[`SPI_STATUS_BUSY] <= 1'b1;
                                status_reg[`SPI_STATUS_TX_READY] <= 1'b0;
                            end
                        end
                        `SPI_REG_CLK_DIV: begin
                            clk_div_reg <= data_in;
                            ack <= 1'b1;
                        end
                        `SPI_REG_CONFIG: begin
                            config_reg <= data_in;
                            ack <= 1'b1;
                        end
                    endcase
                end else begin
                    // 读操作
                    case (addr[7:0])
                        `SPI_REG_CONTROL: begin
                            data_out <= control_reg;
                            ack <= 1'b1;
                        end
                        `SPI_REG_STATUS: begin
                            data_out <= status_reg;
                            ack <= 1'b1;
                        end
                        `SPI_REG_DATA: begin
                            data_out <= rx_data;
                            ack <= 1'b1;
                            status_reg[`SPI_STATUS_RX_READY] <= 1'b0;
                        end
                        `SPI_REG_ADDR: begin
                            data_out <= addr_reg;
                            ack <= 1'b1;
                        end
                        `SPI_REG_CMD: begin
                            data_out <= cmd_reg;
                            ack <= 1'b1;
                        end
                        `SPI_REG_CLK_DIV: begin
                            data_out <= clk_div_reg;
                            ack <= 1'b1;
                        end
                        `SPI_REG_CONFIG: begin
                            data_out <= config_reg;
                            ack <= 1'b1;
                        end
                    endcase
                end
            end
        end
    end

    // SPI主状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= `SPI_STATE_IDLE;
            bit_counter <= 8'h0;
            byte_counter <= 8'h0;
            spi_cs_n <= 1'b1;
            spi_mosi <= 1'b0;
            rx_data <= 32'h0;
            status_reg <= 32'h0;
        end else if (spi_en) begin
            case (state)
                `SPI_STATE_IDLE:
                    begin
                        status_reg[`SPI_STATUS_TX_READY] <= 1'b1;
                        status_reg[`SPI_STATUS_BUSY] <= 1'b0;
                    end

                `SPI_STATE_CMD:
                    begin
                        if (spi_clk_edge) begin
                            if (bit_counter < 8) begin
                                // 发送命令字节
                                spi_mosi <= current_cmd[7 - bit_counter[2:0]];
                                bit_counter <= bit_counter + 1;
                            end else begin
                                bit_counter <= 8'h0;
                                byte_counter <= 8'h0;

                                // 根据命令类型决定下一个状态
                                if (current_cmd == `SPI_CMD_READ_DATA ||
                                    current_cmd == `SPI_CMD_FAST_READ ||
                                    current_cmd == `SPI_CMD_READ_DUAL ||
                                    current_cmd == `SPI_CMD_READ_QUAD) begin
                                    state <= `SPI_STATE_ADDR;
                                end else if (current_cmd == `SPI_CMD_WRITE_ENABLE ||
                                            current_cmd == `SPI_CMD_WRITE_DATA) begin
                                    if (current_cmd == `SPI_CMD_WRITE_DATA) begin
                                        state <= `SPI_STATE_ADDR;
                                    end else begin
                                        // 写使能命令不需要地址
                                        state <= `SPI_STATE_DONE;
                                    end
                                end else begin
                                    state <= `SPI_STATE_DONE;
                                end
                            end
                        end
                    end

                `SPI_STATE_ADDR:
                    begin
                        if (spi_clk_edge) begin
                            if (bit_counter < 24) begin  // 24位地址
                                // 发送地址位
                                spi_mosi <= current_addr[23 - bit_counter[4:0]];
                                bit_counter <= bit_counter + 1;
                            end else begin
                                bit_counter <= 8'h0;

                                if (current_cmd == `SPI_CMD_FAST_READ ||
                                    current_cmd == `SPI_CMD_READ_DUAL ||
                                    current_cmd == `SPI_CMD_READ_QUAD) begin
                                    state <= `SPI_STATE_DUMMY;
                                end else if (current_cmd == `SPI_CMD_WRITE_DATA) begin
                                    state <= `SPI_STATE_WRITE;
                                end else begin
                                    state <= `SPI_STATE_READ;
                                end
                            end
                        end
                    end

                `SPI_STATE_DUMMY:
                    begin
                        if (spi_clk_edge) begin
                            if (bit_counter < 8) begin  // 8个dummy周期
                                bit_counter <= bit_counter + 1;
                            end else begin
                                bit_counter <= 8'h0;
                                state <= `SPI_STATE_READ;
                            end
                        end
                    end

                `SPI_STATE_READ:
                    begin
                        if (spi_clk_edge) begin
                            // 读取数据位
                            rx_data <= {rx_data[30:0], spi_miso};
                            bit_counter <= bit_counter + 1;

                            if (bit_counter >= 31) begin  // 读取32位完成
                                state <= `SPI_STATE_DONE;
                                status_reg[`SPI_STATUS_RX_READY] <= 1'b1;
                            end
                        end
                    end

                `SPI_STATE_WRITE:
                    begin
                        if (spi_clk_edge) begin
                            // 发送数据位
                            spi_mosi <= tx_data[31 - bit_counter[4:0]];
                            bit_counter <= bit_counter + 1;

                            if (bit_counter >= 31) begin  // 发送32位完成
                                state <= `SPI_STATE_DONE;
                            end
                        end
                    end

                `SPI_STATE_DONE:
                    begin
                        spi_cs_n <= 1'b1;
                        status_reg[`SPI_STATUS_BUSY] <= 1'b0;
                        status_reg[`SPI_STATUS_TX_READY] <= 1'b1;

                        // 触发中断
                        if (irq_en) begin
                            status_reg[`SPI_STATUS_IRQ_PEND] <= 1'b1;
                        end

                        state <= `SPI_STATE_IDLE;
                    end
            endcase
        end else begin
            state <= `SPI_STATE_IDLE;
            spi_cs_n <= 1'b1;
            status_reg[`SPI_STATUS_BUSY] <= 1'b0;
        end
    end

endmodule