extends RefCounted
## 从轮回者（character.gd）或敌人数据创建战斗单位，战后把结果写回轮回者。

const BattleUnit = preload("res://core/battle/battle_unit.gd")
const BattleData = preload("res://core/battle/battle_data.gd")
const DerivedStats = preload("res://core/model/derived_stats.gd")


## 轮回者进战斗。skill_ids 是本场可用的技能；resources 是带进来的能量和道具。
static func from_character(ch: RefCounted, side: String, row: int, skill_ids: Array[String], controller: String = "player", resources: Dictionary = {}) -> RefCounted:
	var d := DerivedStats.compute(ch.attributes)
	var u := BattleUnit.new()
	u.id = ch.id
	u.character_id = ch.id
	u.display_name = ch.display_name
	u.side = side
	u.row = row
	u.controller = controller
	u.hp_max = float(d["hp_max"])
	u.hp = minf(ch.hp, u.hp_max)
	u.base_speed = float(d["speed"])
	u.base_attack_mult = float(d["attack_mult"])
	u.spirit = float(d["mental_resist"])
	u.reincarnator = true
	u.newbie = ch.is_newbie()
	u.potential = float(ch.flags.get("potential", 0.0))
	u.gene_lock_stage = ch.gene_lock_stage
	u.fear = ch.fear
	u.skills = skill_ids.duplicate()
	u.resources = resources.duplicate()
	u.revive_charges = int(resources.get("rebirth_cross", 0))
	return u


## 按 enemies.json 创建敌人。unit_id 在一场战斗里要唯一，例如 "zombie_1"。
static func from_enemy(def_id: String, unit_id: String, row: int) -> RefCounted:
	var e := BattleData.enemy(def_id)
	var u := BattleUnit.new()
	u.id = unit_id
	u.def_id = def_id
	u.display_name = String(e["name"])
	u.side = "enemy"
	u.row = row
	u.controller = "ai"
	u.ai_profile = String(e["ai"])
	u.hp_max = float(e["hp"])
	u.hp = u.hp_max
	u.base_speed = float(e["speed"])
	u.base_attack_mult = float(e["attack_mult"])
	u.size = int(e.get("size", 1))
	for s: String in e["skills"]:
		u.skills.append(s)
	for f: String in e.get("flags", []):
		u.flags.append(f)
	u.tag_mult = (e.get("tag_mult", {}) as Dictionary).duplicate()
	u.initiative = float(e.get("initiative", 1.0))
	u.fear_aura = float(e.get("fear_aura", 0.0))
	return u


## 战斗结束后把生命、恐惧、基因锁、生死写回轮回者。
static func write_back(u: RefCounted, ch: RefCounted) -> void:
	ch.hp = maxf(u.hp, 0.0)
	ch.fear = u.fear
	ch.gene_lock_stage = u.gene_lock_stage
	ch.alive = u.alive
	if u.turned:
		ch.flags["turned"] = true
	if u.aftereffect:
		ch.flags["gene_lock_aftereffect"] = true
