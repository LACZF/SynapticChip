// riscv64_memory_arbiter.v
module riscv64_memory_arbiter #(
    parameter NUM_MASTERS                        = 2,
    parameter ADDR_WIDTH                         = 64,
    parameter DATA_WIDTH                         = 64
) (
    input wire                                   clk,
    input wire                                   rst_n,

    // Master interfaces
    input  wire [NUM_MASTERS-1:0]                master_req,
    input  wire [NUM_MASTERS*ADDR_WIDTH-1:0]     master_addr,
    input  wire [NUM_MASTERS*DATA_WIDTH-1:0]     master_wdata,
    input  wire [NUM_MASTERS-1:0]                master_we,
    input  wire [NUM_MASTERS*8-1:0]              master_byte_en,
    output wire [NUM_MASTERS-1:0]                master_grant,

    // Memory interface
    output reg  [ADDR_WIDTH-1:0]                 mem_addr,
    output reg  [DATA_WIDTH-1:0]                 mem_wdata,
    input  wire [DATA_WIDTH-1:0]                 mem_rdata,
    output reg                                   mem_we,
    output reg [7:0]                             mem_byte_en,
    output reg                                   mem_req,
    input  wire                                  mem_ready
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
            mem_req <= 1'b0;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (|master_req) begin
                        state <= STATE_ARBITRATE;
                        pending_req <= master_req;
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
                            mem_addr <= master_addr[j*ADDR_WIDTH +: ADDR_WIDTH];
                            mem_wdata <= master_wdata[j*DATA_WIDTH +: DATA_WIDTH];
                            mem_we <= master_we[j];
                            mem_byte_en <= master_byte_en[j*8 +: 8];
                            mem_req <= 1'b1;
                            j = NUM_MASTERS; // Alternative way to exit loop
                        end
                    end
                end

                STATE_ACCESS: begin
                    if (mem_ready) begin
                        mem_req <= 1'b0;
                        state <= STATE_IDLE;
                        grant_reg <= {NUM_MASTERS{1'b0}};
                    end
                end
            endcase
        end
    end

    assign master_grant = grant_reg;

endmodule