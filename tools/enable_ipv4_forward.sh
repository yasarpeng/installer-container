#!/bin/bash

set -e

# 需要 root 权限写入 /etc
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: 需要 root 权限运行此脚本" >&2
    exit 1
fi

# INFO: 某些操作系统发行版的某些版本，默认通过 /etc/sysctl.conf 关闭了 ip_forward

# kylin 默认在这个文件中禁用ip_forward
# 只锚定 ip_forward 行的赋值, 避免把行内其它数字(如 10/100)误改
if [ -f /etc/sysctl.conf ]; then
    sed -i -E 's/^([[:space:]]*net\.ipv4\.ip_forward[[:space:]]*=[[:space:]]*).*/\11/' /etc/sysctl.conf
fi

# ubuntu 启用ip_forward
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-enable_ipv4_forward.conf

sysctl --system > /dev/null 2>&1
