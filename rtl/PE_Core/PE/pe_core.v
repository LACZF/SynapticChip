// pe_core.v
// PE core module implementation

`include "pe.v"

module pe_core #(
    parameter ADDR_WIDTH            = 64,
    parameter DATA_WIDTH            = 64,
    parameter NUM_PES               = 4,
    parameter INST_WIDTH            = 32,
    parameter PE_ID_WIDTH           = 4,
    parameter PE_ARRAY_ROWS         = 2,
    parameter PE_ARRAY_COLS         = 2
) (
    input                           clk,
    input                           rst_n,
    input                           enable_i,

    // Instruction interface
    input       [INST_WIDTH-1:0]    instruction_i,
    input                           inst_valid_i,

    // Data memory interface
    output                          mem_req_o,
    output                          mem_we_o,
    output      [ADDR_WIDTH-1:0]    mem_addr_o,
    output      [DATA_WIDTH-1:0]    mem_data_out_o,
    input       [DATA_WIDTH-1:0]    mem_data_in_i,
    input                           mem_ack_i,

    // Neighbor PE communication interface
    input                           north_valid_i,
    input       [DATA_WIDTH-1:0]    north_data_i,
    output                          north_ready_o,

    input                           south_valid_i,
    input       [DATA_WIDTH-1:0]    south_data_i,
    output                          south_ready_o,

    input                           east_valid_i,
    input       [DATA_WIDTH-1:0]    east_data_i,
    output                          east_ready_o,

    input                            west_valid_i,
    input       [DATA_WIDTH-1:0]     west_data_i,
    output                           west_ready_o,

    output reg                       out_valid_o,
    output reg  [DATA_WIDTH-1:0]     out_data_o,

    // Status output
    output reg  [DATA_WIDTH-1:0]     status_o,
    output reg                       busy_o
);

    // Internal register file
    reg [DATA_WIDTH-1:0] reg_file [0:`NUM_REGS-1];

    // Special register for status output
    wire [DATA_WIDTH-1:0] status_reg = reg_file[15]; // R15 is used for status output

    // Instruction decoding
    wire [`OPCODE_WIDTH-1:0]   opcode    = instruction_i[31:26];
    wire [`REG_ADDR_WIDTH-1:0] rd        = instruction_i[25:22];
    wire [`REG_ADDR_WIDTH-1:0] rs1       = instruction_i[21:18];
    wire [`REG_ADDR_WIDTH-1:0] rs2       = instruction_i[17:14];
    wire [13:0]                immediate = instruction_i[13:0];

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
            out_valid_o <= 0;
            out_data_o <= 0;
            busy_o <= 0;
            status_o <= 0;

            // Initialize register file
            for (integer i = 0; i < `NUM_REGS; i = i + 1) begin
                reg_file[i] <= 0;
            end

            // Initialize communication buffers
            for (integer j = 0; j < 4; j = j + 1) begin
                comm_buffer[j] <= 0;
                comm_ready[j] <= 0;
            end
        end else if (enable_i) begin
            case (state)
                S_IDLE: begin
                    busy_o <= 0;
                    if (inst_valid_i) begin
                        state <= S_FETCH;
                        busy_o <= 1;
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
                            mdr <= mem_data_in_i;
                            if (mem_ack_i) begin
                                reg_file[rd] <= mem_data_in_i;
                                state <= S_IDLE;
                            end else begin
                                state <= S_MEMORY;
                            end
                        end

                        `OP_STORE: begin
                            // Memory write
                            mdr <= reg_file[rs2];
                            if (mem_ack_i) begin
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
                    if (mem_ack_i) begin
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
            if (north_valid_i && north_ready_o) begin
                comm_buffer[0] <= north_data_i;
                comm_ready[0] <= 1;
            end

            if (south_valid_i && south_ready_o) begin
                comm_buffer[1] <= south_data_i;
                comm_ready[1] <= 1;
            end

            if (east_valid_i && east_ready_o) begin
                comm_buffer[2] <= east_data_i;
                comm_ready[2] <= 1;
            end

            if (west_valid_i && west_ready_o) begin
                comm_buffer[3] <= west_data_i;
                comm_ready[3] <= 1;
            end

            // Update status output with R15 register value
            status_o <= status_reg;
        end
    end

    // Memory interface
    assign mem_req_o = (state == S_EXECUTE && (opcode == `OP_LOAD || opcode == `OP_STORE)) ||
                    (state == S_MEMORY);
    assign mem_we_o = (opcode == `OP_STORE);
    assign mem_addr_o = mar[ADDR_WIDTH-1:0];
    assign mem_data_out_o = mdr;

    // Communication interface
    assign north_ready_o = !comm_ready[0];
    assign south_ready_o = !comm_ready[1];
    assign east_ready_o = !comm_ready[2];
    assign west_ready_o = !comm_ready[3];

endmodule