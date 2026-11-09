extends RefCounted
## 剧情事件（设计规格 5.2）：定时事件（at，到点发生）和条件事件（when，条件一成立就发生），每个只发生一次。
## 效果见 apply_effect。choice（等玩家选）、persuade（等说服检定）、battle（等打完）会让远征停下来等待，之后才继续。
## erase 是主神抹杀（超出百米绑定、剧本直接判定），delay 只推进时钟（地点内的耽搁，不触发定时事件）。
## 剧情惯性：原剧情默认照常发生；事件的 alterations 里第一条 if 成立的改写会替代原效果，
## 剧情偏移量加上事件的惯性等级（inertia，默认 1）。偏移量可以触发连锁事件（deviation_at_least）。

const Conditions = preload("res://core/expedition/conditions.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const Watch = preload("res://core/expedition/watch.gd")


## 下一个还没发生的定时事件（时间最早的；同一时间按剧本顺序）。没有返回空字典。
static func next_timed(st: RefCounted) -> Dictionary:
	var best: Dictionary = {}
	for ev: Dictionary in st.scenario.events():
		if not ev.has("at") or st.fired.has(String(ev["id"])):
			continue
		if best.is_empty() or int(ev["at"]) < int(best["at"]):
			best = ev
	return best


static func fire(st: RefCounted, ev: Dictionary, events: Array[Dictionary]) -> void:
	var ev_id := String(ev["id"])
	var effects: Array = ev.get("effects", [])
	var mode := "original"
	for alt: Dictionary in ev.get("alterations", []):
		if Conditions.check(alt.get("if", {}), st):
			effects = alt.get("effects", [])
			mode = "altered"
			st.deviation += int(ev.get("inertia", 1))
			events.append({"type": "plot_altered", "event": ev_id, "label": String(alt.get("label", "")), "deviation": st.deviation})
			break
	st.fired[ev_id] = mode
	events.append({"type": "plot_event", "event": ev_id, "mode": mode, "clock": st.clock})
	apply_effects(st, effects, String(ev.get("location", "")), events)


## 让所有条件已经成立的条件事件发生（一个事件的效果可能让另一个的条件成立，所以反复检查）。
## 出现待打的战斗或远征结束时停下。
static func run_conditional(st: RefCounted, events: Array[Dictionary]) -> void:
	var changed := true
	while changed and st.outcome == "ongoing" and not st.is_blocked():
		changed = false
		for ev: Dictionary in st.scenario.events():
			if ev.has("when") and not st.fired.has(String(ev["id"])) and Conditions.check(ev["when"], st):
				fire(st, ev, events)
				changed = true
				break


static func apply_effects(st: RefCounted, effects: Array, location: String, events: Array[Dictionary]) -> void:
	for e: Dictionary in effects:
		apply_effect(st, e, location, events)


## 效果的收益人：数组 = 指定的人；"present" = 事件地点上的轮回者；"all" = 所有活着的轮回者。只算活着的。
static func recipients(st: RefCounted, spec: Variant, location: String) -> Array[String]:
	var out: Array[String] = []
	if spec is Array:
		for c: String in spec:
			if st.is_alive(c):
				out.append(c)
	elif String(spec) == "present":
		out = st.members_at(location)
	else:
		out = st.all_living()
	return out


static func apply_effect(st: RefCounted, e: Dictionary, location: String, events: Array[Dictionary]) -> void:
	if e.has("say"):
		events.append({"type": "dialogue", "speaker": String(e["say"]["speaker"]), "text": String(e["say"]["text"])})
	if e.has("set_flag"):
		st.flags[String(e["set_flag"])] = e.get("value", true)
		events.append({"type": "flag_set", "flag": String(e["set_flag"])})
	if e.has("npc_move"):
		var npc_id := String(e["npc_move"]["npc"])
		st.npcs[npc_id]["location"] = String(e["npc_move"]["to"])
		events.append({"type": "npc_moved", "npc": npc_id, "to": st.npcs[npc_id]["location"]})
	if e.has("npc_die"):
		var dead := String(e["npc_die"])
		st.npcs[dead]["alive"] = false
		events.append({"type": "npc_died", "npc": dead})
		if not st.tether.is_empty() and st.tether["npc"] == dead:
			Watch.on_tether_npc_died(st, events)
	if e.has("open_path") or e.has("close_path"):
		var open := e.has("open_path")
		var ends: Array = e["open_path"] if open else e["close_path"]
		st.path_open[Scenario.path_key(String(ends[0]), String(ends[1]))] = open
		events.append({"type": "path_changed", "a": String(ends[0]), "b": String(ends[1]), "open": open})
	if e.has("fear"):
		var where := String(e["fear"].get("location", ""))
		var targets: Array[String] = st.members_at(where) if where != "" else st.all_living()
		for c in targets:
			var d := Watch.add_fear(st.characters[c], float(e["fear"]["amount"]))
			events.append({"type": "fear_changed", "char": c, "amount": d, "fear": st.characters[c].fear, "reason": "plot"})
	if e.has("battle"):
		_battle(st, e["battle"], events)
	if e.has("side_plot"):
		var sp: Dictionary = e["side_plot"]
		var who := recipients(st, sp.get("recipients", "present"), location)
		for c in who:
			st.add_ledger(c, "side_plot", float(sp["points"]), String(sp["label"]), String(sp["grade"]))
		st.flags["side:" + String(sp["id"])] = true
		events.append({"type": "side_plot_done", "id": String(sp["id"]), "grade": String(sp["grade"]), "points": float(sp["points"]), "chars": who})
	if e.has("bonus"):
		var b: Dictionary = e["bonus"]
		var who := recipients(st, b.get("recipients", "present"), location)
		for c in who:
			st.add_ledger(c, "bonus", float(b["points"]), String(b["label"]))
			var attrs: Dictionary = b.get("attributes", {})
			for k: String in attrs:
				st.characters[c].attributes.add_trained(k, float(attrs[k]))
		events.append({"type": "bonus", "label": String(b["label"]), "points": float(b["points"]), "chars": who})
	if e.has("penalty"):
		var p: Dictionary = e["penalty"]
		var who := recipients(st, p.get("recipients", "present"), location)
		for c in who:
			st.add_ledger(c, "penalty", float(p["points"]), String(p["label"]))
		events.append({"type": "penalty", "label": String(p["label"]), "points": float(p["points"]), "chars": who})
	if e.has("tether_release") and not st.tether.is_empty():
		Watch.release_tether(st, events)
	if e.has("choice"):
		_choice(st, e["choice"], location, events)
	if e.has("persuade"):
		_persuade(st, e["persuade"], location, events)
	if e.has("give"):
		var g: Dictionary = e["give"]
		var who := recipients(st, g.get("recipients", "present"), location)
		for c in who:
			var ch: RefCounted = st.characters[c]
			if g.has("skill") and not ch.skills.has(String(g["skill"])):
				ch.skills.append(String(g["skill"]))
			if g.has("item"):
				ch.items[String(g["item"])] = float(ch.items.get(String(g["item"]), 0.0)) + float(g.get("count", 1))
		events.append({"type": "given", "chars": who, "skill": String(g.get("skill", "")), "item": String(g.get("item", ""))})
	if e.has("move_members"):
		var mv: Dictionary = e["move_members"]
		var sid: String = st.move_members(mv["members"], String(mv["to"]))
		if sid != "":
			events.append({"type": "members_moved", "squad": sid, "members": st.living_members(sid), "to": String(mv["to"])})
	if e.has("damage"):
		var dmg: Dictionary = e["damage"]
		for c in recipients(st, dmg.get("recipients", "present"), location):
			var ch: RefCounted = st.characters[c]
			ch.hp -= float(dmg["amount"])
			events.append({"type": "plot_damage", "char": c, "amount": float(dmg["amount"]), "hp": ch.hp})
			if ch.hp <= 0.0:
				Watch.kill(st, c, String(dmg.get("reason", "plot")), events)
	if e.has("set_tether"):
		st.tether = (e["set_tether"] as Dictionary).duplicate()
		st.tether_out.clear()
		events.append({"type": "tether_set", "npc": String(st.tether["npc"])})
		Watch.check_tether(st, 0, events)
	if e.has("clue"):
		events.append_array(st.intel.add_clue(String(e["clue"])))
	if e.has("erase"):
		var er: Dictionary = e["erase"]
		for c in recipients(st, er.get("targets", []), location):
			Watch.erase(st, c, String(er.get("reason", "plot")), events)
	if e.has("delay"):
		Watch.pass_time(st, int(e["delay"]["minutes"]), events)
	if e.has("relation"):
		var rel: Dictionary = e["relation"]
		var targets: Array = rel["targets"] if rel.has("targets") else [rel["target"]]
		for t: String in targets:
			if st.is_alive(t):
				events.append({"type": "relation_request", "kind": String(rel["kind"]), "actor": String(rel["actor"]), "target": t, "witnesses": recipients(st, rel.get("witnesses", "present"), location)})
	if e.has("end"):
		st.outcome = String(e["end"])
		events.append({"type": "expedition_end", "outcome": st.outcome})


## 选择：记下等玩家选（expedition.choose），选项的效果在选了之后才发生；选项里还可以再套一个选择（连续的激光）。
static func _choice(st: RefCounted, spec: Dictionary, location: String, events: Array[Dictionary]) -> void:
	st.pending_choice = {"id": String(spec["id"]), "prompt": String(spec["prompt"]), "options": (spec["options"] as Array).duplicate(true), "location": String(spec.get("location", location))}
	var shown: Array = []
	for o: Dictionary in spec["options"]:
		shown.append({"id": String(o["id"]), "text": String(o["text"])})
	events.append({"type": "choice_request", "id": String(spec["id"]), "prompt": String(spec["prompt"]), "options": shown})


## 说服：记下等对话层（AI 或离线兜底）给出说服力等级，再由 expedition.resolve_persuasion 检定。
static func _persuade(st: RefCounted, spec: Dictionary, location: String, events: Array[Dictionary]) -> void:
	st.pending_check = (spec as Dictionary).duplicate(true)
	st.pending_check["location"] = String(spec.get("location", location))
	events.append({"type": "persuade_request", "id": String(spec["id"]), "npc": String(spec["npc"]), "goal": String(spec["goal"]), "difficulty": int(spec["difficulty"]), "keywords": (spec.get("keywords", []) as Array).duplicate()})


## 战斗效果：有轮回者在那个地点就发起战斗（等界面打完再回报），没人在就躲过去了。
## location 写成 "@马修的 id" 表示在那个剧情人物所在的地方打。after_victory / after_defeat 是战斗结束后才发生的效果。
static func _battle(st: RefCounted, spec: Dictionary, events: Array[Dictionary]) -> void:
	var loc := String(spec["location"])
	if loc.begins_with("@"):
		loc = String(st.npcs[loc.substr(1)]["location"])
	var here: Array[String] = st.squads_at(loc)
	if here.is_empty():
		events.append({"type": "battle_avoided", "location": loc})
		return
	var dark := Watch.is_dark(st, loc)
	st.pending_battle = {
		"location": loc,
		"squad": here[0],
		"enemies": (spec["enemies"] as Array).duplicate(true),
		"dark": dark,
		"survive_until": float(spec.get("survive_until", -1.0)),
		"after_victory": (spec.get("after_victory", []) as Array).duplicate(true),
		"after_defeat": (spec.get("after_defeat", []) as Array).duplicate(true),
	}
	events.append({"type": "battle_request", "location": loc, "squad": here[0], "dark": dark})
