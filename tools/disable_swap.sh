#!/bin/bash

set -e

# 需要 root 权限
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: 需要 root 权限运行此脚本" >&2
    exit 1
fi

# 关闭当前 swap，并注释掉 /etc/fstab 中的 swap 挂载项使其重启后保持关闭
swapoff -a
sed -i '/^[^#].*[\t\ ]swap[\t\ ]/ s/^/#/' /etc/fstab
