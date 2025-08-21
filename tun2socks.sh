#!/bin/bash

GREEN="\033[32m"
RED="\033[31m"
RESET="\033[0m"

menu() {
    clear
    echo -e "${GREEN}=== Alice 出口管理菜单 ===${RESET}"
    echo -e "${GREEN}1) 安装 Alice 出口${RESET}"
    echo -e "${GREEN}2) 卸载 Alice 出口${RESET}"
    echo -e "${GREEN}0) 退出${RESET}"
    echo
    read -p $'\033[32m请选择操作 (0-2): \033[0m' choice
    case $choice in
        1)
            echo -e "${GREEN}正在安装 Alice 出口...${RESET}"
            curl -L https://raw.githubusercontent.com/hkfires/onekey-tun2socks/main/onekey-tun2socks.sh -o onekey-tun2socks.sh
            chmod +x onekey-tun2socks.sh
            sudo ./onekey-tun2socks.sh -i alice
            pause
            ;;
        2)
            echo -e "${GREEN}正在卸载 Alice 出口...${RESET}"
            curl -L https://raw.githubusercontent.com/hkfires/onekey-tun2socks/main/onekey-tun2socks.sh -o onekey-tun2socks.sh
            chmod +x onekey-tun2socks.sh
            sudo ./onekey-tun2socks.sh -r
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
