# 容器运行时安装器

一个兼容多种 Linux 发行版的容器运行时离线安装工具，支持 **Docker** 和 **nerdctl** 两种方案的自动化安装。

> **两种方案的区别**：Docker 与 nerdctl 底层都依赖 containerd，区别在于用户实际使用的命令行工具：
> 一种使用 `docker` / `docker-compose`，另一种使用 `nerdctl`（基于 nerdctl-full 包，内含 containerd + nerdctl + BuildKit）。

## 目录

- [主要特性](#-主要特性)
- [系统要求](#-系统要求)
- [快速开始](#-快速开始)
- [支持的版本](#-支持的版本)
- [功能说明](#️-功能说明)
- [用户权限管理](#-用户权限管理)
- [卸载](#-卸载)
- [故障排除](#-故障排除)
- [项目结构](#-项目结构)

## 🚀 主要特性

- **多发行版支持**：Ubuntu、Debian、CentOS、RHEL、Fedora、openSUSE/SLES 等
- **多架构支持**：x86_64/amd64、aarch64/arm64（完全支持），armv7l、i386（有限支持）
- **离线安装**：预下载安装包后可在无外网环境安装
- **双架构下载**：下载工具一次性获取 amd64 + arm64 两套安装包
- **智能检测**：自动检测系统架构、发行版与包管理器
- **断点续传下载**：基于 `wget -c` / `curl -C -`，网络中断后可续传
- **服务管理**：完整的 systemd 服务配置与开机自启
- **可视化交互**：带横幅、步骤跟踪与结果摘要的终端界面
- **兼容性预检**：安装前可运行系统兼容性检查

## 📋 系统要求

### 支持的操作系统

| 发行版 | 最低版本 |
|--------|----------|
| Ubuntu | 18.04+ |
| Debian | 9+ |
| CentOS | 7+ |
| RHEL | 7+ |
| Fedora | 30+ |
| openSUSE Leap | 15+ |
| SUSE Linux Enterprise Server | 12+ |

### 支持的系统架构

| 架构 | 支持程度 |
|------|----------|
| x86_64 / amd64 | ✅ 完全支持 |
| aarch64 / arm64 | ✅ 完全支持 |
| armv7l / armhf | ⚠️ 有限支持 |
| i386 | ⚠️ 有限支持 |

### 必要条件

- `wget` 或 `curl`
- `tar`
- `systemctl`（仅支持 systemd 系统）
- root 权限或 sudo 权限

## 🔧 快速开始

### 1. 兼容性检查（推荐）

```bash
bash tools/compatibility_test.sh
```

### 2. 下载安装包（离线安装前置步骤）

下载工具会一次性下载 **amd64 与 arm64** 两个架构的安装包，你只需选择工具与版本：

```bash
bash tools/download_package.sh
```

包会保存到对应目录（如 `docker/x86_64/`、`docker/aarch64/`、`containerd/x86_64/`、`containerd/aarch64/`），安装脚本会自动按当前主机架构读取。

### 3. 交互式安装（推荐）

```bash
# 运行主安装脚本：完成系统初始化 → 选择工具/路径 → 安装 → 用户授权
bash install.sh
```

### 4. 直接安装指定版本

```bash
# 安装 Docker（参数：数据存储路径 版本）
bash docker/install.sh /var/lib/docker 24.0.9

# 安装 nerdctl（参数：数据存储路径 版本）
bash containerd/install.sh /data/containerd 2.0.4

# 安装后为用户授权
sudo bash tools/authorize_user.sh
```

### 5. 用户权限管理（推荐）

```bash
# 图形化用户管理工具
bash tools/user_manager.sh

# 或直接命令行授权
sudo bash tools/authorize_user.sh -u username
```

## 📦 支持的版本

安装菜单（`install.sh`）与下载工具（`download_package.sh`）内置的版本列表如下。实际可选版本以脚本内的数组为准，可自行编辑增删。

### Docker

| 安装菜单 | 下载工具 |
|----------|----------|
| 19.03.15 | — |
| 20.10.24（默认）| 20.10.24 |
| 24.0.9 | 24.0.9 |
| 25.0.5 | — |
| 26.1.4 | 26.1.4 |
| — | 27.5.1 |

### nerdctl（nerdctl-full 包）

| 安装菜单 | 下载工具 |
|----------|----------|
| 1.7.6（默认）| — |
| 1.7.7 | 1.7.7 |
| 2.0.0 / 2.0.2 / 2.0.3 | 2.0.4 |
| — | 2.1.4 / 2.2.0 |

> 提示：如需下载并安装同一版本，请确保 `install.sh` 与 `download_package.sh` 中的版本一致。

## 🛠️ 功能说明

### 系统初始化

主安装脚本会自动执行以下系统初始化（对应 `tools/` 下的脚本）：

- 配置系统资源限制（`config_limits.sh`）
- 禁用 swap（`disable_swap.sh`）
- 启用 br_netfilter 模块（`enable_br_netfilter.sh`）
- 启用 IPv4 转发（`enable_ipv4_forward.sh`）
- 配置 IPVS（`enable_ipvs.sh`）
- 禁用防火墙（`disable_firewall.sh`，可选）

> 以上脚本均需 root 权限；执行失败会被标记为"已跳过"而不会中断安装。

### Docker 安装特性

- 从 Docker 官方静态包源下载
- 自动生成 `/etc/docker/daemon.json`（可配置 data-root、cgroup driver、日志与地址池）
- 部署 `docker.service` / `containerd.service` / `docker.socket` 三个 systemd 单元
- 自动安装匹配版本的 `docker-compose`
- 创建 `docker` 用户组并配置权限

### nerdctl 安装特性

- 使用 nerdctl-full 包（包含 containerd + nerdctl + BuildKit）
- 从 GitHub Releases 下载，支持多架构
- 自动生成 `/etc/containerd/config.toml`（可配置 root 路径、SystemdCgroup、sandbox 镜像）
- containerd 服务自动启动，并在存在时启动 buildkit
- 普通用户免 sudo 请使用 rootless 方案：`containerd-rootless-setuptool.sh install`

## 👥 用户权限管理

### 一键授权普通用户

安装完成后可为普通用户授权，无需 sudo 即可管理容器：

```bash
# 为当前用户授权
sudo bash tools/authorize_user.sh

# 为指定用户授权
sudo bash tools/authorize_user.sh -u username

# 为所有普通用户授权
sudo bash tools/authorize_user.sh -a

# 撤销用户权限
sudo bash tools/authorize_user.sh -u username -r

# 列出已授权用户
sudo bash tools/authorize_user.sh -l
```

### 图形化用户管理工具

```bash
bash tools/user_manager.sh
```

### 授权后能做什么

- ✅ 无需 sudo 使用 `docker` 命令
- ✅ 管理 Docker 服务（`start` / `stop` / `restart`）
- ✅ 使用 `docker-compose`
- ✅ 使用 nerdctl / 管理 containerd
- ✅ 查看服务状态和日志

### 环境配置

授权后会自动创建用户环境配置文件：

- Docker 命令别名（`dps`、`dimg`、`drm` 等）
- containerd / nerdctl 别名（`nps`、`nimg` 等）
- 环境变量优化与便捷查询函数

> **注意**：授权后需要重新登录，或执行 `newgrp docker` 使权限生效。

## 🔄 卸载

```bash
# 卸载 Docker
bash docker/uninstall.sh

# 卸载 nerdctl
bash containerd/uninstall.sh

# 交互式卸载（可选择工具与数据路径）
bash uninstall.sh

# 撤销用户权限
sudo bash tools/authorize_user.sh -u username -r
```

> ⚠️ 卸载会删除对应数据目录下的全部容器数据，操作不可恢复，请先备份重要数据。

## 🐛 故障排除

**1. 权限不足**

```bash
sudo bash install.sh
```

**2. 无外网环境 / 下载失败**

先在有网环境执行 `bash tools/download_package.sh` 下载安装包，或手动放入对应目录：

```bash
mkdir -p docker/x86_64 containerd/x86_64
# 将下载好的包放入对应架构目录
```

**3. systemctl 不可用**

本工具仅支持 systemd 系统，请确认系统使用 systemd。

**4. 依赖工具缺失**

```bash
# Ubuntu/Debian
sudo apt-get install -y wget curl tar

# CentOS/RHEL/Fedora
sudo yum install -y wget curl tar
```

**5. 用户权限未生效**

```bash
# 检查用户是否在 docker 组
groups "$USER" | grep docker

# 重新登录或切换组
newgrp docker

# 手动授权
sudo bash tools/authorize_user.sh -u "$USER"
```

**6. sudo 权限不足**

```bash
sudo -v          # 确认当前用户有 sudo 权限
sudo visudo      # 检查/编辑 sudo 配置
```

### 日志查看

```bash
# 服务状态
systemctl status docker
systemctl status containerd

# 实时日志
journalctl -u docker -f
journalctl -u containerd -f
```

## 📁 项目结构

```
├── install.sh                  # 主安装脚本（系统初始化 + 交互式安装）
├── uninstall.sh                # 主卸载脚本（交互式）
├── docker/                     # Docker 方案
│   ├── install.sh              # Docker 安装脚本
│   ├── uninstall.sh            # Docker 卸载脚本
│   ├── daemon.json             # daemon 配置模板
│   ├── docker.service          # systemd 服务单元
│   ├── docker.socket           # systemd socket 单元
│   └── containerd.service      # Docker 依赖的 containerd 服务单元
├── containerd/                 # nerdctl 方案
│   ├── install.sh              # nerdctl 安装脚本
│   └── uninstall.sh            # nerdctl 卸载脚本
└── tools/                      # 工具与系统配置脚本
    ├── common.sh               # 通用函数库（日志/可视化/系统检测）
    ├── compatibility_test.sh   # 兼容性测试
    ├── download_package.sh     # 下载安装包（双架构）
    ├── authorize_user.sh       # 用户授权脚本
    ├── user_manager.sh         # 图形化用户管理工具
    ├── config_limits.sh        # 配置系统资源限制
    ├── disable_swap.sh         # 禁用 swap
    ├── enable_br_netfilter.sh  # 启用 br_netfilter
    ├── enable_ipv4_forward.sh  # 启用 IPv4 转发
    ├── enable_ipvs.sh          # 配置 IPVS
    ├── kernel.sh               # 内核 sysctl 参数
    ├── change_sysctl.sh        # 系统调优 sysctl 参数
    ├── disable_firewall.sh     # 禁用防火墙
    ├── firewall.sh             # 放行 k8s 相关端口（需 firewalld）
    └── limit_network.sh        # ⚠️ 限制外网访问（危险，会插入 DROP 规则）
```

> ⚠️ `tools/limit_network.sh` 会插入默认 DROP 的 iptables 规则以模拟无外网环境，可能导致 SSH 断连甚至主机失联，请仅在有带外/本地控制台的情况下使用（脚本已内置确认提示，`-y` 可跳过）。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进本项目。

## 📄 许可证

MIT License
