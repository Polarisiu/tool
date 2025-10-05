#!/bin/bash

# 颜色定义
GREEN="\033[32m"
YELLOW="\033[33m"
RESET="\033[0m"
RED="\033[31m"

# 记录操作日志
log_action() {
    local action="$1"
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $action" >> "$BACKUP_DIR/backup.log"
}

# 创建备份
create_backup() {
    log_action "创建备份"
    local TIMESTAMP=$(date +"%Y%m%d%H%M%S")
    read -r -p "请输入要备份的目录（多个目录用空格分隔，例如/root /home）：" input

    if [ -z "$input" ]; then
        BACKUP_PATHS=( "/etc" "/usr" "/home" )
    else
        IFS=' ' read -r -a BACKUP_PATHS <<< "$input"
    fi

    # 验证目录是否存在
    for path in "${BACKUP_PATHS[@]}"; do
        if [ ! -d "$path" ]; then
            echo "目录不存在: $path"
            return
        fi
    done

    local PREFIX=""
    for path in "${BACKUP_PATHS[@]}"; do
        dir_name=$(basename "$path")
        PREFIX+="${dir_name}_"
    done
    local PREFIX=${PREFIX%_}

    local BACKUP_NAME="${PREFIX}_$TIMESTAMP.tar.gz"

    echo -e "${GREEN}您选择的备份目录为：{RESET}"
    for path in "${BACKUP_PATHS[@]}"; do
        echo "- $path"
    done

    command -v tar >/dev/null 2>&1 || { echo "tar 未安装，请先安装"; return; }

    echo -e "${GREEN}正在创建备份 $BACKUP_NAME...{RESET}"
    tar -czvf "$BACKUP_DIR/$BACKUP_NAME" "${BACKUP_PATHS[@]}"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}备份创建成功: $BACKUP_DIR/$BACKUP_NAME${RESET}"
        log_action "备份创建成功: $BACKUP_NAME"
    else
        echo "备份创建失败！"
        log_action "备份创建失败: $BACKUP_NAME"
        return
    fi

    # 自动清理旧备份，保留最近5个
    local BACKUP_COUNT
    BACKUP_COUNT=$(ls -1t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | wc -l)
    if [ "$BACKUP_COUNT" -gt 5 ]; then
        ls -1t "$BACKUP_DIR"/*.tar.gz | tail -n +6 | xargs -r rm -f
        log_action "已清理旧备份，只保留最近5个"
    fi
}

# 恢复备份
restore_backup() {
    log_action "恢复备份"
    read -e -p "请输入要恢复的备份文件名: " BACKUP_NAME

    if [ ! -f "$BACKUP_DIR/$BACKUP_NAME" ]; then
        echo "备份文件不存在！"
        return
    fi

    read -p "恢复备份会覆盖现有文件，确定吗？(y/N): " confirm
    [ "$confirm" != "y" ] && echo "取消恢复" && return

    echo -e "${GREEN}正在恢复备份 $BACKUP_NAME...${RESET}"
    tar -xzvf "$BACKUP_DIR/$BACKUP_NAME" -C /
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}备份恢复成功！${RESET}"
        log_action "备份恢复成功: $BACKUP_NAME"
    else
        echo "备份恢复失败！"
        log_action "备份恢复失败: $BACKUP_NAME"
    fi
}

# 列出备份，最新备份高亮
list_backups() {
    echo -e "${YELLOW}可用的备份：${RESET}"
    local files
    files=($(ls -1t "$BACKUP_DIR"/*.tar.gz 2>/dev/null))
    if [ ${#files[@]} -eq 0 ]; then
        echo -e "${YELLOW}暂无备份文件${RESET}"
        return
    fi
    for i in "${!files[@]}"; do
        fname=$(basename "${files[$i]}")
        if [ $i -eq 0 ]; then
            # 最新备份高亮
            echo -e "${YELLOW}${fname}${RESET}"
        else
            echo "$fname"
        fi
    done
}

# 删除备份
delete_backup() {
    log_action "删除备份"
    read -e -p "请输入要删除的备份文件名: " BACKUP_NAME

    if [ ! -f "$BACKUP_DIR/$BACKUP_NAME" ]; then
        echo "备份文件不存在！"
        return
    fi

    rm -f "$BACKUP_DIR/$BACKUP_NAME"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}备份删除成功！${RESET}"
        log_action "备份删除成功: $BACKUP_NAME"
    else
        echo "备份删除失败！"
        log_action "备份删除失败: $BACKUP_NAME"
    fi
}

# 备份主菜单
linux_backup() {
    BACKUP_DIR="/backups"
    mkdir -p "$BACKUP_DIR"
    while true; do
        clear
        echo -e "${GREEN}=== 系统备份功能 ===${RESET}"
        echo -e "${GREEN}------------------------${RESET}"
        list_backups
        echo -e "${GREEN}------------------------${RESET}"
        echo -e "${GREEN}1. 创建备份${RESET}"
        echo -e "${GREEN}2. 恢复备份${RESET}"
        echo -e "${GREEN}3. 删除备份${RESET}"
        echo -e "${GREEN}0. 退出${RESET}"
        read -p "$(echo -e ${GREEN}请输入选项: ${RESET})" choice
        case $choice in
            1) create_backup ;;
            2) restore_backup ;;
            3) delete_backup ;;
            0) break ;;
            *) echo -e "${RED}无效选项${RESET}" ;;
        esac
        read -e -p "按回车键继续..."
    done
}

# 启动菜单
linux_backup
