# 🚀 V2Ray 一键部署脚本集合

**现代化、安全、高效的 V2Ray 代理服务器自动化部署解决方案**

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Docker](https://img.shields.io/badge/Containerization-Docker-blue.svg)](https://www.docker.com/)
[![V2Ray](https://img.shields.io/badge/Core-V2Ray-orange.svg)](https://www.v2fly.org/)

## 📖 项目简介

本项目提供两个高质量的 V2Ray 一键部署脚本，适用于不同的使用场景和安全需求。所有脚本都经过精心优化，具备完善的错误处理、系统检查、证书管理和安全配置。

## 🎯 脚本概览

### 🔷 V2Ray Basic - 基础版本
**适用场景**: 快速测试、学习环境、内网使用

- ✅ **快速部署** - 3分钟内完成全自动安装
- ✅ **WebSocket 传输** - 使用 ws 协议，稳定可靠
- ✅ **Docker 容器化** - 隔离环境，易于管理
- ✅ **自动配置** - 包含 Nginx 反向代理
- ✅ **详细文档** - [查看 Basic 版本文档](README-BASIC.md)

```bash
# 一键部署
sudo bash deploy-v2ray-basic.sh
```

### 🔶 V2Ray TLS - 企业级版本 ⭐ **推荐**
**适用场景**: 生产环境、高安全需求、完美流量伪装

- 🎭 **高级流量伪装** - 动态内容生成，极难检测
- 🔒 **企业级加密** - TLS 1.2/1.3 + 完美前向保密
- 🌐 **域名支持** - 使用真实域名增加可信度
- 📜 **智能证书管理** - Let's Encrypt 自动申请、续期和备份恢复
- 🎨 **三套网站模板** - 技术博客、企业网站、个人作品集
- 🔍 **SEO 优化** - 搜索引擎友好，完整 meta 标签
- 🛡️ **证书备份机制** - 自动备份证书，支持用户选择性恢复
- 📊 **详细文档** - [查看 TLS 版本文档](README-TLS.md)

```bash
# 使用 Let's Encrypt 证书部署
sudo bash deploy-v2ray-tls.sh -d your-domain.com -e your-email@example.com

# 使用自签名证书部署（测试）
sudo bash deploy-v2ray-tls.sh -d your-domain.com -c self-signed
```

## 🌟 核心特性对比

| 特性 | Basic 版本 | TLS 版本 |
|------|------------|----------|
| **部署复杂度** | ⭐ 简单 | ⭐⭐ 中等 |
| **安全等级** | ⭐⭐⭐ 中等 | ⭐⭐⭐⭐⭐ 企业级 |
| **流量伪装** | ⭐⭐ 基础 | ⭐⭐⭐⭐⭐ 高级 |
| **抗检测性** | ⭐⭐⭐ 良好 | ⭐⭐⭐⭐⭐ 极强 |
| **域名需求** | ❌ 不需要 | ✅ 必需 |
| **证书管理** | ❌ 无 | ✅ 自动管理 + 智能备份 |
| **重部署支持** | ⭐⭐ 基础 | ⭐⭐⭐⭐⭐ 智能恢复 |
| **适用环境** | 测试、学习 | 生产、企业 |

## 🎭 TLS版本的流量伪装技术

### 动态内容生成
TLS版本具备业界领先的流量伪装能力：

- **📡 技术博客模式** (00:00-12:59): 显示专业技术博客页面
- **🏢 企业网站模式** (13:00-17:59): 展示企业服务网站
- **👨‍💻 个人作品集模式** (18:00-23:59): 呈现开发者个人网站

### 完整Web生态
```
https://your-domain.com/
├── 📄 动态主页（3种模板轮换）
├── 🎨 /assets/style.css（专业CSS样式）
├── ⚡ /js/main.js（真实JavaScript交互）
├── 🔗 /api/status（模拟后端API）
├── 🔍 /robots.txt（搜索引擎配置）
└── 🔒 /ray（隐藏的V2Ray入口）
```

### 反检测技术
- ✅ **TLS指纹伪装** - 模拟真实HTTPS网站特征
- ✅ **HTTP行为标准化** - 完整的HTTP响应头
- ✅ **搜索引擎优化** - 真实的SEO配置和meta标签
- ✅ **移动端适配** - 响应式设计支持

## 🚀 快速开始

### 1. 选择适合的版本

**新手用户 / 测试环境** → 选择 **Basic版本**
**生产环境 / 高安全需求** → 选择 **TLS版本**

### 2. 准备工作

#### Basic版本
- 一台具有公网IP的Linux服务器
- Root权限

#### TLS版本  
- 一台具有公网IP的Linux服务器
- 一个可控制DNS的域名
- Root权限
- 邮箱地址（用于Let's Encrypt）

### 3. 下载和运行

```bash
# 克隆项目
git clone https://github.com/alleninnz/v2ray.git
cd v2ray

# 运行Basic版本
sudo bash deploy-v2ray-basic.sh

# 运行TLS版本
sudo bash deploy-v2ray-tls.sh -d your-domain.com -e your-email@example.com
```

## 📱 客户端配置

### 支持的客户端
- **iOS**: Shadowrocket, Quantumult X, Surge
- **Android**: v2rayNG, Clash for Android
- **Windows**: v2rayN, Clash for Windows, Qv2ray  
- **macOS**: ClashX, V2rayU, Qv2ray
- **Linux**: v2ray-core, Clash

### 配置示例
脚本运行完成后会自动生成详细的客户端配置信息，包括：
- 完整的连接参数
- 各主流客户端的配置方法
- VMess分享链接（TLS版本）
- 二维码生成指导

## 🔧 系统要求

### 支持的操作系统
- **Ubuntu**: 18.04, 20.04, 22.04
- **CentOS**: 8, 9
- **Debian**: 10, 11, 12
- **其他支持Docker的Linux发行版**

### 硬件要求
- **Basic版本**: 512MB+ 内存, 1GB+ 磁盘空间
- **TLS版本**: 1GB+ 内存, 2GB+ 磁盘空间

### 网络要求
- 公网IP地址
- TLS版本需要域名支持

## 🛡️ 安全特性

### Basic版本安全
- ✅ Docker容器隔离
- ✅ UUID随机生成
- ✅ 访问日志记录
- ✅ 防火墙自动配置

### TLS版本安全（在Basic基础上增加）
- 🔒 **传输层加密**: TLS 1.2/1.3
- 🔒 **证书管理**: Let's Encrypt自动续期
- 🔒 **安全HTTP头**: HSTS, CSP, X-Frame-Options
- 🔒 **完美前向保密**: ECDHE密钥交换
- 🔒 **流量混淆**: 深度包检测对抗

## 📊 性能表现

### 基准测试
- **并发连接数**: 1000+ 同时连接
- **吞吐量**: 支持千兆网络满速
- **延迟增加**: < 5ms
- **资源消耗**: CPU < 10%, 内存 < 512MB

### 优化特性
- HTTP/2 支持提升性能
- Gzip压缩减少带宽消耗
- Keep-Alive连接复用
- 缓存策略优化

## 🔧 管理和维护

### 服务管理
```bash
# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f

# 重启服务
docker-compose restart

# 更新服务
docker-compose pull && docker-compose up -d
```

### TLS证书管理
```bash
# 检查证书有效期
openssl x509 -in /opt/v2ray-tls/certs/live/domain.com/fullchain.pem -enddate -noout

# 手动续期证书
/opt/v2ray-tls/scripts/renew-cert.sh
```

### 🆕 智能证书备份与恢复

TLS版本现在支持智能证书备份机制，重新部署时可选择性恢复：

#### 证书备份流程
1. **自动检测** - 发现现有证书文件时自动提示备份
2. **用户确认** - 交互式选择是否备份现有证书
3. **详情展示** - 显示证书域名、到期时间等关键信息

#### 证书恢复选择
重新部署时会提供两种选择：
```
[y] 使用备份的证书（推荐，避免重新申请）
[N] 删除备份并重新申请 Let's Encrypt 证书（默认）
```

#### 智能验证
- ✅ **有效期检查** - 自动验证恢复证书的有效性
- ✅ **自动续期** - 证书有效期<7天时自动重新申请
- ✅ **安全清理** - 使用后自动清理备份文件

#### 使用场景
- 🔄 **重新部署** - 保留有效证书，避免频繁申请
- 🔧 **配置调试** - 调试配置时不丢失证书
- 📦 **系统迁移** - 在新服务器上恢复证书

> **注意**: Let's Encrypt 有申请频率限制，使用备份证书可避免触及限制

## 🐛 故障排除

### 常见问题
1. **端口被占用** - 自动检测并提示解决方案
2. **域名解析问题** - DNS配置检查和修复建议  
3. **证书申请失败** - 自动回退到自签名证书
4. **防火墙配置** - 自动配置主流防火墙

### 获取支持
- 📖 [详细文档](https://github.com/alleninnz/v2ray)
- 🐛 [问题报告](https://github.com/alleninnz/v2ray/issues)
- 💬 [讨论区](https://github.com/alleninnz/v2ray/discussions)

## 🤝 贡献指南

欢迎提交 Pull Request 和 Issue！

1. Fork 本项目
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

## ⚠️ 重要声明

1. **合法使用**: 请确保在当地法律法规允许的范围内使用
2. **技术用途**: 本项目仅供技术学习和研究使用
3. **隐私保护**: 不记录用户访问数据，保护用户隐私
4. **责任声明**: 使用者需要对自己的行为负责

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE) - 详情请参阅许可证文件。

## 🌟 Star History

如果这个项目对你有帮助，请给个 Star ⭐ 支持一下！

## 📞 联系方式

- **作者**: Allen
- **GitHub**: [@alleninnz](https://github.com/alleninnz)

---

<div align="center">

**🔒 安全连接，🎭 完美伪装，⚡ 极速体验**

Made with ❤️ for the V2Ray community

</div>