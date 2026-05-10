#!/usr/bin/env bash
# crypto-utils.sh — 实验文件加密/解密工具
# 使用 openssl AES-256-CBC + PBKDF2

# ── 生成随机密码（12位字母数字） ──────────────────
crypto_generate_password() {
    openssl rand -hex 6 2>/dev/null
}

# ── 加密实验目录 ───────────────────────────────────
# 用法: crypto_encrypt_lab <lab_dir> <password>
# 将 lab_dir 下的 steps/ hints/ checks/ 打包加密为 lab_dir/labXX.enc
crypto_encrypt_lab() {
    local lab_dir; lab_dir=$(cd "$1" 2>/dev/null && pwd) || { echo "  ❌ 无效目录: $1"; return 1; }
    local password="$2"
    local lab_name; lab_name=$(basename "$lab_dir")
    local enc_file="$lab_dir/${lab_name}.enc"
    local orig_dir; orig_dir=$(pwd)

    # 检查是否有可加密的内容
    local dirs_to_pack=()
    for d in steps hints checks; do
        [[ -d "$lab_dir/$d" ]] && dirs_to_pack+=("$d")
    done

    if [[ ${#dirs_to_pack[@]} -eq 0 ]]; then
        echo "  (无内容可加密)"
        return 0
    fi

    # 打包 + 加密（从 lab_dir 的父目录打包，避免路径前缀问题）
    cd "$lab_dir" || return 1
    if tar czf - "${dirs_to_pack[@]}" 2>/dev/null | \
       openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt \
           -out "$enc_file" -pass pass:"$password" 2>/dev/null; then
        # 加密成功后删除原始目录
        for d in "${dirs_to_pack[@]}"; do
            rm -rf "$d"
        done
        # 标记已加密
        touch "$lab_dir/.encrypted"
        cd "$orig_dir"
        echo "  ✅ 已加密: $(basename "$enc_file") (${#dirs_to_pack[@]} 个目录)"
        return 0
    else
        cd "$orig_dir"
        echo "  ❌ 加密失败: $lab_name"
        return 1
    fi
}

# ── 解密实验目录 ───────────────────────────────────
# 用法: crypto_decrypt_lab <lab_dir> <password>
# 将 lab_dir/labXX.enc 解密并还原 steps/ hints/ checks/
crypto_decrypt_lab() {
    local lab_dir; lab_dir=$(cd "$1" 2>/dev/null && pwd) || { echo "  ❌ 无效目录: $1"; return 1; }
    local password="$2"
    local lab_name; lab_name=$(basename "$lab_dir")
    local enc_file="$lab_dir/${lab_name}.enc"
    local orig_dir; orig_dir=$(pwd)

    if [[ ! -f "$enc_file" ]]; then
        echo "  ❌ 找不到加密文件: $enc_file"
        return 1
    fi

    cd "$lab_dir" || return 1

    # 解密到临时文件（避免 pipefail 导致 openssl SIGPIPE 错误）
    local tmp_tar; tmp_tar=$(mktemp /tmp/cyber-decrypt.XXXXXX)
    if openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -d \
            -in "$enc_file" -pass pass:"$password" \
            -out "$tmp_tar" 2>/dev/null; then
        if tar xzf "$tmp_tar" 2>/dev/null; then
            rm -f "$tmp_tar" "$enc_file" "$lab_dir/.encrypted"
            cd "$orig_dir"
            echo "  ✅ 已解密: $lab_name"
            return 0
        fi
    fi
    rm -f "$tmp_tar"
    cd "$orig_dir"
    echo "  ❌ 解密失败（密码错误或文件损坏）: $lab_name"
    return 1
}

# ── 检查实验是否处于加密状态 ──────────────────────
crypto_is_encrypted() {
    local lab_dir="$1"
    local lab_name; lab_name=$(basename "$lab_dir")
    [[ -f "$lab_dir/.encrypted" || -f "$lab_dir/${lab_name}.enc" ]]
}
