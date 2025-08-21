#!/bin/bash
# ==========================================
# 一键开放 VPS 所有端口
# ⚠️ 警告：非常不安全，仅用于测试环境
# ==========================================

# 颜色
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

echo -e "${YELLOW}检测防火墙类型...${RESET}"

# 检测 ufw 是否存在
if command -v ufw >/dev/null 2>&1; then
    echo -e "${GREEN}检测到 ufw，开始配置...${RESET}"
    sudo ufw --force reset
    sudo ufw default allow incoming
    sudo ufw default allow outgoing
    sudo ufw enable
    echo -e "${GREEN}所有端口已开放（ufw）${RESET}"
# 检测 iptables 是否存在
elif command -v iptables >/dev/null 2>&1; then
    echo -e "${GREEN}检测到 iptables，开始配置...${RESET}"
    sudo iptables -F
    sudo iptables -X
    sudo iptables -t nat -F
    sudo iptables -t nat -X
    sudo iptables -t mangle -F
    sudo iptables -t mangle -X
    sudo iptables -P INPUT ACCEPT
    sudo iptables -P OUTPUT ACCEPT
    sudo iptables -P FORWARD ACCEPT
    echo -e "${GREEN}所有端口已开放（iptables）${RESET}"
else
    echo -e "${RED}未检测到 ufw 或 iptables，请先安装防火墙工具${RESET}"
    exit 1
fi

echo -e "${YELLOW}请注意：VPS 所有端口已开放，存在安全风险${RESET}"
