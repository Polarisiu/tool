#!/bin/bash

GREEN="\033[32m"
RED="\033[31m"
RESET="\033[0m"

menu() {
    clear
    echo -e "${GREEN}=== DNS 管理菜单 ===${RESET}"
    echo -e "${GREEN}1) 查看当前 DNS${RESET}"
    echo -e "${GREEN}2) 修改为 Google DNS (8.8.8.8 / 1.1.1.1)${RESET}"
    echo -e "${GREEN}3) 修改为 阿里云 DNS (223.5.5.5 / 183.60.83.19)${RESET}"
    echo -e "${GREEN}4) 自定义 DNS ${RESET}"
    echo -e "${GREEN}0) 退出${RESET}"
    read -p $'\033[32m请选择操作: \033[0m' choice
    case $choice in
        1)
            echo -e "${GREEN}当前 DNS 配置:${RESET}"
            cat /etc/resolv.conf
            pause
            ;;
        2)
            echo -e "${GREEN}正在修改为 Google DNS...${RESET}"
            sudo bash -c 'echo -e "nameserver 8.8.8.8\nnameserver 1.1.1.1" > /etc/resolv.conf'
            echo -e "${GREEN}修改完成！${RESET}"
            pause
            ;;
        3)
            echo -e "${GREEN}正在修改为 阿里云 DNS...${RESET}"
            sudo bash -c 'echo -e "nameserver 223.5.5.5\nnameserver 183.60.83.19" > /etc/resolv.conf'
            echo -e "${GREEN}修改完成！${RESET}"
            pause
            ;;
        4)
            echo -e "${GREEN}正在运行自定义 DNS 设置...${RESET}"
            bash <(curl -fsSL https://raw.githubusercontent.com/Polarisiu/tool/main/permanentdns.sh)
            pause
            ;;
        0)
            exit 0
            ;;
        *)
            echo -e "${RED}无效选择，请重新输入${RESET}"
            sleep 1
            menu
            ;;
    esac
}

pause() {
    read -p $'\033[32m按回车键返回菜单...\033[0m'
    menu
}

menu
