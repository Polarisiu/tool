#!/bin/bash
# VPS SWAP 管理脚本 (默认添加 1G)

SWAP_FILE="/swapfile"

menu() {
    clear
    echo "========== VPS SWAP 管理 =========="
    echo "1. 添加 SWAP (默认 1G)"
    echo "2. 删除 SWAP"
    echo "3. 查看 SWAP"
    echo "0. 退出"
    echo "==================================="
    read -p "请输入选项 [0-3]: " choice
    case $choice in
        1) add_swap ;;
        2) del_swap ;;
        3) view_swap ;;
        0) exit 0 ;;
        *) echo "❌ 无效选项"; sleep 2; menu ;;
    esac
}

add_swap() {
    read -p "请输入要添加的 SWAP 大小(单位G, 默认1): " SWAP_SIZE
    SWAP_SIZE=${SWAP_SIZE:-1}  # 默认 1G

    # 关闭已有 swap
    swapoff -a 2>/dev/null
    # 删除旧文件
    [ -f $SWAP_FILE ] && rm -f $SWAP_FILE
    # 创建 swap 文件
    fallocate -l ${SWAP_SIZE}G $SWAP_FILE || dd if=/dev/zero of=$SWAP_FILE bs=1M count=$((SWAP_SIZE*1024))
    chmod 600 $SWAP_FILE
    mkswap $SWAP_FILE
    swapon $SWAP_FILE
    # 写入 fstab
    if ! grep -q "$SWAP_FILE" /etc/fstab; then
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
    fi
    echo "✅ 已成功添加 ${SWAP_SIZE}G SWAP"
    sleep 2
    menu
}

del_swap() {
    swapoff -a 2>/dev/null
    sed -i "\|$SWAP_FILE|d" /etc/fstab
    [ -f $SWAP_FILE ] && rm -f $SWAP_FILE
    echo "✅ 已删除 SWAP"
    sleep 2
    menu
}

view_swap() {
    echo "========== 系统 SWAP 状态 =========="
    free -h
    swapon --show
    echo "==================================="
    read -p "按回车返回菜单..." 
    menu
}

menu
