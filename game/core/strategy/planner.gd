extends RefCounted
## 计策与规划器骨架（设计规格 3.8"布局""对弈"，核心机制分析 9.3C~D）。
## 计划由计策积木组成（data/strategy/stratagems.json）。规划器真正去搜索积木组合：智力决定能组合几块（搜索深度）。
## 局面是一个抽象模型：situation = {"our": 我方战力, "enemy": 敌方战力, "people": 能分派的人数, "minutes": 可用时间, "team_size": 队伍人数}。
## 每块积木的作用：power_bonus（我方加成）、first_strike（先手）、split（分割敌人）、reduction（削减敌人）、enemy_morale（敌方士气）、
## casualty_mult（伤亡倍率）；代价：roles（占用人数）、minutes、role_risk（担任者的死亡风险）、trust_cost（道德代价，扣信任）。
## 胜率按平方律：p = 我方有效战力² ÷ (我方² + 敌方²)。
## 每块积木带着对敌人的假设（assumes）；敌人看穿某个假设时，依赖它的积木只剩代价、没有效果。

const DataLoader = preload("res://core/util/data_loader.gd")

const PATH := "res://data/strategy/stratagems.json"

static var _cache: Dictionary = {}


static func stratagems() -> Dictionary:
	if _cache.is_empty():
		var res := DataLoader.load_json(PATH)
		assert(res.ok, res.error)
		_cache = res.data["stratagems"]
	return _cache


## 搜索深度：智力 100 只能想到一块，150 两块，200 三块，250 以上四块。
static func depth_for(intelligence: float) -> int:
	return clampi(1 + floori((intelligence - 100.0) / 50.0), 1, 4)


## 评估一组积木。broken = 被敌人看穿的假设。
static func evaluate(blocks: Array, situation: Dictionary, broken: Array = []) -> Dictionary:
	var bonus := 0.0
	var first := false
	var split := 0.0
	var reduction := 1.0
	var morale := 0.0
	var casualty_mult := 1.0
	var role_risk := 0.0
	var trust := 0.0
	var minutes := 0
	var roles := 0
	var assumes: Array = []
	for id: String in blocks:
		var s: Dictionary = stratagems()[id]
		roles += int(s.get("roles", 0))
		minutes += int(s.get("minutes", 0))
		role_risk += float(s.get("role_risk", 0.0)) * int(s.get("roles", 0))
		trust += float(s.get("trust_cost", 0.0))
		var works := true
		for a: String in s.get("assumes", []):
			if not assumes.has(a):
				assumes.append(a)
			if broken.has(a):
				works = false
		if not works:
			continue
		bonus += float(s.get("power_bonus", 0.0))
		first = first or bool(s.get("first_strike", false))
		split += float(s.get("split", 0.0))
		reduction *= 1.0 - float(s.get("reduction", 0.0))
		morale += float(s.get("enemy_morale", 0.0))
		casualty_mult *= float(s.get("casualty_mult", 1.0))
	var our := float(situation["our"]) * (1.0 + bonus) * (1.15 if first else 1.0)
	var enemy := float(situation["enemy"]) * reduction * (1.0 - minf(split, 0.5)) * maxf(0.1, 1.0 + morale)
	var p := our * our / (our * our + enemy * enemy)
	var casualties := role_risk + (1.0 - p) * float(situation.get("team_size", 1)) * 0.5 * casualty_mult
	return {
		"blocks": blocks.duplicate(),
		"success": p,
		"casualties": casualties,
		"trust_cost": trust,
		"minutes": minutes,
		"roles": roles,
		"assumes": assumes,
	}


## 计划得分：胜率 × 100 − 预计伤亡 × 15 − 道德代价 × 0.3。
static func score(plan: Dictionary) -> float:
	return float(plan["success"]) * 100.0 - float(plan["casualties"]) * 15.0 - float(plan["trust_cost"]) * 0.3


## 搜索所有不超过深度、人手和时间限制的积木组合，返回得分最高的 top 个（得分相同按积木顺序）。
static func plan(situation: Dictionary, intelligence: float, top: int = 3) -> Array[Dictionary]:
	var ids: Array[String] = []
	for id: String in stratagems():
		if float(stratagems()[id].get("requires_intel", 0.0)) <= intelligence:
			ids.append(id)
	ids.sort()
	var combos: Array[Array] = []
	_combine(ids, 0, [], depth_for(intelligence), combos)
	var plans: Array[Dictionary] = []
	for c in combos:
		var p := evaluate(c, situation)
		if int(p["roles"]) <= int(situation["people"]) and int(p["minutes"]) <= int(situation["minutes"]):
			p["score"] = score(p)
			plans.append(p)
	plans.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	return plans.slice(0, top)


static func _combine(ids: Array[String], start: int, current: Array, depth: int, out: Array[Array]) -> void:
	if not current.is_empty():
		out.append(current.duplicate())
	if current.size() >= depth:
		return
	for i in range(start, ids.size()):
		current.append(ids[i])
		_combine(ids, i + 1, current, depth, out)
		current.pop_back()


## 对弈：敌人看穿了哪些假设，计划的实际胜率是多少。
static func against(chosen: Dictionary, situation: Dictionary, enemy_sees_through: Array) -> Dictionary:
	return evaluate(chosen["blocks"], situation, enemy_sees_through)
