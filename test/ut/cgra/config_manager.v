module config_manager #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 16,
    parameter TOTAL_PES = 4,
    parameter CONFIG_WIDTH = 64,
    parameter NUM_CONTEXTS = 4
)(
    input wire clk,
    input wire rst_n,

    // Configuration Interface
    input wire config_req,
    input wire config_we,
    input wire [ADDR_WIDTH-1:0] config_addr,
    input wire [DATA_WIDTH-1:0] config_wdata,
    output reg config_ready,

    // PE Configuration Output
    output reg [CONFIG_WIDTH-1:0] pe_config [0:TOTAL_PES-1],
    output reg [1:0] current_context,
    output reg context_switch
);

// 配置存储 - 每个PE 3个配置字
reg [DATA_WIDTH-1:0] config_memory [0:(TOTAL_PES*3)-1];

// 状态
reg state;
parameter IDLE = 1'b0;
parameter PROCESS = 1'b1;

// 地址解码
wire is_config_write = (config_addr[15:12] == 4'h0); // 0x0000-0x0FFF
wire is_context_write = (config_addr == 16'h1000);   // Context register
wire is_control_write = (config_addr == 16'h1010);   // Control register

// PE索引和配置字索引
wire [3:0] target_pe = config_addr[7:4];  // 每个PE 16字节空间
wire [1:0] word_index = config_addr[3:2]; // 4个字每个PE

integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        config_ready <= 1'b1;
        current_context <= 2'b00;
        context_switch <= 1'b0;

        // 初始化配置存储
        for (i = 0; i < TOTAL_PES*3; i = i + 1) begin
            config_memory[i] <= {DATA_WIDTH{1'b0}};
        end

        // 初始化PE配置
        for (i = 0; i < TOTAL_PES; i = i + 1) begin
            pe_config[i] <= {CONFIG_WIDTH{1'b0}};
        end
    end else begin
        context_switch <= 1'b0;

        case (state)
            IDLE: begin
                if (config_req) begin
                    state <= PROCESS;
                    config_ready <= 1'b0;

                    if (config_we) begin
                        if (is_config_write && (target_pe < TOTAL_PES)) begin
                            // 写入配置存储
                            config_memory[{target_pe, word_index}] <= config_wdata;
                            $display("Config Write: PE=%0d, word=%0d, data=0x%h",
                                     target_pe, word_index, config_wdata);
                        end else if (is_context_write) begin
                            // 更新上下文
                            current_context <= config_wdata[1:0];
                            context_switch <= 1'b1;
                            $display("Context Switch: context=%0d", config_wdata[1:0]);
                        end else if (is_control_write && config_wdata[0]) begin
                            // 加载配置到PE
                            for (i = 0; i < TOTAL_PES; i = i + 1) begin
                                pe_config[i] <= {config_memory[i*3+2],
                                               config_memory[i*3+1],
                                               config_memory[i*3+0]};
                                $display("PE Config Loaded: PE=%0d, config=0x%h_%h_%h",
                                         i, config_memory[i*3+2], config_memory[i*3+1], config_memory[i*3+0]);
                            end
                        end
                    end
                end
            end

            PROCESS: begin
                state <= IDLE;
                config_ready <= 1'b1;
            end
        endcase
    end
end

endmodule