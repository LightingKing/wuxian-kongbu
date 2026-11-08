extends RefCounted
## 关系网（设计规格 7.4，核心机制分析 8.2）：每两个人之间、单向的四个数值（0~100）——
##   trust（信任）、affection（好感）、awe（敬畏）、resentment（怨恨），外加标记（恋慕、仇敌、师徒、战友……）。
## get_rel(a, b) 是 a 怎么看 b。没记录过的关系取默认值（data/social/relation_events.json 的 defaults）。
## 事件（救命、被当诱饵、见死不救……）按数据改变当事人和旁观者对行动者的看法。

const DataLoader = preload("res://core/util/data_loader.gd")

const PATH := "res://data/social/relation_events.json"
const KEYS: Array[String] = ["trust", "affection", "awe", "resentment"]

static var _cache: Dictionary = {}

## "a>b" → {"trust", "affection", "awe", "resentment", "tags": [...]}
var pairs: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		var res := DataLoader.load_json(PATH)
		assert(res.ok, res.error)
		_cache = res.data
	return _cache


static func _key(a: String, b: String) -> String:
	return a + ">" + b


func get_rel(a: String, b: String) -> Dictionary:
	if pairs.has(_key(a, b)):
		return pairs[_key(a, b)]
	var d: Dictionary = (data()["defaults"] as Dictionary).duplicate()
	for k in KEYS:
		d[k] = float(d[k])
	d["tags"] = []
	return d


func value(a: String, b: String, key: String) -> float:
	return float(get_rel(a, b)[key])


func change(a: String, b: String, deltas: Dictionary) -> void:
	var r := get_rel(a, b)
	for k: String in deltas:
		r[k] = clampf(float(r[k]) + float(deltas[k]), 0.0, 100.0)
	pairs[_key(a, b)] = r


func add_tag(a: String, b: String, tag: String) -> void:
	var r := get_rel(a, b)
	if not (r["tags"] as Array).has(tag):
		(r["tags"] as Array).append(tag)
	pairs[_key(a, b)] = r


func has_tag(a: String, b: String, tag: String) -> bool:
	return (get_rel(a, b)["tags"] as Array).has(tag)


## 关系事件：actor 对 target 做了某事，witnesses 看到了。返回一条事件记录。
func apply_event(kind: String, actor: String, target: String, witnesses: Array = []) -> Dictionary:
	var ev: Dictionary = data()["events"][kind]
	if ev.has("target_to_actor"):
		change(target, actor, ev["target_to_actor"])
	if ev.has("actor_to_target"):
		change(actor, target, ev["actor_to_target"])
	if ev.has("witness_to_actor"):
		for w: String in witnesses:
			if w != actor and w != target:
				change(w, actor, ev["witness_to_actor"])
	return {"type": "relation_event", "kind": kind, "name": String(ev["name"]), "actor": actor, "target": target, "witnesses": witnesses.duplicate()}


func to_dict() -> Dictionary:
	return {"pairs": pairs.duplicate(true)}


func load_dict(d: Dictionary) -> void:
	pairs = (d["pairs"] as Dictionary).duplicate(true)
