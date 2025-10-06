# V2Ray TLS 一键部署

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

企业级V2Ray部署脚本，支持TLS加密、Let's Encrypt证书、流量伪装。

## 快速开始

```bash
git clone https://github.com/alleninnz/v2ray.git
cd v2ray

# 部署服务（交互式输入域名和邮箱）
sudo ./deploy-v2ray-tls.sh start

# 查看状态
./deploy-v2ray-tls.sh status

# 查看日志
./deploy-v2ray-tls.sh logs

# 查看连接信息
./deploy-v2ray-tls.sh info
```

## 核心特性

- **自动化部署** - 交互式配置，自动申请Let's Encrypt证书
- **流量伪装** - Nginx反向代理 + WebSocket，伪装成HTTPS网站
- **企业级安全** - 严格输入验证、防注入、权限控制
- **状态管理** - 持久化配置，支持快速重启/停止

## 系统要求

- **OS**: Ubuntu 18.04+, Debian 10+, CentOS 7+
- **内存**: 1GB+ (推荐2GB+)
- **磁盘**: 2GB+
- **网络**: 公网IP + 域名（必需）
- **权限**: Root

## 部署流程

1. **准备域名** - 配置A记录指向服务器IP
2. **运行脚本** - `sudo ./deploy-v2ray-tls.sh start`
3. **输入配置** - 按提示输入域名和邮箱
4. **获取连接** - 部署完成后查看 `/opt/v2ray-tls/connection-info.txt`

## 客户端支持

- **iOS**: Shadowrocket, Quantumult X
- **Android**: v2rayNG, Clash
- **Windows**: v2rayN, Clash for Windows
- **macOS**: ClashX, V2rayU
- **Linux**: v2ray-core, Clash

## 命令列表

| 命令 | 说明 | 需要root |
|------|------|---------|
| `start` | 交互式部署V2Ray | ✅ |
| `restart` | 重启服务 | ✅ |
| `stop` | 停止服务 | ✅ |
| `status` | 查看服务和证书状态 | ❌ |
| `logs` | 实时查看服务日志 | ❌ |
| `info` | 显示连接信息和VMess链接 | ❌ |
| `renew-cert` | 手动续期Let's Encrypt证书 | ✅ |

```bash
# 查看状态（容器状态 + 证书到期时间）
./deploy-v2ray-tls.sh status

# 查看实时日志（Ctrl+C退出）
./deploy-v2ray-tls.sh logs

# 显示连接信息
./deploy-v2ray-tls.sh info

# 重启服务
sudo ./deploy-v2ray-tls.sh restart

# 停止服务
sudo ./deploy-v2ray-tls.sh stop

# 续期证书
sudo ./deploy-v2ray-tls.sh renew-cert
```

## 安全特性

- 域名/邮箱格式验证，防注入攻击
- 证书文件权限控制（600/644）
- Docker容器安全加固
- TLS 1.2/1.3 + 现代密码套件
- 自动证书续期
