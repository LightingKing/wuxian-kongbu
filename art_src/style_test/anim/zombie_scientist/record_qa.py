"""Record existing native sprite-gen outputs without modifying any image."""

from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent
RUN = ROOT / "run"
REPO = ROOT.parents[3]
FINAL = REPO / "game/art/style_test/anim/zombie_scientist"


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def fingerprint(path):
    return {
        "path": path.relative_to(REPO).as_posix(),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "bytes": path.stat().st_size,
    }


def main():
    request = read_json(RUN / "sprite-request.json")
    frames = read_json(RUN / "frames/frames-manifest.json")
    inspect = read_json(RUN / "sprite-inspect.report.json")
    score = read_json(RUN / "sprite-score.report.json")
    composed = read_json(RUN / "sprite-sheet-alpha.report.json")
    batch = read_json(RUN / "reports/gen-set/set.report.json")
    manifest = read_json(FINAL / "manifest.json")
    assert all(report["ok"] for report in (frames, inspect, score, composed))
    assert not batch["failed"] and not batch["not_started"]
    assert manifest == read_json(RUN / "manifest.json")
    assert (FINAL / "sprite-sheet-alpha.png").read_bytes() == (RUN / "sprite-sheet-alpha.png").read_bytes()

    states = []
    for item in batch["items"]:
        state = item["state"]
        report = read_json(RUN / "reports/gen-set" / (state + ".json"))
        row = next(row for row in frames["rows"] if row["state"] == state)
        pngs = []
        for relative in row["files"]:
            path = RUN / relative
            with Image.open(path) as image:
                assert image.size == (768, 768) and image.mode == "RGBA"
                alpha = image.getchannel("A")
                histogram = alpha.histogram()
                assert alpha.getbbox() is not None
                pngs.append({
                    **fingerprint(path),
                    "size": list(image.size),
                    "mode": image.mode,
                    "alpha_bbox": list(alpha.getbbox()),
                    "transparent_pixels": histogram[0],
                    "partial_alpha_pixels": sum(histogram[1:255]),
                    "opaque_pixels": histogram[255],
                })
        gif_path = RUN / "qa" / (state + ".gif")
        with Image.open(gif_path) as gif:
            gif_data = {**fingerprint(gif_path), "size": list(gif.size), "frames": gif.n_frames}
        with Image.open(RUN / "raw" / (state + ".png")) as raw:
            raw_size = list(raw.size)
        assert report["provider"] == "codex"
        assert report["extra"]["facing"].get("action") != "mirror"
        states.append({
            "state": state,
            "row_generation_calls": 1,
            "gen_set_elapsed_seconds": item["elapsed_seconds"],
            "image_report_elapsed_seconds": report["elapsed_seconds"],
            "facing": report["extra"]["facing"],
            "raw_size": raw_size,
            "raw": fingerprint(RUN / "raw" / (state + ".png")),
            "generation_report": fingerprint(RUN / "reports/gen-set" / (state + ".json")),
            "prompt": fingerprint(RUN / "prompts" / (state + ".txt")),
            "runtime": manifest["animation"]["rows"][state],
            "frame_records": row["frame_records"],
            "frames": pngs,
            "qa_gif": gif_data,
        })

    start = (ROOT / "gen-set-attempt-1.log").stat().st_birthtime
    end = (RUN / "reports/gen-set/set.report.json").stat().st_mtime
    summary = {
        "kind": "zombie-scientist-animation-qa",
        "automated_checks_passed": True,
        "row_generation_calls": 4,
        "generation_batches": 1,
        "concurrency": 2,
        "row_regenerations": 0,
        "extract_runs": 2,
        "generation_cell": read_json(ROOT / "request.json")["cell"],
        "final_cell": request["cell"],
        "pixel_unfake": request["fit"]["pixel_unfake"],
        "batch_clock": {
            "method": "Fresh generation-log creation to native set-report modification; filesystem observed wall time, not sum of parallel rows.",
            "start_utc": datetime.fromtimestamp(start, timezone.utc).isoformat(),
            "end_utc": datetime.fromtimestamp(end, timezone.utc).isoformat(),
            "elapsed_seconds": round(end - start, 3),
        },
        "native_inspect_thresholds": inspect["thresholds"],
        "native_inspect_errors": inspect["errors"],
        "native_inspect_warnings": inspect["warnings"],
        "native_score": score["overall_score"],
        "source": fingerprint(RUN / "base-source.png"),
        "finals": [fingerprint(FINAL / name) for name in ("sprite-sheet-alpha.png", "manifest.json")],
        "states": states,
        "visual_review": {
            "scope": "All generated rows and extracted contact sheet, plus independent per-frame static review.",
            "idle": "pass-static; animated seam not certified here",
            "attack": "best-effort; readable preparation/lunge/recovery, detail and transition variation",
            "hit": "pass-static; readable recoil/recovery, animated flicker not certified here",
            "death": "best-effort; readable collapse to curled side-lying pose, four-pose transition needs playback review",
            "gif_playback_review_by_this_agent": False,
            "dynamic_review_owner": "Root agent's Godot preview and main report.",
        },
    }
    (ROOT / "qa-summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(json.dumps({"ok": True, "states": len(states), "frames": sum(len(s["frames"]) for s in states), "wall_seconds": summary["batch_clock"]["elapsed_seconds"], "finals": summary["finals"]}, ensure_ascii=False))


if __name__ == "__main__":
    main()
