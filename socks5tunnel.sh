#!/bin/bash
set -e

#==================== 颜色 ====================
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

#==================== 常量 ====================
CONFIG_DIR="/etc/tun2socks"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
SERVICE_FILE="/etc/systemd/system/tun2socks.service"
BINARY_PATH="/usr/local/bin/tun2socks"

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }

require_root() {
    if [ "$EUID" -ne 0 ]; then
        error "请使用 root 权限运行脚本"
        exit 1
    fi
}

cleanup_ip_rules() {
    info "清理残留路由和规则..."
    ip rule del fwmark 438 lookup main pref 10 2>/dev/null || true
    ip -6 rule del fwmark 438 lookup main pref 10 2>/dev/null || true
    ip route del default dev tun0 table 20 2>/dev/null || true
    ip rule del lookup 20 pref 20 2>/dev/null || true
    ip rule del to 127.0.0.0/8 lookup main pref 16 2>/dev/null || true
    ip rule del to 10.0.0.0/8 lookup main pref 16 2>/dev/null || true
    ip rule del to 172.16.0.0/12 lookup main pref 16 2>/dev/null || true
    ip rule del to 192.168.0.0/16 lookup main pref 16 2>/dev/null || true
    while ip rule del pref 15 2>/dev/null; do :; done
    info "清理完成"
}

select_alice_port() {
    options=("新加坡机房IP:10001" "台湾家宽:30000" "日本家宽:50000")
    echo
    info "请选择 Alice 模式 Socks5 出口端口:"
    for i in "${!options[@]}"; do
        port="${options[$i]#*:}"
        echo -e "  $((i+1))) ${options[$i]%%:*} (端口: $port)"
    done
    while true; do
        read -p "输入选项 (默认 1): " choice
        choice=${choice:-1}
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#options[@]} ]; then
            echo "${options[$((choice-1))]#*:}"
            return
        else
            error "无效选择，请重新输入"
        fi
    done
}

install_or_update() {
    require_root
    cleanup_ip_rules
    mkdir -p "$CONFIG_DIR"

    read -p "请选择模式 (alice / custom) 默认 alice: " MODE
    MODE=${MODE:-alice}

    if [ "$MODE" = "alice" ]; then
        SOCKS_PORT=$(select_alice_port)
        SOCKS_ADDR="2a14:67c0:116::1"
        SOCKS_USER="alice"
        SOCKS_PASS="alicefofo123..OVO"
    elif [ "$MODE" = "custom" ]; then
        read -p "Socks5 地址: " SOCKS_ADDR
        read -p "Socks5 端口: " SOCKS_PORT
        read -p "用户名 (可选): " SOCKS_USER
        read -p "密码 (可选): " SOCKS_PASS
    else
        error "无效模式"
        return
    fi

    # 写 config.yaml
    cat > "$CONFIG_FILE" <<EOF
tunnel:
  name: tun0
  mtu: 8500
  multi-queue: true
  ipv4: 198.18.0.1

socks5:
  port: $SOCKS_PORT
  address: '$SOCKS_ADDR'
  udp: 'udp'
EOF
    [ -n "$SOCKS_USER" ] && echo "  username: '$SOCKS_USER'" >> "$CONFIG_FILE"
    [ -n "$SOCKS_PASS" ] && echo "  password: '$SOCKS_PASS'" >> "$CONFIG_FILE"
    echo "  mark: 438" >> "$CONFIG_FILE"

    # 下载二进制
    info "下载 tun2socks..."
    curl -L -o "$BINARY_PATH" "https://github.com/heiher/hev-socks5-tunnel/releases/latest/download/tun2socks-linux-x86_64"
    chmod +x "$BINARY_PATH"

    # systemd
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Tun2Socks Tunnel Service
After=network.target

[Service]
Type=simple
ExecStart=$BINARY_PATH $CONFIG_FILE
ExecStartPost=/bin/sleep 1
ExecStartPost=/sbin/ip rule add fwmark 438 lookup main pref 10
ExecStartPost=/sbin/ip -6 rule add fwmark 438 lookup main pref 10
ExecStartPost=/sbin/ip route add default dev tun0 table 20
ExecStartPost=/sbin/ip rule add lookup 20 pref 20
ExecStartPost=/sbin/ip rule add to 127.0.0.0/8 lookup main pref 16
ExecStartPost=/sbin/ip rule add to 10.0.0.0/8 lookup main pref 16
ExecStartPost=/sbin/ip rule add to 172.16.0.0/12 lookup main pref 16
ExecStartPost=/sbin/ip rule add to 192.168.0.0/16 lookup main pref 16
ExecStop=/sbin/ip rule del fwmark 438 lookup main pref 10
ExecStop=/sbin/ip -6 rule del fwmark 438 lookup main pref 10
ExecStop=/sbin/ip route del default dev tun0 table 20
ExecStop=/sbin/ip rule del lookup 20 pref 20
ExecStop=/sbin/ip rule del to 127.0.0.0/8 lookup main pref 16
ExecStop=/sbin/ip rule del to 10.0.0.0/8 lookup main pref 16
ExecStop=/sbin/ip rule del to 172.16.0.0/12 lookup main pref 16
ExecStop=/sbin/ip rule del to 192.168.0.0/16 lookup main pref 16
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable tun2socks.service
    systemctl restart tun2socks.service

    info "安装完成"
}

menu() {
    require_root
    while true; do
        echo -e "\n${GREEN}===== tun2socks 管理菜单 =====${NC}"
        echo -e "${GREEN}1) 安装/重装 tun2socks${NC}"
        echo -e "${GREEN}2) 修改配置${NC}"
        echo -e "${GREEN}3) 启动服务${NC}"
        echo -e "${GREEN}4) 停止服务${NC}"
        echo -e "${GREEN}5) 重启服务${NC}"
        echo -e "${GREEN}6) 查看状态${NC}"
        echo -e "${GREEN}7) 查看日志${NC}"
        echo -e "${GREEN}8) 卸载服务${NC}"
        echo -e "${GREEN}0) 退出${NC}"
        read -p "请输入选项: " choice
        case $choice in
            1) install_or_update ;;
            2) install_or_update ;;
            3) systemctl start tun2socks.service ;;
            4) systemctl stop tun2socks.service ;;
            5) systemctl restart tun2socks.service ;;
            6) systemctl status tun2socks.service -n 30 ;;
            7) journalctl -u tun2socks.service -f ;;
            8) uninstall ;;
            0) exit 0 ;;
            *) echo -e "${RED}无效选项${NC}" ;;
        esac
    done
}

menu
