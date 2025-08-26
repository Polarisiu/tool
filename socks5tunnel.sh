#!/bin/bash
set -e

# 颜色
GREEN="\033[32m"
RESET="\033[0m"

# 基本路径
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/tun2socks"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
SERVICE_FILE="/etc/systemd/system/tun2socks.service"
BINARY_PATH="$INSTALL_DIR/tun2socks"
REPO="heiher/hev-socks5-tunnel"

# 检查 root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${GREEN}请使用 root 权限运行此脚本，例如: sudo $0${RESET}"
        exit 1
    fi
}

# 生成配置文件（只需输入 4 个变量，其它默认）
generate_config() {
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" <<EOF
tun:
  name: tun0
  mtu: 1500
  address: 10.0.0.2/24
  gateway: 10.0.0.1
  dns: [8.8.8.8, 1.1.1.1]

proxy:
  type: socks5
  server: $SOCKS_ADDR
  port: $SOCKS_PORT
  username: $SOCKS_USER
  password: $SOCKS_PASS
EOF
}

# 下载二进制
download_binary() {
    echo -e "${GREEN}正在下载最新二进制文件...${RESET}"
    DOWNLOAD_URL=$(curl -s https://api.github.com/repos/$REPO/releases/latest \
        | grep "browser_download_url" | grep "linux-x86_64" | cut -d '"' -f 4)
    if [ -z "$DOWNLOAD_URL" ]; then
        echo -e "${GREEN}未找到适用于 linux-x86_64 的下载链接。${RESET}"
        exit 1
    fi
    curl -L -o "$BINARY_PATH" "$DOWNLOAD_URL"
    chmod +x "$BINARY_PATH"
}

# 生成 systemd 服务
generate_service() {
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Tun2Socks Tunnel Service
After=network.target

[Service]
ExecStart=$BINARY_PATH -c $CONFIG_FILE
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable tun2socks.service
}

# 安装
install_tun2socks() {
    download_binary
    echo -e "${GREEN}请输入配置参数：${RESET}"
    read -p "Socks5 端口: " SOCKS_PORT
    read -p "Socks5 地址 (IPv4/IPv6): " SOCKS_ADDR
    read -p "用户名: " SOCKS_USER
    read -p "密码: " SOCKS_PASS

    generate_config
    generate_service
    systemctl restart tun2socks
    echo -e "${GREEN}✅ 安装完成，服务已启动。${RESET}"
    read -p "按回车返回菜单..."
}

# 修改配置
modify_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${GREEN}❌ 配置文件不存在，请先安装。${RESET}"
        read -p "按回车返回菜单..."
        return
    fi
    echo -e "${GREEN}请输入新的配置参数：${RESET}"
    read -p "Socks5 端口: " SOCKS_PORT
    read -p "Socks5 地址 (IPv4/IPv6): " SOCKS_ADDR
    read -p "用户名: " SOCKS_USER
    read -p "密码: " SOCKS_PASS

    generate_config
    systemctl restart tun2socks
    echo -e "${GREEN}✅ 配置已更新并重启服务。${RESET}"
    read -p "按回车返回菜单..."
}

# 卸载
uninstall_tun2socks() {
    systemctl stop tun2socks.service || true
    systemctl disable tun2socks.service || true
    rm -f "$SERVICE_FILE"
    rm -f "$BINARY_PATH"
    rm -rf "$CONFIG_DIR"
    systemctl daemon-reload
    echo -e "${GREEN}✅ 已卸载。${RESET}"
    read -p "按回车返回菜单..."
}

# 查看当前配置
view_config() {
    if [ -f "$CONFIG_FILE" ]; then
        echo -e "${GREEN}当前配置内容：${RESET}"
        cat "$CONFIG_FILE"
    else
        echo -e "${GREEN}❌ 配置文件不存在。${RESET}"
    fi
    read -p "按回车返回菜单..."
}

# 菜单
show_menu() {
    clear
    echo -e "${GREEN}========== Tun2Socks 管理菜单 ==========${RESET}"
    echo -e "${GREEN}1. 安装 / 重装${RESET}"
    echo -e "${GREEN}2. 卸载${RESET}"
    echo -e "${GREEN}3. 修改配置${RESET}"
    echo -e "${GREEN}4. 查看服务状态${RESET}"
    echo -e "${GREEN}5. 查看当前配置${RESET}"
    echo -e "${GREEN}0. 退出${RESET}"
    echo -e "${GREEN}=======================================${RESET}"
    read -p "请选择操作: " choice
    case $choice in
        1) install_tun2socks ;;
        2) uninstall_tun2socks ;;
        3) modify_config ;;
        4) systemctl status tun2socks -n 30; read -p "按回车返回菜单..." ;;
        5) view_config ;;
        0) exit 0 ;;
        *) echo -e "${GREEN}无效选择${RESET}"; sleep 1 ;;
    esac
}

check_root
while true; do
    show_menu
done
