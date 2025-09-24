// riscv64_mem_sel.v
module riscv64_mem_sel (
    input wire [2:0] addr,      // 地址低3位
    input wire [2:0] mem_size,  // 内存访问大小
    output reg [7:0] mem_sel    // 8字节选择信号
);

    // 内存访问大小定义
    localparam MEM_BYTE  = 3'b000;
    localparam MEM_HALF  = 3'b001;
    localparam MEM_WORD  = 3'b010;
    localparam MEM_DWORD = 3'b011;

    always @(*) begin
        case (mem_size)
            MEM_BYTE: begin
                // 字节访问
                mem_sel = 8'b00000001 << addr;
            end
            MEM_HALF: begin
                // 半字访问（2字节，必须2字节对齐）
                case (addr[2:1])
                    2'b00: mem_sel = 8'b00000011;
                    2'b01: mem_sel = 8'b00001100;
                    2'b10: mem_sel = 8'b00110000;
                    2'b11: mem_sel = 8'b11000000;
                endcase
            end
            MEM_WORD: begin
                // 字访问（4字节，必须4字节对齐）
                case (addr[2])
                    1'b0: mem_sel = 8'b00001111;
                    1'b1: mem_sel = 8'b11110000;
                endcase
            end
            MEM_DWORD: begin
                // 双字访问（8字节，必须8字节对齐）
                mem_sel = 8'b11111111;
            end
            default: begin
                mem_sel = 8'b11111111;
            end
        endcase
    end

endmodule
