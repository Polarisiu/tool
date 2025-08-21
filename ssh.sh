#!/bin/bash

# 自动清理远程重复公钥 + 安装依赖 + 写入公钥 + 确认 + SSH 登录提示

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 读取用户输入
read -p "$(echo -e ${GREEN}请输入远程用户名:${NC} ) " username
read -p "$(echo -e ${GREEN}请输入远程服务器IP:${NC} ) " ip_address
read -p "$(echo -e ${GREEN}请输入SSH端口（默认22）:${NC} ) " port
port=${port:-22}

# 检查并生成本地公钥
LOCAL_KEY="$HOME/.ssh/id_rsa.pub"
if [ ! -f "$LOCAL_KEY" ]; then
    echo -e "${YELLOW}未检测到本地公钥，正在生成新的 SSH 密钥对...${NC}"
    mkdir -p ~/.ssh
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -q
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ 密钥生成失败，请检查 ssh-keygen 是否可用${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ SSH 密钥生成完成: $LOCAL_KEY${NC}"
else
    echo -e "${GREEN}✅ 已检测到本地公钥: $LOCAL_KEY${NC}"
fi

PUBKEY_CONTENT=$(cat $LOCAL_KEY)

echo -e "${YELLOW}⚠️ 第一次连接需要输入远程密码进行操作${NC}"

# 一次性 SSH 会话执行依赖安装 + 公钥清理写入
ssh -p $port $username@$ip_address "bash -s" <<EOF
# 检测系统类型
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=\$ID
else
    OS=\$(uname -s)
fi
echo "远程系统: \$OS"

# 安装依赖
install_pkg() {
    case \$OS in
        ubuntu|debian)
            apt update && apt install -y rsync openssh-client
            ;;
        centos|rhel|rocky)
            yum install -y rsync openssh-clients
            ;;
        alpine)
            apk add --no-cache rsync openssh-client
            ;;
        *)
            echo "⚠️ 未识别系统类型，依赖请手动检查"
            ;;
    esac
}
install_pkg

# 清理远程公钥目录
mkdir -p ~/.ssh
chmod 700 ~/.ssh
touch ~/.ssh/authorized_keys
cp ~/.ssh/authorized_keys ~/.ssh/authorized_keys.bak

# 去重保留原有公钥
awk '!seen[\$0]++' ~/.ssh/authorized_keys.bak > ~/.ssh/authorized_keys

# 确保本地公钥写入
grep -Fxq "$PUBKEY_CONTENT" ~/.ssh/authorized_keys || echo "$PUBKEY_CONTENT" >> ~/.ssh/authorized_keys

# 修复权限
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chown \$(whoami):\$(id -gn) ~/.ssh ~/.ssh/authorized_keys
EOF

# 再次确认本地公钥写入
if command -v ssh-copy-id >/dev/null 2>&1; then
    ssh-copy-id -i $LOCAL_KEY -p $port $username@$ip_address
else
    ssh -p $port $username@$ip_address "grep -Fxq '$PUBKEY_CONTENT' ~/.ssh/authorized_keys || echo '$PUBKEY_CONTENT' >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
fi

# 显示远程 authorized_keys
echo -e "${YELLOW}📂 远程服务器上的 authorized_keys 内容如下:${NC}"
ssh -p $port $username@$ip_address "cat ~/.ssh/authorized_keys"

# 最后提示 SSH 登录命令
echo -e "${GREEN}✅ 操作完成，已完成远程依赖安装、公钥写入及确认${NC}"
echo -e "${YELLOW}➡️ 你现在可以使用以下命令登录远程服务器:${NC}"
echo -e "ssh -p $port $username@$ip_address"
