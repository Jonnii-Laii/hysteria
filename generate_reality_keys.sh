# 这是辅助生成vless密钥的脚本
#!/bin/bash
set -e

# ====== Reality 密钥保存路径 ======
KEY_FILE="/usr/local/etc/xray/reality.keys"

# 创建目录
mkdir -p $(dirname "$KEY_FILE")

echo "🔑 正在生成 Reality 密钥，请稍候..."

# 尝试非交互方式生成密钥
KEY_PAIR=$(xray x25519 --yes 2>/dev/null || echo | xray x25519 2>/dev/null)

# 提取 PrivateKey 和 PublicKey
PRIVATE_KEY=$(echo "$KEY_PAIR" | grep -Eo 'PrivateKey:[[:space:]]*[A-Za-z0-9_-]+' | awk '{print $2}')
PUBLIC_KEY=$(echo "$KEY_PAIR" | grep -Eo 'PublicKey:[[:space:]]*[A-Za-z0-9_-]+' | awk '{print $2}')

# 检查是否成功获取密钥
if [ -z "$PRIVATE_KEY" ] || [ -z "$PUBLIC_KEY" ]; then
    echo "❌ Reality 密钥生成失败，请手动检查 xray x25519 输出"
    exit 1
fi

# 保存到文件
cat > "$KEY_FILE" <<EOF
PRIVATE_KEY=$PRIVATE_KEY
PUBLIC_KEY=$PUBLIC_KEY
EOF

chmod 600 "$KEY_FILE"

echo "✅ Reality 密钥生成成功！"
echo "密钥已保存到：$KEY_FILE"
echo "PrivateKey: $PRIVATE_KEY"
echo "PublicKey: $PUBLIC_KEY"
