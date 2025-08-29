#!/bin/bash

# V2Ray Ubuntu 客户端离线安装脚本
# 使用预下载的安装包进行离线安装

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "此脚本需要root权限运行"
        log_info "请使用: sudo $0"
        exit 1
    fi
}

# 显示下载说明
show_download_instructions() {
    log_step "离线安装准备说明"
    echo
    echo -e "${YELLOW}由于无法访问GitHub，请先在能访问的机器上下载以下文件：${NC}"
    echo
    echo "1. V2Ray核心程序："
    echo "   https://github.com/v2fly/v2ray-core/releases/latest"
    echo "   - Linux 64位: v2ray-linux-64.zip"
    echo
    echo -e "${YELLOW}下载完成后，请将这些文件放在与此脚本相同的目录下。${NC}"
    echo
    read -p "文件已准备好？[y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "请准备好文件后重新运行脚本"
        exit 0
    fi
}

# 检查离线文件
check_offline_files() {
    log_step "检查离线安装文件..."
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # 检测系统架构
    ARCH=$(uname -m)
    if [[ "$ARCH" != "x86_64" ]]; then
        log_error "不支持的系统架构: $ARCH，此脚本仅支持 x86_64"
        exit 1
    fi
    
    PACKAGE_NAME="v2ray-linux-64.zip"
    log_info "检测到系统架构: $ARCH"
    log_info "使用安装包: $PACKAGE_NAME"
    
    # 检查V2Ray安装包
    if [[ ! -f "$SCRIPT_DIR/$PACKAGE_NAME" ]]; then
        log_error "未找到V2Ray安装包: $SCRIPT_DIR/$PACKAGE_NAME"
        log_info "请下载对应架构的V2Ray安装包"
        exit 1
    fi
    
    log_info "离线文件检查完成"
}

# 离线安装V2Ray
install_v2ray_offline() {
    log_step "离线安装V2Ray..."
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    TEMP_DIR="/tmp/v2ray_install"
    mkdir -p $TEMP_DIR
    cd $TEMP_DIR
    
    # 固定使用x86_64架构包
    PACKAGE_NAME="v2ray-linux-64.zip"
    
    # 复制安装包到临时目录
    cp "$SCRIPT_DIR/$PACKAGE_NAME" ./
    
    # 解压安装包
    log_info "解压V2Ray安装包..."
    if ! unzip -q "$PACKAGE_NAME"; then
        log_error "解压失败"
        exit 1
    fi
    
    # 创建必要的目录
    mkdir -p /usr/local/bin
    mkdir -p /usr/local/etc/v2ray
    mkdir -p /var/log/v2ray
    mkdir -p /usr/local/share/v2ray
    
    # 安装二进制文件
    log_info "安装V2Ray二进制文件..."
    cp v2ray /usr/local/bin/
    chmod +x /usr/local/bin/v2ray
    
    # 创建systemd服务文件
    cat > /etc/systemd/system/v2ray.service << 'EOF'
[Unit]
Description=V2Ray Service
Documentation=https://www.v2fly.org/
After=network.target nss-lookup.target

[Service]
User=nobody
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/v2ray run -config /usr/local/etc/v2ray/config.json
Restart=on-failure
RestartPreventExitStatus=23

[Install]
WantedBy=multi-user.target
EOF
    
    # 重新加载systemd
    systemctl daemon-reload
    
    # 清理临时文件
    cd /
    rm -rf $TEMP_DIR
    
    # 验证安装
    if ! command -v v2ray &> /dev/null; then
        log_error "V2Ray安装失败"
        exit 1
    fi
    
    log_info "V2Ray离线安装成功"
    log_info "版本信息: $(/usr/local/bin/v2ray version 2>/dev/null | head -n 1 || echo '版本获取失败')"
}

# 配置V2Ray客户端（简化版，不依赖geo文件）
configure_v2ray_client_simple() {
    log_step "配置V2Ray客户端..."
    
    # 创建配置目录
    mkdir -p /usr/local/etc/v2ray
    
    # 生成客户端配置文件（简化版路由规则）
    cat > /usr/local/etc/v2ray/config.json << 'EOF'
{
  "log": {
    "access": "/var/log/v2ray/v2ray-access.log",
    "error": "/var/log/v2ray/v2ray-error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 1080,
      "listen": "127.0.0.1",
      "protocol": "socks",
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      },
      "settings": {
        "auth": "noauth",
        "udp": false
      }
    },
    {
      "port": 8118,
      "listen": "127.0.0.1",
      "protocol": "http",
      "settings": {
        "allowTransparent": false
      }
    }
  ],
  "outbounds": [
    {
      "tag": "proxy",
      "protocol": "vmess",
      "settings": {
        "vnext": [
          {
            "address": "allenincosmos.online",
            "port": 10086,
            "users": [
              {
                "id": "5a8021ec-a973-487b-a5d0-299440c1bc2e",
                "alterId": 0,
                "email": "user@allenincosmos.online",
                "security": "auto"
              }
            ]
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "tls",
        "tlsSettings": {
          "allowInsecure": false,
          "serverName": "allenincosmos.online"
        },
        "wsSettings": {
          "path": "/ray",
          "headers": {
            "Host": "allenincosmos.online"
          }
        }
      }
    },
    {
      "tag": "direct",
      "protocol": "freedom",
      "settings": {}
    },
    {
      "tag": "block",
      "protocol": "blackhole",
      "settings": {
        "response": {
          "type": "http"
        }
      }
    }
  ],
  "routing": {
    "domainStrategy": "IPOnDemand",
    "rules": [
      {
        "type": "field",
        "ip": ["127.0.0.1/32", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"],
        "outboundTag": "direct"
      },
      {
        "type": "field",
        "domain": [
          "localhost",
          "local"
        ],
        "outboundTag": "direct"
      },
      {
        "type": "field",
        "network": "udp,tcp",
        "outboundTag": "proxy"
      }
    ]
  }
}
EOF

    # 创建日志目录
    mkdir -p /var/log/v2ray
    chown nobody:nogroup /var/log/v2ray
    
    log_info "V2Ray客户端配置完成（简化路由规则）"
}

# 安装基本工具
install_basic_tools() {
    log_step "安装基本工具..."
    apt update -y
    apt install -y curl wget unzip
}

# 配置代理工具
setup_proxy_tools_simple() {
    log_step "配置代理工具..."
    
    # 创建代理脚本
    cat > /usr/local/bin/proxy-on << 'EOF'
#!/bin/bash
export http_proxy=http://127.0.0.1:8118
export https_proxy=http://127.0.0.1:8118
export HTTP_PROXY=http://127.0.0.1:8118
export HTTPS_PROXY=http://127.0.0.1:8118
export no_proxy=localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
export NO_PROXY=localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16

# Git代理配置
git config --global http.proxy http://127.0.0.1:8118
git config --global https.proxy http://127.0.0.1:8118

echo "代理已开启"
echo "HTTP代理: http://127.0.0.1:8118"
echo "SOCKS5代理: socks5://127.0.0.1:1080"
EOF

    cat > /usr/local/bin/proxy-off << 'EOF'
#!/bin/bash
unset http_proxy
unset https_proxy
unset HTTP_PROXY
unset HTTPS_PROXY
unset no_proxy
unset NO_PROXY

# 取消Git代理配置
git config --global --unset http.proxy 2>/dev/null || true
git config --global --unset https.proxy 2>/dev/null || true

echo "代理已关闭"
EOF

    chmod +x /usr/local/bin/proxy-on
    chmod +x /usr/local/bin/proxy-off
    
    # 添加到bashrc
    cat >> /root/.bashrc << 'EOF'

# V2Ray代理别名
alias pon='source /usr/local/bin/proxy-on'
alias poff='source /usr/local/bin/proxy-off'
EOF

    log_info "代理工具配置完成"
}

# 启动服务
start_services() {
    log_step "启动V2Ray服务..."
    
    # 启用并启动V2Ray服务
    systemctl enable v2ray
    systemctl start v2ray
    
    # 检查服务状态
    sleep 3
    if systemctl is-active --quiet v2ray; then
        log_info "V2Ray服务启动成功"
    else
        log_error "V2Ray服务启动失败"
        systemctl status v2ray
        exit 1
    fi
}

# 测试连接
test_connection() {
    log_step "测试连接..."
    
    # 等待服务完全启动
    sleep 5
    
    # 测试SOCKS5代理
    if timeout 10 curl -x socks5://127.0.0.1:1080 -s https://www.google.com > /dev/null 2>&1; then
        log_info "SOCKS5代理连接成功"
    else
        log_warn "SOCKS5代理连接测试失败（这可能是正常的，取决于网络环境）"
    fi
    
    # 测试HTTP代理
    if timeout 10 curl -x http://127.0.0.1:8118 -s https://www.google.com > /dev/null 2>&1; then
        log_info "HTTP代理连接成功"
    else
        log_warn "HTTP代理连接测试失败（这可能是正常的，取决于网络环境）"
    fi
}

# 显示使用说明
show_usage() {
    log_info "=== V2Ray客户端离线安装完成 ==="
    echo
    echo -e "${GREEN}代理信息:${NC}"
    echo "  SOCKS5代理: 127.0.0.1:1080"
    echo "  HTTP代理:   127.0.0.1:8118"
    echo
    echo -e "${GREEN}使用方法:${NC}"
    echo "  1. 开启代理: ${YELLOW}pon${NC}"
    echo "  2. 关闭代理: ${YELLOW}poff${NC}"
    echo
    echo -e "${GREEN}GitHub使用:${NC}"
    echo "  ${YELLOW}pon${NC}"
    echo "  ${YELLOW}git clone https://github.com/user/repo.git${NC}"
    echo
    echo -e "${GREEN}手动测试:${NC}"
    echo "  ${YELLOW}curl -x socks5://127.0.0.1:1080 https://api.github.com${NC}"
    echo "  ${YELLOW}curl -x http://127.0.0.1:8118 https://www.google.com${NC}"
    echo
}

# 主函数
main() {
    clear
    echo -e "${BLUE}"
    echo "================================================"
    echo "         V2Ray Ubuntu 客户端离线安装脚本"
    echo "         连接到: allenincosmos.online"
    echo "================================================"
    echo -e "${NC}"
    
    check_root
    show_download_instructions
    check_offline_files
    install_basic_tools
    install_v2ray_offline
    configure_v2ray_client_simple
    setup_proxy_tools_simple
    start_services
    test_connection
    show_usage
    
    log_info "离线安装完成！请重新登录或运行 'source ~/.bashrc' 以使用代理别名"
}

# 运行主函数
main "$@"
