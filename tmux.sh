#!/bin/bash

# 颜色定义
GREEN="\033[32m"
RESET="\033[0m"

# 打开或创建工作区
open_workspace() {
    local SESSION_NAME=$1
    tmux has-session -t "$SESSION_NAME" 2>/dev/null
    if [ $? -ne 0 ]; then
        tmux new -s "$SESSION_NAME" -d  # 后台启动
        echo -e "${GREEN}工作区 $SESSION_NAME 已创建并后台运行${RESET}"
        tmux attach -t "$SESSION_NAME"  # 可选：直接进入
    else
        tmux attach -t "$SESSION_NAME"
    fi
}

# 安装 tmux
install_tmux() {
    if ! command -v tmux >/dev/null 2>&1; then
        sudo apt update
        sudo apt install -y tmux
        echo -e "${GREEN}tmux 安装完成${RESET}"
    else
        echo -e "${GREEN}tmux 已安装${RESET}"
    fi
}

# 卸载 tmux
remove_tmux() {
    if command -v tmux >/dev/null 2>&1; then
        sudo apt remove -y tmux
        echo -e "${GREEN}tmux 已卸载${RESET}"
    else
        echo -e "${GREEN}tmux 未安装${RESET}"
    fi
}

# 删除指定工作区
delete_workspace() {
    read -rp "$(echo -e ${GREEN}请输入要删除的工作区名称: ${RESET})" del_name
    tmux kill-session -t "$del_name" 2>/dev/null && \
        echo -e "${GREEN}工作区 $del_name 已删除${RESET}" || \
        echo -e "${GREEN}工作区 $del_name 不存在${RESET}"
    read -p "按回车返回菜单..."
}

# 主循环菜单
while true; do
    clear
    echo -e "${GREEN}================ 我的工作区 ================${RESET}"
    echo -e "${GREEN}系统将为你提供5个后台运行的工作区，你可以用来执行长时间的任务${RESET}"
    echo -e "${GREEN}即使你断开SSH，工作区中的任务也不会中断，非常方便！${RESET}"
    echo -e "${GREEN}注意: 进入工作区后使用 Ctrl+b 再按 d 退出${RESET}"
    echo -e "${GREEN}-------------------------------------------${RESET}"
    echo -e "${GREEN}a. 安装工作区环境${RESET}"
    echo -e "${GREEN}b. 卸载工作区环境${RESET}"
    echo -e "${GREEN}1. 1号工作区${RESET}"
    echo -e "${GREEN}2. 2号工作区${RESET}"
    echo -e "${GREEN}3. 3号工作区${RESET}"
    echo -e "${GREEN}4. 4号工作区${RESET}"
    echo -e "${GREEN}5. 5号工作区${RESET}"
    echo -e "${GREEN}7. 删除指定工作区${RESET}"
    echo -e "${GREEN}8. 工作区状态${RESET}"
    echo -e "${GREEN}0. 退出脚本${RESET}"
    echo -e "${GREEN}-------------------------------------------${RESET}"

    read -rp "$(echo -e ${GREEN}请输入你的选择: ${RESET})" sub_choice

    case $sub_choice in
        a) clear; install_tmux ;;
        b) clear; remove_tmux ;;
        1) clear; open_workspace "work1" ;;
        2) clear; open_workspace "work2" ;;
        3) clear; open_workspace "work3" ;;
        4) clear; open_workspace "work4" ;;
        5) clear; open_workspace "work5" ;;
        7) clear; delete_workspace ;;
        8)
            clear
            if tmux list-sessions >/dev/null 2>&1; then
                echo -e "${GREEN}当前运行的工作区:${RESET}"
                tmux list-sessions
            else
                echo -e "${GREEN}暂无工作区正在运行${RESET}"
            fi
            read -p "按回车返回菜单..."
            ;;
        0)
            echo -e "${GREEN}正在退出脚本...${RESET}"
            exit 0
            ;;
        *) echo -e "${GREEN}无效的输入!${RESET}" ; read -p "按回车返回菜单..." ;;
    esac
done
