// riscv64_memory_arbiter.v
module riscv64_memory_arbiter #(
    parameter NUM_MASTERS                        = 2,
    parameter ADDR_WIDTH                         = 64,
    parameter DATA_WIDTH                         = 64
) (
    input wire                                   clk,
    input wire                                   rst_n,

    // Master interfaces
    input  wire [NUM_MASTERS-1:0]                master_req_i,
    input  wire [NUM_MASTERS*ADDR_WIDTH-1:0]     master_addr_i,
    input  wire [NUM_MASTERS*DATA_WIDTH-1:0]     master_wdata_i,
    input  wire [NUM_MASTERS-1:0]                master_we_i,
    input  wire [NUM_MASTERS*8-1:0]              master_byte_en_i,
    output wire [NUM_MASTERS-1:0]                master_grant_o,

    // Memory interface
    output reg  [ADDR_WIDTH-1:0]                 mem_addr_o,
    output reg  [DATA_WIDTH-1:0]                 mem_wdata_o,
    input  wire [DATA_WIDTH-1:0]                 mem_rdata_i,
    output reg                                   mem_we_o,
    output reg [7:0]                             mem_byte_en_o,
    output reg                                   mem_req_o,
    input  wire                                  mem_ready_i
);

    reg [NUM_MASTERS-1:0] grant_reg;
    reg [2:0]             state;
    reg [NUM_MASTERS-1:0] pending_req;

    localparam STATE_IDLE      = 3'b000;
    localparam STATE_ARBITRATE = 3'b001;
    localparam STATE_ACCESS    = 3'b010;

    // Round-robin arbitration
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            grant_reg <= {NUM_MASTERS{1'b0}};
            pending_req <= {NUM_MASTERS{1'b0}};
            mem_req_o <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (|master_req_i) begin
                        state <= STATE_ARBITRATE;
                        pending_req <= master_req_i;
                    end
                end

                STATE_ARBITRATE: begin
                    // Simple fixed-priority arbitration
                    grant_reg <= {NUM_MASTERS{1'b0}};
                    for (integer j = 0; j < NUM_MASTERS; j = j + 1) begin
                        if (pending_req[j]) begin
                            grant_reg[j] <= 1'b1;
                            state <= STATE_ACCESS;

                            // Set memory access signals
                            mem_addr_o <= master_addr_i[j*ADDR_WIDTH +: ADDR_WIDTH];
                            mem_wdata_o <= master_wdata_i[j*DATA_WIDTH +: DATA_WIDTH];
                            mem_we_o <= master_we_i[j];
                            mem_byte_en_o <= master_byte_en_i[j*8 +: 8];
                            mem_req_o <= 1'b1;
                            j = NUM_MASTERS; // Alternative way to exit loop
                        end
                    end
                end

                STATE_ACCESS: begin
                    if (mem_ready_i) begin
                        mem_req_o <= 1'b0;
                        state <= STATE_IDLE;
                        grant_reg <= {NUM_MASTERS{1'b0}};
                    end
                end
            endcase
        end
    end

    assign master_grant_o = grant_reg;

endmodule