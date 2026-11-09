extends RefCounted
## 一部恐怖片的剧本数据（设计规格 5.1~5.3、8"剧本来源抽象"）：地点图、通路、剧情人物、剧情事件、手表限制。
## 手写剧本和以后主神 AI 出的题都产出这种结构。剧本是静态数据，进行中的状态在 expedition_state.gd。

const DataLoader = preload("res://core/util/data_loader.gd")
const BattleData = preload("res://core/battle/battle_data.gd")

const REQUIRED: Array[String] = ["id", "name", "start_location", "duration_minutes", "main_task", "locations", "paths", "npcs", "watch", "events"]
const EFFECT_KEYS: Array[String] = ["say", "set_flag", "npc_move", "npc_die", "open_path", "close_path", "fear", "battle", "side_plot", "bonus", "penalty", "tether_release", "end", "choice", "persuade", "give", "move_members", "damage", "set_tether", "clue", "relation", "erase", "delay", "cg"]

var data: Dictionary = {}
var id: String = ""


func _init(d: Dictionary = {}) -> void:
	data = d
	id = String(d.get("id", ""))


## 从 JSON 文件读取剧本；读不到时返回 null。
static func load_file(path: String) -> RefCounted:
	var res := DataLoader.load_json(path)
	if not res.ok:
		push_error(res.error)
		return null
	return new(res.data)


func location(loc_id: String) -> Dictionary:
	return data["locations"].get(loc_id, {})


func has_location(loc_id: String) -> bool:
	return data["locations"].has(loc_id)


static func path_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a


## 两地之间的通路，没有直接通路时返回空字典。
func path_between(a: String, b: String) -> Dictionary:
	for p: Dictionary in data["paths"]:
		if path_key(String(p["a"]), String(p["b"])) == path_key(a, b):
			return p
	return {}


func neighbors(loc_id: String) -> Array[String]:
	var out: Array[String] = []
	for p: Dictionary in data["paths"]:
		if p["a"] == loc_id:
			out.append(String(p["b"]))
		elif p["b"] == loc_id:
			out.append(String(p["a"]))
	return out


## 两地之间隔几段通路（不管通路开没开：百米绑定量的是实际距离）。走不到返回 -1。
func hops(a: String, b: String) -> int:
	if a == b:
		return 0
	var dist := {a: 0}
	var queue: Array[String] = [a]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for n in neighbors(cur):
			if not dist.has(n):
				dist[n] = int(dist[cur]) + 1
				if n == b:
					return int(dist[n])
				queue.append(n)
	return -1


func events() -> Array:
	return data["events"]


func validate() -> Array[String]:
	var errors: Array[String] = DataLoader.missing_keys(data, REQUIRED, "剧本")
	if not errors.is_empty():
		return errors
	if not has_location(String(data["start_location"])):
		errors.append("起点 %s 不存在" % data["start_location"])
	for p: Dictionary in data["paths"]:
		for end in [p.get("a", ""), p.get("b", "")]:
			if not has_location(String(end)):
				errors.append("通路引用了不存在的地点 %s" % end)
	for npc_id: String in data["npcs"]:
		if not has_location(String(data["npcs"][npc_id].get("location", ""))):
			errors.append("剧情人物 %s 的位置不存在" % npc_id)
	var tether: Dictionary = data["watch"].get("tether", {})
	if not tether.is_empty() and not data["npcs"].has(String(tether.get("npc", ""))):
		errors.append("百米绑定的对象不存在")
	var seen := {}
	for ev: Dictionary in data["events"]:
		var ev_id := String(ev.get("id", ""))
		if ev_id == "" or seen.has(ev_id):
			errors.append("事件 id 为空或重复：%s" % ev_id)
		seen[ev_id] = true
		if not ev.has("at") and not ev.has("when"):
			errors.append("事件 %s 既没有 at 也没有 when" % ev_id)
		_check_effects(ev_id, ev.get("effects", []), errors)
		for alt: Dictionary in ev.get("alterations", []):
			_check_effects(ev_id, alt.get("effects", []), errors)
	return errors


## 检查一组效果，连同选项、说服结果、战斗后效果里套着的效果。
func _check_effects(ev_id: String, effects: Array, errors: Array[String]) -> void:
	for e: Dictionary in effects:
		_check_effect(ev_id, e, errors)
		if e.has("choice"):
			for o: Dictionary in e["choice"].get("options", []):
				_check_effects(ev_id, o.get("effects", []), errors)
		if e.has("persuade"):
			_check_effects(ev_id, e["persuade"].get("success", []), errors)
			_check_effects(ev_id, e["persuade"].get("failure", []), errors)
		if e.has("battle"):
			_check_effects(ev_id, e["battle"].get("after_victory", []), errors)
			_check_effects(ev_id, e["battle"].get("after_defeat", []), errors)


func _check_effect(ev_id: String, e: Dictionary, errors: Array[String]) -> void:
	for k: String in e:
		if not EFFECT_KEYS.has(k):
			errors.append("事件 %s 有未知效果 %s" % [ev_id, k])
	if e.has("battle"):
		for group: Dictionary in e["battle"].get("enemies", []):
			if not BattleData.enemies().has(String(group.get("def", ""))):
				errors.append("事件 %s 引用了不存在的敌人 %s" % [ev_id, group.get("def", "")])
	if e.has("npc_move") and not has_location(String(e["npc_move"].get("to", ""))):
		errors.append("事件 %s 把人移到不存在的地点" % ev_id)
	if e.has("move_members") and not has_location(String(e["move_members"].get("to", ""))):
		errors.append("事件 %s 把队员移到不存在的地点" % ev_id)
	if e.has("choice") and (e["choice"].get("options", []) as Array).is_empty():
		errors.append("事件 %s 的选择没有选项" % ev_id)
	if e.has("clue"):
		var known := false
		for f: String in data.get("facts", {}):
			if (data["facts"][f].get("clues", {}) as Dictionary).has(String(e["clue"])):
				known = true
		if not known:
			errors.append("事件 %s 的线索 %s 不属于任何事实" % [ev_id, e["clue"]])
