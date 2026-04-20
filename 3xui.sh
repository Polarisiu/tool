#!/bin/bash

# 颜色定义
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
RESET="\033[0m"

echo -e "${GREEN}正在检测系统环境...${RESET}"

# 获取操作系统 ID
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    OS="unknown"
fi

# 安装逻辑判断
case "$OS" in
    alpine)
        echo -e "${YELLOW}检测到系统为 Alpine Linux，正在使用 Alpine 专用安装脚本...${RESET}"
        # 执行 Alpine 适配版脚本
        bash <(curl -sL https://raw.githubusercontent.com/Polarisiu/tool/main/3xuiAlpine.sh)
        ;;
    debian|ubuntu|centos|rocky|almalinux|fedora)
        echo -e "${GREEN}检测到系统为 $OS，正在使用原版 3X-UI 安装脚本...${RESET}"
        # 执行原版脚本
        bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
        ;;
    *)
        echo -e "${RED}❌ 错误: 未能识别或暂不支持您的系统 ($OS)。${RESET}"
        echo -e "${YELLOW}尝试默认运行原版脚本...${RESET}"
        bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
        ;;
esac
