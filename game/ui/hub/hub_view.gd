extends RefCounted
## 主神空间界面的取数层：兑换、属性、修复、造人、训练、休息、队伍关系、规则百科。
## 规则在 core/hub；这里只把状态整理成界面能画的东西，并把点击交回去。

const Exchange = preload("res://core/hub/exchange.gd")
const Catalog = preload("res://core/hub/catalog.gd")
const BattleData = preload("res://core/battle/battle_data.gd")
const Talents = preload("res://core/model/talents.gd")
const Cohesion = preload("res://core/social/cohesion.gd")
const Companion = preload("res://core/hub/companion.gd")

## 兑换项效果一句话里用的中文名。
const ATTR_NAMES := {
	"intelligence": "智力", "spirit": "精神", "cell_vitality": "细胞", "nerve_reaction": "神经", "muscle": "肌肉", "immunity": "免疫",
}
const ENERGY_NAMES := {"neili": "内力", "blood": "血能", "mana": "魔力"}

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


## 兑换目录；category 为空时给全部。ok 表示现在能买，reasons 是买不了的原因，effect 是一句话效果。
## affordable_only：只列现在买得起的（目录有两百条，翻起来太长）。
func entries(char_id: String, category: String = "", affordable_only: bool = false) -> Array[Dictionary]:
	var ch: RefCounted = game.characters[char_id]
	var out: Array[Dictionary] = []
	for id: String in Catalog.entries():
		var e: Dictionary = Catalog.entry(id)
		if category != "" and String(e["category"]) != category:
			continue
		var check: Dictionary = Exchange.check(ch, id)
		if affordable_only and not bool(check["ok"]):
			continue
		var reasons: Array[String] = []
		for r: String in check["reasons"]:
			reasons.append(reason_text(r))
		out.append({
			"id": id, "name": String(e["name"]), "category": String(e["category"]),
			"series": String(e["series"]), "points": int(e["price"]["points"]),
			"tier": String(e["price"].get("tier", "")), "owned": ch.owned.has(id),
			"ok": bool(check["ok"]), "reasons": reasons,
			"warnings": (check["warnings"] as Array).duplicate(),
			"effect": effect_text(e),
		})
	return out


## 兑换项的效果，一句话：属性加多少、给什么技能、加多少能量、几件道具。只描述真能用上的积木。
static func effect_text(e: Dictionary) -> String:
	var parts: Array[String] = []
	for b: Dictionary in e["blocks"]:
		if b.has("attr"):
			for k: String in b["attr"]:
				parts.append("%s+%d" % [String(ATTR_NAMES.get(k, k)), int(b["attr"][k])])
		elif b.has("skill"):
			parts.append("技能：" + String(BattleData.skills().get(String(b["skill"]), {}).get("name", b["skill"])))
		elif b.has("energy"):
			parts.append("%s+%d" % [String(ENERGY_NAMES.get(String(b["energy"]), b["energy"])), int(b["amount"])])
		elif b.has("item"):
			parts.append("%s×%d" % [_item_name(String(b["item"])), int(b["count"])])
	return "，".join(parts)


## 道具的中文名：用得上它的技能叫什么，道具就叫什么（弹药、重生十字章单独说）。
static func _item_name(item: String) -> String:
	if item == "ammo":
		return "子弹"
	if item == "rebirth_cross":
		return "重生十字章"
	for s: String in BattleData.skills():
		if (BattleData.skills()[s].get("cost", {}) as Dictionary).has(item) and bool(BattleData.skills()[s].get("item", false)):
			return String(BattleData.skills()[s]["name"])
	return item


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


## 造物：原样字段，加上制造者的名字和她现在想要什么。
func companions() -> Array:
	var out: Array = []
	for c: Dictionary in game.companions:
		var d := c.duplicate(true)
		var creator := String(c["creator"])
		d["creator_name"] = game.characters[creator].display_name if game.characters.has(creator) else creator
		d["wish"] = Companion.wish(c)
		out.append(d)
	return out


## 造人：M1 固定郑吒造萝丽，素质取预设（不超过常人两倍），人设用 luo_li。
func create_human(creator_id: String, name: String) -> Array[Dictionary]:
	return hub.create_human(creator_id, name, LORI_ATTRS, "luo_li")


func visit_companion(companion_id: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = hub.visit_companion(companion_id)
	session.day = hub.day
	return events


func train_with_companion(companion_id: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = hub.train_with_companion(companion_id)
	session.day = hub.day
	return events


func companion_talked(companion_id: String) -> Array[Dictionary]:
	return hub.companion_talked(companion_id)


## 今天的晨会：{"event", "prompt", "options": [{"id", "text"}]}；没有返回空字典。
func morning() -> Dictionary:
	if hub == null or hub.morning.is_empty():
		return {}
	var options: Array = []
	for o: Dictionary in hub.morning["options"]:
		options.append({"id": String(o["id"]), "text": String(o["text"])})
	return {"event": String(hub.morning["id"]), "prompt": String(hub.morning["prompt"]), "options": options}


func answer_morning(option_id: String) -> Array[Dictionary]:
	return hub.answer_morning(option_id)


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


## 队伍：每个活着的队友怎么看拍板的人（信任、好感、敬畏、怨恨）、服从度、听不听指挥、冲突到了哪一级。
## 返回 {"leader": 名字, "cohesion": 全队凝聚力, "rows": [...]}；没有拍板的人时 rows 为空。
func team() -> Dictionary:
	var leader: String = game.leader
	var living: Array = []
	for id: String in game.characters:
		if game.characters[id].alive:
			living.append(id)
	var out := {"leader": "", "cohesion": Cohesion.cohesion(game.relations, living), "rows": []}
	if leader == "" or not game.characters.has(leader):
		return out
	out["leader"] = game.characters[leader].display_name
	for id: String in living:
		if id == leader:
			continue
		var rel: Dictionary = game.relations.get_rel(id, leader)
		var ob: float = Cohesion.obedience(game.relations, id, leader)
		(out["rows"] as Array).append({
			"id": id, "name": game.characters[id].display_name,
			"trust": float(rel["trust"]), "affection": float(rel["affection"]),
			"awe": float(rel["awe"]), "resentment": float(rel["resentment"]),
			"obedience": ob, "obeys": ob >= 40.0,
			"stage": Cohesion.conflict_stage(game.relations, id, leader),
		})
	return out


## 规则百科：已知条目（公开规则在前，智者发现的隐藏规则在后）和还没听说过的条数。
func codex() -> Dictionary:
	var entries: Array[Dictionary] = game.codex.entries()
	for e: Dictionary in entries:
		var src := String(e["source"])
		e["source_name"] = "主神" if src == "zhushen" else (game.characters[src].display_name if game.characters.has(src) else src)
	return {"entries": entries, "locked": game.codex.locked_count()}


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
		"no_companion": "没有这个造物", "no_morning": "今天没有晨会",
	}
	return String(table.get(code, code))
