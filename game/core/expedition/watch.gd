extends RefCounted
## 手表（设计规格 5.3）与时间流逝：倒计时、黑暗里的恐惧、百米绑定、禁言、抹杀。
## 百米绑定在地点图上的表现：必须在绑定对象所在地点或相邻地点（max_hops）；
## 超出时先警告，连续超出 grace_minutes 分钟以上就被主神抹杀。绑定对象死亡后转移给 transfer_to，没有就解除。

const DataLoader = preload("res://core/util/data_loader.gd")
const Rules = preload("res://core/util/rules.gd")

const RULES_PATH := "res://data/rules/expedition_rules.json"

static var _rules: Dictionary = {}


static func rules() -> Dictionary:
	if _rules.is_empty():
		var res := DataLoader.load_json(RULES_PATH)
		assert(res.ok, res.error)
		_rules = res.data
	return _rules


## 远征里的恐惧变化（轮回者身上的 0~100），增加量按精神力折算，和战斗里一致。返回实际变化量。
static func add_fear(ch: RefCounted, amount: float) -> float:
	var delta := amount
	if amount > 0.0:
		delta = amount * 100.0 / maxf(ch.attributes.total("spirit"), 1.0)
	var before: float = ch.fear
	ch.fear = clampf(ch.fear + delta, 0.0, 100.0)
	return ch.fear - before


## 时间流逝 minutes 分钟。到倒计时为止，超过的部分不算；时间到了就回归。
static func pass_time(st: RefCounted, minutes: int, events: Array[Dictionary]) -> void:
	if minutes <= 0 or st.outcome != "ongoing":
		return
	var duration := int(st.scenario.data["duration_minutes"])
	var m := mini(minutes, duration - st.clock)
	st.clock += m
	_darkness(st, m, events)
	check_tether(st, m, events)
	if st.clock >= duration and st.outcome == "ongoing":
		st.outcome = "returned"
		events.append({"type": "returned", "clock": st.clock})


static func _darkness(st: RefCounted, minutes: int, events: Array[Dictionary]) -> void:
	var rate := float(rules()["dark_fear_per_10_minutes"])
	for sid: String in st.squads:
		var loc := String(st.squads[sid]["location"])
		if not bool(st.scenario.location(loc).get("dark", false)):
			continue
		for c in st.living_members(sid):
			var d := add_fear(st.characters[c], rate * float(minutes) / 10.0)
			if d != 0.0:
				events.append({"type": "fear_changed", "char": c, "amount": d, "fear": st.characters[c].fear, "reason": "darkness"})


## 检查百米绑定。minutes = 这次流逝的时间；刚到达新地点时用 0 检查一次，超出就立刻警告。
static func check_tether(st: RefCounted, minutes: int, events: Array[Dictionary]) -> void:
	if st.tether.is_empty():
		return
	var npc_id := String(st.tether["npc"])
	if not bool(st.npcs[npc_id]["alive"]):
		return
	var npc_loc := String(st.npcs[npc_id]["location"])
	var max_hops := int(st.tether["max_hops"])
	var grace := int(st.tether["grace_minutes"])
	for c in st.all_living():
		var dist: int = st.scenario.hops(st.location_of(c), npc_loc)
		if dist >= 0 and dist <= max_hops:
			st.tether_out.erase(c)
			continue
		if not st.tether_out.has(c):
			st.tether_out[c] = 0
			events.append({"type": "tether_warning", "char": c, "npc": npc_id, "grace_minutes": grace})
		st.tether_out[c] = int(st.tether_out[c]) + minutes
		if int(st.tether_out[c]) > grace:
			erase(st, c, "tether", events)


## 绑定对象死亡：转移给 transfer_to（还活着的话），否则解除。
static func on_tether_npc_died(st: RefCounted, events: Array[Dictionary]) -> void:
	var to := String(st.tether.get("transfer_to", ""))
	st.tether_out.clear()
	if to != "" and st.npcs.has(to) and bool(st.npcs[to]["alive"]):
		st.tether["npc"] = to
		st.tether["transfer_to"] = ""
		events.append({"type": "tether_transferred", "npc": to})
	else:
		release_tether(st, events)


static func release_tether(st: RefCounted, events: Array[Dictionary]) -> void:
	st.tether = {}
	st.tether_out.clear()
	events.append({"type": "tether_released"})


## 被主神抹杀。
static func erase(st: RefCounted, char_id: String, reason: String, events: Array[Dictionary]) -> void:
	var ch: RefCounted = st.characters[char_id]
	ch.alive = false
	ch.flags["erased"] = reason
	st.tether_out.erase(char_id)
	events.append({"type": "erased", "char": char_id, "reason": reason})
	check_wipe(st, events)


static func check_wipe(st: RefCounted, events: Array[Dictionary]) -> void:
	if st.outcome == "ongoing" and st.all_living().is_empty():
		st.outcome = "wiped"
		events.append({"type": "wiped"})


## 禁言：剧情人物在场时说出主神的信息，每句扣分（原著：泄密每句 −10）。返回是否被扣分。
static func leak(st: RefCounted, char_id: String, events: Array[Dictionary]) -> bool:
	var loc: String = st.location_of(char_id)
	for npc_id: String in st.npcs:
		var npc: Dictionary = st.npcs[npc_id]
		if bool(npc["alive"]) and npc["location"] == loc and bool(st.scenario.data["npcs"][npc_id].get("plot", false)):
			var penalty := float(st.scenario.data["watch"].get("gag_penalty", Rules.get_value("settlement", "leak_per_sentence")))
			st.add_ledger(char_id, "penalty", penalty, "泄露主神信息")
			events.append({"type": "gag_penalty", "char": char_id, "points": penalty, "witness": npc_id})
			return true
	events.append({"type": "leak_unwitnessed", "char": char_id})
	return false


## 手表界面：主线任务、剩余时间、击杀、限制条件。
static func view(st: RefCounted, char_id: String) -> Dictionary:
	var constraints: Array = []
	if not st.tether.is_empty():
		constraints.append({
			"kind": "tether",
			"npc": String(st.tether["npc"]),
			"max_hops": int(st.tether["max_hops"]),
			"out_minutes": int(st.tether_out.get(char_id, -1)),
		})
	if st.scenario.data["watch"].has("gag_penalty"):
		constraints.append({"kind": "gag", "penalty": int(st.scenario.data["watch"]["gag_penalty"])})
	return {
		"main_task": String(st.scenario.data["main_task"]),
		"remaining_minutes": int(st.scenario.data["duration_minutes"]) - st.clock,
		"kills": int(st.kill_counts.get(char_id, 0)),
		"kill_points": float(st.kill_points.get(char_id, 0.0)),
		"constraints": constraints,
	}
