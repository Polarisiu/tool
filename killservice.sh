#!/bin/bash
# systemd 服务管理脚本 - 菜单版（菜单字体绿色）
# 功能：支持关键词过滤 + 分菜单操作（启动/停止/重启/删除/查看日志/查看状态/开机自启管理）

RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
BOLD="\033[1m"
RESET="\033[0m"

PAGE_SIZE=20
CURRENT_PAGE=1

# 生成完整服务列表
generate_full_list() {
    FULL_SERVICE_LIST=()
    FULL_DISPLAY_LINES=()
    idx=1
    while read -r line; do
        service=$(echo "$line" | awk '{print $1}' | xargs)
        state=$(echo "$line" | awk '{print $2}' | xargs)
        desc=$(systemctl show -p Description --value "$service" 2>/dev/null | xargs)

        [[ -z "$service" ]] && continue
        [[ -n "$KEYWORD" && "$service" != *"$KEYWORD"* && "$desc" != *"$KEYWORD"* ]] && continue

        FULL_SERVICE_LIST+=("$service")

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

# 刷新并显示某一页
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

# 删除服务文件
delete_service() {
    service="$1"
    unit_path=$(systemctl show -p FragmentPath --value "$service" 2>/dev/null)
    if [[ -z "$unit_path" || ! -f "$unit_path" ]]; then
        echo -e "${YELLOW}未找到服务文件: $service${RESET}"
        return
    fi
    echo -e "${RED}⚠ 确认要删除服务: $service ($unit_path) ? [y/N] ${RESET}"
    read -r confirm
    if [[ "$confirm" =~ ^[yY]$ ]]; then
        sudo systemctl stop "$service" 2>/dev/null
        sudo systemctl disable "$service" 2>/dev/null
        sudo rm -f "$unit_path" && echo -e "${RED}已删除: $service${RESET}"
        sudo systemctl daemon-reload
    else
        echo -e "${YELLOW}已取消删除: $service${RESET}"
    fi
}

# 子菜单：启动 / 停止 / 重启 / 删除
submenu_action() {
    local action="$1"
    while true; do
        refresh_list
        echo -e "${GREEN}== 当前操作: $action 服务 ==${RESET}"
        read -p "$(echo -e "${GREEN}输入序号(可多选, 空格分隔)，0 返回上级菜单: ${RESET}")" ARGS
        [[ "$ARGS" == "0" ]] && break

        for num in $ARGS; do
            idx=$((num-1))
            service="${FULL_SERVICE_LIST[$idx]}"
            if [[ -n "$service" ]]; then
                case $action in
                    启动)  sudo systemctl start "$service" && echo -e "${GREEN}已启动: $service${RESET}" ;;
                    停止)  sudo systemctl stop "$service" && echo -e "${RED}已停止: $service${RESET}" ;;
                    重启)  sudo systemctl restart "$service" && echo -e "${GREEN}已重启: $service${RESET}" ;;
                    删除)  delete_service "$service" ;;
                esac
            else
                echo -e "${YELLOW}无效序号: $num${RESET}"
            fi
        done
        read -p "按回车继续..." tmp
    done
}

# 子菜单：开机自启管理
submenu_autostart() {
    while true; do
        refresh_list
        echo -e "${GREEN}== 开机自启管理 ==${RESET}"
        echo -e "${GREEN}1) 启用开机自启${RESET}"
        echo -e "${GREEN}2) 禁用开机自启${RESET}"
        echo -e "${GREEN}0) 返回上级菜单${RESET}"
        read -p "$(echo -e "${GREEN}请选择操作: ${RESET}")" subchoice

        case $subchoice in
            1) 
                read -p "$(echo -e "${GREEN}输入序号(可多选, 空格分隔): ${RESET}")" ARGS
                for num in $ARGS; do
                    idx=$((num-1))
                    service="${FULL_SERVICE_LIST[$idx]}"
                    [[ -n "$service" ]] && sudo systemctl enable "$service" && echo -e "${GREEN}已启用开机自启: $service${RESET}"
                done ;;
            2)
                read -p "$(echo -e "${GREEN}输入序号(可多选, 空格分隔): ${RESET}")" ARGS
                for num in $ARGS; do
                    idx=$((num-1))
                    service="${FULL_SERVICE_LIST[$idx]}"
                    [[ -n "$service" ]] && sudo systemctl disable "$service" && echo -e "${RED}已禁用开机自启: $service${RESET}"
                done ;;
            0) break ;;
            *) echo -e "${YELLOW}无效输入${RESET}" ;;
        esac
        read -p "按回车继续..." tmp
    done
}

# 子菜单：查看日志
submenu_logs() {
    while true; do
        refresh_list
        echo -e "${GREEN}== 查看服务日志 ==${RESET}"
        read -p "$(echo -e "${GREEN}输入序号(单选)，0 返回上级菜单: ${RESET}")" num
        [[ "$num" == "0" ]] && break

        idx=$((num-1))
        service="${FULL_SERVICE_LIST[$idx]}"
        if [[ -n "$service" ]]; then
            echo -e "${CYAN}正在查看日志: $service (按 Ctrl+C 退出)${RESET}"
            sudo journalctl -u "$service" -f
        else
            echo -e "${YELLOW}无效序号: $num${RESET}"
        fi
        read -p "按回车继续..." tmp
    done
}

# 子菜单：查看状态
submenu_status() {
    while true; do
        refresh_list
        echo -e "${GREEN}== 查看服务状态 ==${RESET}"
        read -p "$(echo -e "${GREEN}输入序号(单选)，0 返回上级菜单: ${RESET}")" num
        [[ "$num" == "0" ]] && break

        idx=$((num-1))
        service="${FULL_SERVICE_LIST[$idx]}"
        if [[ -n "$service" ]]; then
            echo -e "${CYAN}正在查看状态: $service (按 q 退出)${RESET}"
            sudo systemctl status "$service"
        else
            echo -e "${YELLOW}无效序号: $num${RESET}"
        fi
        read -p "按回车继续..." tmp
    done
}

# 主逻辑
read -p "$(echo -e "${GREEN}请输入关键词过滤（默认显示所有服务）: ${RESET}")" KEYWORD
generate_full_list
refresh_list

while true; do
    echo -e "${GREEN}=== 主菜单 ===${RESET}"
    echo -e "${GREEN}1) 启动服务${RESET}"
    echo -e "${GREEN}2) 停止服务${RESET}"
    echo -e "${GREEN}3) 重启服务${RESET}"
    echo -e "${GREEN}4) 删除服务${RESET}"
    echo -e "${GREEN}5) 查看日志${RESET}"
    echo -e "${GREEN}6) 查看状态${RESET}"
    echo -e "${GREEN}7) 开机自启管理${RESET}"
    echo -e "${GREEN}n) 下一页   p) 上一页   r) 刷新${RESET}"
    echo -e "${GREEN}0) 退出${RESET}"
    read -p "$(echo -e "${GREEN}请选择操作: ${RESET}")" choice

    case $choice in
        1) submenu_action "启动" ;;
        2) submenu_action "停止" ;;
        3) submenu_action "重启" ;;
        4) submenu_action "删除" ;;
        5) submenu_logs ;;
        6) submenu_status ;;
        7) submenu_autostart ;;
        n) max_page=$(( (${#FULL_DISPLAY_LINES[@]} + PAGE_SIZE - 1) / PAGE_SIZE )); (( CURRENT_PAGE < max_page )) && ((CURRENT_PAGE++)); refresh_list ;;
        p) (( CURRENT_PAGE > 1 )) && ((CURRENT_PAGE--)); refresh_list ;;
        r) generate_full_list; refresh_list ;;
        0) exit 0 ;;
        *) echo -e "${YELLOW}无效输入${RESET}" ;;
    esac
done
