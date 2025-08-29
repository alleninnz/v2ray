# Trojan-Go 一键部署脚本 (简化版)

这是一个专为内网或受限网络环境设计的 Trojan-Go 部署脚本，无需域名，仅使用IP地址进行部署。

## 主要特性

- ✅ **纯IP部署** - 无需域名，直接使用服务器IP
- ✅ **自签名证书** - 自动生成基于IP地址的SSL证书
- ✅ **纯Trojan协议** - 仅支持Trojan协议，简单高效
- ✅ **Docker容器化** - 基于 `teddysun/trojan-go` 镜像
- ✅ **无外网依赖** - 适用于受限网络环境
- ✅ **安全加固** - 容器安全配置，只读文件系统

## 系统要求

- Linux系统 (Ubuntu/Debian/CentOS/RHEL)
- Root权限
- 基本网络连接（用于安装Docker等依赖）

## 快速部署

```bash
# 下载脚本
wget https://raw.githubusercontent.com/your-repo/v2ray/main/deploy-trojan-go-tls.sh

# 给予执行权限
chmod +x deploy-trojan-go-tls.sh

# 运行部署（使用默认端口443）
./deploy-trojan-go-tls.sh

# 或指定自定义端口
./deploy-trojan-go-tls.sh -p 8443
```

## 使用说明

### 部署选项

```bash
./deploy-trojan-go-tls.sh [选项]

选项:
  -p PORT     指定Trojan端口 (默认: 443)
  -h          显示帮助信息
  --debug     启用调试模式
```

### 部署后管理

脚本会自动创建 `/opt/trojan-go` 目录，包含以下文件：

```
/opt/trojan-go/
├── config/
│   └── config.json          # Trojan配置文件
├── certs/
│   └── live/[SERVER_IP]/    # SSL证书目录
├── logs/                    # 日志目录
├── web/                     # 备用网页
├── docker-compose.yml       # Docker编排文件
└── connection-info.txt      # 连接信息
```

#### 常用管理命令

```bash
# 查看服务状态
cd /opt/trojan-go && docker-compose ps

# 查看日志
cd /opt/trojan-go && docker-compose logs -f

# 重启服务
cd /opt/trojan-go && docker-compose restart

# 停止服务
cd /opt/trojan-go && docker-compose down

# 更新服务
cd /opt/trojan-go && docker-compose pull && docker-compose up -d
```

## 客户端配置

部署完成后，脚本会生成详细的连接信息保存在 `connection-info.txt` 文件中。

### 重要配置项

- **服务器地址**: 你的服务器IP
- **端口**: 443 (或自定义端口)
- **密码**: 自动生成的32位随机密码
- **TLS**: 启用
- **允许不安全连接**: **必须启用** (自签名证书)
- **跳过证书验证**: **必须启用** (自签名证书)

### 推荐客户端

**PC端:**
- v2rayN (Windows)
- V2rayU (macOS)
- Clash (跨平台)

**移动端:**
- Shadowrocket (iOS)
- Clash for Android (Android)
- Matsuri (Android)

**路由器:**
- OpenWrt + Passwall
- OpenWrt + SSR Plus

## 安全注意事项

1. **证书验证**: 由于使用自签名证书，客户端必须配置为允许不安全连接或跳过证书验证
2. **端口安全**: 确保服务器防火墙开放所选端口
3. **密码安全**: 自动生成的密码足够安全，请妥善保管
4. **访问控制**: 建议配置适当的访问控制策略

## 故障排除

### 服务无法启动
```bash
# 检查Docker服务
systemctl status docker

# 查看详细日志
cd /opt/trojan-go && docker-compose logs
```

### 连接失败
1. 检查服务器防火墙是否开放端口
2. 确认客户端配置了允许不安全连接
3. 验证IP地址和端口是否正确

### 证书问题
```bash
# 重新生成证书
cd /opt/trojan-go
rm -rf certs/live/[SERVER_IP]
# 然后重新运行部署脚本
```

## 版本历史

- **v2.0** - 简化版本，移除域名依赖，纯IP部署
- **v1.0** - 完整版本，支持域名和多协议

## 注意事项

- 此脚本专为简化部署而设计，仅支持基本的Trojan协议
- 不支持CDN或WebSocket传输
- 适用于对简单性和稳定性有要求的场景
- 建议在测试环境中先行验证

## 许可证

MIT License
