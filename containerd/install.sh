#!/bin/bash

set -e

# 获取目录路径
parent_path="$(cd "$(dirname "$0")" && pwd)"
grandparent_path="$(cd "$(dirname "${parent_path}")" && pwd)"
source "$grandparent_path/tools/common.sh"

# 检查系统架构
detect_system
arch="$(uname -m)"
note "检测到系统架构: $arch ($ARCH)"

# 验证架构是否被containerd/nerdctl支持
case $ARCH in
    amd64|arm64|armv7l|386)
        note "架构 $ARCH 支持安装containerd"
    ;;
    *)
        error "containerd/nerdctl 不支持当前架构: $ARCH"
        exit 1
    ;;
esac

# 设置默认参数
containerd_version="${2:-2.0.4}"
containerd_rootdir="${1:-/data/laiye/containerd}"
containerd_package="nerdctl-full-${containerd_version}-linux-${ARCH}.tar.gz"
containerd_url="https://github.com/containerd/nerdctl/releases/download/v${containerd_version}/${containerd_package}"

# 检查路径是否为绝对路径
if [[ "${containerd_rootdir}" != /* ]]; then
    error "${containerd_rootdir} is not an absolute path."
    exit 1
fi

# 检查容器运行时冲突
if which dockerd &> /dev/null || which podman &> /dev/null; then
    error "Please uninstall dockerd or podman first:
    - For yum: yum remove -y docker podman
    - For apt: apt remove -y docker podman"
    exit 1
fi

# 下载 nerdctl 包（如果本地不存在）
if [[ ! -f "${parent_path}/${arch}/${containerd_package}" ]]; then
    mkdir -p "${parent_path}/${arch}"
    ui_fail "未找到本地安装包 ${containerd_package}"
    error "本地未找到 ${containerd_package}, 请执行tools/download_package.sh下载"
    exit 1
fi

ui_section "Containerd (nerdctl-full) 安装 · ${ARCH}"

# 安装 containerd
ui_substep "解压 nerdctl-full 到 /usr/local"
tar -C /usr/local -xzf "${parent_path}/${arch}/${containerd_package}"
ui_ok "二进制文件已安装"

# 配置 containerd
ui_substep "生成 /etc/containerd/config.toml (root: ${containerd_rootdir})"
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

# 修改配置文件
sed -i \
-e '/sandbox_image/ s#registry.k8s.io/pause:3.8#localhost:5000/registry.aliyuncs.com/google_containers/pause:3.8#g' \
-e '/SystemdCgroup/ s#false#true#g' \
-e '/disable_apparmor/ s#false#true#g' \
-e "/^root/ s#/var/lib/containerd#${containerd_rootdir}#g" \
/etc/containerd/config.toml

# 启动服务
ui_substep "启动并启用 containerd 服务"
start_service "containerd"

# 尝试启动buildkit服务（如果存在）
if systemctl list-unit-files | grep -q "buildkit.service"; then
    start_service "buildkit"
    ui_ok "buildkit 服务已启动"
else
    warn "buildkit服务未找到，跳过启动"
fi

# 验证安装
if command -v nerdctl >/dev/null 2>&1; then
    ui_ok "containerd 安装完成"
    nerdctl version
    nerdctl info
else
    ui_fail "nerdctl 安装失败或不可用"
    error "nerdctl安装失败或不可用"
    exit 1
fi

# 普通用户授权提示
ui_box "普通用户授权 (rootless)" \
    "如需为普通用户配置 nerdctl 权限，请手动执行:" \
    "  containerd-rootless-setuptool.sh install" \
    "" \
    "该命令将配置 rootless 环境、环境变量、用户命名空间与 cgroup。" \
    "执行后需重新登录或重启 shell 使配置生效。"