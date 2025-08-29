#!/bin/bash

# V2Ray Ubuntu 客户端一键部署脚本
# 用于连接到 allenincosmos.online v2ray 服务器

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

# 检查系统
check_system() {
    log_step "检查系统环境..."
    
    if [[ ! -f /etc/os-release ]]; then
        log_error "无法检测操作系统"
        exit 1
    fi
    
    source /etc/os-release
    
    if [[ $ID != "ubuntu" ]]; then
        log_error "此脚本仅支持Ubuntu系统"
        exit 1
    fi
    
    log_info "检测到系统: $PRETTY_NAME"
}

# 更新系统
update_system() {
    log_step "更新系统包..."
    apt update -y
    apt upgrade -y
    apt install -y curl wget unzip software-properties-common
}

# 安装V2Ray
install_v2ray() {
    log_step "安装V2Ray..."
    
    # 使用官方安装脚本
    bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)
    
    if ! command -v v2ray &> /dev/null; then
        log_error "V2Ray安装失败"
        exit 1
    fi
    
    log_info "V2Ray安装成功"
}

# 配置V2Ray客户端
configure_v2ray_client() {
    log_step "配置V2Ray客户端..."
    
    # 创建配置目录
    mkdir -p /usr/local/etc/v2ray
    
    # 生成客户端配置文件
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
        "ip": ["geoip:private"],
        "outboundTag": "direct"
      },
      {
        "type": "field",
        "ip": ["geoip:cn"],
        "outboundTag": "direct"
      },
      {
        "type": "field",
        "domain": ["geosite:cn"],
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
    
    log_info "V2Ray客户端配置完成"
}

# 启动V2Ray服务
start_v2ray_service() {
    log_step "启动V2Ray服务..."
    
    # 启用并启动V2Ray服务
    systemctl enable v2ray
    systemctl start v2ray
    
    # 检查服务状态
    if systemctl is-active --quiet v2ray; then
        log_info "V2Ray服务启动成功"
    else
        log_error "V2Ray服务启动失败"
        systemctl status v2ray
        exit 1
    fi
}

# 安装和配置代理工具
setup_proxy_tools() {
    log_step "安装代理工具..."
    
    # 安装privoxy (HTTP代理)
    apt install -y privoxy
    
    # 配置privoxy
    cp /etc/privoxy/config /etc/privoxy/config.backup
    
    cat >> /etc/privoxy/config << 'EOF'

# V2Ray SOCKS5 代理配置
forward-socks5t / 127.0.0.1:1080 .
listen-address 0.0.0.0:8118
EOF
    
    # 启动privoxy
    systemctl enable privoxy
    systemctl restart privoxy
    
    log_info "代理工具配置完成"
}

# 配置GitHub代理
setup_github_proxy() {
    log_step "配置GitHub代理..."
    
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
git config --global --unset http.proxy
git config --global --unset https.proxy

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

    log_info "GitHub代理配置完成"
}

# 测试连接
test_connection() {
    log_step "测试连接..."
    
    # 等待服务启动
    sleep 5
    
    # 测试SOCKS5代理
    if curl -x socks5://127.0.0.1:1080 --connect-timeout 10 -s https://www.google.com > /dev/null; then
        log_info "SOCKS5代理连接成功"
    else
        log_warn "SOCKS5代理连接测试失败"
    fi
    
    # 测试HTTP代理
    if curl -x http://127.0.0.1:8118 --connect-timeout 10 -s https://www.google.com > /dev/null; then
        log_info "HTTP代理连接成功"
    else
        log_warn "HTTP代理连接测试失败"
    fi
    
    # 测试GitHub连接
    source /usr/local/bin/proxy-on
    if curl --connect-timeout 10 -s https://api.github.com > /dev/null; then
        log_info "GitHub连接测试成功"
    else
        log_warn "GitHub连接测试失败"
    fi
}

# 显示使用说明
show_usage() {
    log_info "=== V2Ray客户端部署完成 ==="
    echo
    echo -e "${GREEN}代理信息:${NC}"
    echo "  SOCKS5代理: 127.0.0.1:1080"
    echo "  HTTP代理:   127.0.0.1:8118"
    echo
    echo -e "${GREEN}使用方法:${NC}"
    echo "  1. 开启代理: ${YELLOW}pon${NC} 或 ${YELLOW}source /usr/local/bin/proxy-on${NC}"
    echo "  2. 关闭代理: ${YELLOW}poff${NC} 或 ${YELLOW}source /usr/local/bin/proxy-off${NC}"
    echo
    echo -e "${GREEN}GitHub使用:${NC}"
    echo "  # 开启代理后直接使用git命令"
    echo "  ${YELLOW}pon${NC}"
    echo "  ${YELLOW}git clone https://github.com/user/repo.git${NC}"
    echo
    echo -e "${GREEN}服务管理:${NC}"
    echo "  启动V2Ray: ${YELLOW}systemctl start v2ray${NC}"
    echo "  停止V2Ray: ${YELLOW}systemctl stop v2ray${NC}"
    echo "  查看状态: ${YELLOW}systemctl status v2ray${NC}"
    echo "  查看日志: ${YELLOW}journalctl -u v2ray -f${NC}"
    echo
    echo -e "${GREEN}测试连接:${NC}"
    echo "  ${YELLOW}curl -x socks5://127.0.0.1:1080 https://www.google.com${NC}"
    echo "  ${YELLOW}curl -x http://127.0.0.1:8118 https://api.github.com${NC}"
    echo
}

# 主函数
main() {
    clear
    echo -e "${BLUE}"
    echo "================================================"
    echo "         V2Ray Ubuntu 客户端一键部署脚本"
    echo "         连接到: allenincosmos.online"
    echo "================================================"
    echo -e "${NC}"
    
    check_root
    check_system
    update_system
    install_v2ray
    configure_v2ray_client
    start_v2ray_service
    setup_proxy_tools
    setup_github_proxy
    test_connection
    show_usage
    
    log_info "部署完成！请重新登录或运行 'source ~/.bashrc' 以使用代理别名"
}

# 运行主函数
main "$@"
