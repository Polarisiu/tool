#!/bin/sh
set -e

# ================== 颜色 ==================
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
RESET='\033[0m'

info() { echo -e "${GREEN}[INFO] $1${RESET}"; }

# ================== 系统检测 ==================
if [ -f /etc/os-release ]; then
    . /etc/os-release
else
    echo "无法识别系统类型，退出"
    exit 1
fi

# ================== Alpine 主版本号 ==================
if [ "$ID" = "alpine" ]; then
    ALPINE_VERSION=$(cut -d. -f1-2 /etc/alpine-release)
fi

# ================== Ubuntu/Debian codename ==================
get_codename() {
    if command -v lsb_release >/dev/null 2>&1; then
        codename=$(lsb_release -cs)
    elif [ -n "$VERSION_CODENAME" ]; then
        codename=$VERSION_CODENAME
    elif [ -n "$VERSION_ID" ]; then
        case "$ID" in
            ubuntu)
                case "$VERSION_ID" in
                    "18.04") codename="bionic" ;;
                    "20.04") codename="focal" ;;
                    "22.04") codename="jammy" ;;
                    *) codename="focal" ;;
                esac
                ;;
            debian)
                case "$VERSION_ID" in
                    "10") codename="buster" ;;
                    "11") codename="bullseye" ;;
                    "12") codename="bookworm" ;;
                    *) codename="bookworm" ;;
                esac
                ;;
        esac
    else
        codename="stable"
    fi
}

get_codename

# ================== 源定义 ==================
# Ubuntu
aliyun_ubuntu_source="http://mirrors.aliyun.com/ubuntu/"
official_ubuntu_source="http://archive.ubuntu.com/ubuntu/"

# Debian
aliyun_debian_source="http://mirrors.aliyun.com/debian/"
official_debian_source="http://deb.debian.org/debian/"
aliyun_debian_security="http://mirrors.aliyun.com/debian-security"
official_debian_security="http://security.debian.org/debian-security"

# CentOS
aliyun_centos_source="http://mirrors.aliyun.com/centos/"
official_centos_source="http://mirror.centos.org/centos/"

# Alpine
aliyun_alpine_main="https://mirrors.aliyun.com/alpine/v${ALPINE_VERSION}/main"
aliyun_alpine_community="https://mirrors.aliyun.com/alpine/v${ALPINE_VERSION}/community"
official_alpine_main="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main"
official_alpine_community="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/community"

# ================== Debian 切换源 ==================
switch_debian_source() {
    local mirror="$1"
    local security="$2"
    cat >/etc/apt/sources.list <<EOF
# 主仓库
deb ${mirror} ${codename} main contrib non-free
# 更新仓库
deb ${mirror} ${codename}-updates main contrib non-free
# Backports
deb ${mirror} ${codename}-backports main contrib non-free
# 安全更新
deb ${security} ${codename}-security main contrib non-free
EOF
    info "已切换 Debian 源为 $mirror"
}

# ================== Ubuntu/CentOS/Alpine 切换函数保持原样 ==================
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
    local main="$1"
    local community="$2"
    cat >/etc/apk/repositories <<EOF
$main
$community
EOF
}

# ================== 缓存更新函数 ==================
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
            case "$ID" in
                debian) switch_debian_source "$aliyun_debian_source" "$aliyun_debian_security" ;;
                ubuntu) switch_apt_source "$aliyun_ubuntu_source" "$codename" ;;
                centos) switch_yum_source "$aliyun_centos_source" ;;
                alpine) switch_apk_source "$aliyun_alpine_main" "$aliyun_alpine_community" ;;
            esac
            update_cache
            ;;
        2)
            case "$ID" in
                debian) switch_debian_source "$official_debian_source" "$official_debian_security" ;;
                ubuntu) switch_apt_source "$official_ubuntu_source" "$codename" ;;
                centos) switch_yum_source "$official_centos_source" ;;
                alpine) switch_apk_source "$official_alpine_main" "$official_alpine_community" ;;
            esac
            update_cache
            ;;
        3)
            case "$ID" in
                debian|ubuntu) cp /etc/apt/sources.list /etc/apt/sources.list.bak ;;
                centos) cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak ;;
                alpine) cp /etc/apk/repositories /etc/apk/repositories.bak ;;
            esac
            info "已备份当前源"
            ;;
        4)
            case "$ID" in
                debian|ubuntu)
                    [ -f /etc/apt/sources.list.bak ] && cp /etc/apt/sources.list.bak /etc/apt/sources.list
                    ;;
                centos)
                    [ -f /etc/yum.repos.d/CentOS-Base.repo.bak ] && cp /etc/yum.repos.d/CentOS-Base.repo.bak /etc/yum.repos.d/CentOS-Base.repo
                    ;;
                alpine)
                    [ -f /etc/apk/repositories.bak ] && cp /etc/apk/repositories.bak /etc/apk/repositories
                    ;;
            esac
            update_cache
            ;;
        0) break ;;
        *) info "无效选择" ;;
    esac
done
