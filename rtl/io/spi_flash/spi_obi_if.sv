// Copyright 2017 ETH Zurich and University of Bologna.
//
// -- Adaptable modifications are redistributed under compatible License --
//
// Copyright (c) 2023-2025 Miao Yuchi <miaoyuchi@ict.ac.cn>
// spi is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.

// verilog_format: off
`define log2(VALUE) ((VALUE) < ( 1 ) ? 0 : (VALUE) < ( 2 ) ? 1 : (VALUE) < ( 4 ) ? 2 : (VALUE) < ( 8 ) ? 3 : (VALUE) < ( 16 )  ? 4 : (VALUE) < ( 32 )  ? 5 : (VALUE) < ( 64 )  ? 6 : (VALUE) < ( 128 ) ? 7 : (VALUE) < ( 256 ) ? 8 : (VALUE) < ( 512 ) ? 9 : (VALUE) < ( 1024 ) ? 10 : (VALUE) < ( 2048 ) ? 11 : (VALUE) < ( 4096 ) ? 12 : (VALUE) < ( 8192 ) ? 13 : (VALUE) < ( 16384 ) ? 14 : (VALUE) < ( 32768 ) ? 15 : (VALUE) < ( 65536 ) ? 16 : (VALUE) < ( 131072 ) ? 17 : (VALUE) < ( 262144 ) ? 18 : (VALUE) < ( 524288 ) ? 19 : (VALUE) < ( 1048576 ) ? 20 : (VALUE) < ( 1048576 * 2 ) ? 21 : (VALUE) < ( 1048576 * 4 ) ? 22 : (VALUE) < ( 1048576 * 8 ) ? 23 : (VALUE) < ( 1048576 * 16 ) ? 24 : 25)
// verilog_format: on

`define REG_STATUS 4'b0000 // BASEREG + 0x00
`define REG_CLKDIV 4'b0001 // BASEREG + 0x04
`define REG_SPICMD 4'b0010 // BASEREG + 0x08
`define REG_SPIADR 4'b0011 // BASEREG + 0x0C
`define REG_SPILEN 4'b0100 // BASEREG + 0x10
`define REG_SPIDUM 4'b0101 // BASEREG + 0x14
`define REG_TXFIFO 4'b0110 // BASEREG + 0x18
`define REG_RXFIFO 4'b1000 // BASEREG + 0x20
`define REG_INTCFG 4'b1001 // BASEREG + 0x24
`define REG_INTSTA 4'b1010 // BASEREG + 0x28

module ip0_spi_obi_if #(
    parameter BUFFER_DEPTH     = 10,
    parameter LOG_BUFFER_DEPTH = `log2(BUFFER_DEPTH)
) (
    // OBI总线接口
    input  wire                        clk_i,
    input  wire                        rst_ni,
    input  wire                        req_i,
    input  wire                        we_i,
    input  wire [3:0]                  be_i,
    input  wire [31:0]                 addr_i,
    input  wire [31:0]                 data_i,
    output wire                        gnt_o,
    output wire                        rvalid_o,
    output wire [31:0]                 data_o,

    // SPI控制信号
    output reg  [7:0]                  spi_clk_div,
    output reg                         spi_clk_div_valid,
    input  wire [31:0]                 spi_status,
    output reg  [31:0]                 spi_addr,
    output reg  [5:0]                  spi_addr_len,
    output reg  [31:0]                 spi_cmd,
    output reg  [5:0]                  spi_cmd_len,
    output reg  [3:0]                  spi_csreg,
    output reg  [15:0]                 spi_data_len,
    output reg  [15:0]                 spi_dummy_rd,
    output reg  [15:0]                 spi_dummy_wr,
    output reg  [LOG_BUFFER_DEPTH:0]   spi_int_th_tx,
    output reg  [LOG_BUFFER_DEPTH:0]   spi_int_th_rx,
    output reg                         spi_int_en,
    input  wire [31:0]                 spi_int_status,
    output reg                         spi_swrst,
    output reg                         spi_rd,
    output reg                         spi_wr,
    output reg                         spi_qrd,
    output reg                         spi_qwr,
    output wire [31:0]                 spi_data_tx,
    output wire                        spi_data_tx_valid,
    input  wire                        spi_data_tx_ready,
    input  wire [31:0]                 spi_data_rx,
    input  wire                        spi_data_rx_valid,
    output wire                        spi_data_rx_ready
);

  reg gnt_reg;
  reg rvalid_reg;
  reg [31:0] rdata_reg;

  wire [3:0] write_address;
  wire [3:0] read_address;

  assign write_address = addr_i[5:2];
  assign read_address  = addr_i[5:2];

  // OBI接口控制
  assign gnt_o = gnt_reg;
  assign rvalid_o = rvalid_reg;
  assign data_o = rdata_reg;

  // 请求处理
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      gnt_reg <= 1'b0;
      rvalid_reg <= 1'b0;
      rdata_reg <= 32'b0;
    end else begin
      // 立即授权请求
      gnt_reg <= req_i;

      // 延迟一个周期返回数据
      if (gnt_reg) begin
        rvalid_reg <= 1'b1;
        rdata_reg <= rdata_reg; // 保持数据
      end else begin
        rvalid_reg <= 1'b0;
      end
    end
  end

  // 寄存器写操作
  always @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      spi_swrst         <= 1'b0;
      spi_rd            <= 1'b0;
      spi_wr            <= 1'b0;
      spi_qrd           <= 1'b0;
      spi_qwr           <= 1'b0;
      spi_clk_div_valid <= 1'b0;
      spi_clk_div       <= 'b0;
      spi_cmd           <= 'b0;
      spi_addr          <= 'b0;
      spi_cmd_len       <= 'b0;
      spi_addr_len      <= 'b0;
      spi_data_len      <= 'b0;
      spi_dummy_rd      <= 'b0;
      spi_dummy_wr      <= 'b0;
      spi_csreg         <= 'b0;
      spi_int_th_tx     <= 'b0;
      spi_int_th_rx     <= 'b0;
      spi_int_en        <= 1'b0;
    end else if (req_i && we_i) begin
      spi_swrst         <= 1'b0;
      spi_rd            <= 1'b0;
      spi_wr            <= 1'b0;
      spi_qrd           <= 1'b0;
      spi_qwr           <= 1'b0;
      spi_clk_div_valid <= 1'b0;

      case (write_address)
        `REG_STATUS: begin
          spi_rd    <= data_i[0];
          spi_wr    <= data_i[1];
          spi_qrd   <= data_i[2];
          spi_qwr   <= data_i[3];
          spi_swrst <= data_i[4];
          spi_csreg <= data_i[11:8];
        end
        `REG_CLKDIV: begin
          spi_clk_div       <= data_i[7:0];
          spi_clk_div_valid <= 1'b1;
        end
        `REG_SPICMD: spi_cmd <= data_i;
        `REG_SPIADR: spi_addr <= data_i;
        `REG_SPILEN: begin
          spi_cmd_len        <= data_i[5:0];
          spi_addr_len       <= data_i[13:8];
          spi_data_len[7:0]  <= data_i[23:16];
          spi_data_len[15:8] <= data_i[31:24];
        end
        `REG_SPIDUM: begin
          spi_dummy_rd[7:0]  <= data_i[7:0];
          spi_dummy_rd[15:8] <= data_i[15:8];
          spi_dummy_wr[7:0]  <= data_i[23:16];
          spi_dummy_wr[15:8] <= data_i[31:24];
        end
        `REG_INTCFG: begin
          spi_int_th_tx <= data_i[LOG_BUFFER_DEPTH:0];
          spi_int_th_rx <= data_i[8+LOG_BUFFER_DEPTH:8];
          spi_int_en    <= data_i[31];
        end
      endcase
    end else begin
      spi_swrst         <= 1'b0;
      spi_rd            <= 1'b0;
      spi_wr            <= 1'b0;
      spi_qrd           <= 1'b0;
      spi_qwr           <= 1'b0;
      spi_clk_div_valid <= 1'b0;
    end
  end

  // 寄存器读操作
  always @(*) begin
    case (read_address)
      `REG_STATUS: rdata_reg = spi_status;
      `REG_CLKDIV: rdata_reg = {24'h0, spi_clk_div};
      `REG_SPICMD: rdata_reg = spi_cmd;
      `REG_SPIADR: rdata_reg = spi_addr;
      `REG_SPILEN: rdata_reg = {spi_data_len, 2'b00, spi_addr_len, 2'b00, spi_cmd_len};
      `REG_SPIDUM: rdata_reg = {spi_dummy_wr, spi_dummy_rd};
      `REG_RXFIFO: rdata_reg = spi_data_rx;
      `REG_INTCFG: begin
        rdata_reg                       = 'b0;
        rdata_reg[LOG_BUFFER_DEPTH:0]   = spi_int_th_tx;
        rdata_reg[8+LOG_BUFFER_DEPTH:8] = spi_int_th_rx;
        rdata_reg[31]                   = spi_int_en;
      end
      `REG_INTSTA: rdata_reg = spi_int_status;
      default:     rdata_reg = 'b0;
    endcase
  end

  // FIFO数据接口
  assign spi_data_tx       = data_i;
  assign spi_data_tx_valid = (req_i && we_i) && (write_address == `REG_TXFIFO);
  assign spi_data_rx_ready = (req_i && !we_i) && (read_address == `REG_RXFIFO);

endmodule