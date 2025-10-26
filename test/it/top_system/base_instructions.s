
.section .text
.global _start

_start:
    # ==================== 初始化阶段 ====================
    li sp, 0x1000          # 设置栈指针
    li a0, 0x800           # 测试结果存储基地址

    # ==================== RV64I 整数计算指令测试 ====================

    # ADDI 测试
    li x1, 0x123
    addi x2, x1, 0x456     # x2 = 0x123 + 0x456 = 0x579
    sw x2, 0(a0)           # 存储结果

    # SLTI 测试
    li x3, -10
    slti x4, x3, 0         # x4 = (-10 < 0) ? 1 : 0 = 1
    slti x5, x1, 0         # x5 = (0x123 > 0) ? 0 : 0 = 0
    sw x4, 8(a0)
    sw x5, 16(a0)

    # SLTIU 测试 - 修复立即数格式
    li x6, -1              # x6 = 0xFFFFFFFFFFFFFFFF
    sltiu x7, x6, 1        # x7 = (大无符号数 < 1) ? 1 : 0 = 0
    li x8, 0x1000          # 先加载立即数到寄存器
    sltu x8, x3, x8        # x8 = (-10作为无符号数 < 0x1000) ? 1 : 0
    sw x7, 24(a0)
    sw x8, 32(a0)

    # ANDI/ORI/XORI 测试 - 修复立即数格式
    li x9, 0xFF00
    andi x10, x9, 0x0F0    # x10 = 0xFF00 & 0x0F0 = 0x0F00 (使用较小的立即数)
    ori x11, x9, 0x00F     # x11 = 0xFF00 | 0x00F = 0xFF0F
    xori x12, x9, 0x0FF    # x12 = 0xFF00 ^ 0x0FF = 0xF0FF
    sw x10, 40(a0)
    sw x11, 48(a0)
    sw x12, 56(a0)

    # SLLI/SRLI/SRAI 测试
    li x13, 0x8765432100000000
    slli x14, x13, 8       # x14 = 左移8位
    srli x15, x13, 16      # x15 = 逻辑右移16位
    srai x16, x13, 24      # x16 = 算术右移24位
    sw x14, 64(a0)
    sw x15, 72(a0)
    sw x16, 80(a0)

    # ==================== RV64I 寄存器-寄存器指令测试 ====================

    # ADD/SUB 测试
    li x17, 1000
    li x18, 500
    add x19, x17, x18      # x19 = 1500
    sub x20, x17, x18      # x20 = 500
    sw x19, 88(a0)
    sw x20, 96(a0)

    # SLT/SLTU 测试
    slt x21, x3, x17       # x21 = (-10 < 1000) ? 1 : 0 = 1
    sltu x22, x3, x17      # x22 = (大无符号数 < 1000) ? 0 : 1 = 1
    sw x21, 104(a0)
    sw x22, 112(a0)

    # AND/OR/XOR 测试
    li x23, 0xAAAAAAAAAAAAAAAA
    li x24, 0x5555555555555555
    and x25, x23, x24      # x25 = 0
    or x26, x23, x24       # x26 = 0xFFFFFFFFFFFFFFFF
    xor x27, x23, x24      # x27 = 0xFFFFFFFFFFFFFFFF
    sw x25, 120(a0)
    sw x26, 128(a0)
    sw x27, 136(a0)

    # SLL/SRL/SRA 测试
    li x28, 0x1234567800000000
    li x29, 16
    sll x30, x28, x29      # 左移16位
    srl x31, x28, x29      # 逻辑右移16位
    sra x1, x28, x29       # 算术右移16位
    sw x30, 144(a0)
    sw x31, 152(a0)
    sw x1, 160(a0)

    # ==================== RV64I 加载指令测试 ====================

load_test:
    # 准备测试数据
    li x2, 0x2000
    li x3, 0x12345678AABBCCDD
    sd x3, 0(x2)           # 存储双字

    # LB/LH/LW/LD 测试
    lb x4, 0(x2)           # 加载字节 (0xDD)
    lh x5, 0(x2)           # 加载半字 (0xCCDD)
    lw x6, 0(x2)           # 加载字 (0xAABBCCDD)
    ld x7, 0(x2)           # 加载双字 (0x12345678AABBCCDD)
    sw x4, 168(a0)
    sw x5, 176(a0)
    sw x6, 184(a0)
    sw x7, 192(a0)

    # LBU/LHU/LWU 测试
    lbu x8, 0(x2)          # 无符号加载字节 (0xDD)
    lhu x9, 0(x2)          # 无符号加载半字 (0xCCDD)
    lwu x10, 0(x2)         # 无符号加载字 (0xAABBCCDD)
    sw x8, 200(a0)
    sw x9, 208(a0)
    sw x10, 216(a0)

    # ==================== RV64I 存储指令测试 ====================

store_test:
    li x11, 0x3000
    li x12, 0x1122334455667788

    # SB/SH/SW/SD 测试
    sb x12, 0(x11)         # 存储字节
    sh x12, 4(x11)         # 存储半字
    sw x12, 8(x11)         # 存储字
    sd x12, 16(x11)        # 存储双字

    # 验证存储结果
    lb x13, 0(x11)         # 应该为 0x88
    lh x14, 4(x11)         # 应该为 0x7788
    lw x15, 8(x11)         # 应该为 0x55667788
    ld x16, 16(x11)        # 应该为 0x1122334455667788
    sw x13, 224(a0)
    sw x14, 232(a0)
    sw x15, 240(a0)
    sw x16, 248(a0)

    # ==================== RV64I 分支指令测试 ====================

branch_test:
    li x17, 10
    li x18, 20
    li x19, 10

    # BEQ 测试
    beq x17, x19, beq_pass
    j beq_fail
beq_pass:
    li x20, 1
    j beq_done
beq_fail:
    li x20, 0
beq_done:
    sw x20, 256(a0)

    # BNE 测试
    bne x17, x18, bne_pass
    j bne_fail
bne_pass:
    li x21, 1
    j bne_done
bne_fail:
    li x21, 0
bne_done:
    sw x21, 264(a0)

    # BLT 测试
    blt x17, x18, blt_pass
    j blt_fail
blt_pass:
    li x22, 1
    j blt_done
blt_fail:
    li x22, 0
blt_done:
    sw x22, 272(a0)

    # BGE 测试
    bge x18, x17, bge_pass
    j bge_fail
bge_pass:
    li x23, 1
    j bge_done
bge_fail:
    li x23, 0
bge_done:
    sw x23, 280(a0)

    # BLTU/BGEU 测试
    li x24, -1             # 大无符号数 0xFFFFFFFFFFFFFFFF
    li x25, 100
    bltu x25, x24, bltu_pass    # 100 < 大无符号数
    j bltu_fail
bltu_pass:
    li x26, 1
    j bltu_done
bltu_fail:
    li x26, 0
bltu_done:
    sw x26, 288(a0)

    # ==================== RV64I 其他指令测试 ====================

    # LUI/AUIPC 测试
    lui x27, 0x12345       # x27 = 0x12345000
    auipc x28, 0x10000     # x28 = PC + 0x10000000
    sw x27, 296(a0)
    sw x28, 304(a0)

    # JAL 测试
    jal x29, jal_target
    j jal_continue
jal_target:
    li x30, 0x5555
    sw x30, 312(a0)
    jalr x0, x29, 0
jal_continue:

    # JALR 测试
    la x31, jalr_target
    jalr x1, x31, 0
    j jalr_continue
jalr_target:
    li x2, 0xAAAA
    sw x2, 320(a0)
    jalr x0, x1, 0
jalr_continue:

    # ==================== RV64M 乘除指令测试 ====================

    # MUL 测试
    li x3, 25
    li x4, 4
    mul x5, x3, x4         # x5 = 100
    sw x5, 328(a0)

    # MULH 测试 (有符号高位乘法)
    li x6, 0x7000000000000000
    li x7, 2
    mulh x8, x6, x7        # 高位结果
    sw x8, 336(a0)

    # MULHU 测试 (无符号高位乘法)
    li x9, 0xF000000000000000
    mulhu x10, x9, x7      # 无符号高位结果
    sw x10, 344(a0)

    # MULHSU 测试 (有符号-无符号高位乘法)
    li x11, -2             # 有符号
    li x12, 0xFFFFFFFFFFFFFFFF  # 无符号大数
    mulhsu x13, x11, x12   # 混合符号高位乘法
    sw x13, 352(a0)

    # DIV 测试 (有符号除法)
    li x14, 100
    li x15, -25
    div x16, x14, x15      # 100 / -25 = -4
    sw x16, 360(a0)

    # DIVU 测试 (无符号除法)
    li x17, 100
    li x18, 25
    divu x19, x17, x18     # 100 / 25 = 4
    sw x19, 368(a0)

    # REM 测试 (有符号取余)
    li x20, 107
    li x21, 25
    rem x22, x20, x21      # 107 % 25 = 7
    sw x22, 376(a0)

    # REMU 测试 (无符号取余)
    remu x23, x20, x21     # 107 % 25 = 7
    sw x23, 384(a0)

    # ==================== 边界情况测试 ====================

edge_cases:
    # 除零测试
    li x24, 100
    li x25, 0
    divu x26, x24, x25     # 应该返回全1 (根据RISC-V规范)
    sw x26, 392(a0)

    # 最小负数除法测试
    li x27, 0x8000000000000000  # 最小有符号数
    li x28, -1
    div x29, x27, x28      # 特殊情况
    sw x29, 400(a0)

    # ==================== 测试完成 ====================

test_complete:
    # 设置测试完成标志
    li x30, 0x123456789ABCDEF
    sd x30, 408(a0)

    # 程序结束 - 使用ebreak或ecall退出
    ebreak
    # 或者无限循环
    # j .

.section .data
test_data:
    .dword 0x0