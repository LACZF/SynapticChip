module pe #(
    parameter DATA_WIDTH = 32
) (
    input                      clk,
    input                      rst_n,

    input                      enable_i,
    input                      start_i,
    input  [DATA_WIDTH-1:0]    op1_i,
    input  [DATA_WIDTH-1:0]    op2_i,
    input  [DATA_WIDTH-1:0]    config_i,

    output [DATA_WIDTH-1:0]    result_o,
    output                     done_o,
    output                     busy_o
);

    // 操作码定义
    localparam OP_ADD = 3'b000;
    localparam OP_SUB = 3'b001;
    localparam OP_MUL = 3'b010;
    localparam OP_AND = 3'b011;
    localparam OP_OR  = 3'b100;
    localparam OP_XOR = 3'b101;
    localparam OP_SHL = 3'b110;
    localparam OP_SHR = 3'b111;

    // 路由方向定义
    localparam DIR_NONE  = 2'b00;
    localparam DIR_NORTH = 2'b01;
    localparam DIR_SOUTH = 2'b10;
    localparam DIR_EAST  = 2'b11;
    localparam DIR_WEST  = 2'b11;

    // 配置解析
    wire [2:0] opcode       = config_i[2:0];      // 操作码
    wire [1:0] route_dir    = config_i[4:3];      // 路由方向
    wire       route_enable = config_i[5];        // 路由使能

    // 内部状态
    reg  [DATA_WIDTH-1:0] result_reg;
    reg                   done_reg;
    reg                   busy_reg;

    // 计算逻辑
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_reg <= {DATA_WIDTH{1'b0}};
            done_reg <= 1'b0;
            busy_reg <= 1'b0;
        end else begin
            done_reg <= 1'b0;

            if (enable_i && start_i && !busy_reg) begin
                busy_reg <= 1'b1;

                // 根据操作码执行计算
                case (opcode)
                    OP_ADD:  result_reg <= op1_i +  op2_i;
                    OP_SUB:  result_reg <= op1_i -  op2_i;
                    OP_MUL:  result_reg <= op1_i *  op2_i;
                    OP_AND:  result_reg <= op1_i &  op2_i;
                    OP_OR:   result_reg <= op1_i |  op2_i;
                    OP_XOR:  result_reg <= op1_i ^  op2_i;
                    OP_SHL:  result_reg <= op1_i << op2_i[4:0];
                    OP_SHR:  result_reg <= op1_i >> op2_i[4:0];
                    default: result_reg <= op1_i;
                endcase

                // 单周期计算完成
                done_reg <= 1'b1;
                busy_reg <= 1'b0;
            end
        end
    end

    assign result_o = result_reg;
    assign done_o   = done_reg;
    assign busy_o   = busy_reg;

endmodule