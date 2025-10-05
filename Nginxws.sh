#!/bin/bash

GREEN="\033[32m"
RED="\033[31m"
RESET="\033[0m"

menu() {
    clear
    echo -e "${GREEN}=== NGINX 反代管理菜单 ===${RESET}"
    echo -e "${GREEN}1) NGINX 反代 (V4)${RESET}"
    echo -e "${GREEN}2) NGINX 反代 (V6)${RESET}"
    echo -e "${GREEN}0) 退出${RESET}"
    read -p $'\033[32m请选择操作: \033[0m' choice
    case $choice in
        1)
            bash <(curl -sL https://raw.githubusercontent.com/Polarisiu/tool/main/ngixv4.sh)
            pause
            ;;
        2)
            bash <(curl -sL https://raw.githubusercontent.com/Polarisiu/tool/main/ngixv6.sh)
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
