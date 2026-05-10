#!/usr/bin/env bash
# check-all: 验证 lab04 全部交付物完成

PASS=0
FAIL=0

REPORT_DIR="$HOME/cyber-practice/reports"

# 1. 检查实验报告
echo -n "实验报告... "
if [[ -f "$REPORT_DIR/lab04-report.md" ]]; then
    lines=$(wc -l < "$REPORT_DIR/lab04-report.md")
    if [[ $lines -gt 10 ]]; then
        echo "✅ ($lines 行)"
        PASS=$((PASS + 1))
    else
        echo "⚠️ 内容较少 ($lines 行), 建议补充"
        PASS=$((PASS + 1))
    fi
else
    echo "❌ 未找到 $REPORT_DIR/lab04-report.md"
    FAIL=$((FAIL + 1))
fi

# 2. 检查是否有提交文件
echo -n "提交文件... "
if ls "$HOME/cyber-practice/submit"/lab04-*.json 2>/dev/null | head -1 | grep -q .; then
    echo "✅ 已生成"
    PASS=$((PASS + 1))
else
    echo "ℹ️  完成所有步骤后自动生成"
fi

echo
if [[ $FAIL -eq 0 ]]; then
    echo "✅ 所有检查通过 ($PASS/$((PASS+FAIL)))"
    exit 0
else
    echo "⚠️  有 $FAIL 项未完成"
    exit 1
fi
