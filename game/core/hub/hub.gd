extends RefCounted
## 主神空间的一次休整（设计规格 6.2~6.4）。休整天数是行动点：兑换、结算、造人、修复不耗天；训练、休息耗天。
## 原著惯例：回归当晚（第 0 天）不兑换，只结算和造人；最后一天强制休息，不能训练；每天恐惧自然下降。
## 代兑：每人每次休整只能用自己的点数或支线给别人兑换一次（设计规格 6.3）。
## 天赋：兑换契合的强化、训练或对练会触发觉醒（talents.gd）；觉醒的"学得快"让训练熟练度翻倍。
## 造人：每个制造者的第一个造物让他的潜力突升；突升够大，主神悄悄把他复制进恶魔小队（议程里记着，玩家不知道）。
## 规则发现：每过一段天数，活着的人里够格的智者会推出隐藏规则（rule_discovery.gd），写进规则百科。
## 陪伴（companion.gd）：陪造物一天、一起训练都耗 1 天；说话每天算一次；亲密够高时制造者恐惧降得更快。
## 晨会（morning.gd）：每天早上从章节的事件表里挑一件；没人理会的话，第二天早上按默认选项了结。

const Exchange = preload("res://core/hub/exchange.gd")
const Pricing = preload("res://core/hub/pricing.gd")
const Rules = preload("res://core/util/rules.gd")
const Battle = preload("res://core/battle/battle.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
const Rng = preload("res://core/util/rng.gd")
const Catalog = preload("res://core/hub/catalog.gd")
const Talents = preload("res://core/model/talents.gd")
const Agenda = preload("res://core/director/agenda.gd")
const Companion = preload("res://core/hub/companion.gd")
const Morning = preload("res://core/hub/morning.gd")

## 对练用的傀儡血量，用来换算"打掉了多少"。
const DUMMY_HP := 240.0

var game: RefCounted
var days_total: int = 10
## 0 = 回归当晚；每过一天加 1，到 days_total 就该出发了。
var day: int = 0
## 这次休整里已经给别人付过钱的人。
var gifts: Dictionary = {}
var history: Array[Dictionary] = []
## 晨会事件表的路径（章节给；空表示没有晨会）、今天等回答的晨会、已经发生过的晨会 id。
var morning_path: String = ""
var morning: Dictionary = {}
var morning_seen: Array = []


func start(game_state: RefCounted, days: int = -1, morning_events: String = "") -> Array[Dictionary]:
	game = game_state
	days_total = days if days > 0 else int(Pricing.rules()["rest"]["days_default"])
	day = 0
	gifts = {}
	morning_path = morning_events
	morning = {}
	morning_seen = []
	return _emit([{"type": "hub_start", "days": days_total}])


func days_left() -> int:
	return days_total - day


func can_depart() -> bool:
	return day >= days_total


func _char(id: String) -> RefCounted:
	return game.characters[id]


func _emit(events: Array[Dictionary]) -> Array[Dictionary]:
	history.append_array(events)
	return events


func _refuse(reason: String) -> Array[Dictionary]:
	return _emit([{"type": "hub_refused", "reason": reason}])


## 兑换。opts：payer（付钱的人的 id）、accept_risk（坚持兑换有变异风险的血统）。
func exchange(char_id: String, entry_id: String, opts: Dictionary = {}) -> Array[Dictionary]:
	if day == 0:
		return _refuse("return_night")
	var payer_id := String(opts.get("payer", char_id))
	var gift := payer_id != char_id
	var events := Exchange.buy(_char(char_id), entry_id, game.rng, {
		"payer": _char(payer_id) if gift else null,
		"accept_risk": bool(opts.get("accept_risk", false)),
		"gift_used": gift and gifts.has(payer_id),
	})
	if events[0]["type"] == "exchange_done":
		if gift:
			gifts[payer_id] = true
		var e := Catalog.entry(entry_id)
		_talent(char_id, "bought_series:" + String(e["series"]), events)
		for b: Dictionary in e["blocks"]:
			for k: String in b.get("attr", {}):
				_talent(char_id, "bought_attr:" + k, events)
	return _emit(events)


## 直接强化属性：10 点 = 1 点（原著）。
func buy_attribute(char_id: String, attr: String, amount: int) -> Array[Dictionary]:
	if day == 0:
		return _refuse("return_night")
	var ch := _char(char_id)
	var cost := amount * int(Rules.get_rules()["points_per_attribute"])
	if amount <= 0 or ch.points < cost:
		return _refuse("not_enough_points")
	ch.points -= cost
	ch.attributes.add_enhanced(attr, float(amount))
	var events: Array[Dictionary] = [{"type": "attribute_bought", "char": char_id, "attr": attr, "amount": amount, "cost": cost}]
	_talent(char_id, "bought_attr:" + attr, events)
	return _emit(events)


## 支线拆分（1 个高一级 → 3 个低一级）与合成（3 个 → 1 个高一级）。
func split_ticket(char_id: String, grade: String) -> Array[Dictionary]:
	if not _char(char_id).tickets.split(grade):
		return _refuse("cannot_split")
	return _emit([{"type": "ticket_split", "char": char_id, "grade": grade}])


func merge_tickets(char_id: String, grade: String) -> Array[Dictionary]:
	if not _char(char_id).tickets.merge(grade):
		return _refuse("cannot_merge")
	return _emit([{"type": "tickets_merged", "char": char_id, "grade": grade}])


## 修复费用：生命还有一半以上算"修补"（400）；更重按伤势线性涨到"修复"上限（2000）。满血不要钱。
func repair_cost(char_id: String) -> int:
	var ch := _char(char_id)
	var ratio: float = ch.hp / ch.hp_max()
	if ratio >= 1.0:
		return 0
	var r: Dictionary = Pricing.rules()["repair"]
	var patch := float(r["patch_cost"])
	var threshold := float(r["patch_hp_ratio"])
	if ratio >= threshold:
		return int(patch)
	return roundi(patch + (threshold - maxf(ratio, 0.0)) / threshold * (float(r["full_cost"]) - patch))


## 修复：生命回满，基因锁后遗症消除。可以由别人付钱（修复不算代兑次数）。
func repair(char_id: String, payer_id: String = "") -> Array[Dictionary]:
	var ch := _char(char_id)
	var payer := _char(payer_id if payer_id != "" else char_id)
	var cost := repair_cost(char_id)
	if cost == 0:
		return _refuse("not_injured")
	if payer.points < cost:
		return _refuse("not_enough_points")
	payer.points -= cost
	ch.hp = ch.hp_max()
	ch.flags.erase("gene_lock_aftereffect")
	return _emit([{"type": "repaired", "char": char_id, "payer": payer.id, "cost": cost}])


## 造人（娱乐类）：每个制造者第一个免费，之后 500 点；各项素质最多约两倍常人（设计规格 6.3）。回归当晚就可以造。
## persona 是她在对话层的人设 id（萝丽是 luo_li；空字符串表示没有 AI 人设）。
func create_human(creator_id: String, name: String, attrs: Dictionary, persona: String = "") -> Array[Dictionary]:
	var ch := _char(creator_id)
	var h: Dictionary = Pricing.rules()["human"]
	var made := 0
	for c: Dictionary in game.companions:
		if c["creator"] == creator_id:
			made += 1
	var cost := 0 if made == 0 else int(h["cost"])
	if ch.points < cost:
		return _refuse("not_enough_points")
	ch.points -= cost
	var clamped := {}
	for k: String in attrs:
		clamped[k] = minf(float(attrs[k]), float(h["attr_max"]))
	var companion := {"id": "%s_human_%d" % [creator_id, made + 1], "name": name, "creator": creator_id, "attributes": clamped}
	Companion.init_fields(companion, persona, day)
	game.companions.append(companion)
	game.flags["seen_human_creation"] = true
	if made == 0:
		var film := _film()
		if game.agenda.potential_spike(creator_id, float(Agenda.rules()["human_creation_spike"]), film, "造人：%s 按自己的记忆造出了 %s" % [ch.display_name, name]):
			game.agenda.copy_to_demon_team(creator_id, film, "潜力突升够大：复制一份放进恶魔小队，做对照实验（M7 才揭晓）。")
	return _emit([{"type": "human_created", "creator": creator_id, "companion": companion, "cost": cost}])


## 训练：花天数提升已有技能或能力的熟练度。最后一天强制休息，不能占用。
func train(char_id: String, skill_id: String, days: int) -> Array[Dictionary]:
	var ch := _char(char_id)
	if not ch.skills.has(skill_id) and not ch.abilities.has(skill_id):
		return _refuse("unknown_skill")
	if days <= 0 or day + days > days_total - 1:
		return _refuse("no_days")
	var gain := float(Pricing.rules()["train"]["proficiency_per_day"]) * days * Talents.train_mult(ch)
	ch.proficiency[skill_id] = minf(1.0, float(ch.proficiency.get(skill_id, 1.0)) + gain)
	var events: Array[Dictionary] = [{"type": "trained", "char": char_id, "skill": skill_id, "days": days, "proficiency": ch.proficiency[skill_id]}]
	_talent(char_id, "trained", events)
	_pass_days(days, events)
	return _emit(events)


## 训练场对练：拿指定技能跟训练傀儡打一场，耗 1 天。
## 目的是让玩家看见兑换前后的伤害差别；单位是副本，不写回，角色不会受伤、不会耗道具。
func spar(char_id: String, skill_id: String) -> Array[Dictionary]:
	var ch := _char(char_id)
	if ch == null or not ch.alive:
		return _refuse("bad_char")
	if not ch.skills.has(skill_id):
		return _refuse("unknown_skill")
	if day + 1 > days_total - 1:
		return _refuse("no_days")
	var units: Array[RefCounted] = []
	units.append(UnitFactory.from_character(ch, "ally", 0, [skill_id], "player", ch.battle_resources()))
	units.append(UnitFactory.from_enemy("training_dummy", "dummy_1", 0))
	var b := Battle.new()
	b.setup(units, {"allow_retreat": false}, Rng.new(day * 37 + 11))
	var rounds := 0
	while b.outcome == "ongoing" and rounds < 40:
		var acts: Array[Dictionary] = b.legal_actions()
		if acts.is_empty():
			break
		var picked: Dictionary = acts[0]
		for a: Dictionary in acts:
			if String(a.get("type", "")) == "skill":
				picked = a
				break
		b.act(picked)
		rounds += 1
	var dummy: RefCounted = b.field.get_unit("dummy_1")
	var left := maxf(float(dummy.hp), 0.0) if dummy != null else 0.0
	var dealt := clampf(DUMMY_HP - left, 0.0, DUMMY_HP)
	var gain := float(Pricing.rules()["train"]["proficiency_per_day"]) * 0.5 * Talents.train_mult(ch)
	ch.proficiency[skill_id] = minf(1.0, float(ch.proficiency.get(skill_id, 1.0)) + gain)
	var events: Array[Dictionary] = [{
		"type": "spar_done", "char": char_id, "skill": skill_id,
		"damage": dealt, "rounds": rounds, "outcome": b.outcome,
		"proficiency": ch.proficiency[skill_id],
	}]
	_talent(char_id, "trained", events)
	_pass_days(1, events)
	return _emit(events)


## 陪造物待一天（耗 1 天，最后一天不行）。
func visit_companion(companion_id: String) -> Array[Dictionary]:
	return _companion_day(companion_id, "visit")


## 和造物一起训练（耗 1 天，最后一天不行）。
func train_with_companion(companion_id: String) -> Array[Dictionary]:
	return _companion_day(companion_id, "train")


func _companion_day(companion_id: String, kind: String) -> Array[Dictionary]:
	var c := Companion.find(game, companion_id)
	if c.is_empty():
		return _refuse("no_companion")
	var creator: RefCounted = game.characters.get(String(c["creator"]), null)
	if creator == null or not creator.alive:
		return _refuse("no_companion")
	if day + 1 > days_total - 1:
		return _refuse("no_days")
	var events: Array[Dictionary] = Companion.visit(c, creator, day + 1) if kind == "visit" else Companion.train_together(c, creator, day + 1)
	_pass_days(1, events)
	return _emit(events)


## 和造物说了一次话（对话层回过一句之后调）。每天只算一次，不耗天。
func companion_talked(companion_id: String) -> Array[Dictionary]:
	var c := Companion.find(game, companion_id)
	if c.is_empty():
		return []
	return _emit(Companion.talked(c, day))


## 回答今天的晨会。
func answer_morning(option_id: String) -> Array[Dictionary]:
	if morning.is_empty():
		return _refuse("no_morning")
	var events: Array[Dictionary] = Morning.apply(game, morning, option_id)
	if String(events[0]["type"]) == "morning_answered":
		morning = {}
	return _emit(events)


func rest(days: int) -> Array[Dictionary]:
	if days <= 0 or day + days > days_total:
		return _refuse("no_days")
	var events: Array[Dictionary] = []
	_pass_days(days, events)
	return _emit(events)


func _pass_days(days: int, events: Array[Dictionary]) -> void:
	var relief := float(Pricing.rules()["rest"]["fear_relief_per_day"])
	for i in days:
		day += 1
		for ch: RefCounted in game.characters.values():
			if ch.alive:
				ch.fear = maxf(0.0, ch.fear - relief)
		events.append({"type": "day_passed", "day": day, "days_left": days_left()})
		for c: Dictionary in game.companions:
			Companion.day_passed(c, game.characters.get(String(c["creator"]), null), day)
		_next_morning(events)
	events.append_array(game.codex.discovery.discover_all(game.living_characters(), game))


## 新的一天早上：昨天没回答的晨会按默认选项了结，再挑今天的（出发那天没有晨会）。
func _next_morning(events: Array[Dictionary]) -> void:
	if not morning.is_empty():
		events.append_array(Morning.apply(game, morning, String(morning.get("default", morning["options"][0]["id"])), true))
		morning = {}
	if day >= days_total or morning_path == "":
		return
	var ev := Morning.pick(game, Morning.load_events(morning_path), day, morning_seen)
	if ev.is_empty():
		return
	morning = ev
	morning_seen.append(String(ev["id"]))
	var shown: Array = []
	for o: Dictionary in ev["options"]:
		shown.append({"id": String(o["id"]), "text": String(o["text"])})
	events.append({"type": "morning_event", "event": String(ev["id"]), "prompt": String(ev["prompt"]), "options": shown})


## 天赋触发：觉醒的事件追加进 events，同时记进主神议程。
func _talent(char_id: String, trigger_id: String, events: Array[Dictionary]) -> void:
	for t in Talents.trigger(_char(char_id), trigger_id, events):
		Talents.record(game.agenda, char_id, t, _film())


## 这次休整接在哪部片后面（议程记录用）。
func _film() -> String:
	return String(game.films_record.back()) if not game.films_record.is_empty() else ""


func to_dict() -> Dictionary:
	return {
		"days_total": days_total, "day": day, "gifts": gifts.duplicate(),
		"morning_path": morning_path, "morning": morning.duplicate(true), "morning_seen": morning_seen.duplicate(),
	}


func load_dict(d: Dictionary, game_state: RefCounted) -> void:
	game = game_state
	days_total = int(d["days_total"])
	day = int(d["day"])
	gifts = (d["gifts"] as Dictionary).duplicate()
	morning_path = String(d.get("morning_path", ""))
	morning = (d.get("morning", {}) as Dictionary).duplicate(true)
	morning_seen = (d.get("morning_seen", []) as Array).duplicate()
