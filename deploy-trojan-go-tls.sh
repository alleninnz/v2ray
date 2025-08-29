#!/bin/bash

# Trojan-Go 一键部署脚本 (纯IP部署)
# 适用于内网或受限网络环境
# 基于 Docker 镜像: teddysun/trojan-go

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# 默认配置变量
DEFAULT_TROJAN_DIR="/opt/trojan-go"
DEFAULT_TROJAN_PORT="443"
DEFAULT_CERT_DAYS="365"
DEFAULT_SERVICE_WAIT="10"
DEFAULT_MAX_RETRIES="3"

# 运行时配置 (可通过配置文件覆盖)
TROJAN_DIR="${TROJAN_DIR:-$DEFAULT_TROJAN_DIR}"
TROJAN_PORT="${TROJAN_PORT:-$DEFAULT_TROJAN_PORT}"
FALLBACK_PORT="${FALLBACK_PORT:-8081}"  # 默认使用8081端口避免冲突
CERT_VALIDITY_DAYS="${CERT_VALIDITY_DAYS:-$DEFAULT_CERT_DAYS}"
SERVICE_WAIT_TIME="${SERVICE_WAIT_TIME:-$DEFAULT_SERVICE_WAIT}"
MAX_RETRIES="${MAX_RETRIES:-$DEFAULT_MAX_RETRIES}"
SERVER_IP=""
DEBUG_MODE=false
CONFIG_FILE=""

# Docker脚本配置
DOCKER_SCRIPT_URL="https://get.docker.com"
DOCKER_SCRIPT_NAME="get-docker.sh"

# 脚本目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 清理函数
cleanup_on_error() {
    log_error "部署失败，正在清理..."
    
    # 停止并删除Docker容器
    if [ -d "$TROJAN_DIR" ]; then
        cd "$TROJAN_DIR" 2>/dev/null || true
        docker-compose down --remove-orphans 2>/dev/null || true
        docker-compose rm -f 2>/dev/null || true
    fi
    
    # 清理安装目录
    if [ -d "$TROJAN_DIR" ] && [ "$TROJAN_DIR" != "/" ]; then
        log_info "删除安装目录: $TROJAN_DIR"
        rm -rf "$TROJAN_DIR" 2>/dev/null || true
    fi
    
    # 清理临时文件
    rm -f "$DOCKER_SCRIPT_NAME" 2>/dev/null || true
    rm -f connection-info.txt 2>/dev/null || true
    
    log_info "清理完成"
    exit 1
}

# 设置错误处理
trap cleanup_on_error ERR

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
    echo -e "${CYAN}[STEP]${NC} $1"
}

# 检查root权限
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用root权限运行此脚本"
        exit 1
    fi
}

# 获取服务器IP
detect_server_ip() {
    log_step "检测服务器IP地址..."
    
    # 尝试多种方法获取公网IP
    SERVER_IP=$(curl -s ipv4.icanhazip.com 2>/dev/null || \
                curl -s ifconfig.me 2>/dev/null || \
                curl -s ip.sb 2>/dev/null || \
                curl -s ipinfo.io/ip 2>/dev/null || \
                curl -s api.ipify.org 2>/dev/null || \
                ip route get 8.8.8.8 | awk '{print $7}' | head -n1 2>/dev/null || \
                hostname -I | awk '{print $1}' 2>/dev/null)
    
    if [ -z "$SERVER_IP" ]; then
        log_error "无法自动检测服务器IP地址"
        read -r -p "请手动输入服务器IP地址: " SERVER_IP
    fi
    
    # 验证IP格式
    if [[ ! $SERVER_IP =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        log_error "IP地址格式无效: $SERVER_IP"
        exit 1
    fi
    
    log_success "服务器IP: $SERVER_IP"
}

# 输入验证函数
validate_port() {
    local port=$1
    if [[ ! $port =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        log_error "端口无效: $port (必须是1-65535范围内的数字)"
        exit 1
    fi
}

# 检查系统要求
check_system_requirements() {
    log_step "检查系统要求..."
    
    # 检查操作系统
    if ! command -v curl &> /dev/null; then
        log_error "curl 未安装，请先安装curl"
        exit 1
    fi
    
    # 验证端口
    validate_port "$TROJAN_PORT"
    
    log_success "系统要求检查通过"
}

# 生成随机密码
generate_password() {
    local length=${1:-32}
    if command -v openssl &> /dev/null; then
        openssl rand -base64 "$length" | tr -d "=+/" | cut -c1-"$length"
    elif [ -f /dev/urandom ]; then
        tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
    else
        date +%s | sha256sum | base64 | head -c "$length"
    fi
}

# 检测包管理器
detect_package_manager() {
    if command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    else
        echo "unknown"
    fi
}

# 安装系统依赖包
install_packages() {
    local pkg_manager="$1"
    local packages=("curl" "wget" "openssl")
    
    case $pkg_manager in
        "apt")
            apt-get update -qq
            apt-get install -y "${packages[@]}"
            ;;
        "yum")
            yum update -y -q
            yum install -y "${packages[@]}"
            ;;
        "dnf")
            dnf update -y -q
            dnf install -y "${packages[@]}"
            ;;
        *)
            log_error "不支持的包管理器: $pkg_manager"
            exit 1
            ;;
    esac
}

# 安装系统依赖
install_system_dependencies() {
    log_step "安装系统依赖..."
    
    local pkg_manager
    pkg_manager=$(detect_package_manager)
    
    if [ "$pkg_manager" = "unknown" ]; then
        log_error "未检测到支持的包管理器 (apt/yum/dnf)"
        exit 1
    fi
    
    log_info "检测到包管理器: $pkg_manager"
    install_packages "$pkg_manager"
    
    # 安装Docker
    if ! command -v docker &> /dev/null; then
        log_info "安装Docker..."
        
        # 下载Docker安装脚本
        if ! curl -fsSL "$DOCKER_SCRIPT_URL" -o "$DOCKER_SCRIPT_NAME"; then
            log_error "下载Docker安装脚本失败"
            exit 1
        fi
        
        # 验证脚本内容（基本检查）
        if ! grep -q "docker" "$DOCKER_SCRIPT_NAME" || [ ! -s "$DOCKER_SCRIPT_NAME" ]; then
            log_error "Docker安装脚本验证失败"
            rm -f "$DOCKER_SCRIPT_NAME"
            exit 1
        fi
        
        # 执行安装脚本
        log_info "执行Docker安装脚本..."
        if ! sh "$DOCKER_SCRIPT_NAME"; then
            log_error "Docker安装失败"
            rm -f "$DOCKER_SCRIPT_NAME"
            exit 1
        fi
        
        # 清理安装脚本
        rm -f "$DOCKER_SCRIPT_NAME"
        
        systemctl enable docker
        systemctl start docker
        
        log_success "Docker安装完成"
    fi
    
    # 安装Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        log_info "安装Docker Compose..."
        curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
    fi
    
    log_success "系统依赖安装完成"
}

# 创建目录结构
create_directories() {
    log_step "创建目录结构..."
    
    mkdir -p "$TROJAN_DIR"/{config,certs,logs}
    mkdir -p "$TROJAN_DIR/certs/live/$SERVER_IP"
    
    log_success "目录结构创建完成"
}

# 生成自签名证书
generate_self_signed_cert() {
    log_step "生成自签名证书..."
    
    cd "$TROJAN_DIR"
    
    # 生成私钥
    openssl genrsa -out "certs/live/$SERVER_IP/privkey.pem" 2048
    
    # 生成证书（使用IP地址）
    openssl req -new -x509 -key "certs/live/$SERVER_IP/privkey.pem" \
        -out "certs/live/$SERVER_IP/fullchain.pem" -days "$CERT_VALIDITY_DAYS" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=$SERVER_IP" \
        -extensions SAN \
        -config <(echo '[req]'; echo 'distinguished_name=req'; echo '[SAN]'; echo "subjectAltName=IP:$SERVER_IP")
    
    # 设置权限
    chmod 600 "certs/live/$SERVER_IP/privkey.pem"
    chmod 644 "certs/live/$SERVER_IP/fullchain.pem"
    chmod 755 "certs/live/$SERVER_IP"
    
    log_success "自签名证书生成完成"
}

# 生成Trojan配置
generate_trojan_config() {
    log_step "生成Trojan配置..."
    
    cd "$TROJAN_DIR"
    
    # 生成密码
    TROJAN_PASSWORD=$(generate_password 32)
    
    # 创建配置文件
    cat > config/config.json << EOF
{
    "run_type": "server",
    "local_addr": "0.0.0.0",
    "local_port": $TROJAN_PORT,
    "remote_addr": "127.0.0.1",
    "remote_port": $FALLBACK_PORT,
    "password": ["$TROJAN_PASSWORD"],
    "ssl": {
        "cert": "/etc/trojan-go/certs/live/$SERVER_IP/fullchain.pem",
        "key": "/etc/trojan-go/certs/live/$SERVER_IP/privkey.pem",
        "sni": "$SERVER_IP",
        "fallback_addr": "127.0.0.1",
        "fallback_port": $FALLBACK_PORT
    }
}
EOF
    
    log_success "Trojan配置生成完成"
    log_info "Trojan密码: $TROJAN_PASSWORD"
}

# 生成Docker Compose配置
generate_docker_compose_config() {
    log_step "生成Docker Compose配置..."
    
    cd "$TROJAN_DIR"
    
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  trojan-go:
    image: teddysun/trojan-go:latest
    container_name: trojan-go
    restart: always
    ports:
      - "$TROJAN_PORT:$TROJAN_PORT"
    volumes:
      - ./config/config.json:/etc/trojan-go/config.json:ro
      - ./certs:/etc/trojan-go/certs:ro
      - ./logs:/var/log/trojan-go
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
    read_only: true
    tmpfs:
      - /tmp
    security_opt:
      - no-new-privileges:true
    networks:
      - trojan-net

  # Fallback web server
  nginx:
    image: nginx:alpine
    container_name: trojan-fallback
    restart: always
    ports:
      - "$FALLBACK_PORT:80"
    volumes:
      - ./web:/usr/share/nginx/html:ro
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE
      - CHOWN
      - SETGID
      - SETUID
    read_only: true
    tmpfs:
      - /tmp
      - /var/cache/nginx
      - /var/run
    security_opt:
      - no-new-privileges:true
    networks:
      - trojan-net

networks:
  trojan-net:
    driver: bridge
EOF
    
    # 创建简单的fallback网页
    mkdir -p web
    cat > web/index.html << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Welcome</title>
</head>
<body>
    <h1>Welcome to Nginx</h1>
    <p>This is a fallback page.</p>
</body>
</html>
EOF
    
    log_success "Docker Compose配置生成完成"
}

# 部署服务
deploy_trojan_service() {
    log_step "部署Trojan服务..."
    
    cd "$TROJAN_DIR"
    
    # 拉取镜像
    docker-compose pull
    
    # 启动服务
    docker-compose up -d
    
    # 等待服务启动
    log_info "等待服务启动... (${SERVICE_WAIT_TIME}秒)"
    sleep "$SERVICE_WAIT_TIME"
    
    # 检查服务状态 (增加重试机制)
    local retry_count=0
    local max_retries="$MAX_RETRIES"
    
    while [ $retry_count -lt "$max_retries" ]; do
        if docker-compose ps | grep -q "Up"; then
            log_success "服务状态检查通过"
            break
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt "$max_retries" ]; then
            log_warning "服务尚未启动，等待重试... ($retry_count/$max_retries)"
            sleep 5
        else
            log_error "服务启动失败，已达到最大重试次数"
            docker-compose logs --tail=50
            exit 1
        fi
    done
    
    log_success "Trojan服务部署完成"
}

# 保存连接信息
save_connection_info() {
    log_step "保存连接信息..."
    
    cat > connection-info.txt << EOF
========================================
Trojan 部署信息 (纯IP部署)
========================================

部署时间: $(date)
服务器IP: $SERVER_IP
端口: $TROJAN_PORT
Trojan密码: $TROJAN_PASSWORD
TLS: 开启 (自签名证书)
证书类型: 自签名 (使用IP地址)

========================================
客户端配置 (Trojan)
========================================

服务器地址: $SERVER_IP
端口: $TROJAN_PORT
密码: $TROJAN_PASSWORD
传输层安全: 启用TLS
SNI: $SERVER_IP (或留空)
ALPN: http/1.1
允许不安全连接: 是 (必须启用)
跳过证书验证: 是 (必须启用)

========================================
管理命令
========================================

查看服务状态:
cd $TROJAN_DIR && docker-compose ps

查看日志:
cd $TROJAN_DIR && docker-compose logs -f

重启服务:
cd $TROJAN_DIR && docker-compose restart

停止服务:
cd $TROJAN_DIR && docker-compose down

更新服务:
cd $TROJAN_DIR && docker-compose pull && docker-compose up -d

========================================
注意事项
========================================

1. 使用自签名证书，客户端必须允许不安全连接
2. 服务配置文件位于: $TROJAN_DIR
3. 日志文件位于: $TROJAN_DIR/logs
4. 仅支持纯 Trojan 协议，无额外功能
5. 证书绑定到服务器IP: $SERVER_IP

========================================
客户端推荐
========================================

PC端:
- v2rayN (Windows) - 支持Trojan协议
- V2rayU (macOS) - 支持Trojan协议
- Clash (跨平台) - 支持Trojan协议

移动端:
- Shadowrocket (iOS) - 支持Trojan协议
- Clash for Android (Android)
- Matsuri (Android)

路由器:
- OpenWrt + Passwall
- OpenWrt + SSR Plus

EOF
    
    log_success "连接信息已保存到: $PWD/connection-info.txt"
}

# 显示部署结果
show_deployment_result() {
    echo
    echo -e "${GREEN}${BOLD}========================================${NC}"
    echo -e "${GREEN}${BOLD}      🎉 Trojan 部署成功！ 🎉        ${NC}"
    echo -e "${GREEN}${BOLD}========================================${NC}"
    echo
    echo -e "${BLUE}📋 连接信息:${NC}"
    echo -e "   服务器IP: ${BOLD}$SERVER_IP${NC}"
    echo -e "   端口: ${BOLD}$TROJAN_PORT${NC}"
    echo -e "   Trojan密码: ${BOLD}$TROJAN_PASSWORD${NC}"
    echo -e "   协议: ${BOLD}Trojan (TLS)${NC}"
    echo -e "   证书: ${YELLOW}自签名（IP证书）${NC}"
    echo
    echo -e "${CYAN}🔗 协议特性:${NC}"
    echo -e "   • ${BOLD}纯Trojan协议${NC} - 简单高效"
    echo -e "   • ${BOLD}TLS加密${NC} - 安全传输"
    echo -e "   • ${BOLD}IP直连${NC} - 无需域名"
    echo
    echo -e "${YELLOW}⚠️  重要提醒:${NC}"
    echo -e "   • 客户端必须${BOLD}允许不安全连接${NC}（自签名证书）"
    echo -e "   • 客户端必须${BOLD}跳过证书验证${NC}"
    echo -e "   • 确保防火墙开放端口 ${BOLD}$TROJAN_PORT${NC}"
    echo -e "   • 配置信息已保存到 ${BOLD}$PWD/connection-info.txt${NC}"
    echo
    echo -e "${PURPLE}🔧 管理命令:${NC}"
    echo -e "   查看状态: ${BOLD}cd $TROJAN_DIR && docker-compose ps${NC}"
    echo -e "   查看日志: ${BOLD}cd $TROJAN_DIR && docker-compose logs -f${NC}"
    echo -e "   重启服务: ${BOLD}cd $TROJAN_DIR && docker-compose restart${NC}"
    echo
    echo -e "${GREEN}✅ 部署完成！请使用上述信息配置客户端。${NC}"
    echo
}

# 加载配置文件
load_config_file() {
    local config_file="$1"
    
    if [ -f "$config_file" ]; then
        log_info "加载配置文件: $config_file"
        # shellcheck source=/dev/null
        source "$config_file"
    else
        log_error "配置文件不存在: $config_file"
        exit 1
    fi
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo
    echo "选项:"
    echo "  -p PORT          指定Trojan端口 (默认: $DEFAULT_TROJAN_PORT)"
    echo "  -d DIRECTORY     指定安装目录 (默认: $DEFAULT_TROJAN_DIR)"
    echo "  -c CONFIG        指定配置文件路径"
    echo "  -f PORT          指定fallback端口 (默认: 8081)"
    echo "  --cert-days N    证书有效期 (默认: $DEFAULT_CERT_DAYS 天)"
    echo "  --debug          启用调试模式"
    echo "  -h, --help       显示此帮助信息"
    echo
    echo "环境变量:"
    echo "  TROJAN_DIR       安装目录"
    echo "  TROJAN_PORT      服务端口"
    echo "  FALLBACK_PORT    fallback网页端口"
    echo "  CERT_VALIDITY_DAYS  证书有效期"
    echo "  SERVICE_WAIT_TIME   服务等待时间"
    echo "  MAX_RETRIES      最大重试次数"
    echo
    echo "示例:"
    echo "  $0                         # 使用默认配置部署"
    echo "  $0 -p 8443                # 使用端口8443部署"
    echo "  $0 -f 8082                # 使用fallback端口8082"
    echo "  $0 -c /path/to/config.env # 使用配置文件"
    echo "  $0 --debug                # 启用调试模式部署"
    echo "  FALLBACK_PORT=8082 $0     # 使用环境变量设置fallback端口"
}

# 解析命令行参数
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--port)
                if [ -z "${2:-}" ]; then
                    log_error "--port 选项需要一个参数"
                    show_help
                    exit 1
                fi
                TROJAN_PORT="$2"
                validate_port "$TROJAN_PORT"
                shift 2
                ;;
            -d|--dir)
                if [ -z "${2:-}" ]; then
                    log_error "--dir 选项需要一个参数"
                    show_help
                    exit 1
                fi
                TROJAN_DIR="$2"
                shift 2
                ;;
            -c|--config)
                if [ -z "${2:-}" ]; then
                    log_error "--config 选项需要一个参数"
                    show_help
                    exit 1
                fi
                CONFIG_FILE="$2"
                shift 2
                ;;
            -f|--fallback-port)
                if [ -z "${2:-}" ]; then
                    log_error "--fallback-port 选项需要一个参数"
                    show_help
                    exit 1
                fi
                FALLBACK_PORT="$2"
                validate_port "$FALLBACK_PORT"
                shift 2
                ;;
            --cert-days)
                if [ -z "${2:-}" ]; then
                    log_error "--cert-days 选项需要一个参数"
                    show_help
                    exit 1
                fi
                CERT_VALIDITY_DAYS="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            --debug)
                DEBUG_MODE=true
                set -x
                shift
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 主函数
main() {
    echo -e "${BOLD}Trojan 一键部署脚本 (纯IP部署)${NC}"
    echo -e "基于 Docker 镜像: ${CYAN}teddysun/trojan-go${NC}"
    echo -e "适用于内网或受限网络环境"
    echo
    
    # 解析参数
    parse_arguments "$@"
    
    # 加载配置文件（如果指定）
    if [ -n "$CONFIG_FILE" ]; then
        load_config_file "$CONFIG_FILE"
    fi
    
    # 系统检查
    check_root
    detect_server_ip
    check_system_requirements
    
    # 安装系统依赖
    install_system_dependencies
    
    # 创建目录
    create_directories
    
    # 生成IP证书
    generate_self_signed_cert
    
    # 生成配置文件
    generate_trojan_config
    generate_docker_compose_config
    
    # 部署服务
    deploy_trojan_service
    
    # 创建连接信息文件
    save_connection_info
    
    # 显示结果
    show_deployment_result
    
    echo -e "${GREEN}🎯 脚本执行完成！${NC}"
}

# 开始执行
main "$@"
