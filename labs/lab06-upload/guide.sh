#!/usr/bin/env bash
# lab06 guide — 文件上传风险
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUIDE_DIR="$SCRIPT_DIR"
LIB_DIR="$(cd "$GUIDE_DIR/../.." && pwd)/lib"

source "$LIB_DIR/guide-framework.sh"
guide_start "lab06" "文件上传风险"
