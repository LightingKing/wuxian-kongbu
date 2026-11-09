extends RefCounted
## 一场战斗（设计规格第 4 节）。输入是单位和玩家的行动，输出是一串事件，界面只按事件播放表现。
## 用法：
##   var b := Battle.new()
##   var events := b.setup(units, {"dark": false}, Rng.new(seed))   # AI 单位会自动行动，直到轮到玩家或战斗结束
##   while b.outcome == "ongoing":
##       events = b.act(玩家从 b.legal_actions() 里选的一项)
## outcome：ongoing（进行中）、victory、defeat、retreat（撤退）、survived（撑到时限）、timeout（行动次数超上限）。

const BattleData = preload("res://core/battle/battle_data.gd")
const Battlefield = preload("res://core/battle/battlefield.gd")
const Ctb = preload("res://core/battle/ctb.gd")
const Statuses = preload("res://core/battle/statuses.gd")
const CombatMath = preload("res://core/battle/combat_math.gd")
const Fear = preload("res://core/battle/fear.gd")
const Targeting = preload("res://core/battle/targeting.gd")
const UtilityAi = preload("res://core/battle/utility_ai.gd")

var field: RefCounted
var ctb: RefCounted
var rng: RefCounted
var dark: bool = false
var allow_retreat: bool = false
## 坚持到这个时刻（CTB 时间）就算撑过去；小于 0 表示不限时。
var survive_until: float = -1.0
## 队伍里智者的判断力（0~2）：0 只看得出对方要行动，1 看得出技能，2 看得出目标。
var intel: int = 0
var outcome: String = "ongoing"
## 正在等待玩家下令的单位；不在玩家回合时为 null。
var current: RefCounted = null
var action_count: int = 0
var max_actions: int = 2000
## 全部事件，按发生顺序。
var history: Array[Dictionary] = []


## options：row_capacity（每排容量）、dark（黑暗）、allow_retreat（允许撤退）、survive_until（坚持到的时刻）。
func setup(units: Array[RefCounted], options: Dictionary, random: RefCounted) -> Array[Dictionary]:
	rng = random
	field = Battlefield.new(int(options.get("row_capacity", -1)))
	ctb = Ctb.new()
	dark = bool(options.get("dark", false))
	allow_retreat = bool(options.get("allow_retreat", false))
	survive_until = float(options.get("survive_until", -1.0))
	intel = int(options.get("intel", 0))
	max_actions = int(BattleData.rules()["max_actions"])
	var events: Array[Dictionary] = []
	var placed: Array[String] = []
	for u in units:
		if field.add(u):
			ctb.init_unit(u)
			placed.append(u.id)
		else:
			events.append({"type": "placement_failed", "target": u.id})
	events.append({"type": "battle_start", "units": placed})
	var aura := 0.0
	for e: RefCounted in field.side_units("enemy"):
		aura += e.fear_aura
	if aura > 0.0:
		for a: RefCounted in field.side_units("ally"):
			_add_fear(a, aura, "enemy_appear", events)
	for u in field.units:
		if u.controller == "ai":
			_plan(u)
	_advance(events)
	return _emit(events)


## 玩家下令。不合法的行动会被拒绝，战斗状态不变。
func act(action: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if outcome != "ongoing" or current == null or not Targeting.is_legal(field, current, action, allow_retreat):
		events.append({"type": "invalid_action", "action": action})
		return events
	_perform(current, action, events)
	_advance(events)
	return _emit(events)


func legal_actions() -> Array[Dictionary]:
	if outcome != "ongoing" or current == null:
		return []
	return Targeting.legal_actions(field, current, allow_retreat)


## 界面上方的时间轴：接下来 count 次行动的单位 id。
func timeline(count: int = 10) -> Array[String]:
	return ctb.preview(field.units, count)


func intent_view(unit_id: String, intel: int) -> Dictionary:
	return UtilityAi.intent_view(field.get_unit(unit_id), intel)


func _emit(events: Array[Dictionary]) -> Array[Dictionary]:
	history.append_array(events)
	return events


## 推进时间轴，让 AI 和失控的单位行动，直到轮到玩家或战斗结束。
func _advance(events: Array[Dictionary]) -> void:
	while true:
		if _check_end(events):
			return
		if action_count >= max_actions:
			_finish("timeout", events)
			return
		var u: RefCounted = ctb.next_actor(field.units)
		if survive_until >= 0.0 and u.next_time >= survive_until:
			_finish("survived", events)
			return
		events.append({"type": "turn_start", "unit": u.id, "time": u.next_time})
		events.append_array(Statuses.start_of_turn(u))
		_after_hp_loss(u, events)
		if not u.in_play():
			continue
		if dark and u.side == "ally":
			_add_fear(u, float(BattleData.rules()["fear"]["darkness_per_turn"]), "darkness", events)
		if Statuses.has_flag(u, "skip_turn"):
			events.append({"type": "turn_skipped", "unit": u.id})
			_end_turn(u, 1.0, "")
			continue
		if Statuses.has_flag(u, "panic"):
			_panic_action(u, events)
			continue
		if u.controller == "player":
			current = u
			return
		var action: Dictionary = u.intent
		if action.is_empty() or not Targeting.is_legal(field, u, action, false):
			action = UtilityAi.choose(field, u, false, dark)
		_perform(u, action, events)


func _perform(u: RefCounted, action: Dictionary, events: Array[Dictionary]) -> void:
	current = null
	events.append({"type": "action", "unit": u.id, "action": action})
	var delays: Dictionary = BattleData.rules()["delay_mult"]
	var mult := 1.0
	var used := ""
	match String(action["type"]):
		"skill":
			used = String(action["skill"])
			mult = _use_skill(u, action, events)
		"move":
			field.move(u, int(action["row"]))
			events.append({"type": "moved", "unit": u.id, "row": u.row})
			mult = float(delays["move"])
		"defend":
			events.append(Statuses.apply(u, "defending"))
			mult = float(delays["defend"])
		"gene_lock":
			u.aftereffect = true
			events.append(Statuses.apply(u, "gene_lock"))
			mult = float(delays["gene_lock"])
		"retreat":
			_finish("retreat", events)
	_end_turn(u, mult, used)


## 行动结束：排下一次行动；冷却减 1（本回合刚用的技能不减）；AI 单位定好下一步意图。
func _end_turn(u: RefCounted, mult: float, used_skill: String) -> void:
	ctb.advance(u, mult)
	action_count += 1
	for k: String in u.cooldowns.keys():
		if k != used_skill:
			u.cooldowns[k] = maxi(0, int(u.cooldowns[k]) - 1)
	if u.controller == "ai" and u.in_play() and outcome == "ongoing":
		_plan(u)


func _plan(u: RefCounted) -> void:
	u.intent = UtilityAi.choose(field, u, false, dark)


func _use_skill(u: RefCounted, action: Dictionary, events: Array[Dictionary]) -> float:
	var skill_id := String(action["skill"])
	var skill := BattleData.skill(skill_id)
	var cost: Dictionary = skill.get("cost", {})
	for k: String in cost:
		u.resources[k] = float(u.resources.get(k, 0.0)) - float(cost[k])
	if skill.has("cooldown"):
		u.cooldowns[skill_id] = int(skill["cooldown"])
	for tid: String in action["targets"]:
		var t: RefCounted = field.get_unit(tid)
		if t != null and t.in_play():
			_apply_skill(u, t, skill_id, events)
	return float(skill.get("delay_mult", 1.0))


## 一个技能作用到一个目标：命中 → 伤害 → 治疗 → 净化 → 恐惧 → 附加状态。
func _apply_skill(u: RefCounted, t: RefCounted, skill_id: String, events: Array[Dictionary]) -> void:
	var skill := BattleData.skill(skill_id)
	if skill.has("accuracy") and rng.randf() >= CombatMath.hit_chance(u, t, skill, dark):
		events.append({"type": "miss", "source": u.id, "target": t.id, "skill": skill_id})
		return
	if float(skill.get("power", 0.0)) > 0.0:
		_deal_damage(u, t, CombatMath.damage(u, t, skill, rng.randf()), events)
		if not t.in_play():
			return
	if skill.has("heal"):
		var before: float = t.hp
		t.hp = minf(t.hp + float(skill["heal"]), t.hp_max)
		events.append({"type": "heal", "source": u.id, "target": t.id, "amount": t.hp - before, "hp": t.hp})
	for c: String in skill.get("cleanse", []):
		if Statuses.remove(t, c):
			events.append({"type": "status_removed", "target": t.id, "status": c})
	if skill.has("fear"):
		_add_fear(t, float(skill["fear"]), "skill", events)
	for a: Dictionary in skill.get("applies", []):
		if rng.randf() < float(a["chance"]):
			events.append(Statuses.apply(t, String(a["status"])))


func _deal_damage(src: RefCounted, t: RefCounted, amount: float, events: Array[Dictionary]) -> void:
	t.hp -= amount
	events.append({"type": "damage", "source": src.id, "target": t.id, "amount": amount, "hp": t.hp})
	if t.hp > 0.0 and amount >= float(BattleData.rules()["fear"]["heavy_wound_ratio"]) * t.hp_max and not Statuses.has_flag(t, "no_pain"):
		_add_fear(t, float(BattleData.rules()["fear"]["heavy_wound"]), "heavy_wound", events)
	_after_hp_loss(t, events)


## 掉血之后：死了就处理死亡（含复活道具），没死就看要不要做低血觉醒检定。
func _after_hp_loss(t: RefCounted, events: Array[Dictionary]) -> void:
	if t.fled:
		return
	if t.turned or t.hp <= 0.0:
		if t.alive or t.turned:
			_on_death(t, events)
		return
	if t.reincarnator and not t.low_hp_checked and t.hp_ratio() < float(BattleData.rules()["gene_lock"]["low_hp_ratio"]):
		events.append_array(Fear.check_low_hp(t, rng.randf()))


func _on_death(t: RefCounted, events: Array[Dictionary]) -> void:
	if t.revive_charges > 0 and not t.turned:
		t.revive_charges -= 1
		t.resources["rebirth_cross"] = t.revive_charges
		t.hp = roundf(t.hp_max * float(BattleData.rules()["revive_hp_ratio"]))
		events.append({"type": "revived", "target": t.id, "hp": t.hp})
		return
	t.alive = false
	events.append({"type": "death", "target": t.id, "turned": t.turned})
	for ally: RefCounted in field.side_units(t.side):
		_add_fear(ally, float(BattleData.rules()["fear"]["ally_death"]), "ally_death", events)


func _add_fear(u: RefCounted, amount: float, reason: String, events: Array[Dictionary]) -> void:
	var delta := Fear.gain(u, amount)
	if delta != 0.0:
		events.append({"type": "fear_changed", "target": u.id, "amount": delta, "fear": u.fear, "reason": reason})
	if u.fear >= Fear.max_fear() and not u.fear_checked:
		events.append_array(Fear.check_full_fear(u, rng.randf()))


## 恐慌（设计规格 3.5）：不听指挥，发呆、往后逃（已在后排就逃离战场），或者对随便一个人出手（可能误伤队友）。
func _panic_action(u: RefCounted, events: Array[Dictionary]) -> void:
	var p: Dictionary = BattleData.rules()["panic"]
	var r: float = rng.randf()
	if r < float(p["freeze"]):
		events.append({"type": "panic_freeze", "unit": u.id})
	elif r < float(p["freeze"]) + float(p["flee"]):
		if field.move(u, u.row + 1):
			events.append({"type": "panic_flee", "unit": u.id, "row": u.row})
		else:
			u.fled = true
			events.append({"type": "fled", "unit": u.id})
	else:
		var others: Array[RefCounted] = []
		for o in field.units:
			if o != u and o.in_play():
				others.append(o)
		var skill_id := "punch"
		for s in u.skills:
			if float(BattleData.skill(s).get("power", 0.0)) > 0.0:
				skill_id = s
				break
		if not others.is_empty():
			var t: RefCounted = others[rng.randi_range(0, others.size() - 1)]
			events.append({"type": "panic_misfire", "unit": u.id, "target": t.id, "skill": skill_id})
			_apply_skill(u, t, skill_id, events)
	_end_turn(u, float(BattleData.rules()["delay_mult"]["panic"]), "")


func _check_end(events: Array[Dictionary]) -> bool:
	if outcome != "ongoing":
		return true
	if field.side_units("enemy").is_empty():
		_finish("victory", events)
		return true
	if field.side_units("ally").is_empty():
		_finish("defeat", events)
		return true
	return false


func _finish(result: String, events: Array[Dictionary]) -> void:
	if outcome != "ongoing":
		return
	outcome = result
	current = null
	events.append({"type": "battle_end", "outcome": result})
