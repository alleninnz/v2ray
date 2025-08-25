#!/bin/bash

# ========================================
# V2Ray TLS Deployment Script (TLS版本)
# 一键部署V2Ray + Nginx反向代理 + TLS证书
# ========================================

set -euo pipefail  # 严格错误处理

# 颜色和格式化
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# 配置变量
V2RAY_DIR="/opt/v2ray-tls"
V2RAY_PORT="8080"
NGINX_PORT="10086"
WS_PATH="/ray"
DOMAIN=""
EMAIL=""
CERT_METHOD=""

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${PURPLE}${BOLD}[STEP]${NC} $1"
}

log_debug() {
    echo -e "${CYAN}[DEBUG]${NC} $1"
}

# 错误处理函数
cleanup_on_error() {
    log_error "部署失败，正在清理..."
    if [ -d "$V2RAY_DIR" ]; then
        cd "$V2RAY_DIR" && docker-compose down 2>/dev/null || true
        rm -rf "$V2RAY_DIR"
    fi
    exit 1
}

# 设置错误陷阱
trap cleanup_on_error ERR

# 显示帮助信息
show_help() {
    echo -e "${BOLD}V2Ray TLS 一键部署脚本${NC}"
    echo
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -d, --domain DOMAIN     域名 (必需)"
    echo "  -e, --email EMAIL       Let's Encrypt 邮箱地址"
    echo "  -c, --cert METHOD       证书获取方法 (letsencrypt|self-signed) [默认: letsencrypt]"
    echo "  -h, --help              显示此帮助信息"
    echo
    echo "示例:"
    echo "  $0 -d example.com -e admin@example.com"
    echo "  $0 --domain example.com --email admin@example.com --cert letsencrypt"
    echo "  $0 -d example.com -c self-signed"
    echo
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--domain)
                DOMAIN="$2"
                shift 2
                ;;
            -e|--email)
                EMAIL="$2"
                shift 2
                ;;
            -c|--cert)
                CERT_METHOD="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 设置默认值
    if [ -z "$CERT_METHOD" ]; then
        CERT_METHOD="letsencrypt"
    fi
    
    # 验证必需参数
    if [ -z "$DOMAIN" ]; then
        log_error "域名是必需的参数"
        show_help
        exit 1
    fi
    
    if [ "$CERT_METHOD" = "letsencrypt" ] && [ -z "$EMAIL" ]; then
        log_error "使用 Let's Encrypt 时邮箱地址是必需的"
        show_help
        exit 1
    fi
}

# 检查是否以root权限运行
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用root权限运行此脚本"
        echo "使用命令: sudo bash $0 [选项]"
        exit 1
    fi
}

# 验证域名格式
validate_domain() {
    log_step "验证域名格式..."
    
    if ! [[ "$DOMAIN" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        log_error "域名格式无效: $DOMAIN"
        exit 1
    fi
    
    log_success "域名格式有效: $DOMAIN"
}

# 验证邮箱格式
validate_email() {
    if [ -n "$EMAIL" ]; then
        log_step "验证邮箱格式..."
        
        if ! [[ "$EMAIL" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
            log_error "邮箱格式无效: $EMAIL"
            exit 1
        fi
        
        log_success "邮箱格式有效: $EMAIL"
    fi
}

# 检查域名DNS解析
check_dns_resolution() {
    log_step "检查域名DNS解析..."
    
    local server_ip
    server_ip=$(curl -s --connect-timeout 10 ifconfig.me 2>/dev/null || \
                curl -s --connect-timeout 10 icanhazip.com 2>/dev/null || \
                curl -s --connect-timeout 10 ipecho.net/plain 2>/dev/null || \
                echo "")
    
    if [ -z "$server_ip" ]; then
        log_warning "无法获取服务器公网IP，跳过DNS检查"
        return 0
    fi
    
    local domain_ip
    domain_ip=$(dig +short "$DOMAIN" @8.8.8.8 2>/dev/null | tail -1)
    
    if [ -z "$domain_ip" ]; then
        log_warning "无法解析域名 $DOMAIN，请确认DNS配置正确"
        if [ "$CERT_METHOD" = "letsencrypt" ]; then
            log_warning "Let's Encrypt 验证可能会失败"
        fi
    elif [ "$domain_ip" != "$server_ip" ]; then
        log_warning "域名解析IP ($domain_ip) 与服务器IP ($server_ip) 不匹配"
        if [ "$CERT_METHOD" = "letsencrypt" ]; then
            log_warning "Let's Encrypt 验证可能会失败"
        fi
    else
        log_success "域名DNS解析正确"
    fi
}

# 检查系统要求
check_system_requirements() {
    log_step "检查系统要求..."
    
    # 检查操作系统
    if ! command -v lsb_release &> /dev/null; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            OS=$NAME
        else
            log_error "无法检测操作系统类型"
            exit 1
        fi
    else
        OS=$(lsb_release -si)
    fi
    
    log_info "操作系统: $OS"
    
    # 检查必需工具
    local required_tools=("curl" "dig" "openssl")
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_info "安装缺失工具: $tool"
            if command -v apt &> /dev/null; then
                apt update && apt install -y "$tool" dnsutils
            elif command -v yum &> /dev/null; then
                yum install -y "$tool" bind-utils
            elif command -v dnf &> /dev/null; then
                dnf install -y "$tool" bind-utils
            fi
        fi
    done
    
    # 检查系统架构
    ARCH=$(uname -m)
    if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "aarch64" ]; then
        log_warning "系统架构 $ARCH 可能不完全支持"
    fi
    
    # 检查内存
    MEMORY_MB=$(free -m | awk 'NR==2{print $2}')
    if [ "$MEMORY_MB" -lt 1024 ]; then
        log_warning "系统内存不足1GB，TLS处理可能影响性能"
    fi
}

# 检查端口是否被占用
check_ports() {
    log_step "检查端口占用情况..."
    
    local ports=(80 443 "$NGINX_PORT" "$V2RAY_PORT")
    for port in "${ports[@]}"; do
        if netstat -tlnp 2>/dev/null | grep -q ":${port} "; then
            if [ "$port" = "80" ] && [ "$CERT_METHOD" = "letsencrypt" ]; then
                log_error "端口 80 被占用，Let's Encrypt 验证需要此端口"
                netstat -tlnp | grep ":80 "
                exit 1
            elif [ "$port" = "$NGINX_PORT" ] || [ "$port" = "$V2RAY_PORT" ]; then
                log_error "端口 $port 已被占用"
                netstat -tlnp | grep ":${port} "
                exit 1
            fi
        fi
    done
    
    log_success "端口检查通过"
}

# 安装Docker
install_docker() {
    if command -v docker &> /dev/null; then
        log_success "Docker 已安装"
        docker --version
    else
        log_step "安装 Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        systemctl start docker
        systemctl enable docker
        rm -f get-docker.sh
        log_success "Docker 安装完成"
    fi
    
    # 检查Docker服务状态
    if ! systemctl is-active --quiet docker; then
        log_error "Docker 服务未运行"
        exit 1
    fi
}

# 安装Docker Compose
install_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        log_success "Docker Compose 已安装"
        docker-compose --version
    else
        log_step "安装 Docker Compose..."
        
        # 检测系统类型并安装
        if command -v apt &> /dev/null; then
            apt update && apt install -y docker-compose
        elif command -v yum &> /dev/null; then
            yum install -y docker-compose
        elif command -v dnf &> /dev/null; then
            dnf install -y docker-compose
        else
            # 手动安装最新版本
            COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
            curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            chmod +x /usr/local/bin/docker-compose
            ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
        fi
        
        log_success "Docker Compose 安装完成"
        docker-compose --version
    fi
}

# 生成UUID
generate_uuid() {
    if command -v uuidgen &> /dev/null; then
        uuidgen
    elif command -v python3 &> /dev/null; then
        python3 -c "import uuid; print(uuid.uuid4())"
    elif command -v python &> /dev/null; then
        python -c "import uuid; print(uuid.uuid4())"
    else
        # 简单的UUID生成（非标准但功能性的）
        cat /proc/sys/kernel/random/uuid 2>/dev/null || \
        od -x /dev/urandom | head -1 | awk '{OFS="-"; print $2$3,$4,$5,$6,$7$8$9}'
    fi
}

# 创建项目目录结构
setup_directories() {
    log_step "创建项目目录..."
    
    rm -rf "$V2RAY_DIR"
    mkdir -p "$V2RAY_DIR"/{config,nginx,certs,logs,scripts}
    cd "$V2RAY_DIR"
    
    log_success "项目目录创建完成: $V2RAY_DIR"
}

# 生成自签名证书
generate_self_signed_cert() {
    log_step "生成自签名证书..."
    
    mkdir -p "certs/live/$DOMAIN"
    
    # 生成私钥
    openssl genrsa -out "certs/live/$DOMAIN/privkey.pem" 2048
    
    # 生成证书
    openssl req -new -x509 -key "certs/live/$DOMAIN/privkey.pem" \
        -out "certs/live/$DOMAIN/fullchain.pem" -days 365 \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN" \
        -extensions SAN \
        -config <(echo '[req]'; echo 'distinguished_name=req'; echo '[SAN]'; echo "subjectAltName=DNS:$DOMAIN")
    
    # 设置权限
    chmod 600 "certs/live/$DOMAIN/privkey.pem"
    chmod 644 "certs/live/$DOMAIN/fullchain.pem"
    
    log_success "自签名证书生成完成"
    log_warning "使用自签名证书时，客户端需要允许不安全连接"
}

# 获取Let's Encrypt证书
get_letsencrypt_cert() {
    log_step "获取 Let's Encrypt 证书..."
    
    # 创建临时Nginx配置用于验证
    mkdir -p certs/www/.well-known/acme-challenge
    
    # 启动临时Web服务器
    docker run --rm -d \
        --name temp-nginx \
        -p 80:80 \
        -v "$PWD/certs/www:/var/www/certbot:ro" \
        nginx:alpine \
        sh -c 'echo "server { listen 80; location /.well-known/acme-challenge/ { root /var/www/certbot; } }" > /etc/nginx/conf.d/default.conf && nginx -g "daemon off;"'
    
    sleep 5
    
    # 获取证书
    if docker run --rm \
        -v "$PWD/certs:/etc/letsencrypt" \
        -v "$PWD/certs/www:/var/www/certbot" \
        certbot/certbot \
        certonly --webroot --webroot-path=/var/www/certbot \
        --email "$EMAIL" --agree-tos --no-eff-email \
        --force-renewal \
        -d "$DOMAIN"; then
        
        log_success "Let's Encrypt 证书获取成功"
    else
        log_error "Let's Encrypt 证书获取失败，切换到自签名证书"
        docker stop temp-nginx 2>/dev/null || true
        generate_self_signed_cert
        return
    fi
    
    # 停止临时服务器
    docker stop temp-nginx 2>/dev/null || true
    
    # 验证证书文件
    if [ ! -f "certs/live/$DOMAIN/fullchain.pem" ] || [ ! -f "certs/live/$DOMAIN/privkey.pem" ]; then
        log_error "证书文件未找到，切换到自签名证书"
        generate_self_signed_cert
    fi
}

# 设置SSL证书
setup_ssl_certificate() {
    log_step "设置SSL证书..."
    
    case "$CERT_METHOD" in
        "letsencrypt")
            get_letsencrypt_cert
            ;;
        "self-signed")
            generate_self_signed_cert
            ;;
        *)
            log_error "不支持的证书方法: $CERT_METHOD"
            exit 1
            ;;
    esac
}

# 创建证书续期脚本
create_cert_renewal_script() {
    if [ "$CERT_METHOD" = "letsencrypt" ]; then
        log_step "创建证书自动续期脚本..."
        
        cat > scripts/renew-cert.sh << EOF
#!/bin/bash

# Let's Encrypt 证书续期脚本
cd $V2RAY_DIR

echo "\$(date): 开始证书续期检查..."

# 创建临时Web服务器用于验证
if ! docker ps | grep -q temp-nginx-renew; then
    docker run --rm -d \\
        --name temp-nginx-renew \\
        -p 80:80 \\
        -v "\$PWD/certs/www:/var/www/certbot:ro" \\
        nginx:alpine \\
        sh -c 'echo "server { listen 80; location /.well-known/acme-challenge/ { root /var/www/certbot; } }" > /etc/nginx/conf.d/default.conf && nginx -g "daemon off;"'
fi

# 停止主Nginx服务
docker-compose stop nginx

sleep 5

# 续期证书
if docker run --rm \\
    -v "\$PWD/certs:/etc/letsencrypt" \\
    -v "\$PWD/certs/www:/var/www/certbot" \\
    certbot/certbot \\
    renew --webroot --webroot-path=/var/www/certbot; then
    echo "\$(date): 证书续期成功"
    # 重启Nginx以加载新证书
    docker-compose start nginx
else
    echo "\$(date): 证书续期失败"
    docker-compose start nginx
fi

# 清理临时服务器
docker stop temp-nginx-renew 2>/dev/null || true

echo "\$(date): 证书续期检查完成"
EOF
        
        chmod +x scripts/renew-cert.sh
        
        # 添加到crontab（每月1号凌晨2点执行）
        if ! crontab -l 2>/dev/null | grep -q "renew-cert.sh"; then
            (crontab -l 2>/dev/null; echo "0 2 1 * * $V2RAY_DIR/scripts/renew-cert.sh >> $V2RAY_DIR/logs/cert-renewal.log 2>&1") | crontab -
            log_success "证书自动续期任务已添加到crontab"
        fi
    fi
}

# 生成V2Ray配置
create_v2ray_config() {
    log_step "生成V2Ray配置..."
    
    NEW_UUID=$(generate_uuid)
    if [ -z "$NEW_UUID" ]; then
        log_error "无法生成UUID"
        exit 1
    fi
    
    cat > config/config.json << EOF
{
  "log": {
    "access": "/tmp/v2ray-access.log",
    "error": "/tmp/v2ray-error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 8080,
      "listen": "0.0.0.0",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "$NEW_UUID",
            "alterId": 0,
            "email": "user@$DOMAIN"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "$WS_PATH",
          "headers": {
            "Host": "$DOMAIN"
          }
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {},
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "settings": {},
      "tag": "blocked"
    }
  ],
  "routing": {
    "rules": [
      {
        "type": "field",
        "ip": ["geoip:private"],
        "outboundTag": "blocked"
      },
      {
        "type": "field",
        "outboundTag": "direct",
        "network": "udp,tcp"
      }
    ]
  }
}
EOF
    
    log_success "V2Ray配置生成完成"
    echo "UUID: $NEW_UUID"
}

# 生成Nginx配置
create_nginx_config() {
    log_step "生成Nginx配置..."
    
    cat > nginx/nginx.conf << EOF
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    # 日志格式
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';
    
    # 基本配置
    sendfile        on;
    keepalive_timeout  65;
    server_tokens   off;
    
    # Gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
    # 上游服务器配置
    upstream v2ray {
        server v2ray:8080;
    }

    # HTTPS 服务器配置（端口 $NGINX_PORT）
    server {
        listen $NGINX_PORT ssl http2;
        server_name $DOMAIN;

        # 访问日志
        access_log /var/log/nginx/access.log main;
        error_log /var/log/nginx/error.log warn;

        # SSL 证书配置
        ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

        # SSL 安全配置
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE:ECDH:AES:HIGH:!NULL:!aNULL:!MD5:!ADH:!RC4:!DH+3DES:!DHE-RSA-AES256-SHA;
        ssl_prefer_server_ciphers on;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;
        ssl_session_tickets off;
        
        # HSTS
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload" always;
        
        # 其他安全头
        add_header X-Frame-Options DENY always;
        add_header X-Content-Type-Options nosniff always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;

        # WebSocket 代理配置
        location $WS_PATH {
            proxy_redirect off;
            proxy_pass http://v2ray;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_read_timeout 86400;
            proxy_send_timeout 86400;
        }

        # 动态内容生成变量
        set \$page_type "";
        set \$user_agent_type "";
        
        # 根据时间和请求特征选择页面类型
        if (\$time_local ~ "0[0-9]:|1[0-2]:") { set \$page_type "tech"; }
        if (\$time_local ~ "1[3-7]:") { set \$page_type "company"; }
        if (\$time_local ~ "1[8-9]:|2[0-3]:") { set \$page_type "portfolio"; }
        
        # 根据User-Agent调整内容
        if (\$http_user_agent ~ "Mobile|Android|iPhone") { set \$user_agent_type "mobile"; }
        if (\$http_user_agent ~ "bot|crawler|spider|Googlebot|Bingbot") { set \$user_agent_type "bot"; }
        
        # 静态资源伪装 - CSS样式
        location /assets/style.css {
            return 200 'body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Oxygen,Ubuntu,Cantarell,sans-serif;margin:0;padding:0;line-height:1.6;color:#333;background:#f8f9fa;}header{background:#fff;box-shadow:0 2px 4px rgba(0,0,0,.1);padding:1rem 0;}nav{display:flex;justify-content:space-between;align-items:center;max-width:1200px;margin:0 auto;padding:0 2rem;}nav h1{margin:0;color:#2c3e50;}nav ul{display:flex;list-style:none;gap:2rem;margin:0;padding:0;}nav a{text-decoration:none;color:#666;font-weight:500;}nav a:hover{color:#3498db;}main{max-width:1200px;margin:0 auto;padding:2rem;}section{margin:3rem 0;}.hero{text-align:center;padding:4rem 2rem;background:linear-gradient(135deg,#667eea 0%,#764ba2 100%);color:white;border-radius:8px;}.hero h1{font-size:2.5rem;margin-bottom:1rem;}.hero p{font-size:1.2rem;margin-bottom:2rem;}.cta-button,.primary-btn{background:#3498db;color:white;border:none;padding:1rem 2rem;border-radius:4px;cursor:pointer;font-size:1rem;text-decoration:none;display:inline-block;}.cta-button:hover,.primary-btn:hover{background:#2980b9;}.secondary-btn{background:transparent;color:#3498db;border:2px solid #3498db;padding:1rem 2rem;border-radius:4px;cursor:pointer;font-size:1rem;text-decoration:none;display:inline-block;margin-left:1rem;}.secondary-btn:hover{background:#3498db;color:white;}.service-grid,.project-grid,.skills-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:2rem;margin:2rem 0;}.service-card,.project-card{background:#fff;padding:2rem;border-radius:8px;box-shadow:0 4px 6px rgba(0,0,0,.1);}.service-card h3,.project-card h3{color:#2c3e50;margin-bottom:1rem;}.project-card img{width:100%;height:200px;object-fit:cover;border-radius:4px;margin-bottom:1rem;}.tech-stack{display:flex;gap:0.5rem;flex-wrap:wrap;margin-top:1rem;}.tech-stack span{background:#3498db;color:white;padding:0.25rem 0.75rem;border-radius:12px;font-size:0.8rem;}.skill-category{background:#fff;padding:2rem;border-radius:8px;box-shadow:0 4px 6px rgba(0,0,0,.1);}.skill-category h3{color:#2c3e50;margin-bottom:1rem;}.skill-category ul{list-style:none;padding:0;}.skill-category li{padding:0.5rem 0;border-bottom:1px solid #eee;}.stats{display:grid;grid-template-columns:repeat(3,1fr);gap:2rem;margin:2rem 0;text-align:center;}.stat h3{font-size:2.5rem;color:#3498db;margin:0;}.stat p{margin:0.5rem 0 0 0;color:#666;}footer{background:#2c3e50;color:#fff;padding:3rem 0;margin-top:4rem;text-align:center;}.footer-content{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:2rem;margin-bottom:2rem;}.footer-section h4{color:#3498db;margin-bottom:1rem;}@media (max-width: 768px){nav{flex-direction:column;gap:1rem;}nav ul{flex-direction:column;text-align:center;}.hero h1{font-size:2rem;}.hero{padding:2rem 1rem;}main{padding:1rem;}.secondary-btn{margin-left:0;margin-top:1rem;}}';
            add_header Content-Type text/css;
            add_header Cache-Control "public, max-age=86400";
        }
        
        # JavaScript资源伪装
        location /js/main.js {
            return 200 'document.addEventListener("DOMContentLoaded",function(){const navLinks=document.querySelectorAll("nav a");navLinks.forEach(link=>{link.addEventListener("click",function(e){if(this.getAttribute("href").startsWith("#")){e.preventDefault();const targetId=this.getAttribute("href").substring(1);const targetElement=document.getElementById(targetId);if(targetElement){targetElement.scrollIntoView({behavior:"smooth"})}}})});const buttons=document.querySelectorAll(".cta-button, .primary-btn, .secondary-btn");buttons.forEach(button=>{button.addEventListener("click",function(e){if(this.textContent.includes("Download")){e.preventDefault();console.log("Download initiated")}else if(this.textContent.includes("Get Started")||this.textContent.includes("View Portfolio")){e.preventDefault();console.log("Action triggered:",this.textContent)}})});if(typeof gtag!=="undefined"){gtag("config","GA_MEASUREMENT_ID",{page_title:document.title,page_location:window.location.href})}const lastUpdate=new Date().toLocaleDateString();const timeElements=document.querySelectorAll("time");timeElements.forEach(el=>{if(!el.getAttribute("datetime")){el.textContent=lastUpdate}})});window.addEventListener("scroll",function(){const header=document.querySelector("header");if(window.scrollY>100){header.style.background="rgba(255,255,255,0.95)";header.style.backdropFilter="blur(10px)"}else{header.style.background="#fff";header.style.backdropFilter="none"}});';
            add_header Content-Type application/javascript;
            add_header Cache-Control "public, max-age=86400";
        }
        
        # 图片资源404伪装
        location /images/ {
            return 404 '<!DOCTYPE html><html><head><title>404 Not Found</title></head><body><h1>404 Not Found</h1><p>The requested image was not found on this server.</p></body></html>';
            add_header Cache-Control "public, max-age=3600";
        }
        
        # API端点伪装
        location /api/status {
            return 200 '{"status":"active","uptime":"99.9%","last_check":"'$(date -Iseconds)'","version":"1.2.3"}';
            add_header Content-Type application/json;
        }
        
        location /api/health {
            return 200 '{"healthy":true,"services":{"database":"up","cache":"up","storage":"up"},"timestamp":"'$(date -Iseconds)'"}';
            add_header Content-Type application/json;
        }
        
        location /favicon.ico {
            return 204;
            add_header Cache-Control "public, max-age=86400";
        }
        
        location /robots.txt {
            return 200 'User-agent: *\nAllow: /\nDisallow: /admin/\nDisallow: /api/private/\nSitemap: https://\$host:\$server_port/sitemap.xml';
            add_header Content-Type text/plain;
        }

        # 技术博客页面模板
        location @tech_blog {
            return 200 '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>TechInsights - $DOMAIN</title><link href="/assets/style.css" rel="stylesheet"><meta name="description" content="Latest technology trends, programming tutorials, and software development insights"><meta name="keywords" content="technology, programming, development, AI, machine learning, web development"><meta name="author" content="TechInsights Team"><link rel="canonical" href="https://$DOMAIN:$NGINX_PORT/"><meta property="og:title" content="TechInsights - Latest Technology Trends"><meta property="og:description" content="Exploring cutting-edge developments in software engineering and AI"><meta property="og:type" content="website"></head><body><header><nav><div class="container"><h1>📡 TechInsights</h1><ul><li><a href="#home">Home</a></li><li><a href="#articles">Articles</a></li><li><a href="#tutorials">Tutorials</a></li><li><a href="#about">About</a></li><li><a href="#contact">Contact</a></li></ul></div></nav></header><main><section class="hero"><div class="container"><h1>Latest in Technology & Development</h1><p>Exploring cutting-edge developments in software engineering, AI, and emerging technologies</p><button class="cta-button">Explore Articles</button></div></section><section class="articles"><div class="container"><h2>🔥 Featured Articles</h2><div class="project-grid"><article class="project-card"><h3>🤖 Machine Learning Trends in 2024</h3><p class="meta">Published on <time datetime="'$(date -I)'">$(date "+%B %d, %Y")</time> • 8 min read</p><p>Machine learning continues to evolve rapidly, with transformer architectures, edge AI, and automated ML leading the charge. Discover the latest frameworks and methodologies...</p><div class="tech-stack"><span>Python</span><span>TensorFlow</span><span>PyTorch</span><span>MLOps</span></div><a href="/articles/ml-trends-2024" class="primary-btn">Read More</a></article><article class="project-card"><h3>🌐 Modern Web Development Stack</h3><p class="meta">Published on <time datetime="'$(date -d "2 days ago" -I)'">$(date -d "2 days ago" "+%B %d, %Y")</time> • 12 min read</p><p>Web development is undergoing significant changes with React Server Components, Edge Functions, and the rise of full-stack TypeScript frameworks...</p><div class="tech-stack"><span>React</span><span>Next.js</span><span>TypeScript</span><span>Vercel</span></div><a href="/articles/modern-web-stack" class="primary-btn">Read More</a></article><article class="project-card"><h3>☁️ Cloud Native Architecture Patterns</h3><p class="meta">Published on <time datetime="'$(date -d "5 days ago" -I)'">$(date -d "5 days ago" "+%B %d, %Y")</time> • 15 min read</p><p>Building cloud-native applications requires understanding of microservices, containers, service mesh, and observability patterns. A comprehensive guide...</p><div class="tech-stack"><span>Kubernetes</span><span>Docker</span><span>Istio</span><span>Prometheus</span></div><a href="/articles/cloud-native-patterns" class="primary-btn">Read More</a></article></div></div></section><section class="skills"><div class="container"><h2>🎯 Popular Topics</h2><div class="skills-grid"><div class="skill-category"><h3>Frontend Development</h3><ul><li>React & Vue.js Ecosystem</li><li>TypeScript Best Practices</li><li>Performance Optimization</li><li>Progressive Web Apps</li><li>State Management</li></ul></div><div class="skill-category"><h3>Backend & DevOps</h3><ul><li>Microservices Architecture</li><li>Kubernetes & Docker</li><li>CI/CD Pipelines</li><li>Database Optimization</li><li>Security Best Practices</li></ul></div><div class="skill-category"><h3>Emerging Technologies</h3><ul><li>Artificial Intelligence</li><li>Edge Computing</li><li>Blockchain Development</li><li>Quantum Computing</li><li>IoT Platforms</li></ul></div></div></div></section></main><footer><div class="container"><div class="footer-content"><div class="footer-section"><h4>📧 Subscribe</h4><p>Get the latest articles delivered to your inbox</p><p>newsletter@$DOMAIN</p></div><div class="footer-section"><h4>🔗 Connect</h4><p>Follow us for daily tech updates</p><p>Twitter • LinkedIn • GitHub • RSS</p></div><div class="footer-section"><h4>📊 Analytics</h4><p>Monthly Readers: 50K+</p><p>Articles Published: 200+</p><p>Code Examples: 500+</p></div></div><p class="copyright">&copy; 2024 TechInsights. All rights reserved. | <a href="/privacy">Privacy Policy</a> | <a href="/terms">Terms</a></p></div></footer><script src="/js/main.js"></script><script>gtag&&gtag("config","GA_MEASUREMENT_ID",{page_title:"TechInsights - Technology Blog"});</script></body></html>';
            add_header Content-Type text/html;
            add_header Cache-Control "public, max-age=3600";
        }

        # 公司主页模板  
        location @company_site {
            return 200 '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>InnovaTech Solutions - $DOMAIN</title><link href="/assets/style.css" rel="stylesheet"><meta name="description" content="Leading enterprise technology solutions, cloud migration, and digital transformation services"><meta name="keywords" content="enterprise, solutions, consulting, technology, innovation, cloud, digital transformation"><link rel="canonical" href="https://$DOMAIN:$NGINX_PORT/"><meta property="og:title" content="InnovaTech Solutions - Enterprise Technology"><meta property="og:type" content="website"></head><body><header><nav><div class="container"><h1>🏢 InnovaTech Solutions</h1><ul><li><a href="#home">Home</a></li><li><a href="#services">Services</a></li><li><a href="#solutions">Solutions</a></li><li><a href="#case-studies">Case Studies</a></li><li><a href="#about">About</a></li><li><a href="#contact">Contact</a></li></ul></div></nav></header><main><section class="hero"><div class="container"><h1>Transform Your Business with Innovative Technology</h1><p>Empowering enterprises worldwide with cutting-edge cloud solutions, AI integration, and digital transformation strategies</p><div class="hero-buttons"><button class="primary-btn">Schedule Consultation</button><button class="secondary-btn">View Case Studies</button></div></div></section><section class="services"><div class="container"><h2>🚀 Our Core Services</h2><div class="service-grid"><div class="service-card"><h3>☁️ Cloud Migration & Architecture</h3><p>Seamless transition to cloud infrastructure with minimal downtime. AWS, Azure, and GCP certified experts.</p><ul><li>Infrastructure Assessment</li><li>Migration Planning</li><li>Security Implementation</li><li>Cost Optimization</li></ul></div><div class="service-card"><h3>🔄 Digital Transformation</h3><p>Complete business process modernization and automation for enhanced operational efficiency.</p><ul><li>Process Automation</li><li>Legacy System Modernization</li><li>Workflow Optimization</li><li>Change Management</li></ul></div><div class="service-card"><h3>🤖 AI & Machine Learning Integration</h3><p>Implement artificial intelligence solutions to enhance decision-making and operational efficiency.</p><ul><li>Predictive Analytics</li><li>Natural Language Processing</li><li>Computer Vision</li><li>MLOps Implementation</li></ul></div><div class="service-card"><h3>🔒 Cybersecurity & Compliance</h3><p>Comprehensive security solutions to protect your digital assets and ensure regulatory compliance.</p><ul><li>Security Audits</li><li>Compliance Management</li><li>Incident Response</li><li>Security Training</li></ul></div></div></div></section><section class="stats"><div class="container"><h2>📈 Trusted by Industry Leaders</h2><div class="stats"><div class="stat"><h3>500+</h3><p>Projects Delivered</p></div><div class="stat"><h3>150+</h3><p>Enterprise Clients</p></div><div class="stat"><h3>99.9%</h3><p>Success Rate</p></div><div class="stat"><h3>24/7</h3><p>Support Available</p></div></div></div></section><section class="about"><div class="container"><h2>🎯 Why Choose InnovaTech Solutions?</h2><p>Founded in 2010, we have been at the forefront of technological innovation, helping Fortune 500 companies and growing enterprises transform their operations through strategic technology adoption.</p><div class="skills-grid"><div class="skill-category"><h3>🏆 Industry Expertise</h3><ul><li>15+ Years in Enterprise Tech</li><li>Certified Cloud Architects</li><li>Industry-Specific Solutions</li><li>Global Delivery Model</li></ul></div><div class="skill-category"><h3>💼 Client Success</h3><ul><li>C-Suite Partnerships</li><li>ROI-Focused Delivery</li><li>Agile Methodologies</li><li>Continuous Innovation</li></ul></div><div class="skill-category"><h3>🔧 Technical Excellence</h3><ul><li>Latest Technology Stack</li><li>DevSecOps Practices</li><li>Scalable Architectures</li><li>Quality Assurance</li></ul></div></div></div></section></main><footer><div class="container"><div class="footer-content"><div class="footer-section"><h4>📍 Contact Info</h4><p>📧 Email: solutions@$DOMAIN</p><p>📞 Phone: +1 (555) 123-4567</p><p>🏢 Address: 123 Innovation Plaza<br>Tech District, Silicon Valley, CA 94025</p></div><div class="footer-section"><h4>🌐 Global Offices</h4><p>🇺🇸 San Francisco • New York</p><p>🇬🇧 London • Manchester</p><p>🇮🇳 Bangalore • Mumbai</p><p>🇸🇬 Singapore</p></div><div class="footer-section"><h4>🤝 Follow Us</h4><p>LinkedIn • Twitter • GitHub</p><p>YouTube • Medium • Podcast</p><br><p>📊 ISO 27001 Certified</p><p>🔒 SOC 2 Type II Compliant</p></div></div><p class="copyright">&copy; 2024 InnovaTech Solutions Inc. All rights reserved. | <a href="/privacy">Privacy</a> | <a href="/terms">Terms</a> | <a href="/security">Security</a></p></div></footer><script src="/js/main.js"></script></body></html>';
            add_header Content-Type text/html;
            add_header Cache-Control "public, max-age=3600";
        }

        # 个人作品集模板
        location @portfolio_site {
            return 200 '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Alex Chen - Full-Stack Developer | $DOMAIN</title><link href="/assets/style.css" rel="stylesheet"><meta name="description" content="Full-stack developer specializing in React, Node.js, and cloud architecture. Building scalable web applications and mobile solutions."><meta name="keywords" content="full-stack developer, React, Node.js, Python, AWS, portfolio, web development, mobile development"><link rel="canonical" href="https://$DOMAIN:$NGINX_PORT/"></head><body><header><nav><div class="container"><h1>💻 Alex Chen</h1><ul><li><a href="#home">Home</a></li><li><a href="#about">About</a></li><li><a href="#portfolio">Portfolio</a></li><li><a href="#skills">Skills</a></li><li><a href="#experience">Experience</a></li><li><a href="#contact">Contact</a></li></ul></div></nav></header><main><section class="hero"><div class="container"><h1>Full-Stack Developer & Cloud Architect</h1><p>Building scalable, user-focused applications with modern technologies. Passionate about clean code, performance optimization, and innovative solutions.</p><div class="hero-buttons"><button class="primary-btn">View Portfolio</button><button class="secondary-btn">Download Resume</button></div></div></section><section class="portfolio"><div class="container"><h2>🎯 Featured Projects</h2><div class="project-grid"><div class="project-card"><h3>🛒 E-Commerce Platform</h3><p>Full-featured e-commerce solution with real-time inventory, payment processing, and analytics dashboard. Handles 10K+ concurrent users.</p><div class="tech-stack"><span>React</span><span>Node.js</span><span>PostgreSQL</span><span>Redis</span><span>AWS</span></div><p><strong>Key Features:</strong> Microservices architecture, real-time notifications, advanced search, mobile-responsive</p></div><div class="project-card"><h3>📱 Fitness Tracking Mobile App</h3><p>Cross-platform mobile application with social features, workout tracking, and AI-powered recommendations. 50K+ active users.</p><div class="tech-stack"><span>React Native</span><span>Firebase</span><span>Python</span><span>TensorFlow</span></div><p><strong>Key Features:</strong> Offline sync, social sharing, ML recommendations, wearable integration</p></div><div class="project-card"><h3>📊 Business Intelligence Dashboard</h3><p>Real-time analytics platform processing millions of events daily with interactive visualizations and automated reporting.</p><div class="tech-stack"><span>Vue.js</span><span>Python</span><span>Apache Kafka</span><span>ClickHouse</span><span>D3.js</span></div><p><strong>Key Features:</strong> Real-time streaming, custom visualizations, automated alerts, multi-tenant</p></div><div class="project-card"><h3>🤖 AI-Powered Chat Platform</h3><p>Enterprise chat solution with AI assistant, file sharing, and integrations. Used by 100+ companies for internal communication.</p><div class="tech-stack"><span>TypeScript</span><span>WebSocket</span><span>OpenAI API</span><span>Docker</span><span>Kubernetes</span></div><p><strong>Key Features:</strong> AI integration, end-to-end encryption, custom workflows, enterprise SSO</p></div></div></div></section><section class="skills"><div class="container"><h2>🛠️ Technical Skills</h2><div class="skills-grid"><div class="skill-category"><h3>Frontend Development</h3><ul><li>⚛️ React, Vue.js, Angular</li><li>📱 React Native, Flutter</li><li>🎨 TypeScript, CSS3, Sass</li><li>⚡ Next.js, Nuxt.js, Webpack</li><li>🧪 Jest, Cypress, Playwright</li></ul></div><div class="skill-category"><h3>Backend Development</h3><ul><li>🟢 Node.js, Express, Fastify</li><li>🐍 Python, Django, FastAPI</li><li>☕ Java, Spring Boot</li><li>🗄️ PostgreSQL, MongoDB, Redis</li><li>📨 GraphQL, REST APIs, gRPC</li></ul></div><div class="skill-category"><h3>Cloud & DevOps</h3><ul><li>☁️ AWS, GCP, Azure</li><li>🐳 Docker, Kubernetes</li><li>🔄 CI/CD, GitHub Actions</li><li>📊 Monitoring, Logging</li><li>🏗️ Infrastructure as Code</li></ul></div><div class="skill-category"><h3>Specializations</h3><ul><li>🤖 Machine Learning, AI Integration</li><li>🏛️ Microservices Architecture</li><li>⚡ Performance Optimization</li><li>🔒 Security Best Practices</li><li>📈 System Design & Scalability</li></ul></div></div></div></section><section class="about"><div class="container"><h2>👋 About Me</h2><p>With 8+ years of experience in full-stack development, I specialize in building scalable web applications and leading technical teams. Currently working as a Senior Software Engineer at a Y Combinator-backed startup.</p><div class="stats"><div class="stat"><h3>50+</h3><p>Projects Completed</p></div><div class="stat"><h3>8+</h3><p>Years Experience</p></div><div class="stat"><h3>15+</h3><p>Technologies Mastered</p></div></div><br><p>🎓 <strong>Education:</strong> M.S. Computer Science, Stanford University</p><p>🏆 <strong>Certifications:</strong> AWS Solutions Architect, Google Cloud Professional, Kubernetes Administrator</p><p>💬 <strong>Languages:</strong> English (Native), Mandarin (Native), Spanish (Conversational)</p></div></section></main><footer><div class="container"><div class="footer-content"><div class="footer-section"><h4>📧 Get In Touch</h4><p>Email: alex@$DOMAIN</p><p>LinkedIn: /in/alexchen-dev</p><p>GitHub: @alexchen-dev</p></div><div class="footer-section"><h4>💼 Currently</h4><p>🔍 Open to new opportunities</p><p>🌍 Available for remote work</p><p>💡 Interested in: AI/ML, Web3, Climate Tech</p></div><div class="footer-section"><h4>📍 Location</h4><p>📍 Based in San Francisco, CA</p><p>🌏 Available for global remote work</p><p>✈️ Open to relocation</p></div></div><p class="copyright">&copy; 2024 Alex Chen. Available for new opportunities. | <a href="mailto:alex@$DOMAIN">Contact Me</a></p></div></footer><script src="/js/main.js"></script></body></html>';
            add_header Content-Type text/html;
            add_header Cache-Control "public, max-age=3600";
        }

        # 搜索引擎爬虫专用页面
        location @bot_page {
            return 200 '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>$DOMAIN - Professional Technology Services</title><meta name="description" content="Professional technology consulting, software development, and digital solutions. Specializing in cloud architecture, web development, and enterprise solutions."><meta name="keywords" content="technology consulting, software development, web development, cloud solutions, enterprise services"><meta name="robots" content="index, follow"><link rel="canonical" href="https://$DOMAIN:$NGINX_PORT/"><meta property="og:title" content="$DOMAIN - Technology Solutions"><meta property="og:description" content="Professional technology services and consulting for modern businesses"><meta property="og:type" content="website"><meta property="og:url" content="https://$DOMAIN:$NGINX_PORT/"><meta property="og:site_name" content="$DOMAIN"><meta name="twitter:card" content="summary"><meta name="twitter:title" content="$DOMAIN - Technology Solutions"><meta name="twitter:description" content="Professional technology services and consulting"><script type="application/ld+json">{"@context":"https://schema.org","@type":"Organization","name":"$DOMAIN","url":"https://$DOMAIN:$NGINX_PORT","description":"Professional technology consulting and software development services","contactPoint":{"@type":"ContactPoint","contactType":"customer service","email":"contact@$DOMAIN"},"sameAs":["https://linkedin.com/company/$DOMAIN","https://github.com/$DOMAIN"]}</script></head><body><header><h1>Welcome to $DOMAIN</h1><nav><ul><li><a href="/services">Services</a></li><li><a href="/about">About</a></li><li><a href="/portfolio">Portfolio</a></li><li><a href="/blog">Blog</a></li><li><a href="/contact">Contact</a></li></ul></nav></header><main><section><h2>🛠️ Our Services</h2><ul><li><strong>Web Development:</strong> Modern, responsive websites and web applications</li><li><strong>Mobile Applications:</strong> Cross-platform mobile solutions for iOS and Android</li><li><strong>Cloud Solutions:</strong> Scalable cloud architecture and migration services</li><li><strong>Digital Consulting:</strong> Strategic technology consulting for digital transformation</li><li><strong>Software Integration:</strong> API development and third-party integrations</li><li><strong>Maintenance & Support:</strong> Ongoing technical support and system maintenance</li></ul></section><section><h2>💡 Why Choose Us</h2><p>With extensive experience in modern technology solutions, we deliver high-quality, scalable results that drive business growth. Our team specializes in:</p><ul><li>✅ Agile development methodologies</li><li>✅ Cloud-native architectures</li><li>✅ Security-first approach</li><li>✅ Performance optimization</li><li>✅ Continuous integration and deployment</li></ul></section><section><h2>🏢 Industry Experience</h2><p>We have successfully delivered projects across various industries including:</p><p><strong>E-commerce, FinTech, HealthTech, Education, Enterprise SaaS, Media & Entertainment</strong></p></section><section><h2>📞 Contact Information</h2><p>Ready to discuss your next project? Get in touch with our team:</p><ul><li>📧 Email: contact@$DOMAIN</li><li>📞 Phone: Available upon request</li><li>🌐 Website: https://$DOMAIN:$NGINX_PORT</li><li>📍 Serving clients globally</li></ul></section></main><footer><p>&copy; 2024 $DOMAIN. All rights reserved.</p><nav><ul><li><a href="/privacy">Privacy Policy</a></li><li><a href="/terms">Terms of Service</a></li><li><a href="/sitemap.xml">Sitemap</a></li></ul></nav></footer></body></html>';
            add_header Content-Type text/html;
            add_header Cache-Control "public, max-age=7200";
        }

        # 主页面路由逻辑 - 动态内容生成
        location / {
            # 搜索引擎爬虫优先处理（SEO优化）
            if (\$user_agent_type = "bot") {
                try_files \$uri @bot_page;
            }
            
            # 根据时间段选择不同的网站类型
            if (\$page_type = "tech") {
                try_files \$uri @tech_blog;
            }
            if (\$page_type = "company") {
                try_files \$uri @company_site;
            }
            if (\$page_type = "portfolio") {
                try_files \$uri @portfolio_site;
            }
            
            # 默认回退到技术博客页面
            try_files \$uri @tech_blog;
        }

        # 健康检查接口
        location /health {
            return 200 '{"status":"ok","timestamp":"\$time_iso8601","tls":true}';
            add_header Content-Type application/json;
        }
    }

    # HTTP 重定向到 HTTPS
    server {
        listen 80;
        server_name $DOMAIN;
        
        # ACME 质询路径
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
        
        # 其他请求重定向到 HTTPS
        location / {
            return 301 https://\$server_name:$NGINX_PORT\$request_uri;
        }
    }
}
EOF
    
    log_success "Nginx配置生成完成"
}

# 生成Docker Compose配置
create_docker_compose() {
    log_step "生成Docker Compose配置..."
    
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  v2ray:
    image: v2fly/v2fly-core:latest
    container_name: v2ray-tls-server
    restart: unless-stopped
    volumes:
      - ./config:/etc/v2ray:ro
      - ./logs:/tmp:rw
    ports:
      - "127.0.0.1:8080:8080"
    environment:
      - TZ=Asia/Shanghai
    networks:
      - v2ray-net
    command: ["run", "-config", "/etc/v2ray/config.json"]
    healthcheck:
      test: ["CMD-SHELL", "netstat -ln | grep :8080 || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3

  nginx:
    image: nginx:alpine
    container_name: v2ray-tls-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "$NGINX_PORT:$NGINX_PORT"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certs:/etc/letsencrypt:ro
      - ./certs/www:/var/www/certbot:ro
      - ./logs:/var/log/nginx:rw
    depends_on:
      - v2ray
    networks:
      - v2ray-net
    healthcheck:
      test: ["CMD-SHELL", "wget -q --spider --no-check-certificate https://localhost:$NGINX_PORT/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  v2ray-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.30.0.0/16
EOF
    
    log_success "Docker Compose配置生成完成"
}

# 配置防火墙
configure_firewall() {
    log_step "配置防火墙..."
    
    local ports=(80 443 "$NGINX_PORT")
    
    # UFW (Ubuntu/Debian)
    if command -v ufw &> /dev/null; then
        for port in "${ports[@]}"; do
            ufw allow "${port}/tcp"
        done
        log_success "UFW防火墙规则已添加"
    # Firewalld (CentOS/RHEL/Fedora)
    elif command -v firewall-cmd &> /dev/null; then
        if systemctl is-active --quiet firewalld; then
            for port in "${ports[@]}"; do
                firewall-cmd --permanent --add-port="${port}/tcp"
            done
            firewall-cmd --reload
            log_success "Firewalld防火墙规则已添加"
        fi
    # iptables (其他系统)
    elif command -v iptables &> /dev/null; then
        for port in "${ports[@]}"; do
            if ! iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null; then
                iptables -I INPUT -p tcp --dport "$port" -j ACCEPT
            fi
        done
        log_success "iptables防火墙规则已添加"
    fi
}

# 启动服务
start_services() {
    log_step "启动V2Ray TLS服务..."
    
    # 拉取最新镜像
    docker-compose pull
    
    # 启动服务
    docker-compose up -d
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 20
    
    # 检查服务状态
    if ! docker-compose ps | grep -q "Up"; then
        log_error "服务启动失败"
        docker-compose logs
        exit 1
    fi
    
    log_success "服务启动成功"
}

# 测试服务
test_services() {
    log_step "测试服务连接..."
    
    local max_attempts=15
    local attempt=1
    
    # 测试HTTPS连接
    while [ $attempt -le $max_attempts ]; do
        if curl -sk --connect-timeout 5 "https://localhost:${NGINX_PORT}/health" > /dev/null; then
            log_success "HTTPS服务测试通过"
            break
        else
            if [ $attempt -eq $max_attempts ]; then
                log_error "HTTPS服务测试失败"
                log_debug "尝试查看Nginx错误日志..."
                docker-compose logs --tail=50 nginx
                exit 1
            fi
            log_info "尝试 $attempt/$max_attempts - 等待HTTPS服务响应..."
            sleep 5
            ((attempt++))
        fi
    done
    
    # 测试证书
    log_info "检查SSL证书..."
    if openssl s_client -connect "localhost:${NGINX_PORT}" -servername "$DOMAIN" </dev/null 2>/dev/null | openssl x509 -noout -text | grep -q "Subject.*$DOMAIN"; then
        log_success "SSL证书验证通过"
    else
        log_warning "SSL证书验证失败，但服务可能仍能正常工作"
    fi
}

# 保存配置信息
save_config_info() {
    log_step "保存配置信息..."
    
    local tls_note=""
    if [ "$CERT_METHOD" = "self-signed" ]; then
        tls_note="（自签名证书，客户端需要允许不安全连接）"
    fi
    
    cat > connection-info.txt << EOF
========================================
V2Ray TLS 部署信息
========================================

部署时间: $(date)
域名: $DOMAIN
端口: $NGINX_PORT
UUID: $NEW_UUID
传输协议: WebSocket (ws)
WebSocket路径: $WS_PATH
TLS: 开启 $tls_note
证书类型: $CERT_METHOD

========================================
客户端配置 (Shadowrocket/V2rayN)
========================================

类型: VMess
服务器: $DOMAIN
端口: $NGINX_PORT
用户ID: $NEW_UUID
额外ID: 0
加密方式: auto
传输协议: WebSocket (ws)
路径: $WS_PATH
Host: $DOMAIN
TLS: 开启
SNI: $DOMAIN
允许不安全: $([ "$CERT_METHOD" = "self-signed" ] && echo "开启" || echo "关闭")

========================================
VMess 分享链接
========================================

$(echo '{
  "v": "2",
  "ps": "'$DOMAIN'-TLS",
  "add": "'$DOMAIN'",
  "port": "'$NGINX_PORT'",
  "id": "'$NEW_UUID'",
  "aid": "0",
  "scy": "auto",
  "net": "ws",
  "type": "none",
  "host": "'$DOMAIN'",
  "path": "'$WS_PATH'",
  "tls": "tls",
  "sni": "'$DOMAIN'",
  "alpn": ""
}' | base64 -w 0)

上面的字符串前加上 vmess:// 即可导入客户端

========================================
管理命令
========================================

查看服务状态:
cd $V2RAY_DIR && docker-compose ps

查看日志:
cd $V2RAY_DIR && docker-compose logs -f

重启服务:
cd $V2RAY_DIR && docker-compose restart

停止服务:
cd $V2RAY_DIR && docker-compose down

更新服务:
cd $V2RAY_DIR && docker-compose pull && docker-compose up -d

续期证书（Let's Encrypt）:
$V2RAY_DIR/scripts/renew-cert.sh

========================================
测试命令
========================================

测试HTTPS连接:
curl -k https://$DOMAIN:$NGINX_PORT/health

测试证书:
openssl s_client -connect $DOMAIN:$NGINX_PORT -servername $DOMAIN

========================================
注意事项
========================================

1. 请确保云服务商安全组开放了 80, $NGINX_PORT 端口
2. 域名 $DOMAIN 必须正确解析到此服务器IP
3. 服务配置文件位于: $V2RAY_DIR
4. 日志文件位于: $V2RAY_DIR/logs
$([ "$CERT_METHOD" = "letsencrypt" ] && echo "5. Let's Encrypt 证书将自动续期" || echo "5. 使用自签名证书，客户端可能需要特殊配置")

EOF
    
    log_success "配置信息已保存到: $PWD/connection-info.txt"
}

# 显示部署结果
show_deployment_result() {
    echo
    echo -e "${GREEN}${BOLD}========================================${NC}"
    echo -e "${GREEN}${BOLD}      🎉 V2Ray TLS 部署成功！ 🎉      ${NC}"
    echo -e "${GREEN}${BOLD}========================================${NC}"
    echo
    echo -e "${BLUE}📋 连接信息:${NC}"
    echo -e "   域名: ${BOLD}$DOMAIN${NC}"
    echo -e "   端口: ${BOLD}$NGINX_PORT${NC}"
    echo -e "   UUID: ${BOLD}$NEW_UUID${NC}"
    echo -e "   传输协议: ${BOLD}WebSocket (ws)${NC}"
    echo -e "   路径: ${BOLD}$WS_PATH${NC}"
    echo -e "   TLS: ${BOLD}开启${NC}"
    if [ "$CERT_METHOD" = "self-signed" ]; then
        echo -e "   证书: ${YELLOW}自签名（需允许不安全连接）${NC}"
    else
        echo -e "   证书: ${GREEN}Let's Encrypt${NC}"
    fi
    echo
    echo -e "${CYAN}🔗 快速连接:${NC}"
    echo -e "   Web测试: ${BOLD}https://$DOMAIN:$NGINX_PORT${NC}"
    echo -e "   健康检查: ${BOLD}https://$DOMAIN:$NGINX_PORT/health${NC}"
    echo
    echo -e "${YELLOW}⚠️  重要提醒:${NC}"
    echo -e "   • 请确保域名 ${BOLD}$DOMAIN${NC} 正确解析到此服务器"
    echo -e "   • 请确保云服务商安全组开放了 ${BOLD}80, $NGINX_PORT${NC} 端口"
    echo -e "   • 配置信息已保存到 ${BOLD}$PWD/connection-info.txt${NC}"
    echo
    echo -e "${PURPLE}🔧 管理命令:${NC}"
    echo -e "   查看状态: ${BOLD}cd $V2RAY_DIR && docker-compose ps${NC}"
    echo -e "   查看日志: ${BOLD}cd $V2RAY_DIR && docker-compose logs -f${NC}"
    echo -e "   重启服务: ${BOLD}cd $V2RAY_DIR && docker-compose restart${NC}"
    if [ "$CERT_METHOD" = "letsencrypt" ]; then
        echo -e "   续期证书: ${BOLD}$V2RAY_DIR/scripts/renew-cert.sh${NC}"
    fi
    echo
}

# 主函数
main() {
    echo -e "${PURPLE}${BOLD}"
    echo "========================================="
    echo "         V2Ray TLS 一键部署脚本         "
    echo "========================================="
    echo -e "${NC}"
    
    parse_arguments "$@"
    check_root
    validate_domain
    validate_email
    check_dns_resolution
    check_system_requirements
    check_ports
    install_docker
    install_docker_compose
    setup_directories
    setup_ssl_certificate
    create_cert_renewal_script
    create_v2ray_config
    create_nginx_config
    create_docker_compose
    configure_firewall
    start_services
    test_services
    save_config_info
    show_deployment_result
    
    log_success "部署完成！"
}

# 执行主函数
main "$@"