#!/bin/bash
#网站一键部署（Debian/Ubuntu）
WEB_ROOT="/var/www/clock_site"
NGINX_CONF_DIR="/etc/nginx/sites-available"
LOG_FILE="/var/log/nginx/clock_access.log"
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

install_site() {
    read -p "请输入你的域名： " DOMAIN
    read -p "请输入你的邮箱（用于 HTTPS）： " EMAIL

    apt update
    apt install -y nginx certbot python3-certbot-nginx

    # 检查域名解析
    VPS_IP=$(curl -s https://ipinfo.io/ip)
    DOMAIN_IP=$(dig +short "$DOMAIN" | tail -n1)
    if [[ "$VPS_IP" != "$DOMAIN_IP" ]]; then
        echo -e "${RED}❌ 域名 $DOMAIN 没有解析到本 VPS 公网 IP $VPS_IP${RESET}"
        return
    fi

    mkdir -p "$WEB_ROOT"
    chmod 755 "$WEB_ROOT"

    # 默认 HTML 页面
    cat > "$WEB_ROOT/index.html" <<'EOF'
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<title>时钟</title>
<style>
html, body { margin:0; padding:0; height:100%; display:flex; justify-content:center; align-items:center; background:#f0f0f0; font-family:Arial,sans-serif; flex-direction:column;}
h1 { font-size:3rem; margin:0;}
#time { font-size:5rem; font-weight:bold; margin-top:20px;}
</style>
</head>
<body>
<h1>🌎 世界时间</h1>
<div id="time"></div>
<script>
function updateTime() {
    const now = new Date();
    document.getElementById("time").innerText = now.toLocaleString();
}
setInterval(updateTime, 1000);
updateTime();
</script>
</body>
</html>
EOF

    # 创建独立 Nginx 配置
    NGINX_CONF="$NGINX_CONF_DIR/$DOMAIN"
    cat > "$NGINX_CONF" <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    root $WEB_ROOT;
    index index.html;

    access_log $LOG_FILE combined;
}
EOF

    ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx

    # HTTPS
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "$EMAIL"

    # 自动续期
    RENEW_SCRIPT="/root/renew_clock_cert.sh"
    cat > "$RENEW_SCRIPT" <<EOF
#!/bin/bash
certbot renew --quiet --deploy-hook "systemctl reload nginx"
EOF
    chmod +x "$RENEW_SCRIPT"
    (crontab -l 2>/dev/null; echo "0 0,12 * * * $RENEW_SCRIPT >> /var/log/renew_clock_cert.log 2>&1") | crontab -

    echo -e "${GREEN}✅ HTML网站部署完成！${RESET}"
    echo -e "${GREEN}页面路径：$WEB_ROOT/index.html${RESET}"
    echo -e "${GREEN}访问：https://$DOMAIN${RESET}"
}

uninstall_site() {
    read -p "请输入你的域名： " DOMAIN
    systemctl stop nginx
    rm -f "$NGINX_CONF_DIR/$DOMAIN"
    rm -f /etc/nginx/sites-enabled/$DOMAIN
    rm -rf "$WEB_ROOT"
    certbot delete --cert-name "$DOMAIN" --non-interactive || echo "证书可能不存在"
    systemctl reload nginx
    echo -e "${GREEN}✅ HTML 时钟网站已卸载${RESET}"
}

edit_html() {
    ${EDITOR:-nano} "$WEB_ROOT/index.html"
    systemctl reload nginx
}

view_logs() {
    if [ -f "$LOG_FILE" ]; then
        tail -n 20 "$LOG_FILE"
        echo -e "\n统计不同 IP 访问次数："
        awk '{print $1}' "$LOG_FILE" | sort | uniq -c | sort -nr
    else
        echo -e "${RED}日志文件不存在${RESET}"
    fi
}

while true; do
    echo -e "${GREEN}=========================================${RESET}"
    echo -e "${GREEN}            网站管理菜单                  ${RESET}"
    echo -e "${GREEN}=========================================${RESET}"
    echo -e "${GREEN}1) 安装/部署网站${RESET}" 
    echo -e "${GREEN}2) 卸载网站${RESET}"
    echo -e "${GREEN}3) 编辑页面${RESET}"
    echo -e "${GREEN}4) 查看访问日志${RESET}"
    echo -e "${GREEN}5) 退出${RESET}"
    read -p "请选择操作 [1-5]：" choice
    case $choice in
        1) install_site ;;
        2) uninstall_site ;;
        3) edit_html ;;
        4) view_logs ;;
        5) exit 0 ;;
        *) echo -e "${RED}请输入有效选项 [1-5]${RESET}" ;;
    esac
    read -p "按回车返回菜单..."
done