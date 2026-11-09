extends RefCounted
## 规则发现（设计规格 3.8，核心机制分析 9.3B）：引擎里有一层隐藏规则和漏洞，被智者发现之前在机制上是锁住的。
## 发现后写进规则百科，并解锁对应的东西（unlocks，例如 "catalog:parts_blueprints" 开放零件图纸页）。
## 规则定义在 data/intel/hidden_rules.json；requires 的各项都满足才能发现：
##   intelligence_min（发现者的智力）、talents（发现者的天赋）、flags（GameState.flags 里为真的旗标）、films_completed_min（发现者经历过的片数）。

const DataLoader = preload("res://core/util/data_loader.gd")
const Talents = preload("res://core/model/talents.gd")

const PATH := "res://data/intel/hidden_rules.json"

static var _cache: Dictionary = {}

## 规则 id → {"by": 发现者 id}
var discovered: Dictionary = {}


static func rules() -> Dictionary:
	if _cache.is_empty():
		var res := DataLoader.load_json(PATH)
		assert(res.ok, res.error)
		_cache = res.data["rules"]
	return _cache


## 发现者满足不了的条件列表（空表示可以发现）。
static func unmet(rule_id: String, thinker: RefCounted, game_state: RefCounted) -> Array[String]:
	var req: Dictionary = rules()[rule_id]["requires"]
	var out: Array[String] = []
	if thinker.attributes.total("intelligence") < float(req.get("intelligence_min", 0.0)):
		out.append("intelligence")
	for t: String in req.get("talents", []):
		if not Talents.has(thinker, t):
			out.append("talent:" + t)
	for f: String in req.get("flags", []):
		if not bool(game_state.flags.get(f, false)):
			out.append("flag:" + f)
	if thinker.films_completed < int(req.get("films_completed_min", 0)):
		out.append("experience")
	return out


func try_discover(rule_id: String, thinker: RefCounted, game_state: RefCounted) -> Dictionary:
	if discovered.has(rule_id):
		return {"type": "rule_known", "rule": rule_id}
	var missing := unmet(rule_id, thinker, game_state)
	if not missing.is_empty():
		return {"type": "rule_not_found", "rule": rule_id, "missing": missing}
	discovered[rule_id] = {"by": thinker.id}
	var r: Dictionary = rules()[rule_id]
	return {"type": "rule_discovered", "rule": rule_id, "name": String(r["name"]), "unlocks": String(r["unlocks"]), "by": thinker.id}


## 让每个智者把能发现的都试一遍（休整期、远征中的思考时间）。
func discover_all(thinkers: Array, game_state: RefCounted) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for rule_id: String in rules():
		if discovered.has(rule_id):
			continue
		for t: RefCounted in thinkers:
			if t.alive and unmet(rule_id, t, game_state).is_empty():
				events.append(try_discover(rule_id, t, game_state))
				break
	return events


func is_unlocked(key: String) -> bool:
	for rule_id: String in discovered:
		if rules()[rule_id]["unlocks"] == key:
			return true
	return false


## 规则百科：已发现的规则，按发现顺序。
func encyclopedia() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rule_id: String in discovered:
		out.append({"rule": rule_id, "name": String(rules()[rule_id]["name"]), "by": String(discovered[rule_id]["by"])})
	return out


func to_dict() -> Dictionary:
	return {"discovered": discovered.duplicate(true)}


func load_dict(d: Dictionary) -> void:
	discovered = (d["discovered"] as Dictionary).duplicate(true)
