#!/bin/bash

set -e

# 需要 root 权限写入 /etc
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: 需要 root 权限运行此脚本" >&2
    exit 1
fi

cat <<EOF > /etc/security/limits.d/99-common.conf
* - memlock     unlimited
* - nofile      131072
* - nproc       65535
EOF

