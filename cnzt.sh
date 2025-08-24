#!/bin/sh
set -e

GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

info() { echo -e "${GREEN}[INFO] $1${RESET}"; }
warn() { echo -e "${YELLOW}[WARN] $1${RESET}"; }

# 必须 root
if [ "$(id -u)" -ne 0 ]; then
    echo "请用 root 运行此脚本"
    exit 1
fi

info "检测系统类型..."
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=$ID
else
    warn "无法识别系统类型，默认 Alpine"
    OS_NAME="alpine"
fi

info "系统类型: $OS_NAME"

case "$OS_NAME" in
    debian|ubuntu)
        info "更新 apt 源并安装中文字体..."
        apt-get update -y
        apt-get install -y locales fonts-wqy-microhei fonts-wqy-zenhei

        info "生成中文 locale..."
        locale-gen zh_CN.UTF-8
        update-locale LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8

        cat > /etc/default/locale <<EOF
LANG=zh_CN.UTF-8
LC_ALL=zh_CN.UTF-8
EOF
        ;;

    alpine)
        info "更新 apk 源并安装中文字体..."
        apk update
        apk add --no-cache fontconfig ttf-dejavu ttf-wqy-microhei ttf-wqy-zenhei

        info "设置系统环境变量..."
        echo 'export LANG=zh_CN.UTF-8' >> /etc/profile
        echo 'export LANGUAGE=zh_CN:zh' >> /etc/profile
        echo 'export LC_ALL=zh_CN.UTF-8' >> /etc/profile
        . /etc/profile
        ;;

    *)
        warn "未识别的系统类型，尝试使用 Alpine 方法"
        apk update
        apk add --no-cache fontconfig ttf-dejavu ttf-wqy-microhei ttf-wqy-zenhei
        echo 'export LANG=zh_CN.UTF-8' >> /etc/profile
        echo 'export LANGUAGE=zh_CN:zh' >> /etc/profile
        echo 'export LC_ALL=zh_CN.UTF-8' >> /etc/profile
        . /etc/profile
        ;;
esac

# 安装一些常用工具
case "$OS_NAME" in
    debian|ubuntu)
        apt-get install -y vim less htop
        ;;
    alpine)
        apk add --no-cache vim less htop
        ;;
esac

info "中文环境配置完成，请重新登录 VPS 查看效果！"
locale
echo "中文测试成功！"
