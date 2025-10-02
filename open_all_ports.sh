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

# --------------------------
# 自动安装函数
# --------------------------
install_package() {
    local pkg="$1"
    if [[ -f /etc/alpine-release ]]; then
        echo -e "${YELLOW}检测到 Alpine，尝试安装 $pkg ...${RESET}"
        apk update
        apk add "$pkg"
    elif [[ -f /etc/debian_version ]]; then
        echo -e "${YELLOW}检测到 Debian/Ubuntu，尝试安装 $pkg ...${RESET}"
        apt-get update
        apt-get install -y "$pkg"
    elif [[ -f /etc/redhat-release ]]; then
        echo -e "${YELLOW}检测到 CentOS/RHEL，尝试安装 $pkg ...${RESET}"
        yum install -y "$pkg"
    else
        echo -e "${RED}❌ 未知系统，请手动安装 $pkg${RESET}"
        exit 1
    fi
}

# --------------------------
# 检测防火墙
# --------------------------
if command -v ufw >/dev/null 2>&1; then
    FW_TYPE="ufw"
elif command -v iptables >/dev/null 2>&1; then
    FW_TYPE="iptables"
elif command -v nft >/dev/null 2>&1; then
    FW_TYPE="nftables"
else
    # 自动安装
    if [[ -f /etc/alpine-release ]]; then
        install_package nftables
        FW_TYPE="nftables"
        rc-update add nftables
        service nftables start
    elif [[ -f /etc/debian_version ]]; then
        install_package ufw
        FW_TYPE="ufw"
    elif [[ -f /etc/redhat-release ]]; then
        install_package iptables
        FW_TYPE="iptables"
    else
        echo -e "${RED}❌ 未知系统，无法安装防火墙${RESET}"
        exit 1
    fi
fi

# --------------------------
# 开放所有端口
# --------------------------
echo -e "${GREEN}检测到防火墙: $FW_TYPE，开始配置...${RESET}"

if [[ "$FW_TYPE" == "ufw" ]]; then
    ufw --force reset
    ufw default allow incoming
    ufw default allow outgoing
    ufw enable
    echo -e "${GREEN}所有端口已开放（ufw）${RESET}"

elif [[ "$FW_TYPE" == "iptables" ]]; then
    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t mangle -F
    iptables -t mangle -X
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P FORWARD ACCEPT
    echo -e "${GREEN}所有端口已开放（iptables）${RESET}"

elif [[ "$FW_TYPE" == "nftables" ]]; then
    nft flush ruleset
    nft add table inet filter
    nft add chain inet filter input { type filter hook input priority 0 \; policy accept \; }
    nft add chain inet filter forward { type filter hook forward priority 0 \; policy accept \; }
    nft add chain inet filter output { type filter hook output priority 0 \; policy accept \; }
    echo -e "${GREEN}所有端口已开放（nftables）${RESET}"
fi

echo -e "${YELLOW}请注意：VPS 所有端口已开放，存在安全风险${RESET}"
