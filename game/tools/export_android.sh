#!/usr/bin/env bash
# 出一个安卓 debug 包。模板/SDK/JDK 没齐时先停，不硬跑。
# 用法：bash game/tools/export_android.sh [输出路径]
# 默认输出：game/build/wuxian-kongbu.apk
set -euo pipefail

cd "$(dirname "$0")/../.."
root="$(pwd -W 2>/dev/null || pwd)"
out="${1:-$root/game/build/wuxian-kongbu.apk}"

if ! bash game/tools/check_export_env.sh; then
	echo
	echo "环境没齐，先按上面的提示补齐。"
	exit 1
fi

mkdir -p "$(dirname "$out")"
echo
echo "导出到：$out"
godot --headless --path game --export-debug "Android" "$out"
ls -lh "$out"
