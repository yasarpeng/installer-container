#!/bin/bash

set -e

# 初始化函数
parent_path="$(cd "$(dirname "$0")" && pwd)"
source "$parent_path/tools/common.sh"

initialize() {
    # 欢迎横幅
    ui_banner "容器运行时安装器" "Container Runtime Installer"

    # 系统检测和初始化
    STEP_TOTAL=3
    STEP_CURRENT=0

    ui_step "系统兼容性检查"
    detect_system
    ui_box "检测到的系统信息" \
        "架构:     $ARCH" \
        "发行版:   $DISTRO $VERSION" \
        "包管理器: $PKG_MANAGER"
    ui_summary_add ok "系统检测" "$DISTRO $VERSION ($ARCH)"

    # 检查必要工具
    # check_dependencies

    # 测试网络连接
    # test_network || warn "网络连接可能存在问题，继续安装但可能需要手动下载"

    # 执行系统初始化脚本
    ui_step "系统初始化配置"
    local init_scripts=(
        "config_limits.sh:配置系统资源限制"
        "disable_swap.sh:禁用 swap"
        "enable_br_netfilter.sh:启用 br_netfilter 模块"
        "enable_ipv4_forward.sh:启用 IPv4 转发"
        "enable_ipvs.sh:启用 IPVS"
        "disable_firewall.sh:禁用防火墙"
    )
    local total=${#init_scripts[@]}
    local idx=0 ok_count=0
    local entry script label
    for entry in "${init_scripts[@]}"; do
        script="${entry%%:*}"
        label="${entry#*:}"
        idx=$((idx + 1))
        if bash "$parent_path/tools/$script" >/dev/null 2>&1; then
            ui_ok "$label"
            ok_count=$((ok_count + 1))
        else
            ui_fail "$label (已跳过)"
        fi
        ui_progress "$idx" "$total" "系统初始化"
    done
    ui_summary_add ok "系统初始化" "$ok_count/$total 项配置完成"
}

# 安装容器运行时的函数
install_runtime() {
    local choice="$1"
    local rootdir="$2"
    local version="$3"

    ui_step "部署容器客户端: $choice"
    ui_kv "工具" "$choice"
    ui_kv "存储路径" "$rootdir"
    [ -n "$version" ] && ui_kv "版本" "$version"

    local rc=0
    case "$choice" in
        docker)
            bash "$parent_path/docker/install.sh" "$rootdir" "$version" || rc=$?
        ;;
        nerdctl)
            bash "$parent_path/containerd/install.sh" "$rootdir" "$version" || rc=$?
        ;;
    esac

    if [ "$rc" -eq 0 ]; then
        ui_summary_add ok "$choice 部署" "存储路径 $rootdir"
    else
        ui_summary_add fail "$choice 部署" "退出码 $rc"
    fi

    # 渲染部署结果仪表盘
    ui_summary_render "部署结果摘要"

    if [ "$rc" -eq 0 ]; then
        ui_box "后续操作" \
            "如需授权普通用户免 sudo 使用容器，请执行:" \
            "  sudo bash $parent_path/tools/authorize_user.sh"
    fi
    return "$rc"
}

# 安装后授权
post_install_authorization() {
    local runtime="$1"
    
    echo
    h2 "用户权限配置"
    
    PS3=$'\033[32m请选择用户权限配置方式: \033[0m'
    local auth_options=(
        "授权当前用户"
        "授权指定用户"
        "授权所有普通用户"
        "跳过用户授权"
        "列出已授权用户"
    )
    
    select auth_choice in "${auth_options[@]}"; do
        case "$auth_choice" in
            "授权当前用户")
                local current_user="${SUDO_USER:-$(logname 2>/dev/null)}"
                if [ -n "$current_user" ]; then
                    note "为当前用户 $current_user 授权..."
                    sudo bash "$parent_path/tools/authorize_user.sh" -u "$current_user"
                else
                    error "无法确定当前用户"
                fi
                break
            ;;
            "授权指定用户")
                read -r -p "请输入要授权的用户名: " target_user
                if [ -n "$target_user" ]; then
                    sudo bash "$parent_path/tools/authorize_user.sh" -u "$target_user"
                else
                    error "用户名不能为空"
                fi
                break
            ;;
            "授权所有普通用户")
                sudo bash "$parent_path/tools/authorize_user.sh" -a
                break
            ;;
            "跳过用户授权")
                note "跳过用户授权，您可以稍后手动运行:"
                note "  sudo bash tools/authorize_user.sh"
                break
            ;;
            "列出已授权用户")
                sudo bash "$parent_path/tools/authorize_user.sh" -l
                echo
                note "请重新选择操作:"
            ;;
            *)
                echo "无效的选项，请重新选择！"
            ;;
        esac
    done
}

# 定义容器运行时选项 (key 为用户使用的命令行工具名)
declare -A runtimes=(
    ["docker"]="/data/laiye/docker"
    ["nerdctl"]="/data/laiye/containerd"
)

# 定义容器版本
declare -a docker_versions=("19.03.15" "20.10.24" "24.0.9" "25.0.5" "26.1.4")
declare -a nerdctl_versions=("1.7.6" "1.7.7" "2.0.0" "2.0.2" "2.0.3")

# 选择容器运行时
choice_runtime() {
    underline "请选择您想要安装的容器工具 (docker / nerdctl):"
    PS3=$'\033[32m输入选项编号: \033[0m'
    
    select runtime in "${!runtimes[@]}" "退出"; do
        if [[ "$runtime" == "退出" ]]; then
            exit 0
            elif [[ -n "$runtime" ]]; then
            choice_rootdir "$runtime" "${runtimes[$runtime]}"
            break
        else
            echo "无效的选项，请重新选择！"
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

# 选择存储路径
choice_rootdir() {
    local service="$1"
    local rootdir="$2"
    
    while true; do
        note "当前选择的工具: $service"
        note "默认存储路径: $rootdir"
        underline "请确认是否继续安装: "
        
        PS3=$'\033[32m输入选项编号: \033[0m'
        local options=("继续" "变更路径" "返回上一步" "退出")
        
        select opt in "${options[@]}"; do
            case "$opt" in
                "继续")
                    # choice_version "$service" 是否开启版本选择
                    install_runtime "$service" "$rootdir" "$version"
                    return
                ;;
                "变更路径")
                    read -r -p "请输入新的存储路径: " rootdir
                    break
                ;;
                "返回上一步") choice_runtime ;;
                "退出") exit 0 ;;
                *) echo "无效的选项，请重新选择！" ;;
            esac
        done
    done
}

# 初始化环境
initialize

# 选择容器运行时
choice_runtime
