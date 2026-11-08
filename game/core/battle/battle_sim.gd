extends RefCounted
## 战斗模拟（设计规格 10.4）：双方都交给 AI，用一组种子各打一场，统计结果，用于平衡和回归测试。
## make_units 每次调用都要返回一组全新的单位（不能复用上一场打过的）。

const Battle = preload("res://core/battle/battle.gd")
const Rng = preload("res://core/util/rng.gd")


static func run(make_units: Callable, options: Dictionary, seeds: Array[int]) -> Dictionary:
	var outcomes: Dictionary = {}
	var actions := 0
	var ally_deaths := 0
	for s in seeds:
		var units: Array[RefCounted] = make_units.call()
		for u in units:
			u.controller = "ai"
		var b := Battle.new()
		b.setup(units, options, Rng.new(s))
		outcomes[b.outcome] = int(outcomes.get(b.outcome, 0)) + 1
		actions += b.action_count
		for u in units:
			if u.side == "ally" and not u.alive:
				ally_deaths += 1
	var n := float(seeds.size())
	return {
		"battles": seeds.size(),
		"outcomes": outcomes,
		"win_rate": float(outcomes.get("victory", 0)) / n,
		"avg_actions": float(actions) / n,
		"avg_ally_deaths": float(ally_deaths) / n,
	}
