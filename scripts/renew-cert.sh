#!/bin/bash
#
# Certificate Renewal Script for V2Ray TLS Deployment
# This script renews Let's Encrypt certificates and restarts services
#

set -euo pipefail

# Configuration
DOMAIN=""
CERT_PATH=""
V2RAY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="$V2RAY_DIR/logs/cert-renewal.log"

# Logging function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Show help
show_help() {
    cat << EOF
证书续期脚本 - V2Ray TLS部署

用法: $0 [选项]

选项:
    -d, --domain DOMAIN     域名
    -p, --path PATH         证书路径 (默认: /etc/letsencrypt/live/DOMAIN)
    -h, --help             显示此帮助信息

示例:
    $0 -d example.com
    $0 -d example.com -p /custom/cert/path
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--domain)
                DOMAIN="$2"
                shift 2
                ;;
            -p|--path)
                CERT_PATH="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo "错误：未知参数 $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    if [ -z "$DOMAIN" ]; then
        echo "错误：必须指定域名"
        show_help
        exit 1
    fi
    
    if [ -z "$CERT_PATH" ]; then
        CERT_PATH="/etc/letsencrypt/live/$DOMAIN"
    fi
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "错误：此脚本需要root权限运行"
        exit 1
    fi
}

# Check certificate expiration
check_cert_expiry() {
    local cert_file="$CERT_PATH/fullchain.pem"
    
    if [ ! -f "$cert_file" ]; then
        log_message "错误：证书文件不存在 $cert_file"
        exit 1
    fi
    
    local expiry_date=$(openssl x509 -in "$cert_file" -enddate -noout | cut -d= -f2)
    local expiry_timestamp=$(date -d "$expiry_date" +%s)
    local current_timestamp=$(date +%s)
    local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
    
    log_message "证书到期时间：$expiry_date ($days_until_expiry 天)"
    
    if [ "$days_until_expiry" -le 7 ]; then
        log_message "警告：证书将在 $days_until_expiry 天内过期，开始续期..."
        return 0
    else
        log_message "证书还有 $days_until_expiry 天才过期，无需续期"
        return 1
    fi
}

# Renew certificate
renew_certificate() {
    log_message "开始续期Let's Encrypt证书..."
    
    # Stop nginx temporarily to allow certbot to bind to port 80
    if docker-compose -f "$V2RAY_DIR/docker-compose.yml" ps nginx | grep -q "Up"; then
        log_message "暂停Nginx容器..."
        docker-compose -f "$V2RAY_DIR/docker-compose.yml" stop nginx
        NGINX_STOPPED=true
    fi
    
    # Renew certificate
    if certbot renew --quiet --no-self-upgrade; then
        log_message "证书续期成功"
    else
        log_message "证书续期失败"
        if [ "${NGINX_STOPPED:-false}" = true ]; then
            log_message "重启Nginx容器..."
            docker-compose -f "$V2RAY_DIR/docker-compose.yml" start nginx
        fi
        exit 1
    fi
    
    # Restart nginx
    if [ "${NGINX_STOPPED:-false}" = true ]; then
        log_message "重启Nginx容器..."
        docker-compose -f "$V2RAY_DIR/docker-compose.yml" start nginx
    fi
    
    log_message "证书续期完成"
}

# Test nginx configuration
test_nginx_config() {
    log_message "测试Nginx配置..."
    if docker-compose -f "$V2RAY_DIR/docker-compose.yml" exec -T nginx nginx -t; then
        log_message "Nginx配置测试通过"
    else
        log_message "错误：Nginx配置测试失败"
        exit 1
    fi
}

# Main function
main() {
    parse_args "$@"
    check_root
    
    log_message "开始证书续期检查 - 域名: $DOMAIN"
    
    if check_cert_expiry; then
        renew_certificate
        test_nginx_config
    fi
    
    log_message "证书续期检查完成"
}

# Run main function
main "$@"