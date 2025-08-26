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
NEW_UUID=""  # 全局UUID变量

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

# 清理临时文件函数
cleanup_temp_files() {
    log_info "清理临时文件..."
    
    # 清理可能的临时文件
    rm -f /tmp/get-docker.sh 2>/dev/null || true
    rm -f /tmp/docker-compose-* 2>/dev/null || true
    
    # 安全清理临时目录 - 避免符号链接攻击
    # 只清理我们自己创建的临时目录，使用更安全的方法
    if [ -n "${TEMP_DIR:-}" ] && [ -d "${TEMP_DIR:-}" ]; then
        # 确保这是一个我们创建的临时目录
        if [[ "$TEMP_DIR" =~ ^/tmp/v2ray-deploy\.[A-Za-z0-9]+$ ]]; then
            rm -rf "$TEMP_DIR" 2>/dev/null || true
        fi
    fi
    
    # 清理我们特定的临时文件（避免通配符攻击）
    local temp_files=(
        "/tmp/v2ray-deploy.pid"
        "/tmp/v2ray-deploy.lock"
        "/tmp/v2ray-config-temp"
    )
    for temp_file in "${temp_files[@]}"; do
        if [ -f "$temp_file" ]; then
            rm -f "$temp_file" 2>/dev/null || true
        fi
    done
}

# 创建安全的临时目录
create_secure_temp_dir() {
    # 使用mktemp创建安全的临时目录
    local temp_dir
    if ! temp_dir=$(mktemp -d -t v2ray-deploy.XXXXXXXXXX 2>/dev/null) || [ -z "$temp_dir" ]; then
        log_error "无法创建临时目录"
        return 1
    fi
    
    # 设置严格的权限（只有创建者可读写执行）
    chmod 700 "$temp_dir"
    
    # 设置全局变量以便清理
    TEMP_DIR="$temp_dir"
    echo "$temp_dir"
}

# 错误处理函数
cleanup_on_error() {
    log_error "部署失败，正在清理..."
    
    # 停止可能运行的容器
    if [ -d "$V2RAY_DIR" ] && [ -f "$V2RAY_DIR/docker-compose.yml" ]; then
        cd "$V2RAY_DIR" && docker-compose down 2>/dev/null || true
    fi
    
    # 清理临时文件
    cleanup_temp_files
    
    # 不删除目录，以便用户调试
    if [ -d "$V2RAY_DIR" ]; then
        log_info "配置文件保留在: $V2RAY_DIR (用于调试)"
    fi
    
    exit 1
}

# 设置错误陷阱
trap cleanup_on_error ERR
trap cleanup_temp_files EXIT

# 检查是否以root权限运行
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
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
            OS="$NAME"
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
    MEMORY_MB=$(free -m 2>/dev/null | awk 'NR==2{print $2}' || echo "0")
    if [ "${MEMORY_MB:-0}" -lt 512 ] && [ "${MEMORY_MB:-0}" -gt 0 ]; then
        log_warning "系统内存不足512MB，可能影响运行性能"
    fi
    
    # 检查磁盘空间
    DISK_AVAILABLE=$(df / 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
    if [ "${DISK_AVAILABLE:-0}" -lt 1048576 ] && [ "${DISK_AVAILABLE:-0}" -gt 0 ]; then  # 1GB
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
        
        # 安全的Docker安装方法
        case "$(uname -s)" in
            Linux*)
                if command -v apt &> /dev/null; then
                    # Ubuntu/Debian
                    apt update
                    apt install -y apt-transport-https ca-certificates curl gnupg lsb-release
                    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
                    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
                    apt update
                    apt install -y docker-ce docker-ce-cli containerd.io
                elif command -v yum &> /dev/null; then
                    # CentOS/RHEL
                    yum install -y yum-utils
                    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                    yum install -y docker-ce docker-ce-cli containerd.io
                elif command -v dnf &> /dev/null; then
                    # Fedora
                    dnf -y install dnf-plugins-core
                    dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
                    dnf install -y docker-ce docker-ce-cli containerd.io
                else
                    log_error "不支持的操作系统，请手动安装Docker"
                    exit 1
                fi
                ;;
            *)
                log_error "不支持的操作系统，请手动安装Docker"
                exit 1
                ;;
        esac
        
        systemctl start docker
        systemctl enable docker
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
            # 手动安装最新版本 - 增加安全验证
            log_info "从GitHub下载Docker Compose..."
            
            # 获取最新版本，增加错误检查
            COMPOSE_VERSION=$(curl -s --connect-timeout 10 --max-time 30 https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
            
            if [ -z "$COMPOSE_VERSION" ]; then
                log_error "无法获取Docker Compose版本信息"
                exit 1
            fi
            
            log_info "下载 Docker Compose $COMPOSE_VERSION..."
            
            # 创建临时目录
            TEMP_DIR=$(mktemp -d)
            COMPOSE_URL="https://github.com/docker/compose/releases/download/${COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)"
            
            # 下载文件和校验和
            local checksum_url="${COMPOSE_URL}.sha256"
            
            if ! curl -L --connect-timeout 10 --max-time 300 "$COMPOSE_URL" -o "$TEMP_DIR/docker-compose"; then
                log_error "下载Docker Compose失败"
                rm -rf "$TEMP_DIR"
                exit 1
            fi
            
            # 验证下载的文件
            if [ ! -s "$TEMP_DIR/docker-compose" ]; then
                log_error "下载的Docker Compose文件为空"
                rm -rf "$TEMP_DIR"
                exit 1
            fi
            
            # 尝试下载并验证校验和（如果可用）
            log_info "尝试验证文件完整性..."
            if curl -L --connect-timeout 10 --max-time 30 "$checksum_url" -o "$TEMP_DIR/docker-compose.sha256" 2>/dev/null; then
                cd "$TEMP_DIR" || exit 1
                if command -v sha256sum &> /dev/null; then
                    if ! sha256sum -c docker-compose.sha256 >/dev/null 2>&1; then
                        log_warning "SHA256校验失败，但继续安装（请注意安全风险）"
                    else
                        log_success "文件完整性验证通过"
                    fi
                elif command -v shasum &> /dev/null; then
                    local expected_hash
                    local actual_hash
                    expected_hash=$(cut -d' ' -f1 docker-compose.sha256)
                    actual_hash=$(shasum -a 256 docker-compose | cut -d' ' -f1)
                    if [ "$expected_hash" != "$actual_hash" ]; then
                        log_warning "SHA256校验失败，但继续安装（请注意安全风险）"
                    else
                        log_success "文件完整性验证通过"
                    fi
                fi
                cd - >/dev/null || exit 1
            else
                log_warning "无法获取校验和文件，跳过完整性验证"
            fi
            
            # 安装文件
            chmod +x "$TEMP_DIR/docker-compose"
            mv "$TEMP_DIR/docker-compose" /usr/local/bin/docker-compose
            ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose
            
            # 清理临时目录
            rm -rf "$TEMP_DIR"
        fi
        
        log_success "Docker Compose 安装完成"
        docker-compose --version
    fi
}

# 生成UUID
generate_uuid() {
    local uuid=""
    
    # 尝试多种UUID生成方法
    if command -v uuidgen &> /dev/null; then
        uuid=$(uuidgen 2>/dev/null)
    elif command -v python3 &> /dev/null; then
        uuid=$(python3 -c "import uuid; print(uuid.uuid4())" 2>/dev/null)
    elif command -v python &> /dev/null; then
        uuid=$(python -c "import uuid; print(uuid.uuid4())" 2>/dev/null)
    elif [ -r /proc/sys/kernel/random/uuid ]; then
        uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null)
    else
        # 安全的备选方案 - 避免复杂管道命令
        # 直接使用Python生成UUID（更安全）
        if command -v python3 &> /dev/null; then
            uuid=$(python3 -c "import uuid; print(str(uuid.uuid4()))" 2>/dev/null)
        elif command -v python &> /dev/null; then
            uuid=$(python -c "import uuid; print(str(uuid.uuid4()))" 2>/dev/null)
        else
            # 最后的安全备选方案：使用/dev/urandom的十六进制读取
            uuid=""
            if [ -r /dev/urandom ]; then
                # 生成128位随机数据并格式化为UUID
                local hex_data
                hex_data=$(dd if=/dev/urandom bs=16 count=1 2>/dev/null | xxd -p -c 16)
                if [ ${#hex_data} -eq 32 ]; then
                    # 格式化为标准UUID格式 (8-4-4-4-12)
                    uuid="${hex_data:0:8}-${hex_data:8:4}-${hex_data:12:4}-${hex_data:16:4}-${hex_data:20:12}"
                fi
            fi
        fi
    fi
    
    # 验证UUID格式
    if [[ "$uuid" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
        echo "$uuid"
    else
        log_error "生成的UUID格式无效: $uuid"
        return 1
    fi
}

# 获取服务器IP
get_server_ip() {
    log_step "获取服务器公网IP..."
    
    # 定义可信的IP查询服务
    local ip_services=(
        "https://ifconfig.me"
        "https://icanhazip.com"
        "https://ipecho.net/plain"
        "https://checkip.amazonaws.com"
    )
    
    SERVER_IP=""
    
    # 尝试从多个服务获取IP
    for service in "${ip_services[@]}"; do
        log_info "尝试从 $service 获取IP..."
        IP_RESULT=$(curl -s --connect-timeout 10 --max-time 15 "$service" 2>/dev/null | tr -d '\n\r' || echo "")
        
        # 验证IP格式
        if [[ "$IP_RESULT" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            # 进一步验证IP地址的有效性
            if validate_ip_address "$IP_RESULT"; then
                SERVER_IP="$IP_RESULT"
                log_success "获取到公网IP: $SERVER_IP"
                break
            fi
        fi
    done
    
    if [ -z "$SERVER_IP" ]; then
        log_warning "无法自动获取公网IP，请手动输入"
        while true; do
            read -r -p "请输入服务器公网IP: " SERVER_IP
            if [ -z "$SERVER_IP" ]; then
                log_error "IP地址不能为空"
                continue
            fi
            
            if validate_ip_address "$SERVER_IP"; then
                break
            else
                log_error "IP地址格式无效: $SERVER_IP"
            fi
        done
    fi
    
    log_success "使用服务器IP: $SERVER_IP"
}

# IP地址验证函数（增强安全检查）
validate_ip_address() {
    local ip=$1
    
    # 检查输入是否为空
    if [[ -z "$ip" ]]; then
        return 1
    fi
    
    # 检查是否包含危险字符
    if echo "$ip" | grep -q '[;&|`$(){}[\]\\<>"\'"'"'*?~#%=]'; then
        log_error "IP地址包含危险字符: $ip"
        return 1
    fi
    
    # 检查是否包含控制字符或空格
    if echo "$ip" | grep -q '[[:space:][:cntrl:]]'; then
        log_error "IP地址包含非法字符: $ip"
        return 1
    fi
    
    # 基本格式检查
    if ! [[ "$ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 1
    fi
    
    # 检查每个部分是否在有效范围内
    IFS='.' read -ra ADDR <<< "$ip"
    for i in "${ADDR[@]}"; do
        if [ "$i" -gt 255 ] || [ "$i" -lt 0 ]; then
            return 1
        fi
    done
    
    # 检查是否为私有地址或特殊地址
    if [[ "$ip" =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|127\.|169\.254\.|224\.|240\.) ]]; then
        log_warning "检测到私有或特殊IP地址: $ip"
        return 1
    fi
    
    return 0
}

# 创建项目目录结构
setup_directories() {
    log_step "创建项目目录..."
    
    # 验证目录路径安全性
    if [[ "$V2RAY_DIR" =~ \.\. ]] || [[ "$V2RAY_DIR" =~ ^/ ]] && [[ "$V2RAY_DIR" != "/opt/v2ray-basic" ]]; then
        log_error "不安全的目录路径: $V2RAY_DIR"
        exit 1
    fi
    
    # 如果目录存在，先备份
    if [ -d "$V2RAY_DIR" ]; then
        log_warning "目录已存在，创建备份..."
        BACKUP_DIR="${V2RAY_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
        mv "$V2RAY_DIR" "$BACKUP_DIR"
        log_info "原目录已备份到: $BACKUP_DIR"
    fi
    
    # 创建目录并设置权限
    mkdir -p "$V2RAY_DIR"/{config,nginx,logs}
    
    # 设置适当的权限
    chmod 755 "$V2RAY_DIR"
    chmod 750 "$V2RAY_DIR/config"  # 配置目录更严格的权限
    chmod 755 "$V2RAY_DIR/nginx"
    chmod 755 "$V2RAY_DIR/logs"
    
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
    
    # 验证变量安全性
    if [[ "$NEW_UUID" =~ [^a-fA-F0-9\-] ]]; then
        log_error "UUID包含无效字符"
        exit 1
    fi
    
    if [[ "$WS_PATH" =~ [^a-zA-Z0-9\/\-_] ]]; then
        log_error "WebSocket路径包含无效字符"
        exit 1
    fi
    
    if [[ "$SERVER_IP" =~ [^0-9\.] ]]; then
        log_error "服务器IP包含无效字符"
        exit 1
    fi
    
    # 创建配置文件
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
    
    # 设置配置文件权限
    chmod 600 config/config.json
    
    # 验证JSON格式（如果有python）
    if command -v python3 &> /dev/null; then
        if ! python3 -m json.tool config/config.json > /dev/null 2>&1; then
            log_error "生成的V2Ray配置JSON格式无效"
            exit 1
        fi
    elif command -v python &> /dev/null; then
        if ! python -m json.tool config/config.json > /dev/null 2>&1; then
            log_error "生成的V2Ray配置JSON格式无效"
            exit 1
        fi
    else
        log_info "跳过JSON格式验证（未找到Python）"
    fi
    
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
    security_opt:
      - no-new-privileges:true
    read_only: true
    tmpfs:
      - /tmp:rw,noexec,nosuid,size=50m

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
    security_opt:
      - no-new-privileges:true

networks:
  v2ray-net:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
EOF
    
    # 设置配置文件权限
    chmod 644 docker-compose.yml
    
    log_success "Docker Compose配置生成完成"
}

# 配置防火墙
configure_firewall() {
    log_step "配置防火墙..."
    
    # UFW (Ubuntu/Debian)
    if command -v ufw &> /dev/null; then
        ufw allow "${NGINX_PORT}/tcp"
        log_success "UFW防火墙规则已添加"
    # Firewalld (CentOS/RHEL/Fedora)
    elif command -v firewall-cmd &> /dev/null; then
        if systemctl is-active --quiet firewalld; then
            firewall-cmd --permanent --add-port="${NGINX_PORT}/tcp"
            firewall-cmd --reload
            log_success "Firewalld防火墙规则已添加"
        fi
    # iptables (其他系统)
    elif command -v iptables &> /dev/null; then
        if ! iptables -C INPUT -p tcp --dport "${NGINX_PORT}" -j ACCEPT 2>/dev/null; then
            iptables -I INPUT -p tcp --dport "${NGINX_PORT}" -j ACCEPT
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