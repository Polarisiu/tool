#!/bin/bash
# ================== 颜色 ==================
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

# ================== 检查脚本是否存在 ==================
SCRIPT_NAME="onekey-tun2socks.sh"
if [ ! -f "$SCRIPT_NAME" ]; then
    echo -e "${YELLOW}未找到 $SCRIPT_NAME，正在下载...${RESET}"
    curl -L https://raw.githubusercontent.com/hkfires/onekey-tun2socks/main/onekey-tun2socks.sh -o $SCRIPT_NAME
    chmod +x $SCRIPT_NAME
    echo -e "${GREEN}下载完成并赋予执行权限.${RESET}"
fi

# ================== 菜单函数 ==================
show_menu() {
    clear
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${GREEN}   tun2socks 管理菜单   ${RESET}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${GREEN}1.  安装自定义 Socks5 出口${RESET}"
    echo -e "${GREEN}2.  安装 Alice 出口${RESET}"
    echo -e "${GREEN}3.  变更 Alice 出口${RESET}"
    echo -e "${GREEN}4.  卸载 tun2socks${RESET}"
    echo -e "${GREEN}5.  检查更新${RESET}"
    echo -e "${GREEN}6.  查看服务状态${RESET}"
    echo -e "${GREEN}7.  启动服务${RESET}"
    echo -e "${GREEN}8.  停止服务${RESET}"
    echo -e "${GREEN}9.  重启服务${RESET}"
    echo -e "${GREEN}10. 查看服务日志${RESET}"
    echo -e "${GREEN}0.  退出菜单${RESET}"
    echo -e "${YELLOW}请选择操作 [0-10]:${RESET} "
}

# ================== 主循环 ==================
while true; do
    show_menu
    read -r choice
    case $choice in
        1)
            echo -e "${GREEN}正在安装自定义 Socks5 出口...${RESET}"
            sudo ./$SCRIPT_NAME -i custom
            ;;
        2)
            echo -e "${GREEN}正在安装 Alice 版本...${RESET}"
            sudo ./$SCRIPT_NAME -i alice
            ;;
        3)
            echo -e "${GREEN}正在变更 Alice 出口...${RESET}"
            sudo ./$SCRIPT_NAME -s
            ;;
        4)
            echo -e "${RED}正在卸载 tun2socks...${RESET}"
            sudo ./$SCRIPT_NAME -r
            ;;
        5)
            echo -e "${GREEN}正在检查更新...${RESET}"
            sudo ./$SCRIPT_NAME -u
            ;;
        6)
            echo -e "${GREEN}服务状态:${RESET}"
            systemctl status tun2socks.service
            ;;
        7)
            echo -e "${GREEN}启动服务...${RESET}"
            systemctl start tun2socks.service
            ;;
        8)
            echo -e "${YELLOW}停止服务...${RESET}"
            systemctl stop tun2socks.service
            ;;
        9)
            echo -e "${GREEN}重启服务...${RESET}"
            systemctl restart tun2socks.service
            ;;
        10)
            echo -e "${GREEN}查看服务日志...${RESET}"
            journalctl -u tun2socks.service -f
            ;;
        0)
            echo -e "${YELLOW}退出菜单.${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}无效选项，请重新选择.${RESET}"
            ;;
    esac
    echo -e "${YELLOW}按回车返回菜单...${RESET}"
    read -r
done
