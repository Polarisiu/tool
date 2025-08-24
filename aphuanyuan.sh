#!/bin/sh
set -e

# ================== 颜色 ==================
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

info() { echo -e "${GREEN}[INFO] $1${RESET}"; }
warn() { echo -e "${YELLOW}[WARN] $1${RESET}"; }
error() { echo -e "${RED}[ERROR] $1${RESET}"; }

# ================== 检测 Alpine ==================
if [ ! -f /etc/alpine-release ]; then
    error "该脚本仅适用于 Alpine Linux"
    exit 1
fi

ALPINE_VERSION=$(cut -d. -f1-2 /etc/alpine-release)

# ================== 定义源 ==================
OFFICIAL_MAIN="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main"
OFFICIAL_COMMUNITY="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/community"

ALIYUN_MAIN="https://mirrors.aliyun.com/alpine/v${ALPINE_VERSION}/main"
ALIYUN_COMMUNITY="https://mirrors.aliyun.com/alpine/v${ALPINE_VERSION}/community"

REPO_FILE="/etc/apk/repositories"

# ================== 备份源 ==================
backup_repo() {
    if [ -f "$REPO_FILE" ]; then
        cp "$REPO_FILE" "${REPO_FILE}.bak"
        info "已备份当前源到 ${REPO_FILE}.bak"
    fi
}

restore_repo() {
    if [ -f "${REPO_FILE}.bak" ]; then
        cp "${REPO_FILE}.bak" "$REPO_FILE"
        info "已还原备份源"
    else
        warn "没有备份源，无法还原"
    fi
}

# ================== 切换源 ==================
switch_source() {
    local main="$1"
    local community="$2"
    cat > "$REPO_FILE" <<EOF
$main
$community
EOF
    info "已切换源为 $main / $community"
}

update_cache() {
    info "正在更新 apk 缓存..."
    apk update
    info "更新完成"
}

# ================== 主菜单 ==================
while true; do
    clear
    echo -e "${GREEN}==============================${RESET}"
    echo -e "${GREEN} Alpine Linux 更新源切换菜单 ${RESET}"
    echo -e "=============================="
    echo -e "${GREEN}1) 切换到阿里云源并更新缓存${RESET}"
    echo -e "${GREEN}2) 切换到官方源并更新缓存${RESET}"
    echo -e "${GREEN}3) 备份当前源${RESET}"
    echo -e "${GREEN}4) 还原备份源并更新缓存${RESET}"
    echo -e "${GREEN}0) 退出${RESET}"
    echo -e "------------------------------"
    read -rp "$(echo -e ${GREEN}请选择操作: ${RESET})" choice

    case $choice in
        1)
            backup_repo
            switch_source "$ALIYUN_MAIN" "$ALIYUN_COMMUNITY"
            update_cache
            ;;
        2)
            backup_repo
            switch_source "$OFFICIAL_MAIN" "$OFFICIAL_COMMUNITY"
            update_cache
            ;;
        3)
            backup_repo
            ;;
        4)
            restore_repo
            update_cache
            ;;
        0)
            info "退出脚本..."
            break
            ;;
        *)
            warn "无效选择，请重新输入"
            ;;
    esac
    echo
    read -rp "$(echo -e ${YELLOW}按回车返回菜单...${RESET})"
done
