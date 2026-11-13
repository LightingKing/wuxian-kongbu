extends RefCounted
## 一次远征（一部恐怖片）进行中的全部状态：时钟、分队、剧情人物、剧情旗标、已触发的事件、剧情偏移、手表限制、击杀与结算条目。
## 规则由 watch.gd、plot_runner.gd、expedition.gd 实现；这里只存数据、做查询、存读档。

const Scenario = preload("res://core/expedition/scenario.gd")
const IntelState = preload("res://core/intel/intel_state.gd")

var scenario: RefCounted
## 角色 id → character.gd，和 GameState 共用同一批对象。
var characters: Dictionary = {}
## 进入这部片的全部轮回者 id（结算时逐个处理，死了的也在）。
var roster: Array = []
## 全局时间（分钟）。所有分队共用一条时间线。
var clock: int = 0
## 分队 id → {"members": [角色 id], "location": 地点, "items": {道具: 数量}}
var squads: Dictionary = {}
var next_squad_no: int = 2
## 剧情人物 id → {"location": 地点, "alive": bool}
var npcs: Dictionary = {}
var flags: Dictionary = {}
## 通路是否开着，键是 Scenario.path_key。剧本里写了 closed 的通路默认关。
var path_open: Dictionary = {}
## 已触发的事件 id → "original"（按原剧情）或 "altered"（被改写）。
var fired: Dictionary = {}
## 剧情偏移量：每改写一个事件，加上它的惯性等级（设计规格 5.2）。
var deviation: int = 0
## 当前的百米绑定 {"npc", "max_hops", "grace_minutes", "transfer_to"}；空字典表示没有绑定。
var tether: Dictionary = {}
## 角色 id → 已经离开绑定范围多少分钟。
var tether_out: Dictionary = {}
var searched: Dictionary = {}
## 聊过的固定话题：话题 id → true（core/dialogue/topics.gd）。
var topics_seen: Dictionary = {}
## 角色 id → 击杀点数（小数，结算时合计后向下取整）。
var kill_points: Dictionary = {}
var kill_counts: Dictionary = {}
## 结算条目：{"char", "kind", "points", "label", "grade"}，kind 同 settlement.gd。
var ledger: Array = []
## 等待界面去打的战斗；不为空时其他行动都会被拒绝。
var pending_battle: Dictionary = {}
## 等待玩家做的选择 {"id", "prompt", "options": [{"id", "text", "effects"}], "location"}。
var pending_choice: Dictionary = {}
## 等待对话层评估的说服 {"id", "npc", "goal", "difficulty", "keywords", "success", "failure", "location"}。
var pending_check: Dictionary = {}
## 待播的剧情插图（CG）：{"name", "text"}；非空时挡着其他行动，等界面播完再 dismiss。
var pending_cutscene: Dictionary = {}
## 这部片的隐藏事实与线索（剧本的 facts）。
var intel: RefCounted = IntelState.new()
## 感染者 id → 已感染多少分钟（战斗里被咬、没解毒，带出了战斗）。
var infected: Dictionary = {}
## ongoing（进行中）、returned（倒计时结束，回归）、wiped（全员死亡）或剧本 end 效果给的结果。
var outcome: String = "ongoing"
var settled: bool = false


func setup(sc: RefCounted, chars: Dictionary, member_ids: Array[String]) -> void:
	scenario = sc
	characters = chars
	roster = member_ids.duplicate()
	squads = {"s1": {"members": member_ids.duplicate(), "location": String(sc.data["start_location"]), "items": {}}}
	for npc_id: String in sc.data["npcs"]:
		npcs[npc_id] = {"location": String(sc.data["npcs"][npc_id]["location"]), "alive": true}
	for p: Dictionary in sc.data["paths"]:
		path_open[Scenario.path_key(String(p["a"]), String(p["b"]))] = not bool(p.get("closed", false))
	tether = (sc.data["watch"].get("tether", {}) as Dictionary).duplicate()
	intel.load_facts(sc.data.get("facts", {}))


## 有等待处理的战斗、选择、说服或插图时，其他行动都要等。
func is_blocked() -> bool:
	return not (pending_battle.is_empty() and pending_choice.is_empty() and pending_check.is_empty() and pending_cutscene.is_empty())


func is_path_open(a: String, b: String) -> bool:
	return bool(path_open.get(Scenario.path_key(a, b), false))


func is_alive(char_id: String) -> bool:
	return characters.has(char_id) and characters[char_id].alive


func squad_of(char_id: String) -> String:
	for sid: String in squads:
		if (squads[sid]["members"] as Array).has(char_id):
			return sid
	return ""


func location_of(char_id: String) -> String:
	var sid := squad_of(char_id)
	return String(squads[sid]["location"]) if sid != "" else ""


func living_members(squad_id: String) -> Array[String]:
	var out: Array[String] = []
	for c: String in squads[squad_id]["members"]:
		if is_alive(c):
			out.append(c)
	return out


func all_living() -> Array[String]:
	var out: Array[String] = []
	for sid: String in squads:
		out.append_array(living_members(sid))
	return out


func squads_at(loc: String) -> Array[String]:
	var out: Array[String] = []
	for sid: String in squads:
		if squads[sid]["location"] == loc and not living_members(sid).is_empty():
			out.append(sid)
	return out


func members_at(loc: String) -> Array[String]:
	var out: Array[String] = []
	for sid in squads_at(loc):
		out.append_array(living_members(sid))
	return out


func party_at(loc: String) -> bool:
	return not squads_at(loc).is_empty()


## 分队（设计规格 5.4）：把 member_ids 从 squad_id 拆出去，成为一支新分队，返回新 id。
## 拆不出（有人不在这支队里，或者会把原队拆空）时返回空字符串。
func split(squad_id: String, member_ids: Array[String]) -> String:
	if not squads.has(squad_id) or member_ids.is_empty():
		return ""
	var members: Array = squads[squad_id]["members"]
	for c in member_ids:
		if not members.has(c):
			return ""
	if member_ids.size() >= members.size():
		return ""
	var new_id := "s%d" % next_squad_no
	next_squad_no += 1
	for c in member_ids:
		members.erase(c)
	squads[new_id] = {"members": member_ids.duplicate(), "location": squads[squad_id]["location"], "items": {}}
	return new_id


## 合队：两支分队在同一地点时，b 并入 a（成员和道具）。
func merge(a: String, b: String) -> bool:
	if a == b or not squads.has(a) or not squads.has(b) or squads[a]["location"] != squads[b]["location"]:
		return false
	(squads[a]["members"] as Array).append_array(squads[b]["members"])
	var items: Dictionary = squads[a]["items"]
	for k: String in squads[b]["items"]:
		items[k] = float(items.get(k, 0.0)) + float(squads[b]["items"][k])
	squads.erase(b)
	return true


## 把指定的人（不管原来在哪支队）拉出来，组成一支新分队放到 to；返回新分队 id。一个活人都没有时返回空字符串。
func move_members(member_ids: Array, to: String) -> String:
	var moving: Array = []
	for c: String in member_ids:
		if is_alive(c):
			moving.append(c)
	if moving.is_empty():
		return ""
	for sid: String in squads:
		for c in moving:
			(squads[sid]["members"] as Array).erase(c)
	var new_id := "s%d" % next_squad_no
	next_squad_no += 1
	squads[new_id] = {"members": moving, "location": to, "items": {}}
	return new_id


func add_ledger(char_id: String, kind: String, points: float, label: String, grade: String = "") -> void:
	ledger.append({"char": char_id, "kind": kind, "points": points, "label": label, "grade": grade})


## 存档：不含剧本本身（按 id 另行加载）和角色（在 GameState 里）。
func to_dict() -> Dictionary:
	return {
		"scenario": scenario.id,
		"roster": roster.duplicate(),
		"clock": clock,
		"squads": squads.duplicate(true),
		"next_squad_no": next_squad_no,
		"npcs": npcs.duplicate(true),
		"flags": flags.duplicate(true),
		"path_open": path_open.duplicate(),
		"fired": fired.duplicate(),
		"deviation": deviation,
		"tether": tether.duplicate(),
		"tether_out": tether_out.duplicate(),
		"searched": searched.duplicate(),
		"topics_seen": topics_seen.duplicate(),
		"kill_points": kill_points.duplicate(),
		"kill_counts": kill_counts.duplicate(),
		"ledger": ledger.duplicate(true),
		"pending_battle": pending_battle.duplicate(true),
		"pending_choice": pending_choice.duplicate(true),
		"pending_check": pending_check.duplicate(true),
		"pending_cutscene": pending_cutscene.duplicate(true),
		"intel": intel.to_dict(),
		"infected": infected.duplicate(),
		"outcome": outcome,
		"settled": settled,
	}


func load_dict(d: Dictionary, sc: RefCounted, chars: Dictionary) -> void:
	assert(String(d["scenario"]) == sc.id, "存档里的剧本和传入的剧本不一致")
	scenario = sc
	characters = chars
	roster = (d["roster"] as Array).duplicate()
	clock = int(d["clock"])
	squads = (d["squads"] as Dictionary).duplicate(true)
	next_squad_no = int(d["next_squad_no"])
	npcs = (d["npcs"] as Dictionary).duplicate(true)
	flags = (d["flags"] as Dictionary).duplicate(true)
	path_open = (d["path_open"] as Dictionary).duplicate()
	fired = (d["fired"] as Dictionary).duplicate()
	deviation = int(d["deviation"])
	tether = (d["tether"] as Dictionary).duplicate()
	tether_out = {}
	for c: String in d["tether_out"]:
		tether_out[c] = int(d["tether_out"][c])
	searched = (d["searched"] as Dictionary).duplicate()
	topics_seen = (d.get("topics_seen", {}) as Dictionary).duplicate()
	kill_points = (d["kill_points"] as Dictionary).duplicate()
	kill_counts = {}
	for c: String in d["kill_counts"]:
		kill_counts[c] = int(d["kill_counts"][c])
	ledger = (d["ledger"] as Array).duplicate(true)
	pending_battle = (d["pending_battle"] as Dictionary).duplicate(true)
	pending_choice = (d.get("pending_choice", {}) as Dictionary).duplicate(true)
	pending_check = (d.get("pending_check", {}) as Dictionary).duplicate(true)
	pending_cutscene = (d.get("pending_cutscene", {}) as Dictionary).duplicate(true)
	if d.has("intel"):
		intel.load_dict(d["intel"])
	infected = {}
	for c: String in d.get("infected", {}):
		infected[c] = int(d["infected"][c])
	outcome = String(d["outcome"])
	settled = bool(d["settled"])
