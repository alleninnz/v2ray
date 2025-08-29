#!/bin/bash

# V2Ray 离线安装文件下载脚本
# 在能访问GitHub的机器上运行此脚本下载所需文件

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 获取最新版本号
get_latest_version() {
    log_step "获取V2Ray最新版本..."
    
    # 尝试从GitHub API获取最新版本
    if command -v curl >/dev/null 2>&1; then
        LATEST_VERSION=$(curl -s https://api.github.com/repos/v2fly/v2ray-core/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    elif command -v wget >/dev/null 2>&1; then
        LATEST_VERSION=$(wget -qO- https://api.github.com/repos/v2fly/v2ray-core/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    else
        log_error "需要curl或wget工具"
        exit 1
    fi
    
    if [[ -z "$LATEST_VERSION" ]]; then
        log_error "无法获取最新版本，使用默认版本"
        LATEST_VERSION="v5.16.1"
    fi
    
    log_info "最新版本: $LATEST_VERSION"
}

# 下载文件函数
download_file() {
    local url=$1
    local filename=$2
    local desc=$3
    
    log_info "下载 $desc: $filename"
    
    if command -v curl >/dev/null 2>&1; then
        if curl -L -o "$filename" "$url"; then
            log_info "✓ $desc 下载成功"
            return 0
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -O "$filename" "$url"; then
            log_info "✓ $desc 下载成功"
            return 0
        fi
    fi
    
    log_error "✗ $desc 下载失败"
    return 1
}

# 主下载函数
download_v2ray_files() {
    log_step "开始下载V2Ray离线安装文件..."
    
    # 创建下载目录
    DOWNLOAD_DIR="v2ray-offline-$(date +%Y%m%d)"
    mkdir -p "$DOWNLOAD_DIR"
    cd "$DOWNLOAD_DIR"
    
    get_latest_version
    
    # 下载不同架构的V2Ray包
    log_step "下载V2Ray核心程序..."
    
    # 定义要下载的包列表
    PACKAGES=(
        "v2ray-linux-64.zip:Linux x86_64"
    )
    
    for package_info in "${PACKAGES[@]}"; do
        package=$(echo "$package_info" | cut -d':' -f1)
        desc=$(echo "$package_info" | cut -d':' -f2)
        url="https://github.com/v2fly/v2ray-core/releases/download/${LATEST_VERSION}/${package}"
        download_file "$url" "$package" "$desc"
    done
    
    # 复制安装脚本
    if [[ -f "../deploy-v2ray-ubuntu-client-offline.sh" ]]; then
        cp "../deploy-v2ray-ubuntu-client-offline.sh" ./
        log_info "✓ 离线安装脚本已复制"
    fi
    
    # 生成使用说明
    cat > README.txt << 'EOF'
V2Ray 离线安装包使用说明
=======================

1. 文件说明：
   - v2ray-linux-64.zip         # Linux x86_64 架构
   - deploy-v2ray-ubuntu-client-offline.sh  # 离线安装脚本

2. 使用方法：
   - 将整个文件夹传输到目标Ubuntu服务器
   - 在目标服务器上运行：sudo bash deploy-v2ray-ubuntu-client-offline.sh

3. 注意事项：
   - 脚本会自动检测系统架构并选择对应的安装包
   - 确保所有文件都在同一目录下
   - 需要root权限运行安装脚本

4. 服务器配置：
   - 服务器地址：allenincosmos.online:10086
   - 协议：VMess over WebSocket with TLS
   - 路径：/ray

5. 安装完成后：
   - 使用 pon 开启代理
   - 使用 poff 关闭代理
   - SOCKS5代理：127.0.0.1:1080
   - HTTP代理：127.0.0.1:8118
EOF
    
    log_info "✓ 使用说明已生成：README.txt"
    
    cd ..
    
    # 显示下载结果
    echo
    log_info "=== 下载完成 ==="
    echo -e "${GREEN}下载目录：${NC} $DOWNLOAD_DIR"
    echo -e "${GREEN}文件列表：${NC}"
    ls -la "$DOWNLOAD_DIR/"
    echo
    echo -e "${YELLOW}接下来的步骤：${NC}"
    echo "1. 将整个 '$DOWNLOAD_DIR' 文件夹传输到目标Ubuntu服务器"
    echo "2. 在Ubuntu服务器上运行：sudo bash $DOWNLOAD_DIR/deploy-v2ray-ubuntu-client-offline.sh"
    echo
    echo -e "${YELLOW}传输命令示例：${NC}"
    echo "scp -r $DOWNLOAD_DIR user@your-server:/tmp/"
    echo "ssh user@your-server"
    echo "sudo bash /tmp/$DOWNLOAD_DIR/deploy-v2ray-ubuntu-client-offline.sh"
    echo
}

# 检查依赖
check_dependencies() {
    if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
        log_error "需要安装 curl 或 wget"
        echo "Ubuntu/Debian: sudo apt install curl"
        echo "CentOS/RHEL:   sudo yum install curl"
        echo "macOS:         brew install curl"
        exit 1
    fi
}

# 主函数
main() {
    clear
    echo -e "${BLUE}"
    echo "================================================"
    echo "         V2Ray 离线安装文件下载脚本"
    echo "         请在能访问GitHub的机器上运行"
    echo "================================================"
    echo -e "${NC}"
    
    check_dependencies
    download_v2ray_files
    
    log_info "所有文件下载完成！"
}

# 运行主函数
main "$@"
