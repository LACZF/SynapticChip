// tb_router.v
// Router Module Test Bench (Pure Verilog)

`include "pe_router_params.v"
`timescale 1ns/1ps

module tb_router;

    // Clock and Reset
    reg clk;
    reg rst_n;

    // Configuration Interface
    reg                    cfg_valid;
    reg  [`ADDR_WIDTH-1:0] cfg_addr;
    reg  [`DATA_WIDTH-1:0] cfg_data;
    wire                   cfg_ack;

    // Data Input Interface
    reg  [`NUM_PORTS-1:0]               data_in_valid;
    reg  [(`NUM_PORTS*`DATA_WIDTH)-1:0] data_in;
    wire [`NUM_PORTS-1:0]               data_in_ready;

    // Data Output Interface
    wire [`NUM_PORTS-1:0]               data_out_valid;
    wire [(`NUM_PORTS*`DATA_WIDTH)-1:0] data_out;
    reg  [`NUM_PORTS-1:0]               data_out_ready;

    // Status Output
    wire [`DATA_WIDTH-1:0] status;

    // Instantiate DUT - Explicitly Pass Parameters for Consistency
    pe_router_top #(
        .NUM_PORTS(`NUM_PORTS)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .cfg_valid(cfg_valid),
        .cfg_addr(cfg_addr),
        .cfg_data(cfg_data),
        .cfg_ack(cfg_ack),
        .data_in_valid(data_in_valid),
        .data_in(data_in),
        .data_in_ready(data_in_ready),
        .data_out_valid(data_out_valid),
        .data_out(data_out),
        .data_out_ready(data_out_ready),
        .status(status)
    );

    // Clock Generation
    always #5 clk = ~clk;

    // Define Timeout Period Parameter
    localparam TIMEOUT_CYCLES = 1000;

    // Test Task: Send Configuration (with Timeout Mechanism)
    task send_config;
        input [`ADDR_WIDTH-1:0] addr;
        input [`DATA_WIDTH-1:0] data;
        integer timeout;
        begin
            @(posedge clk);
            cfg_valid = 1'b1;
            cfg_addr = addr;
            cfg_data = data;
            timeout = 0;

            while (!cfg_ack && timeout < TIMEOUT_CYCLES) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (timeout >= TIMEOUT_CYCLES) begin
                $display("ERROR: Configuration timeout for address 0x%h", addr);
            end

            @(posedge clk);
            cfg_valid = 1'b0;
        end
    endtask

    // Test Task: Send Data (with Timeout Mechanism)
    task send_data;
        input integer port;
        input [`DATA_WIDTH-1:0] data;
        integer timeout;
        begin
            @(posedge clk);
            data_in_valid[port] = 1'b1;
            data_in[port*`DATA_WIDTH +: `DATA_WIDTH] = data;
            timeout = 0;

            while (!data_in_ready[port] && timeout < TIMEOUT_CYCLES) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (timeout >= TIMEOUT_CYCLES) begin
                $display("ERROR: Send data timeout on port %0d", port);
            end

            @(posedge clk);
            data_in_valid[port] = 1'b0;
        end
    endtask

    // Test Task: Receive Data (with Timeout Mechanism)
    task receive_data;
        input integer port;
        output [`DATA_WIDTH-1:0] data;
        integer timeout;
        begin
            timeout = 0;
            while (!data_out_valid[port] && timeout < TIMEOUT_CYCLES) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (timeout >= TIMEOUT_CYCLES) begin
                $display("ERROR: Receive data timeout on port %0d", port);
                data = 32'hDEADBEEF; // Timeout flag value
            end else begin
                data = data_out[port*`DATA_WIDTH +: `DATA_WIDTH];
            end

            @(posedge clk);
            data_out_ready[port] = 1'b1;
            @(posedge clk);
            data_out_ready[port] = 1'b0;
        end
    endtask

    // Main Test Program
    reg [`DATA_WIDTH-1:0] received_data;

    initial begin
        // Initialization
        clk = 0;
        rst_n = 0;
        cfg_valid = 0;
        cfg_addr = 0;
        cfg_data = 0;
        data_in_valid = 5'b00000;
        data_in = 0;
        data_out_ready = 5'b11111; // By default, all output ports are ready

        // Reset
        #20 rst_n = 1;

        fork
            // Main Test Flow
            begin
                $display("Starting Router Test");

                // Test 1: Configure Routing Algorithm
                $display("Test 1: Configure routing algorithm");
                send_config(`REG_ROUTE_ALGO, `ROUTE_XY);
                $display("Routing algorithm configured to XY");

                // Test 2: Configure Routing Table
                $display("Test 2: Configure routing table");
                // Set Routing Table: Local Port -> North Port
                send_config(`REG_ROUTE_TABLE, 25'b0000100000000000000000000);
                $display("Routing table configured");

                // Test 3: Send Data from Local to North
                $display("Test 3: Send data from local to north");
                fork
                    begin
                        send_data(4, 32'hAABBCCDD); // Send data from local port
                        $display("Data sent from local port: 0x%h", 32'hAABBCCDD);
                    end
                    begin
                        receive_data(0, received_data); // Receive data from north port
                        if (received_data !== 32'hAABBCCDD && received_data !== 32'hDEADBEEF) begin
                            $display("ERROR: Received 0x%h, expected 0xAABBCCDD", received_data);
                        end else if (received_data === 32'hAABBCCDD) begin
                            $display("Data received at north port: 0x%h", received_data);
                        end
                    end
                join

                // Test 4: Test Backpressure Mechanism
                $display("Test 4: Test backpressure mechanism");

                // First fill the output buffer of north port
                data_out_ready[0] = 1'b0; // Prevent north port from receiving data

                // Send multiple data packets
                send_data(4, 32'h11223344);
                send_data(4, 32'h55667788);
                send_data(4, 32'h99AABBCC);

                // Check if local port ready signal is low (backpressure)
                if (data_in_ready[4] !== 1'b0) begin
                    $display("ERROR: Backpressure not working, local port ready: %b", data_in_ready[4]);
                end else begin
                    $display("Backpressure working correctly");
                end

                // Release north port
                data_out_ready[0] = 1'b1;

                // Receive all data
                receive_data(0, received_data);
                $display("Received: 0x%h", received_data);
                receive_data(0, received_data);
                $display("Received: 0x%h", received_data);
                receive_data(0, received_data);
                $display("Received: 0x%h", received_data);

                // Test 5: Test Port Disable
                $display("Test 5: Test port disable");

                // Disable north port
                send_config(`REG_PORT_CTRL, 5'b01111); // Only north port disabled

                // Try to send data to north port
                send_data(4, 32'hDEADBEEF);
                // Check if data is not routed to disabled north port
                #50; // Wait for a period
                if (data_out_valid[0] !== 1'b0) begin
                    $display("ERROR: Data routed to disabled north port");
                end else begin
                    $display("Port disable working correctly");
                end

                // Re-enable north port
                send_config(`REG_PORT_CTRL, 5'b11111); // All ports enabled

                // Test 6: Read Status Register
                $display("Test 6: Read status register");
                // Status register contains buffer status and port enable status
                $display("Status register: 0x%h", status);

                $display("All tests completed!");
                $finish;
            end

            // Global Timeout Mechanism
            begin
                #1000000; // 1ms timeout (assuming time unit is ns)
                $display("ERROR: Global test timeout after 1ms");
                $finish;
            end
        join
    end

    // Waveform Output
    initial begin
        $dumpfile("router.vcd");
        $dumpvars(0, tb_router);
    end

endmodule