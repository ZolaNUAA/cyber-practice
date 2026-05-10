#!/usr/bin/env bash
# lab11 guide — 日志关联
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUIDE_DIR="$SCRIPT_DIR"
LIB_DIR="$(cd "$GUIDE_DIR/../.." && pwd)/lib"

source "$LIB_DIR/guide-framework.sh"
guide_start "lab11" "日志关联"
