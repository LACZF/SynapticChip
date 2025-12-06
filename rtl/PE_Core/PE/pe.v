module ip4_pe #(
    parameter DATA_WIDTH = 32
)(
    input  wire                  clk,
    input  wire                  rst_n,
    input  wire                  enable,
    input  wire                  start,
    input  wire [DATA_WIDTH-1:0] operand1,
    input  wire [DATA_WIDTH-1:0] operand2,
    input  wire [DATA_WIDTH-1:0] config_data,

    // Inter-PE inputs
    input  wire [DATA_WIDTH-1:0] north_in,
    input  wire [DATA_WIDTH-1:0] south_in,
    input  wire [DATA_WIDTH-1:0] east_in,
    input  wire [DATA_WIDTH-1:0] west_in,
    input  wire                  north_valid_in,
    input  wire                  south_valid_in,
    input  wire                  east_valid_in,
    input  wire                  west_valid_in,

    // Outputs
    output reg  [DATA_WIDTH-1:0] result,
    output reg                   result_valid
);

    // Opcode definitions - 操作码定义
    localparam [7:0] OP_PASS  = 8'h00;  // PASS (直接传递src1)
    localparam [7:0] OP_ADD   = 8'h01;  // ADD
    localparam [7:0] OP_SUB   = 8'h02;  // SUB
    localparam [7:0] OP_AND   = 8'h03;  // AND
    localparam [7:0] OP_OR    = 8'h04;  // OR
    localparam [7:0] OP_XOR   = 8'h05;  // XOR
    localparam [7:0] OP_MUL   = 8'h06;  // MUL
    localparam [7:0] OP_MIN   = 8'h07;  // MIN
    localparam [7:0] OP_MAX   = 8'h08;  // MAX
    localparam [7:0] OP_SHL   = 8'h09;  // SHL
    localparam [7:0] OP_SHR   = 8'h0A;  // SHR
    localparam [7:0] OP_ASHR  = 8'h0B;  // ASHR (算术右移)
    localparam [7:0] OP_EQ    = 8'h0C;  // EQ (等于比较)
    localparam [7:0] OP_LT    = 8'h0D;  // LT (小于比较)

    // Source selection definitions - 源选择定义
    localparam [2:0] SRC_INVALID  = 3'b000;  // 非法值
    localparam [2:0] SRC_EAST     = 3'b001;  // 东方向输入
    localparam [2:0] SRC_SOUTH    = 3'b010;  // 南方向输入
    localparam [2:0] SRC_WEST     = 3'b011;  // 西方向输入
    localparam [2:0] SRC_NORTH    = 3'b100;  // 北方向输入
    localparam [2:0] SRC_OPERAND1 = 3'b101;  // 外部操作数1
    localparam [2:0] SRC_OPERAND2 = 3'b110;  // 外部操作数2

    // Configuration bits - 重新分配配置位
    wire [7:0] opcode    = config_data[7:0];   // 操作码使用8位
    wire [2:0] src1_sel  = config_data[10:8];  // 源1选择器使用3位
    wire [2:0] src2_sel  = config_data[13:11]; // 源2选择器使用3位

    // Internal signals
    reg  [DATA_WIDTH-1:0] src1, src2;
    reg                   src1_valid, src2_valid;
    reg                   computation_active;

    always @(*) begin
        // Select source 1 from inter-PE connections or external operands
        case (src1_sel)
            SRC_INVALID: begin
                src1       = {DATA_WIDTH{1'b0}};
                src1_valid = 1'b0;
            end
            SRC_EAST: begin
                src1       = east_in;
                src1_valid = east_valid_in;
            end
            SRC_SOUTH: begin
                src1       = south_in;
                src1_valid = south_valid_in;
            end
            SRC_WEST: begin
                src1       = west_in;
                src1_valid = west_valid_in;
            end
            SRC_NORTH: begin
                src1       = north_in;
                src1_valid = north_valid_in;
            end
            SRC_OPERAND1: begin
                src1       = operand1;
                src1_valid = 1'b1;
            end
            SRC_OPERAND2: begin
                src1       = operand2;
                src1_valid = 1'b1;
            end
            default: begin
                src1       = {DATA_WIDTH{1'b0}};
                src1_valid = 1'b0;
            end
        endcase

        case (src2_sel)
            SRC_INVALID: begin
                src2       = {DATA_WIDTH{1'b0}};
                src2_valid = 1'b0;
            end
            SRC_EAST: begin
                src2       = east_in;
                src2_valid = east_valid_in;
            end
            SRC_SOUTH: begin
                src2       = south_in;
                src2_valid = south_valid_in;
            end
            SRC_WEST: begin
                src2       = west_in;
                src2_valid = west_valid_in;
            end
            SRC_NORTH: begin
                src2       = north_in;
                src2_valid = north_valid_in;
            end
            SRC_OPERAND1: begin
                src2       = operand1;
                src2_valid = 1'b1;
            end
            SRC_OPERAND2: begin
                src2       = operand2;
                src2_valid = 1'b1;
            end
            default: begin
                src2       = {DATA_WIDTH{1'b0}};
                src2_valid = 1'b0;
            end
        endcase
    end

    // 内部寄存器
    reg  [7:0] opcode_reg;
    reg  [DATA_WIDTH-1:0] src1_reg, src2_reg;
    reg                   src1_valid_reg, src2_valid_reg;

    // 乘法器实例化
    wire [DATA_WIDTH*2-1:0] mul_result;
    combinational_multiplier #(
        .DATA_WIDTH(DATA_WIDTH)
    ) mul_inst (
        .a(src1_reg),
        .b(src2_reg),
        .result(mul_result)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result             <= {DATA_WIDTH{1'b0}};
            result_valid       <= 1'b0;
            computation_active <= 1'b0;
            opcode_reg         <= 8'h0;
            src1_reg           <= {DATA_WIDTH{1'b0}};
            src2_reg           <= {DATA_WIDTH{1'b0}};
            src1_valid_reg     <= 1'b0;
            src2_valid_reg     <= 1'b0;
        end else if (enable) begin
            // 启动计算
            if (start && !computation_active) begin
                computation_active <= 1'b1;
                result_valid       <= 1'b0;
                opcode_reg         <= opcode;
            end

            // 在计算活跃时，持续采样输入数据和有效信号
            if (computation_active) begin
                src1_reg       <= src1;
                src2_reg       <= src2;
                src1_valid_reg <= src1_valid;
                src2_valid_reg <= src2_valid;
            end

            // 执行计算 - 使用寄存器化的有效信号
            if (computation_active) begin
                // 检查输入数据是否有效
                if (src1_valid_reg && src2_valid_reg) begin
                    // 所有操作都是单周期完成
                    case (opcode_reg)
                        OP_PASS:  result <= src1_reg;
                        OP_ADD:   result <= src1_reg + src2_reg;
                        OP_SUB:   result <= src1_reg - src2_reg;
                        OP_AND:   result <= src1_reg & src2_reg;
                        OP_OR:    result <= src1_reg | src2_reg;
                        OP_XOR:   result <= src1_reg ^ src2_reg;
                        OP_MUL:   result <= mul_result[DATA_WIDTH-1:0];
                        OP_MIN:   result <= src1_reg < src2_reg ? src1_reg : src2_reg;
                        OP_MAX:   result <= src1_reg > src2_reg ? src1_reg : src2_reg;
                        OP_SHL:   result <= src1_reg << src2_reg[4:0];
                        OP_SHR:   result <= src1_reg >> src2_reg[4:0];
                        OP_ASHR:  result <= $signed(src1_reg) >>> src2_reg[4:0];
                        OP_EQ:    result <= (src1_reg == src2_reg) ? {DATA_WIDTH{1'b1}} : {DATA_WIDTH{1'b0}};
                        OP_LT:    result <= (src1_reg < src2_reg) ? {DATA_WIDTH{1'b1}} : {DATA_WIDTH{1'b0}};
                        default:  result <= {DATA_WIDTH{1'b0}};
                    endcase
                    result_valid       <= 1'b1;
                    computation_active <= 1'b0; // 计算完成
                end else begin
                    // 等待输入数据有效
                    result_valid <= 1'b0;
                end
            end else begin
                result_valid <= 1'b0;
            end
        end else begin
            result_valid       <= 1'b0;
            computation_active <= 1'b0;
        end
    end

endmodule