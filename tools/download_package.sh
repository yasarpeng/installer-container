#!/bin/bash

set -e

# Get directory path
parent_path="$(cd "$(dirname "$0")" && pwd)"
grandparent_path="$(cd "$(dirname "${parent_path}")" && pwd)"

source $parent_path/common.sh

# Check architecture
arch="$(uname -m)"
case $arch in
    x86_64)
        ARCH="amd64"
    ;;
    aarch64)
        ARCH="arm64"
    ;;
    *)
        error "The current hardware platform or virtual platform is not supported."
        exit 1
    ;;
esac

choice_runtime() {
    while true; do
        underline "请选择您想要安装的容器运行时: "
        PS3=$'\033[32m输入选项编号: \033[0m'
        
        local runtimes_options=("docker" "containerd")
        
        select runtime in "${runtimes_options[@]}" "退出"
        do
            if [[ "$runtime" == "退出" ]]; then
                exit 0
                elif [[ -n "$runtime" ]]; then
                case "$runtime" in
                    "docker")
                        local selected_version=$(show_version_menu "Docker" "${DOCKER_VERSIONS[@]}")
                        if [[ $? -eq 0 && -n "$selected_version" ]]; then
                            downloader "$runtime" "$selected_version"
                        else
                            # 用户选择返回主菜单，重新显示主菜单
                            break 2
                        fi
                    ;;
                    "containerd")
                        local selected_version=$(show_version_menu "containerd" "${CONTAINERD_VERSIONS[@]}")
                        if [[ $? -eq 0 && -n "$selected_version" ]]; then
                            downloader "$runtime" "$selected_version"
                        else
                            # 用户选择返回主菜单，重新显示主菜单
                            break 2
                        fi
                    ;;
                esac
                # 下载完成，退出脚本
                exit 0
            else
                error "无效的编号选项, 请重新选择"
            fi
        done
    done
}


downloader() {
    local service=$1
    local version=$2
    ui_banner "安装包下载器" "Package Downloader · ${arch}"
    case "$service" in
        "docker")
            url="https://download.docker.com/linux/static/stable/${arch}/docker-${version}.tgz"
            url_rootless_extras="https://download.docker.com/linux/static/stable/${arch}/docker-rootless-extras-${version}.tgz"

            # 根据 Docker 版本选择兼容的 Docker Compose 版本
            local compose_version=$(get_compose_version "$version")
            url_compose="https://github.com/docker/compose/releases/download/v${compose_version}/docker-compose-linux-${arch}"

            local dest="${grandparent_path}/docker/${arch}"
            mkdir -p "$dest"

            ui_kv "运行时" "docker"
            ui_kv "版本" "$version"
            ui_kv "compose 版本" "$compose_version"
            ui_kv "目标目录" "$dest"

            STEP_TOTAL=3; STEP_CURRENT=0
            ui_step "下载 Docker 二进制包"
            ui_download "$url" "$dest" || return 1
            ui_step "下载 rootless-extras"
            ui_download "$url_rootless_extras" "$dest" || return 1
            ui_step "下载 docker-compose"
            ui_download "$url_compose" "$dest" || return 1

            mv "${dest}/docker-compose-linux-${ARCH}" "${dest}/docker-compose"
            chmod +x "${dest}/docker-compose"

            ui_summary_add ok "docker-${version}" "已下载"
            ui_summary_add ok "docker-compose ${compose_version}" "已下载"
            ui_summary_render "下载结果"
            success "下载完成，存储路径：${dest}/"
        ;;
        "containerd")
            url="https://github.com/containerd/nerdctl/releases/download/v${version}/nerdctl-full-${version}-linux-${ARCH}.tar.gz"
            local dest="${grandparent_path}/containerd/${arch}"
            mkdir -p "$dest"

            ui_kv "运行时" "containerd (nerdctl-full)"
            ui_kv "版本" "$version"
            ui_kv "目标目录" "$dest"

            STEP_TOTAL=1; STEP_CURRENT=0
            ui_step "下载 nerdctl-full 包"
            ui_download "$url" "$dest" || return 1

            ui_summary_add ok "nerdctl-full-${version}" "已下载"
            ui_summary_render "下载结果"
            success "下载完成，存储路径：${dest}/"
        ;;
    esac
}

# ----- 带进度的下载封装 -----
# 用法: ui_download <url> <目标目录>
ui_download() {
    local url="$1" dest="$2"
    local file="${url##*/}"
    ui_substep "源: $url"
    if command -v wget >/dev/null 2>&1; then
        # wget 原生进度条 (强制显示, 断点续传)
        if wget -T 15 -c --progress=bar:force -P "$dest" "$url" 2>&1; then
            ui_ok "$file"
            return 0
        fi
    elif command -v curl >/dev/null 2>&1; then
        if curl -fL --connect-timeout 15 -C - -o "${dest}/${file}" "$url"; then
            ui_ok "$file"
            return 0
        fi
    else
        error "未找到 wget 或 curl，无法下载"
        return 1
    fi
    ui_fail "下载失败: $file"
    return 1
}

# 定义可用的版本列表
DOCKER_VERSIONS=(
    "20.10.24"
    "24.0.9"
    "26.1.4"
    "27.5.1"
)

CONTAINERD_VERSIONS=(
    "1.7.7"
    "2.0.4"
    "2.1.4"
    "2.2.0"
)

# 根据 Docker 版本选择兼容的 Docker Compose 版本
get_compose_version() {
    local docker_version=$1
    
    # Docker 版本与 Docker Compose 版本兼容性映射
    case "$docker_version" in
        "20.10.24")
            echo "2.20.2"  # Docker Compose v2 稳定版本
        ;;
        "24.0.9")
            echo "2.24.6"  # Docker Compose v2 最新版本
        ;;
        "26.1.4")
            echo "2.29.0"  # Docker Compose v2 最新版本
        ;;
        "27.5.1")
            echo "2.29.0"  # Docker Compose v2 最新版本
        ;;
        *)
            echo "2.29.0"  # 默认使用最新稳定版本
        ;;
    esac
}

# 显示版本选择菜单
show_version_menu() {
    local service=$1
    shift
    local versions=("$@")
    
    # 显示提示信息到 stderr，避免污染返回值
    underline "请选择 ${service} 版本: " >&2
    PS3=$'\033[32m输入版本编号: \033[0m'
    
    select version in "${versions[@]}" "返回主菜单"
    do
        if [[ "$version" == "返回主菜单" ]]; then
            return 1
            elif [[ -n "$version" ]]; then
            # 将版本输出到 stdout，确保没有其他内容污染
            printf "%s" "$version"
            return 0
        else
            error "无效的编号选项, 请重新选择" >&2
        fi
    done
}

choice_runtime
