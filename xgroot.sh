#!/bin/bash
clear

# 颜色
green='\033[0;32m'
red='\033[0;31m'
yellow='\033[1;33m'
re='\033[0m'

# 设置 root 密码
read -p $'\033[1;35m请设置你的root密码: \033[0m' passwd
echo "root:$passwd" | chpasswd && echo -e "${green}Root密码设置成功${re}" || { echo -e "${red}Root密码修改失败${re}"; exit 1; }

# 修改 sshd_config
sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sed -i 's|^Include /etc/ssh/sshd_config.d/\*.conf|#&|' /etc/ssh/sshd_config

# 重启 SSH 服务（兼容不同系统）
if systemctl list-unit-files | grep -q sshd.service; then
    systemctl restart sshd
elif systemctl list-unit-files | grep -q ssh.service; then
    systemctl restart ssh
else
    service ssh restart
fi

echo -e "${green}ROOT登录设置完毕，重启服务器后生效${re}"

# 是否重启
read -p $'\033[1;35m需要立即重启服务器吗？(y/n): \033[0m' choice
case "$choice" in
    [Yy]*)
        echo -e "${yellow}正在重启...${re}"
        reboot
        ;;
    [Nn]*)
        echo -e "${green}已取消重启，请手动执行 \033[1;33mreboot\033[0m${re}"
        ;;
    *)
        echo -e "${red}无效的选择，已取消重启${re}"
        ;;
esac
