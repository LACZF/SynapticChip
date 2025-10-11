`timescale 1ns/1ps

// Instruction ROM module that reads from file - with req and valid signal control
module instruction_rom #(
    parameter MEM_SIZE                = 4096,              // Memory size (number of instructions)
    parameter ADDR_WIDTH              = 64,                // Address width
    parameter INSTR_WIDTH             = 32,                // Instruction width
    parameter INSTR_FILE              = "instructions.hex" // Instruction file path
) (
    input wire                        req,                 // Instruction request signal
    input wire [ADDR_WIDTH-1:0]       addr,                // Instruction address
    output wire [INSTR_WIDTH-1:0]     instr,               // Output instruction
    output wire                       valid                // Read completion valid signal
);

    // Instruction memory array
    reg [INSTR_WIDTH-1:0] mem[0:MEM_SIZE-1];
    integer i;

    // Initialize memory, read instructions from file
    initial begin
        $readmemh(INSTR_FILE, mem);

    `ifdef DEBUG
        $display("First few instructions loaded:");
        for (i = 0; i < 128; i = i + 1) begin
            $display("MEM[%0d] = 0x%h", i, mem[i]);
        end
    `endif
    end

    // Read instructions from memory - add address range check and request control
    wire [ADDR_WIDTH-1:0] addr_index = addr[ADDR_WIDTH-1:2];
    wire addr_valid = (addr_index < MEM_SIZE);

    // When request is valid and address is valid, set valid signal and output normal instruction
    // Otherwise output NOP instruction and valid signal is invalid
    assign valid = req && addr_valid;
    assign instr = (req && addr_valid) ? mem[addr_index] : {INSTR_WIDTH{1'b0}};

`ifdef DEBUG
    // Add debug information - only displayed when requested
    always @(posedge req) begin
        if (addr_valid) begin
            $display("[%0t ps] ROM: Request received, address=0x%h, index=%d, instruction=0x%h",
                     $time, addr, addr_index, mem[addr_index]);
        end else begin
            $display("[%0t ps] WARNING: ROM address out of range: 0x%h, index=%d",
                     $time, addr, addr_index);
        end
    end
`endif

endmodule