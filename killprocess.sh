#!/bin/bash
# 杀进程脚本 v2.3
# 修复过滤后序号与数组索引不对应问题 + 彩色高亮 + sudo 杀进程 + 序号选择

# ================== 颜色定义 ==================
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RESET="\033[0m"
BOLD="\033[1m"

# ================== 用户输入 ==================
read -p "$(echo -e "${GREEN}请输入进程名关键字过滤（默认显示所有进程）: ${RESET}")" FILTER_KEY

# ================== 获取进程列表 ==================
PID_LIST=()
USER_LIST=()
CMD_LIST=()
DISPLAY_LINES=()

index=0
printf "${BOLD}%-5s %-8s %-20s %-10s %-10s %-20s %s${RESET}\n" "No." "PID" "USER" "CPU(%)" "MEM(%)" "START" "COMMAND"

while read -r pid user cpu mem l1 l2 l3 l4 args; do
    if [[ -n "$FILTER_KEY" && "$args" != *"$FILTER_KEY"* ]]; then
        continue
    fi

    start_time="$l1 $l2 $l3 $l4"

    PID_LIST+=("$pid")
    USER_LIST+=("$user")
    CMD_LIST+=("$args")

    no=$((index+1))

    # 前10名高亮
    if [ "$no" -le 10 ]; then
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

    DISPLAY_LINES+=("$(printf "%-5s %-8s %-20s %-10s %-10s %-20s %s" "$no" "$pid_color" "$user_color" "$cpu_color" "$mem_color" "$start_time" "$command_color")")
    ((index++))
done < <(ps -eo pid,user,%cpu,%mem,lstart,args --sort=-%cpu | tail -n +2)

# 输出进程列表
for line in "${DISPLAY_LINES[@]}"; do
    echo -e "$line"
done

# ================== 用户选择要杀的序号 ==================
read -p "$(echo -e "\n${GREEN}请输入要杀的序号（多个用空格分开，输入 0 退出）: ${RESET}")" SELECTION

if [[ "$SELECTION" == "0" || -z "$SELECTION" ]]; then
    echo -e "${GREEN}未操作，退出脚本${RESET}"
    exit 0
fi

# ================== 校验序号有效性 ==================
for num in $SELECTION; do
    if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt "${#PID_LIST[@]}" ]; then
        echo -e "${RED}无效序号: $num${RESET}"
        exit 1
    fi
done

# ================== 确认操作 ==================
echo -e "${YELLOW}你确定要杀掉以下进程吗？${RESET}"
for num in $SELECTION; do
    idx=$((num-1))
    pid="${PID_LIST[$idx]}"
    user="${USER_LIST[$idx]}"
    cmd="${CMD_LIST[$idx]}"
    echo -e "${RED}序号 $num => PID $pid, USER $user, CMD $cmd${RESET}"
done

read -p "$(echo -e "${GREEN}输入 y 确认，其他键取消: ${RESET}")" CONFIRM

if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
    for num in $SELECTION; do
        idx=$((num-1))
        pid="${PID_LIST[$idx]}"
        if sudo kill -9 "$pid" 2>/dev/null; then
            echo -e "${GREEN}成功杀掉 PID: $pid${RESET}"
        else
            echo -e "${RED}无法杀掉 PID: $pid（可能不存在或权限不足）${RESET}"
        fi
    done
else
    echo -e "${GREEN}退出${RESET}"
fi
