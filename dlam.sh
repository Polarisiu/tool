#!/bin/bash

GREEN="\033[32m"
RED="\033[31m"
RESET="\033[0m"

menu() {
    clear
    echo -e "${GREEN}=== 转发面板管理菜单 ===${RESET}"
    echo -e "${GREEN}1) 安装面板${RESET}"
    echo -e "${GREEN}2) 卸载节点${RESET}"
    echo -e "${GREEN}0) 退出${RESET}"
    echo
    read -p $'\033[32m请选择操作 (0-2): \033[0m' choice
    case $choice in
        1)
            echo -e "${GREEN}正在安装面板...${RESET}"
            curl -L https://raw.githubusercontent.com/BrunuhVille/flux-panel/refs/heads/main/panel_install.sh -o panel_install.sh
            chmod +x panel_install.sh
            ./panel_install.sh
            pause
            ;;
        2)
            echo -e "${GREEN}正在卸载节点...${RESET}"
            curl -L https://raw.githubusercontent.com/BrunuhVille/flux-panel/refs/heads/main/install.sh -o ./install.sh
            chmod +x ./install.sh
            ./install.sh
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
