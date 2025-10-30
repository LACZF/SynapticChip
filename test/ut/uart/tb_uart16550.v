// UART16550 Test Bench

`timescale 1ns/1ps

module tb_uart16550;

    // Define timeout cycle parameter
    parameter TIMEOUT_CYCLES = 100000; // 100000 clock cycles as timeout threshold

    // Error counter
    integer error_count = 0;

    // Clock and Reset
    reg              clk;              // 系统时钟
    reg              rst_n;            // 复位信号，低电平有效
    reg              baud_clk;         // 波特率时钟

    // 寄存器接口信号
    reg              cs_n;             // 片选信号，低电平有效
    reg              rd_n;             // 读信号，低电平有效
    reg              wr_n;             // 写信号，低电平有效
    reg  [2:0]       addr;             // 地址总线
    reg  [7:0]       wr_data;          // 写入数据总线
    wire [7:0]       rd_data;          // 读取数据总线

    // UART接口信号
    reg              uart_rx;          // UART接收信号
    wire             uart_tx;          // UART发送信号
    wire             irq;              // 中断输出信号

    // DUT Instance - 与uart16550.v的接口匹配
    uart16550 dut (
        .clk(clk),
        .rst_n(rst_n),
        .baud_clk(baud_clk),
        .cs_n(cs_n),
        .rd_n(rd_n),
        .wr_n(wr_n),
        .addr(addr),
        .wr_data(wr_data),
        .rd_data(rd_data),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .irq(irq)
    );

    // Clock Generation (100MHz clock)
    always #5 clk = ~clk;

    // Baud Clock Generation (1MHz for 9600 baud with 16x oversampling)
    always #500 baud_clk = ~baud_clk; // 1MHz = 1000ns period, toggle every 500ns

    // Test Task: Write to UART Register - 适配简单寄存器接口
    task write_register;
        input [2:0] reg_addr;
        input [7:0] data;
        begin
            wait(clk);
            cs_n <= 0;
            wr_n <= 0;
            addr <= reg_addr;
            wr_data <= data;
            #1; // 保证信号稳定
            @(posedge clk);
            #1;
            cs_n <= 1;
            wr_n <= 1;
            wait(clk);
        end
    endtask

    // Test Task: Read from UART Register - 适配简单寄存器接口
    task read_register;
        input  [2:0] reg_addr;
        output [7:0] data;
        begin
            wait(clk);
            cs_n <= 0;
            rd_n <= 0;
            addr <= reg_addr;
            #1; // 保证信号稳定
            @(posedge clk);
            #1;
            data = rd_data;
            cs_n <= 1;
            rd_n <= 1;
            wait(clk);
        end
    endtask

    // Test Task: Configure UART
    task configure_uart;
        input [15:0] divisor;
        begin
            // Set DLAB=1 to access divisor latches
            write_register(3, 8'h80);
            // Write divisor (假设baud_clk为1MHz，9600波特率)
            // Divisor = 1MHz / (16 * 9600) = 6.5104, 使用6 = 0x06
            write_register(0, divisor[7:0]);  // DLL
            write_register(1, divisor[15:8]); // DLM
            // Set DLAB=0, 8 data bits, 1 stop bit, no parity
            write_register(3, 8'h03);
            // Enable FIFO
            write_register(2, 8'h07);
        end
    endtask

    // Test Task: Send Data through UART
    task send_data;
        input [7:0] data;
        begin
            write_register(0, data); // Write to Transmit Holding Register
        end
    endtask

    // Test Task: Receive Data from UART
    task receive_data;
        output [7:0] data;
        begin
            read_register(0, data); // Read from Receive Buffer Register
        end
    endtask

    // Test Task: Wait for Transmit Holding Register Empty
    task automatic wait_for_thre;
        reg [7:0] lsr;
        integer timeout = 10000;
        begin
            while(timeout > 0) begin
                read_register(5, lsr);
                if(lsr[5]) begin // THRE bit set
                    break;
                end
                timeout = timeout - 1;
                @(posedge clk);
            end
            if(timeout == 0) begin
                $display("ERROR: THRE timeout");
                error_count = error_count + 1;
            end
        end
    endtask

    // Test Task: Wait for Data Ready
    task automatic wait_for_data_ready;
        reg [7:0] lsr;
        integer timeout = 10000;
        begin
            while(timeout > 0) begin
                read_register(5, lsr);
                if(lsr[0]) begin // DR bit set
                    break;
                end
                timeout = timeout - 1;
                @(posedge clk);
            end
            if(timeout == 0) begin
                $display("ERROR: Data ready timeout");
                error_count = error_count + 1;
            end
        end
    endtask

    // Test Task: Simulate UART RX Data
    task simulate_rx_data;
        input [7:0] data;
        integer i;
        begin
            // Start bit
            uart_rx = 0;
            #104166; // 9600 baud: 1/9600 = 104.166us

            // Data bits (LSB first)
            for(i = 0; i < 8; i = i + 1) begin
                uart_rx = data[i];
                #104166;
            end

            // Stop bit
            uart_rx = 1;
            #104166;
        end
    endtask

    // Test Main Process
    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 0;
        baud_clk = 0;
        cs_n = 1;
        rd_n = 1;
        wr_n = 1;
        addr = 0;
        wr_data = 0;
        uart_rx = 1; // Idle state is high

        // Reset the DUT
        #100;
        rst_n = 1;
        #100;

        $display("Starting UART16550 Test...");

        // Test 1: UART Initialization Test
        $display("Test 1: UART Initialization Test");
        // Configure UART with 9600 baud rate (假设baud_clk为1MHz)
        // Divisor = 1MHz / (16 * 9600) = 6.5104, 使用6 = 0x06
        configure_uart(16'h0006);

        // Check Line Control Register
        begin
            reg [7:0] lcr;
            read_register(3, lcr);
            if(lcr != 8'h03) begin
                $display("ERROR: LCR configuration failed. Expected: 0x03, Got: 0x%02h", lcr);
                error_count = error_count + 1;
            end
        end

        // Test 2: Transmit Data Test
        $display("Test 2: Transmit Data Test");
        // Enable transmitter
        write_register(1, 8'h01); // Enable THRE interrupt

        // Send test data
        send_data(8'h55); // ASCII 'U'
        wait_for_thre;

        // Check if data was transmitted (by observing uart_tx in simulation)
        $display("Transmit test completed. Check waveform for uart_tx signal.");

        // Test 3: Receive Data Test
        $display("Test 3: Receive Data Test");
        // Enable receiver
        write_register(1, 8'h01 | 8'h02); // Enable THRE and Received Data Available interrupts

        // Simulate RX data
        simulate_rx_data(8'h41); // ASCII 'A'
        wait_for_data_ready;

        // Read received data
        begin
            reg [7:0] received_data;
            receive_data(received_data);
            if(received_data != 8'h41) begin
                $display("ERROR: Received data mismatch. Expected: 0x41, Got: 0x%02h", received_data);
                error_count = error_count + 1;
            end else begin
                $display("Received data correct: 0x%02h", received_data);
            end
        end

        // Test 4: Loopback Test
        $display("Test 4: Loopback Test");
        // Enable loopback mode for self-testing
        write_register(3, 8'h13); // Set DLAB=0, 8 bits, loopback mode

        // Send data and check if we receive the same data
        send_data(8'h55);
        wait_for_data_ready;

        begin
            reg [7:0] loopback_data;
            receive_data(loopback_data);
            if(loopback_data != 8'h55) begin
                $display("ERROR: Loopback test failed. Expected: 0x55, Got: 0x%02h", loopback_data);
                error_count = error_count + 1;
            end else begin
                $display("Loopback test passed. Received: 0x%02h", loopback_data);
            end
        end

        // Disable loopback mode
        write_register(3, 8'h03);

        // Test 5: FIFO Test
        $display("Test 5: FIFO Test");
        // Enable FIFO with trigger level 1 (data ready after 1 byte)
        write_register(2, 8'h07);

        // Send multiple characters via RX simulation
        simulate_rx_data(8'h42); // 'B'
        simulate_rx_data(8'h43); // 'C'

        // Wait for data and read multiple times
        repeat(2) begin
            wait_for_data_ready;
            begin
                reg [7:0] fifo_data;
                receive_data(fifo_data);
                $display("FIFO data: 0x%02h", fifo_data);
            end
        end

        // Test completion report
        if (error_count == 0) begin
            $display("All tests passed! UART16550 functionality verified.");
        end else begin
            $display("Test completed with %0d errors", error_count);
        end

        // Wait a bit before finishing to capture all waveforms
        #1000;
        $finish;
    end

    // Global timeout protection process
    initial begin
        #(TIMEOUT_CYCLES * 10); // Assuming clock period is 10ns
        $display("ERROR: Global timeout after %0d cycles", TIMEOUT_CYCLES);
        $display("Test completed with %0d errors", error_count + 1);
        $finish;
    end

    // Waveform output
    initial begin
        $dumpfile("tb_uart16550.vcd");
        $dumpvars(0, tb_uart16550);
    end

endmodule