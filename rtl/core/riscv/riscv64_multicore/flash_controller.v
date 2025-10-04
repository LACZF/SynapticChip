// flash_controller.v
`include "soc_params.v"

module flash_controller (
    input wire clk,
    input wire rst_n,

    // 系统接口
    input wire sys_req,
    input wire [63:0] sys_addr,
    input wire [63:0] sys_wdata,
    output reg [63:0] sys_rdata,
    input wire sys_we,
    output reg sys_ready,

    // Flash物理接口
    output reg [23:0] flash_addr,
    input wire [31:0] flash_data_in,
    output reg [31:0] flash_data_out,
    output reg flash_ce_n,
    output reg flash_oe_n,
    output reg flash_we_n,
    output reg flash_wp_n,
    input wire flash_ready
);

    reg [3:0] state;
    reg [63:0] saved_addr;
    reg [63:0] saved_wdata;
    reg saved_we;
    reg [7:0] delay_counter;
    reg [1:0] read_phase;

    localparam STATE_IDLE = 4'b0000;
    localparam STATE_READ_SETUP = 4'b0001;
    localparam STATE_READ_ACCESS = 4'b0010;
    localparam STATE_READ_COMPLETE = 4'b0011;
    localparam STATE_WRITE_SETUP = 4'b0100;
    localparam STATE_WRITE_ACCESS = 4'b0101;
    localparam STATE_WRITE_COMPLETE = 4'b0110;
    localparam STATE_WAIT_READY = 4'b0111;

    // Flash命令定义
    localparam CMD_READ_ARRAY = 8'hFF;
    localparam CMD_WRITE_ENABLE = 8'h06;
    localparam CMD_PAGE_PROGRAM = 8'h02;
    localparam CMD_SECTOR_ERASE = 8'hD8;
    localparam CMD_READ_STATUS = 8'h05;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            sys_ready <= 1'b0;
            flash_ce_n <= 1'b1;
            flash_oe_n <= 1'b1;
            flash_we_n <= 1'b1;
            flash_wp_n <= 1'b1;
            delay_counter <= 8'h00;
            read_phase <= 2'b00;
        end else begin
            case (state)
                STATE_IDLE: begin
                    sys_ready <= 1'b0;
                    flash_ce_n <= 1'b1;
                    flash_oe_n <= 1'b1;
                    flash_we_n <= 1'b1;

                    if (sys_req) begin
                        saved_addr <= sys_addr;
                        saved_wdata <= sys_wdata;
                        saved_we <= sys_we;

                        if (sys_we) begin
                            state <= STATE_WRITE_SETUP;
                        end else begin
                            state <= STATE_READ_SETUP;
                        end
                    end
                end

                STATE_READ_SETUP: begin
                    flash_ce_n <= 1'b0;
                    flash_addr <= saved_addr[23:0];
                    flash_oe_n <= 1'b0;
                    delay_counter <= `FLASH_READ_DELAY;
                    state <= STATE_READ_ACCESS;
                end

                STATE_READ_ACCESS: begin
                    if (delay_counter > 0) begin
                        delay_counter <= delay_counter - 8'h01;
                    end else begin
                        // 读取数据（32位接口，需要两次读取64位数据）
                        case (read_phase)
                            2'b00: begin
                                sys_rdata[31:0] <= flash_data_in;
                                read_phase <= 2'b01;
                                flash_addr <= saved_addr[23:0] + 24'h4;
                                delay_counter <= `FLASH_READ_DELAY;
                            end
                            2'b01: begin
                                sys_rdata[63:32] <= flash_data_in;
                                read_phase <= 2'b00;
                                state <= STATE_READ_COMPLETE;
                            end
                        endcase
                    end
                end

                STATE_READ_COMPLETE: begin
                    flash_ce_n <= 1'b1;
                    flash_oe_n <= 1'b1;
                    sys_ready <= 1'b1;
                    state <= STATE_IDLE;
                end

                STATE_WRITE_SETUP: begin
                    // 使能写操作
                    flash_ce_n <= 1'b0;
                    flash_data_out <= CMD_WRITE_ENABLE;
                    flash_we_n <= 1'b0;
                    delay_counter <= 8'h04;
                    state <= STATE_WAIT_READY;
                end

                STATE_WAIT_READY: begin
                    if (delay_counter > 0) begin
                        delay_counter <= delay_counter - 8'h01;
                    end else begin
                        flash_we_n <= 1'b1;
                        state <= STATE_WRITE_ACCESS;
                    end
                end

                STATE_WRITE_ACCESS: begin
                    // 发送页编程命令
                    flash_data_out <= CMD_PAGE_PROGRAM;
                    flash_we_n <= 1'b0;
                    delay_counter <= 8'h04;
                    state <= STATE_WRITE_COMPLETE;
                end

                STATE_WRITE_COMPLETE: begin
                    if (delay_counter > 0) begin
                        delay_counter <= delay_counter - 8'h01;
                    end else begin
                        flash_we_n <= 1'b1;
                        flash_ce_n <= 1'b1;
                        sys_ready <= 1'b1;
                        state <= STATE_IDLE;
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
