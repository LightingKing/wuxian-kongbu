extends RefCounted
## 规则百科（设计规格 3.8、9.5.1、9.6）：玩家已经知道的主神规则，分两部分——
##   公开规则（data/intel/codex.json）：张杰讲规则（剧本 codex 效果）、回归当晚带新人认识主神空间（hub_tour 组）、问主神时按关键词解锁；
##   隐藏规则（rule_discovery.gd）：智者自己推出来的漏洞，发现之前在机制上锁着。
## 同一条只解锁一次；解锁顺序就是百科里的显示顺序。整局有效，随 GameState 存档。

const DataLoader = preload("res://core/util/data_loader.gd")
const RuleDiscovery = preload("res://core/intel/rule_discovery.gd")

const PATH := "res://data/intel/codex.json"

static var _cache: Dictionary = {}

## 条目 id → {"source": 从谁那里知道的（角色 id、"zhushen" ……）}
var known: Dictionary = {}
var order: Array = []
var discovery: RefCounted = RuleDiscovery.new()


static func data() -> Dictionary:
	if _cache.is_empty():
		var res := DataLoader.load_json(PATH)
		assert(res.ok, res.error)
		_cache = res.data["entries"]
	return _cache


static func entry(id: String) -> Dictionary:
	return data().get(id, {})


func is_known(id: String) -> bool:
	return known.has(id)


## 解锁一批条目。返回 [{"type": "codex_unlocked", "entries": [新解锁的 id], "source"}]；全都知道了返回空数组。
func unlock(ids: Array, source: String) -> Array[Dictionary]:
	var fresh: Array[String] = []
	for id in ids:
		var k := String(id)
		if not data().has(k) or known.has(k):
			continue
		known[k] = {"source": source}
		order.append(k)
		fresh.append(k)
	if fresh.is_empty():
		return []
	return [{"type": "codex_unlocked", "entries": fresh, "source": source}]


## 按条目的 group 批量解锁（hub_tour：回归当晚有老手带新人认识光球和房间）。
func unlock_group(group: String, source: String) -> Array[Dictionary]:
	var ids: Array = []
	for id: String in data():
		if String(data()[id].get("group", "")) == group:
			ids.append(id)
	return unlock(ids, source)


## 问主神：问题里提到某条目的关键词就解锁它（主神只答规则，不答剧情）。
func unlock_by_question(text: String) -> Array[Dictionary]:
	var ids: Array = []
	for id: String in data():
		for kw: String in data()[id].get("keywords", []):
			if text.contains(kw):
				ids.append(id)
				break
	return unlock(ids, "zhushen")


## 百科内容：已知的公开规则（按解锁顺序），后面接智者发现的隐藏规则。
func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in order:
		var e := entry(id)
		out.append({"id": id, "title": String(e["title"]), "text": String(e["text"]), "source": String(known[id]["source"]), "hidden": false})
	for r: Dictionary in discovery.encyclopedia():
		out.append({"id": String(r["rule"]), "title": String(r["name"]), "text": "", "source": String(r["by"]), "hidden": true})
	return out


## 还没听说过的公开规则条数（提示玩家去问主神）。
func locked_count() -> int:
	return data().size() - known.size()


func to_dict() -> Dictionary:
	return {"known": known.duplicate(true), "order": order.duplicate(), "discovered": discovery.discovered.duplicate(true)}


func load_dict(d: Dictionary) -> void:
	known = (d.get("known", {}) as Dictionary).duplicate(true)
	order = (d.get("order", []) as Array).duplicate()
	discovery = RuleDiscovery.new()
	discovery.discovered = (d.get("discovered", {}) as Dictionary).duplicate(true)
