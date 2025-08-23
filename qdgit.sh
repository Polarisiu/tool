#!/bin/bash
# VPS <-> GitHub 工具安装/更新/启动脚本

BASE_DIR="/root/ghupload"
SCRIPT_URL="https://raw.githubusercontent.com/Polarisiu/tool/main/ghupload.sh"
SCRIPT_PATH="$BASE_DIR/gh_tool.sh"
BIN_LINK_DIR="/usr/local/bin"

# 创建目录
mkdir -p "$BASE_DIR"

# 检查已有安装
if [ -f "$SCRIPT_PATH" ]; then
    echo "ℹ️ 检测到已有安装，正在更新..."
else
    echo "ℹ️ 正在安装 VPS <-> GitHub 工具..."
fi

# 下载最新脚本
curl -fsSL "$SCRIPT_URL" -o "$SCRIPT_PATH"
if [ $? -ne 0 ]; then
    echo "❌ 下载失败，请检查网络或 URL"
    exit 1
fi

# 赋予执行权限
chmod +x "$SCRIPT_PATH"

# 创建或更新快捷命令 s 和 S
ln -sf "$SCRIPT_PATH" "$BIN_LINK_DIR/s"
ln -sf "$SCRIPT_PATH" "$BIN_LINK_DIR/S"

GREEN="\033[32m"
RED="\033[31m"
RESET="\033[0m"

echo -e "${GREEN}✅ 安装/更新完成！${RESET}"
echo -e "你可以使用 '${RED}s${RESET}' 或 '${RED}S${RESET}' 命令来启动 VPS <-> GitHub 工具"

# 直接打开菜单
"$SCRIPT_PATH"
