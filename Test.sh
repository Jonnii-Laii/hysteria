#!/bin/bash
set -e

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

echo "$PRIVATE_KEY" > ~/x25519_private.key
echo "$PUBLIC_KEY"  > ~/x25519_public.key
echo "密钥已保存到 ~/x25519_private.key 和 ~/x25519_public.key"
