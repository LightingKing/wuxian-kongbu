"""写入原生 curation 统一变换；像素变换仍由 sprite-gen compose 执行。"""

import argparse
import json
from pathlib import Path

from sprite_gen.curate.curation import write_curation_atomic
from sprite_gen.spec.runio import publish_guard


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--run-dir", required=True, type=Path)
	parser.add_argument("--scale", type=float, default=0.8)
	parser.add_argument("--dy", type=float, default=3.2)
	args = parser.parse_args()
	if args.scale <= 0:
		parser.error("scale must be positive")
	request = json.loads((args.run_dir / "sprite-request.json").read_text(encoding="utf-8"))
	payload = {"kind": "sprite-gen-curation", "version": 1, "states": {}}
	for state, spec in request["states"].items():
		payload["states"][state] = {"transforms": {str(i): {"scale": args.scale, "dx": 0, "dy": args.dy, "rotate": 0, "flipX": 0} for i in range(spec["frames"])}}
	with publish_guard(args.run_dir):
		backup = write_curation_atomic(args.run_dir, payload)
	print(json.dumps({"states": list(payload["states"]), "uniform_scale": args.scale, "dy": args.dy, "backup": backup}, ensure_ascii=True))


if __name__ == "__main__":
	main()
