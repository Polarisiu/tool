#!/bin/bash

GREEN="\033[32m"
RED="\033[31m"
RESET="\033[0m"

menu() {
    clear
    echo -e "${GREEN}=== 命令行美化工具菜单 ===${RESET}"
    echo -e "${GREEN}1) 单色美化${RESET}"
    echo -e "${GREEN}2) 彩色美化${RESET}"
    echo -e "${GREEN}0) 退出${RESET}"
    echo
    read -p $'\033[32m请选择操作 (0-2): \033[0m' choice
    case $choice in
        1)
            echo -e "${GREEN}正在运行单色美化脚本...${RESET}"
            bash <(curl -sL https://raw.githubusercontent.com/Polarisiu/tool/main/mhzt.sh)
            pause
            ;;
        2)
            echo -e "${GREEN}正在运行彩色美化脚本...${RESET}"
            bash <(curl -sL https://raw.githubusercontent.com/Polarisiu/tool/main/mhztcs.sh)
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
