#!/bin/bash

# ==========================================
# 系统快照 & 备份管理菜单（全绿字体）
# ==========================================

GREEN='\033[0;32m'
NC='\033[0m'

while true; do
    clear
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}         系统快照 & 备份管理菜单        ${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}1) SSH密钥自动配置${NC}"
    echo -e "${GREEN}2) Rclone备份${NC}"
    echo -e "${GREEN}3) 安装快照备份${NC}"
    echo -e "${GREEN}4) 本地系统快照恢复${NC}"
    echo -e "${GREEN}5) 远程系统快照恢复${NC}"
    echo -e "${GREEN}6) 卸载快照备份${NC}"
    echo -e "${GREEN}0) 退出菜单${NC}"
    read -p "$(echo -e ${GREEN}请选择操作: ${NC})" choice

    case $choice in
        1)
            echo -e "${GREEN}执行 SSH密钥自动配置...${NC}"
            bash <(curl -fsSL https://raw.githubusercontent.com/Polarisiu/tool/main/ssh.sh)
            read -p "$(echo -e ${GREEN}按回车继续...${NC})"
            ;;
        2)
            echo -e "${GREEN}执行 Rclone备份...${NC}"
            bash <(curl -fsSL https://raw.githubusercontent.com/Polarisiu/tool/main/rclone.sh)
            read -p "$(echo -e ${GREEN}按回车继续...${NC})"
            ;;
        3)
            echo -e "${GREEN}安装快照备份...${NC}"
            bash <(curl -fsSL https://raw.githubusercontent.com/Polarisiu/tool/main/system_snapshot.sh)
            read -p "$(echo -e ${GREEN}按回车继续...${NC})"
            ;;
        4)
            echo -e "${GREEN}本地系统快照恢复...${NC}"
            bash <(curl -fsSL https://raw.githubusercontent.com/Polarisiu/tool/main/local_restore.sh)
            read -p "$(echo -e ${GREEN}按回车继续...${NC})"
            ;;
        5)
            echo -e "${GREEN}远程系统快照恢复...${NC}"
            bash <(curl -fsSL https://raw.githubusercontent.com/Polarisiu/tool/main/remote.sh)
            read -p "$(echo -e ${GREEN}按回车继续...${NC})"
            ;;
        6)
            echo -e "${GREEN}卸载快照备份...${NC}"
            bash <(curl -fsSL https://raw.githubusercontent.com/Polarisiu/tool/main/uninstall_snapshot.sh)
            read -p "$(echo -e ${GREEN}按回车继续...${NC})"
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${GREEN}无效选项，请重新输入${NC}"
            read -p "$(echo -e ${GREEN}按回车继续...${NC})"
            ;;
    esac
done
