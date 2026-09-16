#!/bin/bash

set -e

# 需要 root 权限写入 /etc
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: 需要 root 权限运行此脚本" >&2
    exit 1
fi

cat <<EOF > /etc/modules-load.d/ipvs.conf
# https://github.com/kubernetes/kubernetes/tree/master/pkg/proxy/ipvs
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
ip_tables
br_netfilter
bridge
nf_nat
nf_conntrack
EOF

systemctl restart systemd-modules-load.service

