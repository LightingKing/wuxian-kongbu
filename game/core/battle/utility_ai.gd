extends RefCounted
## 确定性效用 AI（设计规格 4.6、8）：给每个合法行动打分，取最高分；同分取先出现的，所以同一局面总是同一个选择。
## 敌人在轮到自己之前就定好下一步（intent），玩家能看到多少取决于情报等级（设计规格 3.8）。

const BattleData = preload("res://core/battle/battle_data.gd")
const CombatMath = preload("res://core/battle/combat_math.gd")
const Statuses = preload("res://core/battle/statuses.gd")
const Targeting = preload("res://core/battle/targeting.gd")


## 攻击偏好：nearest 打前排，weakest 打残血比例高的，wounded 专咬已经受伤的（丧尸），threat 打攻击力高的。
static func profile_bonus(profile: String, t: RefCounted) -> float:
	match profile:
		"nearest":
			return float(2 - t.row) * 8.0
		"weakest":
			return (1.0 - t.hp_ratio()) * 20.0
		"wounded":
			return 25.0 if t.hp < t.hp_max else 0.0
		"threat":
			return t.attack_mult() * 10.0
	return 0.0


static func score(field: RefCounted, u: RefCounted, action: Dictionary, dark: bool) -> float:
	match String(action["type"]):
		"skill":
			return _score_skill(field, u, action, dark)
		"move":
			return 1.0 if int(action["row"]) < u.row else 0.0
		"defend":
			return 0.5
		"gene_lock":
			return 25.0 if u.hp_ratio() < 0.5 or u.fear >= 70.0 else 0.0
	return -1.0


static func _score_skill(field: RefCounted, u: RefCounted, action: Dictionary, dark: bool) -> float:
	var skill := BattleData.skill(String(action["skill"]))
	var total := 0.0
	for tid: String in action["targets"]:
		var t: RefCounted = field.get_unit(tid)
		if float(skill.get("power", 0.0)) > 0.0:
			var dmg := CombatMath.damage(u, t, skill, 0.5)
			var expected := CombatMath.hit_chance(u, t, skill, dark) * dmg
			total += minf(expected, t.hp) / t.hp_max * 100.0
			if dmg >= t.hp:
				total += 30.0
			total += profile_bonus(u.ai_profile, t)
		if skill.has("heal") and t.hp_ratio() < 0.5:
			total += minf(float(skill["heal"]), t.hp_max - t.hp) / t.hp_max * 100.0 + 40.0
		for c: String in skill.get("cleanse", []):
			if Statuses.has(t, c):
				total += 60.0
		if float(skill.get("fear", 0.0)) < 0.0:
			total += maxf(0.0, t.fear - 30.0) * 0.5
	var cost: Dictionary = skill.get("cost", {})
	for k: String in cost:
		total -= float(cost[k]) * 0.5
	return total


## 返回得分最高的合法行动。
static func choose(field: RefCounted, u: RefCounted, allow_retreat: bool, dark: bool) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -INF
	for a in Targeting.legal_actions(field, u, allow_retreat):
		var s := score(field, u, a, dark)
		if s > best_score:
			best = a
			best_score = s
	return best


## 把意图按情报等级翻译给界面：0 只知道大类（攻击 / 支援 / 调整），1 知道用什么技能，2 还知道打谁。
static func intent_view(u: RefCounted, intel: int) -> Dictionary:
	var a: Dictionary = u.intent
	if a.is_empty():
		return {"known": false}
	var view := {"known": true, "kind": "maneuver"}
	if a["type"] == "skill":
		var skill := BattleData.skill(String(a["skill"]))
		view["kind"] = "attack" if skill["target_side"] == "enemy" else "support"
		if intel >= 1:
			view["skill"] = a["skill"]
			view["skill_name"] = skill["name"]
		if intel >= 2:
			view["targets"] = (a["targets"] as Array).duplicate()
	return view
