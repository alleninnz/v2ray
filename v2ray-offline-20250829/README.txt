V2Ray 离线安装包使用说明
=======================

1. 文件说明：
   - v2ray-linux-64.zip         # Linux x86_64 架构
   - deploy-v2ray-ubuntu-client-offline.sh  # 离线安装脚本

2. 使用方法：
   - 将整个文件夹传输到目标Ubuntu服务器
   - 在目标服务器上运行：sudo bash deploy-v2ray-ubuntu-client-offline.sh

3. 注意事项：
   - 脚本会自动检测系统架构并选择对应的安装包
   - 确保所有文件都在同一目录下
   - 需要root权限运行安装脚本

4. 服务器配置：
   - 服务器地址：allenincosmos.online:10086
   - 协议：VMess over WebSocket with TLS
   - 路径：/ray

5. 安装完成后：
   - 使用 pon 开启代理
   - 使用 poff 关闭代理
   - SOCKS5代理：127.0.0.1:1080
   - HTTP代理：127.0.0.1:8118
