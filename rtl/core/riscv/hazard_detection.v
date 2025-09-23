// hazard_detection.v
module hazard_detection (
    input wire [4:0] id_ex_rd,
    input wire id_ex_mem_re,
    input wire [4:0] if_id_rs1,
    input wire [4:0] if_id_rs2,

    output reg stall,
    output reg flush
);

    // 检测LOAD-use冒险
    always @(*) begin
        stall = 1'b0;
        flush = 1'b0;

        if (id_ex_mem_re &&
           ((id_ex_rd == if_id_rs1) || (id_ex_rd == if_id_rs2))) begin
            stall = 1'b1;
        end
    end

endmodule
