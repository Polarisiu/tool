#!/bin/bash
set -e

GREEN="\033[32m"
RESET="\033[0m"

if [ "$EUID" -ne 0 ]; then
    echo "请用 root 运行此脚本"
    exit 1
fi

echo -e "${GREEN}=== VPS 设置中文环境 (zh_CN.UTF-8) ===${RESET}"

# 更新系统包索引
apt-get update -y

# 安装必要包
apt-get install -y locales fonts-wqy-microhei fonts-wqy-zenhei

# 生成中文 locale
locale-gen zh_CN.UTF-8

# 更新系统默认语言
update-locale LANG=zh_CN.UTF-8 LC_ALL=zh_CN.UTF-8

# 确认 /etc/default/locale 内容正确
cat > /etc/default/locale <<EOF
LANG=zh_CN.UTF-8
LC_ALL=zh_CN.UTF-8
EOF

# 立即生效（当前 shell）
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8

echo -e "${GREEN}✅ 配置完成，请重新登录 VPS 或执行 'source /etc/default/locale' 查看效果！${RESET}"

# 显示当前 locale
locale
