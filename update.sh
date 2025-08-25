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

# 检查并安装依赖
check_and_install() {
    local check_cmd="$1"
    local install_cmd="$2"
    local missing=()

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

# 清理重复 Docker 源
fix_duplicate_apt_sources() {
    echo -e "${YELLOW}🔍 正在检查重复的 Docker APT 源...${RESET}"
    local docker_sources
    docker_sources=$(grep -rl "download.docker.com" /etc/apt/sources.list.d/ 2>/dev/null || true)

    if [ "$(echo "$docker_sources" | wc -l)" -gt 1 ]; then
        echo -e "${RED}⚠️ 检测到重复的 Docker APT 源:${RESET}"
        echo "$docker_sources"
        # 保留 docker.list，删除 archive_uri 开头的
        for f in $docker_sources; do
            if [[ "$f" == *"archive_uri"* ]]; then
                rm -f "$f"
                echo -e "${GREEN}✔ 已删除多余的源: $f${RESET}"
            fi
        done
    else
        echo -e "${GREEN}✔ 未发现重复 Docker 源${RESET}"
    fi
}

# 修复 non-free 组件和 backports
fix_sources_for_version() {
    echo -e "${YELLOW}🔍 正在检查 sources.list 兼容性...${RESET}"
    local version="$1"
    local files
    files=$(grep -rl "deb" /etc/apt/sources.list /etc/apt/sources.list.d/ 2>/dev/null || true)

    for f in $files; do
        # Bullseye 不加 non-free-firmware
        if [[ "$version" == "bullseye" ]]; then
            sed -i 's/non-free non-free-firmware/non-free/g' "$f"
            # 注释掉不存在的 backports
            sed -i '/bullseye-backports/s/^/##/' "$f"
        fi
        # Bookworm 保留 non-free-firmware，不修改
    done
    echo -e "${GREEN}✔ sources.list 已根据系统版本优化${RESET}"
}

# 系统更新函数
update_system() {
    echo -e "${GREEN}🔄 正在检测系统发行版并执行更新...${RESET}"

    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo -e "${YELLOW}👉 当前系统: $PRETTY_NAME${RESET}"

        case "$ID" in
            debian|ubuntu)
                fix_duplicate_apt_sources
                fix_sources_for_version "$VERSION_CODENAME"
                apt update && apt upgrade -y
                check_and_install "dpkg -s" "apt install -y"
                ;;
            fedora)
                dnf check-update || true
                dnf upgrade -y
                check_and_install "rpm -q" "dnf install -y"
                ;;
            centos|rhel)
                yum check-update || true
                yum upgrade -y
                check_and_install "rpm -q" "yum install -y"
                ;;
            alpine)
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

    echo -e "${GREEN}✅ 系统更新和依赖检测/安装完成！${RESET}"
}

# 执行
clear
update_system
echo -e "${YELLOW}👉 按回车键返回菜单...${RESET}"
read
