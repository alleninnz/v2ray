#!/bin/bash

# ========================================
# V2Ray Basic Deployment Script (无TLS版本)
# 一键部署V2Ray + Nginx反向代理
# ========================================

set -euo pipefail  # 严格错误处理

# 颜色和格式化
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# 配置变量
V2RAY_DIR="/opt/v2ray-basic"
V2RAY_PORT="8080"
NGINX_PORT="10086"
WS_PATH="/ray"

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

# 检查是否以root权限运行
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用root权限运行此脚本"
        echo "使用命令: sudo bash $0"
        exit 1
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
    
    # 检查系统架构
    ARCH=$(uname -m)
    if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "aarch64" ]; then
        log_warning "系统架构 $ARCH 可能不完全支持"
    fi
    
    # 检查内存
    MEMORY_MB=$(free -m | awk 'NR==2{print $2}')
    if [ "$MEMORY_MB" -lt 512 ]; then
        log_warning "系统内存不足512MB，可能影响运行性能"
    fi
    
    # 检查磁盘空间
    DISK_AVAILABLE=$(df / | awk 'NR==2 {print $4}')
    if [ "$DISK_AVAILABLE" -lt 1048576 ]; then  # 1GB
        log_warning "可用磁盘空间不足1GB"
    fi
}

# 检查端口是否被占用
check_ports() {
    log_step "检查端口占用情况..."
    
    if netstat -tlnp 2>/dev/null | grep -q ":${NGINX_PORT} "; then
        log_error "端口 ${NGINX_PORT} 已被占用"
        netstat -tlnp | grep ":${NGINX_PORT} "
        exit 1
    fi
    
    if netstat -tlnp 2>/dev/null | grep -q ":${V2RAY_PORT} "; then
        log_error "端口 ${V2RAY_PORT} 已被占用"
        netstat -tlnp | grep ":${V2RAY_PORT} "
        exit 1
    fi
    
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

# 获取服务器IP
get_server_ip() {
    log_step "获取服务器公网IP..."
    
    SERVER_IP=$(curl -s --connect-timeout 10 ifconfig.me 2>/dev/null || \
                curl -s --connect-timeout 10 icanhazip.com 2>/dev/null || \
                curl -s --connect-timeout 10 ipecho.net/plain 2>/dev/null || \
                curl -s --connect-timeout 10 checkip.amazonaws.com 2>/dev/null || \
                echo "")
    
    if [ -z "$SERVER_IP" ]; then
        log_warning "无法自动获取公网IP，请手动确认"
        read -p "请输入服务器公网IP: " SERVER_IP
        if [ -z "$SERVER_IP" ]; then
            log_error "必须提供服务器IP"
            exit 1
        fi
    fi
    
    # 验证IP格式
    if ! [[ "$SERVER_IP" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        log_error "IP地址格式无效: $SERVER_IP"
        exit 1
    fi
    
    log_success "服务器IP: $SERVER_IP"
}

# 创建项目目录结构
setup_directories() {
    log_step "创建项目目录..."
    
    rm -rf "$V2RAY_DIR"
    mkdir -p "$V2RAY_DIR"/{config,nginx,logs}
    cd "$V2RAY_DIR"
    
    log_success "项目目录创建完成: $V2RAY_DIR"
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
            "email": "user@v2ray-basic.local"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "$WS_PATH",
          "headers": {
            "Host": "$SERVER_IP"
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
    
    cat > nginx/nginx.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;
    
    # 日志格式
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
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

    # 主服务器配置
    server {
        listen 10086;
        server_name _;

        # 访问日志
        access_log /var/log/nginx/access.log main;
        error_log /var/log/nginx/error.log warn;

        # WebSocket 代理配置
        location /ray {
            proxy_redirect off;
            proxy_pass http://v2ray;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_read_timeout 86400;
            proxy_send_timeout 86400;
        }

        # 伪装网站首页
        location / {
            return 200 '<!DOCTYPE html><html><head><title>Welcome</title><meta charset="utf-8"><style>body{font-family:Arial,sans-serif;margin:0;padding:40px;background:#f5f5f5;}h1{color:#333;text-align:center;}p{color:#666;text-align:center;}</style></head><body><h1>🌟 Server is Running</h1><p>Everything looks good!</p><p>Server Time: <span id="time"></span></p><script>document.getElementById("time").textContent=new Date().toLocaleString();</script></body></html>';
            add_header Content-Type text/html;
        }

        # 健康检查接口
        location /health {
            return 200 '{"status":"ok","timestamp":"$time_iso8601"}';
            add_header Content-Type application/json;
        }
    }
}
EOF
    
    log_success "Nginx配置生成完成"
}

# 生成Docker Compose配置
create_docker_compose() {
    log_step "生成Docker Compose配置..."
    
    cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  v2ray:
    image: v2fly/v2fly-core:latest
    container_name: v2ray-basic-server
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
    container_name: v2ray-basic-nginx
    restart: unless-stopped
    ports:
      - "10086:10086"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./logs:/var/log/nginx:rw
    depends_on:
      - v2ray
    networks:
      - v2ray-net
    healthcheck:
      test: ["CMD-SHELL", "wget -q --spider http://localhost:10086/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  v2ray-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
EOF
    
    log_success "Docker Compose配置生成完成"
}

# 配置防火墙
configure_firewall() {
    log_step "配置防火墙..."
    
    # UFW (Ubuntu/Debian)
    if command -v ufw &> /dev/null; then
        ufw allow ${NGINX_PORT}/tcp
        log_success "UFW防火墙规则已添加"
    # Firewalld (CentOS/RHEL/Fedora)
    elif command -v firewall-cmd &> /dev/null; then
        if systemctl is-active --quiet firewalld; then
            firewall-cmd --permanent --add-port=${NGINX_PORT}/tcp
            firewall-cmd --reload
            log_success "Firewalld防火墙规则已添加"
        fi
    # iptables (其他系统)
    elif command -v iptables &> /dev/null; then
        if ! iptables -C INPUT -p tcp --dport ${NGINX_PORT} -j ACCEPT 2>/dev/null; then
            iptables -I INPUT -p tcp --dport ${NGINX_PORT} -j ACCEPT
            log_success "iptables防火墙规则已添加"
        fi
    fi
}

# 启动服务
start_services() {
    log_step "启动V2Ray服务..."
    
    # 拉取最新镜像
    docker-compose pull
    
    # 启动服务
    docker-compose up -d
    
    # 等待服务启动
    log_info "等待服务启动..."
    sleep 15
    
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
    
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if curl -s --connect-timeout 5 http://localhost:${NGINX_PORT}/health > /dev/null; then
            log_success "服务测试通过"
            break
        else
            if [ $attempt -eq $max_attempts ]; then
                log_error "服务测试失败"
                docker-compose logs --tail=50
                exit 1
            fi
            log_info "尝试 $attempt/$max_attempts - 等待服务响应..."
            sleep 5
            ((attempt++))
        fi
    done
}

# 保存配置信息
save_config_info() {
    log_step "保存配置信息..."
    
    cat > connection-info.txt << EOF
========================================
V2Ray Basic 部署信息
========================================

部署时间: $(date)
服务器IP: $SERVER_IP
端口: $NGINX_PORT
UUID: $NEW_UUID
传输协议: WebSocket (ws)
WebSocket路径: $WS_PATH
TLS: 关闭

========================================
客户端配置 (Shadowrocket/V2rayN)
========================================

类型: VMess
服务器: $SERVER_IP
端口: $NGINX_PORT
用户ID: $NEW_UUID
额外ID: 0
加密方式: auto
传输协议: WebSocket (ws)
路径: $WS_PATH
Host: $SERVER_IP
TLS: 关闭

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

========================================
注意事项
========================================

1. 请确保云服务商安全组开放了 $NGINX_PORT 端口
2. 服务配置文件位于: $V2RAY_DIR
3. 日志文件位于: $V2RAY_DIR/logs
4. 如需修改配置，请编辑配置文件后重启服务

EOF
    
    log_success "配置信息已保存到: $PWD/connection-info.txt"
}

# 显示部署结果
show_deployment_result() {
    echo
    echo -e "${GREEN}${BOLD}========================================${NC}"
    echo -e "${GREEN}${BOLD}     🎉 V2Ray Basic 部署成功！ 🎉     ${NC}"
    echo -e "${GREEN}${BOLD}========================================${NC}"
    echo
    echo -e "${BLUE}📋 连接信息:${NC}"
    echo -e "   服务器地址: ${BOLD}$SERVER_IP${NC}"
    echo -e "   端口: ${BOLD}$NGINX_PORT${NC}"
    echo -e "   UUID: ${BOLD}$NEW_UUID${NC}"
    echo -e "   传输协议: ${BOLD}WebSocket (ws)${NC}"
    echo -e "   路径: ${BOLD}$WS_PATH${NC}"
    echo -e "   TLS: ${BOLD}关闭${NC}"
    echo
    echo -e "${YELLOW}⚠️  重要提醒:${NC}"
    echo -e "   • 请确保云服务商安全组开放了 ${BOLD}$NGINX_PORT${NC} 端口"
    echo -e "   • 配置信息已保存到 ${BOLD}$PWD/connection-info.txt${NC}"
    echo
    echo -e "${PURPLE}🔧 管理命令:${NC}"
    echo -e "   查看状态: ${BOLD}cd $V2RAY_DIR && docker-compose ps${NC}"
    echo -e "   查看日志: ${BOLD}cd $V2RAY_DIR && docker-compose logs -f${NC}"
    echo -e "   重启服务: ${BOLD}cd $V2RAY_DIR && docker-compose restart${NC}"
    echo
}

# 主函数
main() {
    echo -e "${PURPLE}${BOLD}"
    echo "========================================="
    echo "        V2Ray Basic 一键部署脚本        "
    echo "========================================="
    echo -e "${NC}"
    
    check_root
    check_system_requirements
    check_ports
    install_docker
    install_docker_compose
    get_server_ip
    setup_directories
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