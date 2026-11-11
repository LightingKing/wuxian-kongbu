#!/usr/bin/env python3
"""把一张带透明的像素图映射到共用调色板（设计 2026-11-10 第 3 节：图块和 Codex 的图都走同一个确定性的映射）。
不缩放、不抖动、不改透明度：每个不透明像素换成调色板里 RGB 距离最近的颜色（和 pixelize_scene.py 用的是同一个最近色规则）。
用法：python -I -X utf8 game/tools/palette_map.py <输入.png> <输出.png> --palette game/art/pixel_test/palette.hex --report <报告.json>
"""

import argparse
import hashlib
import importlib.util
import json
import sys
from collections import Counter
from pathlib import Path

from PIL import Image

sys.dont_write_bytecode = True  # 载入 pixelize_scene.py 时不在 game/tools/ 里留 __pycache__

# 用 pixelize_scene.py 里的调色板读取和距离函数（-I 模式下脚本目录不在 sys.path 里，按文件路径载入）。
_spec = importlib.util.spec_from_file_location("pixelize_scene", Path(__file__).with_name("pixelize_scene.py"))
_ps = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_ps)
load_palette = _ps.load_palette
squared_distance = _ps.squared_distance


def map_to_palette(image: Image.Image, palette: list[tuple[int, int, int]]) -> Image.Image:
	result = image.convert("RGBA")
	px = result.load()
	cache = {}
	for y in range(result.height):
		for x in range(result.width):
			r, g, b, a = px[x, y]
			if a == 0:
				continue
			color = (r, g, b)
			if color not in cache:
				cache[color] = min(palette, key=lambda target: squared_distance(color, target))
			px[x, y] = cache[color] + (a,)
	return result


def sha256(path: Path) -> str:
	return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("input", type=Path)
	parser.add_argument("output", type=Path)
	parser.add_argument("--palette", required=True, type=Path)
	parser.add_argument("--report", required=True, type=Path)
	args = parser.parse_args()
	palette = load_palette(args.palette)
	with Image.open(args.input) as opened:
		source = opened.convert("RGBA")
	result = map_to_palette(source, palette)
	args.output.parent.mkdir(parents=True, exist_ok=True)
	result.save(args.output, format="PNG")
	with Image.open(args.output) as saved:
		rgba = saved.convert("RGBA")
		used = Counter(p[:3] for p in rgba.get_flattened_data() if p[3] > 0)
		foreign = sorted(set(used) - set(palette))
		report = {
			"kind": "palette-map-report",
			"source": args.input.as_posix(),
			"source_sha256": sha256(args.input),
			"output": args.output.as_posix(),
			"output_sha256": sha256(args.output),
			"size": list(saved.size),
			"palette": args.palette.as_posix(),
			"palette_sha256": sha256(args.palette),
			"used_color_count": len(used),
			"foreign_colors": ["#%02X%02X%02X" % c for c in foreign],
			"size_preserved": saved.size == source.size,
			"method": "Nearest shared palette color by squared RGB distance (pixelize_scene.squared_distance) for every pixel with alpha > 0; alpha, size and transparent pixels unchanged; no dithering.",
			"passed": saved.size == source.size and not foreign,
		}
	args.report.parent.mkdir(parents=True, exist_ok=True)
	args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
	print(args.output.name, "colors", len(used), "passed", report["passed"])
	if not report["passed"]:
		raise SystemExit(1)


if __name__ == "__main__":
	main()
