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
DEBUG_MODE=false

# 脚本目录（在脚本开始时就计算，避免工作目录变化导致的问题）
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 验证脚本依赖文件
validate_script_files() {
    local missing_files=()
    local required_files=(
        "$SCRIPT_DIR/configs/v2ray/config.json.template"
        "$SCRIPT_DIR/configs/nginx/nginx.conf.template" 
        "$SCRIPT_DIR/configs/docker/docker-compose.yml.template"
        "$SCRIPT_DIR/assets"
    )
    
    for file in "${required_files[@]}"; do
        if [[ "$file" == *"/assets" ]]; then
            if [ ! -d "$file" ]; then
                missing_files+=("$file (目录)")
            fi
        else
            if [ ! -f "$file" ]; then
                missing_files+=("$file")
            fi
        fi
    done
    
    if [ ${#missing_files[@]} -gt 0 ]; then
        log_error "缺少必需的文件或目录:"
        for file in "${missing_files[@]}"; do
            log_error "  - $file"
        done
        log_error "请确保从完整的项目目录运行此脚本"
        exit 1
    fi
}

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
    if [ "$DEBUG_MODE" = true ]; then
        echo -e "${CYAN}[DEBUG]${NC} $1"
    fi
}

# 模板处理函数
process_template() {
    local template_file="$1"
    local output_file="$2"
    
    if [ ! -f "$template_file" ]; then
        log_error "模板文件不存在: $template_file"
        exit 1
    fi
    
    # Replace template variables with actual values
    sed -e "s|{{DOMAIN}}|$DOMAIN|g" \
        -e "s|{{UUID}}|$NEW_UUID|g" \
        -e "s|{{WS_PATH}}|$WS_PATH|g" \
        -e "s|{{NGINX_PORT}}|$NGINX_PORT|g" \
        -e "s|{{V2RAY_DIR}}|$V2RAY_DIR|g" \
        "$template_file" > "$output_file"
    
    log_success "已生成配置文件: $output_file"
}

# 错误处理函数
cleanup_on_error() {
    local exit_code=$?
    log_error "部署失败，正在清理... (错误代码: $exit_code)"
    
    # 防止清理过程中的错误导致脚本再次触发陷阱
    set +e
    
    if [ -d "$V2RAY_DIR" ]; then
        log_info "清理部署目录: $V2RAY_DIR"
        cd "$V2RAY_DIR" 2>/dev/null && {
            if [ -f "docker-compose.yml" ]; then
                log_info "停止Docker容器..."
                docker-compose down 2>/dev/null || log_warning "无法停止Docker容器"
            fi
        }
        
        # 询问用户是否删除目录
        if [ -t 0 ] && [ -t 1 ]; then
            echo
            read -p "是否删除部署目录 $V2RAY_DIR? (y/N): " -r
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm -rf "$V2RAY_DIR" || log_warning "无法删除目录 $V2RAY_DIR"
                log_info "部署目录已删除"
            else
                log_info "保留部署目录: $V2RAY_DIR"
            fi
        else
            log_info "保留部署目录: $V2RAY_DIR"
            log_info "如需删除，请手动执行: rm -rf $V2RAY_DIR"
        fi
    fi
    
    log_error "部署失败，请查看上述错误信息并重试"
    exit $exit_code
}

# 安全退出函数
safe_exit() {
    local exit_code=${1:-0}
    set +e
    exit $exit_code
}

# 设置错误陷阱
trap cleanup_on_error ERR
trap 'safe_exit 130' INT  # Ctrl+C
trap 'safe_exit 143' TERM # 终止信号

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
    echo "      --debug             启用调试模式，显示详细输出"
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
            --debug)
                DEBUG_MODE=true
                shift
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
    
    log_info "服务器公网IP: $server_ip"
    
    local domain_ip=""
    
    # 尝试使用不同的DNS查询工具
    if command -v dig &> /dev/null; then
        log_debug "使用 dig 查询域名解析..."
        domain_ip=$(dig +short "$DOMAIN" @8.8.8.8 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1 || echo "")
    fi
    
    # 如果dig失败，尝试使用nslookup
    if [ -z "$domain_ip" ] && command -v nslookup &> /dev/null; then
        log_debug "dig 查询失败，尝试使用 nslookup..."
        domain_ip=$(nslookup "$DOMAIN" 8.8.8.8 2>/dev/null | awk '/^Address: / { print $2 }' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1 || echo "")
    fi
    
    # 如果nslookup也失败，尝试使用host
    if [ -z "$domain_ip" ] && command -v host &> /dev/null; then
        log_debug "nslookup 查询失败，尝试使用 host..."
        domain_ip=$(host "$DOMAIN" 8.8.8.8 2>/dev/null | awk '/has address/ { print $4 }' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1 || echo "")
    fi
    
    # 如果所有方法都失败，尝试使用getent（系统DNS解析）
    if [ -z "$domain_ip" ] && command -v getent &> /dev/null; then
        log_debug "其他查询方法失败，尝试使用系统DNS解析..."
        domain_ip=$(getent hosts "$DOMAIN" 2>/dev/null | awk '{ print $1 }' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1 || echo "")
    fi
    
    # 检查DNS解析结果
    if [ -z "$domain_ip" ]; then
        log_warning "无法解析域名 $DOMAIN，请确认DNS配置正确"
        log_info "建议检查："
        log_info "1. 域名是否正确配置A记录指向服务器IP"
        log_info "2. DNS设置是否已生效（可能需要等待最多24小时）"
        log_info "3. 网络连接是否正常"
        if [ "$CERT_METHOD" = "letsencrypt" ]; then
            log_warning "Let's Encrypt 证书验证可能会失败"
            log_info "如果DNS未正确配置，建议使用自签名证书：-c self-signed"
        fi
    elif [ "$domain_ip" != "$server_ip" ]; then
        log_warning "域名解析IP ($domain_ip) 与服务器IP ($server_ip) 不匹配"
        log_info "可能的原因："
        log_info "1. 域名A记录未正确设置"
        log_info "2. DNS缓存未更新（等待DNS传播）"
        log_info "3. 使用了CDN或代理服务"
        if [ "$CERT_METHOD" = "letsencrypt" ]; then
            log_warning "Let's Encrypt 证书验证可能会失败"
            log_info "建议先修复DNS解析或使用自签名证书：-c self-signed"
        fi
    else
        log_success "域名DNS解析正确 ($DOMAIN -> $domain_ip)"
    fi
    
    # DNS检查不应该阻止脚本继续执行
    return 0
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
    local required_tools=("curl" "openssl")
    local dns_tools=("dig" "nslookup" "host")
    
    # 检查基础工具
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_info "安装缺失工具: $tool"
            if command -v apt &> /dev/null; then
                apt update && apt install -y "$tool" || log_warning "无法安装 $tool"
            elif command -v yum &> /dev/null; then
                yum install -y "$tool" || log_warning "无法安装 $tool"
            elif command -v dnf &> /dev/null; then
                dnf install -y "$tool" || log_warning "无法安装 $tool"
            else
                log_warning "无法自动安装 $tool，请手动安装"
            fi
        fi
    done
    
    # 检查DNS查询工具（至少需要一个）
    local dns_tool_available=false
    for tool in "${dns_tools[@]}"; do
        if command -v "$tool" &> /dev/null; then
            dns_tool_available=true
            log_debug "找到DNS查询工具: $tool"
            break
        fi
    done
    
    if ! $dns_tool_available; then
        log_info "安装DNS查询工具..."
        if command -v apt &> /dev/null; then
            apt update && apt install -y dnsutils || log_warning "无法安装dnsutils包"
        elif command -v yum &> /dev/null; then
            yum install -y bind-utils || log_warning "无法安装bind-utils包"
        elif command -v dnf &> /dev/null; then
            dnf install -y bind-utils || log_warning "无法安装bind-utils包"
        else
            log_warning "无法自动安装DNS工具，DNS检查可能不准确"
        fi
    fi
    
    # 检查系统架构
    ARCH=$(uname -m)
    if [ "$ARCH" != "x86_64" ] && [ "$ARCH" != "aarch64" ]; then
        log_warning "系统架构 $ARCH 可能不完全支持"
    fi
    
    # 检查内存
    local MEMORY_MB=0
    if command -v free &> /dev/null; then
        MEMORY_MB=$(free -m 2>/dev/null | awk 'NR==2{print $2}' 2>/dev/null || echo "0")
    elif [ -f /proc/meminfo ]; then
        MEMORY_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo 2>/dev/null || echo "0")
    fi
    
    if [ "$MEMORY_MB" -gt 0 ]; then
        log_info "系统内存: ${MEMORY_MB}MB"
        if [ "$MEMORY_MB" -lt 1024 ]; then
            log_warning "系统内存不足1GB，TLS处理可能影响性能"
        fi
    else
        log_warning "无法检测系统内存大小"
    fi
}

# 检查端口是否被占用
check_ports() {
    log_step "检查端口占用情况..."
    
    local ports=(80 443 "$NGINX_PORT" "$V2RAY_PORT")
    local port_check_cmd=""
    
    # 选择可用的端口检查工具
    if command -v netstat &> /dev/null; then
        port_check_cmd="netstat -tlnp 2>/dev/null"
    elif command -v ss &> /dev/null; then
        port_check_cmd="ss -tlnp 2>/dev/null"
    elif command -v lsof &> /dev/null; then
        port_check_cmd="lsof -i -n -P 2>/dev/null"
    else
        log_warning "无法找到端口检查工具（netstat/ss/lsof），跳过端口检查"
        log_info "建议手动检查端口占用情况"
        return 0
    fi
    
    for port in "${ports[@]}"; do
        local port_in_use=false
        
        # 使用选定的工具检查端口
        if echo "$port_check_cmd" | grep -q netstat; then
            if $port_check_cmd | grep -q ":${port} "; then
                port_in_use=true
            fi
        elif echo "$port_check_cmd" | grep -q "ss"; then
            if $port_check_cmd | grep -q ":${port} "; then
                port_in_use=true
            fi
        elif echo "$port_check_cmd" | grep -q lsof; then
            if $port_check_cmd | grep -q ":${port} "; then
                port_in_use=true
            fi
        fi
        
        if $port_in_use; then
            if [ "$port" = "80" ] && [ "$CERT_METHOD" = "letsencrypt" ]; then
                log_error "端口 80 被占用，Let's Encrypt 验证需要此端口"
                log_info "请停止占用端口80的服务后重试"
                $port_check_cmd | grep ":80 " || true
                exit 1
            elif [ "$port" = "$NGINX_PORT" ] || [ "$port" = "$V2RAY_PORT" ]; then
                log_error "端口 $port 已被占用"
                log_info "请更换端口或停止占用该端口的服务"
                $port_check_cmd | grep ":${port} " || true
                exit 1
            else
                log_warning "端口 $port 被占用，但不影响部署"
            fi
        else
            log_debug "端口 $port 可用"
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
    mkdir -p "$V2RAY_DIR"/{config,nginx,certs,logs,scripts,assets}
    
    # 复制assets文件到部署目录（在cd之前执行）
    if [ -d "$SCRIPT_DIR/assets" ]; then
        log_info "复制静态资源文件..."
        log_debug "源目录: $SCRIPT_DIR/assets"
        log_debug "目标目录: $V2RAY_DIR/assets"
        
        if [ "$(ls -A "$SCRIPT_DIR/assets" 2>/dev/null)" ]; then
            if cp -r "$SCRIPT_DIR/assets/." "$V2RAY_DIR/assets/" 2>/dev/null; then
                log_success "静态资源文件复制完成"
                log_debug "复制的文件数量: $(find "$V2RAY_DIR/assets" -type f | wc -l)"
            else
                log_error "复制静态资源文件失败"
                log_error "请检查权限和磁盘空间"
                exit 1
            fi
        else
            log_warning "assets目录为空: $SCRIPT_DIR/assets"
        fi
    else
        log_error "未找到assets目录: $SCRIPT_DIR/assets"
        log_error "请确保从完整的项目目录运行此脚本"
        exit 1
    fi
    
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
    
    # 使用模板生成配置
    process_template "$SCRIPT_DIR/configs/v2ray/config.json.template" "config/config.json"
    
    log_success "V2Ray配置生成完成"
    echo "UUID: $NEW_UUID"
}

# 生成Nginx配置
create_nginx_config() {
    log_step "生成Nginx配置..."
    
    # 使用模板生成配置
    process_template "$SCRIPT_DIR/configs/nginx/nginx.conf.template" "nginx/nginx.conf"
    
    log_success "Nginx配置生成完成"
}

# 生成Docker Compose配置
create_docker_compose() {
    log_step "生成Docker Compose配置..."
    
    # 使用模板生成配置
    process_template "$SCRIPT_DIR/configs/docker/docker-compose.yml.template" "docker-compose.yml"
    
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
    
    if [ "$DEBUG_MODE" = true ]; then
        log_debug "调试模式已启用"
        log_debug "域名: $DOMAIN"
        log_debug "邮箱: $EMAIL"
        log_debug "证书方法: $CERT_METHOD"
        log_debug "部署目录: $V2RAY_DIR"
        log_debug "Nginx端口: $NGINX_PORT"
        log_debug "V2Ray端口: $V2RAY_PORT"
        log_debug "WebSocket路径: $WS_PATH"
    fi
    
    parse_arguments "$@"
    validate_script_files
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