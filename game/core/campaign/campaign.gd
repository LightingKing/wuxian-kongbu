extends RefCounted
## 章节装配（设计规格 9、10.1）：一份章节 JSON 把剧本、人物表和开局名单拼成一次远征。
## 章节 JSON：{"id", "name", "scenario", "roster", "members"}，两个路径都是 res:// 下的 JSON。
## 可选的 "agenda"：这部片开场时主神议程的状态——{"expected_wipe": 按团灭安排, "anomalies": [{"kind", "char", "note", "reason"}],
##   "decisions": [{"kind", "payload", "reason"}]}。开局时写进 GameState.agenda（同一异常不重复记）。
## 可选的 "leader"：拍板的人（队友服从谁）；"hub_tour_guide"：回归当晚带新人认识主神空间的老手（由 Session 用）。
## 人物表 JSON：{"version", "characters": {id: {"name", "attributes", "skills", "items", "films_completed", "flags"}}}。
## 这里只做装配和校验；远征本身的规则在 expedition/ 里。

const Character = preload("res://core/model/character.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const Expedition = preload("res://core/expedition/expedition.gd")
const Agenda = preload("res://core/director/agenda.gd")
const Attributes = preload("res://core/model/attributes.gd")
const DataLoader = preload("res://core/util/data_loader.gd")
const BattleData = preload("res://core/battle/battle_data.gd")

const REQUIRED: Array[String] = ["id", "name", "scenario", "roster", "members"]


## 读章节文件；读不到时返回空字典，错误由 validate_chapter 报告。
static func load_chapter(path: String) -> Dictionary:
	var res := DataLoader.load_json(path)
	if not res.ok:
		push_error(res.error)
		return {}
	return res.data


## 人物表 → 角色 id → Character。读不到时返回空字典。
static func build_roster(path: String) -> Dictionary:
	var res := DataLoader.load_json(path)
	if not res.ok:
		push_error(res.error)
		return {}
	var out := {}
	for id: String in res.data.get("characters", {}):
		var d: Dictionary = res.data["characters"][id]
		var ch := Character.new(id, String(d.get("name", id)), d.get("attributes", {}))
		ch.skills.assign(d.get("skills", []))
		ch.items = (d.get("items", {}) as Dictionary).duplicate()
		ch.points = int(d.get("points", 0))
		ch.films_completed = int(d.get("films_completed", 0))
		ch.flags = (d.get("flags", {}) as Dictionary).duplicate(true)
		ch.hp = ch.hp_max()
		out[id] = ch
	return out


## 检查章节能不能开局：路径存在、剧本合法、名单上的人都在、技能都有定义、属性齐全。
static func validate_chapter(ch: Dictionary) -> Array[String]:
	var errors: Array[String] = DataLoader.missing_keys(ch, REQUIRED, "章节")
	if not errors.is_empty():
		return errors
	var sc_res := DataLoader.load_json(String(ch["scenario"]))
	if not sc_res.ok:
		errors.append("剧本：%s" % sc_res.error)
	else:
		for e: String in Scenario.new(sc_res.data).validate():
			errors.append("剧本：%s" % e)
	var roster_res := DataLoader.load_json(String(ch["roster"]))
	if not roster_res.ok:
		errors.append("人物表：%s" % roster_res.error)
		return errors
	var roster: Dictionary = roster_res.data.get("characters", {})
	var members: Array = ch["members"]
	if members.is_empty():
		errors.append("章节没有开局名单")
	var seen := {}
	for id: String in members:
		if seen.has(id):
			errors.append("开局名单重复：%s" % id)
		seen[id] = true
		if not roster.has(id):
			errors.append("人物表里没有 %s" % id)
			continue
		var d: Dictionary = roster[id]
		for k in Attributes.KEYS:
			if not (d.get("attributes", {}) as Dictionary).has(k):
				errors.append("%s 缺少属性 %s" % [id, k])
		for s: String in d.get("skills", []):
			if not BattleData.skills().has(s):
				errors.append("%s 的技能 %s 不存在" % [id, s])
	return errors


## 把章节的议程块写进主神议程：异常（已经开着的不重复记）和开场决定，每条都带主神理由。
static func apply_agenda(game_state: RefCounted, ch: Dictionary, film: String) -> void:
	var ag: Dictionary = ch.get("agenda", {})
	var agenda: RefCounted = game_state.agenda
	for a: Dictionary in ag.get("anomalies", []):
		var who := String(a.get("char", ""))
		if agenda.open_anomaly(String(a["kind"]), who) == "":
			agenda.add_anomaly(String(a["kind"]), film, String(a.get("note", "")), String(a.get("reason", "")), who)
	for d: Dictionary in ag.get("decisions", []):
		agenda.record(film, String(d["kind"]), d.get("payload", {}), String(d.get("reason", "")))


## 开局：把名单上的人加进 GameState（已有同名角色则覆盖），按主神评价战力开一部片。
## 返回 Expedition；章节数据有误时返回 null（错误已经 push_error）。
static func start(game_state: RefCounted, path: String) -> RefCounted:
	var ch := load_chapter(path)
	var errors := validate_chapter(ch)
	if not errors.is_empty():
		push_error("章节数据有误：" + "；".join(errors))
		return null
	var roster := build_roster(String(ch["roster"]))
	var members: Array[String] = []
	for id: String in ch["members"]:
		members.append(String(id))
	for id: String in members:
		game_state.add_character(roster[id])
	game_state.leader = String(ch.get("leader", ""))
	var sc := Scenario.load_file(String(ch["scenario"]))
	apply_agenda(game_state, ch, sc.id)
	var ex := Expedition.new()
	ex.start(game_state, sc, members, {"rating_power": Agenda.rating_power(game_state, members)})
	return ex
