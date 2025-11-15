#!/bin/bash

TOP_DIR="$(dirname $(readlink -f $0))"

if [ -z "$RISCV_PREFIX" ]; then
    if [ "$(uname)" == "Linux" ]; then
        RISCV_PREFIX=riscv64-linux-gnu-
    elif [ "$(uname)" == "Darwin" ]; then
        RISCV_PREFIX=riscv64-elf-
    else
        RISCV_PREFIX=riscv64-unknown-elf-
    fi
fi

function compile_asm() {
    local asm_file=$1
    local elf_file=$2
    local cflags="-march=rv64im -mabi=lp64 -static -mcmodel=medany -nostartfiles -nostdlib"

    cflags="-march=rv64im_zicsr"
    ${RISCV_PREFIX}as $cflags -o ${asm_file%.s}.o ${asm_file}
    ${RISCV_PREFIX}ld -T ${TOP_DIR}/script.ld -o ${elf_file} ${asm_file%.s}.o
}

function disassemble() {
    local elf_file=$1
    local dis_file=$2

    # 仅反汇编.text.vector段（代码段）
    ${RISCV_PREFIX}objdump -D -j .text.vector $elf_file > $dis_file
}

function clean_compile_gen_files() {
    local asm_file=$1
    local elf_file=$2
    local dis_file=$3

    rm -f ${asm_file%.s}.o ${elf_file} ${dis_file}
}

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

function build_program() {
    local asm_file=$1
    local elf_file=$2
    local dis_file=$3
    local hex_file=$4

    compile_asm $asm_file $elf_file
    disassemble $elf_file $dis_file
    asm_to_readmemh_file $dis_file $hex_file
}

function extract_data_bss() {
    local elf_file=$1
    local hex_file=$2

    # 使用objcopy提取.data和.bss段到二进制文件
    ${RISCV_PREFIX}objcopy -O binary -j .data -j .bss $elf_file temp_data_bss.bin

    # 将二进制文件转换为hex格式（每行32位）
    # hexdump -v -e '4/1 "%02x" "\n"' temp_data_bss.bin > $hex_file
    hexdump -v -e '1/4 "%08x\n"' temp_data_bss.bin > $hex_file

    # 清理临时文件
    rm -f temp_data_bss.bin

    # echo "提取完成：$hex_file"
    # echo "数据大小：$(wc -l < $hex_file) 个32位字"
}

build_program program.s program.elf program.dis program.hex
extract_data_bss program.elf data_bss.hex
