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

function update_bootrom() {
    local hex_file=$1
    local bootrom_file="$TOP_DIR/../../../rtl/boot_rom/bootrom_top.v"

    if [ ! -f "$hex_file" ]; then
        echo "Error: Hex file $hex_file not found"
        return 1
    fi

    if [ ! -f "$bootrom_file" ]; then
        echo "Error: BootROM file $bootrom_file not found"
        return 1
    fi

    # 计算hex文件中的指令数量
    local rom_size=$(grep -c '^[0-9a-fA-F]' "$hex_file")

    if [ "$rom_size" -eq 0 ]; then
        echo "Error: No valid instructions found in $hex_file"
        return 1
    fi

    echo "Updating BootROM with $rom_size instructions..."

    # 创建临时文件
    local temp_file=$(mktemp)

    # 读取hex文件内容并格式化为Verilog数组（逆序保存）
    local mem_content=""
    local line_count=0

    # 先将所有指令读取到数组中
    local -a instructions=()
    while IFS= read -r line; do
        # 跳过空行和注释行
        if [[ "$line" =~ ^[[:space:]]*$ ]] || [[ "$line" =~ ^// ]]; then
            continue
        fi

        # 提取hex值（忽略注释部分）
        local hex_value=$(echo "$line" | awk '{print $1}')

        if [[ "$hex_value" =~ ^[0-9a-fA-F]{8}$ ]]; then
            instructions+=("$hex_value")
            ((line_count++))
        fi
    done < "$hex_file"

    # 逆序构建mem数组内容
    for ((i=${#instructions[@]}-1; i>=0; i--)); do
        if [ $i -lt $((${#instructions[@]}-1)) ]; then
            mem_content="$mem_content,\n"
        fi
        mem_content="${mem_content}        32'h${instructions[$i]}"
    done

    # 更新bootrom_top.sv文件
    awk -v rom_size="$rom_size" -v mem_content="$mem_content" '
        /localparam BOOT_ROM_DEPTH = [0-9]+;/ {
            print "    localparam BOOT_ROM_DEPTH = " rom_size ";"
            next
        }
        /assign mem = {/ {
            print "    assign mem = {"
            print mem_content
            found_mem = 1
            next
        }
        found_mem && /^[[:space:]]*};/ {
            print "    };"
            found_mem = 0
            next
        }
        found_mem {
            # 跳过mem数组的原有内容
            next
        }
        { print }
    ' "$bootrom_file" > "$temp_file"

    # 检查更新是否成功
    if grep -q "localparam BOOT_ROM_DEPTH = $rom_size;" "$temp_file" && grep -q "assign mem = {" "$temp_file"; then
        mv "$temp_file" "$bootrom_file"
        echo "BootROM updated successfully with $rom_size instructions"
    else
        rm "$temp_file"
        echo "Error: Failed to update BootROM"
        return 1
    fi
}

build_program program.s program.elf program.dis program.hex
extract_data_bss program.elf data_bss.hex

build_program uart_boot.s uart_boot.elf uart_boot.dis uart_boot.hex
update_bootrom uart_boot.hex
