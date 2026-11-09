#!/usr/bin/env bash
# 检查安卓导出要用的东西，缺什么就报什么，不自动安装、不联网。
# 用法：bash game/tools/check_export_env.sh
# 退出码：0 = 都齐了；1 = 有缺项（下面会写清楚缺哪一样、去哪补）。
set -u

fails=0
ok() { printf '  [ok]   %s\n' "$1"; }
bad() { printf '  [缺]   %s\n' "$1"; fails=$((fails + 1)); }
note() { printf '         %s\n' "$1"; }

echo "安卓导出环境检查"
echo

# 1. Godot
if command -v godot >/dev/null 2>&1; then
	ver="$(godot --version 2>/dev/null | head -1)"
	ok "Godot $ver"
else
	bad "找不到 godot 命令（把 Godot 加进 PATH）"
	ver=""
fi

# 2. 导出模板（Godot 4 放在 %APPDATA%/Godot/export_templates/<版本>/）
tpl_root="${APPDATA:-$HOME/.config}/Godot/export_templates"
tpl_dir=""
if [ -d "$tpl_root" ]; then
	for d in "$tpl_root"/*/; do
		[ -d "$d" ] || continue
		if [ -f "${d}android_debug.apk" ] || [ -f "${d}android_release.apk" ]; then
			tpl_dir="$d"
			break
		fi
	done
fi
if [ -n "$tpl_dir" ]; then
	ok "安卓导出模板：$tpl_dir"
else
	bad "没有安卓导出模板"
	note "编辑器 → 编辑器菜单 → 管理导出模板 → 下载并安装（约 1 GB）"
	note "装完后模板在 $tpl_root/<版本>/"
fi

# 3. Android SDK
sdk="${ANDROID_HOME:-${LOCALAPPDATA:-$HOME}/Android/Sdk}"
if [ -d "$sdk" ]; then
	ok "Android SDK：$sdk"
	for part in platform-tools build-tools; do
		if [ -d "$sdk/$part" ]; then
			ok "  $part"
		else
			bad "  SDK 里没有 $part"
			note "用 Android Studio 的 SDK Manager 装"
		fi
	done
else
	bad "没有 Android SDK（ANDROID_HOME 没设，默认位置也不存在）"
	note "装 Android Studio，或用命令行工具装 SDK，然后设 ANDROID_HOME"
fi

# 4. JDK（Godot 4 的安卓导出要 17 以上）
if command -v java >/dev/null 2>&1; then
	jraw="$(java -version 2>&1 | head -1)"
	jver="$(printf '%s' "$jraw" | sed -n 's/.*version "\([0-9.]*\).*/\1/p')"
	major="${jver%%.*}"
	if [ "$major" = "1" ]; then
		major="$(printf '%s' "$jver" | cut -d. -f2)"
	fi
	if [ -n "$major" ] && [ "$major" -ge 17 ] 2>/dev/null; then
		ok "JDK $jver"
	else
		bad "JDK 版本太低（$jver，需要 17 以上）"
		note "装 Temurin / Microsoft OpenJDK 17，并把 JAVA_HOME 指过去"
	fi
else
	bad "找不到 java（需要 JDK 17 以上）"
fi

echo
if [ "$fails" -eq 0 ]; then
	echo "全部就绪，可以出包：bash game/tools/export_android.sh"
	exit 0
fi
echo "还缺 $fails 项；补齐后再跑一次本脚本。"
exit 1
