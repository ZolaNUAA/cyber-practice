#!/usr/bin/env bash
# update-lab.sh — 教师更新实验内容后重新加密并提交
# 用法: ./update-lab.sh lab05 "修改了SQL注入步骤3的说明"
#
# 流程:
#   1. 加密指定的实验（用同一个密码覆盖旧的 .enc）
#   2. git add 该实验的 .enc 文件
#   3. git commit & push

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

source lib/crypto-utils.sh

LAB="${1:-}"
MESSAGE="${2:-更新实验内容}"

if [[ -z "$LAB" ]]; then
    echo "用法: ./update-lab.sh <lab编号> [提交说明]"
    echo "示例: ./update-lab.sh lab05 '修复SQL注入步骤3的拼写错误'"
    exit 1
fi

# 找到实验目录
LAB_DIR=$(find labs -maxdepth 1 -type d -name "${LAB}*" | head -1)
if [[ -z "$LAB_DIR" ]]; then
    echo "❌ 找不到实验: $LAB"
    exit 1
fi

LAB_NAME=$(basename "$LAB_DIR")

# 检查是否有密码文件
PASSWORD_FILE="lab-passwords.txt"
if [[ ! -f "$PASSWORD_FILE" ]]; then
    echo "❌ 找不到 $PASSWORD_FILE，请先运行 make-student-image.sh 生成密码"
    exit 1
fi

# 从密码表读取密码
LAB_ID="${LAB_NAME%%-*}"
PWD=$(grep "^${LAB_ID} " "$PASSWORD_FILE" | awk '{print $2}')
if [[ -z "$PWD" ]]; then
    echo "❌ 在 $PASSWORD_FILE 中找不到 $LAB_ID 的密码"
    exit 1
fi

echo "实验: $LAB_NAME"
echo "密码: $PWD"
echo

# 清除旧加密文件
rm -f "$LAB_DIR"/.encrypted "$LAB_DIR"/*.enc

# 重新加密
if crypto_encrypt_lab "$LAB_DIR" "$PWD"; then
    echo
    echo "✅ 已重新加密"

    # Git 操作
    git add "$LAB_DIR"/*.enc
    git commit -m "update: $LAB_NAME — $MESSAGE"
    git push origin main

    echo
    echo "✅ 已提交并推送到 GitHub"
    echo "   学生下次解锁 $LAB_ID 时会自动获取最新版本。"
else
    echo "❌ 加密失败"
    exit 1
fi
