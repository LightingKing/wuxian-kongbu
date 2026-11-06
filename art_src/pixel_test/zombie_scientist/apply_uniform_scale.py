"""Set one native curation transform across all poses; never edit source pixels."""
import json
from pathlib import Path

from sprite_gen.curate.curation import write_curation_atomic
from sprite_gen.spec.runio import publish_guard


run = Path(__file__).resolve().parent / "run-native"
request = json.loads((run / "sprite-request.json").read_text(encoding="utf-8"))
payload = {"version": 1, "kind": "sprite-gen-curation", "pixel_unfake": True, "states": {}}
for state, spec in request["states"].items():
	indices = list(range(spec["frames"]))
	for index in indices:
		assert (run / "frames" / state / f"frame-{index}.png").is_file()
	payload["states"][state] = {
		"selected": indices,
		"transforms": {str(index): {"scale": 0.8, "dx": 0, "dy": 3.2, "flipX": 0}
						for index in indices},
	}
with publish_guard(run):
	backup = write_curation_atomic(run, payload)
print(json.dumps({"uniform_scale": 0.8, "dy": 3.2, "states": list(payload["states"]),
					"stale_backup": backup}))
