#!/usr/bin/env bash
# make-student-image.sh — 制作学生 VM 镜像
# 在 setup-lab-vm.sh 完成后运行此脚本，
# 或直接运行 setup-lab-vm.sh --student-image
#
# 此脚本会:
#   1. 停止所有 Docker 容器
#   2. 清理教师专用文件
#   3. 重置学生进度
#   4. 清理缓存以减小镜像体积
#   5. 验证学生环境完整性

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source "$SCRIPT_DIR/lib/crypto-utils.sh"
source "$SCRIPT_DIR/lib/progress-lib.sh"

RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'
BLUE='\033[34m'; CYAN='\033[36m'; BOLD='\033[1m'; RESET='\033[0m'
ok()   { echo -e "  ${GREEN}✅${RESET} $1"; }
warn() { echo -e "  ${YELLOW}⚠️${RESET}  $1"; }
info() { echo -e "  ${BLUE}ℹ${RESET}  $1"; }

# 跳过确认的参数
AUTO_CONFIRM=false
case "${1:-}" in
    --yes|-y) AUTO_CONFIRM=true ;;
    --help|-h)
        echo "用法: ./make-student-image.sh [--yes]"
        echo "  --yes, -y   跳过确认提示"
        exit 0
        ;;
esac

echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║${RESET}            ${BOLD}📦 制作学生 VM 镜像${RESET}                         ${BOLD}${CYAN}║${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"
echo

# ── 1. 读取教师配置 ────────────────────────────────
if [[ -f ".teacher-config" ]]; then
    source ".teacher-config"
    ok "教师配置: SOLUTION=${SOLUTION_ENABLED:-false} UNLOCK=${UNLOCK_MODE:-auto} HINT=${HINT_LEVEL:-2}"
else
    warn ".teacher-config 不存在，使用默认设置"
    SOLUTION_ENABLED=false
    UNLOCK_MODE=auto
    HINT_LEVEL=2
fi

# ── 2. 确认操作 ────────────────────────────────────
if ! $AUTO_CONFIRM; then
    echo
    echo -e "  ${YELLOW}⚠️  此操作将:${RESET}"
    echo "     - 停止所有 Docker 容器"
    echo "     - 删除教师专用文件（teacher.sh, setup-lab-vm.sh 等）"
    echo "     - 清空学生进度、提交记录、实验报告"
    echo "     - 清理 Docker 构建缓存（减小镜像体积）"
    echo "     - 锁定除 lab01 外的所有实验"
    echo
    read -rp "  确认继续? [y/N] " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "  已取消。"
        exit 0
    fi
fi

# ── 3. 停止所有 Docker 容器 ────────────────────────
echo
echo -e "${BOLD}[1/7]${RESET} 停止 Docker 容器..."
if command -v docker &>/dev/null; then
    docker compose down --remove-orphans 2>/dev/null || true
    ok "所有容器已停止"
else
    warn "Docker 不可用，跳过"
fi

# ── 4. 清理教师专用文件 ────────────────────────────
echo -e "${BOLD}[2/7]${RESET} 删除教师专用文件..."

TEACHER_FILES=(
    "teacher.sh"
    "setup-lab-vm.sh"
    "make-student-image.sh"
    ".teacher-data"
    ".teacher-config"
    "lab-passwords.txt"
    "docs/"
)

for f in "${TEACHER_FILES[@]}"; do
    if [[ -e "$f" ]]; then
        rm -rf "$f"
        info "已删除: $f"
    fi
done
ok "教师文件已清理"

# ── 5. 重置学生进度 ────────────────────────────────
echo -e "${BOLD}[3/7]${RESET} 重置学生进度..."
rm -rf .progress
mkdir -p .progress

STUDENT_NAME_VAL="${STUDENT_NAME:-}"
cat > .progress/state <<STATE
STUDENT_NAME="${STUDENT_NAME_VAL}"
VERSION="2.0"
STARTED_AT=""
LAB_STATUS_lab01="unlocked"
LAB_TOTAL_lab01="5"
LAB_CURRENT_lab01="0"
LAB_STEPS_DONE_lab01=""
LAB_HINTS_lab01="0"
LAB_SOLUTION_lab01="false"
STATE
ok "lab01 已解锁，其余 11 个实验锁定"

# ── 6. 清空学生产出目录 ────────────────────────────
echo -e "${BOLD}[4/7]${RESET} 清空提交和报告..."
rm -rf submit reports
mkdir -p submit reports

# 清空运行时日志（但保留目录结构）
find logs -type f -delete 2>/dev/null || true
mkdir -p logs/nginx logs/upload logs/traffic logs/incident 2>/dev/null || true

# 只保留 evidence 中的 .gitkeep，删除其他
find evidence -type f -not -name '.gitkeep' -delete 2>/dev/null || true
mkdir -p evidence/ids evidence/logs evidence/incident 2>/dev/null || true

ok "学生产出已清空"

# ── 5. 加密实验文件（lab02~12）─────────────────────
echo -e "${BOLD}[5/8]${RESET} 加密实验文件..."

LABS_DIR="$SCRIPT_DIR/labs"
TEACHER_PASSWORD_FILE="$SCRIPT_DIR/lab-passwords.txt"
> "$TEACHER_PASSWORD_FILE"

cat >> "$TEACHER_PASSWORD_FILE" <<'HEADER'
╔══════════════════════════════════════════════════════╗
║           🔑 实验密码表（教师保留）                   ║
╠══════════════════════════════════════════════════════╣
║  每周发给学生对应实验的密码，学生输入后才能解锁       ║
║  请妥善保管此文件，不要发给学生                       ║
╚══════════════════════════════════════════════════════╝

HEADER

for lab_dir in "$LABS_DIR"/lab*/; do
    lab=$(basename "$lab_dir")
    # lab01 不加密
    if [[ "$lab" == "lab01"* ]]; then
        info "lab01 保持明文（入口实验）"
        continue
    fi

    if crypto_is_encrypted "$lab_dir"; then
        info "$lab 已加密，跳过"
        continue
    fi

    # 生成密码并加密
    pwd=$(crypto_generate_password)
    if crypto_encrypt_lab "$lab_dir" "$pwd"; then
        lab_id="${lab%%-*}"
        printf "%-8s  %s  (%s)\n" "$lab_id" "$pwd" "${lab#*-}" >> "$TEACHER_PASSWORD_FILE"
    else
        warn "$lab 加密失败"
    fi
done

echo >> "$TEACHER_PASSWORD_FILE"
echo "  学生使用方式:" >> "$TEACHER_PASSWORD_FILE"
echo "  1. 打开终端: cd ~/cyber-practice && ./student.sh" >> "$TEACHER_PASSWORD_FILE"
echo "  2. 进入实验时输入上述密码" >> "$TEACHER_PASSWORD_FILE"

ok "实验文件加密完成 (lab02-lab12)"

echo
echo -e "  ${BOLD}${GREEN}📋 密码表已生成: lab-passwords.txt${RESET}"
echo -e "  ${YELLOW}⚠️  请将此文件复制到安全位置，不要留在学生 VM 中！${RESET}"
echo
echo

# ── 6. 清理 Docker 缓存（减小镜像体积） ────────────
echo -e "${BOLD}[6/8]${RESET} 清理 Docker 缓存..."
if command -v docker &>/dev/null; then
    docker builder prune -f 2>/dev/null || true
    docker system prune -f 2>/dev/null || true
    ok "Docker 缓存已清理"
else
    warn "Docker 不可用，跳过"
fi

# ── 7. 设置文件权限 ────────────────────────────────
echo -e "${BOLD}[7/8]${RESET} 设置文件权限..."

# 核心脚本
chmod +x student.sh start-lab.sh stop-lab.sh reset-lab.sh check-env.sh install-kali.sh prepare-lab-data.sh verify-lab-env.sh update-system.sh 2>/dev/null || true

# 恢复 lab10/lab11/lab12 需要的预置证据。上面的清理会删除 evidence 下的运行时文件，
# 但学生镜像仍需要这些样本文件才能按教程直接开始实验。
if [[ -x "$SCRIPT_DIR/prepare-lab-data.sh" ]]; then
    "$SCRIPT_DIR/prepare-lab-data.sh" >/dev/null
fi

# 库文件
chmod +x lib/*.sh 2>/dev/null || true

# 实验引导脚本
find labs -name "guide.sh" -exec chmod +x {} \; 2>/dev/null || true
find labs -name "check-*.sh" -o -name "check-all.sh" | xargs chmod +x 2>/dev/null || true

ok "权限已设置"

# ── 8. 最终验证 ────────────────────────────────────
echo -e "${BOLD}[8/8]${RESET} 验证学生环境..."

PASS=0
FAIL=0

# 检查关键文件
REQUIRED_FILES=(
    "student.sh:学生入口"
    "start-lab.sh:实验启动"
    "stop-lab.sh:实验停止"
    "reset-lab.sh:实验重置"
    "check-env.sh:环境检查"
    "prepare-lab-data.sh:实验数据准备"
    "update-system.sh:系统更新"
    "docker-compose.yml:Docker配置"
    "STUDENT_GUIDE.md:学生使用教程"
    "lib/progress-lib.sh:进度库"
    "lib/ui-utils.sh:UI库"
    "lib/guide-framework.sh:引导框架"
)

for entry in "${REQUIRED_FILES[@]}"; do
    f="${entry%%:*}"
    desc="${entry##*:}"
    if [[ -f "$f" ]]; then
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}❌${RESET} 缺失: $f ($desc)"
        FAIL=$((FAIL + 1))
    fi
done

# 检查实验文件
LAB_COUNT=$(find labs -name "guide.sh" | wc -l)
STEP_COUNT=$(find labs -path "*/steps/*.md" | wc -l)
HINT_COUNT=$(find labs -path "*/hints/*.md" | wc -l)

echo
info "实验文件: ${LAB_COUNT} 个 guide.sh, ${STEP_COUNT} 个步骤, ${HINT_COUNT} 个提示"

# 检查 Docker 镜像
if command -v docker &>/dev/null; then
    IMG_COUNT=$(docker images -q | wc -l)
    info "Docker 镜像: ${IMG_COUNT} 个"
fi

# 磁盘使用
DISK=$(du -sh "$SCRIPT_DIR" 2>/dev/null | cut -f1)
info "项目磁盘: ${DISK}"

echo
if [[ $FAIL -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}✅ 所有检查通过 (${PASS} 项)${RESET}"
else
    echo -e "  ${YELLOW}${BOLD}⚠️  ${FAIL} 项缺失${RESET}"
fi

# ── 最终报告 ───────────────────────────────────────
echo
echo -e "${BOLD}${CYAN}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}${CYAN}║${RESET}          ${GREEN}✅ 学生镜像准备完成！${RESET}                        ${BOLD}${CYAN}║${RESET}"
echo -e "${BOLD}${CYAN}╠══════════════════════════════════════════════════════╣${RESET}"
echo -e "${BOLD}${CYAN}║${RESET}                                                      ${BOLD}${CYAN}║${RESET}"
echo -e "${BOLD}${CYAN}║${RESET}  ${BOLD}发布步骤:${RESET}                                          ${BOLD}${CYAN}║${RESET}"
echo -e "${BOLD}${CYAN}║${RESET}  1. VirtualBox: 关闭 VM                                ${BOLD}${CYAN}║${RESET}"
echo -e "${BOLD}${CYAN}║${RESET}  2. 拍摄快照: baseline-ready                            ${BOLD}${CYAN}║${RESET}"
echo -e "${BOLD}${CYAN}║${RESET}  3. 文件 → 导出虚拟电脑 → OVA 格式                     ${BOLD}${CYAN}║${RESET}"
echo -e "${BOLD}${CYAN}║${RESET}  4. 分发给学生                                          ${BOLD}${CYAN}║${RESET}"
echo -e "${BOLD}${CYAN}║${RESET}                                                      ${BOLD}${CYAN}║${RESET}"
echo -e "${BOLD}${CYAN}║${RESET}  ${BOLD}学生使用:${RESET}                                          ${BOLD}${CYAN}║${RESET}"
echo -e "${BOLD}${CYAN}║${RESET}  导入OVA → 启动VM → 打开终端 → ./student.sh            ${BOLD}${CYAN}║${RESET}"
echo -e "${BOLD}${CYAN}║${RESET}                                                      ${BOLD}${CYAN}║${RESET}"
echo -e "${BOLD}${CYAN}╚══════════════════════════════════════════════════════╝${RESET}"
