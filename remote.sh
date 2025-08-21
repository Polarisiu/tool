#!/bin/bash

# ==========================================
# 终极增强版远程系统快照恢复工具
# 支持远程同步、标准/完全恢复、进度条、依赖自动安装
# ==========================================

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'
LOG_FILE="/var/log/remote_restore.log"

log() {
    echo -e "[$(date '+%F %T')] $1" | tee -a "$LOG_FILE"
}

clear
echo -e "${BLUE}=================================================${NC}"
echo -e "${BLUE}                远程系统快照恢复工具              ${NC}"
echo -e "${BLUE}=================================================${NC}"
echo ""

# 远程服务器配置
read -p "请输入远程服务器IP: " REMOTE_IP
read -p "请输入远程服务器用户名: " REMOTE_USER
read -p "请输入SSH端口 [默认: 22]: " SSH_PORT
SSH_PORT=${SSH_PORT:-22}
read -p "请输入远程备份目录: " REMOTE_BACKUP_DIR

# 系统类型检测
OS_TYPE=$(awk -F= '/^ID=/{print $2}' /etc/os-release | tr -d '"')
log "检测系统类型: $OS_TYPE"

# 自动安装 rsync
if ! command -v rsync &>/dev/null; then
    log "${YELLOW}未检测到 rsync，正在安装...${NC}"
    if [[ "$OS_TYPE" =~ (ubuntu|debian) ]]; then
        apt-get update && apt-get install -y rsync
    elif [[ "$OS_TYPE" =~ (centos|rhel) ]]; then
        yum install -y rsync
    else
        log "${RED}无法自动安装 rsync，请手动安装${NC}"
        exit 1
    fi
fi

# 自动安装 pv
if ! command -v pv &>/dev/null; then
    log "${YELLOW}未检测到 pv，正在安装...${NC}"
    if [[ "$OS_TYPE" =~ (ubuntu|debian) ]]; then
        apt-get update && apt-get install -y pv
    elif [[ "$OS_TYPE" =~ (centos|rhel) ]]; then
        yum install -y pv
    fi
fi

# 临时同步目录
TMP_DIR="/tmp/remote_backup_$(date +%s)"
mkdir -p "$TMP_DIR"

# 同步远程备份
log "${BLUE}从远程服务器同步备份到本地...${NC}"
rsync -avz -e "ssh -p $SSH_PORT" "$REMOTE_USER@$REMOTE_IP:$REMOTE_BACKUP_DIR/" "$TMP_DIR/"
RSYNC_RESULT=$?
if [ $RSYNC_RESULT -ne 0 ]; then
    log "${RED}错误: 从远程同步备份失败! rsync 返回码: $RSYNC_RESULT${NC}"
    exit 1
fi

# 查找快照文件
SNAPSHOT_FILES=($(find "$TMP_DIR" -maxdepth 1 -type f -name "system_snapshot_*.tar.gz" | sort -r))
if [ ${#SNAPSHOT_FILES[@]} -eq 0 ]; then
    log "${RED}错误: 未找到快照文件!${NC}"
    exit 1
fi

# 显示可用快照
log "${YELLOW}可用的快照:${NC}"
for i in "${!SNAPSHOT_FILES[@]}"; do
    SNAPSHOT_PATH="${SNAPSHOT_FILES[$i]}"
    SNAPSHOT_NAME=$(basename "$SNAPSHOT_PATH")
    SNAPSHOT_SIZE=$(du -h "$SNAPSHOT_PATH" | cut -f1)
    SNAPSHOT_DATE=$(date -r "$SNAPSHOT_PATH" "+%F %T")
    echo -e "$((i+1))) ${GREEN}$SNAPSHOT_NAME${NC} (${SNAPSHOT_SIZE}, ${SNAPSHOT_DATE})"
done

read -p "请选择要恢复的快照编号 [1-${#SNAPSHOT_FILES[@]}]: " SNAPSHOT_CHOICE
if ! [[ "$SNAPSHOT_CHOICE" =~ ^[0-9]+$ ]] || [ "$SNAPSHOT_CHOICE" -lt 1 ] || [ "$SNAPSHOT_CHOICE" -gt ${#SNAPSHOT_FILES[@]} ]; then
    log "${RED}错误: 无效选择!${NC}"
    exit 1
fi
SELECTED_SNAPSHOT="${SNAPSHOT_FILES[$((SNAPSHOT_CHOICE-1))]}"
SNAPSHOT_NAME=$(basename "$SELECTED_SNAPSHOT")

# SHA256 校验
if [ -f "${SELECTED_SNAPSHOT}.sha256" ]; then
    sha256sum -c "${SELECTED_SNAPSHOT}.sha256" --quiet
    if [ $? -ne 0 ]; then
        log "${RED}警告: SHA256 校验失败!${NC}"
        read -p "是否继续恢复? [y/N]: " CONTINUE_CHECK
        [[ "$CONTINUE_CHECK" =~ ^[Yy]$ ]] || exit 1
    fi
fi

# 确认恢复
log "\n${YELLOW}准备恢复系统快照: ${GREEN}$SNAPSHOT_NAME${NC}"
log "${RED}警告: 恢复操作不可撤销!${NC}"
read -p "是否继续? [y/N]: " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { log "${YELLOW}恢复已取消.${NC}"; exit 0; }

# 选择恢复模式
echo -e "\n${YELLOW}请选择恢复模式:${NC}"
echo -e "1) ${GREEN}标准恢复${NC} ${YELLOW}(推荐)${NC} - 保留网络配置"
echo -e "2) ${GREEN}完全恢复${NC} - 恢复所有文件"
read -p "请选择恢复模式 [1-2]: " RESTORE_MODE
[[ "$RESTORE_MODE" =~ ^[1-2]$ ]] || { log "${RED}错误: 无效选择!${NC}"; exit 1; }

# 网络配置备份
if [ "$RESTORE_MODE" -eq 1 ]; then
    log "${BLUE}备份当前网络和系统配置...${NC}"
    BACKUP_DIR="/root/system_backup_$(date +%s)"
    mkdir -p "$BACKUP_DIR"
    cp /etc/fstab "$BACKUP_DIR/fstab.bak" 2>/dev/null
    cp /etc/hostname "$BACKUP_DIR/hostname.bak" 2>/dev/null
    cp /etc/hosts "$BACKUP_DIR/hosts.bak" 2>/dev/null
    cp /etc/resolv.conf "$BACKUP_DIR/resolv.conf.bak" 2>/dev/null

    if [[ "$OS_TYPE" =~ (ubuntu|debian) ]]; then
        cp /etc/network/interfaces "$BACKUP_DIR/interfaces.bak" 2>/dev/null
        cp -r /etc/netplan "$BACKUP_DIR/netplan" 2>/dev/null
    elif [[ "$OS_TYPE" =~ (centos|rhel) ]]; then
        cp -r /etc/sysconfig/network-scripts "$BACKUP_DIR/network-scripts" 2>/dev/null
    fi
fi

# 停止关键服务
log "${BLUE}停止关键服务...${NC}"
ACTIVE_SERVICES=$(systemctl list-units --type=service --state=running | awk '{print $1}')
for service in $ACTIVE_SERVICES; do
    [[ "$service" =~ (nginx|apache2|httpd|mysql|mariadb|docker) ]] && systemctl stop "$service" 2>/dev/null && log "停止服务: $service"
done

# 恢复快照（带进度条）
log "${BLUE}正在恢复系统文件 (显示进度)...${NC}"
if [ "$RESTORE_MODE" -eq 1 ]; then
    pv "$SELECTED_SNAPSHOT" | tar -xzf - -C / \
        --exclude="dev/*" --exclude="proc/*" --exclude="sys/*" --exclude="run/*" --exclude="tmp/*" \
        --exclude="backups/*" --exclude="etc/fstab" --exclude="etc/hostname" --exclude="etc/hosts" \
        --exclude="etc/resolv.conf" --exclude="etc/network/*" --exclude="etc/netplan/*"
else
    pv "$SELECTED_SNAPSHOT" | tar -xzf - -C / \
        --exclude="dev/*" --exclude="proc/*" --exclude="sys/*" --exclude="run/*" --exclude="tmp/*" --exclude="backups/*"
fi
[ $? -ne 0 ] && { log "${RED}错误: 恢复失败!${NC}"; exit 1; }

# 恢复网络配置
if [ "$RESTORE_MODE" -eq 1 ]; then
    log "${BLUE}恢复网络配置...${NC}"
    cp "$BACKUP_DIR/fstab.bak" /etc/fstab 2>/dev/null
    cp "$BACKUP_DIR/hostname.bak" /etc/hostname 2>/dev/null
    cp "$BACKUP_DIR/hosts.bak" /etc/hosts 2>/dev/null
    cp "$BACKUP_DIR/resolv.conf.bak" /etc/resolv.conf 2>/dev/null
    [[ "$OS_TYPE" =~ (ubuntu|debian) ]] && cp "$BACKUP_DIR/interfaces.bak" /etc/network/interfaces 2>/dev/null && cp -r "$BACKUP_DIR/netplan/*" /etc/netplan/
    [[ "$OS_TYPE" =~ (centos|rhel) ]] && cp -r "$BACKUP_DIR/network-scripts/*" /etc/sysconfig/network-scripts/
fi

log "${GREEN}系统快照恢复完成!${NC}"
[ "$RESTORE_MODE" -eq 1 ] && log "${BLUE}已保留当前网络配置.${NC}" || log "${YELLOW}已恢复所有设置，包括网络配置.${NC}"

# 自动/手动重启
REBOOT_CMD=""
[ -x /sbin/reboot ] && REBOOT_CMD="/sbin/reboot"
[ -x /usr/sbin/reboot ] && REBOOT_CMD="/usr/sbin/reboot"
command -v shutdown &>/dev/null && REBOOT_CMD="shutdown -r now"

if [ -n "$REBOOT_CMD" ]; then
    read -p "是否立即重启系统? [y/N]: " REBOOT_CONFIRM
    [[ "$REBOOT_CONFIRM" =~ ^[Yy]$ ]] && { log "${BLUE}系统将在5秒后重启...${NC}"; sleep 5; $REBOOT_CMD; } || log "${YELLOW}请手动重启系统以完成恢复.${NC}"
else
    log "${RED}⚠ 系统无法自动重启，请手动重启${NC}"
fi