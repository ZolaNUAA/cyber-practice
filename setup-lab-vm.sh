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

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

REPO_URL="https://github.com/ZolaNUAA/cyber-practice.git"
KALI_MIRROR="${KALI_MIRROR:-http://mirrors.ustc.edu.cn/kali}"
DOCKER_APT_MIRROR="${DOCKER_APT_MIRROR:-https://mirrors.aliyun.com/docker-ce/linux/debian}"
DOCKER_DEBIAN_CODENAME="${DOCKER_DEBIAN_CODENAME:-bookworm}"
CHINA_MIRRORS="${CHINA_MIRRORS:-true}"
SKIP_TOOLS=false
MAKE_STUDENT_IMAGE=false

# ── 参数解析 ───────────────────────────────────────
for arg in "$@"; do
    case "$arg" in
        --skip-tools) SKIP_TOOLS=true ;;
        --student-image) MAKE_STUDENT_IMAGE=true ;;
        --no-china-mirrors) CHINA_MIRRORS=false ;;
        --help|-h)
            echo "用法: sudo ./setup-lab-vm.sh [选项]"
            echo "  --skip-tools          跳过工具安装"
            echo "  --student-image       完成后制作学生镜像"
            echo "  --no-china-mirrors    不切换国内 apt/Docker 加速源"
            echo
            echo "环境变量:"
            echo "  KALI_MIRROR           Kali apt 源，默认: $KALI_MIRROR"
            echo "  DOCKER_APT_MIRROR     Docker CE apt 源，默认: $DOCKER_APT_MIRROR"
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

# ── 权限检查 ───────────────────────────────────────
if [[ "$(id -u)" -ne 0 ]]; then
    echo -e "${RED}此脚本需要 root 权限运行。${RESET}"
    echo "请使用: sudo ./setup-lab-vm.sh"
    exit 1
fi

# 获取实际用户（即使通过 sudo 运行）
ACTUAL_USER="${SUDO_USER:-$USER}"
ACTUAL_HOME=$(eval echo "~$ACTUAL_USER")

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
if [[ ! -f "student.sh" || ! -d "labs" ]]; then
    echo -e "\n[1/1] 从 GitHub 克隆实验内容..."
    configure_china_mirrors
    install_git_if_missing
    # 克隆到临时目录再移动，避免覆盖已有文件
    TEMP_DIR=$(mktemp -d /tmp/cyber-practice.XXXXXX)
    git clone --depth=1 "$REPO_URL" "$TEMP_DIR"
    # 移动所有文件到当前目录
    cp -r "$TEMP_DIR/"* "$TEMP_DIR"/.[!.]* "$ROOT_DIR/" 2>/dev/null || true
    rm -rf "$TEMP_DIR"
    echo "✅ 克隆完成"
fi

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

mkdir -p reports pcaps submit logs
mkdir -p evidence/ids evidence/logs evidence/incident
chown -R "$ACTUAL_USER:$ACTUAL_USER" reports pcaps submit logs evidence 2>/dev/null || true
ok "目录结构就绪"

# ─────────────────────────────────────────────────────
# 步骤 7: 逐一验证所有实验
# ─────────────────────────────────────────────────────
step "7" "验证所有实验环境"

LABS=(
    "lab01:recon"
    "lab02:info-leak"
    "lab03:auth"
    "lab04:sqli"
    "lab05:xss"
    "lab06:upload"
    "lab07:cmd"
    "lab08:priv"
    "lab09:traffic"
    "lab10:ids"
    "lab11:logs"
    "lab12:incident"
)

LAB_PASS=0
LAB_FAIL=0

for entry in "${LABS[@]}"; do
    lab="${entry%%:*}"
    profile="${entry##*:}"
    echo -n "  $lab ($profile)... "

    # 启动
    if docker_cmd compose --profile "$profile" up -d --wait 2>/dev/null; then
        # 简单验证：等2秒然后检查容器状态
        sleep 2
        CONTAINERS=$(docker_cmd compose --profile "$profile" ps -q 2>/dev/null | wc -l)
        if [[ $CONTAINERS -gt 0 ]]; then
            echo -e "${GREEN}OK${RESET} ($CONTAINERS 容器)"
            LAB_PASS=$((LAB_PASS + 1))
        else
            echo -e "${YELLOW}WARN${RESET} (无运行容器)"
            LAB_FAIL=$((LAB_FAIL + 1))
            ERRORS+=("verify:$lab")
        fi
    else
        echo -e "${RED}FAIL${RESET}"
        LAB_FAIL=$((LAB_FAIL + 1))
        ERRORS+=("verify:$lab")
    fi

    # 停止
    docker_cmd compose --profile "$profile" down 2>/dev/null
done

echo
info "验证结果: ${LAB_PASS}/${#LABS[@]} 通过"
[[ $LAB_FAIL -gt 0 ]] && warn "${LAB_FAIL} 个实验验证失败"

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

# ─────────────────────────────────────────────────────
# 可选：制作学生镜像
# ─────────────────────────────────────────────────────
if $MAKE_STUDENT_IMAGE; then
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}制作学生分发镜像...${RESET}"
    echo

    if [[ -x "$ROOT_DIR/make-student-image.sh" ]]; then
        bash "$ROOT_DIR/make-student-image.sh"
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
