#!/usr/bin/env bash
# lab09 guide — 流量分析
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUIDE_DIR="$SCRIPT_DIR"
LIB_DIR="$(cd "$GUIDE_DIR/../.." && pwd)/lib"

source "$LIB_DIR/guide-framework.sh"
guide_start "lab09" "流量分析"
