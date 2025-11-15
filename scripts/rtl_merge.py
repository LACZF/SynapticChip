#!/usr/bin/env python3
"""
Verilog/SystemVerilog文件合并工具 - 修正版
功能：
1. 将多个.v/.sv文件合并为一个
2. 删除注释
3. 宏定义指令放在最前，module内的实现保持原样放在最后
4. 解决依赖关系
"""

import re
import os
import sys
import argparse
from collections import defaultdict, deque
from typing import List, Dict, Set, Tuple

class VerilogMerger:
    def __init__(self):
        self.modules = {}  # 存储模块定义 {模块名: 完整代码}
        self.macros = []   # 存储宏定义和指令
        self.other_declarations = []  # 存储其他声明（package, parameter等）
        self.parsed_files = set()  # 已解析的文件
        self.module_dependencies = defaultdict(set)  # 模块依赖关系
        self.all_code_blocks = []  # 存储所有代码块，保持原始顺序

    def remove_comments(self, content: str) -> str:
        """移除注释，但保持字符串内容不变"""
        result = []
        i = 0
        in_string = False
        string_char = None
        content_len = len(content)

        while i < content_len:
            if not in_string:
                # 检查是否进入字符串
                if content[i] in ['"', "'"]:
                    in_string = True
                    string_char = content[i]
                    result.append(content[i])
                    i += 1
                    continue

                # 检查单行注释
                if i + 1 < content_len and content[i:i+2] == '//':
                    # 跳过直到行尾
                    while i < content_len and content[i] != '\n':
                        i += 1
                    if i < content_len and content[i] == '\n':
                        result.append('\n')
                        i += 1
                    continue

                # 检查多行注释
                if i + 1 < content_len and content[i:i+2] == '/*':
                    # 跳过直到注释结束
                    while i + 1 < content_len and content[i:i+2] != '*/':
                        i += 1
                    i += 2  # 跳过 '*/'
                    continue

            else:  # 在字符串中
                if content[i] == string_char and (i == 0 or content[i-1] != '\\'):
                    in_string = False
                    string_char = None

            # 添加非注释字符
            if i < content_len:
                result.append(content[i])
                i += 1

        return ''.join(result)

    def parse_file(self, filepath: str):
        """解析Verilog文件"""
        if filepath in self.parsed_files:
            return

        self.parsed_files.add(filepath)
        print(f"正在解析: {filepath}")

        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
        except UnicodeDecodeError:
            with open(filepath, 'r', encoding='latin-1') as f:
                content = f.read()

        # 移除注释但保持代码结构
        content = self.remove_comments(content)

        # 处理include指令
        content = self.process_includes(content, os.path.dirname(filepath))

        # 提取代码块
        self.extract_code_blocks(content, filepath)

    def process_includes(self, content: str, base_dir: str) -> str:
        """处理`include指令"""
        lines = content.split('\n')
        result_lines = []

        for line in lines:
            stripped = line.strip()
            # 匹配include指令
            if stripped.startswith('`include'):
                match = re.search(r'`include\s+["\']([^"\']+)["\']', stripped)
                if match:
                    include_file = match.group(1)
                    include_path = os.path.join(base_dir, include_file)

                    if os.path.exists(include_path):
                        print(f"  包含文件: {include_path}")
                        self.parse_file(include_path)
                        # 不将include行添加到结果中
                        continue

            result_lines.append(line)

        return '\n'.join(result_lines)

    def extract_code_blocks(self, content: str, filename: str):
        """提取代码块并分类"""
        # 使用更精确的方法分割代码块
        blocks = self.split_into_blocks(content)

        for block in blocks:
            block = block.strip()
            if not block:
                continue

            # 分类代码块
            if block.startswith('`'):
                # 宏定义和指令
                self.macros.append((block, filename))
            elif re.match(r'^\s*(package|parameter|localparam|typedef|import)\s', block, re.IGNORECASE):
                # 其他声明
                self.other_declarations.append((block, filename))
            elif re.match(r'^\s*module\s+\w', block):
                # 模块定义
                self.extract_module(block, filename)
            else:
                # 无法分类的代码，暂时放在other_declarations中
                self.other_declarations.append((block, filename))

    def split_into_blocks(self, content: str) -> List[str]:
        """将内容分割成逻辑块"""
        lines = content.split('\n')
        blocks = []
        current_block = []
        in_module = False
        brace_count = 0

        for line in lines:
            stripped = line.strip()

            if not stripped:
                if current_block and not in_module:
                    blocks.append('\n'.join(current_block))
                    current_block = []
                elif current_block:
                    current_block.append('')
                continue

            # 检查模块开始
            if re.match(r'module\s+\w', stripped) and not in_module:
                if current_block:
                    blocks.append('\n'.join(current_block))
                current_block = [line]
                in_module = True
                # 计算起始大括号
                brace_count += stripped.count('{') - stripped.count('}')
                continue

            if in_module:
                brace_count += line.count('{') - line.count('}')
                current_block.append(line)

                # 检查模块结束
                if brace_count == 0 and 'endmodule' in stripped:
                    blocks.append('\n'.join(current_block))
                    current_block = []
                    in_module = False
                    brace_count = 0
            else:
                # 非模块代码，按分号或特定指令分割
                if stripped.endswith(';') or stripped.startswith('`'):
                    if current_block:
                        current_block.append(line)
                        blocks.append('\n'.join(current_block))
                        current_block = []
                    else:
                        blocks.append(line)
                else:
                    current_block.append(line)

        # 处理最后一个块
        if current_block:
            blocks.append('\n'.join(current_block))

        return blocks

    def extract_module(self, module_text: str, filename: str):
        """提取模块定义"""
        # 找到模块名
        match = re.search(r'module\s+(\w+)', module_text)
        if not match:
            self.other_declarations.append((module_text, filename))
            return

        module_name = match.group(1)

        # 提取依赖的模块
        dependencies = self.find_module_dependencies(module_text)
        self.module_dependencies[module_name] = dependencies

        # 存储模块
        self.modules[module_name] = (module_text, filename)
        print(f"  找到模块: {module_name}")

    def find_module_dependencies(self, module_text: str) -> Set[str]:
        """查找模块依赖的其他模块"""
        dependencies = set()

        # 更精确地匹配模块实例化
        # 匹配: module_name instance_name ( ... );
        pattern = r'(\w+)\s+#?\s*\(.*?\)\s*\w+\s*\([^;]*\);'
        matches = re.findall(pattern, module_text, re.DOTALL)
        dependencies.update(matches)

        # 匹配简单的实例化: module_name instance_name ( ... );
        pattern2 = r'(\w+)\s+\w+\s*\([^;]*\);'
        matches2 = re.findall(pattern2, module_text)
        for match in matches2:
            # 排除Verilog关键字
            if match.lower() not in ['if', 'for', 'while', 'case', 'always', 'initial', 'assign', 'function', 'task']:
                dependencies.add(match)

        return dependencies

    def topological_sort_modules(self) -> List[str]:
        """对模块进行拓扑排序，确保依赖关系正确"""
        visited = set()
        result = []
        temporary_visited = set()

        def visit(module):
            if module in temporary_visited:
                print(f"警告: 检测到循环依赖，可能涉及模块: {module}")
                return
            if module in visited:
                return

            temporary_visited.add(module)

            # 先访问所有依赖
            for dependency in self.module_dependencies[module]:
                if dependency in self.modules and dependency != module:
                    visit(dependency)

            temporary_visited.remove(module)
            visited.add(module)
            result.append(module)

        # 访问所有模块
        for module in list(self.modules.keys()):
            if module not in visited:
                visit(module)

        return result

    def merge_files(self, input_files: List[str], output_file: str):
        """合并文件"""
        print("开始解析文件...")

        # 解析所有输入文件
        for filepath in input_files:
            if os.path.exists(filepath):
                self.parse_file(filepath)
            else:
                print(f"警告: 文件不存在: {filepath}")

        print("\n分析依赖关系...")

        # 对模块进行拓扑排序
        sorted_modules = self.topological_sort_modules()
        print(f"模块依赖顺序: {sorted_modules}")

        # 写入输出文件
        with open(output_file, 'w', encoding='utf-8') as f:
            # 写入文件头
            f.write("// Merged Verilog/SystemVerilog files\n")
            f.write("// Generated by Verilog Merger\n\n")

            # 写入宏定义 - 保持原始格式，每行一个
            if self.macros:
                f.write("// ========== Macro Definitions ==========\n")
                seen_macros = set()
                for macro, src_file in self.macros:
                    # 去重
                    if macro not in seen_macros:
                        f.write(macro + '\n')
                        seen_macros.add(macro)
                f.write("\n")

            # 写入其他声明
            if self.other_declarations:
                f.write("// ========== Other Declarations ==========\n")
                seen_declarations = set()
                for decl, src_file in self.other_declarations:
                    if decl not in seen_declarations:
                        f.write(decl + '\n')
                        seen_declarations.add(decl)
                f.write("\n")

            # 按依赖顺序写入模块 - 保持原始RTL结构
            if sorted_modules:
                f.write("// ========== Module Definitions ==========\n\n")
                for module_name in sorted_modules:
                    module_text, src_file = self.modules[module_name]
                    f.write(f"// From: {src_file}\n")
                    f.write(module_text + '\n\n')

            print(f"合并完成! 输出文件: {output_file}")
            print(f"统计: {len(self.macros)} 个宏定义, {len(self.other_declarations)} 个其他声明, {len(self.modules)} 个模块")

def find_verilog_files(directory: str) -> List[str]:
    """查找目录中的所有Verilog文件"""
    verilog_files = []
    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith(('.v', '.sv')):
                verilog_files.append(os.path.join(root, file))
    return verilog_files

def main():
    parser = argparse.ArgumentParser(description='Verilog/SystemVerilog文件合并工具 - 修正版')
    parser.add_argument('inputs', nargs='+', help='输入文件或目录')
    parser.add_argument('-o', '--output', default='merged_output.v', help='输出文件名')

    args = parser.parse_args()

    merger = VerilogMerger()
    input_files = []

    # 处理输入参数
    for input_path in args.inputs:
        if os.path.isdir(input_path):
            input_files.extend(find_verilog_files(input_path))
        elif os.path.isfile(input_path):
            input_files.append(input_path)
        else:
            print(f"警告: 路径不存在: {input_path}")

    if not input_files:
        print("错误: 没有找到任何Verilog文件!")
        sys.exit(1)

    print(f"找到 {len(input_files)} 个文件:")
    for f in input_files:
        print(f"  {f}")

    # 合并文件
    merger.merge_files(input_files, args.output)

if __name__ == "__main__":
    main()