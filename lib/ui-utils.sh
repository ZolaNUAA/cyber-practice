#!/usr/bin/env bash
# ui-utils.sh — 终端UI工具库
# 提供颜色、盒子、进度条、表格、分步显示等功能

# ── 颜色定义 ───────────────────────────────────────
if [[ -t 1 ]]; then
    C_RESET='\033[0m'
    C_BOLD='\033[1m'
    C_DIM='\033[2m'
    C_RED='\033[31m'
    C_GREEN='\033[32m'
    C_YELLOW='\033[33m'
    C_BLUE='\033[34m'
    C_MAGENTA='\033[35m'
    C_CYAN='\033[36m'
    C_WHITE='\033[37m'
    C_BG_GREEN='\033[42m'
    C_BG_BLUE='\033[44m'
    C_BG_YELLOW='\033[43m'
    C_BG_RED='\033[41m'
else
    C_RESET=''; C_BOLD=''; C_DIM=''; C_RED=''; C_GREEN=''; C_YELLOW=''
    C_BLUE=''; C_MAGENTA=''; C_CYAN=''; C_WHITE=''
    C_BG_GREEN=''; C_BG_BLUE=''; C_BG_YELLOW=''; C_BG_RED=''
fi

# ── 基础输出 ───────────────────────────────────────
ui_icon_ok()    { echo -e "${C_GREEN}✅${C_RESET} $*"; }
ui_icon_fail()  { echo -e "${C_RED}❌${C_RESET} $*"; }
ui_icon_info()  { echo -e "${C_BLUE}💡${C_RESET} $*"; }
ui_icon_warn()  { echo -e "${C_YELLOW}⚠️${C_RESET} $*"; }
ui_icon_lock()  { echo -e "${C_DIM}🔒${C_RESET}"; }
ui_icon_active(){ echo -e "${C_GREEN}▶${C_RESET}"; }
ui_icon_done()  { echo -e "${C_GREEN}✅${C_RESET}"; }
ui_icon_todo()  { echo -e "${C_DIM}⬜${C_RESET}"; }

ui_success() { echo -e "${C_GREEN}${C_BOLD}✓${C_RESET} ${C_GREEN}$*${C_RESET}"; }
ui_error()   { echo -e "${C_RED}${C_BOLD}✗${C_RESET} ${C_RED}$*${C_RESET}"; }
ui_info()    { echo -e "${C_BLUE}ℹ${C_RESET}  $*"; }
ui_warn()    { echo -e "${C_YELLOW}⚠${C_RESET}  ${C_YELLOW}$*${C_RESET}"; }
ui_dim()     { echo -e "${C_DIM}$*${C_RESET}"; }

# ── 盒子标题 ───────────────────────────────────────
ui_header() {
    local title="$1"
    local width=48
    echo
    echo -e "${C_BOLD}${C_CYAN}╔$(printf '═%.0s' $(seq 1 $width))╗${C_RESET}"
    echo -e "${C_BOLD}${C_CYAN}║${C_RESET}  ${C_BOLD}${title}${C_RESET}$(printf ' %.0s' $(seq 1 $((width - ${#title} - 3))))${C_BOLD}${C_CYAN}║${C_RESET}"
    echo -e "${C_BOLD}${C_CYAN}╚$(printf '═%.0s' $(seq 1 $width))╝${C_RESET}"
    echo
}

ui_box_start() {
    local width=48
    echo -e "${C_BOLD}${C_CYAN}╔$(printf '═%.0s' $(seq 1 $width))╗${C_RESET}"
}
ui_box_line() {
    local text="$1" align="${2:-left}"
    local width=48
    local visible_len=${#text}
    local padding=$((width - visible_len - 2))
    [[ $padding -lt 0 ]] && padding=0
    if [[ "$align" == "center" ]]; then
        local left=$((padding / 2))
        local right=$((padding - left))
        echo -e "${C_BOLD}${C_CYAN}║${C_RESET}$(printf ' %.0s' $(seq 1 $left))${text}$(printf ' %.0s' $(seq 1 $right))${C_BOLD}${C_CYAN}║${C_RESET}"
    else
        echo -e "${C_BOLD}${C_CYAN}║${C_RESET} ${text}$(printf ' %.0s' $(seq 1 $((padding))))${C_BOLD}${C_CYAN}║${C_RESET}"
    fi
}
ui_box_end() {
    local width=48
    echo -e "${C_BOLD}${C_CYAN}╚$(printf '═%.0s' $(seq 1 $width))╝${C_RESET}"
}
ui_box_sep() {
    local width=48
    echo -e "${C_BOLD}${C_CYAN}╟$(printf '─%.0s' $(seq 1 $width))╢${C_RESET}"
}

# ── 进度条 ─────────────────────────────────────────
ui_progress_bar() {
    local current="$1" total="$2" width="${3:-20}" label="${4:-}"
    local filled=$((current * width / total))
    local empty=$((width - filled))
    local pct=$((current * 100 / total))

    printf "${C_BOLD}"
    [[ -n "$label" ]] && printf "  %-12s " "$label"
    printf "["
    printf "${C_BG_GREEN}%${filled}s${C_RESET}${C_BOLD}" | sed "s/ /█/g"
    printf "%${empty}s" | sed "s/ /░/g"
    printf "] %3d%%${C_RESET}" "$pct"
}

# ── 步骤清单 ───────────────────────────────────────
ui_step_list() {
    local current="$1"; shift
    local i=1 step_title
    for step_title in "$@"; do
        local icon
        if [[ $i -lt $current ]]; then
            icon="✅"
        elif [[ $i -eq $current ]]; then
            icon="▶"
        else
            icon="⬜"
        fi
        printf "  ${C_BOLD}%s${C_RESET} %s\n" "$icon" "$step_title"
        i=$((i + 1))
    done
}

# ── 实验总览表格 ───────────────────────────────────
ui_lab_overview() {
    local completed=0 total=0
    local lines=()
    while IFS='|' read -r lab status current steps; do
        total=$((total + 1))
        local title; title=$(progress_lab_title "$lab")
        local icon line
        case "$status" in
            completed)
                icon="✅"; line="  ${C_GREEN}${icon} ${lab}${C_RESET}  ${C_BOLD}${title}${C_RESET}"
                completed=$((completed + 1))
                ;;
            in_progress)
                icon="▶";  line="  ${C_CYAN}${icon} ${lab}${C_RESET}  ${C_BOLD}${title}${C_RESET}  ${C_DIM}[步骤 ${current}/${steps}]${C_RESET}"
                ;;
            unlocked)
                icon="🔓"; line="  ${C_YELLOW}${icon} ${lab}${C_RESET}  ${title}  ${C_DIM}[未开始]${C_RESET}"
                ;;
            *)
                icon="🔒"; line="  ${C_DIM}${icon} ${lab}  ${title}${C_RESET}"
                ;;
        esac
        lines+=("$line")
    done < <(progress_get_all_labs)

    echo
    echo -e "  ${C_BOLD}📊 整体进度: ${completed}/${total} — $((completed * 100 / total))%${C_RESET}"
    ui_progress_bar "$completed" "$total" 24
    echo; echo
    for line in "${lines[@]}"; do
        echo -e "$line"
    done
}

# ── 分节显示 ───────────────────────────────────────
ui_section_why() {
    echo
    echo -e "${C_BOLD}${C_BLUE}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "${C_BOLD}${C_BLUE}  💡 为什么${C_RESET}"
    echo -e "${C_BOLD}${C_BLUE}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo
}

ui_section_do() {
    echo
    echo -e "${C_BOLD}${C_GREEN}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "${C_BOLD}${C_GREEN}  🛠️ 操作${C_RESET}"
    echo -e "${C_BOLD}${C_GREEN}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo
}

ui_section_check() {
    echo
    echo -e "${C_BOLD}${C_YELLOW}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo -e "${C_BOLD}${C_YELLOW}  ✅ 验证${C_RESET}"
    echo -e "${C_BOLD}${C_YELLOW}  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_RESET}"
    echo
}

# ── 按键等待 ───────────────────────────────────────
ui_press_enter() {
    local prompt="${1:-按 Enter 继续...}"
    echo
    echo -ne "${C_DIM}  ${prompt}${C_RESET}"
    read -r
}

ui_any_key() {
    local prompt="${1:-按任意键...}"
    echo -ne "${C_DIM}  ${prompt}${C_RESET}"
    read -rn 1
}

# ── 清屏 ───────────────────────────────────────────
ui_clear() {
    clear 2>/dev/null || printf '\033[2J\033[H'
}

# ── 分隔线 ─────────────────────────────────────────
ui_divider() {
    local char="${1:-─}"
    printf "${C_DIM}  %s${C_RESET}\n" "$(printf "${char}%.0s" $(seq 1 46))"
}

# ── 显示 Markdown 内容（简单解析） ─────────────────
ui_render_md() {
    local content="$1"
    local in_code=false
    while IFS= read -r line; do
        # 跳过空行（在代码块外）
        if [[ -z "$line" && "$in_code" == "false" ]]; then
            echo
            continue
        fi
        # 代码块
        if [[ "$line" == '```'* ]]; then
            if $in_code; then
                in_code=false
            else
                in_code=true
            fi
            continue
        fi
        if $in_code; then
            echo -e "    ${C_DIM}\$${C_RESET} ${C_CYAN}${line}${C_RESET}"
            continue
        fi
        # 标题
        if [[ "$line" =~ ^###[[:space:]]+(.*) ]]; then
            echo -e "\n  ${C_BOLD}${BASH_REMATCH[1]}${C_RESET}"
        elif [[ "$line" =~ ^##[[:space:]]+(.*) ]]; then
            echo -e "\n  ${C_BOLD}${C_YELLOW}${BASH_REMATCH[1]}${C_RESET}"
        elif [[ "$line" =~ ^#[[:space:]]+(.*) ]]; then
            echo -e "\n  ${C_BOLD}${C_CYAN}${BASH_REMATCH[1]}${C_RESET}"
        # 列表
        elif [[ "$line" =~ ^[[:space:]]*[-*][[:space:]]+(.*) ]]; then
            echo -e "    ${C_BOLD}•${C_RESET} ${BASH_REMATCH[1]}"
        elif [[ "$line" =~ ^[[:space:]]*[0-9]+\.([[:space:]]+(.*))? ]]; then
            echo -e "    ${C_BOLD}${line%%\.*}${C_RESET}.${BASH_REMATCH[1]}"
        # 引用
        elif [[ "$line" =~ ^\>[[:space:]]*(.*) ]]; then
            echo -e "  ${C_DIM}│ ${BASH_REMATCH[1]}${C_RESET}"
        # 普通文本
        else
            echo -e "  $line"
        fi
    done <<< "$content"
}
