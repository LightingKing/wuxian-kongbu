"""只读像素试验成品审计；不生成、裁切或改写图片。"""

from collections import Counter
import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "game/art/pixel_test"
SOURCE = ROOT / "art_src/pixel_test"


def digest(path: Path) -> str:
	return hashlib.sha256(path.read_bytes()).hexdigest()


def image_record(path: Path, palette: set) -> dict:
	with Image.open(path) as image:
		rgba = image.convert("RGBA")
		pixels = list(rgba.get_flattened_data())
		colors = Counter(p[:3] for p in pixels if p[3])
		return {
			"path": path.relative_to(ROOT).as_posix(),
			"sha256": digest(path),
			"size": list(image.size),
			"mode": image.mode,
			"alpha_values": sorted({p[3] for p in pixels}),
			"opaque_color_count": len(colors),
			"opaque_colors": ["#%02X%02X%02X" % c for c in sorted(colors)],
			"foreign_colors": ["#%02X%02X%02X" % c for c in sorted(set(colors) - palette)],
		}


def main() -> None:
	palette_path = ART / "palette.hex"
	palette = {tuple(bytes.fromhex(line.strip()[1:])) for line in palette_path.read_text().splitlines() if line.strip()}
	assert 1 <= len(palette) <= 32
	report = {"kind": "pixel-test-asset-audit", "palette_count": len(palette), "characters": {}, "checks": {}}
	all_colors = set()
	for character, last in [("zheng_zha", "down"), ("zombie_scientist", "death")]:
		directory = ART / character
		manifest = json.loads((directory / "manifest.json").read_text(encoding="utf-8"))
		atlas_path = directory / manifest["sprite_sheet_alpha"]
		info = image_record(atlas_path, palette)
		assert info["alpha_values"] == [0, 255] and not info["foreign_colors"], info
		all_colors.update(info["opaque_colors"])
		info["states"] = {}
		assert set(manifest["frame_layout"]["rows"]) == {"idle", "attack", "hit", last}
		with Image.open(atlas_path) as opened:
			atlas = opened.convert("RGBA")
			assert (manifest["frame_layout"]["sheetWidth"], manifest["frame_layout"]["sheetHeight"]) == atlas.size
			for state, layout in manifest["frame_layout"]["rows"].items():
				animation = manifest["animation"]["rows"][state]
				frames = []
				for rect in layout:
					x, y, width, height = rect["x"], rect["y"], rect["w"], rect["h"]
					assert (width, height) == (48, 48)
					assert x >= 0 and y >= 0 and x + width <= atlas.width and y + height <= atlas.height
					# A read-only region view is used solely for statistics, never saved.
					cell = atlas.crop((x, y, x + width, y + height))
					bbox = cell.getchannel("A").getbbox()
					assert bbox is not None
					assert bbox[3] == 40, (character, state, "baseline", bbox)
					if state in ("idle", "attack", "hit"):
						assert 28 <= bbox[3] - bbox[1] <= 34, (character, state, "standing height", bbox)
					colors = {p[:3] for p in cell.get_flattened_data() if p[3]}
					assert colors <= palette
					frames.append({"bbox_xyxy": list(bbox), "visible_width": bbox[2] - bbox[0], "visible_height": bbox[3] - bbox[1], "baseline_exclusive": bbox[3], "color_count": len(colors), "visible_height_28_to_34": 28 <= bbox[3] - bbox[1] <= 34})
				assert 2 <= len(frames) <= 6
				assert animation["loop"] == (state == "idle")
				info["states"][state] = {"frame_count": len(frames), "fps": animation["fps"], "loop": animation["loop"], "frames": frames}
		report["characters"][character] = info
	background = image_record(ART / "bg_lab_corridor_pixel.png", palette)
	assert background["size"] == [480, 270] and background["alpha_values"] == [255] and not background["foreign_colors"]
	all_colors.update(background["opaque_colors"])
	report["background"] = background
	report["combined_color_count"] = len(all_colors)
	report["combined_colors"] = sorted(all_colors)
	assert len(all_colors) <= 32
	report["checks"] = {"cell_size": "48x48", "binary_character_alpha": True, "opaque_background": True, "shared_palette_only": True, "height": "See each frame measurement and the report's posture interpretation; no excluded frames are silently marked passing."}
	report["files_sha256"] = {}
	for directory in [ART, SOURCE]:
		for path in sorted(directory.rglob("*")):
			if path.is_file() and path.name != "asset-audit.json" and not path.name.endswith((".lock", ".import")) and "__pycache__" not in path.parts:
				report["files_sha256"][path.relative_to(ROOT).as_posix()] = digest(path)
	output = SOURCE / "asset-audit.json"
	output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
	print(json.dumps({"characters": list(report["characters"]), "combined_color_count": len(all_colors), "report": output.relative_to(ROOT).as_posix()}, ensure_ascii=True))


if __name__ == "__main__":
	main()
