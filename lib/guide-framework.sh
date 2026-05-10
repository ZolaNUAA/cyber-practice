#!/usr/bin/env bash
# guide-framework.sh — 渐进式实验引导框架
# 每个实验的 guide.sh 只需 source 此文件并调用 guide_start

# ── 加载依赖 ───────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CYBER_PRACTICE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$SCRIPT_DIR/progress-lib.sh"
source "$SCRIPT_DIR/ui-utils.sh"
source "$SCRIPT_DIR/crypto-utils.sh"

# ── 全局状态 ───────────────────────────────────────
GUIDE_LAB_ID=""
GUIDE_LAB_TITLE=""
GUIDE_LAB_DIR=""
GUIDE_TOTAL_STEPS=0
GUIDE_CURRENT_STEP=0
GUIDE_STEP_FILES=()
GUIDE_STEP_TITLES=()
GUIDE_HINT_COUNT=0
GUIDE_SOLUTION_VIEWED=false

# ── 教师配置 ───────────────────────────────────────
load_teacher_config() {
    local config_file="$CYBER_PRACTICE_ROOT/.teacher-config"
    SOLUTION_ENABLED="${SOLUTION_ENABLED:-false}"
    HINT_LEVEL="${HINT_LEVEL:-2}"
    if [[ -f "$config_file" ]]; then
        source "$config_file"
    fi
}

# ── 解析步骤文件元数据 ─────────────────────────────
parse_step_metadata() {
    local file="$1"
    local title=""; local step=""; local minutes=""
    while IFS= read -r line; do
        [[ "$line" != "# "* ]] && break
        case "$line" in
            "# TITLE: "*) title="${line#\# TITLE: }" ;;
            "# STEP: "*)   step="${line#\# STEP: }" ;;
            "# MINUTES: "*) minutes="${line#\# MINUTES: }" ;;
        esac
    done < "$file"
    echo "${title}|${step}|${minutes}"
}

# ── 加载实验所有步骤文件 ───────────────────────────
guide_load_steps() {
    local steps_dir="$GUIDE_LAB_DIR/steps"
    GUIDE_STEP_FILES=()
    GUIDE_STEP_TITLES=()

    if [[ ! -d "$steps_dir" ]]; then
        ui_error "找不到步骤目录: $steps_dir"
        exit 1
    fi

    while IFS= read -r -d '' file; do
        GUIDE_STEP_FILES+=("$file")
        local meta; meta=$(parse_step_metadata "$file")
        local title="${meta%%|*}"
        GUIDE_STEP_TITLES+=("$title")
    done < <(find "$steps_dir" -name "*.md" -type f -print0 | sort -z)

    GUIDE_TOTAL_STEPS=${#GUIDE_STEP_FILES[@]}

    if [[ $GUIDE_TOTAL_STEPS -eq 0 ]]; then
        ui_error "步骤目录为空: $steps_dir"
        exit 1
    fi
}

# ── 获取步骤内容（跳过元数据行） ───────────────────
guide_step_content() {
    local file="$1"
    local skip_meta=true
    while IFS= read -r line; do
        if $skip_meta; then
            [[ "$line" == "# "* ]] && continue
            skip_meta=false
        fi
        echo "$line"
    done < "$file"
}

# ── 显示单个步骤 ───────────────────────────────────
guide_show_step() {
    local step_num="$1"

    if [[ $step_num -lt 1 || $step_num -gt $GUIDE_TOTAL_STEPS ]]; then
        ui_error "步骤编号无效: $step_num (共 $GUIDE_TOTAL_STEPS 步)"
        return 1
    fi

    local idx=$((step_num - 1))
    local file="${GUIDE_STEP_FILES[$idx]}"
    local title="${GUIDE_STEP_TITLES[$idx]}"
    local content; content=$(guide_step_content "$file")

    ui_clear

    # 标题栏
    echo
    echo -e "  ${C_BOLD}${C_CYAN}━━━ 步骤 ${step_num}/${GUIDE_TOTAL_STEPS}: ${title} ━━━${C_RESET}"
    ui_progress_bar "$step_num" "$GUIDE_TOTAL_STEPS" 30
    echo; echo

    # 按段落显示：WHY / DO / CHECK
    local section=""
    while IFS= read -r line; do
        case "$line" in
            "### WHY")
                ui_section_why
                section="why"
                ;;
            "### DO")
                ui_section_do
                section="do"
                ;;
            "### CHECK")
                ui_section_check
                section="check"
                ;;
            *)
                if [[ -z "$line" ]]; then
                    echo
                elif [[ "$line" =~ ^\`\`\` ]]; then
                    continue
                elif [[ "$line" =~ ^[[:space:]]*[-*][[:space:]] ]]; then
                    printf '    %b•%b %s\n' "${C_BOLD}" "${C_RESET}" "${line#*[-*] }"
                elif [[ "$line" =~ ^[[:space:]]*[0-9]+\. ]]; then
                    local num="${line%%\.*}"
                    printf '    %b%s%b.%s\n' "${C_BOLD}" "$num" "${C_RESET}" "${line#*.}"
                elif [[ "$line" =~ ^\>[[:space:]] ]]; then
                    printf '  %b%s%b\n' "${C_DIM}" "$line" "${C_RESET}"
                else
                    if [[ "$line" =~ ^[[:space:]]{4} ]]; then
                        printf '    %b\$%b %b%s%b\n' "${C_DIM}" "${C_RESET}" "${C_CYAN}" "${line#    }" "${C_RESET}"
                    else
                        printf '  %s\n' "$line"
                    fi
                fi
                ;;
        esac
    done <<< "$content"

    echo
}

# ── 运行验证脚本 ───────────────────────────────────
guide_run_check() {
    local step_num="$1"
    local check_file="$GUIDE_LAB_DIR/checks/check-$(printf '%02d' "$step_num").sh"

    if [[ -f "$check_file" && -x "$check_file" ]]; then
        echo
        echo -e "${C_BOLD}${C_YELLOW}  ── 自动验证 ──${C_RESET}"
        if bash "$check_file"; then
            ui_success "验证通过！"
            return 0
        else
            ui_warn "验证未通过，请检查你的操作是否正确。"
            ui_dim "  你可以选择: [Enter] 跳过验证继续  [r] 重新验证"
            read -r choice
            if [[ "$choice" == "r" ]]; then
                guide_run_check "$step_num"
            fi
            return 0  # 允许跳过
        fi
    fi
    return 0
}

# ── 显示提示 ───────────────────────────────────────
guide_show_hint() {
    local step_num="$1"
    local step_padded; step_padded=$(printf '%02d' "$step_num")
    local hints_dir="$GUIDE_LAB_DIR/hints"

    GUIDE_HINT_COUNT=$((GUIDE_HINT_COUNT + 1))
    progress_record_hint "$GUIDE_LAB_ID"

    # 渐进式: hint1 → hint2 → solution
    if [[ $GUIDE_HINT_COUNT -eq 1 ]]; then
        local hint_file="$hints_dir/${step_padded}-hint1.md"
        if [[ -f "$hint_file" ]]; then
            echo
            echo -e "${C_BOLD}${C_YELLOW}  ━━━ 提示 1/${HINT_LEVEL} ━━━${C_RESET}"
            cat "$hint_file" | while IFS= read -r line; do echo -e "  ${C_YELLOW}${line}${C_RESET}"; done
            echo
        else
            ui_warn "此步骤暂无提示。"
            echo
        fi
    elif [[ $GUIDE_HINT_COUNT -eq 2 ]]; then
        local hint_file="$hints_dir/${step_padded}-hint2.md"
        if [[ -f "$hint_file" ]]; then
            echo
            echo -e "${C_BOLD}${C_YELLOW}  ━━━ 提示 2/${HINT_LEVEL} ━━━${C_RESET}"
            cat "$hint_file" | while IFS= read -r line; do echo -e "  ${C_YELLOW}${line}${C_RESET}"; done
            echo
        else
            # 如果 hint2 不存在，直接给 solution
            guide_show_solution "$step_num"
            return
        fi
    else
        guide_show_solution "$step_num"
        return
    fi
}

guide_show_solution() {
    local step_num="$1"
    local step_padded; step_padded=$(printf '%02d' "$step_num")
    local solution_file="$GUIDE_LAB_DIR/hints/${step_padded}-solution.md"

    GUIDE_SOLUTION_VIEWED=true
    progress_record_solution "$GUIDE_LAB_ID"

    if [[ -f "$solution_file" ]]; then
        echo
        echo -e "${C_BOLD}${C_RED}  ━━━ 完整答案 ━━━${C_RESET}"
        if [[ "$SOLUTION_ENABLED" != "true" ]]; then
            echo -e "  ${C_RED}教师已禁用直接查看答案。请向老师寻求帮助。${C_RESET}"
        else
            cat "$solution_file" | while IFS= read -r line; do echo -e "  ${C_DIM}${line}${C_RESET}"; done
        fi
        echo
    fi
}

# ── 主引导循环 ─────────────────────────────────────
guide_run() {
    local current; current=$(progress_lab_current_step "$GUIDE_LAB_ID")
    current=${current:-0}

    # 找到下一个未完成的步骤
    local next_step=$((current + 1))
    if [[ $next_step -gt $GUIDE_TOTAL_STEPS ]]; then
        next_step=$GUIDE_TOTAL_STEPS
    fi

    while [[ $next_step -le $GUIDE_TOTAL_STEPS ]]; do
        GUIDE_CURRENT_STEP=$next_step

        # 如果已经完成，检查下一步
        if progress_is_step_done "$GUIDE_LAB_ID" "$(printf '%02d' "$next_step")"; then
            next_step=$((next_step + 1))
            continue
        fi

        # 显示当前步骤
        guide_show_step "$next_step"

        # 交互提示
        echo -ne "  ${C_DIM}[Enter] 继续  [h] 提示  [b] 上一步  [q] 退出${C_RESET}"

        local choice
        read -r choice

        case "$choice" in
            h|H)
                guide_show_hint "$next_step"
                continue  # 重新显示当前步骤
                ;;
            b|B)
                if [[ $next_step -gt 1 ]]; then
                    next_step=$((next_step - 1))
                fi
                continue
                ;;
            q|Q)
                echo
                ui_info "进度已保存。下次运行 ./student.sh 继续。"
                return 0
                ;;
        esac

        # 运行验证
        guide_run_check "$next_step"

        # 标记完成
        local step_id; step_id=$(printf '%02d' "$next_step")
        progress_mark_step_done "$GUIDE_LAB_ID" "$step_id"

        # 显示步骤完成
        echo
        ui_success "步骤 ${next_step}/${GUIDE_TOTAL_STEPS} 完成！"

        # 如果是最后一步，完成实验
        if [[ $next_step -eq $GUIDE_TOTAL_STEPS ]]; then
            guide_finish_lab
            return 0
        fi

        ui_press_enter "按 Enter 进入下一步..."
        next_step=$((next_step + 1))
    done

    # 所有步骤已完成
    guide_finish_lab
}

# ── 完成实验 ───────────────────────────────────────
guide_finish_lab() {
    progress_complete_lab "$GUIDE_LAB_ID"
    progress_unlock_next "$GUIDE_LAB_ID"

    ui_clear
    ui_box_start
    ui_box_line "🎉 实验完成！" "center"
    ui_box_sep
    ui_box_line "$GUIDE_LAB_TITLE — 全部 ${GUIDE_TOTAL_STEPS} 步已完成" "center"
    ui_box_sep
    ui_box_line "提示次数: ${GUIDE_HINT_COUNT}  |  查看答案: $([ "$GUIDE_SOLUTION_VIEWED" = true ] && echo '是' || echo '否')" "center"
    ui_box_end

    echo
    # 生成提交文件
    local student_name; student_name=$(progress_get "STUDENT_NAME")
    local submit_file; submit_file=$(progress_generate_submit "$GUIDE_LAB_ID" "${student_name:-kali}")
    ui_success "提交文件已生成: submit/$(basename "$submit_file")"
    ui_info "请将此文件提交给老师。"

    echo
    ui_press_enter "按 Enter 返回..."
}

# ── 显示实验总览（步骤列表） ───────────────────────
guide_show_overview() {
    ui_clear
    echo
    echo -e "  ${C_BOLD}${C_CYAN}━━━ ${GUIDE_LAB_TITLE} ━━━${C_RESET}"
    echo

    local current; current=$(progress_lab_current_step "$GUIDE_LAB_ID")
    current=${current:-0}

    local i=1
    for title in "${GUIDE_STEP_TITLES[@]}"; do
        local icon
        if progress_is_step_done "$GUIDE_LAB_ID" "$(printf '%02d' "$i")"; then
            icon="✅"
        elif [[ $i -eq $((current + 1)) ]]; then
            icon="▶"
        else
            icon="⬜"
        fi
        echo -e "  ${C_BOLD}${icon}${C_RESET} ${title}"
        i=$((i + 1))
    done

    echo
    echo -ne "  ${C_DIM}[Enter] 继续  [q] 返回${C_RESET}"
    read -r
}

# ── 入口：开始引导 ─────────────────────────────────
guide_start() {
    # 参数校验
    if [[ -z "${1:-}" ]]; then
        ui_error "用法: guide_start <lab_id> <lab_title>"
        return 1
    fi

    GUIDE_LAB_ID="$1"
    GUIDE_LAB_TITLE="${2:-$1}"

    # 找到实验目录
    local labs_dir="$CYBER_PRACTICE_ROOT/labs"
    GUIDE_LAB_DIR=$(find "$labs_dir" -maxdepth 1 -type d -name "${GUIDE_LAB_ID}*" | head -1)
    if [[ -z "$GUIDE_LAB_DIR" ]]; then
        ui_error "找不到实验目录: $GUIDE_LAB_ID"
        return 1
    fi

    # 初始化
    progress_init
    load_teacher_config

    # ── 从 Git 拉取最新加密文件 ──────────────────
    if crypto_is_encrypted "$GUIDE_LAB_DIR"; then
        local updated_from_git=false
        if command -v git &>/dev/null; then
            local git_dir; git_dir=$(cd "$CYBER_PRACTICE_ROOT" && git rev-parse --show-toplevel 2>/dev/null)
            if [[ -n "$git_dir" ]]; then
                echo
                ui_info "正在检查实验更新..."
                if cd "$git_dir" && git fetch origin 2>/dev/null; then
                    # 拉取该实验的最新 .enc 文件
                    local lab_glob="labs/${GUIDE_LAB_ID}*"
                    if git checkout "origin/main" -- "$lab_glob"/*.enc 2>/dev/null; then
                        ui_success "已同步最新版本！"
                    fi
                else
                    ui_dim "  无法连接网络，使用本地版本。"
                fi
                cd "$CYBER_PRACTICE_ROOT"
            fi
        fi

        # 提示输入密码解密
        echo
        ui_info "请输入老师提供的密码来解锁此实验："
        echo -ne "  > "
        read -r pwd
        if [[ -z "$pwd" ]]; then
            ui_error "密码不能为空。"
            ui_press_enter
            return 1
        fi
        if ! crypto_decrypt_lab "$GUIDE_LAB_DIR" "$pwd"; then
            ui_error "密码错误！请检查后重试。"
            ui_press_enter
            return 1
        fi
        ui_success "实验已解锁！开始学习吧。"
        ui_press_enter
    fi

    guide_load_steps

    # 如果实验未开始，初始化
    local status; status=$(progress_lab_status "$GUIDE_LAB_ID")
    if [[ "$status" != "in_progress" && "$status" != "completed" ]]; then
        progress_start_lab "$GUIDE_LAB_ID" "$GUIDE_TOTAL_STEPS"
    fi

    # 如果已完成，显示总结
    if [[ "$status" == "completed" ]]; then
        guide_show_overview
        ui_info "此实验已完成。回顾完毕。"
        ui_press_enter
        return 0
    fi

    # 加载提示计数
    GUIDE_HINT_COUNT=$(progress_lab_hints "$GUIDE_LAB_ID")
    GUIDE_SOLUTION_VIEWED=$(progress_lab_solution "$GUIDE_LAB_ID")
    [[ "$GUIDE_SOLUTION_VIEWED" == "true" ]] && GUIDE_SOLUTION_VIEWED=true || GUIDE_SOLUTION_VIEWED=false

    # 运行引导
    guide_run
}
