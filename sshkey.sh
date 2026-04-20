#!/bin/bash
# ==========================================
# 自动生成 Ed25519 密钥并禁止密码登录 (含 Y/N 确认)
# ==========================================

# 颜色定义
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"

# 1. 交互确认
echo -e "${RED}警告：此操作将生成 Ed25519 密钥并彻底禁用密码登录！${RESET}"
read -p "是否继续？(y/n): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}已取消操作。${RESET}"
    exit 0
fi

# 2. Root 检查
[ "$(id -u)" -ne 0 ] && echo -e "${RED}❌ 请使用 root 权限运行${RESET}" && exit 1

# 3. 系统识别
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_ID="$ID"
else
    OS_ID="unknown"
fi

SSH_DIR="$HOME/.ssh"
PRIVATE_KEY="$SSH_DIR/id_ed25519"
PUBLIC_KEY="$SSH_DIR/id_ed25519.pub"
AUTH_KEYS="$SSH_DIR/authorized_keys"

# 4. 准备工作
mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

# 5. 自动生成 Ed25519 密钥对
if [ ! -f "$PRIVATE_KEY" ]; then
    echo -e "${YELLOW}正在生成 Ed25519 密钥对...${RESET}"
    ssh-keygen -t ed25519 -f "$PRIVATE_KEY" -N ""
    echo -e "${GREEN}✔ 密钥对生成成功${RESET}"
else
    echo -e "${YELLOW}提示: 检测到已有密钥，将使用现有密钥配置${RESET}"
fi

# 6. 配置授权列表
cat "$PUBLIC_KEY" >> "$AUTH_KEYS"
chmod 600 "$AUTH_KEYS"
sort -u "$AUTH_KEYS" -o "$AUTH_KEYS"

# 7. 修改 SSH 配置文件
SSHD_CONFIG="/etc/ssh/sshd_config"
echo -e "${YELLOW}正在加固 SSH 配置 (禁用密码登录)...${RESET}"

# 备份原配置
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"

# 确保配置生效
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
sed -i 's/^#\?PermitEmptyPasswords.*/PermitEmptyPasswords no/' "$SSHD_CONFIG"
sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSHD_CONFIG"
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' "$SSHD_CONFIG"

# 8. 重启 SSH 服务 (完美适配 Alpine OpenRC / Systemd)
case "$OS_ID" in
    alpine)
        rc-service sshd restart || /etc/init.d/sshd restart
        ;;
    debian|ubuntu|centos|rhel|rocky|almalinux|fedora)
        if command -v systemctl >/dev/null 2>&1; then
            systemctl restart sshd || systemctl restart ssh
        else
            service sshd restart || service ssh restart
        fi
        ;;
    *)
        service sshd restart || /etc/init.d/sshd restart
        ;;
esac

# 9. 输出私钥
echo -e "\n${GREEN}==================================================${RESET}"
echo -e "${GREEN}✅ SSH Ed25519 密钥配置完成！${RESET}"
echo -e "${RED}⚠️  请立即复制下方私钥内容并保存到本地文件 (如 vps.key)${RESET}"
echo -e "${GREEN}==================================================${RESET}\n"

cat "$PRIVATE_KEY"

echo -e "\n${GREEN}==================================================${RESET}"
echo -e "${YELLOW}私钥路径: $PRIVATE_KEY${RESET}"
echo -e "${GREEN}==================================================${RESET}"
