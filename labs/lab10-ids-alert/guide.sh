#!/usr/bin/env bash
# lab10 guide — IDS告警分析
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUIDE_DIR="$SCRIPT_DIR"
LIB_DIR="$(cd "$GUIDE_DIR/../.." && pwd)/lib"

source "$LIB_DIR/guide-framework.sh"
guide_start "lab10" "IDS告警分析"
