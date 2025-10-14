// RISC-V 64-bit Instruction Decode Unit Test Bench
module tb_riscv64_instruction_decode;

    // Clock and Reset Signals
    reg         clk;
    reg         rst_n;

    // Input Signals
    reg         stall_i;
    reg         flush_i;
    reg  [63:0] pc_in_i;
    reg  [31:0] instr_in_i;
    reg  [2:0]  funct3_i;

    // Output Signals
    wire [63:0] pc_out_o;
    wire [31:0] instr_out_o;
    wire [4:0]  rs1_o;
    wire [4:0]  rs2_o;
    wire [4:0]  rd_o;
    wire [63:0] imm_o;
    wire [15:0] ctrl_signals_o;

    // Clock Generation (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Instantiate Device Under Test (DUT)
    riscv64_instruction_decode u_riscv64_instruction_decode (
        .clk            (clk),
        .rst_n          (rst_n),
        .stall_i        (stall_i),
        .flush_i        (flush_i),
        .pc_in_i        (pc_in_i),
        .instr_in_i     (instr_in_i),
        .pc_out_o       (pc_out_o),
        .instr_out_o    (instr_out_o),
        .funct3_i       (funct3_i),
        .rs1_o          (rs1_o),
        .rs2_o          (rs2_o),
        .rd_o           (rd_o),
        .imm_o          (imm_o),
        .ctrl_signals_o (ctrl_signals_o)
    );

    // Test Variables
    integer test_passed;
    integer total_tests;
    integer error_count;

    // Helper function to calculate expected immediate values based on module implementation
    function [63:0] get_expected_imm(input [31:0] instr);
        case (instr[6:0])
            7'b0110111, 7'b0010111: // LUI, AUIPC
                get_expected_imm = {instr[31:12], 12'b0};
            7'b1101111: // JAL
                get_expected_imm = {{44{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
            7'b1100111: // JALR
                get_expected_imm = {{53{instr[31]}}, instr[30:20]};
            7'b1100011: // Branch instructions
                get_expected_imm = {{52{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
            7'b0000011: // Load instructions
                get_expected_imm = {{53{instr[31]}}, instr[30:20]};
            7'b0100011: // Store instructions
                get_expected_imm = {{53{instr[31]}}, instr[30:25], instr[11:7]};
            7'b0010011: // Immediate arithmetic
                get_expected_imm = (instr[14:12] == 3'b101) ?
                                 {{59{instr[24]}}, instr[23:20]} : // SRAI, SRLI
                                 {{53{instr[31]}}, instr[30:20]};
            default:
                get_expected_imm = 64'b0;
        endcase
    endfunction

    // Test Task: Set Instruction and Control Signals
    task set_instruction(input [63:0] pc, input [31:0] instr, input [2:0] funct3);
        begin
            @(negedge clk);
            pc_in_i = pc;
            instr_in_i = instr;
            funct3_i = funct3;
            stall_i = 1'b0;
            flush_i = 1'b0;
        end
    endtask

    // Test Task: Check outputs
    task check_outputs(input [63:0] expected_pc,
                       input [31:0] expected_instr,
                       input integer test_id,
                       input integer test_name_id);
        reg [255:0] test_name;
        reg [4:0] expected_rs1;
        reg [4:0] expected_rs2;
        reg [4:0] expected_rd;
        begin
            // Map test_name_id to test_name string
            case(test_name_id)
                2: test_name = "R-type Instruction (ADD)";
                3: test_name = "I-type Instruction (ADDI)";
                4: test_name = "U-type Instruction (LUI)";
                5: test_name = "U-type Instruction (AUIPC)";
                6: test_name = "J-type Instruction (JAL)";
                7: test_name = "I-type Instruction (JALR)";
                8: test_name = "B-type Instruction (BEQ)";
                9: test_name = "Load Instruction (LW)";
                10: test_name = "Store Instruction (SW)";
                default: test_name = "Unknown Test";
            endcase

            $display("Test %0d: %s", test_id, test_name);

            // Check registered outputs on next rising edge
            @(posedge clk);
            #1;

            total_tests = total_tests + 1;
            if (pc_out_o === expected_pc &&
                instr_out_o === expected_instr) begin
                test_passed = test_passed + 1;
            `ifdef DEBUG
                $display("  Pass: Registered outputs");
                $display("    PC: 0x%h, Instr: 0x%h", pc_out_o, instr_out_o);
            `endif
            end else begin
                error_count = error_count + 1;
                $display("  Error: Registered outputs");
                $display("    PC: expected 0x%h, got 0x%h", expected_pc, pc_out_o);
                $display("    Instr: expected 0x%h, got 0x%h", expected_instr, instr_out_o);
            end
        end
    endtask

    // Test Task: Test Stall Functionality
    task test_stall();
        reg [31:0] prev_instr;
        begin
            $display("Test 11: Stall Functionality Test");

            @(posedge clk);
            #1;
            prev_instr = instr_out_o;

            @(negedge clk);
            stall_i = 1'b1;
            instr_in_i = 32'h002181b3; // Different instruction

            @(posedge clk);
            #1;

            total_tests = total_tests + 1;
            if (instr_out_o === prev_instr) begin
                test_passed = test_passed + 1;
            `ifdef DEBUG
                $display("  Pass: Stall functionality");
            `endif
            end else begin
                error_count = error_count + 1;
                $display("  Error: Stall functionality");
                $display("    Expected instr_out_o to remain 0x%h, got 0x%h", prev_instr, instr_out_o);
            end

            @(negedge clk);
            stall_i = 1'b0;
        end
    endtask

    // Test Task: Test Flush Functionality
    task test_flush();
        begin
            $display("Test 12: Flush Functionality Test");

            @(negedge clk);
            flush_i = 1'b1;

            @(posedge clk);
            #1;

            total_tests = total_tests + 1;
            if (instr_out_o === 32'h00000013) begin // NOP instruction
                test_passed = test_passed + 1;
            `ifdef DEBUG
                $display("  Pass: Flush functionality");
            `endif
            end else begin
                error_count = error_count + 1;
                $display("  Error: Flush functionality");
                $display("    Expected instr_out_o to be NOP (0x00000013), got 0x%h", instr_out_o);
            end

            @(negedge clk);
            flush_i = 1'b0;
        end
    endtask

    // Main Test Program
    initial begin
        // Initialization
        rst_n = 1;
        stall_i = 0;
        flush_i = 0;
        pc_in_i = 0;
        instr_in_i = 0;
        funct3_i = 0;
        test_passed = 0;
        total_tests = 0;
        error_count = 0;

        // Perform Reset
        $display("start test: riscv64_instruction_decode ut");
        $display("Test 1: Perform Reset Operation");
        rst_n = 0;
        #20 rst_n = 1;
        #10;

        // Verify reset values
        @(posedge clk);
        #1;
        total_tests = total_tests + 1;
        if (pc_out_o === 64'b0 && instr_out_o === 32'h00000000) begin
            test_passed = test_passed + 1;
            $display("  Pass: Reset values");
        end else begin
            error_count = error_count + 1;
            $display("  Error: Reset values");
            $display("    PC: expected 0x0 got 0x%h", pc_out_o);
            $display("    Instr: expected 0x00000000 got 0x%h", instr_out_o);
        end

        // Test 2: R-type Instruction (ADD)
        set_instruction(64'h80000000, 32'h003181b3, 3'b000); // ADD x3, x3, x1
        check_outputs(64'h80000000, 32'h003181b3, 2, 2);

        // Test 3: I-type Instruction (ADDI)
        set_instruction(64'h80000004, 32'h00510113, 3'b000); // ADDI x2, x2, 5
        check_outputs(64'h80000004, 32'h00510113, 3, 3);

        // Test 4: U-type Instruction (LUI)
        set_instruction(64'h80000008, 32'h00100237, 3'b000); // LUI x4, 1
        check_outputs(64'h80000008, 32'h00100237, 4, 4);

        // Test 5: U-type Instruction (AUIPC)
        set_instruction(64'h8000000c, 32'h002002b7, 3'b000); // AUIPC x5, 2
        check_outputs(64'h8000000c, 32'h002002b7, 5, 5);

        // Test 6: J-type Instruction (JAL)
        set_instruction(64'h80000010, 32'h00a000ef, 3'b000); // JAL x0, 10
        check_outputs(64'h80000010, 32'h00a000ef, 6, 6);

        // Test 7: I-type Instruction (JALR)
        set_instruction(64'h80000014, 32'h006100e7, 3'b000); // JALR x0, x2, 6
        check_outputs(64'h80000014, 32'h006100e7, 7, 7);

        // Test 8: B-type Instruction (BEQ)
        set_instruction(64'h80000018, 32'h00410c63, 3'b000); // BEQ x2, x4, 12
        check_outputs(64'h80000018, 32'h00410c63, 8, 8);

        // Test 9: Load Instruction (LW)
        set_instruction(64'h8000001c, 32'h00812283, 3'b010); // LW x5, 8(x2)
        check_outputs(64'h8000001c, 32'h00812283, 9, 9);

        // Test 10: Store Instruction (SW)
        set_instruction(64'h80000020, 32'h00a1a023, 3'b010); // SW x5, 0(x2)
        check_outputs(64'h80000020, 32'h00a1a023, 10, 10);

        // Test 11: Stall Functionality
        test_stall();

        // Test 12: Flush Functionality
        test_flush();

        // Test Summary
        #10;
        $display("========================================");
        $display("Test Summary: riscv64_instruction_decode Unit Test");
        $display("Total Tests: %d", total_tests);
        $display("Passed Tests: %d", test_passed);
        $display("Failed Tests: %d", error_count);
        $display("Test Result: %s", (error_count == 0) ? "PASS" : "FAIL");
        $display("========================================");

        // Finish Simulation
        $finish;
    end

endmodule