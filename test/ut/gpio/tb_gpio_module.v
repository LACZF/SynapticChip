// tb_gpio_module.v
// GPIO Module Test Bench

`include "gpio_params.v"
`timescale 1ns/1ps

module tb_gpio_module;

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

    // GPIO Pins
    wire [`GPIO_WIDTH-1:0] gpio_pins;
    reg  [`GPIO_WIDTH-1:0] gpio_ext_drive;
    reg  [`GPIO_WIDTH-1:0] gpio_dir;

    // Initialize to Input Mode
    initial begin
        gpio_dir = {`GPIO_WIDTH{1'b0}};
    end

    // Control GPIO Pins Based on Direction Register Values
    genvar i;
    generate
        for (i = 0; i < `GPIO_WIDTH; i = i + 1) begin : gpio_bidirectional
            assign gpio_pins[i] = gpio_dir[i] ? gpio_ext_drive[i] : 1'bz;
        end
    endgenerate

    // Interrupt Signal
    wire int_out;

    // Instantiate DUT
    gpio_module dut (
        .clk(clk),
        .rst_n(rst_n),
        .req(req),
        .we(we),
        .addr(addr),
        .data_in(data_in),
        .data_out(data_out),
        .ack(ack),
        .gpio_pins(gpio_pins),
        .int_out(int_out)
    );

    // Clock Generation
    always #5 clk = ~clk;

    // Test Task: Register Write Operation
    task write_register;
        input [`ADDR_WIDTH-1:0] reg_addr;
        input [`DATA_WIDTH-1:0] write_data;
        reg [31:0] timeout_count;
        reg timeout;
        begin
            timeout_count = 0;
            timeout = 0;

        `ifdef DEBUG
            $display("[write_register] Writing to addr=0x%h, data=0x%h", reg_addr, write_data);
        `endif
            @(posedge clk);
            req <= 1'b1;
            we <= 1'b1;
            addr <= reg_addr;
            data_in <= write_data;

            // Wait for Acknowledgment and Add Timeout Mechanism
            while (!ack && !timeout) begin
                timeout_count = timeout_count + 1;
                if (timeout_count >= 100) begin
                    $display("ERROR: write_register timeout at address 0x%h", reg_addr);
                    timeout = 1;
                end
                @(posedge clk);
            end

            if (!timeout) begin
                $display("[write_register] Write completed successfully");
            end else begin
                $display("Warning: Write operation may not have completed");
            end

            @(posedge clk);
            req <= 1'b0;
            we <= 1'b0;
            addr <= 0;
            data_in <= 0;
        end
    endtask

    // Test Task: Register Read Operation
    task read_register;
        input [`ADDR_WIDTH-1:0] reg_addr;
        output [`DATA_WIDTH-1:0] read_data;
        reg [31:0] timeout_count;
        reg timeout;
        begin
            timeout_count = 0;
            timeout = 0;

        `ifdef DEBUG
            $display("[read_register] Reading from addr=0x%h", reg_addr);
        `endif
            @(posedge clk);
            req <= 1'b1;
            we <= 1'b0;
            addr <= reg_addr;

            // Wait for Acknowledgment and Add Timeout Mechanism
            while (!ack && !timeout) begin
                timeout_count = timeout_count + 1;
                if (timeout_count >= 100) begin
                    $display("ERROR: read_register timeout at address 0x%h", reg_addr);
                    timeout = 1;
                end
                @(posedge clk);
            end

            if (!timeout) begin
                read_data = data_out;
                $display("[read_register] Read completed: data=0x%h", read_data);
            end else begin
                read_data = {`DATA_WIDTH{1'bx}};
                $display("Warning: Read operation may not have completed");
            end

            @(posedge clk);
            req <= 1'b0;
            we <= 1'b0;
            addr <= 0;
        end
    endtask

    // Main Test Program
    reg [`DATA_WIDTH-1:0] read_data;
    reg error_occurred = 0;

    initial begin
        // Initialization
        clk = 0;
        rst_n = 0;
        req = 0;
        we = 0;
        addr = 0;
        data_in = 0;
        gpio_ext_drive = {`GPIO_WIDTH{1'b0}};

        // Reset
        #20 rst_n = 1;

        $display("Starting GPIO Module Test");
        $display("=========================");
        $display("Direct testing of gpio_module without Ring Bus");
        $display("=========================");

        // Wait for Reset Completion
        #100;

        $display("\n--- GPIO Register Test ---");

        // Test Basic Register Read/Write Functions
        $display("\n1. Testing register read/write operations");

        // Test Direction Register
        write_register(`REG_DIR, 32'h0000FFFF);
        #50;
        read_register(`REG_DIR, read_data);
        if (read_data == 32'h0000FFFF) begin
            $display("     Direction register readback verified: 0x%h", read_data);
        end else begin
            $display("     ERROR: Direction register readback mismatch: 0x%h (expected: 0x0000FFFF)", read_data);
            error_occurred = 1;
        end

        // Test Data Register (Set Direction to Output First)
        write_register(`REG_DATA, 32'h0000AAAA);
        #50;
        read_register(`REG_DATA, read_data);
        if (read_data == 32'h0000AAAA) begin
            $display("     Data register readback verified: 0x%h", read_data);
        end else begin
            $display("     ERROR: Data register readback mismatch: 0x%h (expected: 0x0000AAAA)", read_data);
            error_occurred = 1;
        end

        // Test Interrupt Related Registers
        write_register(`REG_INTEN, 32'h00010000);
        #50;
        read_register(`REG_INTEN, read_data);
        if (read_data == 32'h00010000) begin
            $display("     Interrupt enable register readback verified: 0x%h", read_data);
        end else begin
            $display("     ERROR: Interrupt enable register readback mismatch: 0x%h (expected: 0x00010000)", read_data);
            error_occurred = 1;
        end

        // Final Test Result
        if (error_occurred) begin
            $display("\nTEST FAILED: Some errors occurred during testing.");
        end else begin
            $display("\nTEST PASSED: GPIO module register functionality verified successfully!");
        end

        $display("\nTest completed.");

        $finish;
    end

    // Waveform Output
    initial begin
        $dumpfile("tb_gpio_module.vcd");
        $dumpvars(0, tb_gpio_module);
    end

endmodule