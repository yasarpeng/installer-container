#!/bin/bash

set -e

# 需要 root 权限写入 /etc
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: 需要 root 权限运行此脚本" >&2
    exit 1
fi

cat <<EOF > /etc/sysctl.d/99-container.conf
# 容器运行所需的内核参数
fs.inotify.max_user_instances = 8192
fs.inotify.max_user_watches = 524288

net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-arptables = 1

EOF

# 这些是 sysctl 参数, 需用 sysctl --system 应用 (原先 restart modules-load 不会生效)
sysctl --system > /dev/null 2>&1

