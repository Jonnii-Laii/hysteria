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

# ====== 3. 使用 OpenSSL 生成 X25519 密钥对 ======
echo "🔑 自动生成 Reality 密钥..."
KEY_FILE="/usr/local/etc/xray/reality.keys"
mkdir -p "$(dirname "$KEY_FILE")"

# 生成私钥
PRIVATE_KEY_RAW=$(openssl genpkey -algorithm X25519 -outform PEM 2>/dev/null)
# 提取 base64 格式的私钥
PRIVATE_KEY=$(echo "$PRIVATE_KEY_RAW" | awk 'NR>1 && NR<11 {printf "%s",$0}')

# 生成公钥
PUBLIC_KEY_RAW=$(openssl pkey -in <(echo "$PRIVATE_KEY_RAW") -pubout -outform PEM 2>/dev/null)
PUBLIC_KEY=$(echo "$PUBLIC_KEY_RAW" | awk 'NR>1 && NR<12 {printf "%s",$0}')

# 保存密钥到文件
cat > "$KEY_FILE" <<EOF
PRIVATE_KEY=$PRIVATE_KEY
PUBLIC_KEY=$PUBLIC_KEY
EOF
chmod 600 "$KEY_FILE"
echo "✅ Reality 密钥生成完成并保存到 $KEY_FILE"

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
