extends RefCounted
## 合法行动（设计规格 4.3、4.4）：技能能不能用、能打谁；换位、防御、开基因锁、撤退。
## 近战只能打对方的"前排"（最前面还有人的一排），远程按技能的 target_rows 选排。
## 行动统一写成字典，玩家和 AI 用同一种格式：
##   {"type": "skill", "skill": 技能 id, "targets": [单位 id, ...]}
##   {"type": "move", "row": 目标排}、{"type": "defend"}、{"type": "gene_lock"}、{"type": "retreat"}

const BattleData = preload("res://core/battle/battle_data.gd")
const Battlefield = preload("res://core/battle/battlefield.gd")
const Statuses = preload("res://core/battle/statuses.gd")


static func _ints(values: Array) -> Array[int]:
	var out: Array[int] = []
	for v in values:
		out.append(int(v))
	return out


static func can_pay(u: RefCounted, skill: Dictionary) -> bool:
	var cost: Dictionary = skill.get("cost", {})
	for k: String in cost:
		if float(u.resources.get(k, 0.0)) < float(cost[k]):
			return false
	return true


static func on_cooldown(u: RefCounted, skill_id: String) -> bool:
	return int(u.cooldowns.get(skill_id, 0)) > 0


## 技能所有可选的目标组合，每个组合是一组单位 id。单体：每人一组；一排：每排一组；全体：一组。
static func target_choices(field: RefCounted, u: RefCounted, skill: Dictionary) -> Array[Array]:
	var out: Array[Array] = []
	var target_side := String(skill["target_side"])
	if target_side == "self":
		out.append([u.id])
		return out
	var side: String = u.side if target_side == "ally" else Battlefield.opponent(u.side)
	var allowed := _ints(skill["target_rows"])
	var rows: Array[int] = []
	if target_side == "enemy" and skill["reach"] == "melee":
		var front: int = field.front_row(side)
		if allowed.has(front):
			rows.append(front)
	else:
		rows = allowed
	var kind := String(skill["target_type"])
	if kind == "single":
		for t: RefCounted in field.side_units(side):
			if rows.has(t.row):
				out.append([t.id])
	elif kind == "row":
		for r in field.rows:
			if not rows.has(r):
				continue
			var ids: Array = []
			for t: RefCounted in field.row_units(side, r):
				ids.append(t.id)
			if not ids.is_empty():
				out.append(ids)
	else:
		var ids: Array = []
		for t: RefCounted in field.side_units(side):
			if rows.has(t.row):
				ids.append(t.id)
		if not ids.is_empty():
			out.append(ids)
	return out


static func usable(field: RefCounted, u: RefCounted, skill_id: String) -> bool:
	var skill := BattleData.skill(skill_id)
	if not _ints(skill["user_rows"]).has(u.row):
		return false
	if on_cooldown(u, skill_id) or not can_pay(u, skill):
		return false
	return not target_choices(field, u, skill).is_empty()


## 当前单位全部合法行动，顺序固定：技能（按单位技能顺序）、换位（先前后后）、防御、基因锁、撤退。
static func legal_actions(field: RefCounted, u: RefCounted, allow_retreat: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for skill_id in u.skills:
		if not usable(field, u, skill_id):
			continue
		for choice in target_choices(field, u, BattleData.skill(skill_id)):
			out.append({"type": "skill", "skill": skill_id, "targets": choice})
	for r: int in [u.row - 1, u.row + 1]:
		if field.can_place(u.side, r, u.size):
			out.append({"type": "move", "row": r})
	out.append({"type": "defend"})
	var g: Dictionary = BattleData.rules()["gene_lock"]
	if u.reincarnator and u.gene_lock_stage >= int(g["active_min_stage"]) and not Statuses.has(u, "gene_lock"):
		out.append({"type": "gene_lock"})
	if allow_retreat and u.side == "ally":
		out.append({"type": "retreat"})
	return out


static func is_legal(field: RefCounted, u: RefCounted, action: Dictionary, allow_retreat: bool) -> bool:
	return legal_actions(field, u, allow_retreat).has(action)
