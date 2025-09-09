#!/bin/bash
# Ubuntu 一键安装 Typecho 博客 + SEO + HTTPS
# 域名: wjz5788.com
# 邮箱: zmshyc@gmail.com
# 适用 Ubuntu 20.04 / 22.04

set -e

# ======== 配置变量 ========
DOMAIN="wjz5788.com"
EMAIL="zmshyc@gmail.com"
DB_NAME="typecho"
DB_USER="typecho"
DB_PASS=$(openssl rand -hex 12)
PHP_VER="8.1"

echo "=== 更新系统 ==="
sudo apt update && sudo apt upgrade -y

echo "=== 安装基础软件 ==="
sudo apt install nginx php${PHP_VER} php${PHP_VER}-fpm php${PHP_VER}-mysql php${PHP_VER}-xml php${PHP_VER}-mbstring php${PHP_VER}-curl unzip wget certbot python3-certbot-nginx -y
sudo apt install mariadb-server -y

echo "=== 创建数据库 ==="
sudo mysql -e "CREATE DATABASE ${DB_NAME} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
sudo mysql -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
sudo mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

echo "=== 下载 Typecho ==="
sudo mkdir -p /var/www/typecho
cd /var/www/
sudo wget -O typecho.zip https://github.com/typecho/typecho/releases/latest/download/typecho.zip
sudo unzip -o typecho.zip -d typecho
sudo chown -R www-data:www-data /var/www/typecho

echo "=== 配置 Nginx (SEO + HTTPS) ==="
cat <<EOF | sudo tee /etc/nginx/sites-available/typecho.conf
server {
    listen 80;
    server_name ${DOMAIN};
    root /var/www/typecho;
    index index.php index.html;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php${PHP_VER}-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    # SEO Headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
    add_header X-XSS-Protection "1; mode=block";

    # Gzip 压缩
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # 静态文件缓存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|webp|svg)\$ {
        expires 30d;
        access_log off;
    }
}
EOF

sudo ln -sf /etc/nginx/sites-available/typecho.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

echo "=== 配置 robots.txt 和 sitemap.xml ==="
cat <<EOF | sudo tee /var/www/typecho/robots.txt
User-agent: *
Allow: /
Sitemap: https://${DOMAIN}/sitemap.xml
EOF

cat <<EOF | sudo tee /var/www/typecho/sitemap.xml
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
</urlset>
EOF

sudo chown www-data:www-data /var/www/typecho/robots.txt /var/www/typecho/sitemap.xml

echo "=== 申请 Let’s Encrypt SSL 证书 ==="
sudo certbot --nginx -d ${DOMAIN} --non-interactive --agree-tos -m ${EMAIL} --redirect

echo "=== 安装完成 ==="
echo "访问 https://${DOMAIN} 进行 Typecho 初始化"
echo "数据库信息如下："
echo "数据库名: ${DB_NAME}"
echo "数据库用户: ${DB_USER}"
echo "数据库密码: ${DB_PASS}"
echo "HTTPS 已自动配置并启用重定向"
