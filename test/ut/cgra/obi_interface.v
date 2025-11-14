module obi_interface #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,

    // OBI Bus Signals
    input wire obi_req,
    input wire obi_we,
    input wire [ADDR_WIDTH-1:0] obi_addr,
    input wire [DATA_WIDTH-1:0] obi_wdata,
    output reg obi_gnt,
    output reg obi_rvalid,
    output reg [DATA_WIDTH-1:0] obi_rdata,

    // Configuration Interface
    output reg config_req,
    output reg config_we,
    output reg [ADDR_WIDTH-1:0] config_addr,
    output reg [DATA_WIDTH-1:0] config_wdata,
    input wire config_ready,

    // Data Memory Interface
    output reg data_mem_we,
    output reg [7:0] data_mem_addr,
    output reg [DATA_WIDTH-1:0] data_mem_wdata,
    input wire [DATA_WIDTH-1:0] data_mem_rdata,

    // Status
    output reg ready
);

// 状态机
parameter IDLE = 1'b0;
parameter PROCESS = 1'b1;
reg state;

// 地址空间定义
wire is_config_space = (obi_addr[15:12] == 4'h0);
wire is_data_space   = (obi_addr[15:12] == 4'h8);
wire is_control_space = (obi_addr[15:12] == 4'hC); // 控制空间

// 字地址转换（字节地址转字地址）
wire [7:0] word_addr = obi_addr[9:2]; // 忽略最低2位（字节偏移）

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        obi_gnt <= 1'b0;
        obi_rvalid <= 1'b0;
        obi_rdata <= {DATA_WIDTH{1'b0}};
        config_req <= 1'b0;
        config_we <= 1'b0;
        config_addr <= {ADDR_WIDTH{1'b0}};
        config_wdata <= {DATA_WIDTH{1'b0}};
        data_mem_we <= 1'b0;
        data_mem_addr <= 8'b0;
        data_mem_wdata <= {DATA_WIDTH{1'b0}};
        ready <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                obi_rvalid <= 1'b0;
                config_req <= 1'b0;
                data_mem_we <= 1'b0;
                ready <= 1'b1;

                if (obi_req) begin
                    state <= PROCESS;
                    obi_gnt <= 1'b1;

                    if (is_config_space) begin
                        config_req <= 1'b1;
                        config_we <= obi_we;
                        config_addr <= obi_addr;
                        config_wdata <= obi_wdata;
                    end else if (is_data_space || is_control_space) begin
                        data_mem_addr <= word_addr;
                        if (obi_we) begin
                            data_mem_we <= 1'b1;
                            data_mem_wdata <= obi_wdata;
                        end
                    end
                end
            end

            PROCESS: begin
                obi_gnt <= 1'b0;
                config_req <= 1'b0;
                data_mem_we <= 1'b0;

                obi_rvalid <= 1'b1;

                if (is_config_space) begin
                    obi_rdata <= config_ready ? 32'h1 : 32'h0;
                end else if ((is_data_space || is_control_space) && !obi_we) begin
                    obi_rdata <= data_mem_rdata;
                end else begin
                    obi_rdata <= obi_wdata; // Echo for writes
                end

                state <= IDLE;
            end
        endcase
    end
end

endmodule