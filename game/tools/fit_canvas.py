#!/usr/bin/env python3
"""等比放入画布：透明图留 2px 透明边，不透明图以 RGB 暗色补边。"""

import argparse
from pathlib import Path

from PIL import Image


def positive_int(value: str) -> int:
	try:
		number = int(value)
	except ValueError as exc:
		raise argparse.ArgumentTypeError("尺寸必须是正整数") from exc
	if number <= 0:
		raise argparse.ArgumentTypeError("尺寸必须是正整数")
	return number


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("input")
	parser.add_argument("output")
	parser.add_argument("width", type=positive_int)
	parser.add_argument("height", type=positive_int)
	parser.add_argument("--bottom", action="store_true")
	args = parser.parse_args()

	with Image.open(args.input) as source:
		image = source.convert("RGBA")
	alpha = image.getchannel("A")
	transparent = alpha.getextrema()[0] < 255
	margin = 0
	if transparent:
		bounds = alpha.getbbox()
		if bounds is None:
			parser.error("输入图片完全透明，没有可放入画布的内容")
		# 只去除空白画布，保留所有非零 alpha 像素；不改动抠图结果。
		image = image.crop(bounds)
		margin = min(2, (min(args.width, args.height) - 1) // 2)
	else:
		image = image.convert("RGB")
	scale = min((args.width - 2 * margin) / image.width, (args.height - 2 * margin) / image.height)
	size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
	resized = image.resize(size, Image.Resampling.LANCZOS)
	# RGB 图片使用固定暗色 #11141a 补边，保持整张背景不透明。
	canvas = Image.new("RGBA" if transparent else "RGB", (args.width, args.height), (0, 0, 0, 0) if transparent else (17, 20, 26))
	x = (args.width - resized.width) // 2
	y = args.height - margin - resized.height if args.bottom else (args.height - resized.height) // 2
	if transparent:
		canvas.alpha_composite(resized, (x, y))
	else:
		canvas.paste(resized, (x, y))
	Path(args.output).parent.mkdir(parents=True, exist_ok=True)
	canvas.save(args.output)


if __name__ == "__main__":
	main()
