#!/bin/sh
set -e

# ================== 颜色 ==================
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

info() { echo -e "${GREEN}[INFO] $1${RESET}"; }
warn() { echo -e "${YELLOW}[WARN] $1${RESET}"; }

# ================== 系统检测 ==================
if [ -f /etc/os-release ]; then
    . /etc/os-release
else
    echo "无法识别系统类型，退出"
    exit 1
fi

# ================== Alpine 特殊处理 ==================
ALPINE_VERSION=$(grep -Eo 'VERSION_ID="[0-9.]+"' /etc/os-release | cut -d'"' -f2)

# ================== 源定义 ==================
aliyun_ubuntu_source="http://mirrors.aliyun.com/ubuntu/"
official_ubuntu_source="http://archive.ubuntu.com/ubuntu/"

aliyun_debian_source="http://mirrors.aliyun.com/debian/"
official_debian_source="http://deb.debian.org/debian/"

aliyun_centos_source="http://mirrors.aliyun.com/centos/"
official_centos_source="http://mirror.centos.org/centos/"

aliyun_alpine_source="https://mirrors.aliyun.com/alpine/v${ALPINE_VERSION}/main"
official_alpine_source="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main"

# ================== 备份源 ==================
backup_sources() {
    case "$ID" in
        ubuntu|debian)
            cp /etc/apt/sources.list /etc/apt/sources.list.bak
            ;;
        centos)
            cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
            ;;
        alpine)
            cp /etc/apk/repositories /etc/apk/repositories.bak
            ;;
    esac
    info "已备份当前更新源"
}

# ================== 还原源 ==================
restore_sources() {
    case "$ID" in
        ubuntu|debian)
            [ -f /etc/apt/sources.list.bak ] && cp /etc/apt/sources.list.bak /etc/apt/sources.list
            ;;
        centos)
            [ -f /etc/yum.repos.d/CentOS-Base.repo.bak ] && cp /etc/yum.repos.d/CentOS-Base.repo.bak /etc/yum.repos.d/CentOS-Base.repo
            ;;
        alpine)
            [ -f /etc/apk/repositories.bak ] && cp /etc/apk/repositories.bak /etc/apk/repositories
            ;;
    esac
    info "已还原初始源"
}

# ================== 切换源 ==================
switch_apt_source() {
    local new_source="$1"
    local codename="$2"
    cat >/etc/apt/sources.list <<EOF
deb ${new_source} ${codename} main restricted universe multiverse
deb ${new_source} ${codename}-updates main restricted universe multiverse
deb ${new_source} ${codename}-backports main restricted universe multiverse
deb ${new_source} ${codename}-security main restricted universe multiverse
EOF
}

switch_yum_source() {
    local new_source="$1"
    sed -i "s|^baseurl=.*$|baseurl=$new_source|g" /etc/yum.repos.d/CentOS-Base.repo
}

switch_apk_source() {
    local new_source="$1"
    cat >/etc/apk/repositories <<EOF
${new_source}
${new_source%-main}/community
EOF
}

# ================== 更新缓存 ==================
update_cache() {
    case "$ID" in
        ubuntu|debian)
            info "正在更新 apt 缓存..."
            apt update
            ;;
        centos)
            info "正在生成 yum 缓存..."
            yum makecache
            ;;
        alpine)
            info "正在更新 apk 缓存..."
            apk update
            ;;
    esac
    info "缓存更新完成"
}

# ================== 暂停 ==================
pause() {
    read -rp "$(echo -e ${YELLOW}按回车键继续...${RESET})" temp
}

# ================== 主菜单 ==================
while true; do
    clear
    echo -e "${GREEN}==============================${RESET}"
    case "$ID" in
        ubuntu) echo "Ubuntu 更新源切换菜单" ;;
        debian) echo "Debian 更新源切换菜单" ;;
        centos) echo "CentOS 更新源切换菜单" ;;
        alpine) echo "Alpine 更新源切换菜单" ;;
    esac
    echo -e "==============================${RESET}"
    echo -e "${GREEN}1) 切换到阿里云源并更新缓存${RESET}"
    echo -e "${GREEN}2) 切换到官方源并更新缓存${RESET}"
    echo -e "${GREEN}3) 备份当前更新源${RESET}"
    echo -e "${GREEN}4) 还原初始更新源并更新缓存${RESET}"
    echo -e "${GREEN}0) 退出${RESET}"
    echo -e "------------------------------${RESET}"
    read -rp "$(echo -e ${GREEN}请选择操作: ${RESET})" choice

    case $choice in
        1)
            backup_sources
            case "$ID" in
                ubuntu) switch_apt_source "$aliyun_ubuntu_source" "$codename" ;;
                debian) switch_apt_source "$aliyun_debian_source" "$codename" ;;
                centos) switch_yum_source "$aliyun_centos_source" ;;
                alpine) switch_apk_source "$aliyun_alpine_source" ;;
            esac
            update_cache
            pause
            ;;
        2)
            backup_sources
            case "$ID" in
                ubuntu) switch_apt_source "$official_ubuntu_source" "$codename" ;;
                debian) switch_apt_source "$official_debian_source" "$codename" ;;
                centos) switch_yum_source "$official_centos_source" ;;
                alpine) switch_apk_source "$official_alpine_source" ;;
            esac
            update_cache
            pause
            ;;
        3)
            backup_sources
            pause
            ;;
        4)
            restore_sources
            update_cache
            pause
            ;;
        0)
            echo "退出脚本..."
            break
            ;;
        *)
            echo -e "${RED}无效选择，请重新输入${RESET}"
            pause
            ;;
    esac
done
