extends RefCounted
## 命中与伤害公式。纯函数：随机数由调用方传入（roll 在 0~1 之间），方便测试。

const BattleData = preload("res://core/battle/battle_data.gd")
const Statuses = preload("res://core/battle/statuses.gd")


## 技能没有 accuracy（治疗、鼓舞）时必中。
## 命中 = 技能命中 + (攻方速度 − 守方速度) × 系数 + 状态修正；黑暗中再降，爬行者这类靠热感嗅觉的不受影响。
static func hit_chance(attacker: RefCounted, target: RefCounted, skill: Dictionary, dark: bool) -> float:
	if not skill.has("accuracy"):
		return 1.0
	var h: Dictionary = BattleData.rules()["hit"]
	var c := float(skill["accuracy"])
	c += (attacker.speed() - target.speed()) * float(h["per_speed_point"])
	c += Statuses.sum(attacker, "hit_mod")
	if dark and not attacker.has_flag("ignores_darkness"):
		c -= float(h["darkness_penalty"])
	return clampf(c, float(h["min"]), float(h["max"]))


## 伤害 = 威力 ×（肌肉加成，只对 scaling = muscle 的技能）× 攻方状态加成 × 浮动 × 标签承伤倍率 × 守方状态承伤倍率，四舍五入。
## roll = 0.5 时没有浮动；0 和 1 分别是下限和上限。
static func damage(attacker: RefCounted, target: RefCounted, skill: Dictionary, roll: float) -> float:
	var dmg := float(skill.get("power", 0.0))
	if dmg <= 0.0:
		return 0.0
	if skill.get("scaling", "fixed") == "muscle":
		dmg *= attacker.base_attack_mult
	dmg *= Statuses.mult(attacker, "attack_mult")
	var variance := float(BattleData.rules()["damage_variance"])
	dmg *= 1.0 + variance * (2.0 * roll - 1.0)
	for tag: String in skill.get("tags", []):
		dmg *= float(target.tag_mult.get(tag, 1.0))
	dmg *= Statuses.mult(target, "damage_taken_mult")
	return maxf(0.0, roundf(dmg))
