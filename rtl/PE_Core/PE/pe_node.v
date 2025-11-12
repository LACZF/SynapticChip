// pe_node.v
// PE top-level module, containing memory and interface logic

`include "pe.v"

module pe_node #(
    parameter ADDR_WIDTH         = 64,
    parameter DATA_WIDTH         = 64,
    parameter NUM_PES            = 4,
    parameter INST_WIDTH         = 32,
    parameter PE_ID_WIDTH        = 4,
    parameter PE_ARRAY_ROWS      = 2,
    parameter PE_ARRAY_COLS      = 2
) (
    input                        clk,
    input                        rst_n,
    input                        enable_i,

    // Instruction interface
    input [INST_WIDTH-1:0]       instruction_i,
    input                        inst_valid_i,

    // Data memory interface (connected to shared memory or upper-level memory)
    output                       ext_mem_req_o,
    output                       ext_mem_we_o,
    output [ADDR_WIDTH-1:0]      ext_mem_addr_o,
    output [DATA_WIDTH-1:0]      ext_mem_data_out_o,
    input  [DATA_WIDTH-1:0]      ext_mem_data_in_i,
    input                        ext_mem_ack_i,

    // Neighbor PE communication interface
    input                        north_valid_i,
    input  [DATA_WIDTH-1:0]      north_data_i,
    output                       north_ready_o,

    input                        south_valid_i,
    input  [DATA_WIDTH-1:0]      south_data_i,
    output                       south_ready_o,

    input                        east_valid_i,
    input  [DATA_WIDTH-1:0]      east_data_i,
    output                       east_ready_o,

    input                        west_valid_i,
    input  [DATA_WIDTH-1:0]      west_data_i,
    output                       west_ready_o,

    output                       out_valid_o,
    output [DATA_WIDTH-1:0]      out_data_o,

    // Status output
    output [DATA_WIDTH-1:0]      status_o,
    output                       busy_o,

    // IRQ interface
    output                       irq_o,           // IRQ输出信号
    output [7:0]                 irq_id_o         // IRQ ID输出
);

    // Local memory
    reg [DATA_WIDTH-1:0] local_mem [0:`MEM_DEPTH-1];
    reg                  local_mem_ack;

    // Memory interface signals
    wire                  mem_req;
    wire                  mem_we;
    wire [ADDR_WIDTH-1:0] mem_addr;
    wire [DATA_WIDTH-1:0] mem_data_out;
    wire [DATA_WIDTH-1:0] mem_data_in;
    wire                  mem_ack;

    // Address decoding
    wire local_access = (mem_addr < `MEM_DEPTH);
    wire ext_access   = !local_access;

    // Local memory access
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            local_mem_ack <= 0;
            // Initialize local memory
            for (integer i = 0; i < `MEM_DEPTH; i = i + 1) begin
                local_mem[i] <= 0;
            end
        end else begin
            local_mem_ack <= 0;

            if (mem_req && local_access) begin
                if (mem_we) begin
                    local_mem[mem_addr] <= mem_data_out;
                end
                local_mem_ack <= 1;
            end
        end
    end

    // Memory data selection
    assign mem_data_in = local_access ? local_mem[mem_addr] : ext_mem_data_in_i;
    assign mem_ack     = local_access ? local_mem_ack : ext_mem_ack_i;

    // External memory interface
    assign ext_mem_req_o      = mem_req && ext_access;
    assign ext_mem_we_o       = mem_we;
    assign ext_mem_addr_o     = mem_addr;
    assign ext_mem_data_out_o = mem_data_out;

    // PE core instantiation
    pe_core #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .NUM_PES(NUM_PES),
        .INST_WIDTH(INST_WIDTH),
        .PE_ID_WIDTH(PE_ID_WIDTH),
        .PE_ARRAY_ROWS(PE_ARRAY_ROWS),
        .PE_ARRAY_COLS(PE_ARRAY_COLS)
    ) core_inst (
        .clk(clk),
        .rst_n(rst_n),
        .enable_i(enable_i),
        .instruction_i(instruction_i),
        .inst_valid_i(inst_valid_i),
        .mem_req_o(mem_req),
        .mem_we_o(mem_we),
        .mem_addr_o(mem_addr),
        .mem_data_out_o(mem_data_out),
        .mem_data_in_i(mem_data_in),
        .mem_ack_i(mem_ack),
        .north_valid_i(north_valid_i),
        .north_data_i(north_data_i),
        .north_ready_o(north_ready_o),
        .south_valid_i(south_valid_i),
        .south_data_i(south_data_i),
        .south_ready_o(south_ready_o),
        .east_valid_i(east_valid_i),
        .east_data_i(east_data_i),
        .east_ready_o(east_ready_o),
        .west_valid_i(west_valid_i),
        .west_data_i(west_data_i),
        .west_ready_o(west_ready_o),
        .out_valid_o(out_valid_o),
        .out_data_o(out_data_o),
        .status_o(status_o),
        .busy_o(busy_o),
        .irq_o(irq_o),
        .irq_id_o(irq_id_o)
    );

endmodule