#!/bin/bash

set -e

# 需要 root 权限写入 /etc
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: 需要 root 权限运行此脚本" >&2
    exit 1
fi

echo br_netfilter > /etc/modules-load.d/br_netfilter.conf
modprobe br_netfilter 2>/dev/null || true
systemctl restart systemd-modules-load.service

# 解决noekylin v7启用br_netfilter失败的问题
cat <<EOF > /etc/sysctl.d/99-enable_br_netfilter.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sysctl --system > /dev/null 2>&1
