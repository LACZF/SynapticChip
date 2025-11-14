module pe #(
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

    // Configuration bits
    wire [3:0] opcode                = config_data[3:0];
    wire       use_external_operands = config_data[6];
    wire [1:0] src1_sel              = config_data[8:7];
    wire [1:0] src2_sel              = config_data[10:9];

    // Internal signals
    reg  [DATA_WIDTH-1:0] src1, src2;
    reg                   src1_valid, src2_valid;
    reg                   computation_active;

    // Input selection logic
    always @(*) begin
        if (use_external_operands) begin
            // Use external operands from memory
            src1       = operand1;
            src2       = operand2;
            src1_valid = 1'b1;
            src2_valid = 1'b1;
        end else begin
            // Select source 1 from inter-PE connections
            case (src1_sel)
                2'b00: begin
                    src1       = north_in;
                    src1_valid = north_valid_in;
                end
                2'b01: begin
                    src1       = south_in;
                    src1_valid = south_valid_in;
                end
                2'b10: begin
                    src1       = east_in;
                    src1_valid = east_valid_in;
                end
                2'b11: begin
                    src1       = west_in;
                    src1_valid = west_valid_in;
                end
                default: begin
                    src1       = {DATA_WIDTH{1'b0}};
                    src1_valid = 1'b0;
                end
            endcase

            // Select source 2 from inter-PE connections
            case (src2_sel)
                2'b00: begin
                    src2       = north_in;
                    src2_valid = north_valid_in;
                end
                2'b01: begin
                    src2       = south_in;
                    src2_valid = south_valid_in;
                end
                2'b10: begin
                    src2       = east_in;
                    src2_valid = east_valid_in;
                end
                2'b11: begin
                    src2       = west_in;
                    src2_valid = west_valid_in;
                end
                default: begin
                    src2       = {DATA_WIDTH{1'b0}};
                    src2_valid = 1'b0;
                end
            endcase
        end
    end

    // Computation logic - 修复版本
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result             <= {DATA_WIDTH{1'b0}};
            result_valid       <= 1'b0;
            computation_active <= 1'b0;
        end else if (enable) begin
            // 启动计算
            if (start && !computation_active) begin
                computation_active <= 1'b1;
                result_valid       <= 1'b0;
            end

            // 执行计算
            if (computation_active && src1_valid && src2_valid) begin
                case (opcode)
                    4'b0000: result <= src1 + src2;        // ADD
                    4'b0001: result <= src1 - src2;        // SUB
                    4'b0010: result <= src1 & src2;        // AND
                    4'b0011: result <= src1 | src2;        // OR
                    4'b0100: result <= src1 ^ src2;        // XOR
                    4'b0101: result <= src1 * src2;        // MUL
                    4'b0110: result <= src1 < src2 ? src1 : src2; // MIN
                    4'b0111: result <= src1 > src2 ? src1 : src2; // MAX
                    4'b1000: result <= src1 << src2[4:0];  // SHL
                    4'b1001: result <= src1 >> src2[4:0];  // SHR
                    default: result <= {DATA_WIDTH{1'b0}};
                endcase
                result_valid       <= 1'b1;
                computation_active <= 1'b0; // 计算完成
            end else if (computation_active && (!src1_valid || !src2_valid)) begin
                // 等待输入数据有效
                result_valid <= 1'b0;
            end else begin
                result_valid <= 1'b0;
            end
        end else begin
            result_valid       <= 1'b0;
            computation_active <= 1'b0;
        end
    end

endmodule