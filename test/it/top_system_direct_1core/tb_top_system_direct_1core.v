// tb_top_system_direct_single_core.v
// Top-Level System Integration Test Bench - Single Core + Direct Bus + No L2/L3 Cache Configuration

`include "top_system_params.v"
`include "spi_params.v"
`timescale 1ns/1ps

// SPI Flash Model - Simulating SPI ROM Device
module spi_flash_model(input wire cs_n, input wire sclk, input wire mosi, output wire miso);
    parameter MEM_SIZE = 4096; // Memory Size (Instruction Count)
    parameter INSTR_FILE = "instructions.hex"; // Instruction File Path

    // Internal Memory
    reg [31:0] mem [0:MEM_SIZE-1];
    reg [31:0] current_addr;
    reg [7:0]  current_cmd;
    reg [1:0]  state;
    reg [4:0]  bit_count;
    reg [31:0] rx_data;
    reg [31:0] tx_data;
    reg        miso_reg;

    localparam IDLE = 2'b00;
    localparam CMD  = 2'b01;
    localparam ADDR = 2'b10;
    localparam DATA = 2'b11;

    // Initialize by Loading Instructions from File
    initial begin
        $readmemh(INSTR_FILE, mem);
        state = IDLE;
        miso_reg = 1'b0;
    end

    // SPI Communication Processing
    always @(negedge sclk or posedge cs_n) begin
        if (cs_n) begin
            state = IDLE;
            bit_count = 0;
            miso_reg = 1'b0;
        end else begin
            case (state)
                IDLE:
                    begin
                        state = CMD;
                        bit_count = 0;
                        current_cmd = 0;
                    end
                CMD:
                    begin
                        current_cmd = {current_cmd[6:0], mosi};
                        bit_count = bit_count + 1;
                        if (bit_count == 8) begin
                            bit_count = 0;
                            if (current_cmd == `SPI_CMD_READ_DATA || current_cmd == `SPI_CMD_FAST_READ) begin
                                state = ADDR;
                                current_addr = 0;
                            end
                        end
                    end
                ADDR:
                    begin
                        current_addr = {current_addr[29:0], mosi};
                        bit_count = bit_count + 1;
                        if (bit_count == 24) begin
                            bit_count = 0;
                            state = DATA;
                            // Convert Byte Address to Instruction Index (Divide by 4)
                            tx_data = mem[current_addr / 4];
                        end
                    end
                DATA:
                    begin
                        // Send Data Starting from MSB
                        miso_reg = tx_data[31 - bit_count];
                        bit_count = bit_count + 1;
                        if (bit_count == 32) begin
                            // After reading one instruction, automatically increment address to read next
                            current_addr = current_addr + 4;
                            tx_data = mem[current_addr / 4];
                            bit_count = 0;
                        end
                    end
            endcase
        end
    end

    // Output MISO Signal
    assign miso = cs_n ? 1'bz : miso_reg;
endmodule

module tb_top_system_direct_1core;
    localparam SPI_CS_NUM = 2;

    // Clock and Reset
    reg clk;
    reg rst_n;

    // UART Interface
    wire uart_txd;
    reg  uart_rxd;

    // GPIO Interface
    wire [`DATA_WIDTH-1:0] gpio_pins;
    reg  [`DATA_WIDTH-1:0] gpio_ext_drive;
    assign gpio_pins = gpio_ext_drive;

    // External Interrupt
    reg ext_int;

    // Status Output
    wire [`DATA_WIDTH-1:0] system_status;

    // SPI Physical Interface (Connected to SPI Flash Model)
    wire [SPI_CS_NUM-1:0] spi_cs_n;
    wire spi_clk;
    wire spi_mosi;
    wire spi_miso;

    // Instantiate DUT - Configured as Direct Bus, Single Core, No L2/L3 Cache
    top_system #(
        .BUS_TYPE(`BUS_TYPE_DIRECT),
        .NUM_RINGS(1),
        .NUM_NODES(`NODES),
        .ADDR_WIDTH(`ADDR_WIDTH),
        .NODE_ID_WIDTH(`NODE_ID_WIDTH),
        .DATA_WIDTH(`DATA_WIDTH),
        .NUM_PES(`NUM_PES),
        .PE_ARRAY_ROWS(`PE_ARRAY_ROWS),
        .PE_ARRAY_COLS(`PE_ARRAY_COLS),
        .INST_WIDTH(`INST_WIDTH),
        .PE_ID_WIDTH(`PE_ID_WIDTH),
        .SPI_CS_NUM(SPI_CS_NUM),
        .NUM_CORES(1),             // 1 Core
        .ENABLE_L2_CACHE(0),       // Disable L2 Cache
        .ENABLE_L3_CACHE(0)        // Disable L3 Cache
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .uart_txd(uart_txd),
        .uart_rxd(uart_rxd),
        .gpio_pins(gpio_pins),
        .ext_int(ext_int),
        .system_status(system_status),
        // SPI Interface Connected to SPI Flash Model
        .spi_cs_n(spi_cs_n),
        .spi_clk(spi_clk),
        .spi_mosi(spi_mosi),
        .spi_miso(spi_miso)
    );

    // Clock Generation
    always #5 clk = ~clk;

    // Test Task: Send Data via UART
    task uart_send_byte;
        input [7:0] data;
        integer i;
        begin
            // Start Bit
            uart_rxd <= 1'b0;
            #8680; // Bit time for 115200 baud rate

            // Data Bits
            for (i = 0; i < 8; i = i + 1) begin
                uart_rxd <= data[i];
                #8680;
            end

            // Stop Bit
            uart_rxd <= 1'b1;
            #8680;
        end
    endtask

    // Instantiate SPI Flash Model, Connected to SPI Physical Interface (Using First Chip Select)
    spi_flash_model #(
        .MEM_SIZE(4096),
        .INSTR_FILE("instructions.hex")
    ) u_spi_flash_model (
        .cs_n(spi_cs_n[0]),
        .sclk(spi_clk),
        .mosi(spi_mosi),
        .miso(spi_miso)
    );

    // Main Test Program
    initial begin
        // Initialization
        clk = 0;
        rst_n = 0;
        uart_rxd = 1'b1;
        gpio_ext_drive = 0;
        ext_int = 0;

        // Open Waveform File
        $dumpfile("top_system_direct_1core.vcd");
        $dumpvars(0, tb_top_system_direct_1core);

        // Reset
        #20 rst_n = 1;

        $display("Starting Top System Integration Test - Direct Bus, Single Core, No L2/L3 Cache");

        // Test 1: System Startup and Initialization
        $display("Test 1: System startup and initialization");
        #100;
        $display("System status: 0x%h", system_status);

        // Test 2: GPIO Test
        $display("Test 2: GPIO test");
        // Drive GPIO Pins via External Drive
        #1000;
        gpio_ext_drive = 32'h12345678;
        #100;
        $display("GPIO pins driven to: 0x%h", gpio_ext_drive);

        // Test 3: UART Communication Test
        $display("Test 3: UART communication test");
        #1000;
        $display("Sending test data via UART");
        uart_send_byte(8'h48); // 'H'
        uart_send_byte(8'h65); // 'e'
        uart_send_byte(8'h6C); // 'l'
        uart_send_byte(8'h6C); // 'l'
        uart_send_byte(8'h6F); // 'o'
        uart_send_byte(8'h0A); // '\n'

        // Test 4: External Interrupt Test
        $display("Test 4: External interrupt test");
        #2000;
        ext_int = 1;
        #100;
        ext_int = 0;
        #100;
        $display("External interrupt triggered");

        // Wait for a period to observe system response
        #5000;

        $display("All tests completed!");
        $finish;
    end

endmodule