#!/bin/bash

# 颜色定义
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
RESET="\033[0m"

echo -e "${GREEN}正在检测系统环境以适配 Emby 反代脚本...${RESET}"

# 1. 获取操作系统 ID
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    OS="unknown"
fi

# 2. 根据系统类型执行对应的脚本
case "$OS" in
    alpine)
        echo -e "${YELLOW}检测到系统为 Alpine Linux，正在调用 Alpine 专用脚本...${RESET}"
        # 确保 Alpine 环境有基础工具
        if ! command -v curl >/dev/null 2>&1 || ! command -v bash >/dev/null 2>&1; then
            echo -e "${YELLOW}正在补充基础依赖 (bash/curl)...${RESET}"
            apk add --no-cache curl bash
        fi
        bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/Alpine/EmbyAlpine.sh)
        ;;
    
    debian|ubuntu|centos|rocky|almalinux|fedora)
        echo -e "${GREEN}检测到系统为 $OS，正在调用标准版反代脚本...${RESET}"
        # 确保有 curl
        if ! command -v curl >/dev/null 2>&1; then
            if [ -f /etc/debian_version ]; then
                apt update && apt install -y curl
            else
                yum install -y curl
            fi
        fi
        bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/toy/Embyfd.sh)
        ;;

    *)
        echo -e "${RED}❌ 错误: 未能识别您的系统发行版 ($OS)。${RESET}"
        echo -e "${YELLOW}尝试运行通用版脚本...${RESET}"
        bash <(curl -sL https://raw.githubusercontent.com/sistarry/toolbox/main/toy/Embyfd.sh)
        ;;
esac