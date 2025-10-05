#!/bin/bash
# ========================================
# Rclone 管理菜单 (终极安全版，systemd 直接启动)
# ========================================

# 颜色
green="\033[32m"
yellow="\033[33m"
red="\033[31m"
plain="\033[0m"

# 显示菜单
show_menu() {
    clear
    echo -e "${green}====== Rclone 管理菜单 =======${plain}"
    echo -e "${green} 1. 安装 Rclone${plain}"
    echo -e "${green} 2. 卸载 Rclone${plain}"
    echo -e "${green} 3. 配置 Rclone${plain}"
    echo -e "${green} 4. 挂载远程存储到本地${plain}"
    echo -e "${green} 5. 同步 本地 → 远程${plain}"
    echo -e "${green} 6. 同步 远程 → 本地${plain}"
    echo -e "${green} 7. 查看远程存储文件${plain}"
    echo -e "${green} 8. 查看远程存储列表${plain}"
    echo -e "${green} 9. 卸载挂载点${plain}"
    echo -e "${green}10. 查看当前挂载点${plain}"
    echo -e "${green}11. 卸载所有挂载点${plain}"
    echo -e "${green}12. 设置开机启动${plain}"
    echo -e "${green} 0. 退出${plain}${plain}"
}

# 安装 Rclone
install_rclone() {
    echo -e "${yellow}正在安装 Rclone...${plain}"
    sudo -v
    curl https://rclone.org/install.sh | sudo bash
    echo -e "${green}Rclone 安装完成！${plain}"
}

# 卸载 Rclone（含 systemd 服务文件和挂载 PID）
uninstall_rclone() {
    echo -e "${yellow}正在卸载 Rclone...${plain}"

    # 删除 rclone 二进制
    sudo rm -f /usr/bin/rclone /usr/local/bin/rclone

    # 停止并删除所有 systemd 服务
    sudo systemctl stop 'rclone-mount@*' 2>/dev/null
    sudo systemctl disable 'rclone-mount@*' 2>/dev/null
    sudo rm -f /etc/systemd/system/rclone-mount@*.service
    sudo systemctl daemon-reload

    # 删除 PID 文件
    sudo rm -f /var/run/rclone_*.pid

    echo -e "${green}Rclone 及所有 systemd 挂载服务已卸载！${plain}"
}

# 配置 Rclone
config_rclone() {
    rclone config
}

# 列出远程
list_remotes() {
    rclone listremotes
}

# 挂载远程（增加挂载前检查）
mount_remote() {
    read -p "请输入远程名称: " remote
    [ -z "$remote" ] && { echo -e "${red}远程名称不能为空${plain}"; return; }

    path="/mnt/$remote"
    read -p "请输入挂载路径 (默认 $path): " input_path
    path=${input_path:-$path}
    mkdir -p "$path"

    # 检查是否已挂载
    if mount | grep -q "on $path type"; then
        echo -e "${yellow}$remote 已经挂载在 $path，无需重复挂载${plain}"
        return
    fi

    log="/var/log/rclone_${remote}.log"
    pidfile="/var/run/rclone_${remote}.pid"

    echo -e "${yellow}正在挂载 $remote 到 $path，日志: $log${plain}"

    nohup rclone mount "${remote}:" "$path" --allow-other --vfs-cache-mode writes --dir-cache-time 1000h &> "$log" &
    pid=$!
    echo $pid > "$pidfile"
    echo -e "${green}$remote 已挂载到 $path，PID: $pid${plain}"
}

# 卸载挂载 (按远程名称)
unmount_remote_by_name() {
    read -p "请输入远程名称: " remote
    [ -z "$remote" ] && { echo -e "${red}远程名称不能为空${plain}"; return; }

    pidfile="/var/run/rclone_${remote}.pid"
    path="/mnt/$remote"

    if [ -f "$pidfile" ]; then
        fusermount -u "$path" 2>/dev/null || umount "$path" 2>/dev/null
        rm -f "$pidfile"
        echo -e "${green}已卸载远程: $remote${plain}"
    else
        echo -e "${red}找不到 $remote 的挂载 PID 文件${plain}"
    fi
}

# 卸载所有挂载
unmount_all() {
    echo -e "${yellow}正在卸载所有 rclone 挂载点...${plain}"
    for pidfile in /var/run/rclone_*.pid; do
        [ -f "$pidfile" ] || continue
        remote=$(basename "$pidfile" | sed 's/rclone_//;s/\.pid//')
        path="/mnt/$remote"
        fusermount -u "$path" 2>/dev/null || umount "$path" 2>/dev/null
        rm -f "$pidfile"
        echo -e "${green}已卸载 $remote${plain}"
    done
}

# 查看挂载
show_mounts() {
    echo -e "${yellow}当前 rclone 挂载点:${plain}"
    mount | grep rclone || echo -e "${red}暂无 rclone 挂载点${plain}"
}

# 同步 本地 → 远程
sync_local_to_remote() {
    read -p "请输入本地目录路径: " local
    [ -z "$local" ] || [ ! -d "$local" ] && { echo -e "${red}本地路径不存在${plain}"; return; }
    read -p "请输入远程名称: " remote
    [ -z "$remote" ] && { echo -e "${red}远程名称不能为空${plain}"; return; }
    read -p "请输入远程目录 (默认 backup): " remote_dir
    remote_dir=${remote_dir:-backup}

    echo -e "${yellow}正在同步 $local → ${remote}:$remote_dir${plain}"
    rclone sync "$local" "${remote}:$remote_dir" -v -P
}

# 同步 远程 → 本地
sync_remote_to_local() {
    read -p "请输入远程名称: " remote
    [ -z "$remote" ] && { echo -e "${red}远程名称不能为空${plain}"; return; }
    read -p "请输入本地目录路径: " local
    [ -z "$local" ] && { echo -e "${red}本地路径不能为空${plain}"; return; }
    read -p "请输入远程目录 (默认 backup): " remote_dir
    remote_dir=${remote_dir:-backup}

    echo -e "${yellow}正在同步 ${remote}:$remote_dir → $local${plain}"
    rclone sync "${remote}:$remote_dir" "$local" -v -P
}

# 查看远程文件
list_files_remote() {
    read -p "请输入远程名称: " remote
    [ -z "$remote" ] && { echo -e "${red}远程名称不能为空${plain}"; return; }
    rclone ls "${remote}:"
}

# 生成 systemd 服务文件并直接启用启动
generate_systemd_service() {
    read -p "请输入远程名称 (用于服务文件): " remote
    [ -z "$remote" ] && { echo -e "${red}远程名称不能为空${plain}"; return; }

    path="/mnt/$remote"
    mkdir -p "$path"

    service_file="/etc/systemd/system/rclone-mount@${remote}.service"
    sudo tee "$service_file" >/dev/null <<EOF
[Unit]
Description=Rclone Mount ${remote}
After=network-online.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/rclone mount ${remote}: $path --allow-other --vfs-cache-mode writes --dir-cache-time 1000h
ExecStop=/bin/fusermount -u $path
Restart=always
RestartSec=10
StandardOutput=append:/var/log/rclone_${remote}.log
StandardError=append:/var/log/rclone_${remote}.log

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable rclone-mount@${remote}
    sudo systemctl start rclone-mount@${remote}

    echo -e "${green}Systemd 服务文件已生成并启动: $service_file${plain}"
    echo -e "${yellow}服务已启用开机自启并启动运行${plain}"
}

# 主循环
while true; do
    show_menu
    read -p "请输入选项: " choice
    case $choice in
        1) install_rclone ;;
        2) uninstall_rclone ;;
        3) config_rclone ;;
        4) mount_remote ;;
        5) sync_local_to_remote ;;
        6) sync_remote_to_local ;;
        7) list_files_remote ;;
        8) list_remotes ;;
        9) unmount_remote_by_name ;;
        10) show_mounts ;;
        11) unmount_all ;;
        12) generate_systemd_service ;;
        0)  exit 0 ;;
        *) echo -e "${red}无效选项，请重新输入${plain}" ;;
    esac
    read -r -p "按回车继续..."
done
