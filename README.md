# 🚀 科学上网一键部署脚本集合

**现代化、安全、高效的代理服务器自动化部署解决方案**

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Shell](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Docker](https://img.shields.io/badge/Containerization-Docker-blue.svg)](https://www.docker.com/)
[![V2Ray](https://img.shields.io/badge/Core-V2Ray-orange.svg)](https://www.v2fly.org/)
[![Trojan-Go](https://img.shields.io/badge/Core-Trojan--Go-red.svg)](https://p4gefau1t.github.io/trojan-go/)

## 📖 项目简介

本项目提供多种协议的高质量一键部署脚本，包括 V2Ray 和 Trojan-Go，专为生产环境和高安全需求场景设计。脚本经过精心优化，具备完善的错误处理、系统检查、证书管理和企业级安全配置。

## 🎯 支持的协议

### 🔶 V2Ray TLS - 企业级版本 ⭐ **推荐**
**适用场景**: 生产环境、高安全需求、完美流量伪装

- 🎭 **高级流量伪装** - 动态内容生成，极难检测
- 🔒 **企业级安全** - TLS 1.2/1.3 + 22项安全增强
- 🌐 **域名支持** - 使用真实域名增加可信度

### 🔴 Trojan-Go - 新增！🆕
**适用场景**: 多协议需求、高性能、简单配置
**专为服务器 95.169.25.130 优化**

- 🚀 **多协议支持** - Trojan + Shadowsocks + WebSocket
- ⚡ **高性能** - 基于 teddysun/trojan-go 官方镜像
- 🔧 **简单配置** - 一键部署，自动优化
- 📜 **智能证书管理** - Let's Encrypt 自动申请、续期和备份恢复
- 🎨 **三套网站模板** - 技术博客、企业网站、个人作品集
- �️ **证书备份机制** - 智能备份与恢复，避免重复申请
- � **进度指示器** - 可视化部署进度
- 📊 **详细文档** - [查看 TLS 版本文档](README-TLS.md)

```bash
# 使用 Let's Encrypt 证书部署
sudo bash deploy-v2ray-tls.sh -d your-domain.com -e your-email@example.com

# 使用自签名证书部署（测试）
sudo bash deploy-v2ray-tls.sh -d your-domain.com -c self-signed
```

**Trojan-Go 快速部署**：
```bash
# 一行命令安装（推荐）
curl -fsSL https://raw.githubusercontent.com/alleninnz/v2ray/main/install-trojan-server.sh | sudo bash

# 然后运行交互式部署
sudo bash quick-deploy-trojan.sh

# 或者直接命令行部署
sudo bash deploy-trojan-go-tls.sh -d your-domain.com -e your-email@example.com
```

📚 **详细文档**：
- V2Ray TLS 版本：[README-TLS.md](README-TLS.md)
- Trojan-Go 版本：[README-TROJAN.md](README-TROJAN.md)

## 🌟 核心特性

TLS版本具备企业级安全特性：

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
├── 🎨 /assets/css/style.css（专业CSS样式）
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

## 🛡️ 企业级安全特性（TLS版本）

### 22项安全增强措施
1. **证书安全** - 备份目录权限700，私钥600权限
2. **域名验证** - 防SQL注入，长度限制，字符过滤
3. **输入验证** - 邮箱格式验证，特殊字符过滤
4. **容器安全** - 非root用户，capability控制，no-new-privileges
5. **网络隔离** - 专用网络，子网限制，端口绑定控制
6. **SSL/TLS优化** - 现代密码套件，OCSP装订，PFS支持
7. **错误处理** - 统一异常处理，资源清理机制
8. **资源限制** - CPU/内存限制，ulimit控制
9. **端口安全** - 明确IP绑定，避免0.0.0.0暴露
10. **证书验证** - 有效期检查，完整性验证
11. **防火墙规则** - 严格出入站控制，最小权限原则
12. **容器加固** - 只读文件系统，临时文件隔离
13. **日志安全** - 敏感信息脱敏，安全日志记录
14. **自动更新** - 版本检查，安全更新提醒
15. **环境保护** - 敏感变量保护，环境隔离
16. **会话管理** - 超时控制，状态验证
17. **进度显示** - 可视化进度条，任务状态跟踪
18. **配置保护** - 文件权限控制，目录安全
19. **信号处理** - 优雅退出，资源清理，中断处理
20. **日志轮转** - 自动日志管理
21. **性能监控** - 资源使用监控
22. **更新机制** - 自动化更新检查

### 核心安全架构
- **多层防护**：输入验证 → 权限控制 → 网络隔离 → 容器安全
- **优雅处理**：信号捕获 → 资源清理 → 安全退出
- **监控告警**：权限验证 → 状态检查 → 异常报告
- **自动化管理**：证书续期 → 安全更新 → 配置验证

## 🚀 快速开始

### 1. 准备工作

- 一台具有公网IP的Linux服务器
- 一个可控制DNS的域名
- Root权限
- 邮箱地址（用于Let's Encrypt）

### 2. 下载和运行

```bash
# 克隆项目
git clone https://github.com/alleninnz/v2ray.git
cd v2ray

# 使用 Let's Encrypt 证书部署
sudo bash deploy-v2ray-tls.sh -d your-domain.com -e your-email@example.com

# 使用自签名证书部署（测试）
sudo bash deploy-v2ray-tls.sh -d your-domain.com -c self-signed
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
- VMess分享链接
- 二维码生成指导

## 🔧 系统要求

### 支持的操作系统
- **Ubuntu**: 18.04, 20.04, 22.04, 24.04
- **CentOS**: 8, 9
- **Debian**: 10, 11, 12
- **其他支持Docker的Linux发行版**

### 硬件要求
- **内存**: 1GB+ 内存（推荐2GB+以获得最佳性能）
- **磁盘空间**: 2GB+ 磁盘空间（安全增强需要更多资源）

### 网络要求
- 公网IP地址
- 域名支持（必需）
- 开放必要端口（80, 443, 自定义端口）
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

V2Ray TLS部署脚本现在支持智能证书备份机制，避免重复申请Let's Encrypt证书：

#### 🔄 自动备份流程
1. **检测现有证书** - 部署前扫描已存在的有效证书
2. **用户确认机制** - 交互式选择是否备份现有证书
3. **安全存储** - 备份到 `/var/lib/v2ray-backup`（权限700）
4. **详情展示** - 显示证书域名、到期时间、有效性状态

#### 🎯 智能恢复选项
重新部署时提供灵活选择：
```
是否使用备份的证书? (y/N): 
[y] 恢复备份证书（推荐，避免重新申请）
[N] 删除备份并重新申请新证书（默认）
```

#### ✅ 智能验证机制
- **有效期检查** - 自动验证恢复证书的剩余有效期
- **自动续期** - 证书有效期<7天时自动重新申请
- **安全清理** - 使用后自动清理临时备份文件
- **权限保护** - 严格的文件权限控制（600/700）

#### � 适用场景
- **配置调试** - 频繁测试时保留有效证书
- **重新部署** - 系统重装后快速恢复服务
- **避免限制** - 防止触及Let's Encrypt申请频率限制

## 🐛 故障排除

### 常见问题解决
1. **端口被占用** - 自动检测并提示解决方案
2. **域名解析问题** - DNS配置检查和修复建议  
3. **证书申请失败** - 自动回退到自签名证书
4. **防火墙配置** - 自动配置主流防火墙规则
5. **权限问题** - 自动修复文件和目录权限

### 性能优化建议
- **内存使用** - 建议2GB+内存以获得最佳性能
- **网络优化** - 启用BBR拥塞控制算法
- **磁盘空间** - 定期清理Docker镜像和日志文件

### 获取支持
- 📖 [详细文档](https://github.com/alleninnz/v2ray)
- 🐛 [问题报告](https://github.com/alleninnz/v2ray/issues)
- 💬 [讨论区](https://github.com/alleninnz/v2ray/discussions)

## 🤝 贡献指南

欢迎提交 Pull Request 和 Issue！参与贡献请遵循以下流程：

1. **Fork 项目** - 创建你的项目副本
2. **创建分支** - `git checkout -b feature/AmazingFeature`
3. **提交更改** - `git commit -m 'Add some AmazingFeature'`
4. **推送分支** - `git push origin feature/AmazingFeature`
5. **创建 PR** - 提交Pull Request并描述你的改进

### 贡献类型
- 🐛 **Bug修复** - 修复现有问题
- ✨ **新功能** - 添加有用的新特性
- 📝 **文档改进** - 完善文档和示例
- 🔒 **安全增强** - 提升安全性和稳定性
- 🎨 **界面优化** - 改进用户体验

## ⚠️ 重要声明

1. **合法使用**: 请确保在当地法律法规允许的范围内使用
2. **技术用途**: 本项目仅供技术学习和研究使用
3. **隐私保护**: 不记录用户访问数据，保护用户隐私
4. **责任声明**: 使用者需要对自己的行为负责

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE) - 详情请参阅许可证文件。

## 🌟 项目统计

- **⭐ Stars**: 如果这个项目对你有帮助，请给个 Star 支持！
- **📝 版本**: v2.0 - 企业级安全增强版
- **🔧 维护状态**: 积极维护中
- **📅 最后更新**: 2025年8月

## 📞 联系方式

- **作者**: Claude
- **GitHub**: [@alleninnz](https://github.com/alleninnz)
- **项目地址**: [V2Ray一键部署脚本](https://github.com/alleninnz/v2ray)

---

<div align="center">

**🔒 企业级安全 · 🎭 完美伪装 · ⚡ 极速体验**

*Made with ❤️ for the V2Ray community*

</div>