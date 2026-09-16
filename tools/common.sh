#!/bin/bash

set +e
set -o noglob

# 系统兼容性函数
detect_system() {
    # 检测操作系统类型
    OS_TYPE="$(uname -s)"

    # 检测系统架构
    ARCH="$(uname -m)"
    case $ARCH in
        x86_64|amd64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        armv7l|armhf) ARCH="armv7l" ;;
        armv6l) ARCH="armv6l" ;;
        i386|i686) ARCH="386" ;;
        *)
            warn "不常见的系统架构: $ARCH"
            ;;
    esac

    # 针对不同操作系统的检测
    case "$OS_TYPE" in
        Linux)
            # 检测Linux发行版
            if [ -r /etc/os-release ]; then
                . /etc/os-release
                DISTRO="${ID,,}"  # 转换为小写
                VERSION="${VERSION_ID}"
                CODENAME="${VERSION_CODENAME}"
            elif [ -r /etc/redhat-release ]; then
                DISTRO="rhel"
                VERSION="$(grep -oE '[0-9]+\.[0-9]+' /etc/redhat-release | head -1)"
            elif [ -r /etc/debian_version ]; then
                DISTRO="debian"
                VERSION="$(cat /etc/debian_version)"
            else
                DISTRO="unknown"
                VERSION="unknown"
            fi

            # 检测包管理器
            if command -v apt-get >/dev/null 2>&1; then
                PKG_MANAGER="apt"
            elif command -v yum >/dev/null 2>&1; then
                PKG_MANAGER="yum"
            elif command -v dnf >/dev/null 2>&1; then
                PKG_MANAGER="dnf"
            elif command -v zypper >/dev/null 2>&1; then
                PKG_MANAGER="zypper"
            elif command -v pacman >/dev/null 2>&1; then
                PKG_MANAGER="pacman"
            else
                PKG_MANAGER="unknown"
            fi
            ;;
        Darwin)
            DISTRO="macos"
            VERSION="$(sw_vers -productVersion)"
            PKG_MANAGER="brew"
            ;;
        *)
            DISTRO="unknown"
            VERSION="unknown"
            PKG_MANAGER="unknown"
            warn "不支持的操作系统: $OS_TYPE"
            ;;
    esac
}

# 检查必要工具
check_dependencies() {
    local missing_tools=()

    for tool in wget curl tar systemctl; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -gt 0 ]; then
        error "缺少必要工具: ${missing_tools[*]}"
        install_dependencies "${missing_tools[@]}"
    fi
}

# 安装依赖
install_dependencies() {
    local tools=("$@")
    note "正在安装缺少的工具: ${tools[*]}"

    case "$PKG_MANAGER" in
        apt)
            apt-get update
            apt-get install -y "${tools[@]}"
            ;;
        yum|dnf)
            $PKG_MANAGER install -y "${tools[@]}"
            ;;
        zypper)
            zypper install -y "${tools[@]}"
            ;;
        pacman)
            pacman -S --noconfirm "${tools[@]}"
            ;;
    esac
}

# 服务管理函数
start_service() {
    local service="$1"
    systemctl daemon-reload
    systemctl enable "$service"
    systemctl start "$service"

    # 检查服务状态
    if systemctl is-active --quiet "$service"; then
        success "$service 服务启动成功"
    else
        error "$service 服务启动失败"
        return 1
    fi
}

stop_service() {
    local service="$1"
    if systemctl is-active --quiet "$service"; then
        systemctl stop "$service"
    fi
    if systemctl is-enabled --quiet "$service"; then
        systemctl disable "$service"
    fi
}

# 网络连接测试
test_network() {
    local test_urls=("https://www.baidu.com" "https://www.google.com")
    local connected=false

    for url in "${test_urls[@]}"; do
        if curl -s --connect-timeout 5 "$url" >/dev/null 2>&1; then
            connected=true
            break
        fi
    done

    if [ "$connected" = false ]; then
        warn "网络连接测试失败，请检查网络设置"
        return 1
    fi

    return 0
}

#
# ============================================================================
#  可视化 / UI 库 (Visualization Library)
# ============================================================================
#

# ----- 颜色与样式检测 -----
# 允许通过 NO_COLOR=1 强制禁用颜色；否则在支持颜色的终端上启用。
if [ -z "${NO_COLOR:-}" ] && { [ -t 1 ] || [ "${FORCE_COLOR:-0}" = "1" ]; } && command -v tput >/dev/null 2>&1; then
    _ncolors=$(tput colors 2>/dev/null || echo 0)
    bold=$(tput bold 2>/dev/null || printf '')
    underline=$(tput smul 2>/dev/null || printf '')
    reset=$(tput sgr0 2>/dev/null || printf '')
    if [ "${_ncolors:-0}" -ge 8 ]; then
        red=$(tput setaf 1 2>/dev/null || printf '')
        green=$(tput setaf 2 2>/dev/null || printf '')
        tan=$(tput setaf 3 2>/dev/null || printf '')
        blue=$(tput setaf 4 2>/dev/null || printf '')
        magenta=$(tput setaf 5 2>/dev/null || printf '')
        cyan=$(tput setaf 6 2>/dev/null || printf '')
        white=$(tput setaf 7 2>/dev/null || printf '')
        grey=$(tput setaf 8 2>/dev/null || printf '')
    else
        red=""; green=""; tan=""; blue=""; magenta=""; cyan=""; white=""; grey=""
    fi
else
    bold=""; underline=""; reset=""
    red=""; green=""; tan=""; blue=""; magenta=""; cyan=""; white=""; grey=""
fi

# ----- 状态符号 (在 UTF-8 终端使用图形符号，否则退回 ASCII) -----
if printf '%s' "${LANG:-}${LC_ALL:-}${LC_CTYPE:-}" | grep -qi 'utf-\?8'; then
    SYM_OK="✔"; SYM_ERR="✖"; SYM_WARN="⚠"; SYM_INFO="➜"; SYM_STEP="▶"
    SYM_DOT="•"; SYM_ARROW="➜"; BAR_FULL="█"; BAR_EMPTY="░"
else
    SYM_OK="[OK]"; SYM_ERR="[!!]"; SYM_WARN="[**]"; SYM_INFO="->"; SYM_STEP=">"
    SYM_DOT="*"; SYM_ARROW="->"; BAR_FULL="#"; BAR_EMPTY="-"
fi

# ----- 终端宽度 -----
ui_width() {
    local w
    w=$(tput cols 2>/dev/null || echo 80)
    [ "${w:-0}" -ge 20 ] 2>/dev/null || w=80
    [ "$w" -gt 100 ] && w=100
    echo "$w"
}

# ----- 重复字符 n 次 -----
ui_repeat() {
    local ch="$1" n="$2" out=""
    while [ "$n" -gt 0 ]; do out="${out}${ch}"; n=$((n - 1)); done
    printf '%s' "$out"
}

#
# ============================================================================
#  Headers & Logging (基础日志，向后兼容原有函数名)
# ============================================================================
#
underline() { printf "${underline}${bold}%s${reset}\n" "$@"; }
h1()    { printf "\n${bold}${blue}%s${reset}\n" "$@"; }
h2()    { printf "\n${bold}${white}%s${reset}\n" "$@"; }
debug() { printf "${grey}%s${reset}\n" "$@"; }
info()  { printf "${white}${SYM_INFO} %s${reset}\n" "$@"; }
success() { printf "${green}${SYM_OK} %s${reset}\n" "$@"; }
error() { printf "${red}${bold}${SYM_ERR} %s${reset}\n" "$@" >&2; }
warn()  { printf "${tan}${SYM_WARN} %s${reset}\n" "$@"; }
bold()  { printf "${bold}%s${reset}\n" "$@"; }
note()  { printf "${blue}${bold}${SYM_INFO} Note:${reset} ${blue}%s${reset}\n" "$@"; }

#
# ============================================================================
#  高级可视化组件 (Banners, Boxes, Progress, Spinner, Steps, Summary)
# ============================================================================
#

# ----- 顶部横幅 (ASCII art banner) -----
ui_banner() {
    local title="${1:-Container Runtime Installer}"
    local subtitle="${2:-}"
    local width; width=$(ui_width)
    local line; line=$(ui_repeat "═" $((width - 2)))
    printf "\n${cyan}${bold}╔%s╗${reset}\n" "$line"
    ui_center_line "${title}" "$width" "${cyan}${bold}"
    [ -n "$subtitle" ] && ui_center_line "${subtitle}" "$width" "${cyan}"
    printf "${cyan}${bold}╚%s╝${reset}\n\n" "$line"
}

# 居中输出一行 (在 ║ ... ║ 框内)
ui_center_line() {
    local text="$1" width="$2" color="${3:-}"
    local inner=$((width - 2))
    local len=${#text}
    [ "$len" -gt "$inner" ] && { text="${text:0:$inner}"; len=$inner; }
    local pad=$(( (inner - len) / 2 ))
    local rpad=$(( inner - len - pad ))
    printf "${cyan}${bold}║${reset}%s${color}%s${reset}%s${cyan}${bold}║${reset}\n" \
        "$(ui_repeat ' ' "$pad")" "$text" "$(ui_repeat ' ' "$rpad")"
}

# ----- 信息框 (在框内输出若干行文本) -----
ui_box() {
    local title="$1"; shift
    local width; width=$(ui_width)
    local inner=$((width - 4))
    local line; line=$(ui_repeat "─" $((width - 2)))
    printf "${blue}┌%s┐${reset}\n" "$line"
    if [ -n "$title" ]; then
        printf "${blue}│${reset} ${bold}%-*s${reset} ${blue}│${reset}\n" "$inner" "$title"
        printf "${blue}├%s┤${reset}\n" "$line"
    fi
    local l
    for l in "$@"; do
        printf "${blue}│${reset} %-*s ${blue}│${reset}\n" "$inner" "$l"
    done
    printf "${blue}└%s┘${reset}\n" "$line"
}

# ----- 分节标题 (带编号的章节) -----
ui_section() {
    local title="$1"
    local width; width=$(ui_width)
    local line; line=$(ui_repeat "─" $((width - 2)))
    printf "\n${magenta}${bold}%s${reset}\n" "$title"
    printf "${magenta}%s${reset}\n" "$line"
}

# ----- 步骤跟踪器 (Step Tracker) -----
# 使用: STEP_TOTAL=5; STEP_CURRENT=0; 然后调用 ui_step "描述"
STEP_TOTAL="${STEP_TOTAL:-0}"
STEP_CURRENT="${STEP_CURRENT:-0}"

ui_step() {
    local desc="$1"
    STEP_CURRENT=$((STEP_CURRENT + 1))
    if [ "${STEP_TOTAL:-0}" -gt 0 ]; then
        printf "\n${cyan}${bold}[%d/%d]${reset} ${white}${bold}${SYM_STEP} %s${reset}\n" \
            "$STEP_CURRENT" "$STEP_TOTAL" "$desc"
    else
        printf "\n${cyan}${bold}${SYM_STEP}${reset} ${white}${bold}%s${reset}\n" "$desc"
    fi
}

ui_substep() { printf "  ${grey}${SYM_DOT}${reset} %s\n" "$@"; }
ui_ok()      { printf "  ${green}${SYM_OK}${reset} %s\n" "$@"; }
ui_fail()    { printf "  ${red}${SYM_ERR}${reset} %s\n" "$@" >&2; }

# ----- 进度条 (Progress Bar) -----
# 用法: ui_progress <current> <total> [label]
ui_progress() {
    local current="$1" total="$2" label="${3:-}"
    [ "${total:-0}" -le 0 ] && total=1
    local width=40
    local pct=$(( current * 100 / total ))
    [ "$pct" -gt 100 ] && pct=100
    local filled=$(( pct * width / 100 ))
    local empty=$(( width - filled ))
    printf "\r  ${cyan}[%s%s${cyan}]${reset} ${bold}%3d%%${reset} %s" \
        "$(ui_repeat "$BAR_FULL" "$filled")" \
        "${grey}$(ui_repeat "$BAR_EMPTY" "$empty")${reset}${cyan}" \
        "$pct" "$label"
    [ "$pct" -ge 100 ] && printf "\n"
}

# ----- 旋转器 (Spinner) 包裹一个后台命令 -----
# 用法: ui_spinner "描述" command args...
ui_spinner() {
    local msg="$1"; shift
    if [ ! -t 1 ]; then
        # 非交互终端: 直接执行，不显示动画
        printf "  ${SYM_INFO} %s ...\n" "$msg"
        "$@"
        return $?
    fi
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local tmp_log; tmp_log=$(mktemp 2>/dev/null || echo "/tmp/ui_spin.$$")
    "$@" >"$tmp_log" 2>&1 &
    local pid=$!
    local i=0
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i + 1) % ${#spin} ))
        printf "\r  ${cyan}%s${reset} %s" "${spin:$i:1}" "$msg"
        sleep 0.1
    done
    wait "$pid"; local rc=$?
    if [ "$rc" -eq 0 ]; then
        printf "\r  ${green}${SYM_OK}${reset} %s\n" "$msg"
    else
        printf "\r  ${red}${SYM_ERR}${reset} %s\n" "$msg"
        sed 's/^/      /' "$tmp_log" >&2
    fi
    rm -f "$tmp_log" 2>/dev/null
    return $rc
}

# ----- 键值对表格 (用于摘要展示) -----
ui_kv() {
    local key="$1" value="$2"
    printf "  ${bold}%-22s${reset} ${green}%s${reset}\n" "${key}:" "$value"
}

#
# ============================================================================
#  部署摘要仪表盘 (Deployment Summary Dashboard)
# ============================================================================
#
# 通过 ui_summary_add "状态" "项目" "详情" 累积条目, 最后 ui_summary_render 输出。
SUMMARY_ITEMS=()

ui_summary_reset() { SUMMARY_ITEMS=(); }

# status: ok | warn | fail | info
ui_summary_add() {
    SUMMARY_ITEMS+=("$1|$2|$3")
}

ui_summary_render() {
    local title="${1:-部署结果摘要}"
    local width; width=$(ui_width)
    local line; line=$(ui_repeat "═" $((width - 2)))
    printf "\n${cyan}${bold}╔%s╗${reset}\n" "$line"
    ui_center_line "$title" "$width" "${cyan}${bold}"
    printf "${cyan}${bold}╚%s╝${reset}\n" "$line"

    local entry status item detail sym color
    local ok=0 warncnt=0 failcnt=0
    for entry in "${SUMMARY_ITEMS[@]}"; do
        status="${entry%%|*}"
        item="${entry#*|}"; detail="${item#*|}"; item="${item%%|*}"
        case "$status" in
            ok)   sym="$SYM_OK";   color="$green"; ok=$((ok+1)) ;;
            warn) sym="$SYM_WARN"; color="$tan";  warncnt=$((warncnt+1)) ;;
            fail) sym="$SYM_ERR";  color="$red";  failcnt=$((failcnt+1)) ;;
            *)    sym="$SYM_INFO"; color="$blue" ;;
        esac
        printf "  ${color}%s${reset} ${bold}%-20s${reset} ${grey}%s${reset}\n" \
            "$sym" "$item" "$detail"
    done
    printf "${cyan}%s${reset}\n" "$(ui_repeat "─" $((width - 2)))"
    printf "  ${green}${SYM_OK} %d 成功${reset}   ${tan}${SYM_WARN} %d 警告${reset}   ${red}${SYM_ERR} %d 失败${reset}\n\n" \
        "$ok" "$warncnt" "$failcnt"
}

#
# ============================================================================
#  版本检查工具 (Version Checks)
# ============================================================================
#
check_docker() {
    if ! docker --version >/dev/null 2>&1; then
        note "需要先安装 docker(19.06.0+) 后再运行此脚本。"
        return 1
    fi
    if [[ $(docker --version) =~ (([0-9]+)\.([0-9]+)([\.0-9]*)) ]]; then
        docker_version=${BASH_REMATCH[1]}
        docker_version_part1=${BASH_REMATCH[2]}
        docker_version_part2=${BASH_REMATCH[3]}
        note "docker 版本: $docker_version"
        if [ "$docker_version_part1" -lt 19 ] || { [ "$docker_version_part1" -eq 19 ] && [ "$docker_version_part2" -lt 6 ]; }; then
            error "需要将 docker 升级到 19.06.0+。"
            return 1
        fi
    else
        error "无法解析 docker 版本。"
        return 1
    fi
}

check_dockercompose() {
    if ! docker-compose --version >/dev/null 2>&1; then
        error "需要先自行安装 docker-compose(1.18.0+) 后再运行此脚本。"
        return 1
    fi
    if [[ $(docker-compose --version) =~ (([0-9]+)\.([0-9]+)([\.0-9]*)) ]]; then
        docker_compose_version=${BASH_REMATCH[1]}
        docker_compose_version_part1=${BASH_REMATCH[2]}
        docker_compose_version_part2=${BASH_REMATCH[3]}
        note "docker-compose 版本: $docker_compose_version"
        if [ "$docker_compose_version_part1" -lt 1 ] || { [ "$docker_compose_version_part1" -eq 1 ] && [ "$docker_compose_version_part2" -lt 18 ]; }; then
            error "需要将 docker-compose 升级到 1.18.0+。"
            return 1
        fi
    else
        error "无法解析 docker-compose 版本。"
        return 1
    fi
}