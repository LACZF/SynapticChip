// pe_core.v
// PE core module implementation

`include "pe_params.v"

module pe_core #(
    parameter ADDR_WIDTH            = 32,
    parameter DATA_WIDTH            = 64,
    parameter NUM_PES               = 4,
    parameter INST_WIDTH            = 32,
    parameter PE_ID_WIDTH           = 4,
    parameter PE_ARRAY_ROWS         = 2,
    parameter PE_ARRAY_COLS         = 2
) (
    input                           clk,
    input                           rst_n,
    input                           enable,

    // Instruction interface
    input       [INST_WIDTH-1:0]    instruction,
    input                           inst_valid,

    // Data memory interface
    output                          mem_req,
    output                          mem_we,
    output      [ADDR_WIDTH-1:0]    mem_addr,
    output      [DATA_WIDTH-1:0]    mem_data_out,
    input       [DATA_WIDTH-1:0]    mem_data_in,
    input                           mem_ack,

    // Neighbor PE communication interface
    input                           north_valid,
    input       [DATA_WIDTH-1:0]    north_data,
    output                          north_ready,

    input                           south_valid,
    input       [DATA_WIDTH-1:0]    south_data,
    output                          south_ready,

    input                           east_valid,
    input       [DATA_WIDTH-1:0]    east_data,
    output                          east_ready,

    input                            west_valid,
    input       [DATA_WIDTH-1:0]     west_data,
    output                           west_ready,

    output reg                       out_valid,
    output reg  [DATA_WIDTH-1:0]     out_data,

    // Status output
    output reg  [DATA_WIDTH-1:0]     status,
    output reg                       busy
);

    // Internal register file
    reg [DATA_WIDTH-1:0] reg_file [0:`NUM_REGS-1];

    // Instruction decoding
    wire [`OPCODE_WIDTH-1:0]   opcode    = instruction[31:26];
    wire [`REG_ADDR_WIDTH-1:0] rd        = instruction[25:22];
    wire [`REG_ADDR_WIDTH-1:0] rs1       = instruction[21:18];
    wire [`REG_ADDR_WIDTH-1:0] rs2       = instruction[17:14];
    wire [13:0]                immediate = instruction[13:0];

    // Internal signals
    reg [DATA_WIDTH-1:0] alu_out;
    reg [DATA_WIDTH-1:0] alu_a, alu_b;
    reg alu_zero, alu_neg;

    // Status registers
    reg [1:0] mode;
    reg [DATA_WIDTH-1:0] pc; // Program counter
    reg [DATA_WIDTH-1:0] mar; // Memory address register
    reg [DATA_WIDTH-1:0] mdr; // Memory data register

    // Communication buffers - storage for incoming data from neighboring PEs
    reg [DATA_WIDTH-1:0] comm_buffer [0:3]; // 0: North, 1: South, 2: East, 3: West
    reg comm_ready [0:3];

    // State machine
    reg [2:0] state;
    parameter S_IDLE = 3'b000;
    parameter S_FETCH = 3'b001;
    parameter S_DECODE = 3'b010;
    parameter S_EXECUTE = 3'b011;
    parameter S_MEMORY = 3'b100;
    parameter S_COMM = 3'b101;

    // ALU operations
    always @(*) begin
        alu_zero = 0;
        alu_neg = 0;

        case (opcode)
            `OP_ADD: alu_out = alu_a + alu_b;
            `OP_SUB: alu_out = alu_a - alu_b;
            `OP_MUL: alu_out = alu_a * alu_b;
            `OP_AND: alu_out = alu_a & alu_b;
            `OP_OR:  alu_out = alu_a | alu_b;
            `OP_XOR: alu_out = alu_a ^ alu_b;
            `OP_NOT: alu_out = ~alu_a;
            `OP_SHL: alu_out = alu_a << alu_b[3:0];
            `OP_SHR: alu_out = alu_a >> alu_b[3:0];
            default: alu_out = 0;
        endcase

        if (alu_out == 0) alu_zero = 1;
        if (alu_out[DATA_WIDTH-1]) alu_neg = 1;
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            mode <= `MODE_IDLE;
            pc <= 0;
            mar <= 0;
            mdr <= 0;
            out_valid <= 0;
            out_data <= 0;
            busy <= 0;
            status <= 0;

            // Initialize register file
            for (integer i = 0; i < `NUM_REGS; i = i + 1) begin
                reg_file[i] <= 0;
            end

            // Initialize communication buffers
            for (integer j = 0; j < 4; j = j + 1) begin
                comm_buffer[j] <= 0;
                comm_ready[j] <= 0;
            end
        end else if (enable) begin
            case (state)
                S_IDLE: begin
                    busy <= 0;
                    if (inst_valid) begin
                        state <= S_FETCH;
                        busy <= 1;
                    end
                end

                S_FETCH: begin
                    // Instruction already input, decode directly
                    state <= S_DECODE;
                end

                S_DECODE: begin
                    // Prepare operands
                    alu_a <= reg_file[rs1];
                    alu_b <= (opcode == `OP_LOAD || opcode == `OP_STORE ||
                             opcode == `OP_JUMP || opcode[5:4] == 2'b01) ?
                             {{(DATA_WIDTH-14){immediate[13]}}, immediate} :
                             reg_file[rs2];

                    // Set memory address (for LOAD/STORE)
                    if (opcode == `OP_LOAD || opcode == `OP_STORE) begin
                        mar <= reg_file[rs1] + {{(DATA_WIDTH-14){immediate[13]}}, immediate};
                    end

                    state <= S_EXECUTE;
                end

                S_EXECUTE: begin
                    case (opcode)
                        `OP_ADD, `OP_SUB, `OP_MUL, `OP_AND, `OP_OR, `OP_XOR,
                        `OP_NOT, `OP_SHL, `OP_SHR: begin
                            // Arithmetic/logic operations
                            reg_file[rd] <= alu_out;
                            state <= S_IDLE;
                        end

                        `OP_LOAD: begin
                            // Memory read
                            mdr <= mem_data_in;
                            if (mem_ack) begin
                                reg_file[rd] <= mem_data_in;
                                state <= S_IDLE;
                            end else begin
                                state <= S_MEMORY;
                            end
                        end

                        `OP_STORE: begin
                            // Memory write
                            mdr <= reg_file[rs2];
                            if (mem_ack) begin
                                state <= S_IDLE;
                            end else begin
                                state <= S_MEMORY;
                            end
                        end

                        `OP_MOVE: begin
                            // Inter-register move
                            reg_file[rd] <= reg_file[rs1];
                            state <= S_IDLE;
                        end

                        `OP_JUMP: begin
                            // Unconditional jump
                            pc <= reg_file[rs1] + {{(DATA_WIDTH-14){immediate[13]}}, immediate};
                            state <= S_IDLE;
                        end

                        `OP_BEQ: begin
                            // Conditional jump: equal
                            if (alu_zero) begin
                                pc <= reg_file[rs1] + {{(DATA_WIDTH-14){immediate[13]}}, immediate};
                            end
                            state <= S_IDLE;
                        end

                        `OP_BNE: begin
                            // Conditional jump: not equal
                            if (!alu_zero) begin
                                pc <= reg_file[rs1] + {{(DATA_WIDTH-14){immediate[13]}}, immediate};
                            end
                            state <= S_IDLE;
                        end

                        `OP_BLT: begin
                            // Conditional jump: less than
                            if (alu_neg) begin
                                pc <= reg_file[rs1] + {{(DATA_WIDTH-14){immediate[13]}}, immediate};
                            end
                            state <= S_IDLE;
                        end

                        `OP_BGT: begin
                            // Conditional jump: greater than
                            if (!alu_neg && !alu_zero) begin
                                pc <= reg_file[rs1] + {{(DATA_WIDTH-14){immediate[13]}}, immediate};
                            end
                            state <= S_IDLE;
                        end

                        default: begin
                            // NOP or other undefined operations
                            state <= S_IDLE;
                        end
                    endcase
                end

                S_MEMORY: begin
                    // Handle memory access
                    if (mem_ack) begin
                        if (opcode == `OP_LOAD) begin
                            reg_file[rd] <= mdr;
                        end
                        state <= S_IDLE;
                    end
                end

                S_COMM: begin
                    // Handle communication
                    // Simplified handling here, actual implementation is more complex
                    state <= S_IDLE;
                end
            endcase

            // Handle communication input
            if (north_valid && north_ready) begin
                comm_buffer[0] <= north_data;
                comm_ready[0] <= 1;
            end

            if (south_valid && south_ready) begin
                comm_buffer[1] <= south_data;
                comm_ready[1] <= 1;
            end

            if (east_valid && east_ready) begin
                comm_buffer[2] <= east_data;
                comm_ready[2] <= 1;
            end

            if (west_valid && west_ready) begin
                comm_buffer[3] <= west_data;
                comm_ready[3] <= 1;
            end
        end
    end

    // Memory interface
    assign mem_req = (state == S_EXECUTE && (opcode == `OP_LOAD || opcode == `OP_STORE)) ||
                    (state == S_MEMORY);
    assign mem_we = (opcode == `OP_STORE);
    assign mem_addr = mar[ADDR_WIDTH-1:0];
    assign mem_data_out = mdr;

    // Communication interface
    assign north_ready = !comm_ready[0];
    assign south_ready = !comm_ready[1];
    assign east_ready = !comm_ready[2];
    assign west_ready = !comm_ready[3];

endmodule