#!/usr/bin/env bash
# 运行全部无界面测试。运行时错误不会中断 GDScript，所以额外检查输出里的 SCRIPT ERROR。
# 测试可以等帧、等信号；万一有一个永远等不到，15 分钟后强制结束并算失败。
cd "$(dirname "$0")/.." || exit 2
out=$(timeout 900 godot --headless --path . -s res://tests/run_tests.gd 2>&1)
code=$?
echo "$out"
if [ "$code" -eq 124 ]; then
	echo "!! 测试超时（有测试一直在等）"
	exit 1
fi
if echo "$out" | grep -q "SCRIPT ERROR"; then
	echo "!! 检测到脚本错误"
	exit 1
fi
exit $code
