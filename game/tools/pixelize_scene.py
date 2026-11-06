#!/usr/bin/env python3
"""整张不透明场景：区域主色二聚类缩小，再映射到共享调色板。"""

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re

from PIL import Image


def load_palette(path: Path) -> list[tuple[int, int, int]]:
	colors = []
	for line in path.read_text(encoding="utf-8-sig").splitlines():
		value = line.strip()
		if not value:
			continue
		if not re.fullmatch(r"#[0-9A-Fa-f]{6}", value):
			raise ValueError(f"调色板必须每行一个 #RRGGBB：{value!r}")
		color = tuple(int(value[start:start + 2], 16) for start in (1, 3, 5))
		if color in colors:
			raise ValueError(f"调色板包含重复颜色：{value}")
		colors.append(color)
	if not 1 <= len(colors) <= 32:
		raise ValueError("调色板必须包含 1 到 32 种颜色")
	return colors


def squared_distance(first: tuple, second: tuple) -> int:
	return sum((first[index] - second[index]) ** 2 for index in range(3))


def dominant_centroid(pixels: list[tuple[int, int, int]]) -> tuple[int, int, int]:
	"""确定性、按像素数量加权的二聚类；取较大簇的 RGB 均值。"""
	counts = Counter(pixels)
	if len(counts) == 1:
		return next(iter(counts))
	colors = sorted(counts)
	channel = max(range(3), key=lambda index: max(c[index] for c in colors) - min(c[index] for c in colors))
	centers = [min(colors, key=lambda c: (c[channel], c)), max(colors, key=lambda c: (c[channel], c))]
	for _ in range(8):
		groups = [[], []]
		for color in colors:
			group = 0 if squared_distance(color, centers[0]) <= squared_distance(color, centers[1]) else 1
			groups[group].append(color)
		updated = []
		for index, group in enumerate(groups):
			weight = sum(counts[color] for color in group)
			updated.append(tuple(round(sum(color[channel] * counts[color] for color in group) / weight) for channel in range(3)) if weight else centers[index])
		if updated == centers:
			break
		centers = updated
	weights = [sum(counts[color] for color in group) for group in groups]
	winner = min(range(2), key=lambda index: (-weights[index], sum(centers[index]), centers[index]))
	return centers[winner]


def pixelize(image: Image.Image, width: int, height: int, palette: list[tuple[int, int, int]]) -> Image.Image:
	"""按完整画布划分区域，不提取主体、不裁切，也不补边。"""
	source = image.convert("RGB")
	pixels = source.load()
	result = Image.new("RGB", (width, height))
	out = result.load()
	cache = {}
	for y in range(height):
		top, bottom = y * source.height // height, (y + 1) * source.height // height
		for x in range(width):
			left, right = x * source.width // width, (x + 1) * source.width // width
			block = [pixels[sx, sy] for sy in range(top, bottom) for sx in range(left, right)]
			color = dominant_centroid(block)
			if color not in cache:
				cache[color] = min(palette, key=lambda target: squared_distance(color, target))
			out[x, y] = cache[color]
	return result


def sha256(path: Path) -> str:
	return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("input", type=Path)
	parser.add_argument("output", type=Path)
	parser.add_argument("--palette", required=True, type=Path)
	parser.add_argument("--report", required=True, type=Path)
	parser.add_argument("--width", type=int, default=480)
	parser.add_argument("--height", type=int, default=270)
	args = parser.parse_args()
	if args.width <= 0 or args.height <= 0:
		parser.error("输出尺寸必须为正整数")
	paths = [args.input, args.output, args.palette, args.report]
	if len({path.resolve() for path in paths}) != len(paths):
		parser.error("输入、输出、调色板和报告路径必须互不相同")
	try:
		palette = load_palette(args.palette)
		with Image.open(args.input) as opened:
			image = opened.convert("RGBA")
		if image.getchannel("A").getextrema() != (255, 255):
			raise ValueError("只接受整张不透明场景；本工具不抠图、不丢弃透明度")
		if image.width < args.width or image.height < args.height:
			raise ValueError("输入每个轴的尺寸都必须不小于输出，本工具只做缩小")
		result = pixelize(image, args.width, args.height, palette)
	except (OSError, ValueError) as error:
		parser.error(str(error))
	args.output.parent.mkdir(parents=True, exist_ok=True)
	result.save(args.output, format="PNG")
	# 从落盘成品重新读取验收，不使用内存中的中间结果作为验收证据。
	with Image.open(args.output) as saved:
		used = Counter(saved.convert("RGB").get_flattened_data())
		alpha = sorted(set(saved.convert("RGBA").getchannel("A").get_flattened_data()))
		foreign = sorted(set(used) - set(palette))
		report = {
			"kind": "pixel-scene-conversion-report",
			"source": args.input.as_posix(),
			"source_sha256": sha256(args.input),
			"source_size": list(image.size),
			"output": args.output.as_posix(),
			"output_sha256": sha256(args.output),
			"output_size": list(saved.size),
			"output_mode": saved.mode,
			"palette": args.palette.as_posix(),
			"palette_sha256": sha256(args.palette),
			"palette_count": len(palette),
			"used_color_count": len(used),
			"used_colors": {"#%02X%02X%02X" % color: count for color, count in sorted(used.items())},
			"foreign_colors": ["#%02X%02X%02X" % color for color in foreign],
			"alpha_values": alpha,
			"full_canvas_preserved": True,
			"method": "Full-canvas integer area partitions; weighted RGB 2-means (up to 8 iterations, largest-channel-range endpoints); dominant-cluster centroid; nearest shared palette color by squared RGB distance; no dithering, crop, padding or alpha removal.",
			"passed": saved.size == (args.width, args.height) and alpha == [255] and not foreign and len(used) <= 32,
		}
	args.report.parent.mkdir(parents=True, exist_ok=True)
	args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
	print(json.dumps(report, ensure_ascii=True))
	if not report["passed"]:
		raise SystemExit(1)


if __name__ == "__main__":
	main()
