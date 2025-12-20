#!/bin/bash

# -------------------------------
# 🔐 脚本访问密码保护（SHA-256）
# -------------------------------

# 这里填写你想要的明文密码（开发者用）
PASSWORD_PLAIN="psw2025-"

# 将密码生成 SHA-256 哈希，用于校验
# 生成方法：
# echo -n "psw2025-" | sha256sum
# 将输出的 hash 填写在下面
PASSWORD_HASH="6f310eb32ef875b41cf53fe04182ec53425fcb8d52e856e3dc963840e9dcd67d"

# 用户输入密码
read -sp "请输入访问密码: " INPUT_PASSWORD
echo

# 校验输入
INPUT_HASH=$(echo -n "$INPUT_PASSWORD" | sha256sum | awk '{print $1}')

if [ "$INPUT_HASH" != "$PASSWORD_HASH" ]; then
    echo "密码错误，脚本终止！"
    exit 1
fi

echo "密码验证通过，继续执行脚本…"

# 🛠️ 先修复 Buster 源问题（仅 Debian 10）
if grep -qi 'buster' /etc/os-release 2>/dev/null || grep -qi 'buster' /etc/debian_version 2>/dev/null; then
    echo "[INFO] Detected Debian 10 (Buster) - switching APT sources to archive.debian.org"

    sed -i 's|http://deb.debian.org|http://archive.debian.org|g' /etc/apt/sources.list
    sed -i 's|http://security.debian.org|http://archive.debian.org|g' /etc/apt/sources.list

    echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until

    apt update
fi

# ✅ 继续安装依赖
apt install curl wget tar -y

# 安装 Hysteria2 最新版本
curl -fsSL https://get.hy2.sh | bash

# 创建配置目录
mkdir -p /etc/hysteria

# 生成自签 TLS 证书（有效期10年）
openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
  -keyout /etc/hysteria/key.pem -out /etc/hysteria/cert.pem \
  -subj "/CN=bing.com"

# 写入配置文件（启用高并发 & 性能优化）
cat > /etc/hysteria/config.yaml <<EOF

# listen: 0.0.0.0:443

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
    protocol: https
  
EOF

# 写入 systemd 启动服务配置
cat > /etc/systemd/system/hysteria.service <<EOF
[Unit]
Description=Hysteria2 Server
After=network.target

[Service]
ExecStart=/usr/local/bin/hysteria server --config /etc/hysteria/config.yaml
Restart=always

[Install]
WantedBy=multi-user.target

EOF

# 加载 systemd 服务并启动
systemctl daemon-reload
systemctl enable hysteria
systemctl restart hysteria

cat >> /etc/sysctl.conf <<EOF
# =========================
# 文件描述符限制（适配高并发）
# =========================
fs.file-max = 1048576
fs.nr_open = 1048576

# =========================
# 连接跟踪表大小（适用于代理、NAT 等）
# =========================
net.netfilter.nf_conntrack_max = 262144

# =========================
# IPv6 优化
# =========================
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1
net.ipv6.neigh.default.gc_thresh1 = 1024
net.ipv6.neigh.default.gc_thresh2 = 2048
net.ipv6.neigh.default.gc_thresh3 = 4096
net.ipv6.icmp.ratelimit = 1000

# =========================
# 通用网络优化
# =========================
net.core.default_qdisc = fq
net.ipv4.tcp_congestion_control = bbr
net.core.netdev_max_backlog = 8192
net.ipv4.ip_local_port_range = 10240 65535

# =========================
# TCP 参数优化
# =========================
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 0
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_syncookies = 1

# =========================
# 安全与路由设置
# =========================
net.ipv4.ip_forward = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# =========================
# 缓冲区 & 内存优化
# =========================
# TCP 缓冲区
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# UDP 缓冲区（扩展优化）
net.ipv4.udp_mem = 65536 131072 33554432
net.ipv4.udp_rmem_min = 32768
net.ipv4.udp_wmem_min = 32768

# 系统最大缓冲区
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.rmem_max = 33554432
net.core.wmem_max = 33554432

# =========================
# UDP 高并发 & 低丢包专项优化
# =========================
# 单个 socket 接收队列最大长度
net.core.optmem_max = 25165824
net.core.netdev_budget = 600
net.core.netdev_budget_usecs = 8000

# 避免 UDP 包被强行丢弃
net.ipv4.udp_max_err_queue = 4096
net.ipv4.udp_rmem_min = 65536
net.ipv4.udp_wmem_min = 65536

# =========================
# 额外建议
# =========================
# 增大队列长度，减少丢包
net.core.somaxconn = 8192
net.ipv4.udp_rfc2460 = 1


EOF

# 应用内核参数
sysctl -p

# 提取 IPv6 地址（取第一个全局 IPv6）
IPV6=$(ip -6 addr show scope global | grep inet6 | head -n1 | awk '{print $2}' | cut -d'/' -f1)

# 提取第一个全局 IPv4 地址
IPV4=$(ip -4 addr show scope global | grep inet | head -n1 | awk '{print $2}' | cut -d'/' -f1)

# 提取端口号
PORT=$(grep '^listen:' /etc/hysteria/config.yaml | grep -oE '[0-9]+$')

# 提取认证密码
PASSWORD=$(grep -E '^[[:space:]]*main:' /etc/hysteria/config.yaml | sed -E 's/[[:space:]]//g')

systemctl status hysteria --no-pager

# 拼接输出
echo -e "\n客户端IPV6连接信息：\nhy2://$PASSWORD@[$IPV6]:$PORT?insecure=1&sni=bing.com#Hysteria2-$IPV6\n"

echo -e "\n客户端IPV4连接信息：\nhy2://$PASSWORD@$IPV4:$PORT?insecure=1&sni=bing.com#Hysteria2-$IPV4\n"

# 输出状态
echo -e "\n✅ Hysteria2 已部署完毕，使用端口 443，自签 TLS，已开启高并发优化。"
systemctl status hysteria --no-pager
