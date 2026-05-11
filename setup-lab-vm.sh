#!/usr/bin/env bash
# setup-lab-vm.sh — 一键部署脚本
# 将全新的 Kali VM 变成完整的 cyber-practice 教学环境
#
# 用法:
#   sudo ./setup-lab-vm.sh                 # 完整部署（首次自动从 GitHub 克隆）
#   sudo ./setup-lab-vm.sh --skip-tools     # 跳过工具安装（已装过）
#   sudo ./setup-lab-vm.sh --student-image  # 部署完直接制作学生镜像
#
# 首次运行时会自动从 GitHub 克隆所有文件，无需手动 clone
#
# 此脚本会:
#   1. 安装所有需要的系统工具和 Kali 安全工具
#   2. 安装 Docker 并配置用户权限
#   3. 拉取所有 Docker 镜像（nginx, juice-shop, webgoat 等）
#   4. 构建所有自定义 Docker 镜像
#   5. 逐一启动每个实验环境验证
#   6. （可选）清理并准备学生分发镜像

set -euo pipefail

REPO_URL="https://github.com/ZolaNUAA/cyber-practice.git"
KALI_MIRROR="${KALI_MIRROR:-http://mirrors.ustc.edu.cn/kali}"
DOCKER_APT_MIRROR="${DOCKER_APT_MIRROR:-https://mirrors.aliyun.com/docker-ce/linux/debian}"
DOCKER_DEBIAN_CODENAME="${DOCKER_DEBIAN_CODENAME:-bookworm}"
CHINA_MIRRORS="${CHINA_MIRRORS:-true}"
SCRIPT_PATH="${BASH_SOURCE[0]}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
ACTUAL_USER="${SUDO_USER:-${USER:-root}}"
ACTUAL_HOME=$(eval echo "~$ACTUAL_USER")

# ── 颜色 ───────────────────────────────────────────
RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'
BLUE='\033[34m'; CYAN='\033[36m'; BOLD='\033[1m'; RESET='\033[0m'
step()  { echo -e "\n${BOLD}${CYAN}[$1/$TOTAL_STEPS]${RESET} ${BOLD}$2${RESET}"; }
ok()    { echo -e "  ${GREEN}✅${RESET} $1"; }
fail()  { echo -e "  ${RED}❌${RESET} $1"; }
warn()  { echo -e "  ${YELLOW}⚠️${RESET}  $1"; }
info()  { echo -e "  ${BLUE}ℹ${RESET}  $1"; }

TOTAL_STEPS=8
ERRORS=()

# ── 参数解析 ───────────────────────────────────────
TEACHER_MODE=false
SKIP_TOOLS=false
for arg in "$@"; do
    case "$arg" in
        --teacher-mode) TEACHER_MODE=true ;;
        --skip-tools) SKIP_TOOLS=true ;;
        --student-image) TEACHER_MODE=false ;; # Backward-compatible no-op; student image is now the default.
        --no-china-mirrors) CHINA_MIRRORS=false ;;
        --help|-h)
            echo "用法: sudo ./setup-lab-vm.sh [选项]"
            echo "  --teacher-mode        保留教师模式（不加密实验、不清理教师文件）"
            echo "  --skip-tools          跳过工具安装（已装过）"
            echo "  --student-image       兼容旧参数；当前默认就是学生镜像模式"
            echo "  --no-china-mirrors    不切换国内 apt/Docker 加速源"
            echo
            echo "默认行为：学生模式部署 → 克隆到 ~/cyber-practice 并自动配置"
            echo
            echo "环境变量:"
            echo "  KALI_MIRROR            Kali apt 源，默认: $KALI_MIRROR"
            echo "  DOCKER_APT_MIRROR      Docker CE apt 源，默认: $DOCKER_APT_MIRROR"
            echo "  DOCKER_DEBIAN_CODENAME Docker CE Debian 发行版名，默认: $DOCKER_DEBIAN_CODENAME"
            exit 0
            ;;
        *)
            echo "未知参数: $arg"
            echo "运行 --help 查看用法"
            exit 1
            ;;
    esac
done

# ── 权限检查 ───────────────────────────────────────
if [[ "$(id -u)" -ne 0 ]]; then
    echo -e "${RED}此脚本需要 root 权限运行。${RESET}"
    echo "请使用: sudo ./setup-lab-vm.sh"
    exit 1
fi

configure_china_mirrors() {
    if ! $CHINA_MIRRORS; then
        info "国内加速源: 已关闭"
        return 0
    fi

    info "配置 Kali 国内 apt 源: $KALI_MIRROR"
    if [[ -f /etc/apt/sources.list && ! -f /etc/apt/sources.list.cyber-practice.bak ]]; then
        cp /etc/apt/sources.list /etc/apt/sources.list.cyber-practice.bak
    fi

    cat > /etc/apt/sources.list <<APT
deb $KALI_MIRROR kali-rolling main contrib non-free non-free-firmware
APT

    mkdir -p /etc/apt/apt.conf.d
    cat > /etc/apt/apt.conf.d/99cyber-practice-retries <<'APTCONF'
Acquire::Retries "3";
Acquire::http::Timeout "20";
Acquire::https::Timeout "20";
APTCONF
    ok "apt 源已切换，原文件备份为 /etc/apt/sources.list.cyber-practice.bak"
}

install_git_if_missing() {
    command -v git &>/dev/null && return 0

    info "git 未安装，先补装 git 以便自动克隆项目..."
    apt-get update -qq
    apt-get install -y -qq git ca-certificates curl
    ok "git 已安装"
}

configure_docker_registry_mirrors() {
    $CHINA_MIRRORS || return 0

    info "配置 Docker Hub 国内加速镜像..."
    mkdir -p /etc/docker
    if [[ -f /etc/docker/daemon.json && ! -f /etc/docker/daemon.json.cyber-practice.bak ]]; then
        cp /etc/docker/daemon.json /etc/docker/daemon.json.cyber-practice.bak
    fi

    cat > /etc/docker/daemon.json <<'DOCKERJSON'
{
  "registry-mirrors": [
    "https://docker.m.daocloud.io",
    "https://docker.1ms.run",
    "https://dockerproxy.cn"
  ],
  "max-concurrent-downloads": 6
}
DOCKERJSON
    ok "Docker 镜像加速已写入 /etc/docker/daemon.json"
}

# ── 如果还没有项目文件，从 GitHub 克隆 ─────────────
# 默认创建 ~/cyber-practice 目录并在其中部署。
PROJECT_DIR="$ACTUAL_HOME/cyber-practice"

if [[ ! -f "$PROJECT_DIR/student.sh" || ! -d "$PROJECT_DIR/labs" ]]; then
    echo -e "\n[1/1] 从 GitHub 克隆实验内容到 ~/cyber-practice ..."
    configure_china_mirrors
    install_git_if_missing

    if [[ -d "$PROJECT_DIR" ]]; then
        warn "~/cyber-practice 已存在，先备份..."
        mv "$PROJECT_DIR" "$PROJECT_DIR.bak.$(date +%Y%m%d%H%M%S)"
    fi

    echo "克隆中（首次需要几分钟）..."
    git clone --depth=1 "$REPO_URL" "$PROJECT_DIR"
    echo "克隆完成"
fi

# 切换到项目目录，后续所有操作都在此目录进行。
ROOT_DIR="$PROJECT_DIR"
cd "$ROOT_DIR"

echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║${RESET}     ${BOLD}Cyber Practice Lab — 一键环境部署${RESET}              ${BOLD}${CYAN}║${RESET}"
echo -e "${BOLD}${CYAN}║${RESET}  目标: 将 Kali VM 变成完整的 12 实验教学环境         ${BOLD}${CYAN}║${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"
echo
info "部署用户: $ACTUAL_USER"
info "项目路径: $ROOT_DIR"
info "预计耗时: 15-30 分钟（取决于网络速度）"
echo

# ─────────────────────────────────────────────────────
# 步骤 1: 系统更新
# ─────────────────────────────────────────────────────
step "1" "系统包更新"
configure_china_mirrors
if apt-get update -qq; then
    ok "apt update 完成"
else
    fail "apt update 失败"
    if $CHINA_MIRRORS && [[ -f /etc/apt/sources.list.cyber-practice.bak ]]; then
        warn "国内源不可用，恢复 Kali 默认源后重试"
        cp /etc/apt/sources.list.cyber-practice.bak /etc/apt/sources.list
        apt-get update -qq && ok "apt update 使用默认源完成" || ERRORS+=("apt update")
    else
        ERRORS+=("apt update")
    fi
fi

# ─────────────────────────────────────────────────────
# 步骤 2: 安装所有工具
# ─────────────────────────────────────────────────────
if $SKIP_TOOLS; then
    step "2" "工具安装 — 已跳过"
else
    step "2" "安装所需工具包"
    export DEBIAN_FRONTEND=noninteractive

    info "安装基础工具..."
    apt-get install -y -qq \
        curl wget git jq tree vim nano \
        netcat-traditional dnsutils \
        openssl python3 python3-pip python3-venv \
        ca-certificates gnupg lsb-release \
        2>&1 | tail -1
    ok "基础工具完成"

    info "安装网络与安全工具..."
    apt-get install -y -qq \
        nmap tcpdump wireshark tshark \
        burpsuite zaproxy \
        john hashcat hydra \
        sqlmap dirb gobuster \
        2>&1 | tail -1
    ok "安全工具完成"

    info "清理 apt 缓存..."
    apt-get clean -qq
    ok "清理完成"
fi

# ─────────────────────────────────────────────────────
# 步骤 3: 安装 Docker
# ─────────────────────────────────────────────────────
step "3" "Docker 安装与配置"

if command -v docker &>/dev/null && docker version &>/dev/null 2>&1; then
    ok "Docker 已安装并运行"
    configure_docker_registry_mirrors
    systemctl restart docker 2>/dev/null || service docker restart 2>/dev/null || true
else
    info "安装 Docker..."
    # Kali/Ubuntu 仓库通常已包含 docker.io；Compose 插件包名在不同发行版上略有差异。
    apt-get install -y -qq docker.io docker-compose-plugin 2>/dev/null || \
    apt-get install -y -qq docker.io docker-compose-v2 2>/dev/null || {
        # 回退：使用 Docker CE 仓库。国内默认走阿里云镜像，可用 DOCKER_APT_MIRROR 覆盖。
        info "从 Docker CE apt 仓库安装..."
        install -m 0755 -d /etc/apt/keyrings
        docker_apt_repo="$DOCKER_APT_MIRROR"
        $CHINA_MIRRORS || docker_apt_repo="https://download.docker.com/linux/debian"
        rm -f /etc/apt/keyrings/docker.gpg
        curl -fsSL "$docker_apt_repo/gpg" | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null || \
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] $docker_apt_repo $DOCKER_DEBIAN_CODENAME stable" > /etc/apt/sources.list.d/docker.list
        apt-get update -qq
        apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-compose-plugin
    }
    ok "Docker 安装完成"

    configure_docker_registry_mirrors

    info "启动 Docker 服务..."
    systemctl enable --now docker 2>/dev/null || service docker start 2>/dev/null
    systemctl restart docker 2>/dev/null || service docker restart 2>/dev/null || true
    ok "Docker 服务已启动"
fi

if ! docker compose version &>/dev/null; then
    fail "Docker Compose v2 不可用。请安装 docker-compose-plugin 或 docker-compose-v2。"
    exit 1
fi

# 将用户加入 docker 组
if id -nG "$ACTUAL_USER" 2>/dev/null | grep -qw docker; then
    ok "用户 $ACTUAL_USER 已在 docker 组中"
else
    info "将 $ACTUAL_USER 加入 docker 组..."
    usermod -aG docker "$ACTUAL_USER"
    ok "已加入 docker 组（下次登录生效）"
fi

# ─────────────────────────────────────────────────────
# 步骤 4: 拉取 Docker 镜像
# ─────────────────────────────────────────────────────
step "4" "拉取 Docker 基础镜像"

# 使用 sg 绕过组权限问题
docker_cmd() {
    if [[ "$ACTUAL_USER" != "root" ]]; then
        sg docker -c "docker $*" 2>/dev/null || docker "$@"
    else
        docker "$@"
    fi
}

IMAGES=(
    "nginx:1.25-alpine"
    "alpine:3.19"
    "bkimminich/juice-shop:latest"
    "webgoat/webgoat:latest"
)

for img in "${IMAGES[@]}"; do
    info "拉取 $img ..."
    if docker_cmd pull "$img" 2>&1 | tail -1; then
        ok "$img"
    else
        warn "$img 拉取失败，将在构建时重试"
        ERRORS+=("pull:$img")
    fi
done

# ─────────────────────────────────────────────────────
# 步骤 5: 构建自定义镜像
# ─────────────────────────────────────────────────────
step "5" "构建自定义 Docker 镜像"

info "构建所有服务镜像（可能需要几分钟）..."
if docker_cmd compose build 2>&1 | tail -5; then
    ok "所有自定义镜像构建完成"
else
    fail "部分镜像构建失败"
    ERRORS+=("docker build")
fi

# ─────────────────────────────────────────────────────
# 步骤 6: 准备目录结构
# ─────────────────────────────────────────────────────
step "6" "准备目录结构"

if [[ -x "$ROOT_DIR/prepare-lab-data.sh" ]]; then
    "$ROOT_DIR/prepare-lab-data.sh" >/dev/null
else
    mkdir -p reports pcaps submit logs
    mkdir -p evidence/ids evidence/logs evidence/incident
fi
chown -R "$ACTUAL_USER:$ACTUAL_USER" reports pcaps submit logs evidence 2>/dev/null || true
ok "目录结构与预置证据就绪"

# ─────────────────────────────────────────────────────
# 步骤 7: 逐一验证所有实验
# ─────────────────────────────────────────────────────
step "7" "验证所有实验环境"

if [[ -x "$ROOT_DIR/verify-lab-env.sh" ]]; then
    if "$ROOT_DIR/verify-lab-env.sh"; then
        ok "12 个实验环境均通过端口、Web 响应和证据文件检查"
    else
        fail "12 实验环境验收未全部通过"
        ERRORS+=("verify-lab-env")
    fi
else
    warn "找不到 verify-lab-env.sh，跳过深度验收"
    ERRORS+=("missing verify-lab-env.sh")
fi

# ─────────────────────────────────────────────────────
# 步骤 8: 最终检查
# ─────────────────────────────────────────────────────
step "8" "最终检查和清理"

# 检查关键工具
TOOLS=("nmap" "curl" "tcpdump" "tshark" "jq" "docker" "burpsuite")
MISSING_TOOLS=()
for tool in "${TOOLS[@]}"; do
    command -v "$tool" &>/dev/null || MISSING_TOOLS+=("$tool")
done

if [[ ${#MISSING_TOOLS[@]} -eq 0 ]]; then
    ok "所有关键工具可用"
else
    warn "缺失工具: ${MISSING_TOOLS[*]}"
    ERRORS+=("tools:${MISSING_TOOLS[*]}")
fi

# Docker 镜像统计
IMAGE_COUNT=$(docker_cmd images -q | wc -l)
ok "Docker 镜像: ${IMAGE_COUNT} 个"

# 磁盘使用
DISK_USAGE=$(du -sh "$ROOT_DIR" 2>/dev/null | cut -f1)
info "项目磁盘占用: ${DISK_USAGE}"

# ─────────────────────────────────────────────────────
# 部署报告
# ─────────────────────────────────────────────────────
echo
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║${RESET}              ${BOLD}部署完成报告${RESET}                          ${BOLD}${CYAN}║${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"
echo

if [[ ${#ERRORS[@]} -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}✅ 所有步骤成功完成！${RESET}"
else
    echo -e "  ${YELLOW}${BOLD}⚠️  以下步骤有问题:${RESET}"
    for e in "${ERRORS[@]}"; do
        echo -e "     - $e"
    done
fi

echo
echo -e "  ${BOLD}下一步:${RESET}"
echo -e "    ./check-env.sh                  # 检查环境"
echo -e "    ./start-lab.sh lab01            # 手动启动实验"
echo -e "    ./student.sh                    # 启动学生引导系统"
echo

if [[ "$ACTUAL_USER" != "root" ]]; then
    echo -e "  ${YELLOW}⚠️  Docker 组权限: 如果 docker 命令报权限错误，请注销后重新登录${RESET}"
    echo -e "     或执行: newgrp docker"
    echo
fi

if $TEACHER_MODE; then
    echo -e "  ${BOLD}教师模式已启用${RESET}：保留所有文件，未加密实验内容"
    echo -e "  ${BOLD}下一步:${RESET}"
    echo -e "    ./teacher.sh                    # 启动教师管理界面"
    echo -e "    ./student.sh                    # 启动学生引导系统"
else
    if [[ ${#ERRORS[@]} -eq 0 ]]; then
        echo -e "  ${BOLD}环境验收通过，下一步制作学生镜像${RESET}"
    else
        echo -e "  ${YELLOW}存在部署错误，跳过学生镜像制作，避免分发不可用环境。${RESET}"
    fi
fi

# ─────────────────────────────────────────────────────
# 制作学生镜像（默认行为）
# ─────────────────────────────────────────────────────
if ! $TEACHER_MODE && [[ ${#ERRORS[@]} -eq 0 ]]; then
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}制作学生分发镜像...${RESET}"
    echo

    if [[ -x "$ROOT_DIR/make-student-image.sh" ]]; then
        bash "$ROOT_DIR/make-student-image.sh" --yes
        echo
        echo -e "${GREEN}${BOLD}✅ 学生镜像准备完成！${RESET}"
        echo
        echo -e "  ${BOLD}发布步骤:${RESET}"
        echo -e "  1. 在 VirtualBox 中: 关闭 VM → 拍摄快照 'baseline-ready'"
        echo -e "  2. 文件 → 导出虚拟机 → OVA 格式"
        echo -e "  3. 将 OVA 文件分发给学生"
        echo -e "  4. 学生导入 OVA → 启动 VM → 打开终端运行: ${BOLD}./student.sh${RESET}"
    else
        fail "找不到 make-student-image.sh"
    fi
fi

exit ${#ERRORS[@]}
