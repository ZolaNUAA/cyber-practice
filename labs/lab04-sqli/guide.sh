#!/usr/bin/env bash
# lab04 guide — SQL注入实验
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUIDE_DIR="$SCRIPT_DIR"
# 向上两级到 cyber-practice 根目录
LIB_DIR="$(cd "$GUIDE_DIR/../.." && pwd)/lib"

source "$LIB_DIR/guide-framework.sh"
guide_start "lab04" "SQL注入"
