// flash_controller.v
// Flash控制器，用于初始化ROM内容

`include "rom_params.v"

module flash_controller (
    input clk,
    input rst_n,
    input init_req,  // 初始化请求

    // Flash接口
    output reg flash_ce_n,
    output reg flash_oe_n,
    output reg flash_we_n,
    output reg [`FLASH_ADDR_WIDTH-1:0] flash_addr,
    inout [`FLASH_DATA_WIDTH-1:0] flash_data,

    // ROM接口
    output reg rom_init_req,
    output reg [`ADDR_WIDTH-1:0] rom_init_addr,
    output reg [`DATA_WIDTH-1:0] rom_init_data,
    input rom_init_ack,

    // 状态输出
    output reg init_done
);

    // 内部状态
    reg [2:0] state;
    reg [`ADDR_WIDTH-1:0] rom_addr_counter;
    reg [3:0] byte_counter;
    reg [`DATA_WIDTH-1:0] data_buffer;

    // Flash数据总线控制
    reg flash_data_dir; // 0:输入, 1:输出
    reg [`FLASH_DATA_WIDTH-1:0] flash_data_out;

    assign flash_data = flash_data_dir ? flash_data_out : {`FLASH_DATA_WIDTH{1'bz}};

    // 状态定义
    parameter S_IDLE = 3'b000;
    parameter S_READ_FLASH = 3'b001;
    parameter S_WAIT_FLASH = 3'b010;
    parameter S_WRITE_ROM = 3'b011;
    parameter S_DONE = 3'b100;

    // 状态机
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            flash_ce_n <= 1'b1;
            flash_oe_n <= 1'b1;
            flash_we_n <= 1'b1;
            flash_data_dir <= 1'b0;
            rom_init_req <= 1'b0;
            init_done <= 1'b0;
            rom_addr_counter <= 0;
            byte_counter <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (init_req) begin
                        state <= S_READ_FLASH;
                        flash_ce_n <= 1'b0;
                        rom_addr_counter <= 0;
                        byte_counter <= 0;
                    end
                end

                S_READ_FLASH: begin
                    // 设置Flash地址
                    flash_addr <= {10'b0, rom_addr_counter, byte_counter[1:0]};
                    flash_oe_n <= 1'b0;
                    flash_data_dir <= 1'b0; // 从Flash读取

                    state <= S_WAIT_FLASH;
                end

                S_WAIT_FLASH: begin
                    // 等待Flash数据稳定
                    if (byte_counter == 2) begin
                        data_buffer[7:0] <= flash_data;
                    end else if (byte_counter == 3) begin
                        data_buffer[15:8] <= flash_data;
                    end else if (byte_counter == 4) begin
                        data_buffer[23:16] <= flash_data;
                    end else if (byte_counter == 5) begin
                        data_buffer[31:24] <= flash_data;

                        // 已读取4个字节，准备写入ROM
                        state <= S_WRITE_ROM;
                        rom_init_req <= 1'b1;
                        rom_init_addr <= rom_addr_counter;
                        rom_init_data <= data_buffer;
                    end

                    byte_counter <= byte_counter + 1;
                end

                S_WRITE_ROM: begin
                    if (rom_init_ack) begin
                        rom_init_req <= 1'b0;

                        if (rom_addr_counter == `ROM_DEPTH - 1) begin
                            // 所有地址都已初始化
                            state <= S_DONE;
                        end else begin
                            // 继续读取下一个地址
                            rom_addr_counter <= rom_addr_counter + 1;
                            byte_counter <= 0;
                            state <= S_READ_FLASH;
                        end
                    end
                end

                S_DONE: begin
                    init_done <= 1'b1;
                    flash_ce_n <= 1'b1;
                    flash_oe_n <= 1'b1;
                end
            endcase
        end
    end

endmodule
