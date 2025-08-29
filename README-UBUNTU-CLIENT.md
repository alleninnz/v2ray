# V2Ray Ubuntu 客户端一键部署使用说明

## 概述
这个脚本用于在Ubuntu服务器上快速部署V2Ray客户端，连接到你的v2ray服务器（allenincosmos.online），实现GitHub等网站的访问。

## 服务器配置信息
- **服务器地址**: allenincosmos.online
- **端口**: 10086
- **用户ID**: 5a8021ec-a973-487b-a5d0-299440c1bc2e
- **传输协议**: WebSocket (ws)
- **路径**: /ray
- **TLS**: 开启
- **SNI**: allenincosmos.online

## 使用方法

### 1. 部署客户端
在你的Ubuntu服务器上运行：

```bash
# 下载脚本（如果是从本地传输）
scp deploy-v2ray-ubuntu-client.sh your-server:/tmp/

# 登录到Ubuntu服务器
ssh your-server

# 运行部署脚本
sudo bash /tmp/deploy-v2ray-ubuntu-client.sh
```

### 2. 使用代理

部署完成后，你可以使用以下命令：

```bash
# 开启代理
pon

# 现在可以直接使用GitHub
git clone https://github.com/user/repo.git
curl https://api.github.com

# 关闭代理
poff
```

### 3. 代理端口信息
- **SOCKS5代理**: 127.0.0.1:1080
- **HTTP代理**: 127.0.0.1:8118

### 4. 手动使用代理
如果不想使用别名，可以手动设置：

```bash
# 设置环境变量
export http_proxy=http://127.0.0.1:8118
export https_proxy=http://127.0.0.1:8118

# 或者直接在命令中指定代理
curl -x http://127.0.0.1:8118 https://api.github.com
git -c http.proxy=http://127.0.0.1:8118 clone https://github.com/user/repo.git
```

## 服务管理

```bash
# 查看V2Ray状态
sudo systemctl status v2ray

# 启动/停止/重启V2Ray
sudo systemctl start v2ray
sudo systemctl stop v2ray
sudo systemctl restart v2ray

# 查看日志
sudo journalctl -u v2ray -f
```

## 测试连接

```bash
# 测试SOCKS5代理
curl -x socks5://127.0.0.1:1080 https://www.google.com

# 测试HTTP代理
curl -x http://127.0.0.1:8118 https://api.github.com

# 测试GitHub连接（开启代理后）
pon
curl https://api.github.com
```

## 故障排除

### 1. 如果连接失败
- 检查服务器配置是否正确
- 确认防火墙设置
- 查看V2Ray日志：`sudo journalctl -u v2ray -f`

### 2. 如果GitHub仍然无法访问
- 确认代理已开启：`echo $http_proxy`
- 手动测试代理：`curl -x http://127.0.0.1:8118 https://api.github.com`
- 检查DNS设置

### 3. 重新配置
如果需要修改配置，编辑文件：
```bash
sudo nano /usr/local/etc/v2ray/config.json
sudo systemctl restart v2ray
```

## 安全注意事项
- 代理端口（1080, 8118）默认只监听本地，如需远程访问请谨慎配置
- 定期检查V2Ray版本并更新
- 监控服务器日志，确保没有异常连接

## 支持的系统
- Ubuntu 18.04+
- Ubuntu 20.04+
- Ubuntu 22.04+

部署完成后，你就可以在Ubuntu服务器上正常使用GitHub了！
