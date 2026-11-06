"""Forward facing options through sprite-gen 3.15.0's native gen-set runner.

The CLI does not expose these gen options. Scheduling, input resolution, reuse,
validation and reports remain owned by sprite_gen.gen.gen_set.run_set.
--handed is required because regen may otherwise fall back to mirroring.
"""

import argparse
from pathlib import Path
import sys

from sprite_gen.gen import gen_set


def main() -> int:
	sys.stdout.reconfigure(encoding="utf-8")
	sys.stderr.reconfigure(encoding="utf-8")
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("--run-dir", required=True, type=Path)
	parser.add_argument("--states")
	parser.add_argument("--provider", choices=["codex"], required=True)
	parser.add_argument("--facing", choices=["left", "right"], required=True)
	parser.add_argument("--handed", required=True)
	parser.add_argument("--concurrency", type=int, default=2)
	parser.add_argument("--force", action="store_true")
	args = parser.parse_args()
	if not args.handed.strip():
		parser.error("--handed must be nonempty to disable mirror fallback")
	if args.concurrency < 1:
		parser.error("--concurrency must be positive")

	def generate(prompt_file, out, refs, report, *, provider, model, log):
		command = [sys.executable, "-m", "sprite_gen.cli", "gen",
			"--prompt-file", str(prompt_file), "--out", str(out),
			"--report", str(report), "--provider", provider,
			"--direction", "side", "--facing", args.facing,
			"--facing-fix", "regen", "--handed", args.handed]
		for ref in refs:
			command.extend(["--ref", str(ref)])
		if model:
			command.extend(["--model", model])
		return gen_set.run_logged(command, log)

	result = gen_set.run_set(
		run_dir=args.run_dir,
		states=[s.strip() for s in args.states.split(",") if s.strip()] if args.states else None,
		provider=args.provider,
		model=None,
		concurrency=args.concurrency,
		force=args.force,
		gen_runner=generate,
	)
	return 0 if not result["failed"] and not result["not_started"] else 1


if __name__ == "__main__":
	raise SystemExit(main())
