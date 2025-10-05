#!/bin/bash
# 端口占用释放脚本 v2.0
# 输入端口号 -> 显示占用进程 -> 按序号杀掉

# ================== 颜色定义 ==================
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RESET="\033[0m"
BOLD="\033[1m"

# ================== 用户输入端口 ==================
read -p "$(echo -e "${GREEN}请输入要释放的端口号: ${RESET}")" PORT
if [[ -z "$PORT" ]]; then
    echo -e "${RED}端口号不能为空，退出脚本${RESET}"
    exit 1
fi

# ================== 获取占用进程 ==================
PROCESS_LIST=()
PID_LIST=()
DISPLAY_LINES=()

mapfile -t OCCUPY < <(sudo lsof -i :"$PORT" | tail -n +2)

if [[ ${#OCCUPY[@]} -eq 0 ]]; then
    echo -e "${GREEN}端口 $PORT 没有被占用${RESET}"
    exit 0
fi

echo -e "${YELLOW}端口 $PORT 被以下进程占用:${RESET}"
printf "${BOLD}%-5s %-8s %-10s %-10s %s${RESET}\n" "No." "PID" "USER" "PROTO" "COMMAND"

idx=1
for line in "${OCCUPY[@]}"; do
    pid=$(echo "$line" | awk '{print $2}')
    user=$(echo "$line" | awk '{print $3}')
    proto=$(echo "$line" | awk '{print $1}')
    cmd=$(echo "$line" | awk '{print $1}')
    
    PID_LIST+=("$pid")
    DISPLAY_LINES+=("$(printf "%-5s %-8s %-10s %-10s %s" "$idx" "$pid" "$user" "$proto" "$cmd")")
    ((idx++))
done

for line in "${DISPLAY_LINES[@]}"; do
    echo -e "$line"
done

# ================== 用户选择杀掉的序号 ==================
read -p "$(echo -e "\n${GREEN}请输入要杀掉的序号（多个用空格分开，输入 0 退出）: ${RESET}")" SELECTION

if [[ "$SELECTION" == "0" || -z "$SELECTION" ]]; then
    echo -e "${GREEN}未操作，退出脚本${RESET}"
    exit 0
fi

# ================== 确认操作 ==================
echo -e "${YELLOW}你确定要杀掉以下进程吗？${RESET}"
for num in $SELECTION; do
    idx=$((num-1))
    pid="${PID_LIST[$idx]}"
    echo -e "${RED}序号 $num => PID $pid${RESET}"
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

# ================== 检查端口是否释放 ==================
if [[ -z $(sudo lsof -i :"$PORT" | tail -n +2) ]]; then
    echo -e "${GREEN}端口 $PORT 已成功释放${RESET}"
else
    echo -e "${RED}端口 $PORT 仍被占用，请检查${RESET}"
fi
