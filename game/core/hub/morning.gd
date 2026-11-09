extends RefCounted
## 晨会（设计规格 6.1 广场、9.6 第 2~8 天的晨会事件：结盟、新人去留）。
## 每天早上最多一件，每件只发生一次。事件表来自章节（M1 是 data/hub/m1_morning.json）：
##   {"id", "day_min", "when": {条件}, "prompt", "default": 没人理会时按哪个选项, "options": [{"id", "text", "effects": [...]}]}
## 条件（都满足才发生）：alive（都活着）、dead（都死了）、any_alive（其中有人活着，第一个活着的记作 {who}）、
##   companion_of（这个人有造物）、points_min（{角色: 至少多少点}）、flag（GameState.flags 里为真）。
## 效果：rel_change {"from": [..] 或 "all", "to", "deltas"}、relation {"kind", "actor", "target"}、fear {"chars": [..] 或 "all", "amount"}、
##   points {"from", "to", "amount"}、codex [条目 id]、companion {"creator", 各项增减}、say {"speaker", "text"}。
## 文本和效果里的 {who} 换成角色 id、{who_name} 换成名字。

const DataLoader = preload("res://core/util/data_loader.gd")
const Companion = preload("res://core/hub/companion.gd")


static func load_events(path: String) -> Array:
	if path == "":
		return []
	var res := DataLoader.load_json(path)
	assert(res.ok, res.error)
	return res.data["events"]


## 今天该发生哪件晨会（已经发生过的不再发生）。返回替换过占位符的事件，没有返回空字典。
static func pick(game: RefCounted, events: Array, day: int, seen: Array) -> Dictionary:
	for ev: Dictionary in events:
		if seen.has(String(ev["id"])) or day < int(ev.get("day_min", 1)):
			continue
		var who := _check(game, ev.get("when", {}))
		if who == "?":
			continue
		return _fill(ev, who, game)
	return {}


## 条件不满足返回 "?"；满足时返回 {who}（没有 any_alive 时是空字符串）。
static func _check(game: RefCounted, when: Dictionary) -> String:
	for id: String in when.get("alive", []):
		if not _alive(game, id):
			return "?"
	for id: String in when.get("dead", []):
		if _alive(game, id):
			return "?"
	var who := ""
	if when.has("any_alive"):
		who = "?"
		for id: String in when["any_alive"]:
			if _alive(game, id):
				who = id
				break
		if who == "?":
			return "?"
	if when.has("companion_of"):
		var found := false
		for c: Dictionary in game.companions:
			if String(c["creator"]) == String(when["companion_of"]):
				found = true
		if not found:
			return "?"
	var pm: Dictionary = when.get("points_min", {})
	for id: String in pm:
		if not _alive(game, id) or int(game.characters[id].points) < int(pm[id]):
			return "?"
	if when.has("flag") and not bool(game.flags.get(String(when["flag"]), false)):
		return "?"
	return who


static func _alive(game: RefCounted, id: String) -> bool:
	return game.characters.has(id) and game.characters[id].alive


static func _fill(ev: Dictionary, who: String, game: RefCounted) -> Dictionary:
	var text := JSON.stringify(ev)
	if who != "":
		text = text.replace("{who_name}", String(game.characters[who].display_name)).replace("{who}", who)
	var parsed: Variant = JSON.parse_string(text)
	var out: Dictionary = parsed
	out["who"] = who
	return out


## 回答晨会：按选项落效果。返回事件（第一条是 morning_answered）。
static func apply(game: RefCounted, ev: Dictionary, option_id: String, auto: bool = false) -> Array[Dictionary]:
	var picked: Dictionary = {}
	for o: Dictionary in ev["options"]:
		if String(o["id"]) == option_id:
			picked = o
	if picked.is_empty():
		return [{"type": "morning_refused", "reason": "bad_option"}]
	var events: Array[Dictionary] = [{"type": "morning_answered", "event": String(ev["id"]), "option": option_id, "text": String(picked["text"]), "auto": auto}]
	for e: Dictionary in picked.get("effects", []):
		_effect(game, e, events)
	return events


static func _effect(game: RefCounted, e: Dictionary, events: Array[Dictionary]) -> void:
	if e.has("say"):
		events.append({"type": "dialogue", "speaker": String(e["say"]["speaker"]), "text": String(e["say"]["text"])})
	if e.has("rel_change"):
		var rc: Dictionary = e["rel_change"]
		var to := String(rc["to"])
		for who: String in _chars(game, rc["from"]):
			if who != to:
				game.relations.change(who, to, rc["deltas"])
		events.append({"type": "relations_changed", "to": to, "deltas": (rc["deltas"] as Dictionary).duplicate()})
	if e.has("relation"):
		var r: Dictionary = e["relation"]
		events.append(game.relations.apply_event(String(r["kind"]), String(r["actor"]), String(r["target"]), _chars(game, "all")))
	if e.has("fear"):
		for who: String in _chars(game, e["fear"]["chars"]):
			var ch: RefCounted = game.characters[who]
			ch.fear = clampf(ch.fear + float(e["fear"]["amount"]), 0.0, 100.0)
			events.append({"type": "fear_changed", "char": who, "amount": float(e["fear"]["amount"]), "fear": ch.fear, "reason": "morning"})
	if e.has("points"):
		var p: Dictionary = e["points"]
		var giver: RefCounted = game.characters[String(p["from"])]
		var amount := mini(int(p["amount"]), int(giver.points))
		giver.points -= amount
		game.characters[String(p["to"])].points += amount
		events.append({"type": "points_given", "from": String(p["from"]), "to": String(p["to"]), "amount": amount})
	if e.has("codex"):
		events.append_array(game.codex.unlock(e["codex"], "morning"))
	if e.has("companion"):
		var cs: Dictionary = (e["companion"] as Dictionary).duplicate()
		var creator := String(cs["creator"])
		cs.erase("creator")
		for c: Dictionary in game.companions:
			if String(c["creator"]) == creator:
				for k: String in cs:
					c[k] = clampf(float(c.get(k, 50.0)) + float(cs[k]), 0.0, 100.0)
				events.append({"type": "companion_changed", "companion": String(c["id"]), "name": String(c["name"]), "deltas": cs.duplicate()})


## "all" = 所有活着的轮回者；数组 = 其中活着的。
static func _chars(game: RefCounted, spec: Variant) -> Array[String]:
	var out: Array[String] = []
	if spec is Array:
		for id: String in spec:
			if _alive(game, id):
				out.append(id)
	else:
		for id: String in game.characters:
			if game.characters[id].alive:
				out.append(id)
	return out
