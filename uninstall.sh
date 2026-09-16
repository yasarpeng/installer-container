#!/bin/bash

set -e

# 初始化函数
parent_path="$(cd "$(dirname "$0")" && pwd)"
source "$parent_path/tools/common.sh"

# 定义容器版本
declare -a docker_versions=("19.03.15" "20.10.24" "24.0.9" "25.0.5" "26.1.4")
declare -a nerdctl_versions=("1.7.6" "1.7.7" "2.0.0" "2.0.2" "2.0.3")

# 卸载环境初始化 (欢迎横幅 + 系统检测)
initialize() {
    ui_banner "容器运行时卸载器" "Container Runtime Uninstaller"

    ui_step "系统环境检查"
    detect_system
    ui_box "检测到的系统信息" \
        "架构:     $ARCH" \
        "发行版:   $DISTRO $VERSION" \
        "包管理器: $PKG_MANAGER"
}


# 卸载容器工具的函数
uninstall_runtime() {
    local choice=$1
    local rootdir=$2
    local version=$3

    ui_step "卸载: $choice"
    ui_kv "工具" "$choice"
    ui_kv "存储路径" "$rootdir"
    [ -n "$version" ] && ui_kv "版本" "$version"

    local rc=0
    case "$choice" in
        docker|d)
            bash "$parent_path/docker/uninstall.sh" "$rootdir" "$version" || rc=$?
        ;;
        nerdctl|n)
            bash "$parent_path/containerd/uninstall.sh" "$rootdir" "$version" || rc=$?
        ;;
    esac

    if [ "$rc" -eq 0 ]; then
        ui_summary_add ok "$choice 卸载" "已移除 $rootdir"
    else
        ui_summary_add fail "$choice 卸载" "退出码 $rc"
    fi

    ui_summary_render "卸载结果摘要"
    return "$rc"
}

# 显示容器工具选项
choice_runtime() {
    ui_step "选择要卸载的容器工具"
    underline "请选择您想要卸载的容器工具 (docker / nerdctl): "
    PS3=$'\033[32m输入选项编号: \033[0m'
    
    select runtime in "${!runtimes[@]}" "退出"
    do
        if [[ "$runtime" == "退出" ]]; then
            exit 0
            elif [[ -n "$runtime" ]]; then
            choice_rootdir "$runtime" "${runtimes[$runtime]}"
            break
        else
            error "无效的编号选项, 请重新选择"
        fi
    done
}

# 选择版本
choice_version() {
    local service="$1"
    local versions
    
    if [[ "$service" == "docker" ]]; then
        versions=("${docker_versions[@]}")
    else
        versions=("${nerdctl_versions[@]}")
    fi
    
    underline "请选择 $service 的版本:"
    PS3=$'\033[32m输入选项编号: \033[0m'
    
    select version in "${versions[@]}" "返回上一步" "退出"; do
        case "$version" in
            "退出") exit 0 ;;
            "返回上一步") choice_runtime ;;
            *) return ;;
        esac
    done
}


choice_rootdir() {
    local service=$1
    local default_dir=$2
    local rootdir="$default_dir"
    
    while true; do
        ui_box "⚠ 危险操作确认" \
            "即将卸载工具:   $service" \
            "数据存储路径:   $rootdir" \
            "" \
            "该操作将删除 $rootdir 下的全部容器数据，" \
            "并卸载 $service 相关服务，且不可恢复，请谨慎操作！"
        underline "请确认是否继续卸载删除: "
        PS3=$'\033[32m输入选项编号: \033[0m'
        
        local options=("继续" "变更路径" "返回上一步")
        
        select opt in "${options[@]}" "退出"
        do
            case "$opt" in
                "继续")
                    # choice_version "$service"
                    uninstall_runtime "$service" "$rootdir" "$version"
                    return
                ;;
                "变更路径")
                    read -p "请输入您要变更的存储路径: " rootdir
                    break
                ;;
                "返回上一步")
                    choice_runtime
                ;;
                "退出")
                    exit 0
                ;;
                *)
                    error "无效的编号选项, 请重新选择"
                ;;
            esac
        done
    done
}

# 定义一个关联数组，容器工具选项 (key 为用户使用的命令行工具名)
declare -A runtimes
runtimes=(
    ["docker"]="/data/laiye/docker"
    ["nerdctl"]="/data/laiye/containerd"
)

# 初始化环境 (横幅 + 系统检测)
initialize

# 选择容器工具
choice_runtime

