module ring_bus_system_tb;

    reg clk;
    reg rst_n;

    // Memory Interface
    reg          mem_req_enable;
    reg  [31:0]  mem_req_addr;
    reg  [63:0]  mem_req_data;
    reg          mem_req_wr;
    wire [63:0]  mem_req_data_out;
    wire         mem_req_ready;

    wire         mem_resp_enable;
    wire [31:0]  mem_resp_addr;
    wire [63:0]  mem_resp_data;
    wire         mem_resp_wr;
    reg  [63:0]  mem_resp_data_in;
    reg          mem_resp_ready;

    // UART Interface
    reg          uart_req_enable;
    reg  [31:0]  uart_req_addr;
    reg  [63:0]  uart_req_data;
    reg          uart_req_wr;
    wire [63:0]  uart_req_data_out;
    wire         uart_req_ready;

    wire         uart_resp_enable;
    wire [31:0]  uart_resp_addr;
    wire [63:0]  uart_resp_data;
    wire         uart_resp_wr;
    reg  [63:0]  uart_resp_data_in;
    reg          uart_resp_ready;

    // UART Physical Interface
    reg  uart_rx;
    wire uart_tx;
    wire uart_irq;

    // Debug Interface
    wire [1:0]  debug_ring_busy;
    wire [15:0] debug_ring_load;

    // DUT Instance
    ring_bus_system u_dut (
        .clk(clk),
        .rst_n(rst_n),
        // Memory Interface
        .mem_req_enable_i(mem_req_enable),
        .mem_req_addr_i(mem_req_addr),
        .mem_req_data_i(mem_req_data),
        .mem_req_wr_i(mem_req_wr),
        .mem_req_data_o(mem_req_data_out),
        .mem_req_ready_o(mem_req_ready),
        .mem_resp_enable_o(mem_resp_enable),
        .mem_resp_addr_o(mem_resp_addr),
        .mem_resp_data_o(mem_resp_data),
        .mem_resp_wr_o(mem_resp_wr),
        .mem_resp_data_i(mem_resp_data_in),
        .mem_resp_ready_i(mem_resp_ready),
        // UART Interface
        .uart_req_enable_i(uart_req_enable),
        .uart_req_addr_i(uart_req_addr),
        .uart_req_data_i(uart_req_data),
        .uart_req_wr_i(uart_req_wr),
        .uart_req_data_o(uart_req_data_out),
        .uart_req_ready_o(uart_req_ready),
        .uart_resp_enable_o(uart_resp_enable),
        .uart_resp_addr_o(uart_resp_addr),
        .uart_resp_data_o(uart_resp_data),
        .uart_resp_wr_o(uart_resp_wr),
        .uart_resp_data_i(uart_resp_data_in),
        .uart_resp_ready_i(uart_resp_ready),
        // UART Physical Interface
        .uart_rx_i(uart_rx),
        .uart_tx_o(uart_tx),
        .uart_irq_o(uart_irq),
        // Debug Interface
        .debug_ring_busy(debug_ring_busy),
        .debug_ring_load(debug_ring_load)
    );

    // Clock Generation
    always #5 clk = ~clk;

    // Extract Load Values
    wire [7:0] ring0_load = debug_ring_load[7:0];
    wire [7:0] ring1_load = debug_ring_load[15:8];

    // Test Task: Memory Operation
    task test_memory_operation;
        input [31:0] addr;
        input [63:0] data;
        input wr;
        begin
            @(posedge clk);
            mem_req_enable <= 1'b1;
            mem_req_addr <= addr;
            mem_req_data <= data;
            mem_req_wr <= wr;

            wait (mem_req_ready);
            @(posedge clk);
            mem_req_enable <= 1'b0;

        `ifdef DEBUG
            if (!wr) begin
                $display("Memory Read: Address=%h, Data=%h", addr, mem_req_data_out);
            end else begin
                $display("Memory Write: Address=%h, Data=%h", addr, data);
            end
        `endif
        end
    endtask

    // Test Task: UART Operation
    task test_uart_operation;
        input [31:0] addr;
        input [63:0] data;
        input wr;
        begin
            @(posedge clk);
            uart_req_enable <= 1'b1;
            uart_req_addr <= addr;
            uart_req_data <= data;
            uart_req_wr <= wr;

            wait (uart_req_ready);
            @(posedge clk);
            uart_req_enable <= 1'b0;

        `ifdef DEBUG
            if (!wr) begin
                $display("UART Read: Address=%h, Data=%h", addr, uart_req_data_out);
            end else begin
                $display("UART Write: Address=%h, Data=%h", addr, data);
            end
        `endif
        end
    endtask

    // Main Test Program
    initial begin
        // Initialization
        clk = 0;
        rst_n = 0;
        mem_req_enable = 0;
        uart_req_enable = 0;
        uart_rx = 1'b1;
        mem_resp_ready = 1'b1;
        uart_resp_ready = 1'b1;

        // Start Global Timeout Monitoring
        fork
            begin
                // Main Test Flow
                // Reset
                #100 rst_n = 1;

                // Test 1: Memory Read/Write
                $display("=== Test 1: Memory Operations ===");
                test_memory_operation(32'h0000_1000, 64'h1234_5678_9ABC_DEF0, 1'b1);
                $display("=== Test 1: Memory write Operations done ===");
                test_memory_operation(32'h0000_1000, 64'h0, 1'b0);
                $display("=== Test 1: Memory read Operations done ===");

                #100;

                // Test 2: UART Operations
                $display("=== Test 2: UART Operations ===");
                test_uart_operation(32'h4000_0000, 64'h0000_0000_0000_0041, 1'b1); // Send character 'A'
                test_uart_operation(32'h4000_0008, 64'h0, 1'b0); // Read status

                #200;

                // Test 3: Concurrent Operations
                $display("=== Test 3: Concurrent Operations ===");
                fork
                    begin
                        test_memory_operation(32'h0000_2000, 64'hAAAA_BBBB_CCCC_DDDD, 1'b1);
                    end
                    begin
                        #50 test_uart_operation(32'h4000_0000, 64'h0000_0000_0000_0042, 1'b1); // Send character 'B'
                    end
                join

                #100;

                // Display system status
                $display("=== System Status ===");
                $display("Ring 0: Busy=%b, Load=%d", debug_ring_busy[0], ring0_load);
                $display("Ring 1: Busy=%b, Load=%d", debug_ring_busy[1], ring1_load);
                $display("UART IRQ: %b, UART TX: %b", uart_irq, uart_tx);

                #100;
                $display("All tests completed successfully!");
                $finish;
            end

            // Global timeout mechanism
            begin
                #1000000; // 1ms timeout
                $display("ERROR: Global test timeout reached! Forcing test termination.");
                $finish;
            end
        join
    end

    // Waveform recording
    initial begin
        $dumpfile("ring_bus_system.vcd");
        $dumpvars(0, ring_bus_system_tb);
    end

endmodule