#!/bin/bash
set -e

# ====== 颜色 ======
GREEN="\033[32m"
RED="\033[31m"
YELLOW="\033[33m"
RESET="\033[0m"

# ====== 检查 root ======
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}请以 root 用户运行此脚本！${RESET}"
  exit 1
fi

# ====== 自动创建 Nginx 目录 ======
mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

# ====== 安装 Certbot (snap 方式，带 nginx 插件) ======
install_certbot() {
  if ! command -v certbot >/dev/null 2>&1; then
    echo -e "${YELLOW}检测到 Certbot 未安装，正在使用 snap 安装...${RESET}"
    if ! command -v snap >/dev/null 2>&1; then
      if command -v apt >/dev/null 2>&1; then
        apt update && apt install -y snapd
      elif command -v yum >/dev/null 2>&1; then
        yum install -y epel-release
        yum install -y snapd
        systemctl enable --now snapd.socket
      fi
    fi
    snap install core
    snap refresh core
    snap install --classic certbot
    ln -sf /snap/bin/certbot /usr/bin/certbot
    echo -e "${GREEN}Certbot 安装完成${RESET}"
  fi
}

# ====== 防火墙开放端口 ======
configure_firewall() {
  REQUIRED_PORTS=(80 443)
  for port in "${REQUIRED_PORTS[@]}"; do
    if command -v ufw >/dev/null 2>&1; then
      ufw allow "$port"
    elif systemctl is-active --quiet firewalld; then
      firewall-cmd --permanent --add-port=${port}/tcp
    elif command -v iptables >/dev/null 2>&1; then
      iptables -I INPUT -p tcp --dport "$port" -j ACCEPT
    fi
  done
}

# ====== 确保 sites-enabled 被包含 ======
ensure_nginx_include() {
  if ! grep -q "sites-enabled" /etc/nginx/nginx.conf; then
    sed -i '/http {/a \    include /etc/nginx/sites-enabled/*;' /etc/nginx/nginx.conf
  fi
}

# ====== 默认 server 阻止 IP ======
create_default_server() {
  rm -f /etc/nginx/sites-enabled/default
  DEFAULT_PATH="/etc/nginx/sites-available/default_server_block"
  if [ ! -f "$DEFAULT_PATH" ]; then
    cat > "$DEFAULT_PATH" <<EOF
server {
    listen 80 default_server;
    server_name _;
    return 403;
}
EOF
    ln -sf "$DEFAULT_PATH" /etc/nginx/sites-enabled/default_server_block
  fi
}

# ====== 修复 systemd 启动，保证 443 可监听 ======
fix_systemd_nginx() {
  echo -e "${YELLOW}修复 systemd 启动问题，确保 Nginx 监听 443...${RESET}"
  systemctl stop nginx
  # 禁用 inherited sockets
  systemctl disable nginx
  systemctl daemon-reload
  # 启用并启动 Nginx
  systemctl enable nginx
  systemctl start nginx
}

# ====== 启动 Nginx ======
start_nginx() {
  fix_systemd_nginx
}

# ====== 卸载 Nginx 和 Certbot ======
uninstall_nginx() {
  echo -ne "${YELLOW}确定要卸载 Nginx、Certbot 和所有配置吗？(y/n): ${RESET}"
  read CONFIRM
  if [[ "$CONFIRM" == "y" ]]; then
    systemctl stop nginx 2>/dev/null || true
    systemctl disable nginx 2>/dev/null || true
    if command -v apt >/dev/null 2>&1; then
      apt remove --purge -y nginx nginx-common nginx-core || true
    elif command -v yum >/dev/null 2>&1; then
      yum remove -y nginx || true
    fi
    if snap list 2>/dev/null | grep -q certbot; then
      snap remove certbot
    fi
    if command -v apt >/dev/null 2>&1; then
      apt remove --purge -y certbot python3-certbot-nginx || true
    elif command -v yum >/dev/null 2>&1; then
      yum remove -y certbot python3-certbot-nginx || true
    fi
    rm -rf /etc/nginx /etc/letsencrypt /var/log/letsencrypt
    echo -e "${GREEN}Nginx 和 Certbot 已完全卸载${RESET}"
    echo -e "${YELLOW}按回车返回主菜单...${RESET}"
    read
  fi
}

# ====== 生成 Nginx 配置 ======
generate_nginx() {
  local DOMAIN=$1
  local PORT=$2
  local IS_WS=$3

  CONFIG_PATH="/etc/nginx/sites-available/$DOMAIN"
  ENABLED_PATH="/etc/nginx/sites-enabled/$DOMAIN"

  WS_HEADERS=""
  if [[ "$IS_WS" == "y" ]]; then
    WS_HEADERS="proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection \"Upgrade\";"
  fi

  cat > "$CONFIG_PATH" <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:$PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        $WS_HEADERS
    }
}
EOF

  ln -sf "$CONFIG_PATH" "$ENABLED_PATH"
  nginx -t
  start_nginx
}

# ====== 自动续期任务 ======
setup_auto_renew() {
  if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
    (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --renew-hook 'systemctl reload nginx'") | crontab -
    echo -e "${GREEN}自动续期任务已添加，每天凌晨 3 点尝试续期${RESET}"
  fi
}

# ====== 续期证书 ======
renew_certs() {
  echo -e "${GREEN}正在尝试续期所有证书...${RESET}"
  certbot renew --quiet --renew-hook "systemctl reload nginx"
  echo -e "${GREEN}证书续期完成，如果有更新，Nginx 已重载${RESET}"
  echo -e "${YELLOW}按回车返回主菜单...${RESET}"
  read
}

# ====== 查看证书有效期 ======
check_cert_expiry() {
  echo -e "${GREEN}当前 Nginx 域名证书有效期:${RESET}"
  for CERT in /etc/letsencrypt/live/*/fullchain.pem; do
    if [ -f "$CERT" ]; then
      DOMAIN=$(basename $(dirname "$CERT"))
      EXPIRY=$(openssl x509 -enddate -noout -in "$CERT" | cut -d= -f2)
      echo -e "${YELLOW}$DOMAIN: ${GREEN}$EXPIRY${RESET}"
    fi
  done
  echo -e "${YELLOW}按回车返回主菜单...${RESET}"
  read
}

# ====== 刷新并显示当前容器列表 ======
refresh_docker_list() {
  echo -e "${GREEN}当前正在运行的 Docker 容器:${RESET}"
  docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}"
}

# ====== 添加/重建容器 ======
add_container() {
  if ! command -v nginx >/dev/null 2>&1; then
    echo -e "${YELLOW}检测到 Nginx 未安装，正在安装...${RESET}"
    if command -v apt >/dev/null 2>&1; then
      apt update && apt install -y nginx
    elif command -v yum >/dev/null 2>&1; then
      yum install -y nginx
    fi
  fi
  install_certbot
  ensure_nginx_include
  create_default_server
  configure_firewall
  setup_auto_renew

  refresh_docker_list
  echo -ne "${GREEN}请输入要操作的容器名称: ${RESET}"
  read CONTAINER

  if ! docker ps -a --format "{{.Names}}" | grep -qw "$CONTAINER"; then
    echo -e "${RED}容器不存在${RESET}"
    echo -e "${YELLOW}按回车返回主菜单...${RESET}"
    read
    return
  fi

  IMAGE=$(docker inspect --format='{{.Config.Image}}' "$CONTAINER")
  VOLUMES=$(docker inspect --format '{{range .Mounts}}-v {{.Source}}:{{.Destination}} {{end}}' "$CONTAINER")

  echo -ne "${GREEN}请输入域名: ${RESET}"
  read DOMAIN
  echo -ne "${GREEN}请输入容器内端口: ${RESET}"
  read PORT
  echo -ne "${GREEN}是否为 WebSocket 反代? (y/n): ${RESET}"
  read IS_WS
  echo -ne "${GREEN}请输入邮箱: ${RESET}"
  read EMAIL

  docker stop "$CONTAINER"
  docker rm "$CONTAINER"
  docker run -d --restart=always -p 127.0.0.1:$PORT:$PORT $VOLUMES --name $CONTAINER $IMAGE

  certbot certonly --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL"
  generate_nginx "$DOMAIN" "$PORT" "$IS_WS"

  echo -e "${GREEN}容器 $CONTAINER 安装/反代配置完成，域名 $DOMAIN 可访问${RESET}"
  echo -e "${YELLOW}按回车返回主菜单...${RESET}"
  read
}

# ====== 修改域名配置 ======
modify_config() {
  ensure_nginx_include
  refresh_docker_list
  echo -e "${GREEN}已有 Nginx 域名配置:${RESET}"
  ls /etc/nginx/sites-available/
  echo -ne "${GREEN}请输入要修改的域名: ${RESET}"
  read DOMAIN
  CONFIG_PATH="/etc/nginx/sites-available/$DOMAIN"
  [ ! -f "$CONFIG_PATH" ] && { echo -e "${RED}域名配置不存在${RESET}"; echo -e "${YELLOW}按回车返回主菜单...${RESET}"; read; return; }

  echo -ne "${GREEN}请输入新容器内端口: ${RESET}"
  read PORT
  echo -ne "${GREEN}是否为 WebSocket 反代? (y/n): ${RESET}"
  read IS_WS
  echo -ne "${GREEN}是否更新证书邮箱? (y/n): ${RESET}"
  read CHOICE
  if [[ "$CHOICE" == "y" ]]; then
    echo -ne "${GREEN}新邮箱: ${RESET}"
    read EMAIL
    certbot certonly --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL"
  fi

  generate_nginx "$DOMAIN" "$PORT" "$IS_WS"
  echo -e "${GREEN}域名 $DOMAIN 修改完成${RESET}"
  echo -e "${YELLOW}按回车返回主菜单...${RESET}"
  read
}

# ====== 卸载容器及域名配置 ======
uninstall() {
  refresh_docker_list
  echo -ne "${GREEN}请输入要卸载的容器名称: ${RESET}"
  read CONTAINER

  if docker ps -a --format "{{.Names}}" | grep -qw "$CONTAINER"; then
    docker stop "$CONTAINER"
    docker rm "$CONTAINER"
  fi

  echo -ne "${GREEN}请输入要删除的域名配置: ${RESET}"
  read DOMAIN
  rm -f /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/$DOMAIN
  nginx -t
  start_nginx
  echo -e "${GREEN}容器和域名配置已卸载${RESET}"
  echo -e "${YELLOW}按回车返回主菜单...${RESET}"
  read
}

# ====== 菜单 ======
while true; do
  echo -e "${GREEN}====== Docker + Nginx 管理脚本 ======${RESET}"
  echo -e "${GREEN}1) 安装/添加容器并反代 + TLS${RESET}"
  echo -e "${GREEN}2) 修改现有域名配置${RESET}"
  echo -e "${GREEN}3) 卸载容器及域名配置${RESET}"
  echo -e "${GREEN}4) 卸载 Nginx + Certbot${RESET}"
  echo -e "${GREEN}5) 续期所有 TLS 证书${RESET}"
  echo -e "${GREEN}6) 查看证书有效期${RESET}"
  echo -e "${GREEN}0) 退出${RESET}"
  echo -ne "${GREEN}请选择 [0-6]: ${RESET}"
  read CHOICE
  case $CHOICE in
    1) add_container ;;
    2) modify_config ;;
    3) uninstall ;;
    4) uninstall_nginx ;;
    5) renew_certs ;;
    6) check_cert_expiry ;;
    0) exit 0 ;;
    *) echo -e "${RED}无效选项${RESET}" ;;
  esac
  echo ""
done
