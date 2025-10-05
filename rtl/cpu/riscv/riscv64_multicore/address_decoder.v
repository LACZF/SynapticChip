// address_decoder.v
`include "soc_params.v"

module address_decoder (
    input wire clk,
    input wire rst_n,

    // 系统总线输入
    input wire [63:0] sys_addr,
    input wire [63:0] sys_wdata,
    output reg [63:0] sys_rdata,
    input wire sys_we,
    input wire [7:0] sys_byte_en,
    input wire sys_req,
    output reg sys_ready,

    // Flash控制器接口
    output reg flash_req,
    output reg [63:0] flash_addr,
    output reg [63:0] flash_wdata,
    input wire [63:0] flash_rdata,
    output reg flash_we,
    input wire flash_ready,

    // SRAM控制器接口
    output reg sram_req,
    output reg [63:0] sram_addr,
    output reg [63:0] sram_wdata,
    input wire [63:0] sram_rdata,
    output reg sram_we,
    input wire sram_ready,

    // MMIO接口
    output reg mmio_req,
    output reg [63:0] mmio_addr,
    output reg [63:0] mmio_wdata,
    input wire [63:0] mmio_rdata,
    output reg mmio_we,
    output reg [7:0] mmio_byte_en,
    input wire mmio_ready
);

    reg [2:0] state;
    reg [63:0] saved_addr;
    reg [63:0] saved_wdata;
    reg saved_we;
    reg [7:0] saved_byte_en;
    reg [1:0] target_device;

    localparam STATE_IDLE = 3'b000;
    localparam STATE_DECODE = 3'b001;
    localparam STATE_ACCESS = 3'b010;
    localparam STATE_RESPONSE = 3'b011;

    // 地址范围解码
    always @(*) begin
        if (sys_addr >= `FLASH_BASE_ADDR && sys_addr < (`FLASH_BASE_ADDR + `FLASH_SIZE)) begin
            target_device = 2'b00; // Flash
        end else if (sys_addr >= `SRAM_BASE_ADDR && sys_addr < (`SRAM_BASE_ADDR + `SRAM_SIZE)) begin
            target_device = 2'b01; // SRAM
        end else if (sys_addr >= `MMIO_BASE_ADDR && sys_addr < (`MMIO_BASE_ADDR + `MMIO_SIZE)) begin
            target_device = 2'b10; // MMIO
        end else begin
            target_device = 2'b11; // 未定义地址
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            sys_ready <= 1'b0;
            flash_req <= 1'b0;
            sram_req <= 1'b0;
            mmio_req <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    sys_ready <= 1'b0;

                    if (sys_req) begin
                        state <= STATE_DECODE;
                        saved_addr <= sys_addr;
                        saved_wdata <= sys_wdata;
                        saved_we <= sys_we;
                        saved_byte_en <= sys_byte_en;
                    end
                end

                STATE_DECODE: begin
                    case (target_device)
                        2'b00: begin // Flash
                            flash_addr <= saved_addr;
                            flash_wdata <= saved_wdata;
                            flash_we <= saved_we;
                            flash_req <= 1'b1;
                        end
                        2'b01: begin // SRAM
                            sram_addr <= saved_addr;
                            sram_wdata <= saved_wdata;
                            sram_we <= saved_we;
                            sram_req <= 1'b1;
                        end
                        2'b10: begin // MMIO
                            mmio_addr <= saved_addr;
                            mmio_wdata <= saved_wdata;
                            mmio_we <= saved_we;
                            mmio_byte_en <= saved_byte_en;
                            mmio_req <= 1'b1;
                        end
                        default: begin // 未定义地址
                            sys_ready <= 1'b1; // 立即返回，读操作返回0，写操作忽略
                            state <= STATE_IDLE;
                        end
                    endcase

                    if (target_device != 2'b11) begin
                        state <= STATE_ACCESS;
                    end
                end

                STATE_ACCESS: begin
                    case (target_device)
                        2'b00: begin
                            if (flash_ready) begin
                                sys_rdata <= flash_rdata;
                                sys_ready <= 1'b1;
                                flash_req <= 1'b0;
                                state <= STATE_IDLE;
                            end
                        end
                        2'b01: begin
                            if (sram_ready) begin
                                sys_rdata <= sram_rdata;
                                sys_ready <= 1'b1;
                                sram_req <= 1'b0;
                                state <= STATE_IDLE;
                            end
                        end
                        2'b10: begin
                            if (mmio_ready) begin
                                sys_rdata <= mmio_rdata;
                                sys_ready <= 1'b1;
                                mmio_req <= 1'b0;
                                state <= STATE_IDLE;
                            end
                        end
                    endcase
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
