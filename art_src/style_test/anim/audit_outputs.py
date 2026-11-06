"""Read-only asset metadata and SHA-256 evidence; never modifies an image."""

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
import sys

from PIL import Image, ImageSequence


ROOT = Path(__file__).resolve().parents[3]
RUNS = {
	"zheng_zha": ROOT / "art_src/style_test/anim/zheng_zha",
	"zombie_scientist": ROOT / "art_src/style_test/anim/zombie_scientist/run",
}


def metadata(path: Path) -> dict:
	result = {"path": path.relative_to(ROOT).as_posix(), "bytes": path.stat().st_size,
		"sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
	if path.suffix.lower() in (".png", ".gif"):
		with Image.open(path) as image:
			result.update(size=list(image.size), mode=image.mode, frames=getattr(image, "n_frames", 1))
			if path.suffix.lower() == ".gif":
				result["durations_ms"] = [frame.info.get("duration", 0) for frame in ImageSequence.Iterator(image)]
				result["loop"] = image.info.get("loop")
			else:
				alpha = image.convert("RGBA").getchannel("A")
				histogram = alpha.histogram()
				result["alpha"] = {"transparent": histogram[0], "partial": sum(histogram[1:255]),
					"opaque": histogram[255], "bbox": alpha.getbbox()}
	return result


def main() -> None:
	sys.stdout.reconfigure(encoding="utf-8")
	audit = {"tool": "sprite-gen 3.15.0", "characters": {}, "references": [
		metadata(ROOT / "game/art/style_test/zheng_zha_battle_idle.png"),
		metadata(ROOT / "game/art/style_test/zombie_scientist_attack.png"),
	]}
	for character, run in RUNS.items():
		final = ROOT / "game/art/style_test/anim" / character
		manifest = json.loads((final / "manifest.json").read_text(encoding="utf-8"))
		frames = json.loads((run / "frames/frames-manifest.json").read_text(encoding="utf-8"))
		files = [final / name for name in ("sprite-sheet-alpha.png", "manifest.json", "sprite_frames.tres")]
		files += sorted((run / "qa").glob("*.gif"))
		files += sorted((run / "previews").glob("*.gif"))
		if character == "zombie_scientist":
			files += sorted((run.parent / "gifs").glob("*.gif"))
		files += sorted((run / "raw").glob("*.png"))
		entry = {"files": [metadata(path) for path in files], "states": {}, "generation": []}
		logs = list((run / "reports/gen-set").glob("*.log"))
		if character == "zombie_scientist":
			logs.append(run.parent / "gen-set-attempt-1.log")
		start = min(path.stat().st_birthtime for path in logs)
		end = (run / "reports/gen-set/set.report.json").stat().st_mtime
		entry["batch_clock"] = {"method": "Fresh log creation to native batch report modification, filesystem observed",
			"start_utc": datetime.fromtimestamp(start, timezone.utc).isoformat(),
			"end_utc": datetime.fromtimestamp(end, timezone.utc).isoformat(), "seconds": round(end - start, 3)}
		for row in frames["rows"]:
			state = row["state"]
			entry["states"][state] = {"timing": manifest["animation"]["rows"][state],
				"rectangles": manifest["frame_layout"]["rows"][state],
				"extraction": row, "frames": [metadata(run / name) for name in row["files"]]}
		for report_path in sorted((run / "reports/gen-set").glob("*.json")):
			report = json.loads(report_path.read_text(encoding="utf-8"))
			if report.get("kind") == "sprite-gen-image-report":
				entry["generation"].append({"report": report_path.relative_to(ROOT).as_posix(),
					"seconds": report["elapsed_seconds"], "facing": report.get("extra", {}).get("facing", {})})
		audit["characters"][character] = entry
	audit["godot_captures"] = [metadata(path) for path in sorted(Path(__file__).parent.glob("godot-*.png"))]
	output = Path(__file__).with_name("asset-audit.json")
	output.write_text(json.dumps(audit, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
	print(output.relative_to(ROOT).as_posix())


if __name__ == "__main__":
	main()
