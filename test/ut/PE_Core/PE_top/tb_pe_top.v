// PE_TOP Test Bench

`include "pe_ctrl.v"
`timescale 1ns/1ps

module tb_pe_top;
    localparam INST_WIDTH = 32;

    // Clock and Reset
    reg clk;
    reg rst_n;

    // Direct Control Interface
    reg  [`NUM_PES-1:0]                  pe_enable;
    reg  [`NUM_PES-1:0]                  pe_reset;
    reg  [(`NUM_PES*INST_WIDTH)-1:0]     pe_instructions;
    reg                                  pe_inst_valid;
    reg  [(`NUM_PES*4*`PE_ID_WIDTH)-1:0] route_config; // Routing Configuration
    reg                                  route_cfg_valid;

    // Status Output
    wire [(`NUM_PES*`DATA_WIDTH)-1:0]    pe_status;
    wire [(`NUM_PES*`DATA_WIDTH)-1:0]    pe_outputs;
    wire [`NUM_PES-1:0]                  pe_busy;
    wire [`DATA_WIDTH-1:0]               fabric_status;

    // DUT Instantiation
	pe_top #(
		.ADDR_WIDTH(`WORD_ADDR_W),
		.DATA_WIDTH(`WORD_DATA_W),
		.NUM_PES(4),
		.INST_WIDTH(32),
		.PE_ID_WIDTH(4),
		.NUM_RINGS(2),
		.PE_ARRAY_ROWS(2),
		.PE_ARRAY_COLS(2)
	) pe (
		.clk(clk),
		.reset(reset)
	);

    // Clock Generation
    always #5 clk = ~clk;

    // Test Task: Control PE Enable
    task control_pe_enable;
        input [`NUM_PES-1:0] enable_mask;
        begin
            @(posedge clk);
            pe_enable <= enable_mask;
            @(posedge clk);
        end
    endtask

    // Test Task: Control PE Reset
    task control_pe_reset;
        input [`NUM_PES-1:0] reset_mask;
        input integer reset_cycles;
        integer i;
        begin
            @(posedge clk);
            pe_reset <= reset_mask;
            for (i = 0; i < reset_cycles; i = i + 1) begin
                @(posedge clk);
            end
            pe_reset <= 0;
        end
    endtask

    // Test Task: Configure PE Instructions
    task configure_pe_instruction;
        input integer pe_id;
        input [127:0] instruction;
        begin
            @(posedge clk);
            pe_instructions[pe_id*128 +: 128] <= instruction;
            pe_inst_valid <= 1'b1;
            @(posedge clk);
            pe_inst_valid <= 1'b0;
        end
    endtask

    // Test Task: Configure Routing
    task configure_routing;
        input [(4*4*`PE_ID_WIDTH)-1:0] config_data;
        begin
            @(posedge clk);
            route_config <= config_data;
            route_cfg_valid <= 1'b1;
            @(posedge clk);
            route_cfg_valid <= 1'b0;
        end
    endtask

    // Main Test Program
    reg [127:0] test_instruction;
    integer error_count;

    initial begin
        // Initialization
        clk = 0;
        rst_n = 0;
        pe_enable = 0;
        pe_reset = 0;
        pe_instructions = 0;
        pe_inst_valid = 0;
        route_config = 0;
        route_cfg_valid = 0;
        error_count = 0;

        // Reset
        #100 rst_n = 1;
        #200; // Give enough time for the system to stabilize

        $display("Starting PE_TOP Test");

        // Test 1: Read Initial Status
        $display("Test 1: Read initial fabric status");
        $display("Initial fabric status: 0x%h", fabric_status);
        #20;

        // Test 2: Reset All PEs
        $display("Test 2: Reset all PEs");
        control_pe_reset(4'b1111, 5); // Reset all 4 PEs for 5 clock cycles
        #20;

        // Test 3: Enable All PEs
        $display("Test 3: Enable all PEs");
        control_pe_enable(4'b1111); // Enable all 4 PEs
        #100; // Wait for PEs to stabilize

        // Check PE Enable Status
        if (fabric_status[3:0] != 4'b1111) begin
            $display("ERROR: PE enable status mismatch! Expected 0xF, Got 0x%h", fabric_status[3:0]);
            error_count = error_count + 1;
        end else begin
            $display("INFO: PE enable status verified successfully");
        end
        #20;

        // Test 4: Configure PE Instructions
        $display("Test 4: Configure PE instructions");
        test_instruction = 128'h00010002000300040005000600070008; // Test instruction
        configure_pe_instruction(0, test_instruction);
        configure_pe_instruction(1, test_instruction);
        configure_pe_instruction(2, test_instruction);
        configure_pe_instruction(3, test_instruction);
        #20;

        // Test 5: Configure Routing
        $display("Test 5: Configure routing");
        // Simple Routing Configuration: Each PE's four directions all point to itself
        configure_routing({
            {`PE_ID_WIDTH{1'b0}}, {`PE_ID_WIDTH{1'b0}}, {`PE_ID_WIDTH{1'b0}}, {`PE_ID_WIDTH{1'b0}}, // PE0
            {`PE_ID_WIDTH{1'b1}}, {`PE_ID_WIDTH{1'b1}}, {`PE_ID_WIDTH{1'b1}}, {`PE_ID_WIDTH{1'b1}}, // PE1
            {`PE_ID_WIDTH{2'b10}}, {`PE_ID_WIDTH{2'b10}}, {`PE_ID_WIDTH{2'b10}}, {`PE_ID_WIDTH{2'b10}}, // PE2
            {`PE_ID_WIDTH{2'b11}}, {`PE_ID_WIDTH{2'b11}}, {`PE_ID_WIDTH{2'b11}}, {`PE_ID_WIDTH{2'b11}}  // PE3
        });
        #20;

        // Test 6: Observe PE Status
        $display("Test 6: Observe PE status");
        $display("PE 0 status: 0x%h", pe_status[0*`DATA_WIDTH +: `DATA_WIDTH]);
        $display("PE 1 status: 0x%h", pe_status[1*`DATA_WIDTH +: `DATA_WIDTH]);
        $display("PE 2 status: 0x%h", pe_status[2*`DATA_WIDTH +: `DATA_WIDTH]);
        $display("PE 3 status: 0x%h", pe_status[3*`DATA_WIDTH +: `DATA_WIDTH]);
        $display("PE busy signals: 0b%b", pe_busy);
        $display("Fabric status: 0x%h", fabric_status);
        #20;

        // Test 7: Disable Some PEs
        $display("Test 7: Disable some PEs");
        control_pe_enable(4'b1010); // Disable PE0 and PE2
        #100;

        // Check PE Enable Status
        if (fabric_status[3:0] != 4'b1010) begin
            $display("ERROR: PE enable status after disable mismatch! Expected 0xA, Got 0x%h", fabric_status[3:0]);
            error_count = error_count + 1;
        end else begin
            $display("INFO: PE enable status after disable verified successfully");
        end
        #20;

        // Test 8: Completely Disable All PEs
        $display("Test 8: Disable all PEs");
        control_pe_enable(4'b0000); // Disable all PEs
        #100;

        // Check PE Enable Status
        if (fabric_status[3:0] != 4'b0000) begin
            $display("ERROR: PE enable status after full disable mismatch! Expected 0x0, Got 0x%h", fabric_status[3:0]);
            error_count = error_count + 1;
        end else begin
            $display("INFO: PE enable status after full disable verified successfully");
        end

        // Final Test Results
        if (error_count == 0) begin
            $display("\nTEST PASSED");
        end else begin
            $display("\nTEST FAILED with %0d errors", error_count);
        end

        $display("All tests completed!");
        $finish;
    end

    // Waveform Output
    initial begin
        $dumpfile("tb_pe_top.vcd");
        $dumpvars(0, tb_pe_top);
    end

endmodule