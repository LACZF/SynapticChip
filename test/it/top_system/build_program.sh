#!/bin/bash

if [ -z "$RISCV_PREFIX" ]; then
    if [ "$(uname)" == "Linux" ]; then
        RISCV_PREFIX=riscv64-linux-elf-
    elif [ "$(uname)" == "Darwin" ]; then
        RISCV_PREFIX=riscv64-elf-
    else
        RISCV_PREFIX=riscv64-unknown-elf-
    fi
fi

# 编译选项
CFLAGS="-march=rv64im -mabi=lp64 -static -mcmodel=medany -nostartfiles -nostdlib"

# 编译为ELF文件
${RISCV_PREFIX}as -march=rv64im -o program.o program.s
${RISCV_PREFIX}ld -T script.ld -o program.elf program.o

# 生成反汇编文件用于调试
${RISCV_PREFIX}objdump -d program.elf > program.dis

# 生成hex文件
${RISCV_PREFIX}objcopy -O verilog program.elf program.hex

function asm_to_readmemh_file() {
    local in_file=$1
    local out_file=$2
    gawk '
        /[>][:]$/ {
            print "// " $0;
            next
        }

        /^[ \t]*[0-9a-fA-F]+:[ \t]*/ {
            # 匹配指令行：地址 + 机器码 + 汇编代码
            addr = $1;
            code = $2;
            asm = substr($0, index($0, $3));

            printf "%s  // [%08x]: %s\n", code, strtonum("0x" addr), asm;
            next
        }

        /^$/ {
            # 空行
            print "";
            next
        }

        {
            # 其他所有行作为注释
            print "// " $0;
            next
        }
    ' $in_file > $out_file
}

asm_to_readmemh_file program.dis program.hex

# 清理临时文件
rm -f program.o

echo "编译完成，生成 program.hex 文件"