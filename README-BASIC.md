# V2Ray Basic 一键部署脚本

🚀 **快速部署V2Ray + Nginx反向代理的Docker解决方案**

## 📖 简介

V2Ray Basic 是一个简化的代理服务器部署方案，使用 WebSocket 传输协议，通过 Nginx 反向代理提供服务。此版本专为快速测试、学习V2Ray或在受信任的网络环境中使用而设计，具备完善的自动化部署和管理功能。

> **💡 升级建议**: 如需生产环境或高安全需求，推荐使用 [V2Ray TLS版本](README-TLS.md)，支持域名、SSL证书、22项安全增强和高级流量伪装。

## ✨ 功能特性

### 🎯 核心功能
- ✅ **一键部署** - 自动安装所有依赖并配置服务
- ✅ **Docker 容器化** - 使用 Docker 和 Docker Compose 管理
- ✅ **WebSocket 传输** - 使用 WebSocket 协议传输数据
- ✅ **Nginx 反向代理** - 提供负载均衡和请求转发
- ✅ **自动防火墙配置** - 支持 UFW、Firewalld 和 iptables

### 🛡️ 安全特性
- ✅ **UUID 自动生成** - 每次部署生成唯一标识符
- ✅ **网络隔离** - Docker 网络隔离
- ✅ **访问日志** - 完整的访问和错误日志记录
- ✅ **健康检查** - 容器健康状态监控

### 🔧 管理特性
- ✅ **系统检查** - 部署前全面检查系统要求
- ✅ **端口检测** - 自动检测端口占用情况
- ✅ **服务测试** - 部署后自动验证服务状态
- ✅ **错误处理** - 失败时自动清理和回滚

## 📋 系统要求

### 操作系统
- Ubuntu 18.04+ 
- CentOS 8+
- Debian 10+
- 其他支持 Docker 的 Linux 发行版

### 硬件要求
- **内存**: 最低 512MB，推荐 1GB+
- **磁盘**: 最低 1GB 可用空间
- **网络**: 公网IP地址

### 软件依赖
以下软件将自动安装（如果缺失）：
- Docker
- Docker Compose
- curl
- netstat

## 🚀 快速开始

### 1. 下载脚本
```bash
# 克隆完整项目（推荐）
git clone https://github.com/alleninnz/v2ray.git
cd v2ray

# 或直接下载脚本
wget https://raw.githubusercontent.com/alleninnz/v2ray/main/deploy-v2ray-basic.sh
```

### 2. 运行脚本
```bash
sudo bash deploy-v2ray-basic.sh
```

### 3. 部署过程
脚本会自动执行以下步骤：
1. ✅ 检查系统要求和权限
2. ✅ 检查端口占用情况
3. ✅ 安装 Docker 和 Docker Compose
4. ✅ 获取服务器公网IP
5. ✅ 生成配置文件
6. ✅ 启动服务并验证
7. ✅ 配置防火墙规则
8. ✅ 输出连接信息

## 📊 配置详情

### 默认配置
- **Nginx 端口**: 10086
- **V2Ray 内部端口**: 8080
- **WebSocket 路径**: `/ray`
- **传输协议**: WebSocket (ws)
- **加密**: VMess + auto

### 目录结构
```
/opt/v2ray-basic/
├── config/
│   └── config.json          # V2Ray 配置文件
├── nginx/
│   └── nginx.conf           # Nginx 配置文件
├── logs/                    # 日志目录
├── docker-compose.yml       # Docker Compose 配置
└── connection-info.txt      # 连接信息
```

### V2Ray 配置
- **协议**: VMess
- **传输**: WebSocket
- **路径**: `/ray`
- **alterId**: 0（推荐）
- **安全**: auto

### Nginx 配置
- **端口**: 10086
- **协议**: HTTP
- **代理路径**: `/ray` → V2Ray 容器
- **伪装页面**: 欢迎页面
- **健康检查**: `/health` 端点

## 📱 客户端配置

### Shadowrocket
```
类型: VMess
服务器: [你的服务器IP]
端口: 10086
用户ID: [生成的UUID]
额外ID: 0
加密方式: auto
传输协议: WebSocket (ws)
路径: /ray
Host: [你的服务器IP]
TLS: 关闭
```

### V2rayN
```
地址(Address): [你的服务器IP]
端口(Port): 10086
用户ID(User ID): [生成的UUID]
额外ID(AlterID): 0
加密方式(Security): auto
传输协议(Network): ws
路径(Path): /ray
TLS: none
```

### Clash
```yaml
proxies:
  - name: "V2Ray-Basic"
    type: vmess
    server: [你的服务器IP]
    port: 10086
    uuid: [生成的UUID]
    alterId: 0
    cipher: auto
## 📱 客户端配置

### 连接参数
部署完成后，脚本会显示完整的连接信息：

```
类型: VMess
服务器: [服务器IP地址]
端口: 10086
用户ID: [自动生成的UUID]
额外ID: 0
加密方式: auto
传输协议: WebSocket (ws)
路径: /ray
TLS: 关闭
```

### 主流客户端配置

#### 📱 Shadowrocket (iOS)
```
类型: VMess
地址: [服务器IP]
端口: 10086
UUID: [生成的UUID]
alterId: 0
安全: auto
网络: WebSocket
路径: /ray
TLS: 关闭
```

#### 🤖 v2rayNG (Android)
```
地址: [服务器IP]
端口: 10086
用户ID: [生成的UUID]
额外ID: 0
加密方式: auto
传输协议: ws
路径: /ray
传输层安全: 关闭
```

#### 💻 v2rayN (Windows)
```
地址: [服务器IP]
端口: 10086
用户ID: [生成的UUID]
额外ID: 0
加密方式: auto
传输协议: ws
路径: /ray
传输层安全: 关闭
```

#### 🍎 ClashX (macOS)
```yaml
proxies:
  - name: "V2Ray-Basic"
    type: vmess
    server: [服务器IP]
    port: 10086
    uuid: [生成的UUID]
    alterId: 0
    cipher: auto
    network: ws
    tls: false
    ws-opts:
      path: /ray
      headers:
        Host: [服务器IP]
```

### 配置说明
- **服务器地址**: 使用服务器的公网IP地址
- **TLS设置**: Basic版本不使用TLS加密
- **路径**: 固定为 `/ray`
- **UUID**: 每次部署自动生成唯一ID

## 🔧 管理命令

### 查看服务状态
```bash
cd /opt/v2ray-basic && docker-compose ps
```

### 查看日志
```bash
# 查看所有日志
cd /opt/v2ray-basic && docker-compose logs -f

# 查看 V2Ray 日志
cd /opt/v2ray-basic && docker-compose logs -f v2ray-server

# 查看 Nginx 日志
cd /opt/v2ray-basic && docker-compose logs -f nginx-proxy
```

### 重启服务
```bash
cd /opt/v2ray-basic && docker-compose restart
```

### 停止服务
```bash
cd /opt/v2ray-basic && docker-compose down
```

### 更新服务
```bash
cd /opt/v2ray-basic && docker-compose pull && docker-compose up -d
```

### 完全卸载
```bash
cd /opt/v2ray-basic && docker-compose down
rm -rf /opt/v2ray-basic
```

## 🔍 故障排除

### 常见问题解决

1. **端口被占用**
   ```bash
   # 检查端口占用
   netstat -tlnp | grep 10086
   # 终止占用进程
   sudo fuser -k 10086/tcp
   ```

2. **Docker 服务未启动**
   ```bash
   sudo systemctl start docker
   sudo systemctl enable docker
   ```

3. **防火墙阻止连接**
   ```bash
   # UFW
   sudo ufw allow 10086
   
   # Firewalld
   sudo firewall-cmd --permanent --add-port=10086/tcp
   sudo firewall-cmd --reload
   ```

4. **服务无法访问**
   ```bash
   # 检查容器状态
   cd /opt/v2ray-basic && docker-compose ps
   
   # 查看错误日志
   cd /opt/v2ray-basic && docker-compose logs
   ```

### 性能优化
- 定期清理Docker镜像: `docker system prune -f`
- 监控资源使用: `docker stats`
- 调整Nginx配置以适应高并发

### 获取支持
- 📖 [项目文档](https://github.com/alleninnz/v2ray)
- 🐛 [问题报告](https://github.com/alleninnz/v2ray/issues)
- 💬 [讨论区](https://github.com/alleninnz/v2ray/discussions)

## 📝 版本历史

- **v1.0**: 初始版本，基础VMess协议支持
- **v1.1**: 增加Docker支持和自动化部署
- **v1.2**: 优化错误处理和日志记录
- **v1.3**: 当前版本，增强安全性和稳定性

## ⚠️ 重要提醒

1. **安全建议**: Basic版本适用于测试和学习，生产环境请使用TLS版本
2. **网络要求**: 确保服务器具有稳定的网络连接
3. **合规使用**: 请确保在法律允许的范围内使用
4. **定期更新**: 建议定期更新Docker镜像和脚本

---

**💡 想要更强的安全性和流量伪装？** 

升级到 [V2Ray TLS版本](README-TLS.md) 享受：
- 🔒 企业级TLS加密
- 🎭 高级流量伪装  
- 🛡️ 22项安全增强
- 📜 智能证书管理

#### 1. 端口被占用
```bash
# 检查端口占用
netstat -tlnp | grep 10086

# 解决方案：停止占用端口的进程或修改配置使用其他端口
```

#### 2. Docker 安装失败
```bash
# 手动安装 Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo systemctl start docker
sudo systemctl enable docker
```

#### 3. 服务启动失败
```bash
# 检查 Docker 服务状态
sudo systemctl status docker

# 检查容器日志
cd /opt/v2ray-basic && docker-compose logs
```

#### 4. 无法连接
- ✅ 检查防火墙设置
- ✅ 验证云服务商安全组配置
- ✅ 确认端口 10086 已开放
- ✅ 检查客户端配置是否正确

#### 5. 性能问题
```bash
# 监控系统资源
htop
free -h
df -h

# 监控 Docker 容器资源
docker stats
```

### 调试命令

```bash
# 测试服务连通性
curl -v http://localhost:10086/health

# 检查容器网络
docker network ls
docker network inspect v2ray-basic_v2ray-net

# 进入容器调试
docker exec -it v2ray-basic-server sh
docker exec -it v2ray-basic-nginx sh
```

## 🔐 安全建议

### 1. 定期维护
- 🔄 定期更新 Docker 镜像
- 🔄 监控系统日志
- 🔄 备份重要配置

### 2. 网络安全
- 🛡️ 仅开放必要的端口
- 🛡️ 使用强密码和密钥
- 🛡️ 定期更换 UUID

### 3. 监控和日志
- 📊 监控异常访问
- 📊 分析流量模式
- 📊 设置日志轮转

### 4. 升级到 TLS 版本
对于生产环境，强烈建议使用 TLS 版本：
- 🔒 提供 HTTPS 加密
- 🔒 支持域名访问
- 🔒 更好的安全性

## 📞 技术支持

### 文档和资源
- 📖 [V2Ray 官方文档](https://www.v2fly.org/)
- 📖 [Docker 官方文档](https://docs.docker.com/)
- 📖 [Nginx 官方文档](https://nginx.org/en/docs/)

### 社区支持
- 💬 [GitHub Issues](https://github.com/alleninnz/v2ray/issues)
- 💬 [V2Ray 社区](https://github.com/v2fly/v2ray-core)

## ⚠️ 重要提醒

1. **合法使用**: 请确保在允许的法律框架内使用
2. **网络安全**: 本脚本仅用于技术学习和测试
3. **生产环境**: 生产环境建议使用 TLS 版本
4. **定期更新**: 保持系统和软件更新

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

---

**Made with ❤️ for the V2Ray community**