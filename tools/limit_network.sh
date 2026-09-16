#!/bin/bash

set -e

# WARNNING: 禁用公网访问、禁用访问公网，用于模拟客户的无互联网访问的环境
# 该脚本会插入默认 DROP 规则，可能导致当前 SSH 会话断开、主机失联，请谨慎执行！

# 需要 root 权限操作 iptables
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: 需要 root 权限运行此脚本" >&2
    exit 1
fi

# 显式确认 (传入 -y 可跳过, 供自动化调用)
if [ "$1" != "-y" ]; then
    echo "⚠ 警告: 即将屏蔽除内网外的所有出入站流量 (默认 DROP)。"
    echo "  这可能立即断开你的 SSH 连接并使主机无法远程访问。"
    read -r -p "确认继续请输入 yes: " confirm
    if [ "$confirm" != "yes" ]; then
        echo "已取消。"
        exit 0
    fi
fi

# 入站: 放行本地回环与内网网段，其余丢弃
iptables -A INPUT -s 127.0.0.0/8 -j ACCEPT
iptables -A INPUT -s 10.0.0.0/8 -j ACCEPT
iptables -A INPUT -s 173.20.0.0/16 -j ACCEPT
iptables -A INPUT -s 192.168.0.0/16 -j ACCEPT
iptables -A INPUT -j DROP

# 出站: 放行本地回环与内网网段，其余丢弃
iptables -A OUTPUT -d 127.0.0.0/8 -j ACCEPT
iptables -A OUTPUT -d 10.0.0.0/8 -j ACCEPT
iptables -A OUTPUT -d 173.20.0.0/16 -j ACCEPT
iptables -A OUTPUT -d 192.168.0.0/16 -j ACCEPT
iptables -A OUTPUT -j DROP
