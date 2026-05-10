#!/usr/bin/env bash
# progress-lib.sh — 进度状态读写库
# 使用 bash-sourceable 的 key=value 格式，无需 jq 依赖

PROGRESS_DIR="${CYBER_PRACTICE_ROOT:-$HOME/cyber-practice}/.progress"
STATE_FILE="$PROGRESS_DIR/state"

# ── 初始化 ──────────────────────────────────────────
progress_init() {
    mkdir -p "$PROGRESS_DIR"
    if [[ ! -f "$STATE_FILE" ]]; then
        cat > "$STATE_FILE" <<'EOF'
STUDENT_NAME="kali"
VERSION="2.0"
STARTED_AT=""
EOF
        progress_set "STARTED_AT" "$(date -Iseconds)"
    fi
    # shellcheck source=/dev/null
    source "$STATE_FILE"
}

# ── 读写单值 ───────────────────────────────────────
progress_set() {
    local key="$1" value="$2"
    if grep -q "^${key}=" "$STATE_FILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$STATE_FILE"
    else
        echo "${key}=\"${value}\"" >> "$STATE_FILE"
    fi
}

progress_get() {
    local key="$1"
    source "$STATE_FILE" 2>/dev/null
    echo "${!key:-}"
}

# ── Lab 状态操作 ───────────────────────────────────
progress_lab_status() {
    local lab="$1"
    progress_get "LAB_STATUS_${lab//-/_}"
}

progress_lab_current_step() {
    local lab="$1"
    progress_get "LAB_CURRENT_${lab//-/_}"
}

progress_lab_total_steps() {
    local lab="$1"
    progress_get "LAB_TOTAL_${lab//-/_}"
}

progress_lab_hints() {
    local lab="$1"
    local v; v=$(progress_get "LAB_HINTS_${lab//-/_}")
    echo "${v:-0}"
}

progress_lab_solution() {
    local lab="$1"
    local v; v=$(progress_get "LAB_SOLUTION_${lab//-/_}")
    echo "${v:-false}"
}

progress_lab_started_at() {
    local lab="$1"
    progress_get "LAB_STARTED_${lab//-/_}"
}

progress_lab_completed_at() {
    local lab="$1"
    progress_get "LAB_COMPLETED_AT_${lab//-/_}"
}

# ── 步骤完成标记 ──────────────────────────────────
progress_mark_step_done() {
    local lab="$1" step="$2"
    local safe_lab="${lab//-/_}"
    local done_list
    done_list=$(progress_get "LAB_STEPS_DONE_${safe_lab}")
    # 避免重复
    if [[ " $done_list " != *" $step "* ]]; then
        done_list="${done_list} ${step}"
        progress_set "LAB_STEPS_DONE_${safe_lab}" "$done_list"
        progress_set "LAB_CURRENT_${safe_lab}" "$step"
    fi
}

progress_is_step_done() {
    local lab="$1" step="$2"
    local safe_lab="${lab//-/_}"
    local done_list
    done_list=$(progress_get "LAB_STEPS_DONE_${safe_lab}")
    [[ " $done_list " == *" $step "* ]]
}

# ── 实验级别操作 ──────────────────────────────────
progress_start_lab() {
    local lab="$1" total_steps="$2"
    local safe_lab="${lab//-/_}"
    progress_set "LAB_STATUS_${safe_lab}" "in_progress"
    progress_set "LAB_TOTAL_${safe_lab}" "$total_steps"
    progress_set "LAB_CURRENT_${safe_lab}" "0"
    progress_set "LAB_STEPS_DONE_${safe_lab}" ""
    progress_set "LAB_HINTS_${safe_lab}" "0"
    progress_set "LAB_SOLUTION_${safe_lab}" "false"
    progress_set "LAB_STARTED_${safe_lab}" "$(date -Iseconds)"
    progress_set "LAB_COMPLETED_AT_${safe_lab}" ""
}

progress_complete_lab() {
    local lab="$1"
    local safe_lab="${lab//-/_}"
    progress_set "LAB_STATUS_${safe_lab}" "completed"
    progress_set "LAB_COMPLETED_AT_${safe_lab}" "$(date -Iseconds)"
}

progress_record_hint() {
    local lab="$1"
    local safe_lab="${lab//-/_}"
    local current; current=$(progress_lab_hints "$lab")
    progress_set "LAB_HINTS_${safe_lab}" "$((current + 1))"
}

progress_record_solution() {
    local lab="$1"
    local safe_lab="${lab//-/_}"
    progress_set "LAB_SOLUTION_${safe_lab}" "true"
}

# ── 解锁下一个实验 ────────────────────────────────
progress_unlock_next() {
    local current_lab="$1"
    local lab_num="${current_lab#lab}"
    lab_num=$((10#${lab_num} + 1))
    local next_lab
    next_lab=$(printf "lab%02d" "$lab_num")
    # 如果下一个实验目录存在，解锁它
    if [[ -d "${CYBER_PRACTICE_ROOT:-$HOME/cyber-practice}/labs/${next_lab}"* ]]; then
        local status; status=$(progress_lab_status "$next_lab")
        if [[ "$status" == "locked" || -z "$status" ]]; then
            progress_set "LAB_STATUS_${next_lab//-/_}" "unlocked"
        fi
    fi
}

# 手动解锁指定实验（教师功能）
progress_force_unlock() {
    local lab="$1"
    local safe_lab="${lab//-/_}"
    local status; status=$(progress_lab_status "$lab")
    if [[ "$status" == "locked" || -z "$status" ]]; then
        progress_set "LAB_STATUS_${safe_lab}" "unlocked"
    fi
}

# ── 首次初始化所有实验状态 ────────────────────────
progress_init_all_labs() {
    local labs_dir="${CYBER_PRACTICE_ROOT:-$HOME/cyber-practice}/labs"
    local first=true
    for lab_dir in "$labs_dir"/lab*/; do
        local dirname; dirname=$(basename "$lab_dir")
        # 提取纯数字前缀: lab04-sqli → lab04
        local lab="${dirname%%-*}"
        local safe_lab="${lab//-/_}"
        local status; status=$(progress_lab_status "$lab")
        if [[ -z "$status" ]]; then
            if $first; then
                progress_set "LAB_STATUS_${safe_lab}" "unlocked"
                first=false
            else
                progress_set "LAB_STATUS_${safe_lab}" "locked"
            fi
        fi
    done
}

# ── 获取所有实验概览 ──────────────────────────────
progress_get_all_labs() {
    local labs_dir="${CYBER_PRACTICE_ROOT:-$HOME/cyber-practice}/labs"
    for lab_dir in "$labs_dir"/lab*/; do
        local dirname; dirname=$(basename "$lab_dir")
        local lab="${dirname%%-*}"
        local status; status=$(progress_lab_status "$lab")
        status="${status:-locked}"
        local current; current=$(progress_lab_current_step "$lab")
        local total; total=$(progress_lab_total_steps "$lab")
        echo "${lab}|${status}|${current:-0}|${total:-0}"
    done | sort
}

# ── 获取整体进度数字 ──────────────────────────────
progress_overall() {
    local completed=0 total=0
    while IFS='|' read -r lab status current steps; do
        total=$((total + 1))
        [[ "$status" == "completed" ]] && completed=$((completed + 1))
    done < <(progress_get_all_labs)
    echo "$completed $total"
}

# ── 获取实验标题（从 labs 目录名提取） ──────────
progress_lab_title() {
    local lab="$1"
    local labs_dir="${CYBER_PRACTICE_ROOT:-$HOME/cyber-practice}/labs"
    local lab_dir
    lab_dir=$(find "$labs_dir" -maxdepth 1 -type d -name "${lab}*" | head -1)
    if [[ -n "$lab_dir" ]]; then
        # 从目录名提取标题: lab04-sqli → SQL注入
        local dirname; dirname=$(basename "$lab_dir")
        echo "${dirname#*-}"
    else
        echo "$lab"
    fi
}

# ── 生成提交文件 ──────────────────────────────────
progress_generate_submit() {
    local lab="$1" student_name="${2:-kali}"
    local submit_dir="${CYBER_PRACTICE_ROOT:-$HOME/cyber-practice}/submit"
    mkdir -p "$submit_dir"

    local completed_at; completed_at=$(progress_lab_completed_at "$lab")
    local started_at; started_at=$(progress_lab_started_at "$lab")
    local hints; hints=$(progress_lab_hints "$lab")
    local solution; solution=$(progress_lab_solution "$lab")
    local total; total=$(progress_lab_total_steps "$lab")

    local timestamp; timestamp=$(date +%Y%m%d-%H%M%S)
    local submit_file="$submit_dir/${lab}-${student_name}-${timestamp}.json"

    cat > "$submit_file" <<EOF
{
  "student": "${student_name}",
  "lab": "${lab}",
  "title": "$(progress_lab_title "$lab")",
  "version": "2.0",
  "completed_at": "${completed_at}",
  "started_at": "${started_at}",
  "total_steps": ${total},
  "hints_used": ${hints},
  "solution_viewed": ${solution}
}
EOF
    echo "$submit_file"
}

# ── 密码管理（实验加密解密用） ────────────────────
PASSWORD_FILE="$PROGRESS_DIR/passwords"

progress_set_password() {
    local lab="$1" password="$2"
    local safe_lab="${lab//-/_}"
    mkdir -p "$PROGRESS_DIR"
    if grep -q "^${safe_lab}=" "$PASSWORD_FILE" 2>/dev/null; then
        sed -i "s|^${safe_lab}=.*|${safe_lab}=${password}|" "$PASSWORD_FILE"
    else
        echo "${safe_lab}=${password}" >> "$PASSWORD_FILE"
    fi
    chmod 600 "$PASSWORD_FILE" 2>/dev/null || true
}

progress_get_password() {
    local lab="$1"
    local safe_lab="${lab//-/_}"
    if [[ -f "$PASSWORD_FILE" ]]; then
        grep "^${safe_lab}=" "$PASSWORD_FILE" 2>/dev/null | cut -d'=' -f2
    fi
}

# 完成实验后自动写入下一个实验的密码
progress_unlock_next_with_password() {
    local current_lab="$1"
    local lab_num="${current_lab#lab}"
    lab_num=$((10#${lab_num} + 1))
    local next_lab; next_lab=$(printf "lab%02d" "$lab_num")

    # 解锁
    if [[ -d "${CYBER_PRACTICE_ROOT:-$HOME/cyber-practice}/labs/${next_lab}"* ]]; then
        local status; status=$(progress_lab_status "$next_lab")
        if [[ "$status" == "locked" || -z "$status" ]]; then
            progress_set "LAB_STATUS_${next_lab//-/_}" "unlocked"
        fi
    fi

    # 显示密码（如果下一个实验是加密的）
    local next_pwd; next_pwd=$(progress_get_password "$next_lab")
    if [[ -n "$next_pwd" ]]; then
        echo
        echo -e "  ${C_YELLOW}🔑 下一个实验密码: ${C_BOLD}${next_pwd}${C_RESET}"
        echo -e "  ${C_DIM}(已自动保存，下次进入实验时自动解密)${C_RESET}"
    fi
}
