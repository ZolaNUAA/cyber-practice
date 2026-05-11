#!/usr/bin/env bash
# sync-lab.sh — 同步最新实验内容（学生端）
# 用法: ./sync-lab.sh [lab编号]
#
#   不带参数：检查所有实验室，提示每个需同步的实验
#   带 lab 编号：只检查指定实验
#
# 流程（参考 guide_start 中的 git sync 逻辑）:
#   1. git pull 拉取最新 .enc 文件
#   2. 如果本地有已解密的 steps/hints/checks（未加密状态），
#      提示是否重新加密后再覆盖

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source lib/crypto-utils.sh

TARGET="${1:-}"

# ── 检查是否是 git 仓库 ──────────────────────────────
if ! git rev-parse --show-toplevel &>/dev/null; then
    echo "❌ 不是 git 仓库，无法同步。"
    echo "   请从 GitHub 重新克隆："
    echo "   git clone https://github.com/ZolaNUAA/cyber-practice.git"
    exit 1
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  🔄 实验内容同步"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# ── 拉取最新代码 ────────────────────────────────────
echo "📡 正在拉取最新代码..."
if git fetch origin 2>/dev/null; then
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse @{u})
    if [[ "$LOCAL" == "$REMOTE" ]]; then
        echo "✅ 已最新，无需更新"
    else
        echo "📥 有新提交，正在合并..."
        git pull origin main
        echo "✅ 同步完成"
    fi
else
    echo "⚠️  无法连接网络（继续使用本地版本）"
fi
echo

# ── 获取远程的 .enc 文件列表 ────────────────────────
fetch_remote_encs() {
    git ls-tree -r --name-only origin/main 2>/dev/null | \
        grep '\.enc$' | \
        grep '^labs/' | \
        sort
}

# ── 检查指定实验是否需要同步 ────────────────────────
sync_single_lab() {
    local lab_id="$1"
    local lab_dir; lab_dir=$(find labs -maxdepth 1 -type d -name "${lab_id}-*" | head -1)

    if [[ -z "$lab_dir" ]]; then
        echo "  ❌ 找不到实验: $lab_id"
        return
    fi

    local lab_name; lab_name=$(basename "$lab_dir")
    local enc_file="$lab_dir/${lab_name}.enc"

    # 检查远程是否有更新的 .enc
    local remote_enc="labs/${lab_name}/${lab_name}.enc"
    local local_hash=""; local remote_hash=""

    if git rev-parse "origin/main:${remote_enc}" &>/dev/null; then
        local_hash=$(git rev-parse "HEAD:${remote_enc}" 2>/dev/null || echo "")
        remote_hash=$(git rev-parse "origin/main:${remote_enc}")
    fi

    if [[ "$local_hash" != "$remote_hash" ]]; then
        echo "  🔄 $lab_name — 有更新"
        echo "     远程: ${remote_hash:0:7}  本地: ${local_hash:0:7:-1:-1}"

        # 如果本地处于未加密状态（有 steps/hints 目录）
        if [[ -d "$lab_dir/steps" || -d "$lab_dir/hints" ]]; then
            echo "     ⚠️  本地有未加密内容，合并可能冲突"
            echo "     选择操作:"
            echo "       [k] 保留本地（不更新）"
            echo "       [o] 覆盖本地（获取远程版本）"
            echo -n "       [r] 重新加密本地内容 [默认: k]: "
            read -r choice
            case "$choice" in
                o|O)
                    git checkout "origin/main" -- "$remote_enc" 2>/dev/null
                    echo "     ✅ 已覆盖为远程版本"
                    ;;
                r|R)
                    # 用密码重新加密本地内容
                    local pwd_file="lab-passwords.txt"
                    if [[ -f "$pwd_file" ]]; then
                        local pwd; pwd=$(grep "^${lab_id} " "$pwd_file" | awk '{print $2}')
                        if [[ -n "$pwd" ]]; then
                            rm -f "$lab_dir"/*.enc "$lab_dir"/.encrypted
                            if crypto_encrypt_lab "$lab_dir" "$pwd"; then
                                git add "$lab_dir"/*.enc
                                git commit -m "sync: re-encrypt $lab_name"
                                git push origin main
                                echo "     ✅ 已重新加密并推送"
                            else
                                echo "     ❌ 加密失败，保留本地明文"
                            fi
                        else
                            echo "     ❌ 密码文件中未找到 $lab_id 的密码"
                        fi
                    else
                        echo "     ❌ 找不到密码文件 lab-passwords.txt"
                    fi
                    ;;
                *)
                    echo "     ⏭️  跳过"
                    ;;
            esac
        else
            # 本地是加密状态，直接 checkout
            git checkout "origin/main" -- "$remote_enc" 2>/dev/null
            echo "     ✅ 已更新为远程版本"
        fi
    else
        echo "  ✅ $lab_name — 已最新"
    fi
}

# ── 主逻辑 ──────────────────────────────────────────
if [[ -n "$TARGET" ]]; then
    # 检查指定实验
    sync_single_lab "$TARGET"
else
    # 检查所有实验
    echo "📋 正在检查所有实验室..."
    echo

    for lab_dir in labs/lab*-*; do
        [[ -d "$lab_dir" ]] || continue
        lab_name=$(basename "$lab_dir")
        lab_id="${lab_name%%-*}"
        sync_single_lab "$lab_id"
        echo
    done
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ 检查完成"
echo
echo "💡 提示：启动实验时会自动检查更新："
echo "   ./student.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
