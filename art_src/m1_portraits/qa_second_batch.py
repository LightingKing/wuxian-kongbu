"""Inspect existing task-005 batch-two portraits and create separate previews.

Run with sprite-gen's virtual-environment Python. This script does not generate
art, remove backgrounds, call a provider, or modify source/final images.
"""

from __future__ import annotations

import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / "art_src/m1_portraits"
IDS = (
    "mu_gang", "li_xiao_yi", "xiao_pang_zi", "zhong_nian_fu_nv",
    "alice", "rain", "kaplan", "matt", "jd", "ryan", "red_queen", "zhushen",
)
NONHUMAN = {"red_queen", "zhushen"}
ASSETS = {name: f"game/art/portraits/{name}.png" for name in IDS}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def inspect_asset(name: str) -> tuple[dict, Image.Image | None]:
    path = ROOT / ASSETS[name]
    result = {"id": name, "path": ASSETS[name], "checks": {}, "warnings": [], "sources": []}
    checks = result["checks"]
    checks["exists"] = path.is_file()
    for source in (WORK / "sources" / f"{name}.png", WORK / "sources" / f"{name}.png.raw.png"):
        if source.is_file():
            result["sources"].append({"path": relative(source), "sha256": sha256(source)})
    if not checks["exists"]:
        result["error"] = "Final asset is missing."
        return result, None

    result["sha256"] = sha256(path)
    try:
        with Image.open(path) as opened:
            opened.load()
            result.update(format=opened.format, mode=opened.mode, size=list(opened.size))
            checks.update(png=opened.format == "PNG", rgba=opened.mode == "RGBA",
                          single_frame=getattr(opened, "n_frames", 1) == 1,
                          size=opened.size == (512, 768), decodable=True)
            rgba = opened.convert("RGBA")
    except (OSError, ValueError, Image.DecompressionBombError) as exc:
        checks["decodable"] = False
        result["error"] = str(exc)
        return result, None

    alpha = rgba.getchannel("A")
    histogram = alpha.histogram()
    width, height = rgba.size
    corners = [alpha.getpixel(point) for point in
               ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1))]
    edges = {"top": (0, 0, width, 1), "bottom": (0, height - 1, width, height),
             "left": (0, 0, 1, height), "right": (width - 1, 0, width, height)}
    edge_nonzero = {edge: sum(alpha.crop(box).histogram()[1:]) for edge, box in edges.items()}
    meaningful = alpha.point(lambda value: 255 if value >= 16 else 0).getbbox()
    solid = alpha.point(lambda value: 255 if value >= 128 else 0).getbbox()
    nonzero = sum(histogram[1:])
    result["alpha"] = {
        "minimum": alpha.getextrema()[0], "maximum": alpha.getextrema()[1],
        "histogram_nonzero_bins": {str(value): count for value, count in enumerate(histogram) if count},
        "transparent_pixels": histogram[0], "opaque_pixels": histogram[255],
        "partial_pixels": sum(histogram[1:255]), "near_opaque_pixels_alpha_ge250": sum(histogram[250:]),
        "near_opaque_fraction_of_nonzero": sum(histogram[250:]) / nonzero if nonzero else 0,
        "bbox_nonzero": alpha.getbbox(), "bbox_alpha_ge16": meaningful,
        "bbox_alpha_ge128": solid, "corners": corners, "edge_nonzero": edge_nonzero,
    }
    checks.update(nonempty=nonzero > 0, meaningful_content=meaningful is not None,
                  has_transparency=histogram[0] > 0, corners_transparent=not any(corners),
                  outer_edges_transparent=not any(edge_nonzero.values()))
    if name not in NONHUMAN:
        checks["has_near_opaque_subject_pixels"] = sum(histogram[250:]) > 0
        if histogram[255] == 0:
            result["warnings"].append("No fully opaque pixels; the ordinary character is slightly transparent. Alpha was not modified.")
    elif name == "red_queen":
        checks["substantial_hologram_translucency"] = sum(histogram[32:225]) > nonzero * 0.25
    result["alpha_policy"] = (
        "Intentional translucent hologram; no near-opaque requirement." if name == "red_queen" else
        "Light orb with soft glow; no near-opaque requirement." if name == "zhushen" else
        "Ordinary character: some subject pixels must reach alpha 250 or higher."
    )
    top = meaningful[1] if meaningful else None
    result["headroom_observation"] = {
        "measured_from": "All pixels with alpha >= 16, not a detected head landmark.",
        "top_px": top, "fraction_of_canvas": top / height if top is not None else None,
        "target_px": None if name in NONHUMAN else 61.44,
        "assessment": "Recorded only; nonhuman portraits allow irregular composition. Visual review is required.",
    }
    result["avatar_crop_xyxy"] = [0, 128, 512, 640] if name == "zhushen" else [0, 0, 512, 512]
    return result, rgba


def write_checksums(results: list[dict]) -> None:
    path = ROOT / "art_src/qa/portraits.sha256"
    own_paths = {value.lower() for value in ASSETS.values()}
    retained = []
    if path.exists():
        for line in path.read_text(encoding="utf-8-sig").splitlines():
            match = re.fullmatch(r"[0-9a-fA-F]{64}\s+\*?(.+)", line)
            normalized = match.group(1).replace("\\", "/") if match else None
            if normalized is not None:
                while normalized.startswith("./"):
                    normalized = normalized[2:]
            if normalized is None or normalized.lower() not in own_paths:
                retained.append(line)
    retained.extend(f"{item['sha256']}  {item['path']}" for item in results)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(retained) + "\n", encoding="utf-8")


def make_previews(images: dict[str, Image.Image], results: list[dict]) -> list[dict]:
    directory = WORK / "previews"
    directory.mkdir(parents=True, exist_ok=True)
    previews = []
    for theme, background, foreground in (("dark", "#171c26", "#f3f4f6"), ("light", "#edf0f4", "#202631")):
        board = Image.new("RGB", (768, 1648), background)
        draw = ImageDraw.Draw(board)
        for index, name in enumerate(IDS):
            x, y = (index % 3) * 256, (index // 3) * 412
            draw.text((x + 8, y + 8), name, fill=foreground)
            portrait = images[name].resize((256, 384), Image.Resampling.LANCZOS)
            board.paste(portrait, (x, y + 28), portrait)
        path = directory / f"second_batch_{theme}.png"
        board.save(path)
        previews.append({"path": relative(path), "size": list(board.size), "sha256": sha256(path),
                         "kind": f"portrait_board_{theme}", "grid": [3, 4],
                         "portrait_cell_size": [256, 384], "labels_outside_art": True})

    board = Image.new("RGB", (1312, 1068), "#171c26")
    draw = ImageDraw.Draw(board)
    crops = []
    for index, item in enumerate(results):
        name, crop = item["id"], item["avatar_crop_xyxy"]
        x, y = (index % 4) * 328, (index // 4) * 356
        draw.text((x + 8, y + 8), name, fill="#f3f4f6")
        avatar = images[name].crop(tuple(crop)).resize((328, 328), Image.Resampling.LANCZOS)
        board.paste(avatar, (x, y + 28), avatar)
        crops.append({"id": name, "source": ASSETS[name], "crop_xyxy": crop,
                      "resampling": "LANCZOS", "visual_recognizability": "pending"})
    path = directory / "second_batch_avatars.png"
    board.save(path)
    previews.append({"path": relative(path), "size": list(board.size), "sha256": sha256(path),
                     "kind": "avatar_board", "grid": [4, 3], "avatar_cell_size": [328, 328],
                     "labels_outside_art": True, "crops": crops})
    return previews


def main() -> int:
    results, images = [], {}
    for name in IDS:
        result, image = inspect_asset(name)
        result["automatic_checks_passed"] = all(result["checks"].values())
        results.append(result)
        if image is not None:
            images[name] = image
    passed = all(item["automatic_checks_passed"] for item in results)
    report = {
        "task": "005 second batch", "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "automatic_checks_passed": passed, "visual_review": "pending", "seed": None,
        "notice": "Automatic checks do not establish visual acceptance. Headroom, anatomy, identity, style, hologram/glow and avatar readability need visual review.",
        "assets": results, "previews": [], "checksum_manifest_updated": False,
    }
    if passed:
        report["previews"] = make_previews(images, results)
        write_checksums(results)
        report["checksum_manifest_updated"] = True
    else:
        report["notice"] += " Failed checks: previews/checksums were not updated; any older outputs may be stale."
    WORK.mkdir(parents=True, exist_ok=True)
    report_path = WORK / "qa-second-batch.json"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    for item in results:
        failed = [key for key, value in item["checks"].items() if not value]
        print(f"{item['id']}: {'FAIL: ' + ', '.join(failed) if failed else 'PASS (automatic only)'}")
    print(f"Report: {report_path}\nVisual review remains pending.")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
