// system_bus_arbiter.v
module system_bus_arbiter #(
    parameter NUM_MASTERS = 4,
    parameter ADDR_WIDTH = 64,
    parameter DATA_WIDTH = 64
) (
    input wire clk,
    input wire rst_n,

    // CPU接口（来自L2缓存）
    input wire cpu_req,
    input wire [ADDR_WIDTH-1:0] cpu_addr,
    input wire [DATA_WIDTH-1:0] cpu_wdata,
    output reg [DATA_WIDTH-1:0] cpu_rdata,
    input wire cpu_we,
    input wire [7:0] cpu_byte_en,
    output reg cpu_ready,

    // 系统总线
    output reg [ADDR_WIDTH-1:0] sys_addr,
    output reg [DATA_WIDTH-1:0] sys_wdata,
    input wire [DATA_WIDTH-1:0] sys_rdata,
    output reg sys_we,
    output reg [7:0] sys_byte_en,
    output reg sys_req,
    input wire sys_ready,
    output reg [1:0] sys_master_id
);

    reg [2:0] state;
    reg [ADDR_WIDTH-1:0] saved_addr;
    reg [DATA_WIDTH-1:0] saved_wdata;
    reg saved_we;
    reg [7:0] saved_byte_en;

    localparam STATE_IDLE = 3'b000;
    localparam STATE_ARBITRATE = 3'b001;
    localparam STATE_ACCESS = 3'b010;
    localparam STATE_WAIT = 3'b011;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            cpu_ready <= 1'b0;
            sys_req <= 1'b0;
            sys_master_id <= 2'b00;
        end else begin
            case (state)
                STATE_IDLE: begin
                    cpu_ready <= 1'b0;

                    if (cpu_req) begin
                        state <= STATE_ARBITRATE;
                        saved_addr <= cpu_addr;
                        saved_wdata <= cpu_wdata;
                        saved_we <= cpu_we;
                        saved_byte_en <= cpu_byte_en;
                    end
                end

                STATE_ARBITRATE: begin
                    // 固定优先级仲裁（可扩展为轮询）
                    sys_addr <= saved_addr;
                    sys_wdata <= saved_wdata;
                    sys_we <= saved_we;
                    sys_byte_en <= saved_byte_en;
                    sys_req <= 1'b1;
                    sys_master_id <= 2'b00; // 主设备ID

                    state <= STATE_ACCESS;
                end

                STATE_ACCESS: begin
                    if (sys_ready) begin
                        cpu_rdata <= sys_rdata;
                        cpu_ready <= 1'b1;
                        sys_req <= 1'b0;
                        state <= STATE_IDLE;
                    end else begin
                        state <= STATE_WAIT;
                    end
                end

                STATE_WAIT: begin
                    if (sys_ready) begin
                        cpu_rdata <= sys_rdata;
                        cpu_ready <= 1'b1;
                        sys_req <= 1'b0;
                        state <= STATE_IDLE;
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
