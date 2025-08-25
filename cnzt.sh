#!/bin/bash
set -e

GREEN="\033[32m"
RESET="\033[0m"

# 检查 root 权限
if [ "$EUID" -ne 0 ]; then
    echo "请用 root 运行此脚本"
    exit 1
fi

echo -e "${GREEN}=== VPS 设置中文环境 (zh_CN.UTF-8) ===${RESET}"

# 更新系统包索引
apt-get update -y

# 安装必要包
apt-get install -y locales fonts-wqy-microhei fonts-wqy-zenhei

# 确保 /etc/locale.gen 含有 zh_CN.UTF-8
if ! grep -q "^zh_CN.UTF-8 UTF-8" /etc/locale.gen; then
    echo "zh_CN.UTF-8 UTF-8" >> /etc/locale.gen
fi

# 生成 locale
locale-gen

# 设置系统默认语言（仅 LANG，LC_ALL 不要写入 /etc/default/locale）
update-locale LANG=zh_CN.UTF-8

# 立即生效当前 shell
export LANG=zh_CN.UTF-8
export LC_ALL=zh_CN.UTF-8

# 提示用户
echo -e "${GREEN}✅ 中文环境已配置完成${RESET}"
echo -e "${GREEN}请重新登录 VPS 或执行: source /etc/default/locale${RESET}"

# 显示当前 locale
locale
