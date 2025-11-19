#!/bin/bash
set -e

echo "======================================"
echo "     🚀 Xray Reality 一键安装脚本"
echo "======================================"

# ====== 1. 安装官方 Xray ======
echo "🚀 安装官方 Xray..."
bash <(wget -qO- https://github.com/XTLS/Xray-install/raw/main/install-release.sh) install -u root

# ====== 2. 生成 UUID ======
UUID=$(xray uuid)
SHORT_ID=$(openssl rand -hex 4)
# 检查 xray 是否安装
if ! command -v xray &> /dev/null; then
    echo "Error: xray 未安装，请先安装 Xray" >&2
    exit 1
fi

# 生成密钥
KEY_PAIR=$(xray x25519 2>/tmp/xray_keypair_error.log) || {
    echo "Error: 无法生成 X25519 密钥对，请查看 /tmp/xray_keypair_error.log" >&2
    exit 1
}

PRIVATE_KEY=$(echo "$KEY_PAIR" | grep -oP '(?<=Private key: ).*')
PUBLIC_KEY=$(echo "$KEY_PAIR"  | grep -oP '(?<=Public key: ).*')

echo "=============================="
echo "Private Key: $PRIVATE_KEY"
echo "Public Key:  $PUBLIC_KEY"
echo "=============================="

# ====== 4. 创建 Xray 配置 ======
mkdir -p /usr/local/etc/xray
mkdir -p /var/log/xray
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

# ====== 5. 创建 systemd 服务 ======
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

# ====== 6. 启动并开机自启 ======
systemctl daemon-reload
systemctl enable xray
systemctl restart xray

# ====== 7. 输出连接信息 ======
echo -e "\n===== Reality 配置信息 ====="
echo "服务器IP: $SERVER_IP"
echo "UUID: $UUID"
echo "PublicKey: $PUBLIC_KEY"
echo "ShortID: $SHORT_ID"
echo "伪装域名: www.bing.com"
echo "端口: 443"
echo -e "客户端示例（NekoBox 格式）：\n\
vless://$UUID@$SERVER_IP:443?encryption=none&security=reality&flow=xtls-rprx-vision&sni=www.bing.com&fp=chrome&pbk=$PUBLIC_KEY&sid=$SHORT_ID&type=tcp#Reality\n"
