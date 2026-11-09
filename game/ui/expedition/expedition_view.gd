extends RefCounted
## 地点图与手表界面的取数层：把 Expedition 的状态整理成界面能直接画的东西。
## 界面只调用这里的行动方法，拿回事件；不在这里写规则。

const EventText = preload("res://ui/event_text.gd")
const Watch = preload("res://core/expedition/watch.gd")
const BattleData = preload("res://core/battle/battle_data.gd")

var ex: RefCounted
var names: Dictionary = {}

## names：角色 id → 显示名（界面从人物表传入，事件文本用）。
func _init(expedition: RefCounted, char_names: Dictionary = {}) -> void:
	ex = expedition
	names = char_names.duplicate()
	for npc_id: String in ex.st.scenario.data.get("npcs", {}):
		var def: Dictionary = ex.st.scenario.data["npcs"][npc_id]
		names[npc_id] = String(def.get("name", npc_id))
	for loc_id: String in ex.st.scenario.data.get("locations", {}):
		names[loc_id] = String(ex.st.scenario.location(loc_id).get("name", loc_id))
	for ev: Dictionary in ex.st.scenario.events():
		names[String(ev["id"])] = String(ev.get("label", ev["id"]))
	for fact_id: String in ex.st.scenario.data.get("facts", {}):
		var fact: Dictionary = ex.st.scenario.data["facts"][fact_id]
		names[fact_id] = String(fact.get("statement", fact_id))
		for clue_id: String in fact.get("clues", {}):
			names[clue_id] = String(fact.get("statement", clue_id))


func squad_id() -> String:
	for sid: String in ex.st.squads:
		if not ex.st.living_members(sid).is_empty():
			return sid
	return ""


func location() -> String:
	var sid := squad_id()
	return String(ex.st.squads[sid]["location"]) if sid != "" else ""


func blocked_reason() -> String:
	if ex.st.outcome != "ongoing":
		return "ended"
	if not ex.st.pending_battle.is_empty():
		return "battle"
	if not ex.st.pending_choice.is_empty():
		return "choice"
	if not ex.st.pending_check.is_empty():
		return "check"
	return ""


## 地图：每个地点的坐标、是否在这里、是否相邻可走、有没有搜过、黑不黑、有谁。
func map() -> Array[Dictionary]:
	var here := location()
	var around: Array[String] = ex.st.scenario.neighbors(here) if here != "" else []
	var out: Array[Dictionary] = []
	for loc_id: String in ex.st.scenario.data["locations"]:
		var info: Dictionary = ex.st.scenario.location(loc_id)
		var pos: Array = info.get("pos", [0, 0])
		var here_now := loc_id == here
		var adjacent := around.has(loc_id)
		out.append({
			"id": loc_id,
			"name": String(info.get("name", loc_id)),
			"pos": Vector2(float(pos[0]), float(pos[1])),
			"here": here_now,
			"adjacent": adjacent,
			"open": here_now or not adjacent or ex.st.is_path_open(here, loc_id),
			"searched": ex.st.searched.has(loc_id),
			"dark": Watch.is_dark(ex.st, loc_id),
			"risk": info.has("search_encounter"),
			"npcs": _npcs_at(loc_id),
		})
	return out


func _npcs_at(loc_id: String) -> Array[String]:
	var out: Array[String] = []
	for npc_id: String in ex.st.npcs:
		if ex.st.npcs[npc_id]["location"] == loc_id and bool(ex.st.npcs[npc_id]["alive"]):
			var def: Dictionary = ex.st.scenario.data["npcs"].get(npc_id, {})
			out.append(String(def.get("name", npc_id)))
	return out


## 能搭话的人：当前地点的剧情人物 + 同分队的队友。
func talk_targets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var loc := location()
	for npc_id: String in ex.st.npcs:
		var n: Dictionary = ex.st.npcs[npc_id]
		if String(n["location"]) == loc and bool(n["alive"]):
			out.append({"id": npc_id, "name": _name(npc_id), "kind": "npc"})
	var sid := squad_id()
	if sid != "":
		for c: String in ex.st.squads[sid]["members"]:
			if ex.st.is_alive(c):
				out.append({"id": c, "name": _name(c), "kind": "mate"})
	return out


## 信任到一定门槛会说实话的配置（剧本 trust 段）；没有就返回空字典。
func trust_def(id: String) -> Dictionary:
	return (ex.st.scenario.data.get("trust", {}) as Dictionary).get(id, {})


## 手表：主线、剩余时间、击杀、绑定、禁言。
func watch() -> Dictionary:
	var sid := squad_id()
	var who := ""
	if sid != "":
		var living: Array[String] = ex.st.living_members(sid)
		who = living[0] if not living.is_empty() else ""
	var view: Dictionary = ex.watch_view(who) if who != "" else {}
	var kills := 0
	var points := 0.0
	for c: String in ex.st.kill_counts:
		kills += int(ex.st.kill_counts[c])
	for c: String in ex.st.kill_points:
		points += float(ex.st.kill_points[c])
	var tether := ""
	if not ex.st.tether.is_empty():
		tether = "%s（%d 格内）" % [_name(String(ex.st.tether["npc"])), int(ex.st.tether["max_hops"])]
	return {
		"main_task": String(view.get("main_task", ex.st.scenario.data["main_task"])),
		"remaining_minutes": int(view.get("remaining_minutes", ex.st.scenario.data["duration_minutes"])),
		"clock": int(ex.st.clock),
		"kills": kills,
		"kill_points": points,
		"tether": tether,
		"gag": bool(ex.st.scenario.data["watch"].has("gag_penalty")),
		"dark": Watch.is_dark(ex.st, location()),
	}


## 当前分队的成员（活着的和死了的都列出来，界面上灰掉）。
func members() -> Array[Dictionary]:
	var sid := squad_id()
	var out: Array[Dictionary] = []
	if sid == "":
		return out
	for c: String in ex.st.squads[sid]["members"]:
		var ch: RefCounted = ex.st.characters[c]
		out.append({
			"id": c,
			"name": ch.display_name,
			"hp": ch.hp,
			"hp_max": ch.hp_max(),
			"fear": ch.fear,
			"alive": ch.alive,
			"infected": ex.st.infected.has(c),
		})
	return out


## 等待处理的事：选择、说服或战斗。
func pending() -> Dictionary:
	if not ex.st.pending_choice.is_empty():
		var c: Dictionary = ex.st.pending_choice
		var options: Array = []
		for o: Dictionary in c["options"]:
			options.append({"id": String(o["id"]), "text": String(o["text"])})
		return {"kind": "choice", "id": String(c["id"]), "prompt": String(c["prompt"]), "options": options}
	if not ex.st.pending_check.is_empty():
		var k: Dictionary = ex.st.pending_check
		var fact := String(k.get("requires_fact", ""))
		var fact_status: String = ex.st.intel.status(fact) if fact != "" else ""
		return {
			"kind": "check", "id": String(k["id"]), "npc": _name(String(k["npc"])), "goal": String(k["goal"]),
			"difficulty": int(k["difficulty"]), "keywords": (k.get("keywords", []) as Array).duplicate(),
			"requires_fact": fact, "fact_name": _name(fact), "fact_ready": fact_status == "inferred" or fact_status == "confirmed",
			"thinker": _name(best_thinker_id()),
		}
	if not ex.st.pending_battle.is_empty():
		var b: Dictionary = ex.st.pending_battle
		var enemies: Array = []
		for g: Dictionary in b["enemies"]:
			var def := String(g["def"])
			var info: Dictionary = BattleData.enemies().get(def, {})
			enemies.append("%s ×%d" % [String(info.get("name", def)), int(g.get("count", 1))])
		return {"kind": "battle", "location": String(b["location"]), "enemies": enemies}
	return {}


## 事件流（最近 n 条），已经翻成中文。
func log_tail(n: int = 8) -> Array[String]:
	var out: Array[String] = []
	var start := maxi(0, ex.history.size() - n)
	for i in range(start, ex.history.size()):
		var line := EventText.describe(ex.history[i], names)
		if line != "":
			out.append(line)
	return out


func can_move(to: String) -> bool:
	return blocked_reason() == "" and ex.st.scenario.neighbors(location()).has(to) and ex.st.is_path_open(location(), to)


func move(to: String) -> Array[Dictionary]:
	return ex.move(squad_id(), to)


func search() -> Array[Dictionary]:
	return ex.search(squad_id())


func rest(minutes: int = 10) -> Array[Dictionary]:
	return ex.rest(squad_id(), minutes)


func choose(option_id: String) -> Array[Dictionary]:
	return ex.choose(option_id)


func persuade(level: int) -> Array[Dictionary]:
	return ex.resolve_persuasion(level)


## 用选中的关键词开口，说服力由离线裁决算。
func persuade_with(keywords: Array) -> Array[Dictionary]:
	return ex.persuade_with(keywords, best_thinker_id())


## 队伍里最适合开口的人（智力最高）。
func best_thinker_id() -> String:
	var best := ""
	var iq := -1.0
	for c: String in ex.st.all_living():
		var v := float(ex.st.characters[c].attributes.total("intelligence"))
		if v > iq:
			iq = v
			best = c
	return best


## 现在能用的道具：感染的人用解毒剂、受伤的人用喷雾。先看自己的，再看分队共用的。
func item_actions() -> Array[Dictionary]:
	var sid := squad_id()
	var out: Array[Dictionary] = []
	if sid == "":
		return out
	var shared: Dictionary = ex.st.squads[sid]["items"]
	for c: String in ex.st.squads[sid]["members"]:
		if not ex.st.is_alive(c):
			continue
		var ch: RefCounted = ex.st.characters[c]
		for item: String in ["antidote", "spray"]:
			var count := float(ch.items.get(item, 0.0)) + float(shared.get(item, 0.0))
			if count <= 0.0:
				continue
			if item == "antidote" and not ex.st.infected.has(c):
				continue
			if item == "spray" and ch.hp >= ch.hp_max():
				continue
			out.append({"char": c, "name": ch.display_name, "item": item,
				"label": "给%s用%s" % [ch.display_name, "解毒剂" if item == "antidote" else "喷雾"]})
	return out


func use_item(char_id: String, item_id: String) -> Array[Dictionary]:
	return ex.use_item(char_id, item_id)


func deduce(fact_id: String, thinker_id: String) -> Array[Dictionary]:
	return ex.deduce(fact_id, thinker_id)


func battle_units() -> Array[RefCounted]:
	return ex.battle_units({})


func report_battle(battle: RefCounted) -> Array[Dictionary]:
	return ex.report_battle(battle)


func ended() -> bool:
	return ex.st.outcome != "ongoing"


func outcome() -> String:
	return ex.st.outcome


func _name(id: String) -> String:
	return String(names.get(id, id))
