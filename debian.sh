#!/bin/bash
# ========================================
# 安全版 Debian 重装执行器
# 作者: ChatGPT
# 功能: 下载远程重装脚本，执行前安全确认
# ========================================

REINSTALL_URL="https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh"
SCRIPT_NAME="reinstall.sh"

echo "⚠️ 警告: 此操作将会完全重装系统，磁盘上所有数据将丢失！"
echo "请确保已备份重要数据！"
echo

# 用户确认
read -p "你确定要继续吗？(y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
    echo "已取消操作。"
    exit 1
fi

# 检查是否输入密码参数
read -p "请输入 root 密码 (用于重装系统): " ROOT_PASS
if [[ -z "$ROOT_PASS" ]]; then
    echo "❌ 密码不能为空，已取消操作。"
    exit 1
fi

# 检查 SSH 端口
read -p "请输入 SSH 端口 (默认 22): " SSH_PORT
SSH_PORT=${SSH_PORT:-22}

# 下载脚本
echo "🔄 下载重装脚本..."
if ! wget -q "$REINSTALL_URL" -O "$SCRIPT_NAME"; then
    echo "❌ 下载失败，请检查网络或 URL。"
    exit 1
fi

chmod +x "$SCRIPT_NAME"
echo "✅ 脚本下载完成并赋予执行权限。"

# 执行重装脚本
echo "🔧 正在执行重装脚本..."
./"$SCRIPT_NAME" debian 12 --password "$ROOT_PASS" --ssh-port "$SSH_PORT"

# 提示用户系统将重启
echo "⚠️ 系统将在完成后重启。"
read -p "按 Enter 确认重启..." dummy
reboot
