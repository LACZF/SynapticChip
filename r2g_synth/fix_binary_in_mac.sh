#!/bin/bash

# 二进制文件修复脚本 for macOS
# 用法: ./fix_binary.sh /path/to/your/binary

if [ $# -ne 1 ]; then
    echo "用法: $0 /path/to/binary"
    exit 1
fi

BINARY_PATH="$1"

if [ ! -f "$BINARY_PATH" ]; then
    echo "错误: 文件 '$BINARY_PATH' 不存在"
    exit 1
fi

echo "正在修复二进制文件: $BINARY_PATH"

# 1. 移除隔离属性（适用于从网络下载的文件）
echo "步骤 1: 移除隔离属性..."
xattr -dr com.apple.quarantine "$BINARY_PATH" 2>/dev/null

# 2. 移除所有扩展属性
echo "步骤 2: 移除所有扩展属性..."
xattr -cr "$BINARY_PATH" 2>/dev/null

# 3. 添加执行权限
echo "步骤 3: 添加执行权限..."
chmod +x "$BINARY_PATH"

# 4. 尝试使用 ad-hoc 签名
echo "步骤 4: 尝试代码签名..."
codesign --force --deep --sign - "$BINARY_PATH" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "代码签名成功"
else
    echo "代码签名失败或未安装开发者工具，继续其他步骤..."
fi

# 5. 检查文件类型和架构
echo "步骤 5: 检查文件信息..."
file "$BINARY_PATH"

# 6. 测试运行
echo "步骤 6: 测试运行..."
if "$BINARY_PATH" --version >/dev/null 2>&1; then
    echo "测试成功！二进制文件现在应该可以正常运行。"
else
    echo "测试运行失败，但文件属性已修复。"
    echo "如果仍然被系统阻止，请尝试："
    echo "1. 系统偏好设置 -> 安全性与隐私 -> 通用 -> 允许来自 'App Store 和认可的开发者' 或 '任何来源'"
    echo "2. 或者临时禁用 SIP: 重启按 Cmd+R，终端执行 'csrutil disable'"
    echo "3. 首次运行时在终端中直接执行，然后在系统弹窗中选择允许"
fi

echo "修复完成！"