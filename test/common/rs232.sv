// Copyright (c) 2023-2024 Miao Yuchi <miaoyuchi@ict.ac.cn>
// uart is licensed under Mulan PSL v2.
// You can use this software according to the terms and conditions of the Mulan PSL v2.
// You may obtain a copy of Mulan PSL v2 at:
//             http://license.coscl.org.cn/MulanPSL2
// THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
// EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
// MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
// See the Mulan PSL v2 for more details.
`timescale 1ns/1ps

module rs232 #(
    parameter int BAUD_RATE    = 115200,
    parameter int LOOPBACK     = 0
) (
    input  logic         rs232_rx_i,
    output reg   [7:0]   rs232_rx_data_o,
    output reg           rs232_rx_busy_o,
    output reg           rs232_rx_ready_o,

    input  wire  [7:0]   rs232_tx_data_i,
    input  wire          rs232_tx_start_i,
    output reg           rs232_tx_busy_o,
    output reg           rs232_tx_end_o,
    output logic         rs232_tx_o
);

  // unit: ns
  localparam DELAY_TIME = (10_0000_0000 / BAUD_RATE);
  logic [7:0] data;

  initial begin
    rs232_tx_o = 1'b1;
    rs232_rx_busy_o = 1'b0;
    rs232_rx_ready_o = 1'b0;
    rs232_tx_busy_o = 1'b0;
    rs232_tx_end_o = 1'b0;
  end

  always @(negedge rs232_rx_i) begin
    receive(data);
    // $write("%c", data);
    if (LOOPBACK) send(data);
  end

  // 发送数据逻辑
  always @(posedge rs232_tx_start_i) begin
    if (rs232_tx_busy_o == 1'b0) begin
      send(rs232_tx_data_i);
    end
  end

  task automatic receive(output bit [7:0] value);
    begin
      value = '0;
      rs232_rx_busy_o = 1'b1;
      rs232_rx_ready_o = 1'b0;
      #(DELAY_TIME * 1.5);
      for (int i = 0; i < 8; i++) begin
        value[i] = rs232_rx_i;
        #(DELAY_TIME);
      end
      rs232_rx_data_o = data;
      rs232_rx_busy_o = 1'b0;
      rs232_rx_ready_o = 1'b1;
      # 10;
      rs232_rx_ready_o = 1'b0;
    end
  endtask

  task automatic send(input bit [7:0] value);
    begin
      rs232_tx_o = 1'b0;
      rs232_tx_busy_o = 1'b1;
      rs232_tx_end_o = 1'b0;
      #(DELAY_TIME);
      for (int i = 0; i < 8; i++) begin
        rs232_tx_o = value[i];
        #(DELAY_TIME);
      end
      rs232_tx_o = 1'b1;
      #(DELAY_TIME);
      rs232_tx_busy_o = 1'b0;
      rs232_tx_end_o = 1'b1;
      # 10;
      rs232_tx_end_o = 1'b0;
    end
  endtask
endmodule
