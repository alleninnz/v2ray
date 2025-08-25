# V2Ray TLS 一键部署脚本 🔒

🚀 **企业级V2Ray + Nginx + TLS的完整解决方案，具备高级流量伪装功能**

## 📖 简介

V2Ray TLS 是一个高级代理服务器部署方案，使用 WebSocket over TLS 传输协议，通过域名和SSL证书提供安全连接。具备先进的流量伪装技术，流量特征与真实HTTPS网站几乎无法区分。

## ✨ 核心亮点

### 🎭 **高级流量伪装**
- ✅ **动态内容生成** - 根据访问时间自动切换网站类型
- ✅ **三套专业模板** - 技术博客、企业网站、个人作品集
- ✅ **完整静态资源** - CSS/JS/API端点伪装
- ✅ **搜索引擎优化** - 专用爬虫页面，完整SEO配置
- ✅ **真实网站行为** - 模拟正常Web服务器响应

### 🔐 **企业级安全**
- ✅ **TLS 1.2/1.3 加密** - 最新的传输层安全协议
- ✅ **自动证书管理** - Let's Encrypt 自动申请和续期
- ✅ **HTTP/2 支持** - 现代Web协议支持
- ✅ **安全HTTP头** - HSTS、CSP等安全策略
- ✅ **完美前向保密** - PFS加密套件

### 🛡️ **反检测技术**
- ✅ **深度流量混淆** - WebSocket over TLS隐藏
- ✅ **域名伪装** - 使用真实域名增加可信度
- ✅ **行为模拟** - 模拟真实用户访问模式
- ✅ **多路径支持** - 只有特定路径才是代理流量

## 📋 系统要求

### 基础要求
- **操作系统**: Ubuntu 18.04+, CentOS 8+, Debian 10+
- **内存**: 最低 1GB，推荐 2GB+（TLS处理需要更多内存）
- **磁盘**: 最低 2GB 可用空间
- **网络**: 公网IP地址 + 域名解析

### 域名要求
- 🌐 **有效域名** - 必须拥有一个可以控制DNS的域名
- 🌐 **DNS解析** - 域名需要正确解析到服务器IP
- 🌐 **80端口访问** - Let's Encrypt需要80端口进行验证

## 🚀 快速开始

### 1. 准备域名
确保你的域名正确解析到服务器：
```bash
# 检查域名解析
nslookup your-domain.com
dig +short your-domain.com
```

### 2. 下载脚本
```bash
wget https://raw.githubusercontent.com/alleninnz/v2ray/main/deploy-v2ray-tls.sh
# 或者
curl -O https://raw.githubusercontent.com/alleninnz/v2ray/main/deploy-v2ray-tls.sh
```

### 3. 运行脚本

#### 使用 Let's Encrypt 证书（推荐）
```bash
sudo bash deploy-v2ray-tls.sh -d your-domain.com -e your-email@example.com
```

#### 使用自签名证书（测试环境）
```bash
sudo bash deploy-v2ray-tls.sh -d your-domain.com -c self-signed
```

#### 查看所有选项
```bash
bash deploy-v2ray-tls.sh -h
```

### 4. 参数说明
- `-d, --domain` - 域名（必需）
- `-e, --email` - Let's Encrypt 邮箱地址
- `-c, --cert` - 证书类型：`letsencrypt`（默认）或 `self-signed`

## 🎭 流量伪装详解

### 动态内容切换
脚本会根据访问时间自动切换不同的网站类型：

| 时间段 | 网站类型 | 描述 |
|--------|----------|------|
| 00:00-12:59 | 📡 **TechInsights 技术博客** | ML趋势、Web开发、云架构文章 |
| 13:00-17:59 | 🏢 **InnovaTech 企业网站** | 云迁移、数字转型、AI集成服务 |
| 18:00-23:59 | 👨‍💻 **Alex Chen 个人作品集** | 全栈开发者、项目展示、技能介绍 |

### 完整的Web生态系统
```
https://your-domain.com/
├── /                    # 动态主页（根据时间切换）
├── /assets/style.css    # 完整CSS样式表
├── /js/main.js         # 真实JavaScript逻辑
├── /api/status         # 模拟API状态接口
├── /api/health         # 健康检查API
├── /images/            # 图片路径（404响应）
├── /favicon.ico        # 网站图标
├── /robots.txt         # 搜索引擎爬虫指令
└── /ray                # V2Ray WebSocket路径（隐藏）
```

### 搜索引擎优化
- 🔍 **完整Meta标签** - description, keywords, Open Graph
- 🔍 **结构化数据** - JSON-LD 组织架构数据
- 🔍 **Canonical链接** - 防重复内容
- 🔍 **移动端适配** - 响应式设计
- 🔍 **爬虫专用页面** - 针对搜索引擎优化的内容

## 📊 配置详情

### 默认配置
- **HTTPS 端口**: 10086
- **HTTP 端口**: 80（重定向到HTTPS）
- **V2Ray 内部端口**: 8080
- **WebSocket 路径**: `/ray`
- **传输协议**: WebSocket over TLS

### 目录结构
```
/opt/v2ray-tls/
├── config/
│   └── config.json              # V2Ray 配置文件
├── nginx/
│   └── nginx.conf               # Nginx 配置文件
├── certs/                       # SSL证书目录
│   ├── live/your-domain.com/    # Let's Encrypt 证书
│   └── www/                     # ACME验证目录
├── scripts/
│   └── renew-cert.sh           # 证书续期脚本
├── logs/                        # 日志目录
├── docker-compose.yml           # Docker Compose 配置
└── connection-info.txt          # 连接信息
```

### 证书管理
- **自动续期** - 每月自动检查和续期证书
- **失败回退** - Let's Encrypt失败时自动切换到自签名
- **Cron任务** - 自动添加到系统定时任务

## 📱 客户端配置

### Shadowrocket
```
类型: VMess
服务器: your-domain.com
端口: 10086
用户ID: [生成的UUID]
额外ID: 0
加密方式: auto
传输协议: WebSocket (ws)
路径: /ray
Host: your-domain.com
TLS: 开启
SNI: your-domain.com
允许不安全: 关闭（Let's Encrypt）/ 开启（自签名）
```

### V2rayN
```
地址: your-domain.com
端口: 10086
用户ID: [生成的UUID]
额外ID: 0
加密方式: auto
传输协议: ws
路径: /ray
传输层安全: tls
SNI: your-domain.com
```

### Clash
```yaml
proxies:
  - name: "V2Ray-TLS"
    type: vmess
    server: your-domain.com
    port: 10086
    uuid: [生成的UUID]
    alterId: 0
    cipher: auto
    network: ws
    tls: true
    servername: your-domain.com
    ws-opts:
      path: /ray
      headers:
        Host: your-domain.com
```

### VMess 分享链接
脚本会自动生成 VMess 分享链接，可直接导入客户端：
```
vmess://[base64编码的配置信息]
```

## 🔧 管理命令

### 基础管理
```bash
# 查看服务状态
cd /opt/v2ray-tls && docker-compose ps

# 查看日志
cd /opt/v2ray-tls && docker-compose logs -f

# 重启服务
cd /opt/v2ray-tls && docker-compose restart

# 停止服务
cd /opt/v2ray-tls && docker-compose down

# 更新服务
cd /opt/v2ray-tls && docker-compose pull && docker-compose up -d
```

### 证书管理
```bash
# 手动续期证书
/opt/v2ray-tls/scripts/renew-cert.sh

# 查看证书信息
openssl x509 -in /opt/v2ray-tls/certs/live/your-domain.com/fullchain.pem -text -noout

# 测试证书有效性
openssl s_client -connect your-domain.com:10086 -servername your-domain.com
```

### 监控和调试
```bash
# 测试HTTPS连接
curl -k https://your-domain.com:10086/health

# 查看Nginx访问日志
tail -f /opt/v2ray-tls/logs/access.log

# 检查证书状态
curl -I https://your-domain.com:10086
```

## 🔍 故障排除

### 常见问题解决

#### 1. 域名解析问题
```bash
# 检查域名解析
dig +short your-domain.com

# 检查从服务器是否能访问
curl -I http://your-domain.com
```

#### 2. Let's Encrypt 证书申请失败
- ✅ 确保域名正确解析到服务器IP
- ✅ 检查80端口是否被占用
- ✅ 验证邮箱地址格式正确
- ✅ 检查防火墙是否允许80端口

```bash
# 手动测试80端口
python3 -m http.server 80
```

#### 3. SSL证书验证失败
```bash
# 使用自签名证书重新部署
sudo bash deploy-v2ray-tls.sh -d your-domain.com -c self-signed
```

#### 4. 服务连接问题
```bash
# 检查端口监听
netstat -tlnp | grep 10086

# 测试本地连接
curl -k https://localhost:10086/health

# 检查防火墙规则
sudo ufw status
sudo firewall-cmd --list-ports
```

#### 5. 证书过期
```bash
# 检查证书有效期
openssl x509 -in /opt/v2ray-tls/certs/live/your-domain.com/fullchain.pem -enddate -noout

# 强制续期
/opt/v2ray-tls/scripts/renew-cert.sh
```

### 性能优化

#### 1. 系统优化
```bash
# 优化内核参数
echo 'net.core.default_qdisc=fq' >> /etc/sysctl.conf
echo 'net.ipv4.tcp_congestion_control=bbr' >> /etc/sysctl.conf
sysctl -p
```

#### 2. Docker优化
```bash
# 清理未使用的Docker资源
docker system prune -a

# 监控容器资源使用
docker stats
```

## 🔐 安全最佳实践

### 1. 证书安全
- 🔒 使用 Let's Encrypt 证书而非自签名
- 🔒 定期检查证书有效期
- 🔒 启用证书透明度监控

### 2. 访问控制
- 🛡️ 配置强密码和复杂UUID
- 🛡️ 限制登录尝试次数
- 🛡️ 监控异常访问模式

### 3. 网络安全
- 🌐 只开放必要的端口（80, 443, 10086）
- 🌐 使用云厂商的安全组功能
- 🌐 启用DDoS防护

### 4. 日志监控
```bash
# 设置日志轮转
echo '/opt/v2ray-tls/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    notifempty
    create 0644 root root
}' > /etc/logrotate.d/v2ray-tls
```

## 🎯 高级功能

### 1. 多域名支持
可以修改配置支持多个域名：
```nginx
server_name domain1.com domain2.com *.example.com;
```

### 2. 负载均衡
```yaml
services:
  v2ray-1:
    # V2Ray实例1配置
  v2ray-2:
    # V2Ray实例2配置
```

### 3. 监控集成
```yaml
services:
  prometheus:
    # 监控配置
  grafana:
    # 可视化配置
```

## 📈 性能指标

### 预期性能
- **并发连接**: 1000+ 同时连接
- **带宽**: 支持千兆网络
- **延迟**: 额外延迟 < 5ms
- **CPU使用**: < 10%（闲时）
- **内存使用**: < 512MB

### 基准测试
```bash
# 测试延迟
ping your-domain.com

# 测试带宽
speedtest-cli

# 压力测试
ab -n 1000 -c 10 https://your-domain.com:10086/
```

## 🌟 更新日志

### v2.0.0（当前版本）
- ✅ 新增动态内容生成
- ✅ 新增三套专业网站模板
- ✅ 新增搜索引擎优化
- ✅ 新增完整静态资源伪装
- ✅ 优化TLS配置和安全性

### v1.0.0
- ✅ 基础TLS支持
- ✅ Let's Encrypt自动证书
- ✅ Docker容器化部署

## 📞 技术支持

### 在线资源
- 📖 [项目文档](https://github.com/alleninnz/v2ray)
- 📖 [V2Ray官方文档](https://www.v2fly.org/)
- 📖 [Let's Encrypt文档](https://letsencrypt.org/docs/)

### 社区支持
- 💬 [GitHub Issues](https://github.com/alleninnz/v2ray/issues)
- 💬 [讨论区](https://github.com/alleninnz/v2ray/discussions)

## ⚠️ 重要声明

1. **合法使用**: 请确保在当地法律法规允许的范围内使用
2. **隐私保护**: 不记录用户访问数据，保护用户隐私
3. **技术用途**: 本项目仅供技术学习和研究使用
4. **责任声明**: 使用者需要对自己的行为负责

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

---

**🔒 安全连接，🎭 完美伪装，⚡ 极速体验**