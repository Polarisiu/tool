#!/bin/bash
set -e

# ================== 颜色 ==================
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

# ================== 基本路径 ==================
REPO="heiher/hev-socks5-tunnel"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/tun2socks"
SERVICE_FILE="/etc/systemd/system/tun2socks.service"
BINARY_PATH="$INSTALL_DIR/tun2socks"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
TUN_NAME="tun0"
MTU="8500"

# ================== 检查 root ==================
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}请使用 root 权限运行此脚本，例如: sudo $0${RESET}"
    exit 1
fi

# ================== 下载最新二进制 ==================
download_binary() {
    echo -e "${GREEN}获取最新版本下载链接...${RESET}"
    DOWNLOAD_URL=$(curl -s https://api.github.com/repos/$REPO/releases/latest \
        | grep "browser_download_url" | grep "linux-x86_64" | cut -d '"' -f 4)
    if [ -z "$DOWNLOAD_URL" ]; then
        echo -e "${RED}未找到适用于 linux-x86_64 的二进制文件，请检查网络。${RESET}"
        exit 1
    fi
    echo -e "${GREEN}下载最新二进制文件：${DOWNLOAD_URL}${RESET}"
    curl -L -o "$BINARY_PATH" "$DOWNLOAD_URL"
    chmod +x "$BINARY_PATH"
}

# ================== 生成配置（安装时） ==================
generate_config() {
    echo -e "${YELLOW}请输入 Socks5 配置参数${RESET}"

    # 用户输入必须填写的参数
    while true; do
        read -p "Socks5 端口: " SOCKS_PORT
        [ -n "$SOCKS_PORT" ] && break
        echo -e "${RED}端口不能为空${RESET}"
    done

    while true; do
        read -p "Socks5 地址 (IPv4/IPv6): " SOCKS_ADDR
        [ -n "$SOCKS_ADDR" ] && break
        echo -e "${RED}地址不能为空${RESET}"
    done

    while true; do
        read -p "用户名: " SOCKS_USER
        [ -n "$SOCKS_USER" ] && break
        echo -e "${RED}用户名不能为空${RESET}"
    done

    while true; do
        read -p "密码: " SOCKS_PASS
        [ -n "$SOCKS_PASS" ] && break
        echo -e "${RED}密码不能为空${RESET}"
    done

    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" <<EOF
tunnel:
  name: $TUN_NAME
  mtu: $MTU
  multi-queue: true
  ipv4: 198.18.0.1

socks5:
  port: $SOCKS_PORT
  address: '$SOCKS_ADDR'
  udp: 'udp'
  username: '$SOCKS_USER'
  password: '$SOCKS_PASS'
EOF
    chmod 600 "$CONFIG_FILE"
}

# ================== 生成 systemd 服务 ==================
generate_service() {
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Tun2Socks Tunnel Service
After=network.target

[Service]
Type=simple
ExecStart=$BINARY_PATH $CONFIG_FILE
ExecStartPost=/sbin/ip route replace default dev $TUN_NAME || true
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable tun2socks.service
}

# ================== 安装 ==================
install_tun2socks() {
    download_binary
    generate_config
    generate_service
    systemctl restart tun2socks.service
    echo -e "${GREEN}安装完成！使用 'systemctl status tun2socks.service' 查看状态。${RESET}"
}

# ================== 升级二进制（保留配置） ==================
update_tun2socks() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${RED}未找到现有配置文件，请先安装 tun2socks${RESET}"
        exit 1
    fi
    download_binary
    systemctl restart tun2socks.service
    echo -e "${GREEN}更新完成，服务已重启，配置保持不变${RESET}"
}

# ================== 卸载 ==================
uninstall_tun2socks() {
    echo -e "${YELLOW}停止服务...${RESET}"
    systemctl stop tun2socks.service || true
    systemctl disable tun2socks.service || true
    echo -e "${YELLOW}删除 systemd 服务文件...${RESET}"
    rm -f "$SERVICE_FILE"
    echo -e "${YELLOW}删除二进制文件和配置文件...${RESET}"
    rm -f "$BINARY_PATH"
    rm -rf "$CONFIG_DIR"
    systemctl daemon-reload
    echo -e "${GREEN}卸载完成！${RESET}"
}

# ================== 主菜单 ==================
echo -e "${GREEN}Tun2Socks 一键管理脚本${RESET}"
echo "1) 安装 tun2socks"
echo "2) 更新二进制（保留配置）"
echo "3) 卸载 tun2socks"
echo "4) 启动服务"
echo "5) 停止服务"
echo "6) 查看服务状态"
read -p "请选择操作 [1-6]: " choice

case $choice in
1)
    install_tun2socks
    ;;
2)
    update_tun2socks
    ;;
3)
    uninstall_tun2socks
    ;;
4)
    systemctl start tun2socks.service
    echo -e "${GREEN}服务已启动${RESET}"
    ;;
5)
    systemctl stop tun2socks.service
    echo -e "${GREEN}服务已停止${RESET}"
    ;;
6)
    systemctl status tun2socks.service
    ;;
*)
    echo -e "${RED}无效选项${RESET}"
    ;;
esac
