#!/bin/bash
KEY_FILE="/usr/local/etc/xray/reality.keys"
mkdir -p "$(dirname "$KEY_FILE")"

# 手动执行 x25519 并保存（这里你需要手动输入或确认生成的密钥）
xray x25519
# 输出示例：
# PrivateKey: EKy3YD7BMEn_2UZeRoa7q_c7Zp4QHZUrrJD3g2VHR0I
# PublicKey: MHxEyASuMdEfZX3M7pYvY3HpLRzVsERWFHwmYFtWfkM

# 将密钥写入文件
cat > "$KEY_FILE" <<EOF
PRIVATE_KEY=EKy3YD7BMEn_2UZeRoa7q_c7Zp4QHZUrrJD3g2VHR0I
PUBLIC_KEY=MHxEyASuMdEfZX3M7pYvY3HpLRzVsERWFHwmYFtWfkM
EOF

chmod 600 "$KEY_FILE"
echo "密钥生成并保存到 $KEY_FILE"

# ====== 读取密钥并输出 ======
source "$KEY_FILE"

echo "===== 读取到的 Reality 密钥 ====="
echo "PrivateKey: $PRIVATE_KEY"
echo "PublicKey:  $PUBLIC_KEY"
