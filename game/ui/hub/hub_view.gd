extends RefCounted
## 主神空间界面的取数层：兑换、属性、修复、造人、训练、休息。
## 规则在 core/hub；这里只把状态整理成界面能画的东西，并把点击交回去。

const Exchange = preload("res://core/hub/exchange.gd")
const Catalog = preload("res://core/hub/catalog.gd")
const BattleData = preload("res://core/battle/battle_data.gd")
const Talents = preload("res://core/model/talents.gd")

## 造人预设：萝丽（郑吒的青梅竹马），素质在常人的上限附近。
const LORI_ATTRS := {"intelligence": 110, "spirit": 120, "cell_vitality": 120, "nerve_reaction": 120, "muscle": 100, "immunity": 110}

var session: RefCounted
var hub: RefCounted
var game: RefCounted


func _init(s: RefCounted) -> void:
	session = s
	hub = s.hub
	game = s.game
	if hub != null:
		session.day = hub.day


func day_text() -> String:
	if hub == null:
		return ""
	return "回归当晚" if hub.day == 0 else "第 %d 天 / %d 天" % [hub.day, hub.days_total]


func days_left() -> int:
	return hub.days_left() if hub != null else 0


func can_depart() -> bool:
	return session.can_depart()


func characters() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in game.characters:
		var ch: RefCounted = game.characters[id]
		out.append({
			"id": id, "name": ch.display_name, "points": ch.points,
			"hp": ch.hp, "hp_max": ch.hp_max(), "fear": ch.fear,
			"tickets": ch.tickets.counts.duplicate(), "alive": ch.alive,
			"talents": Talents.awake_names(ch),
		})
	return out


## 兑换目录；category 为空时给全部。ok 表示现在能买，reasons 是买不了的原因。
func entries(char_id: String, category: String = "") -> Array[Dictionary]:
	var ch: RefCounted = game.characters[char_id]
	var out: Array[Dictionary] = []
	for id: String in Catalog.entries():
		var e: Dictionary = Catalog.entry(id)
		if category != "" and String(e["category"]) != category:
			continue
		var check: Dictionary = Exchange.check(ch, id)
		var reasons: Array[String] = []
		for r: String in check["reasons"]:
			reasons.append(reason_text(r))
		out.append({
			"id": id, "name": String(e["name"]), "category": String(e["category"]),
			"series": String(e["series"]), "points": int(e["price"]["points"]),
			"tier": String(e["price"].get("tier", "")), "owned": ch.owned.has(id),
			"ok": bool(check["ok"]), "reasons": reasons,
			"warnings": (check["warnings"] as Array).duplicate(),
		})
	return out


func buy(char_id: String, entry_id: String, accept_risk: bool = false) -> Array[Dictionary]:
	return hub.exchange(char_id, entry_id, {"accept_risk": accept_risk})


func buy_attribute(char_id: String, attr: String, amount: int) -> Array[Dictionary]:
	return hub.buy_attribute(char_id, attr, amount)


func split_ticket(char_id: String, grade: String) -> Array[Dictionary]:
	return hub.split_ticket(char_id, grade)


func repairs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in game.characters:
		var ch: RefCounted = game.characters[id]
		if not ch.alive or ch.hp >= ch.hp_max():
			continue
		out.append({"id": id, "name": ch.display_name, "hp": ch.hp, "hp_max": ch.hp_max(), "cost": hub.repair_cost(id)})
	return out


func repair(char_id: String) -> Array[Dictionary]:
	return hub.repair(char_id)


func companions() -> Array:
	return game.companions.duplicate(true)


## 造人：M1 固定郑吒造萝丽，素质取预设（不超过常人两倍）。
func create_human(creator_id: String, name: String) -> Array[Dictionary]:
	return hub.create_human(creator_id, name, LORI_ATTRS)


## 还有熟练度可练的技能/能力（低于 1.0 的）。
func trainable(char_id: String) -> Array[Dictionary]:
	var ch: RefCounted = game.characters[char_id]
	var out: Array[Dictionary] = []
	for s: String in ch.skills:
		if float(ch.proficiency.get(s, 1.0)) < 1.0:
			var info: Dictionary = BattleData.skills().get(s, {})
			out.append({"id": s, "name": String(info.get("name", s)), "proficiency": float(ch.proficiency.get(s, 0.0))})
	for a: String in ch.abilities:
		if float(ch.proficiency.get(a, 1.0)) < 1.0:
			out.append({"id": a, "name": a, "proficiency": float(ch.proficiency.get(a, 0.0))})
	return out


## 对练能用的招式：只列战斗技能（被动能力不上场）。
func sparrable(char_id: String) -> Array[Dictionary]:
	var ch: RefCounted = game.characters[char_id]
	var out: Array[Dictionary] = []
	for s: String in ch.skills:
		var info: Dictionary = BattleData.skills().get(s, {})
		out.append({"id": s, "name": String(info.get("name", s)), "proficiency": float(ch.proficiency.get(s, 1.0))})
	return out


func spar(char_id: String, skill_id: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = hub.spar(char_id, skill_id)
	session.day = hub.day
	return events


func train(char_id: String, skill_id: String, days: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = hub.train(char_id, skill_id, days)
	session.day = hub.day
	return events


func rest(days: int = 1) -> Array[Dictionary]:
	var events: Array[Dictionary] = hub.rest(days)
	session.day = hub.day
	return events


## 提示文字：把 core 的原因码翻成中文。
static func reason_text(code: String) -> String:
	if code.begins_with("missing_prerequisite:"):
		return "缺前置：" + code.get_slice(":", 1)
	if code.begins_with("gate:"):
		return "属性不够：" + code.get_slice(":", 1)
	if code.begins_with("needs_energy:"):
		return "需要能量：" + code.get_slice(":", 1)
	var table := {
		"not_enough_points": "点数不够", "missing_ticket": "支线不够",
		"already_owned": "已经拥有", "gift_used": "这次休整已经代兑过",
		"unknown_entry": "目录里没有这一项", "return_night": "回归当晚不兑换",
		"not_injured": "没有受伤", "cannot_split": "拆不了", "cannot_merge": "合不了",
		"no_days": "天数不够", "unknown_skill": "没有这个技能",
	}
	return String(table.get(code, code))
