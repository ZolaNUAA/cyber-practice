#!/usr/bin/env bash
# student.sh — 学生入口
# 用法: cd ~/cyber-practice && ./student.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CYBER_PRACTICE_ROOT="$SCRIPT_DIR"

source "$SCRIPT_DIR/lib/progress-lib.sh"
source "$SCRIPT_DIR/lib/ui-utils.sh"

# ── 初始化 ─────────────────────────────────────────
progress_init
progress_init_all_labs

# ── 获取当前进行中的实验 ──────────────────────────
get_current_lab() {
    while IFS='|' read -r lab status current steps; do
        if [[ "$status" == "in_progress" ]]; then
            echo "$lab"
            return
        fi
    done < <(progress_get_all_labs)

    # 没有进行中的，找第一个未锁定/未完成的
    while IFS='|' read -r lab status current steps; do
        if [[ "$status" == "unlocked" ]]; then
            echo "$lab"
            return
        fi
    done < <(progress_get_all_labs)

    echo ""
}

# ── 启动实验引导 ───────────────────────────────────
launch_lab() {
    local lab="$1"
    local lab_dir; lab_dir=$(find "$CYBER_PRACTICE_ROOT/labs" -maxdepth 1 -type d -name "${lab}*" | head -1)

    if [[ -z "$lab_dir" ]]; then
        ui_error "找不到实验: $lab"
        ui_press_enter
        return 1
    fi

    local guide_script="$lab_dir/guide.sh"
    if [[ -f "$guide_script" ]]; then
        bash "$guide_script"
    else
        ui_warn "此实验暂无引导脚本，请直接查看 README.md"
        ui_press_enter
    fi
}

# ── 回顾已完成的实验 ──────────────────────────────
review_lab() {
    local lab="$1"
    local status; status=$(progress_lab_status "$lab")

    if [[ "$status" != "completed" && "$status" != "in_progress" ]]; then
        ui_warn "此实验尚未完成或未解锁。"
        ui_press_enter
        return
    fi

    launch_lab "$lab"
}

# ── 首次启动提示 ──────────────────────────────────
show_welcome() {
    local started_at; started_at=$(progress_get "STARTED_AT")
    if [[ -z "$started_at" || "$started_at" == '""' ]]; then
        ui_clear
        ui_header "欢迎来到 Cyber Practice 实验中心"
        echo -e "  ${C_BOLD}使用说明${C_RESET}"
        echo
        echo -e "  • 每个实验分多个步骤，按顺序逐步解锁"
        echo -e "  • 每步先讲${C_BOLD}原理${C_RESET}（为什么），再给${C_BOLD}操作${C_RESET}（怎么做）"
        echo -e "  • 卡住时按 ${C_BOLD}h${C_RESET} 获取提示"
        echo -e "  • 完成实验后自动生成提交文件"
        echo
        echo -e "  ${C_DIM}所有操作限制在 127.0.0.1 本地环境。${C_RESET}"
        echo -e "  ${C_DIM}禁止扫描外部网络或他人机器。${C_RESET}"
        echo
        ui_press_enter "按 Enter 开始..."
        progress_set "STARTED_AT" "$(date -Iseconds)"
    fi
}

# ── 学生姓名设置（首次） ──────────────────────────
ensure_student_name() {
    local name; name=$(progress_get "STUDENT_NAME")
    if [[ -z "$name" || "$name" == '""' || "$name" == "kali" ]]; then
        ui_clear
        echo
        echo -e "  ${C_BOLD}请输入你的姓名（用于提交文件）:${C_RESET}"
        echo -ne "  > "
        read -r name
        if [[ -n "$name" ]]; then
            progress_set "STUDENT_NAME" "$name"
        fi
    fi
}

# ── 主循环 ─────────────────────────────────────────
main() {
    show_welcome
    ensure_student_name

    local student_name; student_name=$(progress_get "STUDENT_NAME")

    while true; do
        ui_clear

        echo -e "${C_BOLD}${C_CYAN}╔════════════════════════════════════════════════╗${C_RESET}"
        echo -e "${C_BOLD}${C_CYAN}║${C_RESET}         ${C_BOLD}🔐 Cyber Practice 实验中心${C_RESET}              ${C_BOLD}${C_CYAN}║${C_RESET}"
        echo -e "${C_BOLD}${C_CYAN}║${C_RESET}  ${C_DIM}学生: ${student_name}${C_RESET}                                  ${C_BOLD}${C_CYAN}║${C_RESET}"
        echo -e "${C_BOLD}${C_CYAN}╚════════════════════════════════════════════════╝${C_RESET}"

        local overall; overall=$(progress_overall)
        local completed; completed=$(echo "$overall" | cut -d' ' -f1)
        local total; total=$(echo "$overall" | cut -d' ' -f2)
        echo
        echo -ne "  ${C_BOLD}📊 整体进度: ${completed}/${total}${C_RESET}  "
        ui_progress_bar "$completed" "$total" 24
        echo; echo

        # 显示所有实验
        while IFS='|' read -r lab status current steps; do
            local title; title=$(progress_lab_title "$lab")
            local icon line
            case "$status" in
                completed)
                    echo -e "  ${C_GREEN}✅ ${lab}${C_RESET}  ${C_BOLD}${title}${C_RESET}"
                    ;;
                in_progress)
                    echo -e "  ${C_CYAN}▶ ${lab}${C_RESET}  ${C_BOLD}${title}${C_RESET}  ${C_DIM}[步骤 ${current}/${steps}]${C_RESET}"
                    ;;
                unlocked)
                    echo -e "  ${C_YELLOW}🔓 ${lab}${C_RESET}  ${title}  ${C_DIM}[可开始]${C_RESET}"
                    ;;
                *)
                    echo -e "  ${C_DIM}🔒 ${lab}  ${title}${C_RESET}"
                    ;;
            esac
        done < <(progress_get_all_labs)

        echo
        echo -e "  ${C_DIM}────────────────────────────────────────────${C_RESET}"

        local current_lab; current_lab=$(get_current_lab)
        if [[ -n "$current_lab" ]]; then
            echo -e "  ${C_BOLD}[Enter]${C_RESET} 继续实验  ${C_DIM}[数字]${C_RESET} 回顾  ${C_DIM}[r]${C_RESET} 刷新  ${C_DIM}[q]${C_RESET} 退出"
        else
            echo -e "  ${C_DIM}[数字]${C_RESET} 回顾  ${C_DIM}[r]${C_RESET} 刷新  ${C_DIM}[q]${C_RESET} 退出"
        fi

        echo -ne "  > "
        read -r choice

        case "$choice" in
            q|Q)
                echo
                ui_info "进度已保存。再见！"
                exit 0
                ;;
            r|R)
                continue
                ;;
            "")
                if [[ -n "$current_lab" ]]; then
                    launch_lab "$current_lab"
                fi
                ;;
            *)
                # 尝试匹配实验编号
                local lab_id
                if [[ "$choice" =~ ^[0-9]+$ ]]; then
                    lab_id=$(printf "lab%02d" "$((10#$choice))")
                elif [[ "$choice" =~ ^lab[0-9]+$ ]]; then
                    lab_id="$choice"
                else
                    ui_warn "无效输入: $choice"
                    ui_press_enter
                    continue
                fi
                local lab_status; lab_status=$(progress_lab_status "$lab_id")
                if [[ "$lab_status" == "completed" || "$lab_status" == "in_progress" ]]; then
                    review_lab "$lab_id"
                elif [[ "$lab_status" == "unlocked" ]]; then
                    launch_lab "$lab_id"
                else
                    ui_warn "实验 ${lab_id} 尚未解锁。请先完成前面的实验。"
                    ui_press_enter
                fi
                ;;
        esac
    done
}

main "$@"
