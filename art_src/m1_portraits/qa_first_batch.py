"""Check existing task-005 PNGs and build separate review previews.

Run with the sprite-gen virtual environment's Python. This script never
generates artwork, removes backgrounds, or changes a final/source image.
"""

from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
import re
import sys

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / "art_src/m1_portraits"
PORTRAITS = ("zheng_zha", "zhan_lan", "zhang_jie", "matthew")
ASSETS = {
    **{name: f"game/art/portraits/{name}.png" for name in PORTRAITS},
    "cg_laser": "game/art/cg/cg_laser.png",
}
AVATAR_CROP = (0, 0, 512, 512)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def inspect_asset(name: str, path_text: str) -> tuple[dict, Image.Image | None]:
    path = ROOT / path_text
    portrait = name in PORTRAITS
    result = {"id": name, "path": path_text, "exists": path.is_file(), "checks": {}, "warnings": []}
    checks = result["checks"]
    checks["exists"] = result["exists"]
    result["sources"] = []
    for source in (WORK / "sources" / f"{name}.png", WORK / "sources" / f"{name}.png.raw.png"):
        if source.is_file():
            result["sources"].append({"path": relative(source), "sha256": sha256(source)})
    if not result["exists"]:
        result["error"] = "Final asset is missing; no image checks passed."
        return result, None

    result["sha256"] = sha256(path)
    try:
        with Image.open(path) as opened:
            result.update(format=opened.format, mode=opened.mode, size=list(opened.size))
            result["frames"] = getattr(opened, "n_frames", 1)
            opened.load()
            checks["png"] = opened.format == "PNG"
            checks["single_frame"] = result["frames"] == 1
            checks["size"] = opened.size == ((512, 768) if portrait else (1920, 1080))
            if portrait:
                checks["rgba"] = opened.mode == "RGBA"
            rgba = opened.convert("RGBA")
    except (OSError, ValueError, Image.DecompressionBombError) as exc:
        checks["decodable"] = False
        result["error"] = str(exc)
        return result, None

    checks["decodable"] = True
    alpha = rgba.getchannel("A")
    histogram = alpha.histogram()
    width, height = rgba.size
    result["alpha"] = {
        "minimum": alpha.getextrema()[0],
        "maximum": alpha.getextrema()[1],
        "transparent_pixels": histogram[0],
        "opaque_pixels": histogram[255],
        "near_opaque_pixels_alpha_ge250": sum(histogram[250:]),
        "near_opaque_fraction_of_nonzero": sum(histogram[250:]) / sum(histogram[1:]) if sum(histogram[1:]) else 0,
        "partial_pixels": sum(histogram[1:255]),
        "histogram_0_to_255": histogram,
        "bbox_nonzero": alpha.getbbox(),
    }
    if portrait:
        corners = [alpha.getpixel(point) for point in
                   ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1))]
        edge_boxes = {
            "top": (0, 0, width, 1), "bottom": (0, height - 1, width, height),
            "left": (0, 0, 1, height), "right": (width - 1, 0, width, height),
        }
        edge_nonzero = {}
        for edge, box in edge_boxes.items():
            edge_hist = alpha.crop(box).histogram()
            edge_nonzero[edge] = sum(edge_hist[1:])
        meaningful = alpha.point(lambda value: 255 if value >= 16 else 0).getbbox()
        solid = alpha.point(lambda value: 255 if value >= 128 else 0).getbbox()
        result["alpha"].update(corners=corners, edge_nonzero=edge_nonzero,
                               bbox_alpha_ge16=meaningful, bbox_alpha_ge128=solid)
        top = meaningful[1] if meaningful else None
        result["headroom_observation"] = {
            "measured_from": "Top of all pixels with alpha >= 16; not a detected head landmark.",
            "top_px": top,
            "fraction_of_canvas": top / height if top is not None else None,
            "target_fraction": 0.08,
            "target_px": 61.44,
            "difference_from_target_px": top - 61.44 if top is not None else None,
            "assessment": "Recorded only. Human review must confirm approximately 8% headroom.",
        }
        checks.update(corners_transparent=not any(corners),
                      outer_edges_transparent=not any(edge_nonzero.values()),
                      nonempty=alpha.getbbox() is not None,
                      meaningful_content=meaningful is not None,
                      has_near_opaque_subject_pixels=sum(histogram[250:]) > 0,
                      has_transparency=histogram[0] > 0)
        if histogram[255] == 0:
            result["warnings"].append("No fully opaque pixels: the subject is slightly transparent. Human acceptance is required; alpha was not modified.")
    else:
        checks["fully_opaque"] = alpha.getextrema() == (255, 255)
    return result, rgba


def write_checksums(results: list[dict]) -> None:
    target = ROOT / "art_src/qa/portraits.sha256"
    own_paths = {path.lower() for path in ASSETS.values()}
    retained = []
    if target.exists():
        for line in target.read_text(encoding="utf-8-sig").splitlines():
            match = re.fullmatch(r"[0-9a-fA-F]{64}\s+\*?(.+)", line)
            normalized = match.group(1).replace("\\", "/") if match else None
            if normalized is not None:
                while normalized.startswith("./"):
                    normalized = normalized[2:]
            if normalized is None or normalized.lower() not in own_paths:
                retained.append(line)
    retained.extend(f"{result['sha256']}  {result['path']}" for result in results)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text("\n".join(retained) + "\n", encoding="utf-8")


def make_previews(images: dict[str, Image.Image]) -> list[dict]:
    preview_dir = WORK / "previews"
    preview_dir.mkdir(parents=True, exist_ok=True)
    cell_width, image_height, label_height = 256, 384, 28
    cell_height = image_height + label_height
    board = Image.new("RGB", (4 * cell_width, 2 * cell_height))
    draw = ImageDraw.Draw(board)
    for row, (background, foreground, label) in enumerate(
        (("#171c26", "#f3f4f6", "dark"), ("#edf0f4", "#202631", "light"))
    ):
        for column, name in enumerate(PORTRAITS):
            x, y = column * cell_width, row * cell_height
            draw.rectangle((x, y, x + cell_width - 1, y + cell_height - 1), fill=background)
            draw.text((x + 8, y + 8), f"{name} / {label}", fill=foreground)
            resized = images[name].resize((cell_width, image_height), Image.Resampling.LANCZOS)
            board.paste(resized, (x, y + label_height), resized)
    board_path = preview_dir / "portraits_dark_light.png"
    board.save(board_path)
    previews = [{"path": relative(board_path), "size": list(board.size),
                 "sha256": sha256(board_path), "kind": "dark_light_portrait_board",
                 "portrait_cell_size": [256, 384], "labels_outside_art": True}]
    avatar_board = Image.new("RGB", (328 * len(PORTRAITS), 356), "#181d27")
    avatar_draw = ImageDraw.Draw(avatar_board)
    for column, name in enumerate(PORTRAITS):
        avatar = images[name].crop(AVATAR_CROP).resize((328, 328), Image.Resampling.LANCZOS)
        avatar_path = preview_dir / f"{name}_avatar_328.png"
        avatar.save(avatar_path)
        previews.append({"path": relative(avatar_path), "size": [328, 328],
                         "sha256": sha256(avatar_path), "kind": "avatar_crop",
                         "source": ASSETS[name], "crop_xyxy": list(AVATAR_CROP),
                         "resampling": "LANCZOS", "visual_recognizability": "pending"})
        avatar_board.paste(avatar, (column * 328, 28), avatar)
        avatar_draw.text((column * 328 + 10, 8), name, fill="white")
    avatar_board_path = preview_dir / "avatars_328_board.png"
    avatar_board.save(avatar_board_path)
    previews.append({"path": relative(avatar_board_path), "size": list(avatar_board.size),
                     "sha256": sha256(avatar_board_path), "kind": "avatar_review_board",
                     "avatar_cell_size": [328, 328], "labels_outside_art": True})
    return previews


def main() -> int:
    results, images = [], {}
    for name, path in ASSETS.items():
        result, rgba = inspect_asset(name, path)
        result["automatic_checks_passed"] = all(result["checks"].values())
        results.append(result)
        if rgba is not None:
            images[name] = rgba
    passed = all(result["automatic_checks_passed"] for result in results)
    report = {
        "task": "005 first batch", "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "automatic_checks_passed": passed, "visual_review": "pending",
        "notice": "Automatic PNG/alpha checks do not constitute visual acceptance. Headroom, identity, anatomy, style and avatar recognizability require human review.",
        "assets": results, "previews": [], "checksum_manifest_updated": False,
    }
    if passed:
        report["previews"] = make_previews(images)
        write_checksums(results)
        report["checksum_manifest_updated"] = True
    else:
        report["notice"] += " Asset checks failed: previews and checksum manifest were not updated; any existing outputs may be stale."
    WORK.mkdir(parents=True, exist_ok=True)
    (WORK / "qa.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for result in results:
        failures = [check for check, value in result["checks"].items() if not value]
        print(f"{result['id']}: {'PASS (automatic only)' if not failures else 'FAIL: ' + ', '.join(failures)}")
    print(f"Report: {WORK / 'qa.json'}")
    print("Visual review remains pending.")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
