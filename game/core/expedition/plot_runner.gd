extends RefCounted
## 剧情事件（设计规格 5.2）：定时事件（at，到点发生）和条件事件（when，条件一成立就发生），每个只发生一次。
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
	while changed and st.outcome == "ongoing" and st.pending_battle.is_empty():
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
	if e.has("end"):
		st.outcome = String(e["end"])
		events.append({"type": "expedition_end", "outcome": st.outcome})


## 战斗效果：有轮回者在那个地点就发起战斗（等界面打完再回报），没人在就躲过去了。
static func _battle(st: RefCounted, spec: Dictionary, events: Array[Dictionary]) -> void:
	var loc := String(spec["location"])
	var here: Array[String] = st.squads_at(loc)
	if here.is_empty():
		events.append({"type": "battle_avoided", "location": loc})
		return
	var dark := bool(st.scenario.location(loc).get("dark", false)) or bool(st.flags.get("lights_out", false))
	st.pending_battle = {
		"location": loc,
		"squad": here[0],
		"enemies": (spec["enemies"] as Array).duplicate(true),
		"dark": dark,
	}
	events.append({"type": "battle_request", "location": loc, "squad": here[0], "dark": dark})
