#!/usr/bin/env bash
# 运行全部无界面测试。运行时错误不会中断 GDScript，所以额外检查输出里的 SCRIPT ERROR。
cd "$(dirname "$0")/.." || exit 2
out=$(godot --headless --path . -s res://tests/run_tests.gd 2>&1)
code=$?
echo "$out"
if echo "$out" | grep -q "SCRIPT ERROR"; then
	echo "!! 检测到脚本错误"
	exit 1
fi
exit $code
