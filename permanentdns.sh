#!/bin/bash
# 永久修改 systemd-resolved DNS 脚本

GREEN="\033[32m"
RED="\033[31m"
RESET="\033[0m"

CONFIG_DIR="/etc/systemd/resolved.conf.d"
CONFIG_FILE="$CONFIG_DIR/custom_dns.conf"

echo -e "${GREEN}=== 永久修改 DNS 配置 ===${RESET}"

# 输入主 DNS
read -p $'\033[32m请输入主 DNS (例如 223.5.5.5): \033[0m' MAIN_DNS
# 输入备用 DNS
read -p $'\033[32m请输入备用 DNS (可留空，多个用空格，例如 183.60.83.19 1.1.1.1): \033[0m' BACKUP_DNS

# 校验输入
if [[ -z "$MAIN_DNS" ]]; then
    echo -e "${RED}错误: 主 DNS 不能为空！${RESET}"
    exit 1
fi

# 确认提示
echo -e "${GREEN}即将应用以下配置：${RESET}"
echo -e "${GREEN}DNS=$MAIN_DNS${RESET}"
echo -e "${GREEN}FallbackDNS=$BACKUP_DNS${RESET}"
read -p $'\033[32m确认继续? (y/n): \033[0m' CONFIRM
[[ "$CONFIRM" != "y" ]] && echo -e "${RED}已取消${RESET}" && exit 0

# 创建目录
sudo mkdir -p "$CONFIG_DIR"

# 写入配置
sudo bash -c "cat > $CONFIG_FILE <<EOF
[Resolve]
DNS=$MAIN_DNS
FallbackDNS=$BACKUP_DNS
EOF"

# 确保 systemd-resolved 正在运行
if ! systemctl is-active --quiet systemd-resolved; then
    echo -e "${RED}systemd-resolved 未运行，正在启动...${RESET}"
    sudo systemctl enable --now systemd-resolved
fi

# 重启服务
sudo systemctl restart systemd-resolved

# 显示结果
echo -e "${GREEN}已应用新的 DNS 配置！${RESET}"
echo -e "${GREEN}当前 DNS 状态：${RESET}"
resolvectl status | grep -E 'DNS Servers|Fallback DNS Servers'
