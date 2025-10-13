// UART Core Module Test Bench

`include "uart_params.v"
`timescale 1ns/1ps

module tb_uart_core;

    // Clock and Reset
    reg clk;
    reg rst_n;

    // Control Interface Signals
    reg                    req;
    reg                    we;
    reg  [`ADDR_WIDTH-1:0] addr;
    reg  [`DATA_WIDTH-1:0] data_in;
    wire [`DATA_WIDTH-1:0] data_out;
    wire                   ack;

    // Serial Interface
    wire txd;
    reg  rxd;
    wire rts;
    reg  cts;

    // Interrupt Signal
    wire int_out;

    // DUT Instantiation
    uart_core #(
        .ADDR_WIDTH(`ADDR_WIDTH),
        .DATA_WIDTH(`DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .req_i(req),
        .we_i(we),
        .addr_i(addr),
        .data_in_i(data_in),
        .data_out_o(data_out),
        .ack_o(ack),
        .txd_o(txd),
        .rxd_i(rxd),
        .rts_o(rts),
        .cts_i(cts),
        .int_out_o(int_out)
    );

    // Clock Generation
    always #5 clk = ~clk;

    // Test Task: Send Write Request
    task write_reg;
        input [`ADDR_WIDTH-1:0] reg_addr;
        input [`DATA_WIDTH-1:0] reg_data;
        begin
            @(posedge clk);
            req <= 1'b1;
            we <= 1'b1;
            addr <= reg_addr;
            data_in <= reg_data;

            // Wait for acknowledgment
            wait(ack);
            @(posedge clk);
            req <= 1'b0;
            we <= 1'b0;
        end
    endtask

    // Test Task: Send Read Request
    task read_reg;
        input [`ADDR_WIDTH-1:0] reg_addr;
        output [`DATA_WIDTH-1:0] reg_data;
        begin
            @(posedge clk);
            req <= 1'b1;
            we <= 1'b0;
            addr <= reg_addr;

            // Wait for data
            wait(ack);
            reg_data = data_out;
            @(posedge clk);
            req <= 1'b0;
        end
    endtask

    // Simulate UART Data Reception
    task uart_send_byte;
        input [7:0] data;
        integer i;
        begin
            // Start bit
            rxd <= 1'b0;
            #8680; // Bit time for 115200 baud (1/115200 ≈ 8.68μs)

            // Data bits
            for (i = 0; i < 8; i = i + 1) begin
                rxd <= data[i];
            `ifdef DEBUG
                $display("Sending bit %d: %b", i, data[i]);
            `endif
                #8680;
            end

            // Stop bit
            rxd <= 1'b1;
            #8680;
        end
    endtask

    // Main Test Program
    reg [`DATA_WIDTH-1:0] read_data;

    initial begin
        // Initialization
        clk = 0;
        rst_n = 0;
        req = 0;
        we = 0;
        addr = 0;
        data_in = 0;
        rxd = 1'b1;
        cts = 1'b0;

        // Reset
        #20 rst_n = 1;

        $display("Starting UART Core Test");

        // Test 1: Configure UART
        $display("Test 1: Configure UART");
        write_reg(`REG_LCR, 32'h00000083); // 8 data bits, 1 stop bit, no parity, enable DLAB
        write_reg(`REG_DLL, 32'h0000000C); // Set baud rate to 115200
        write_reg(`REG_DLM, 32'h00000000); // Higher bits are 0
        write_reg(`REG_LCR, 32'h00000003); // Disable DLAB
        write_reg(`REG_IER, 32'h00000001); // Enable receive interrupt

        // Read line status register to confirm successful configuration
        read_reg(`REG_LSR, read_data);
        $display("Initial line status: 0x%h", read_data[7:0]);

        // Test 2: Send data
        $display("Test 2: Send data");
        write_reg(`REG_THR, 32'h00000041); // Send character 'A'
        write_reg(`REG_THR, 32'h00000042); // Send character 'B'
        write_reg(`REG_THR, 32'h00000043); // Send character 'C'

        // Wait for transmission to complete
        #100000;

        // Test 3: Receive data
        $display("Test 3: Receive data");

        // Check if receive FIFO is empty
        read_reg(`REG_LSR, read_data);
        $display("Line status before receive: 0x%h", read_data[7:0]);

        // Send data
        uart_send_byte(8'h31); // Send character '1'
        #100000;

        // Check receive FIFO status
        read_reg(`REG_LSR, read_data);
        $display("Line status after first byte: 0x%h", read_data[7:0]);

        uart_send_byte(8'h32); // Send character '2'
        #100000;

        read_reg(`REG_LSR, read_data);
        $display("Line status after second byte: 0x%h", read_data[7:0]);

        uart_send_byte(8'h33); // Send character '3'
        #100000;

        read_reg(`REG_LSR, read_data);
        $display("Line status after third byte: 0x%h", read_data[7:0]);

        // Test 4: Read received data
        $display("Test 4: Read received data");

        // Check line status register again
        read_reg(`REG_LSR, read_data);
        $display("Line status before read: 0x%h", read_data[7:0]);

        // Read first character
        read_reg(`REG_RBR, read_data);
        $display("Read from RBR: 0x%h", read_data[7:0]);
        if (read_data[7:0] !== 8'h31) begin
            $display("ERROR: Received 0x%h, expected 0x31", read_data[7:0]);
        end else begin
            $display("Received: 0x%h ('%c')", read_data[7:0], read_data[7:0]);
        end

        // Check line status register
        read_reg(`REG_LSR, read_data);
        $display("Line status after first read: 0x%h", read_data[7:0]);

        // Read second character
        read_reg(`REG_RBR, read_data);
        if (read_data[7:0] !== 8'h32) begin
            $display("ERROR: Received 0x%h, expected 0x32", read_data[7:0]);
        end else begin
            $display("Received: 0x%h ('%c')", read_data[7:0], read_data[7:0]);
        end

        // Check line status register
        read_reg(`REG_LSR, read_data);
        $display("Line status after second read: 0x%h", read_data[7:0]);

        // Read third character
        read_reg(`REG_RBR, read_data);
        if (read_data[7:0] !== 8'h33) begin
            $display("ERROR: Received 0x%h, expected 0x33", read_data[7:0]);
        end else begin
            $display("Received: 0x%h ('%c')", read_data[7:0], read_data[7:0]);
        end

        // Check if receive FIFO is empty
        read_reg(`REG_LSR, read_data);
        $display("Final line status: 0x%h", read_data[7:0]);

        // Test 5: Check line status
        $display("Test 5: Check line status");
        read_reg(`REG_LSR, read_data);
        $display("Line status: 0x%h", read_data[7:0]);

        // Test 6: Check interrupt status
        $display("Test 6: Check interrupt status");
        read_reg(`REG_IIR, read_data);
        $display("Interrupt status: 0x%h", read_data[7:0]);

        $display("All tests completed!");
        $finish;
    end

    // Monitor TX Output
    reg [7:0] tx_byte;
    integer tx_bit_count;
    initial begin
        forever begin
            // Wait for start bit
            wait(txd === 1'b0);
            #4340; // Wait to the middle of the bit

            // Receive data bits
            for (tx_bit_count = 0; tx_bit_count < 8; tx_bit_count = tx_bit_count + 1) begin
                #8680;
                tx_byte[tx_bit_count] = txd;
            end

            // Wait for stop bit
            #8680;

            $display("TX: 0x%h ('%c')", tx_byte, tx_byte);
        end
    end

    // Waveform Output
    initial begin
        $dumpfile("uart_core.vcd");
        $dumpvars(0, tb_uart_core);
    end

endmodule