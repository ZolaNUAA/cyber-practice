#!/usr/bin/env bash
# check-02: 验证 SQL 注入实验靶机已启动

PASS=0
FAIL=0

# 检查 Juice Shop
echo -n "Juice Shop (3000)... "
if curl -s --connect-timeout 5 http://127.0.0.1:3000 > /dev/null 2>&1; then
    echo "✅ 运行正常"
    PASS=$((PASS + 1))
else
    echo "❌ 未响应"
    FAIL=$((FAIL + 1))
fi

# 检查 WebGoat
echo -n "WebGoat (8080)...  "
if curl -s --connect-timeout 5 http://127.0.0.1:8080/WebGoat > /dev/null 2>&1; then
    echo "✅ 运行正常"
    PASS=$((PASS + 1))
else
    echo "❌ 未响应 (首次启动可能需要几分钟)"
    FAIL=$((FAIL + 1))
fi

echo
if [[ $FAIL -eq 0 ]]; then
    echo "✅ 所有靶机就绪 ($PASS/$((PASS+FAIL)))"
    exit 0
else
    echo "⚠️  $FAIL 个服务未就绪。请确保执行了: ./start-lab.sh lab04"
    exit 1
fi
