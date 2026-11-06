"""Read-only pixel/alpha/palette audit of sprite-gen's composed atlas and sources."""
import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[2]
RUN = ROOT / "run-native"
PALETTE = REPO / "game/art/pixel_test/palette.hex"
COLORS = {tuple(bytes.fromhex(line.strip().lstrip("#")))
			for line in PALETTE.read_text(encoding="utf-8").splitlines() if line.strip()}


def image_metrics(image):
	image = image.convert("RGBA")
	pixels = list(image.get_flattened_data())
	alpha = image.getchannel("A")
	bbox = alpha.getbbox()
	colors = {pixel[:3] for pixel in pixels if pixel[3]}
	return {
		"size": list(image.size), "bbox": list(bbox) if bbox else None,
		"visible_height": bbox[3] - bbox[1] if bbox else 0,
		"bottom_visible_row": bbox[3] - 1 if bbox else None,
		"alpha_values": sorted(set(alpha.get_flattened_data())),
		"nonzero_alpha_pixels": sum(pixel[3] > 0 for pixel in pixels),
		"opaque_color_count": len(colors),
		"outside_palette_color_count": len(colors - COLORS),
		"outside_palette_colors_sample": sorted(colors - COLORS)[:32],
	}


def main():
	manifest = json.loads((RUN / "manifest.json").read_text(encoding="utf-8"))
	atlas_path = RUN / "sprite-sheet-alpha.png"
	atlas = Image.open(atlas_path)
	states = {}
	for state, frames in manifest["frame_layout"]["rows"].items():
		states[state] = []
		for index, rect in enumerate(frames):
			box = (rect["x"], rect["y"], rect["x"] + rect["w"], rect["y"] + rect["h"])
			metric = image_metrics(atlas.crop(box))
			states[state].append({"index": index, "rect": rect, **metric})
	generated = []
	for path in sorted(ROOT.rglob("*.json")):
		if path.name == "qa-summary.json":
			continue
		try:
			value = json.loads(path.read_text(encoding="utf-8"))
		except (ValueError, UnicodeError):
			continue
		if value.get("kind") == "sprite-gen-image-report":
			generated.append({"path": path.relative_to(REPO).as_posix(),
								"provider": value.get("provider"),
								"elapsed_seconds": value.get("elapsed_seconds"),
								"facing": value.get("extra", {}).get("facing")})
	files = []
	for path in sorted(ROOT.rglob("*")):
		if not path.is_file() or path.name in {"qa-summary.json", "pixel-audit.log"}:
			continue
		files.append({"path": path.relative_to(REPO).as_posix(), "bytes": path.stat().st_size,
						"sha256": hashlib.sha256(path.read_bytes()).hexdigest()})
	result = {
		"shared_palette": PALETTE.relative_to(REPO).as_posix(),
		"palette_colors": len(COLORS),
		"atlas": image_metrics(atlas), "states": states,
		"animation": manifest["animation"],
		"base_published_chroma_error": image_metrics(Image.open(ROOT / "base.png")),
		"base_accepted_native_raw": image_metrics(Image.open(ROOT / "base.png.raw.png")),
		"generation_reports": generated,
		"image_report_count": len(generated),
		"reported_generation_seconds": sum(item["elapsed_seconds"] or 0 for item in generated),
		"interrupted_run": {
			"path": "art_src/pixel_test/zombie_scientist/run",
			"submitted_state_jobs": ["idle", "attack"],
			"completed_image_reports": 0,
			"raw_images": 0,
			"provider_completion_unknown": True,
			"reason": "Stopped after discovering the incorrectly chroma-keyed base reference.",
		},
		"native_score": json.loads((RUN / "sprite-score.report.json").read_text(encoding="utf-8")),
		"final_artifacts": [
			{"path": (REPO / "game/art/pixel_test/zombie_scientist" / name).relative_to(REPO).as_posix(),
				"sha256": hashlib.sha256((REPO / "game/art/pixel_test/zombie_scientist" / name).read_bytes()).hexdigest()}
			for name in ("sprite-sheet-alpha.png", "manifest.json")
		],
		"files": files,
	}
	(ROOT / "qa-summary.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n",
											encoding="utf-8", newline="\n")
	print(json.dumps({"states": states, "image_report_count": len(generated),
						"reported_generation_seconds": result["reported_generation_seconds"]},
						ensure_ascii=False, indent=2))


if __name__ == "__main__":
	main()
