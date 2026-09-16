#!/bin/bash

set -e

# Get directory path
parent_path="$(cd "$(dirname "$0")" && pwd)"
grandparent_path="$(cd "$(dirname "${parent_path}")" && pwd)"

source $parent_path/common.sh

# 同时下载 amd64 与 arm64 两个架构，无需探测本机架构。
# 注意两类下载源的架构命名不同:
#   - Docker 官方静态包 / docker-compose : URL 用 x86_64 / aarch64 (与目录名一致)
#   - nerdctl-full (GitHub release)       : 文件名用 amd64 / arm64
# 因此 Docker 分支直接用目录名 $dir，nerdctl 分支用 arch_download_name 转换。
declare -a TARGET_DIRS=("x86_64" "aarch64")
arch_download_name() {
    case "$1" in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
    esac
}

choice_runtime() {
    while true; do
        underline "请选择您想要下载的容器工具 (docker / nerdctl): "
        PS3=$'\033[32m输入选项编号: \033[0m'
        
        local runtimes_options=("docker" "nerdctl")
        
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
                    "nerdctl")
                        local selected_version=$(show_version_menu "nerdctl" "${NERDCTL_VERSIONS[@]}")
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
    ui_banner "安装包下载器" "Package Downloader · amd64 + arm64"

    case "$service" in
        "docker")
            local compose_version
            compose_version=$(get_compose_version "$version")

            ui_kv "运行时" "docker"
            ui_kv "版本" "$version"
            ui_kv "compose 版本" "$compose_version"
            ui_kv "目标架构" "amd64 + arm64"

            local dir url url_rootless_extras url_compose dest
            for dir in "${TARGET_DIRS[@]}"; do
                # Docker 静态包 / rootless-extras / docker-compose 的 URL 均使用
                # x86_64 / aarch64 命名 (与目录名一致), 不是 amd64 / arm64。
                url="https://download.docker.com/linux/static/stable/${dir}/docker-${version}.tgz"
                url_rootless_extras="https://download.docker.com/linux/static/stable/${dir}/docker-rootless-extras-${version}.tgz"
                url_compose="https://github.com/docker/compose/releases/download/v${compose_version}/docker-compose-linux-${dir}"
                dest="${grandparent_path}/docker/${dir}"
                mkdir -p "$dest"

                ui_section "架构 ${dir}"
                STEP_TOTAL=3; STEP_CURRENT=0
                ui_step "下载 Docker 二进制包"
                if ui_download "$url" "$dest"; then
                    ui_summary_add ok "docker-${version} [${dir}]" "已下载"
                else
                    ui_summary_add fail "docker-${version} [${dir}]" "下载失败"
                fi
                ui_step "下载 rootless-extras"
                if ui_download "$url_rootless_extras" "$dest"; then
                    ui_summary_add ok "rootless-extras [${dir}]" "已下载"
                else
                    ui_summary_add fail "rootless-extras [${dir}]" "下载失败"
                fi
                ui_step "下载 docker-compose"
                if ui_download "$url_compose" "$dest"; then
                    mv "${dest}/docker-compose-linux-${dir}" "${dest}/docker-compose"
                    chmod +x "${dest}/docker-compose"
                    ui_summary_add ok "docker-compose ${compose_version} [${dir}]" "已下载"
                else
                    ui_summary_add fail "docker-compose ${compose_version} [${dir}]" "下载失败"
                fi
            done

            ui_summary_render "下载结果"
            success "下载完成，存储路径：${grandparent_path}/docker/{x86_64,aarch64}/"
        ;;
        "nerdctl")
            ui_kv "运行时" "nerdctl (nerdctl-full)"
            ui_kv "版本" "$version"
            ui_kv "目标架构" "amd64 + arm64"

            local dir arch url dest
            for dir in "${TARGET_DIRS[@]}"; do
                arch=$(arch_download_name "$dir")
                url="https://github.com/containerd/nerdctl/releases/download/v${version}/nerdctl-full-${version}-linux-${arch}.tar.gz"
                dest="${grandparent_path}/containerd/${dir}"
                mkdir -p "$dest"

                ui_section "架构 ${dir} (${arch})"
                STEP_TOTAL=1; STEP_CURRENT=0
                ui_step "下载 nerdctl-full 包"
                if ui_download "$url" "$dest"; then
                    ui_summary_add ok "nerdctl-full-${version} [${arch}]" "已下载"
                else
                    ui_summary_add fail "nerdctl-full-${version} [${arch}]" "下载失败"
                fi
            done

            ui_summary_render "下载结果"
            success "下载完成，存储路径：${grandparent_path}/containerd/{x86_64,aarch64}/"
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

NERDCTL_VERSIONS=(
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
