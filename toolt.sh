#!/bin/bash

# 颜色定义
BGreen='\033[1;32m'
BRed='\033[1;31m'
BYellow='\033[1;33m'
BBlue='\033[1;34m'
BPurple='\033[1;35m'
BCyan='\033[1;36m'
White='\033[1;37m'
BOrange='\033[1;38;5;208m'
NC='\033[0m'


# 脚本元数据
VERSION="1.0"
SCRIPT_PATH="/root/toolt.sh"
SCRIPT_URL="https://raw.githubusercontent.com/Polarisiu/tool/main/toolt.sh" # 替换为你脚本的实际URL

# --- 1. 更新功能 ---
update_script() {
    # 下载到临时文件，避免下载失败导致原脚本损坏
    curl -sL "$SCRIPT_URL" -o "${SCRIPT_PATH}.tmp"
    if [ $? -eq 0 ] && [ -s "${SCRIPT_PATH}.tmp" ]; then
        mv "${SCRIPT_PATH}.tmp" "$SCRIPT_PATH"
        chmod +x "$SCRIPT_PATH"
        echo -e "${BGreen}更新完成! ${NC}"
        sleep 1
        exec bash "$SCRIPT_PATH"
    else
        echo -e "${BRed}更新失败，请检查网络连接。${NC}"
        rm -f "${SCRIPT_PATH}.tmp"
        any_key_to_continue
    fi
}

# --- 2. 卸载功能 (清理版) ---
uninstall_script() {
    echo -e "${BRed}正在卸载工具箱并清理快捷键...${NC}"
    # 清理所有快捷方式
    rm -f /usr/local/bin/t
    rm -f /usr/local/bin/T
    # 删除主脚本自身
    rm -f "$SCRIPT_PATH"
    echo -e "${BGreen}卸载完成! ${NC}"
    exit 0
}

# 按键继续函数
any_key_to_continue() {
    echo ""
    echo -e "${BYellow}操作已完成，按任意键继续...${NC}"
    read -n 1 -s -r -p ""
}

progress_bar() {
    local percent=$1
    local width=20

    # 确保百分比不超标
    [ "$percent" -gt 100 ] && percent=100
    [ "$percent" -lt 0 ] && percent=0

    local filled=$((percent * width / 100))
    local empty=$((width - filled))

    # 根据百分比选颜色
    if [ "$percent" -lt 50 ]; then
        color="\033[32m" # 绿色
    elif [ "$percent" -lt 80 ]; then
        color="\033[33m" # 黄色
    else
        color="\033[31m" # 红色
    fi

    # 关键修改：直接构造固定长度的 bar 字符串
    local bar_chars=""
    for ((i=0; i<filled; i++)); do bar_chars+="█"; done
    for ((i=0; i<empty; i++)); do bar_chars+="░"; done

    # 输出颜色 + 20位进度条 + 重置颜色
    printf "${color}%s\033[0m" "$bar_chars"
}

# 单位自动转换：MB 转为 M 或 G
format_size() {
    local size_mb=$1
    if [ "$size_mb" -ge 1024 ]; then
        echo "$(awk "BEGIN {printf \"%.1f\", $size_mb/1024}")G"
    else
        echo "${size_mb}M"
    fi
}


# ===============================
# 获取当前时区（跨系统兼容）
# ===============================
get_timezone() {
    # 1️⃣ systemd 环境，屏蔽错误
    if command -v timedatectl &>/dev/null; then
        tz=$(timedatectl show -p Timezone --value 2>/dev/null)
        [[ -n "$tz" ]] && echo "$tz" && return
    fi

    # 2️⃣ /etc/timezone 文件（Debian）
    if [[ -f /etc/timezone ]]; then
        tz=$(cat /etc/timezone)
        [[ -n "$tz" ]] && echo "$tz" && return
    fi

    # 3️⃣ /etc/localtime 符号链接（RedHat / CentOS）
    if [[ -L /etc/localtime ]]; then
        tz=$(readlink /etc/localtime | sed 's#.*/zoneinfo/##')
        [[ -n "$tz" ]] && echo "$tz" && return
    fi

    # 4️⃣ /etc/localtime 文件内容匹配（minimal / docker / chroot）
    if [[ -f /etc/localtime ]]; then
        tz=$(strings /etc/localtime 2>/dev/null | grep -E '^[A-Z][a-z]+/[A-Z][a-zA-Z_]+$' | head -n1)
        [[ -n "$tz" ]] && echo "$tz" && return
    fi

    # 5️⃣ 兜底
    echo "未知"
}


get_sys_status() {
    # 1. 内存与虚拟内存
    MEM_TOTAL_MB=$(free -m | awk '/Mem:/ {print $2}')
    MEM_USED_MB=$(free -m | awk '/Mem:/ {print $3}')
    MEM_PCT=$((MEM_USED_MB * 100 / (MEM_TOTAL_MB + 1)))
    MEM_USED_STR=$(format_size $MEM_USED_MB)
    MEM_TOTAL_STR=$(format_size $MEM_TOTAL_MB)

    SWAP_TOTAL_MB=$(free -m | awk '/Swap:/ {print $2}')
    SWAP_USED_MB=$(free -m | awk '/Swap:/ {print $3}')
    if [ "$SWAP_TOTAL_MB" -gt 0 ]; then
        SWAP_PCT=$((SWAP_USED_MB * 100 / SWAP_TOTAL_MB))
    else
        SWAP_PCT=0
    fi
    SWAP_USED_STR=$(format_size $SWAP_USED_MB)
    SWAP_TOTAL_STR=$(format_size $SWAP_TOTAL_MB)

    # 2. 磁盘计算
    DISK_TOTAL=$(df -h / | awk '/\// {print $2}' | tail -n 1)
    DISK_USED=$(df -h / | awk '/\// {print $3}' | tail -n 1)
    DISK_PCT_STR=$(df -h / | awk '/\// {print $5}' | tail -n 1)
    DISK_VAL=$(echo "$DISK_PCT_STR" | tr -d '%')
    DISK_PCT=$DISK_PCT_STR

    # 3. CPU 使用率
    CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk -F',' '{for(i=1;i<=NF;i++) if($i ~ /id/) print $i}' | awk '{print $1}' | cut -d. -f1 | tr -d '[:space:]')
    CPU_VAL=$(top -bn1 | awk -F'id,' '/Cpu/ {split($1,a,","); split(a[length(a)],b," "); print 100 - b[length(b)]}' | cut -d. -f1)
    CPU_PCT="${CPU_VAL}%"

    # 4. 系统状态动态判断
    if [ "$CPU_VAL" -gt 90 ] || [ "$MEM_PCT" -gt 90 ] || [ "$DISK_VAL" -gt 90 ] || [ "$SWAP_PCT" -gt 80 ]; then
        SYS_STATE="${BRed}危险 ⚡${NC}"
    elif [ "$CPU_VAL" -gt 70 ] || [ "$MEM_PCT" -gt 70 ] || [ "$DISK_VAL" -gt 70 ]; then
        SYS_STATE="${BYellow}注意 ⚠️${NC}"
    else
        SYS_STATE="${BGreen}正常 ✔${NC}"
    fi

    # 5. 其他信息
    OS=$(grep -w "PRETTY_NAME" /etc/os-release | cut -d '"' -f2)
    # 1. 尝试多渠道获取 CPU 型号
    local raw_cpu=""
    raw_cpu=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2)
    [ -z "$raw_cpu" ] && raw_cpu=$(grep -m1 "Hardware" /proc/cpuinfo 2>/dev/null | cut -d: -f2)
    [ -z "$raw_cpu" ] && raw_cpu=$(lscpu 2>/dev/null | grep "Model name" | cut -d: -f2)

    # 2. 精简清理逻辑 (合并 sed 指令提高效率)
    # 移除 @...GHz, CPU, Processor, Intel, AMD, 以及括号内容(可选)
    CPU_MODEL=$(echo "$raw_cpu" | sed -E \
        -e 's/\(R\)|\(TM\)//g' \
        -e 's/@.*//g' \
        -e 's/[Cc][Pp][Uu]//g' \
        -e 's/[Pp]rocessor//g' \
        -e 's/[0-9]+-Core//g' \
        -e 's/^[[:space:]]*|[[:space:]]*$//g' \
        -e 's/[[:space:]]+/ /g')

    # 3. 最终格式化
    ARCH=$(uname -m)
    [ -z "$CPU_MODEL" ] && CPU_MODEL="Unknown CPU"
    CPU_INFO="${CPU_MODEL} (${ARCH})"
    TIME_NOW=$(date "+%Y-%m-%d %H:%M:%S")
    TIME_ZONE=$(get_timezone)


    total_seconds=$(cut -d. -f1 /proc/uptime)
    d=$((total_seconds / 86400))
    h=$(( (total_seconds % 86400) / 3600 ))
    m=$(( (total_seconds % 3600) / 60 ))
    UPTIME=""
    [ $d -gt 0 ] && UPTIME+="${d}天"
    [ $h -gt 0 ] && UPTIME+="${h}小时"
    [ $m -gt 0 ] && UPTIME+="${m}分钟"
    [ -z "$UPTIME" ] && UPTIME="刚刚启动"
}

# 顶部看板
draw_banner() {
    clear
    echo -e "${BCyan}"
    echo "████████╗ ██████╗  ██████╗ ██╗  ████████╗"
    echo "╚══██╔══╝██╔═══██╗██╔═══██╗██║  ╚══██╔══╝"
    echo "   ██║   ██║   ██║██║   ██║██║     ██║   "
    echo "   ██║   ██║   ██║██║   ██║██║     ██║   "
    echo "   ██║   ╚██████╔╝╚██████╔╝███████╗██║   "
    echo "   ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚═╝   "
    echo -e "  ${BYellow}>> VPS 综合管理工具箱(快捷指令:T/t) <<${NC}"
    
    get_sys_status
    echo -e "${BCyan}┌──────────────────────────────────────────────┐${NC}"
    echo -e "  ${BOrange}系统状态：${NC}${SYS_STATE}\n"                                    
    # 统一格式：标签(12字节) + 进度条(20个符号) + 间隔(2空格) + 数据(固定列宽)
    printf "  ${BOrange}内存占用：${NC}"
    progress_bar "$MEM_PCT"
    printf "  %-18s\n" "${MEM_USED_STR} / ${MEM_TOTAL_STR}"

    printf "  ${BOrange}虚拟内存：${NC}"
    progress_bar "$SWAP_PCT"
    printf "  %-18s\n" "${SWAP_USED_STR} / ${SWAP_TOTAL_STR}"

    printf "  ${BOrange}磁盘占用：${NC}"
    progress_bar "$DISK_VAL"
    printf "  %-18s\n" "${DISK_USED} / ${DISK_TOTAL}"

    printf "  ${BOrange}CPU 使用：${NC}"
    progress_bar "$CPU_VAL"
    printf "  %-18s\n" "${CPU_PCT}"
    echo -e "${BCyan}└──────────────────────────────────────────────┘${NC}"
    echo -e " ${BOrange}💻 系统 :${NC} ${BOrange}$OS${NC}"
    echo -e " ${BOrange}🧩 架构 :${NC} ${BOrange}$CPU_INFO${NC}"
    echo -e " ${BOrange}🌍 时区 :${NC} ${BOrange}$TIME_ZONE${NC}"
    echo -e " ${BOrange}🕒 时间 :${NC} ${BOrange}$TIME_NOW${NC}"
    echo -e " ${BOrange}🚀 运行 :${NC} ${BYellow}$UPTIME${NC}  ${BBlue}V:核心状态检测${NC}"
    echo -e "${BCyan}────────────────────────────────────────────────${NC}"
}

# 一级主菜单
main_menu() {
    draw_banner
    echo -e "${BYellow}▶1. 系统设置${NC}"
    echo -e "${BYellow}▶2. 网络设置${NC}"
    echo -e "${BYellow}▶3. 网络检测${NC}"
    echo -e "${BYellow}▶4. 网络代理${NC}"
    echo -e "${BYellow}▶5. 网络监控${NC}"
    echo -e "${BYellow}▶6. 玩具熊ʕ•ᴥ•ʔ${NC}"
    echo -e "${BGreen}▶8. 更新工具箱${NC}"
    echo -e "${BGreen}▶9. 卸载工具箱${NC}"
    echo -e "${BRed}▶0. 退出${NC}"
}

# 二级菜单处理逻辑
menu_system() {
    while true; do
        draw_banner
        echo -e "${BYellow}▶ 1. 更新系统${NC}"
        echo -e "${BYellow}▶ 2. 系统信息${NC}"
        echo -e "${BYellow}▶ 3. 系统清理${NC}"
        echo -e "${BYellow}▶ 4. 修改主机名${NC}"
        echo -e "${BYellow}▶ 5. 修改Root密码${NC}"
        echo -e "${BYellow}▶ 6. 修改SSH端口${NC}"
        echo -e "${BYellow}▶ 7. 设置SWAP内存${NC}"
        echo -e "${BYellow}▶ 8. SSH密钥登录"
        echo -e "${BYellow}▶ 9. Fail2Ban"
        echo -e "${BYellow}▶10. 定时任务"
        echo -e "${BYellow}▶11. 重装系统(DD)${NC}"
        echo -e "${BYellow}▶12. 系统重启${NC}"
        echo -e "${BOrange}▶ X. 退出${NC}"
        echo -e "${BRed}▶ 0. 返回主菜单${NC}"
        read -r -p $'\033[1;36m请输入选择: \033[0m' sub
        case "$sub" in
            1) bash <(curl -sL https://raw.githubusercontent.com/Polarisiu/tool/main/vpsup.sh) ; any_key_to_continue ;;
            2) bash <(curl -sL https://raw.githubusercontent.com/Polarisiu/tool/main/vpsx.sh) ; any_key_to_continue ;;
            3) bash <(curl -sL https://raw.githubusercontent.com/Polarisiu/tool/main/vpsq.sh) ; any_key_to_continue ;;
            4) bash <(curl -sL https://raw.githubusercontent.com/Polarisiu/tool/main/hostname.sh) ; any_key_to_continue ;;
            5) sudo passwd root ; any_key_to_continue ;;
            6) bash <(curl -sL https://raw.githubusercontent.com/Polarisiu/tool/main/vpssshdk.sh) ; any_key_to_continue ;;
            7) bash <(curl -sL https://raw.githubusercontent.com/Polarisiu/tool/main/vpsswap.sh) ; any_key_to_continue ;;
            8) bash <(curl -sL https://raw.githubusercontent.com/Polarisiu/tool/main/sshkey.sh) ; any_key_to_continue ;;
            9) bash <(curl -sL https://raw.githubusercontent.com/Polarisiu/tool/main/Fail2Ban.sh) ; any_key_to_continue ;;
            10) bash <(curl -sL https://raw.githubusercontent.com/Polarisiu/tool/main/crontab.sh) ; any_key_to_continue ;;
            11) bash <(curl -sL https://raw.githubusercontent.com/Polarisiu/tool/main/VPSDD.sh) ; any_key_to_continue ;;
            12) sudo reboot ;;
            x|X) exit 0 ;;
            0) break ;;
        esac
    done
}

menu_network() {
    while true; do
        draw_banner
        echo -e "${BYellow}▶1. BBR调优"
        echo -e "${BYellow}▶2. 切换v4/v6"
        echo -e "${BYellow}▶3. 开放所有端口"
        echo -e "${BYellow}▶4. DNS设置"
        echo -e "${BYellow}▶5. AkileDNS"
        echo -e "${BYellow}▶6. CFWARP"
        echo -e "${BYellow}▶7. EasyTier组网"
        echo -e "${BOrange}▶X. 退出${NC}"
        echo -e "${BRed}▶0. 返回主菜单${NC}"
        read -r -p $'\033[1;36m请输入选择: \033[0m' sub
        case "$sub" in
            1) bash <(curl -sL https://raw.githubusercontent.com/Polarisiu/tool/main/BBR.sh) ; any_key_to_continue ;;
            2) bash <(curl -sL https://raw.githubusercontent.com/Polarisiu/tool/main/qhwl.sh) ; any_key_to_continue ;;
            3) bash <(curl -sL https://raw.githubusercontent.com/Polarisiu/tool/main/opendk.sh) ; any_key_to_continue ;;
            4) bash <(curl -sL https://raw.githubusercontent.com/Polarisiu/tool/main/DNS.sh) ; any_key_to_continue ;;
            5) wget -qO- https://raw.githubusercontent.com/akile-network/aktools/refs/heads/main/akdns.sh | bash ; any_key_to_continue ;;
            6) wget -N https://gitlab.com/fscarmen/warp/-/raw/main/menu.sh && bash menu.sh ; any_key_to_continue ;;
            7) bash <(curl -sL https://raw.githubusercontent.com/ceocok/c.cococ/refs/heads/main/easytier.sh) ; any_key_to_continue ;;
            x|X) exit 0 ;;
            0) break ;;
        esac
    done
}

menu_test() {
    while true; do
        draw_banner
        echo -e "${BYellow}▶1. 流媒体解锁检测"
        echo -e "${BYellow}▶2. 回程线路检测"
        echo -e "${BYellow}▶3. NodeQuality"
        echo -e "${BYellow}▶4. 融合怪"
        echo -e "${BOrange}▶X. 退出${NC}"
        echo -e "${BRed}▶0. 返回主菜单${NC}"
        read -r -p $'\033[1;36m请输入选择: \033[0m' sub
        case "$sub" in
            1) bash <(curl -L -s https://raw.githubusercontent.com/lmc999/RegionRestrictionCheck/main/check.sh) ; any_key_to_continue ;;
            2) curl https://raw.githubusercontent.com/ludashi2020/backtrace/main/install.sh -sSf | sh ; any_key_to_continue ;;
            3) bash <(curl -sL https://run.NodeQuality.com) ; any_key_to_continue ;;
            4) bash <(wget -qO- --no-check-certificate https://gitlab.com/spiritysdx/za/-/raw/main/ecs.sh) ; any_key_to_continue ;;
            x|X) exit 0 ;;
            0) break ;;
        esac
    done
}

menu_proxy() {
    while true; do
        draw_banner
        echo -e "${BYellow}▶1. 3X-UI面板"
        echo -e "${BYellow}▶2. Realm转发"
        echo -e "${BYellow}▶3. SS-Xray-2go"
        echo -e "${BYellow}▶4. vless-all-in-one"
        echo -e "${BOrange}▶X. 退出${NC}"
        echo -e "${BRed}▶0. 返回主菜单${NC}"
        read -r -p $'\033[1;36m请输入选择: \033[0m' sub
        case "$sub" in
            1) bash <(curl -sL https://raw.githubusercontent.com/Polarisiu/tool/main/3xui.sh) ; any_key_to_continue ;;
            2) wget -qO- https://raw.githubusercontent.com/zywe03/realm-xwPF/main/xwPF.sh | sudo bash -s install ; any_key_to_continue ;;
            3) bash <(curl -Ls https://raw.githubusercontent.com/Luckylos/xray-2go/refs/heads/main/xray_2go.sh) ; any_key_to_continue ;;
            4) wget -O vless-server.sh https://raw.githubusercontent.com/Zyx0rx/vless-all-in-one/main/vless-server.sh && chmod +x vless-server.sh && ./vless-server.sh ; any_key_to_continue ;;
            x|X) exit 0 ;;
            0) break ;;
        esac
    done
}

menu_jk() {
    while true; do
        draw_banner
        echo -e "${BYellow}▶1. 端口流量狗"
        echo -e "${BYellow}▶2. DDNS动态域名"
        echo -e "${BOrange}▶X. 退出${NC}"
        echo -e "${BRed}▶0. 返回主菜单${NC}"
        read -r -p $'\033[1;36m请输入选择: \033[0m' sub
        case "$sub" in
            1) wget -O port-traffic-dog.sh https://raw.githubusercontent.com/zywe03/realm-xwPF/main/port-traffic-dog.sh && chmod +x port-traffic-dog.sh && ./port-traffic-dog.sh ; any_key_to_continue ;;
            2) bash <(curl -sL https://raw.githubusercontent.com/Polarisiu/tool/main/DDNS.sh) ; any_key_to_continue ;;
            x|X) exit 0 ;;
            0) break ;;
        esac
    done
}

menu_app() {
    while true; do
        draw_banner
        echo -e "${BYellow}▶1. Emby反代"
        echo -e "${BYellow}▶2. 关闭哪吒V1SSH"
        echo -e "${BYellow}▶3. 卸载探针"
        echo -e "${BOrange}▶X. 退出${NC}"
        echo -e "${BRed}▶0. 返回主菜单${NC}"
        read -r -p $'\033[1;36m请输入选择: \033[0m' sub
        case "$sub" in
            1) bash <(curl -sL https://raw.githubusercontent.com/Polarisiu/tool/main/Embyfd.sh) ; any_key_to_continue ;;
            2) sed -i 's/disable_command_execute: false/disable_command_execute: true/' /opt/nezha/agent/config.yml && systemctl restart nezha-agent ; any_key_to_continue ;;
            3) bash <(curl -sL https://raw.githubusercontent.com/Polarisiu/tool/main/agent.sh) ; any_key_to_continue ;;
            x|X) exit 0 ;;
            0) break ;;
        esac
    done
}


# --- 程序入口 ---

while true; do
    main_menu
    read -r -p $'\033[1;36m请输入菜单编号: \033[0m' choice
    case "$choice" in
        1) menu_system ;;
        2) menu_network ;;
        3) menu_test ;;
        4) menu_proxy ;;
        5) menu_jk ;;
        6) menu_app ;;
        8) update_script ;;
        9) uninstall_script ;;
        v|V)
            bash <(curl -sL https://raw.githubusercontent.com/Polarisiu/tool/main/test.sh)
            any_key_to_continue 
            ;;
        0) exit 0 ;;
        *) echo -e "${BRed}无效输入${NC}" && sleep 1 ;;
    esac
done
