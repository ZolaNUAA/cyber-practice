#!/usr/bin/env bash
# teacher.sh — 教师入口
# 用法:
#   ./teacher.sh                  → 管理面板
#   ./teacher.sh --import FILE    → 导入学生提交
#   ./teacher.sh --demo lab04     → 快速演示模式

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CYBER_PRACTICE_ROOT="$SCRIPT_DIR"

source "$SCRIPT_DIR/lib/progress-lib.sh"
source "$SCRIPT_DIR/lib/ui-utils.sh"

TEACHER_CONFIG="$CYBER_PRACTICE_ROOT/.teacher-config"
TEACHER_DATA="$CYBER_PRACTICE_ROOT/.teacher-data"

# ── 初始化教师数据目录 ────────────────────────────
teacher_init() {
    mkdir -p "$TEACHER_DATA" "$CYBER_PRACTICE_ROOT/submit"
    if [[ ! -f "$TEACHER_CONFIG" ]]; then
        cat > "$TEACHER_CONFIG" <<'EOF'
# 教师配置文件
# 这些设置影响学生端的行为

# 学生能否直接查看完整答案 (true/false)
SOLUTION_ENABLED=false

# 解锁模式: auto(完成一个自动解锁下一个) / manual(教师手动控制)
UNLOCK_MODE=auto

# 提示等级: 1=只给方向, 2=给具体线索, 3=直接给答案
HINT_LEVEL=2

# 学生姓名（制作镜像时设置，留空则学生首次启动时自己输入）
STUDENT_NAME=""
EOF
    fi
    source "$TEACHER_CONFIG"
}

# ── 导入学生提交 ───────────────────────────────────
import_submit() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        ui_error "文件不存在: $file"
        return 1
    fi

    local basename; basename=$(basename "$file")
    cp "$file" "$TEACHER_DATA/$basename"
    ui_success "已导入: $basename"
}

# ── 查看班级概览 ───────────────────────────────────
show_class_overview() {
    ui_clear
    echo
    echo -e "${C_BOLD}${C_CYAN}╔════════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_BOLD}${C_CYAN}║${C_RESET}           ${C_BOLD}🎓 班级进度概览${C_RESET}                        ${C_BOLD}${C_CYAN}║${C_RESET}"
    echo -e "${C_BOLD}${C_CYAN}╚════════════════════════════════════════════════╝${C_RESET}"
    echo

    if [[ ! -d "$TEACHER_DATA" ]] || [[ -z "$(ls -A "$TEACHER_DATA" 2>/dev/null)" ]]; then
        echo -e "  ${C_DIM}暂无学生提交数据。${C_RESET}"
        echo -e "  ${C_DIM}学生完成实验后会将 submit/*.json 提交给你。${C_RESET}"
        echo -e "  ${C_DIM}使用: ./teacher.sh --import <文件> 导入。${C_RESET}"
        echo
        ui_press_enter
        return
    fi

    # 汇总每个学生的最新状态
    declare -A student_labs student_titles
    while IFS= read -r -d '' file; do
        local student; student=$(grep -o '"student": "[^"]*"' "$file" | head -1 | cut -d'"' -f4)
        local lab; lab=$(grep -o '"lab": "[^"]*"' "$file" | head -1 | cut -d'"' -f4)
        local title; title=$(grep -o '"title": "[^"]*"' "$file" | head -1 | cut -d'"' -f4)
        local hints; hints=$(grep -o '"hints_used": [0-9]*' "$file" | head -1 | awk '{print $2}')
        local solution; solution=$(grep -o '"solution_viewed": [a-z]*' "$file" | head -1 | awk '{print $2}')

        student_labs["$student"]="$lab"
        student_titles["$student"]="$title"
    done < <(find "$TEACHER_DATA" -name "*.json" -type f -print0 | sort -z)

    printf "  ${C_BOLD}%-12s %-10s %-18s %-8s %-8s${C_RESET}\n" "学生" "当前实验" "标题" "提示次数" "看答案"
    echo "  ─────────────────────────────────────────────────────"

    for student in $(printf '%s\n' "${!student_labs[@]}" | sort -u); do
        local lab="${student_labs[$student]}"
        local title="${student_titles[$student]}"
        # 统计该学生的提示和答案
        local total_hints=0; local saw_solution="否"
        while IFS= read -r -d '' file; do
            local s; s=$(grep -o '"student": "[^"]*"' "$file" | head -1 | cut -d'"' -f4)
            if [[ "$s" == "$student" ]]; then
                local h; h=$(grep -o '"hints_used": [0-9]*' "$file" | head -1 | awk '{print $2}')
                total_hints=$((total_hints + h))
                local sol; sol=$(grep -o '"solution_viewed": [a-z]*' "$file" | head -1 | awk '{print $2}')
                [[ "$sol" == "true" ]] && saw_solution="是"
            fi
        done < <(find "$TEACHER_DATA" -name "*.json" -type f -print0)

        printf "  %-12s %-10s %-18s %-8s %-8s\n" \
            "$student" "$lab" "${title:0:18}" "$total_hints" "$saw_solution"
    done

    echo
    ui_press_enter
}

# ── 系统配置 ───────────────────────────────────────
show_config() {
    ui_clear
    echo
    echo -e "${C_BOLD}${C_CYAN}╔════════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_BOLD}${C_CYAN}║${C_RESET}            ${C_BOLD}⚙️ 系统配置${C_RESET}                           ${C_BOLD}${C_CYAN}║${C_RESET}"
    echo -e "${C_BOLD}${C_CYAN}╚════════════════════════════════════════════════╝${C_RESET}"
    echo

    source "$TEACHER_CONFIG"

    echo -e "  ${C_BOLD}[1]${C_RESET} 答案可见性: ${C_YELLOW}${SOLUTION_ENABLED}${C_RESET}"
    echo -e "       ${C_DIM}true=学生可以看完整答案, false=禁止${C_RESET}"
    echo
    echo -e "  ${C_BOLD}[2]${C_RESET} 解锁模式:   ${C_YELLOW}${UNLOCK_MODE}${C_RESET}"
    echo -e "       ${C_DIM}auto=完成自动解锁下一个, manual=教师手动控制${C_RESET}"
    echo
    echo -e "  ${C_BOLD}[3]${C_RESET} 提示等级:   ${C_YELLOW}${HINT_LEVEL}${C_RESET}"
    echo -e "       ${C_DIM}1=只给方向, 2=给具体线索, 3=直接给答案${C_RESET}"
    echo

    echo -ne "  ${C_DIM}选择要修改的项 [1-3] 或 [q] 返回: ${C_RESET}"
    read -r choice

    case "$choice" in
        1)
            if [[ "$SOLUTION_ENABLED" == "true" ]]; then
                sed -i 's/^SOLUTION_ENABLED=.*/SOLUTION_ENABLED=false/' "$TEACHER_CONFIG"
            else
                sed -i 's/^SOLUTION_ENABLED=.*/SOLUTION_ENABLED=true/' "$TEACHER_CONFIG"
            fi
            ui_success "已切换。"
            ;;
        2)
            if [[ "$UNLOCK_MODE" == "auto" ]]; then
                sed -i 's/^UNLOCK_MODE=.*/UNLOCK_MODE=manual/' "$TEACHER_CONFIG"
            else
                sed -i 's/^UNLOCK_MODE=.*/UNLOCK_MODE=auto/' "$TEACHER_CONFIG"
            fi
            ui_success "已切换。"
            ;;
        3)
            echo -ne "  输入新等级 (1/2/3): "
            read -r level
            if [[ "$level" =~ ^[1-3]$ ]]; then
                sed -i "s/^HINT_LEVEL=.*/HINT_LEVEL=$level/" "$TEACHER_CONFIG"
                ui_success "已更新。"
            else
                ui_error "无效等级。"
            fi
            ;;
    esac
    ui_press_enter
}

# ── 快速演示 ───────────────────────────────────────
demo_mode() {
    local lab="${1:-}"
    if [[ -z "$lab" ]]; then
        echo -ne "  ${C_BOLD}要演示的实验编号 (如 04): ${C_RESET}"
        read -r lab
        lab=$(printf "lab%02d" "$((10#$lab))")
    fi

    # 找到实验目录
    local lab_dir; lab_dir=$(find "$CYBER_PRACTICE_ROOT/labs" -maxdepth 1 -type d -name "${lab}*" | head -1)
    if [[ -z "$lab_dir" ]]; then
        ui_error "找不到实验: $lab"
        ui_press_enter
        return
    fi

    local guide_script="$lab_dir/guide.sh"
    if [[ ! -f "$guide_script" ]]; then
        ui_error "此实验暂无引导脚本。"
        ui_press_enter
        return
    fi

    # 覆盖配置：演示模式下允许看答案
    SOLUTION_ENABLED=true bash "$guide_script"
}

# ── 学生进度管理 ───────────────────────────────────
manage_students() {
    ui_clear
    echo
    echo -e "${C_BOLD}学生进度管理${C_RESET}"
    echo -e "${C_DIM}此功能需要在学生VM上操作。${C_RESET}"
    echo -e "${C_DIM}制作镜像时预设进度在 .progress/state 文件中。${C_RESET}"
    echo
    ui_press_enter
}

# ── 一键制作学生镜像 ──────────────────────────────
make_student_image() {
    if [[ -x "$CYBER_PRACTICE_ROOT/make-student-image.sh" ]]; then
        bash "$CYBER_PRACTICE_ROOT/make-student-image.sh"
    else
        ui_error "找不到 make-student-image.sh"
        ui_info "请确保 make-student-image.sh 存在且可执行。"
    fi
    ui_press_enter
}

# ── 进入学生模式 ───────────────────────────────────
enter_student_mode() {
    ui_info "以学生身份启动 student.sh（进度不影响真实学生）..."
    ui_press_enter
    bash "$CYBER_PRACTICE_ROOT/student.sh"
}

# ── 命令行参数处理 ─────────────────────────────────
if [[ "${1:-}" == "--import" ]]; then
    teacher_init
    import_submit "${2:-}"
    exit 0
elif [[ "${1:-}" == "--demo" ]]; then
    teacher_init
    demo_mode "${2:-}"
    exit 0
elif [[ "${1:-}" == "--make-image" ]]; then
    teacher_init
    make_student_image
    exit 0
elif [[ "${1:-}" == "--student" ]]; then
    enter_student_mode
    exit 0
fi

# ── 管理面板主循环 ─────────────────────────────────
main() {
    teacher_init

    while true; do
        ui_clear
        echo -e "${C_BOLD}${C_CYAN}╔════════════════════════════════════════════════╗${C_RESET}"
        echo -e "${C_BOLD}${C_CYAN}║${C_RESET}            ${C_BOLD}🎓 教师管理面板${C_RESET}                          ${C_BOLD}${C_CYAN}║${C_RESET}"
        echo -e "${C_BOLD}${C_CYAN}╚════════════════════════════════════════════════╝${C_RESET}"
        echo

        # 快速统计
        local submit_count=0
        if [[ -d "$TEACHER_DATA" ]]; then
            submit_count=$(find "$TEACHER_DATA" -name "*.json" -type f | wc -l)
        fi
        echo -e "  ${C_DIM}已导入提交: ${submit_count} 份${C_RESET}"
        echo

        echo -e "  ${C_BOLD}[1]${C_RESET} 📋 查看班级概览"
        echo -e "  ${C_BOLD}[2]${C_RESET} ⚙️ 系统配置"
        echo -e "  ${C_BOLD}[3]${C_RESET} 🎬 快速演示 (跳过限制打开实验)"
        echo -e "  ${C_BOLD}[4]${C_RESET} 👥 学生进度管理"
        echo -e "  ${C_BOLD}[5]${C_RESET} 📦 制作学生镜像"
        echo -e "  ${C_BOLD}[6]${C_RESET} 👤 进入学生模式 (教师体验)"
        echo
        echo -e "  ${C_DIM}[q] 退出${C_RESET}"
        echo
        echo -ne "  > "
        read -r choice

        case "$choice" in
            1) show_class_overview ;;
            2) show_config ;;
            3) demo_mode "" ;;
            4) manage_students ;;
            5) make_student_image ;;
            6) enter_student_mode ;;
            q|Q) echo; ui_info "再见！"; exit 0 ;;
            *) ui_warn "无效选项。" ; ui_press_enter ;;
        esac
    done
}

main "$@"
