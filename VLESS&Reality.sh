#!/bin/bash
set -e

echo "======================================"
echo "     🚀 Xray Reality 一键安装脚本"
echo "======================================"

# ====== 1. 安装 Xray ======
echo "🚀 安装官方 Xray..."
bash <(wget -qO- https://github.com/XTLS/Xray-install/raw/main/install-release.sh) install -u root

# ====== 2. 获取 Xray 版本 ======
XRAY_VERSION=$(xray version | head -n1 | awk '{print $2}')
echo "🛠 Xray 版本: $XRAY_VERSION"

# ====== 3. 生成 UUID 和 Reality 密钥 ======
echo "🔑 生成 UUID 和 Reality 密钥..."
UUID=$(xray uuid)

KEY_PAIR=$(xray x25519)

# 根据版本判断字段提取方式
if [[ "$XRAY_VERSION" < "25.10" ]]; then
    # 旧版本
    PRIVATE_KEY=$(echo "$KEY_PAIR" | awk -F': ' '/Private key/ {print $2}')
    PUBLIC_KEY=$(echo "$KEY_PAIR" | awk -F': ' '/Public key/ {print $2}')
else
    # 新版本
    PRIVATE_KEY=$(echo "$KEY_PAIR" | awk -F':' '/PrivateKey/ {print $2}' | tr -d ' ')
    PUBLIC_KEY=$(echo "$KEY_PAIR" | awk -F':' '/Password/ {print $2}' | tr -d ' ')
fi

SHORT_ID=$(openssl rand -hex 4)

# ====== 4. 创建配置目录 ======
mkdir -p /usr/local/etc/xray
mkdir -p /var/log/xray

# ====== 5. 写入 Reality 配置 ======
SERVER_IP=$(curl -s ipv4.ip.sb)
cat > /usr/local/etc/xray/config.json << EOF
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "inbounds": [
    {
      "port": 443,
      "listen": "0.0.0.0",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "$UUID",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "www.bing.com:443",
          "xver": 0,
          "serverNames": ["www.bing.com"],
          "privateKey": "$PRIVATE_KEY",
          "shortIds": ["$SHORT_ID"],
          "fingerprint": "chrome"
        }
      }
    }
  ],
  "outbounds": [
    { "protocol": "freedom" }
  ]
}
EOF

# ====== 6. 创建 systemd 服务 ======
echo "⚙️ 创建 systemd 服务..."
cat > /etc/systemd/system/xray.service <<EOF
[Unit]
Description=Xray Service
After=network.target nss-lookup.target

[Service]
User=root
ExecStart=/usr/local/bin/xray run -config /usr/local/etc/xray/config.json
Restart=always
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

# ====== 7. 启动并开机自启 ======
systemctl daemon-reload
systemctl enable xray
systemctl restart xray
systemctl status xray --no-pager -l

# ====== 8. 输出连接信息 ======
CLIENT_LINK="vless://$UUID@$SERVER_IP:443?encryption=none&security=reality&flow=xtls-rprx-vision&sni=www.bing.com&fp=chrome&pbk=$PUBLIC_KEY&sid=$SHORT_ID&type=tcp#Reality_$SHORT_ID"
echo -e "\n===== Reality 配置信息 ====="
echo "服务器IP: $SERVER_IP"
echo "UUID: $UUID"
echo "PrivateKey: $PRIVATE_KEY"
echo "PublicKey/Password: $PUBLIC_KEY"
echo "ShortID: $SHORT_ID"
echo "伪装域名: www.bing.com"
echo "端口: 443"
echo -e "\n客户端示例（NekoBox 格式）："
echo "$CLIENT_LINK"

# 将连接信息追加写入 config.json 最前端（作为注释）
{
  echo "// 客户端连接示例（NekoBox 格式）："
  echo "// $CLIENT_LINK"
  echo ""
  cat /usr/local/etc/xray/config.json
} > /usr/local/etc/xray/config.json.tmp
mv /usr/local/etc/xray/config.json.tmp /usr/local/etc/xray/config.json
