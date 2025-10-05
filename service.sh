#!/bin/bash
# systemd 自启动服务管理脚本 v2.7
# 支持关键词过滤，停止/禁用后自动刷新，输入 r 手动刷新，status 可回车返回，分页显示

# ================== 颜色定义 ==================
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
BOLD="\033[1m"
RESET="\033[0m"

# ================== 配置 ==================
PAGE_SIZE=20   # 每页显示多少条
CURRENT_PAGE=1

# ================== 用户输入关键词 ==================
read -p "$(echo -e "${GREEN}请输入关键词过滤（默认显示所有服务）: ${RESET}")" KEYWORD

# ================== 生成完整服务列表 ==================
generate_full_list() {
    FULL_SERVICE_LIST=()
    FULL_DISPLAY_LINES=()
    idx=1

    while read -r line; do
        service=$(echo "$line" | awk '{print $1}' | xargs)
        state=$(echo "$line" | awk '{print $2}' | xargs)
        desc=$(systemctl show -p Description --value "$service" 2>/dev/null | xargs)

        [[ -z "$service" ]] && continue

        # 关键词过滤
        if [[ -n "$KEYWORD" && "$service" != *"$KEYWORD"* && "$desc" != *"$KEYWORD"* ]]; then
            continue
        fi

        FULL_SERVICE_LIST+=("$service")

        # 彩色状态
        if [[ "$state" == "enabled" ]]; then
            state_color="${GREEN}$state${RESET}"
        elif [[ "$state" == "disabled" ]]; then
            state_color="${YELLOW}$state${RESET}"
        else
            state_color="${RED}$state${RESET}"
        fi

        FULL_DISPLAY_LINES+=("$(printf "%-5s %-40s %-10s %-50s" "$idx" "$service" "$state_color" "$desc")")
        ((idx++))
    done < <(systemctl list-unit-files --type=service | grep -v 'unit files listed' | tail -n +2)
}

# ================== 刷新并显示某一页 ==================
refresh_list() {
    clear
    echo -e "${BOLD}${CYAN}=== Systemd 服务列表（第 $CURRENT_PAGE 页 / 共 $(( (${#FULL_DISPLAY_LINES[@]} + PAGE_SIZE - 1) / PAGE_SIZE)) 页） ===${RESET}"
    printf "${BOLD}%-5s %-40s %-10s %-50s${RESET}\n" "No." "SERVICE" "STATE" "DESCRIPTION"

    start=$(( (CURRENT_PAGE - 1) * PAGE_SIZE ))
    end=$(( start + PAGE_SIZE - 1 ))

    for i in $(seq $start $end); do
        [[ $i -ge ${#FULL_DISPLAY_LINES[@]} ]] && break
        echo -e "${FULL_DISPLAY_LINES[$i]}"
    done
}

# ================== 初始化 ==================
generate_full_list
refresh_list

# ================== 用户选择操作 ==================
while true; do
    echo
    read -p "$(echo -e "${GREEN}输入序号查看状态，s 序号停止服务，r 刷新，n 下一页，p 上一页，0 退出: ${RESET}")" INPUT

    if [[ "$INPUT" == "0" ]]; then
        break

    elif [[ "$INPUT" == "r" ]]; then
        generate_full_list
        refresh_list

    elif [[ "$INPUT" == "n" ]]; then
        max_page=$(( (${#FULL_DISPLAY_LINES[@]} + PAGE_SIZE - 1) / PAGE_SIZE ))
        if (( CURRENT_PAGE < max_page )); then
            ((CURRENT_PAGE++))
        fi
        refresh_list

    elif [[ "$INPUT" == "p" ]]; then
        if (( CURRENT_PAGE > 1 )); then
            ((CURRENT_PAGE--))
        fi
        refresh_list

    elif [[ "$INPUT" =~ ^s[[:space:]]*([0-9 ]+)$ ]]; then
        NUMS="${BASH_REMATCH[1]}"
        for num in $NUMS; do
            idx=$((num-1))
            service="${FULL_SERVICE_LIST[$idx]}"
            if [[ -n "$service" ]]; then
                # 停止服务
                sudo systemctl stop "$service"
                if systemctl is-active --quiet "$service"; then
                    echo -e "${YELLOW}服务仍在运行（可能有依赖）: $service${RESET}"
                else
                    echo -e "${RED}已停止: $service${RESET}"
                fi

                # 获取服务类型
                unit_state=$(systemctl list-unit-files | awk -v s="$service" '$1==s {print $2}')
                if [[ "$unit_state" == "enabled" || "$unit_state" == "disabled" ]]; then
                    if sudo systemctl disable "$service"; then
                        echo -e "${RED}已禁用: $service${RESET}"
                    else
                        echo -e "${YELLOW}禁用失败: $service${RESET}"
                    fi
                else
                    echo -e "${YELLOW}服务为 static 或模板，不能禁用: $service${RESET}"
                fi
            else
                echo -e "${YELLOW}无效序号: $num${RESET}"
            fi
        done

        # ✅ 停止/禁用后刷新
        generate_full_list
        refresh_list

    elif [[ "$INPUT" =~ ^[0-9]+$ ]]; then
        idx=$((INPUT-1))
        service="${FULL_SERVICE_LIST[$idx]}"
        if [[ -n "$service" ]]; then
            echo -e "${CYAN}=== $service 详细状态（最近20行） ===${RESET}"
            systemctl status -n 20 --no-pager "$service"
            echo -e "${YELLOW}按回车返回菜单...${RESET}"
            read
            refresh_list
        else
            echo -e "${YELLOW}无效序号: $INPUT${RESET}"
        fi

    else
        echo -e "${YELLOW} 无效输入${RESET}"
    fi
done
