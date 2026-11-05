extends "res://tests/test_case.gd"

const Settlement = preload("res://core/economy/settlement.gd")
const KillReward = preload("res://core/economy/kill_reward.gd")


func test_zheng_zha_first_film_is_6502() -> void:
	# 原著 L482：6502 = 1000 基本 + 5000（B 级支线）+ 500 其他 + 2（杀丧尸）
	var entries: Array = [
		{"kind": "survival", "points": 1000, "label": "存活"},
		{"kind": "side_plot", "points": 5000, "grade": "B", "label": "救下马修"},
		{"kind": "bonus", "points": 500, "label": "精神临界值突破"},
	]
	for i in 20:
		entries.append({"kind": "kill", "points": KillReward.points_for_kill(0.1, 100.0, 100.0)})
	var r := Settlement.settle(entries, 0)
	assert_eq(r.delta, 6502)
	assert_eq(r.final_points, 6502)
	assert_eq(r.tickets, ["B"])
	assert_false(r.erased)


func test_fractional_kills_round_down() -> void:
	var entries: Array = []
	for i in 19:
		entries.append({"kind": "kill", "points": 0.1})
	assert_eq(Settlement.settle(entries, 0).delta, 1)


func test_negative_result_is_erased() -> void:
	# 原著 L1872：奖励点数成负数就会被主神抹杀
	var r := Settlement.settle([{"kind": "penalty", "points": -1000, "label": "杀死新人"}], 200)
	assert_eq(r.final_points, -800)
	assert_true(r.erased)


func test_leak_penalty_absorbed_by_survival() -> void:
	# 原著：李萧毅说漏"奖励点"被扣 10 点，结算时被存活奖励抵消
	var r := Settlement.settle([
		{"kind": "penalty", "points": -10, "label": "泄密"},
		{"kind": "survival", "points": 1000, "label": "存活"},
	], 0)
	assert_eq(r.final_points, 990)
	assert_false(r.erased)
