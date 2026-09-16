#!/bin/bash

set -e

# 需要 root 权限操作防火墙
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: 需要 root 权限运行此脚本" >&2
    exit 1
fi

# 该脚本依赖 firewalld 的 firewall-cmd。若系统未安装/未运行 firewalld 则跳过。
if ! command -v firewall-cmd >/dev/null 2>&1; then
    echo "Warning: 未找到 firewall-cmd，当前系统可能未使用 firewalld，跳过端口放行。" >&2
    exit 0
fi
if ! firewall-cmd --state >/dev/null 2>&1; then
    echo "Warning: firewalld 未运行，跳过端口放行。可先执行: systemctl start firewalld" >&2
    exit 0
fi

# http/https
firewall-cmd --zone=public --add-port=80/tcp --permanent
firewall-cmd --zone=public --add-port=80/tcp
firewall-cmd --zone=public --add-port=443/tcp --permanent
firewall-cmd --zone=public --add-port=443/tcp
# etcd
firewall-cmd --zone=public --add-port=2379-2380/tcp --permanent
firewall-cmd --zone=public --add-port=2379-2380/tcp
# kube-apiserver
firewall-cmd --zone=public --add-port=6443/tcp --permanent
firewall-cmd --zone=public --add-port=6443/tcp
# kubelet
firewall-cmd --zone=public --add-port=10250/tcp --permanent
firewall-cmd --zone=public --add-port=10250/tcp
# flannel
firewall-cmd --zone=public --add-port=8285/udp --permanent
firewall-cmd --zone=public --add-port=8285/udp
firewall-cmd --zone=public --add-port=8472/udp --permanent
firewall-cmd --zone=public --add-port=8472/udp
# flannel pod&svc subnet
firewall-cmd --zone=public --add-rich-rule 'rule family=ipv4 source address=10.244.0.0/16 accept' --permanent
firewall-cmd --zone=public --add-rich-rule 'rule family=ipv4 source address=10.244.0.0/16 accept'
firewall-cmd --zone=public --add-rich-rule 'rule family=ipv4 source address=10.96.0.0/16 accept' --permanent
firewall-cmd --zone=public --add-rich-rule 'rule family=ipv4 source address=10.96.0.0/16 accept'
# nodeport range
firewall-cmd --zone=public --add-port=30000-32767/tcp --permanent
firewall-cmd --zone=public --add-port=30000-32767/tcp
firewall-cmd --zone=public --add-port=30000-32767/udp --permanent
firewall-cmd --zone=public --add-port=30000-32767/udp
# masquerade
firewall-cmd --zone=public --add-masquerade --permanent
firewall-cmd --zone=public --add-masquerade

# rpa 6.0
firewall-cmd --zone=public --add-port=8084/tcp --permanent
firewall-cmd --zone=public --add-port=8084/tcp

# list all
firewall-cmd --zone=public --list-all
