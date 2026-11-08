extends RefCounted
## 恐惧值与基因锁觉醒（设计规格 3.4、3.5）。随机数由调用方传入（roll 在 0~1 之间）。
## 觉醒检定在两种情况下各做一次：生命第一次低于 25%；恐惧值满（降下来以后再满会再检定）。
## 恐惧满时：roll 落在觉醒概率内 → 觉醒；落在后面的崩溃概率内 → 恐慌；否则硬撑过去。

const BattleData = preload("res://core/battle/battle_data.gd")
const Statuses = preload("res://core/battle/statuses.gd")


static func _fear_rules() -> Dictionary:
	return BattleData.rules()["fear"]


static func max_fear() -> float:
	return float(_fear_rules()["max"])


## 增减恐惧，返回实际变化量。增加量按精神力折算：精神力 200 的人只涨一半；减少量不折算。
static func gain(u: RefCounted, amount: float) -> float:
	if u.has_flag("fearless"):
		return 0.0
	var delta := amount
	if amount > 0.0:
		delta = amount * float(_fear_rules()["resist_baseline"]) / maxf(u.spirit, 1.0)
	var before: float = u.fear
	u.fear = clampf(u.fear + delta, 0.0, max_fear())
	if u.fear < max_fear():
		u.fear_checked = false
	return u.fear - before


## 觉醒概率：只有轮回者有，第三阶以上要过心魔关，不能在战斗里觉醒。
static func awaken_chance(u: RefCounted) -> float:
	var g: Dictionary = BattleData.rules()["gene_lock"]
	if not u.reincarnator or u.gene_lock_stage >= int(g["max_stage_in_battle"]):
		return 0.0
	var c := float(g["awaken_base"])
	c += u.potential * float(g["awaken_per_potential"])
	c += (u.spirit - float(_fear_rules()["resist_baseline"])) * float(g["awaken_per_spirit_over_baseline"])
	c += u.fear * float(g["awaken_per_fear"])
	if not u.newbie:
		c += float(g["awaken_veteran_bonus"])
	return clampf(c, 0.0, float(g["awaken_max"]))


## 恐惧满时的崩溃概率：新人高，精神力高的人低。
static func collapse_chance(u: RefCounted) -> float:
	if u.has_flag("fearless"):
		return 0.0
	var c: Dictionary = BattleData.rules()["collapse"]
	var p := float(c["base"])
	if u.newbie:
		p += float(c["newbie_bonus"])
	p += (u.spirit - float(_fear_rules()["resist_baseline"])) * float(c["per_spirit_over_baseline"])
	return clampf(p, float(c["min"]), float(c["max"]))


## 觉醒：基因锁升一阶，进入基因锁状态，恐惧回落，战后有后遗症。
static func awaken(u: RefCounted) -> Array[Dictionary]:
	u.gene_lock_stage += 1
	u.fear = float(_fear_rules()["after_awaken"])
	u.fear_checked = false
	u.aftereffect = true
	var events: Array[Dictionary] = [{"type": "gene_lock_awaken", "target": u.id, "stage": u.gene_lock_stage}]
	events.append(Statuses.apply(u, "gene_lock"))
	return events


## 生命第一次低于 25% 时的觉醒检定。
static func check_low_hp(u: RefCounted, roll: float) -> Array[Dictionary]:
	var g: Dictionary = BattleData.rules()["gene_lock"]
	if u.low_hp_checked or not u.reincarnator or u.hp <= 0.0 or u.hp_ratio() >= float(g["low_hp_ratio"]):
		return []
	u.low_hp_checked = true
	if roll < awaken_chance(u):
		return awaken(u)
	return [{"type": "awaken_failed", "target": u.id, "trigger": "low_hp"}]


## 恐惧满时的检定：觉醒、崩溃（恐慌）或硬撑。
static func check_full_fear(u: RefCounted, roll: float) -> Array[Dictionary]:
	if u.fear < max_fear() or u.fear_checked:
		return []
	u.fear_checked = true
	var aw := awaken_chance(u)
	if roll < aw:
		return awaken(u)
	if roll < aw + collapse_chance(u):
		var events: Array[Dictionary] = [{"type": "fear_collapse", "target": u.id}]
		events.append(Statuses.apply(u, "panic"))
		return events
	return [{"type": "fear_endured", "target": u.id}]
