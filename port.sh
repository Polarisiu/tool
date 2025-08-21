#!/bin/bash
# ss 彩色高亮增强版 v5.5 多系统适配 + 高风险端口排序 + 0退出 + 默认显示所有端口/协议 + 绿色提示 + 红色0

# ================== 颜色定义 ==================
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
PURPLE="\033[35m"
CYAN="\033[36m"
RESET="\033[0m"
BOLD="\033[1m"

# ================== 用户输入 ==================
echo -ne "${GREEN}"
read -p "是否启用实时刷新？(y/N): " resp
[[ "$resp" =~ ^[Yy]$ ]] && REFRESH=1 || REFRESH=0

read -p "过滤协议 (tcp/udp, 默认全部): " FILTER_PROTO
FILTER_PROTO=${FILTER_PROTO,,} # 转小写

read -p "过滤端口 (数字/多个用逗号分隔, 默认全部): " FILTER_PORT
IFS=',' read -r -a FILTER_PORT_ARR <<< "$FILTER_PORT"
echo -ne "${RESET}"

# ================== 表头 ==================
printf "${BOLD}%-6s %-12s %-10s %-10s %-30s %-30s %s${RESET}\n" \
    "Proto" "State" "Recv-Q" "Send-Q" "Local:Port" "Peer:Port" "Process"

# ================== 循环显示 ==================
while true; do
    [ $REFRESH -eq 1 ] && clear

    ss -tulnape 2>/dev/null | tail -n +2 | while read -r line; do
        [[ "$line" =~ Failed.*cgroup ]] && continue

        proto=$(echo "$line" | awk '{print $1}')
        state=$(echo "$line" | awk '{print $2}')
        recvq=$(echo "$line" | awk '{print $3}')
        sendq=$(echo "$line" | awk '{print $4}')
        local_addr=$(echo "$line" | awk '{print $5}')
        peer_addr=$(echo "$line" | awk '{print $6}')
        process=$(echo "$line" | awk '{$1=$2=$3=$4=$5=$6=""; print $0}' | sed 's/^ *//')

        port="${local_addr##*:}"

        # 协议过滤
        if [[ -n "$FILTER_PROTO" && "$FILTER_PROTO" != "" && "$FILTER_PROTO" != "全部" && "$proto" != "$FILTER_PROTO" ]]; then
            continue
        fi

        # 端口过滤
        if [[ -n "$FILTER_PORT" && "$FILTER_PORT" != "" ]]; then
            match=0
            for p in "${FILTER_PORT_ARR[@]}"; do
                [[ "$port" == "$p" ]] && match=1
            done
            [[ $match -eq 0 ]] && continue
        fi

        # 高风险端口标记
        if [[ "$port" =~ ^(22|80|443|3389)$ ]]; then
            risk=1
        else
            risk=0
        fi

        # 协议颜色
        case "$proto" in
            tcp) proto_color="${GREEN}${proto}${RESET}" ;;
            udp) proto_color="${CYAN}${proto}${RESET}" ;;
            *) proto_color="$proto" ;;
        esac

        # 状态颜色
        case "$state" in
            LISTEN) state_color="${YELLOW}${state}${RESET}" ;;
            ESTAB) state_color="${GREEN}${state}${RESET}" ;;
            SYN-RECV|FIN-WAIT-1|FIN-WAIT-2|CLOSE-WAIT|CLOSING|LAST-ACK|TIME-WAIT)
                state_color="${PURPLE}${state}${RESET}" ;;
            UNCONN) state_color="${BLUE}${state}${RESET}" ;;
            *) state_color="$state" ;;
        esac

        # 本地地址颜色
        if [[ "$local_addr" =~ ^127\.|^::1|^10\.|^192\.168\.|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-1]\. ]]; then
            local_color="$BLUE$local_addr$RESET"
        elif [[ "$risk" -eq 1 ]]; then
            local_color="$RED$local_addr$RESET"
        else
            local_color="$YELLOW$local_addr$RESET"
        fi

        # 输出格式，risk 用于排序
        printf "%d %s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
            "$risk" "$proto_color" "$state_color" "$recvq" "$sendq" "$local_color" "$peer_addr" "$process"

    done | sort -r -k1,1 -k3,3 | while read -r _ proto state recvq sendq local peer proc; do
        printf "%-6b %-12b %-10s %-10s %-30b %-30s %s\n" \
            "$proto" "$state" "$recvq" "$sendq" "$local" "$peer" "$proc"
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
