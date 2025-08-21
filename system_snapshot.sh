#!/bin/bash

# 增强版交互式系统快照备份工具安装脚本
# 包含更智能的配置选项和远程目录管理

# 颜色设置
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志文件
LOG_FILE="/root/snapshot_install.log"

# 日志函数
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# 错误处理函数
error_exit() {
    log "${RED}错误: $1${NC}"
    exit 1
}

# 显示带边框的标题
show_title() {
    local title="$1"
    local width=60
    local padding=$(( (width - ${#title}) / 2 ))
    
    echo -e "\n${BLUE}$(printf '=%.0s' {1..60})${NC}"
    echo -e "${BLUE}$(printf ' %.0s' {1..$padding})${CYAN}$title${BLUE}$(printf ' %.0s' {1..$padding})${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..60})${NC}\n"
}

# 验证必要条件
check_requirements() {
    if [ "$EUID" -ne 0 ]; then 
        error_exit "请使用root权限运行此脚本"
    fi
    
    # 检查必要的命令
    for cmd in curl ssh rsync tar git hostname; do
        if ! command -v $cmd &> /dev/null; then
            log "${YELLOW}安装 $cmd...${NC}"
            apt-get update && apt-get install -y $cmd || error_exit "无法安装 $cmd"
        fi
    done
}

# 配置收集函数
collect_config() {
    show_title "系统快照备份配置向导"
    
    # Telegram配置
    log "${YELLOW}📱 Telegram 通知配置:${NC}"
    read -p "请输入 Telegram Bot Token: " BOT_TOKEN
    while [ -z "$BOT_TOKEN" ]; do
        log "${RED}Bot Token 不能为空${NC}"
        read -p "请输入 Telegram Bot Token: " BOT_TOKEN
    done
    
    read -p "请输入 Telegram Chat ID: " CHAT_ID
    while [ -z "$CHAT_ID" ]; do
        log "${RED}Chat ID 不能为空${NC}"
        read -p "请输入 Telegram Chat ID: " CHAT_ID
    done
    echo
    
    # 远程服务器配置
    log "${YELLOW}🌐 远程服务器配置:${NC}"
    read -p "请输入远程服务器IP地址: " TARGET_IP
    while [ -z "$TARGET_IP" ]; do
        log "${RED}IP地址不能为空${NC}"
        read -p "请输入远程服务器IP地址: " TARGET_IP
    done
    
    read -p "请输入远程服务器用户名: " TARGET_USER
    while [ -z "$TARGET_USER" ]; do
        log "${RED}用户名不能为空${NC}"
        read -p "请输入远程服务器用户名: " TARGET_USER
    done
    
    read -p "请输入SSH端口 [默认: 8000]: " SSH_PORT
    SSH_PORT=${SSH_PORT:-8000}
    echo
    
    # 远程目录配置
    log "${YELLOW}📁 远程存储配置:${NC}"
    read -p "请输入远程基础备份目录 [默认: /Volumes/SamsungHD/remote_backup]: " TARGET_BASE_DIR
    TARGET_BASE_DIR=${TARGET_BASE_DIR:-/Volumes/SamsungHD/remote_backup}
    
    # 本机目录名配置
    HOSTNAME=$(hostname)
    log "\n${CYAN}ℹ️ 本机将在远程创建目录: $TARGET_BASE_DIR/$HOSTNAME${NC}"
    read -p "是否使用默认目录名 '$HOSTNAME'? [Y/n]: " USE_DEFAULT_HOSTNAME
    if [[ "$USE_DEFAULT_HOSTNAME" =~ ^[Nn]$ ]]; then
        read -p "请输入自定义目录名: " CUSTOM_HOSTNAME
        while [ -z "$CUSTOM_HOSTNAME" ]; do
            log "${RED}目录名不能为空${NC}"
            read -p "请输入自定义目录名: " CUSTOM_HOSTNAME
        done
        REMOTE_DIR_NAME="$CUSTOM_HOSTNAME"
    else
        REMOTE_DIR_NAME="$HOSTNAME"
    fi
    
    FULL_REMOTE_PATH="$TARGET_BASE_DIR/$REMOTE_DIR_NAME"
    log "${GREEN}✓ 远程完整路径: $FULL_REMOTE_PATH${NC}"
    echo
    
    # 本地配置
    log "${YELLOW}💾 本地配置:${NC}"
    read -p "请输入本地备份目录 [默认: /backups]: " BACKUP_DIR
    BACKUP_DIR=${BACKUP_DIR:-/backups}
    
    # 保留策略配置
    log "\n${YELLOW}🗄️ 备份保留策略:${NC}"
    log "本地快照保留数量（保留最近的N个快照）"
    read -p "请输入本地保留快照数量 [默认: 2]: " LOCAL_SNAPSHOT_KEEP
    LOCAL_SNAPSHOT_KEEP=${LOCAL_SNAPSHOT_KEEP:-2}
    
    log "\n远程快照保留天数（自动删除N天前的快照）"
    read -p "请输入远程快照保留天数 [默认: 15]: " REMOTE_SNAPSHOT_DAYS
    REMOTE_SNAPSHOT_DAYS=${REMOTE_SNAPSHOT_DAYS:-15}
    echo
    
    # 自动执行间隔配置
    log "${YELLOW}⏰ 自动执行配置:${NC}"
    log "系统可以每N天自动执行一次备份（1-30天）"
    read -p "请输入备份间隔天数 [默认: 5]: " BACKUP_INTERVAL_DAYS
    BACKUP_INTERVAL_DAYS=${BACKUP_INTERVAL_DAYS:-5}
    
    # 确保输入值在合理范围内
    while [[ ! "$BACKUP_INTERVAL_DAYS" =~ ^[1-9]$|^[1-2][0-9]$|^30$ ]]; do
        log "${RED}请输入1-30之间的数字${NC}"
        read -p "请输入备份间隔天数 [默认: 5]: " BACKUP_INTERVAL_DAYS
        BACKUP_INTERVAL_DAYS=${BACKUP_INTERVAL_DAYS:-5}
    done
    
    log "\n${CYAN}ℹ️ 系统将每${BACKUP_INTERVAL_DAYS}天自动执行一次备份（随机延迟最长12小时）${NC}"
    
    read -p "是否需要立即执行一次快照测试？[Y/n]: " RUN_NOW
    RUN_NOW=${RUN_NOW:-Y}
    echo
    
    # 配置预览
    show_title "配置预览"
    log "${CYAN}远程服务器:${NC} $TARGET_USER@$TARGET_IP:$SSH_PORT"
    log "${CYAN}远程路径:${NC} $FULL_REMOTE_PATH"
    log "${CYAN}本地路径:${NC} $BACKUP_DIR"
    log "${CYAN}保留策略:${NC} 本地${LOCAL_SNAPSHOT_KEEP}个，远程${REMOTE_SNAPSHOT_DAYS}天"
    log "${CYAN}自动执行:${NC} 每${BACKUP_INTERVAL_DAYS}天一次"
    echo
    
    read -p "确认以上配置并继续？[Y/n]: " CONFIRM_CONFIG
    if [[ "$CONFIRM_CONFIG" =~ ^[Nn]$ ]]; then
        log "\n${YELLOW}配置已取消，请重新运行脚本进行配置${NC}"
        exit 0
    fi
}

# SSH密钥配置
setup_ssh_key() {
    show_title "SSH密钥配置"
    
    if [ ! -f "/root/.ssh/id_rsa" ]; then
        log "${YELLOW}生成新的SSH密钥...${NC}"
        ssh-keygen -t rsa -b 4096 -N "" -f /root/.ssh/id_rsa -q
    fi
    
    log "${YELLOW}请将以下公钥添加到远程服务器的 ~/.ssh/authorized_keys 文件中:${NC}"
    echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    cat /root/.ssh/id_rsa.pub
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
    
    read -p "已将公钥添加到远程服务器？继续测试连接... [Y/n]: " SSH_OK
    if [[ ! "$SSH_OK" =~ ^[Nn]$ ]]; then
        log "${YELLOW}测试SSH连接...${NC}"
        if ssh -p "$SSH_PORT" -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$TARGET_USER@$TARGET_IP" "echo 'SSH连接测试成功'" 2>/dev/null; then
            log "${GREEN}✓ SSH连接测试成功！${NC}\n"
            
            # 自动创建远程目录结构
            log "${YELLOW}创建远程目录结构...${NC}"
            ssh -p "$SSH_PORT" "$TARGET_USER@$TARGET_IP" "mkdir -p $FULL_REMOTE_PATH/system_snapshots $FULL_REMOTE_PATH/configs $FULL_REMOTE_PATH/logs" 2>/dev/null
            
            if [ $? -eq 0 ]; then
                log "${GREEN}✓ 远程目录创建成功: $FULL_REMOTE_PATH${NC}\n"
            else
                log "${YELLOW}⚠ 远程目录创建可能失败，请手动检查${NC}\n"
            fi
        else
            log "${RED}✗ SSH连接失败。请检查配置后重试。${NC}"
            read -p "继续安装（将跳过远程备份）？[y/N]: " CONTINUE
            if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
}

# 测试Telegram通知
test_telegram() {
    show_title "Telegram通知测试"
    
    HOSTNAME=$(hostname)
    response=$(curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="🚀 *系统快照备份工具安装测试*

📱 如果您看到此消息，说明Telegram配置成功！
🖥️ *本机名称*: \`$REMOTE_DIR_NAME\`  
🌐 *远程路径*: \`$FULL_REMOTE_PATH\`
⏰ *执行频率*: 每${BACKUP_INTERVAL_DAYS}天一次
⏱️ *时间*: \`$(date '+%F %T')\`" \
        -d parse_mode="Markdown")
    
    if [[ $response == *"\"ok\":true"* ]]; then
        log "${GREEN}✓ Telegram通知测试成功！${NC}\n"
    else
        log "${RED}✗ Telegram通知发送失败，请检查配置${NC}\n"
    fi
}

# 创建配置文件和主脚本
create_script() {
    show_title "创建备份脚本"
    
    # 创建备份目录
    mkdir -p "$BACKUP_DIR"
    
    # 创建配置文件
    log "${YELLOW}创建配置文件...${NC}"
    cat > /root/snapshot_config.conf << EOF
#!/bin/bash
# 系统快照备份配置文件
# 自动生成于: $(date '+%F %T')

# Telegram配置
BOT_TOKEN="$BOT_TOKEN"
CHAT_ID="$CHAT_ID"

# 远程服务器配置
TARGET_IP="$TARGET_IP"
TARGET_USER="$TARGET_USER"
SSH_PORT="$SSH_PORT"
TARGET_BASE_DIR="$TARGET_BASE_DIR"
REMOTE_DIR_NAME="$REMOTE_DIR_NAME"

# 本地配置
BACKUP_DIR="$BACKUP_DIR"
HOSTNAME=\$(hostname)

# 保留策略
LOCAL_SNAPSHOT_KEEP=$LOCAL_SNAPSHOT_KEEP
REMOTE_SNAPSHOT_DAYS=$REMOTE_SNAPSHOT_DAYS

# 执行配置
BACKUP_INTERVAL_DAYS=$BACKUP_INTERVAL_DAYS

# 日志文件
LOG_FILE="/root/snapshot_log.log"
DEBUG_LOG="/root/snapshot_debug.log"
EOF

    # 创建主备份脚本
    log "${YELLOW}创建主备份脚本...${NC}"
    cat > /root/system_snapshot.sh << 'EOF'
#!/bin/bash

# 加载配置
source /root/snapshot_config.conf

# 命名与路径设置
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
FILEDATE=$(date '+%F %T')
mkdir -p "$BACKUP_DIR"
SNAPSHOT_FILE="$BACKUP_DIR/system_snapshot_${TIMESTAMP}.tar.gz"

# 远程完整路径
FULL_REMOTE_PATH="$TARGET_BASE_DIR/$REMOTE_DIR_NAME"

# 日志功能
log_debug() {
    echo "$(date '+%F %T') [DEBUG] $1" >> "$DEBUG_LOG"
}

log_info() {
    echo "$(date '+%F %T') [INFO] $1" >> "$LOG_FILE"
    log_debug "$1"
}

log_error() {
    echo "$(date '+%F %T') [ERROR] $1" >> "$LOG_FILE"
    log_debug "$1"
}

# systemd定时器设置（动态间隔天数）
setup_systemd_timer() {
    SCRIPT_PATH=$(realpath "$0")
    SERVICE_NAME="system-snapshot"
    SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"
    TIMER_FILE="/etc/systemd/system/${SERVICE_NAME}.timer"
    
    log_debug "设置systemd定时器，脚本路径: $SCRIPT_PATH"
    
    if [ -f "$TIMER_FILE" ]; then
        log_debug "systemd定时器已存在，更新配置..."
        systemctl stop "${SERVICE_NAME}.timer" 2>/dev/null
    else
        log_info "创建新的systemd定时器..."
    fi
    
    cat > "$SERVICE_FILE" << EOFSERVICE
[Unit]
Description=System Snapshot Backup Service
After=network.target

[Service]
Type=oneshot
ExecStart=$SCRIPT_PATH
Environment="SYSTEMD_TIMER=1"
WorkingDirectory=/root

[Install]
WantedBy=multi-user.target
EOFSERVICE

    cat > "$TIMER_FILE" << EOFTIMER
[Unit]
Description=Run System Snapshot Every ${BACKUP_INTERVAL_DAYS} Days at Random Time

[Timer]
OnCalendar=*-*-1/${BACKUP_INTERVAL_DAYS} 00:00:00
RandomizedDelaySec=12h
Persistent=true

[Install]
WantedBy=timers.target
EOFTIMER

    chmod 644 "$SERVICE_FILE" "$TIMER_FILE"
    systemctl daemon-reload
    systemctl enable "${SERVICE_NAME}.timer"
    systemctl start "${SERVICE_NAME}.timer"
    
    NEXT_RUN=$(systemctl list-timers "${SERVICE_NAME}.timer" 2>/dev/null | grep "${SERVICE_NAME}" | awk '{print $3" "$4" "$5}')
    
    log_info "systemd定时器已设置: 每${BACKUP_INTERVAL_DAYS}天随机执行一次"
    
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
      -d chat_id="$CHAT_ID" \
      -d text="⏰ *系统快照定时任务更新* 

🔄 *频率*: 每${BACKUP_INTERVAL_DAYS}天一次 (随机时间)
⏱️ *下次执行*: ${NEXT_RUN:-'计算中...'}
🖥️ *本机*: \`$REMOTE_DIR_NAME\`
📁 *远程路径*: \`$FULL_REMOTE_PATH\`" \
      -d parse_mode="Markdown"
}

# 创建快照
create_snapshot() {
    log_info "开始创建系统快照..."
    
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
      -d chat_id="$CHAT_ID" \
      -d text="🔄 开始创建系统快照

🖥️ *本机*: \`$REMOTE_DIR_NAME\`
⏰ *时间*: \`$(date '+%F %T')\`" \
      -d parse_mode="Markdown"
    
    cd / && \
    tar -czf "$SNAPSHOT_FILE" \
      --exclude="dev/*" \
      --exclude="proc/*" \
      --exclude="sys/*" \
      --exclude="tmp/*" \
      --exclude="run/*" \
      --exclude="mnt/*" \
      --exclude="media/*" \
      --exclude="lost+found" \
      --exclude="var/cache/*" \
      --exclude="var/tmp/*" \
      --exclude="var/log/*" \
      --exclude="var/lib/apt/lists/*" \
      --exclude="usr/share/doc/*" \
      --exclude="usr/share/man/*" \
      --exclude="backups/*" \
      --exclude="*.log" \
      --warning=no-file-changed \
      --warning=no-file-ignored \
      etc usr var root home opt bin sbin lib lib64 > /tmp/snapshot_output.log 2>/tmp/snapshot_error.log
    
    TAR_STATUS=$?
    
    if [ $TAR_STATUS -ne 0 ]; then
      ERROR_MSG=$(cat /tmp/snapshot_error.log)
      log_error "tar命令退出状态非零: $TAR_STATUS"
      
      if [ -f "$SNAPSHOT_FILE" ] && [ -s "$SNAPSHOT_FILE" ]; then
        SNAPSHOT_SIZE=$(du -h "$SNAPSHOT_FILE" | cut -f1)
        log_info "快照文件已创建: $SNAPSHOT_FILE ($SNAPSHOT_SIZE)"
        TAR_STATUS=0
      else
        log_error "快照创建失败"
        curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
          -d chat_id="$CHAT_ID" \
          -d text="❌ *系统快照失败* | \`$REMOTE_DIR_NAME\`
          
⚠️ *错误*: \`\`\`
$ERROR_MSG
\`\`\`" \
          -d parse_mode="Markdown"
        exit 1
      fi
    fi
    
    SNAPSHOT_SIZE=$(du -h "$SNAPSHOT_FILE" | cut -f1)
    log_info "快照创建成功: $SNAPSHOT_FILE ($SNAPSHOT_SIZE)"
    
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
      -d chat_id="$CHAT_ID" \
      -d text="📸 *系统快照创建成功* 

🖥️ *本机*: \`$REMOTE_DIR_NAME\`
📦 *文件*: \`system_snapshot_${TIMESTAMP}.tar.gz\`
📏 *大小*: \`$SNAPSHOT_SIZE\`
🕒 *时间*: \`$FILEDATE\`" \
      -d parse_mode="Markdown"
}

# 清理本地旧快照
cleanup_local() {
    log_info "清理本地旧快照..."
    find "$BACKUP_DIR" -maxdepth 1 -type f -name "system_snapshot_*.tar.gz" | sort -r | tail -n +$((LOCAL_SNAPSHOT_KEEP+1)) | xargs -r rm -f
}

# 上传到远程
upload_snapshot() {
    log_info "开始上传快照到远程服务器..."
    
    ssh -p "$SSH_PORT" -o ConnectTimeout=10 "$TARGET_USER@$TARGET_IP" "echo 连接测试" > /dev/null 2>/tmp/ssh_error.log
    SSH_STATUS=$?
    
    if [ $SSH_STATUS -ne 0 ]; then
      log_error "无法连接到远程服务器"
      curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="⚠️ *无法连接到远程服务器* - 快照已保存在本地
        
🖥️ *本机*: \`$REMOTE_DIR_NAME\`
🌐 *远程服务器*: \`$TARGET_USER@$TARGET_IP:$SSH_PORT\`
📁 *预定路径*: \`$FULL_REMOTE_PATH\`" \
        -d parse_mode="Markdown"
    else
      rsync -avz --inplace --partial --timeout=60 --progress \
        -e "ssh -p $SSH_PORT" "$SNAPSHOT_FILE" "$TARGET_USER@$TARGET_IP:$FULL_REMOTE_PATH/system_snapshots/" 2>/tmp/rsync_error.log
      
      RSYNC_STATUS=$?
      
      if [ $RSYNC_STATUS -eq 0 ]; then
        SNAPSHOT_FILENAME=$(basename "$SNAPSHOT_FILE")
        log_info "快照上传成功"
        
        curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
          -d chat_id="$CHAT_ID" \
          -d text="📤 *系统快照上传成功* ✅
          
🖥️ *本机*: \`$REMOTE_DIR_NAME\`
📦 *文件*: \`$SNAPSHOT_FILENAME\`
📁 *远程路径*: \`$FULL_REMOTE_PATH/system_snapshots/\`
🕒 *时间*: \`$FILEDATE\`" \
          -d parse_mode="Markdown"
      else
        RSYNC_ERROR=$(cat /tmp/rsync_error.log)
        log_error "快照上传失败: $RSYNC_ERROR"
      fi
      
      ssh -p "$SSH_PORT" "$TARGET_USER@$TARGET_IP" "find $FULL_REMOTE_PATH/system_snapshots -type f -name '*.tar.gz' -mtime +$REMOTE_SNAPSHOT_DAYS -delete"
    fi
}

# 主执行流程
if [ -z "$SYSTEMD_TIMER" ]; then
    setup_systemd_timer
fi

create_snapshot
cleanup_local
upload_snapshot

# 完成通知
LOCAL_SNAPSHOT_COUNT=$(find "$BACKUP_DIR" -maxdepth 1 -type f -name "system_snapshot_*.tar.gz" | wc -l)

curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
  -d chat_id="$CHAT_ID" \
  -d text="🔄 *系统快照操作完成* \`$REMOTE_DIR_NAME\`

⏱️ *完成时间*: \`$(date '+%F %T')\`
📂 *本地快照*: \`${LOCAL_SNAPSHOT_COUNT}个\`
☁️ *远程保留*: \`${REMOTE_SNAPSHOT_DAYS}天\`
💾 *本地路径*: \`$BACKUP_DIR\`
📁 *远程路径*: \`$FULL_REMOTE_PATH\`" \
  -d parse_mode="Markdown"

log_info "系统快照操作全部完成"
EOF

    chmod +x /root/system_snapshot.sh
    chmod 600 /root/snapshot_config.conf
    
    log "${GREEN}✓ 脚本创建完成！${NC}\n"
}

# 主流程
main() {
    clear
    show_title "系统快照备份工具安装向导"
    
    # 检查环境
    check_requirements
    
    # 收集配置
    collect_config
    
    # 配置SSH
    setup_ssh_key
    
    # 测试Telegram
    test_telegram
    
    # 创建脚本
    create_script
    
    # 是否立即执行测试
    if [[ "$RUN_NOW" =~ ^[Yy]$ ]]; then
        log "${YELLOW}正在执行测试运行...${NC}"
        bash /root/system_snapshot.sh
    fi
    
    show_title "安装完成"
    log "${GREEN}✓ 系统快照备份工具安装成功！${NC}\n"
    
    log "${CYAN}配置文件位置:${NC} /root/snapshot_config.conf"
    log "${CYAN}主脚本位置:${NC} /root/system_snapshot.sh"
    log "${CYAN}日志位置:${NC} /root/snapshot_log.log"
    log "${CYAN}远程路径:${NC} $FULL_REMOTE_PATH"
    echo
    log "${YELLOW}定时任务设置:${NC} 每${BACKUP_INTERVAL_DAYS}天自动执行"
    log "${YELLOW}手动运行命令:${NC} bash /root/system_snapshot.sh"
    log "${YELLOW}修改配置命令:${NC} nano /root/snapshot_config.conf"
    echo
    log "${BLUE}如需重新配置定时器，编辑配置文件后运行主脚本即可自动更新${NC}"
    echo
}

# 运行主程序
main
