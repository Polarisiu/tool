#!/bin/bash
# 查看进程彩色高亮脚本 v2.3
# 提示文字统一绿色

# ================== 颜色定义 ==================
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RESET="\033[0m"
BOLD="\033[1m"

# ================== 用户选择 ==================
echo -e "${GREEN}请选择排序方式:${RESET}"
echo -e "${GREEN}1) CPU 占用排序${RESET}"
echo -e "${GREEN}2) 内存占用排序${RESET}"
read -p "$(echo -e "${GREEN}输入选项 (默认 1 CPU): ${RESET}")" sort_choice
sort_choice=${sort_choice:-1}

read -p "$(echo -e "${GREEN}是否启用实时刷新？(y/N): ${RESET}")" resp
[[ "$resp" =~ ^[Yy]$ ]] && REFRESH=1 || REFRESH=0

read -p "$(echo -e "${GREEN}请输入进程名关键字过滤（默认显示所有进程）: ${RESET}")" FILTER_KEY

# ================== 循环显示 ==================
while true; do
    [ $REFRESH -eq 1 ] && clear

    # 表头
    printf "${BOLD}%-8s %-20s %-10s %-10s %-20s %s${RESET}\n" \
        "PID" "USER" "CPU(%)" "MEM(%)" "START" "COMMAND"

    # 获取进程数据并排序
    if [[ "$sort_choice" == "2" ]]; then
        ps -eo pid,user,%cpu,%mem,lstart,args --sort=-%mem | tail -n +2
    else
        ps -eo pid,user,%cpu,%mem,lstart,args --sort=-%cpu | tail -n +2
    fi | nl -w1 -s' ' | while read -r rank pid user cpu mem l1 l2 l3 l4 args; do
        # 过滤进程名
        if [[ -n "$FILTER_KEY" && "$FILTER_KEY" != "" && "$args" != *"$FILTER_KEY"* ]]; then
            continue
        fi

        start_time="$l1 $l2 $l3 $l4"

        # 高亮前10名
        if [ "$rank" -le 10 ]; then
            pid_color="${RED}$pid${RESET}"
            user_color="${RED}$user${RESET}"
            cpu_color="${RED}$cpu${RESET}"
            mem_color="${RED}$mem${RESET}"
            command_color="${RED}$args${RESET}"
        else
            pid_color="$pid"
            user_color="$user"
            cpu_color="$cpu"
            mem_color="$mem"
            command_color="$args"
        fi

        # 使用 %b 确保颜色转义序列生效
        printf "%-8b %-20b %-10b %-10b %-20b %b\n" \
            "$pid_color" "$user_color" "$cpu_color" "$mem_color" "$start_time" "$command_color"
    done

    # ================== 退出逻辑 ==================
    if [ $REFRESH -eq 1 ]; then
        echo -e "\n${GREEN}输入 ${RED}0${GREEN} 回车退出实时刷新，其他回车继续...${RESET}"
        read -r input
        if [ "$input" == "0" ]; then
            echo -e "${GREEN}退出实时刷新${RESET}"
            break
        fi
    else
        break
    fi
done
