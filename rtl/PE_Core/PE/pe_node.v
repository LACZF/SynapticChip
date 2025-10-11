// pe_node.v
// PE top-level module, containing memory and interface logic

`include "pe_params.v"

module pe_node #(
    parameter ADDR_WIDTH         = 32,
    parameter DATA_WIDTH         = 64,
    parameter NUM_PES            = 4,
    parameter INST_WIDTH         = 32,
    parameter PE_ID_WIDTH        = 4,
    parameter PE_ARRAY_ROWS      = 2,
    parameter PE_ARRAY_COLS      = 2
) (
    input                        clk,
    input                        rst_n,
    input                        enable,

    // Instruction interface
    input [INST_WIDTH-1:0]       instruction,
    input                        inst_valid,

    // Data memory interface (connected to shared memory or upper-level memory)
    output                       ext_mem_req,
    output                       ext_mem_we,
    output [ADDR_WIDTH-1:0]      ext_mem_addr,
    output [DATA_WIDTH-1:0]      ext_mem_data_out,
    input  [DATA_WIDTH-1:0]      ext_mem_data_in,
    input                        ext_mem_ack,

    // Neighbor PE communication interface
    input                        north_valid,
    input  [DATA_WIDTH-1:0]      north_data,
    output                       north_ready,

    input                        south_valid,
    input  [DATA_WIDTH-1:0]      south_data,
    output                       south_ready,

    input                        east_valid,
    input  [DATA_WIDTH-1:0]      east_data,
    output                       east_ready,

    input                        west_valid,
    input  [DATA_WIDTH-1:0]      west_data,
    output                       west_ready,

    output                       out_valid,
    output [DATA_WIDTH-1:0]      out_data,

    // Status output
    output [DATA_WIDTH-1:0]      status,
    output                       busy
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
    wire ext_access = !local_access;

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
    assign mem_data_in = local_access ? local_mem[mem_addr] : ext_mem_data_in;
    assign mem_ack = local_access ? local_mem_ack : ext_mem_ack;

    // External memory interface
    assign ext_mem_req = mem_req && ext_access;
    assign ext_mem_we = mem_we;
    assign ext_mem_addr = mem_addr;
    assign ext_mem_data_out = mem_data_out;

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
        .enable(enable),
        .instruction(instruction),
        .inst_valid(inst_valid),
        .mem_req(mem_req),
        .mem_we(mem_we),
        .mem_addr(mem_addr),
        .mem_data_out(mem_data_out),
        .mem_data_in(mem_data_in),
        .mem_ack(mem_ack),
        .north_valid(north_valid),
        .north_data(north_data),
        .north_ready(north_ready),
        .south_valid(south_valid),
        .south_data(south_data),
        .south_ready(south_ready),
        .east_valid(east_valid),
        .east_data(east_data),
        .east_ready(east_ready),
        .west_valid(west_valid),
        .west_data(west_data),
        .west_ready(west_ready),
        .out_valid(out_valid),
        .out_data(out_data),
        .status(status),
        .busy(busy)
    );

endmodule