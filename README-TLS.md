# V2Ray TLS 一键部署脚本 🔒

🚀 **企业级V2Ray + Nginx + TLS + 22项安全增强的完整解决方案**

## 📖 简介

V2Ray TLS 是一个企业级代理服务器部署方案，使用 WebSocket over TLS 传输协议，通过域名和SSL证书提供安全连接。具备先进的流量伪装技术和22项安全增强措施，流量特征与真实HTTPS网站几乎无法区分。

## ✨ 核心亮点

### 🎭 **高级流量伪装**
- ✅ **动态内容生成** - 根据访问时间自动切换网站类型
- ✅ **三套专业模板** - 技术博客、企业网站、个人作品集
- ✅ **完整静态资源** - CSS/JS/API端点伪装
- ✅ **搜索引擎优化** - 专用爬虫页面，完整SEO配置
- ✅ **真实网站行为** - 模拟正常Web服务器响应

### 🔐 **企业级安全（22项增强）**
- ✅ **TLS 1.2/1.3 加密** - 最新的传输层安全协议
- ✅ **智能证书管理** - Let's Encrypt 自动申请、续期和备份恢复
- ✅ **证书备份机制** - 重新部署时可选择性恢复有效证书
- ✅ **容器安全加固** - 非root用户、capability控制、security_opt
- ✅ **网络隔离** - 专用网络、子网限制、端口绑定控制
- ✅ **输入验证强化** - 防SQL注入、长度限制、字符过滤
- ✅ **文件权限控制** - 严格的权限设置（600/700）
- ✅ **信号处理机制** - 优雅退出、资源清理、中断处理
- ✅ **HTTP/2 支持** - 现代Web协议支持
- ✅ **安全HTTP头** - HSTS、CSP、OCSP装订等安全策略
- ✅ **完美前向保密** - PFS加密套件
- ✅ **进度可视化** - 部署进度条和状态跟踪

### 🛡️ **反检测技术**
- ✅ **深度流量混淆** - WebSocket over TLS隐藏
- ✅ **域名伪装** - 使用真实域名增加可信度
- ✅ **行为模拟** - 模拟真实用户访问模式
- ✅ **多路径支持** - 只有特定路径才是代理流量
- ✅ **TLS指纹伪装** - 模拟真实HTTPS网站特征

## 📋 系统要求

### 基础要求
- **操作系统**: Ubuntu 18.04+, CentOS 8+, Debian 10+
- **内存**: 最低 1GB，推荐 2GB+（安全增强需要更多内存）
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
# 克隆完整项目（推荐）
git clone https://github.com/alleninnz/v2ray.git
cd v2ray

# 或直接下载脚本
wget https://raw.githubusercontent.com/alleninnz/v2ray/main/deploy-v2ray-tls.sh
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

#### 调试模式
```bash
sudo bash deploy-v2ray-tls.sh -d your-domain.com -e your-email@example.com --debug
```

### 4. 参数说明
- `-d, --domain` - 域名（必需）
- `-e, --email` - Let's Encrypt 邮箱地址
- `-c, --cert` - 证书类型：`letsencrypt`（默认）或 `self-signed`
- `--debug` - 启用调试模式
- `-h, --help` - 显示帮助信息

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
├── /assets/css/style.css # 完整CSS样式表
├── /js/main.js         # 真实JavaScript逻辑

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
## 📱 客户端配置

### 连接参数
部署完成后，脚本会显示完整的连接信息：

```
类型: VMess
服务器: your-domain.com
端口: 10086
用户ID: [自动生成的UUID]
额外ID: 0
加密方式: auto
传输协议: WebSocket (ws)
路径: /ray
Host: your-domain.com
TLS: 开启
SNI: your-domain.com
允许不安全: 关闭（Let's Encrypt）/ 开启（自签名）
```

### 主流客户端配置

#### 📱 Shadowrocket (iOS)
```
类型: VMess
地址: your-domain.com
端口: 10086
UUID: [生成的UUID]
alterId: 0
安全: auto
网络: WebSocket
路径: /ray
主机: your-domain.com
TLS: 开启
允许不安全: 关闭
```

#### 🤖 v2rayNG (Android)
```
地址: your-domain.com
端口: 10086
用户ID: [生成的UUID]
额外ID: 0
加密方式: auto
传输协议: ws
主机名: your-domain.com
路径: /ray
传输层安全: tls
```

#### 💻 v2rayN (Windows)
```
地址: your-domain.com
端口: 10086
用户ID: [生成的UUID]
额外ID: 0
加密方式: auto
传输协议: ws
伪装域名: your-domain.com
路径: /ray
传输层安全: tls
跳过证书验证: 否（Let's Encrypt）
```

#### 🍎 ClashX (macOS)
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
    skip-cert-verify: false
    ws-opts:
      path: /ray
      headers:
        Host: your-domain.com
```

### 🔗 自动配置功能

#### VMess 分享链接
脚本会自动生成 VMess 分享链接：
```
vmess://[base64编码的配置信息]
```

#### 二维码生成
可使用以下命令生成二维码：
```bash
# 安装 qrencode
sudo apt install qrencode  # Ubuntu/Debian
sudo yum install qrencode  # CentOS

# 生成二维码
echo "vmess://[分享链接]" | qrencode -t ansiutf8
```

#### 配置文件导出
连接信息会保存到：
```
/opt/v2ray-tls/connection-info.txt
```

### 🔧 客户端优化建议

#### 网络设置
- **路由模式**: 绕过局域网和中国大陆
- **DNS设置**: 使用安全DNS（如1.1.1.1）
- **Mux设置**: 启用多路复用（推荐值：8-16）

#### 性能优化
- **并发连接**: 根据网络情况调整
- **超时设置**: 连接超时30秒，读取超时60秒
- **重试机制**: 启用自动重连

### ⚠️ 重要注意事项

#### Let's Encrypt 证书
- **TLS设置**: 必须开启TLS
- **证书验证**: 不允许跳过证书验证
- **SNI设置**: 设置为你的域名

#### 自签名证书
- **TLS设置**: 必须开启TLS  
- **证书验证**: 需要允许不安全连接
- **警告**: 仅用于测试环境

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
├── /api/status          # 模拟API端点
├── /robots.txt          # 搜索引擎配置
└── /ray                 # 隐藏的V2Ray代理入口
```

### 智能网站模板选择
每个模板都是精心设计的完整网站：

#### 🌅 TechInsights 技术博客 (00:00-12:59)
```html
现代技术洞察平台，专注机器学习、云架构、Web开发
- 专业的技术文章布局
- 代码高亮和技术图表
- 完整的导航和分类系统
```

#### 🏢 InnovaTech 企业网站 (13:00-17:59) 
```html
专业的企业技术服务网站
- 企业级视觉设计
- 服务展示和案例研究
- 专业的商务色调和布局
```

#### 👨‍💻 Alex Chen 个人作品集 (18:00-23:59)
```html
全栈开发者个人展示网站
- 项目作品集展示
- 技能和经验介绍
- 个性化设计风格
```

## 🔐 智能证书管理系统

### 📋 证书管理概述
TLS版本配备了先进的证书管理系统，支持：
- **自动申请** - Let's Encrypt 证书自动申请
- **智能续期** - 自动检测并续期即将过期的证书
- **备份恢复** - 重新部署时可选择性恢复有效证书
- **多重验证** - 确保证书有效性和安全性

### 🆕 智能证书备份与恢复

#### 🔄 自动检测与备份
重新部署时，脚本会智能检测现有证书：
```bash
[STEP] 检查现有证书文件...
[INFO] 发现证书目录: /opt/v2ray-tls/certs/live/your-domain.com
[INFO] 证书文件详情:
  • 域名: your-domain.com
  • 到期时间: Sep 25 12:34:56 2025 GMT
  • 剩余天数: 28 天
  • 证书文件: 4 个

[证书备份确认]
是否备份现有证书以备后续使用? (y/N):
```

#### ⚡ 智能恢复选择
```bash
[STEP] 证书恢复选项
[INFO] 发现证书备份: /var/lib/v2ray-backup/certs-20250826-214836
[INFO] 备份证书状态: ✅ 有效 (剩余 28 天)

[选择证书处理方式]
  [y] 恢复备份证书 (推荐，避免重复申请)
  [N] 重新申请 Let's Encrypt 证书 (默认)

是否使用备份的证书? (y/N):
```

#### 🛡️ 多重安全验证
恢复证书时执行全面验证：
- ✅ **文件完整性** - 验证证书文件格式和签名
- ✅ **有效期检查** - 确保证书在有效期内
- ✅ **域名匹配** - 验证证书域名与部署域名一致  
- ✅ **权限设置** - 自动设置正确的文件权限(600)
- ✅ **自动续期** - 有效期<7天时自动重新申请

#### 📂 安全存储机制
- **备份位置**: `/var/lib/v2ray-backup/` (权限700)
- **文件权限**: 证书文件600，目录700
- **自动清理**: 使用后自动清理临时文件
- **时间戳**: 每次备份使用唯一时间戳命名

### 📜 手动证书管理
```bash
# 手动续期证书
/opt/v2ray-tls/scripts/renew-cert.sh

# 查看证书详细信息
openssl x509 -in /opt/v2ray-tls/certs/live/your-domain.com/fullchain.pem -text -noout

# 检查证书有效期
openssl x509 -in /opt/v2ray-tls/certs/live/your-domain.com/fullchain.pem -enddate -noout

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

### 💡 证书管理最佳实践

#### 重新部署建议
1. **保留有效证书** - 如果当前证书有效期>30天，建议选择恢复
2. **定期重新申请** - 有效期<30天时建议重新申请新证书
3. **避免频繁申请** - Let's Encrypt 有每周重复申请限制（5次/周）

#### 故障处理
- **备份失败** - 检查磁盘空间，确保有足够的临时存储
- **恢复失败** - 备份文件会保留，可手动复制到正确位置
- **证书过期** - 系统会自动跳过过期证书，重新申请新证书

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

#### 3. 证书备份与恢复问题

**证书备份失败**
```bash
# 检查磁盘空间
df -h /tmp

# 检查证书目录权限
ls -la /opt/v2ray-tls/certs

# 手动备份证书
sudo cp -r /opt/v2ray-tls/certs /tmp/manual-backup-$(date +%Y%m%d)
```

**证书恢复失败**
```bash
# 查找备份文件
ls -la /tmp/v2ray-certs-backup-*

# 手动恢复证书
sudo cp -r /tmp/v2ray-certs-backup-*/. /opt/v2ray-tls/certs/

# 检查证书文件权限
sudo chown -R root:root /opt/v2ray-tls/certs
sudo chmod 600 /opt/v2ray-tls/certs/live/*/privkey.pem
sudo chmod 644 /opt/v2ray-tls/certs/live/*/fullchain.pem
```

**证书过期或无效**
```bash
# 检查证书有效期
openssl x509 -in /opt/v2ray-tls/certs/live/your-domain.com/fullchain.pem -enddate -noout

# 验证证书域名
openssl x509 -in /opt/v2ray-tls/certs/live/your-domain.com/fullchain.pem -subject -noout

# 强制重新申请证书
sudo bash deploy-v2ray-tls.sh -d your-domain.com -e your-email@example.com
# 选择 [N] 删除备份并重新申请
```

#### 4. SSL证书验证失败
```bash
# 使用自签名证书重新部署
sudo bash deploy-v2ray-tls.sh -d your-domain.com -c self-signed
```

#### 5. 服务连接问题
```bash
# 检查端口监听
netstat -tlnp | grep 10086

# 测试本地连接
curl -k https://localhost:10086/health

# 检查防火墙规则
sudo ufw status
sudo firewall-cmd --list-ports
```

#### 6. 重复部署问题
```bash
# 如果反复重新部署导致证书问题
# 建议使用备份恢复机制，避免触及 Let's Encrypt 频率限制

# 查看 Let's Encrypt 申请日志
sudo tail -f /var/log/letsencrypt/letsencrypt.log

# 等待频率限制重置（通常1小时内最多5次，1周内最多5次重复申请）
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