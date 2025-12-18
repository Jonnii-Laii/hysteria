#!/bin/bash

echo "==============================="
echo "   Hysteria2 商用版自动部署脚本"
echo "   UDP + 性能优化 + IPv6 + RPS/RFS"
echo "==============================="

# -----------------------------
# 修复 Debian 10 源（如果是 Buster）
# -----------------------------
if grep -qi 'buster' /etc/os-release 2>/dev/null || grep -qi 'buster' /etc/debian_version 2>/dev/null; then
    echo "[INFO] Debian 10 detected, fixing APT source..."
    sed -i 's|http://deb.debian.org|http://archive.debian.org|g' /etc/apt/sources.list
    sed -i 's|http://security.debian.org|http://archive.debian.org|g' /etc/apt/sources.list
    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until
fi

apt update
apt install -y curl wget tar openssl ethtool

# -----------------------------
# 安装 Hysteria2 最新版本
# -----------------------------
curl -fsSL https://get.hy2.sh | bash

mkdir -p /etc/hysteria

# -----------------------------
# 生成随机 CN 的自签证书
# -----------------------------
RAND_CN=$(openssl rand -hex 8).bing.com

openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -keyout /etc/hysteria/key.pem -out /etc/hysteria/cert.pem \
  -subj "/CN=$RAND_CN"

# -----------------------------
# 写入 Hysteria2 配置文件
# -----------------------------
cat > /etc/hysteria/config.yaml <<'EOF'
listen: :443

auth:
  type: userpass
  userpass:
    main: abc123a

tls:
  cert: /etc/hysteria/cert.pem
  key: /etc/hysteria/key.pem

masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com
    rewriteHost: true

obfs:
  type: salamander
  password: abc123a       # 和主密码一致

brutal:
  upMbps: 1000
  downMbps: 1000

ports: 40000-50000

quic:
  max_idle_timeout: 60s
  max_ack_delay: 25ms
  maxStreams: 100
  initStreamRecvWindow: 8388608
  maxStreamRecvWindow: 8388608
  initConnRecvWindow: 20971520
  maxConnRecvWindow: 20971520

bandwidth:
  up: 1000 mbps
  down: 1000 mbps

fastOpen: true
EOF

# -----------------------------
# 创建 systemd 服务
# -----------------------------
cat > /etc/systemd/system/hysteria.service <<EOF
[Unit]
Description=Hysteria2 Server
After=network.target

[Service]
ExecStart=/usr/local/bin/hysteria server --config /etc/hysteria/config.yaml
Restart=always
RestartSec=2
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable hysteria
systemctl restart hysteria

# -----------------------------
# 系统网络优化
# -----------------------------
cat >> /etc/sysctl.conf <<EOF
# 通用优化
fs.file-max = 1048576
fs.nr_open = 1048576
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1

# BBR + fq
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_mtu_probing = 2

# UDP 超强优化
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432
net.ipv4.udp_rmem_min = 131072
net.ipv4.udp_wmem_min = 131072
net.ipv4.udp_mem = 65536 131072 33554432
net.core.optmem_max = 25165824

# 网络队列优化
net.core.netdev_max_backlog = 8192
net.core.netdev_budget = 600
net.core.netdev_budget_usecs = 8000
net.core.somaxconn = 8192

# RPS/RFS
net.core.rps_sock_flow_entries = 32768
net.core.flow_limit_table_len = 32768

EOF

sysctl -p

# -----------------------------
# RPS/RFS + 多队列并行加速
# -----------------------------
for f in /sys/class/net/*/queues/rx-*/rps_cpus; do echo ffffffff > $f; done

# -----------------------------
# 网卡 Buffer 扩大
# -----------------------------
NIC=$(ls /sys/class/net | head -n 1)
ethtool -G $NIC rx 4096 tx 4096 2>/dev/null

# -----------------------------
# 防火墙放行
# -----------------------------
iptables -I INPUT -p udp --dport 443 -j ACCEPT
iptables -I INPUT -p tcp --dport 443 -j ACCEPT

# -----------------------------
# 限制系统日志大小
# -----------------------------
sed -i 's/#SystemMaxUse=/SystemMaxUse=50M/' /etc/systemd/journald.conf
systemctl restart systemd-journald

# -----------------------------
# 输出连接信息
# -----------------------------
IPV6=$(ip -6 addr show scope global | grep inet6 | awk '{print $2}' | cut -d/ -f1 | head -n 1)
IPV4=$(ip -4 addr show scope global | grep inet | awk '{print $2}' | cut -d/ -f1 | head -n 1)

PORT=443
PASSWORD="main:abc123a"

echo
echo "======== Hysteria2 客户端链接 ========"
echo
echo "IPv6："
echo "hy2://$PASSWORD@[$IPV6]:$PORT?insecure=1&sni=$RAND_CN#Hysteria2-IPv6"
echo
echo "IPv4："
echo "hy2://$PASSWORD@$IPV4:$PORT?insecure=1&sni=$RAND_CN#Hysteria2-IPv4"
echo
echo "======================================"
echo "Hysteria2 高性能商用版部署完成。"
