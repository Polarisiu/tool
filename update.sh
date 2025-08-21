#!/bin/bash

# ==========================================
# 系统更新 & 常用依赖安装脚本 (智能检测版)
# ==========================================

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

# 检查是否为 root 用户
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}❌ 请使用 root 用户运行此脚本${RESET}"
    exit 1
fi

# 常用依赖 (包含 sudo)
deps=(curl wget git net-tools lsof tar unzip rsync pv sudo)
missing=()

# 通用依赖检测函数
check_and_install() {
    local check_cmd="$1"
    local install_cmd="$2"

    for pkg in "${deps[@]}"; do
        if ! eval "$check_cmd \"$pkg\"" &>/dev/null; then
            missing+=("$pkg")
        else
            echo -e "${GREEN}✔ 已安装: $pkg${RESET}"
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${YELLOW}👉 开始安装缺失依赖: ${missing[*]}${RESET}"
        eval "$install_cmd \"\${missing[@]}\""
    fi
}

update_system() {
    echo -e "${GREEN}🔄 正在检测系统发行版并执行更新...${RESET}"

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            debian|ubuntu)
                echo -e "${YELLOW}👉 检测到 Debian/Ubuntu 系列${RESET}"
                apt update && apt upgrade -y
                check_and_install "dpkg -s" "apt install -y"
                ;;
            fedora)
                echo -e "${YELLOW}👉 检测到 Fedora${RESET}"
                dnf check-update || true
                dnf upgrade -y
                check_and_install "rpm -q" "dnf install -y"
                ;;
            centos|rhel)
                echo -e "${YELLOW}👉 检测到 CentOS/RHEL${RESET}"
                yum check-update || true
                yum upgrade -y
                check_and_install "rpm -q" "yum install -y"
                ;;
            alpine)
                echo -e "${YELLOW}👉 检测到 Alpine Linux${RESET}"
                apk update && apk upgrade
                check_and_install "apk info -e" "apk add"
                ;;
            *)
                echo -e "${RED}❌ 暂不支持的 Linux 发行版: $ID${RESET}"
                return 1
                ;;
        esac
    else
        echo -e "${RED}❌ 无法检测系统发行版 (/etc/os-release 不存在)${RESET}"
        return 1
    fi

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ 系统更新和依赖检测/安装完成！${RESET}"
    else
        echo -e "${RED}⚠️ 系统更新或依赖安装失败，请检查网络或源配置！${RESET}"
        return 1
    fi
}

# 执行
clear
update_system
echo -e "${YELLOW}👉 按回车键返回菜单...${RESET}"
read
