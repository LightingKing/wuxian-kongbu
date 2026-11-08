extends "res://tests/test_case.gd"

const Planner = preload("res://core/strategy/planner.gd")

const EVEN := {"our": 100.0, "enemy": 100.0, "people": 4, "minutes": 60, "team_size": 4}
const OUTMATCHED := {"our": 100.0, "enemy": 180.0, "people": 4, "minutes": 90, "team_size": 4}


func test_stratagems_load() -> void:
	assert_eq(Planner.stratagems().size(), 12)
	assert_eq(Planner.stratagems()["bait"]["name"], "诱饵")


func test_depth_by_intelligence() -> void:
	assert_eq(Planner.depth_for(100.0), 1)
	assert_eq(Planner.depth_for(150.0), 2)
	assert_eq(Planner.depth_for(220.0), 3)
	assert_eq(Planner.depth_for(400.0), 4)


func test_baseline_even_fight() -> void:
	var p := Planner.evaluate([], EVEN)
	assert_almost(float(p["success"]), 0.5)
	assert_almost(float(p["casualties"]), 1.0)


## 伏击：先手 + 加成；诱饵：先手，但担任诱饵的人风险高，还扣信任。
func test_block_effects() -> void:
	var ambush := Planner.evaluate(["ambush"], EVEN)
	var our := 100.0 * 1.2 * 1.15
	assert_almost(float(ambush["success"]), our * our / (our * our + 10000.0))
	var bait := Planner.evaluate(["bait"], EVEN)
	assert_almost(float(bait["trust_cost"]), 25.0)
	assert_true(float(bait["casualties"]) > 0.4)
	assert_eq(bait["assumes"], ["enemy_takes_bait"])


## 计划不超过可分派的人手和时间。
func test_limits() -> void:
	var nobody := {"our": 100.0, "enemy": 100.0, "people": 0, "minutes": 60, "team_size": 1}
	for p in Planner.plan(nobody, 300.0, 50):
		assert_eq(int(p["roles"]), 0, str(p["blocks"]))
	var hurry := {"our": 100.0, "enemy": 100.0, "people": 4, "minutes": 10, "team_size": 4}
	for p in Planner.plan(hurry, 300.0, 50):
		assert_true(int(p["minutes"]) <= 10, str(p["blocks"]))


## 越聪明想得越深：更好的计划，且结果确定。
func test_smarter_finds_better_plan() -> void:
	var dull := Planner.plan(OUTMATCHED, 100.0)
	var genius := Planner.plan(OUTMATCHED, 220.0)
	assert_eq((dull[0]["blocks"] as Array).size(), 1)
	assert_true(float(genius[0]["score"]) > float(dull[0]["score"]))
	assert_true(float(genius[0]["success"]) > float(dull[0]["success"]))
	assert_eq(Planner.plan(OUTMATCHED, 220.0), genius)


## 情报欺骗要智力 180 才想得到。
func test_requires_intel() -> void:
	for p in Planner.plan(EVEN, 170.0, 200):
		assert_false((p["blocks"] as Array).has("deceive"))


## 对弈：敌人看穿"知道它的行进路线"，伏击和陷阱就只剩代价。
func test_seen_through() -> void:
	var chosen := Planner.evaluate(["ambush", "trap"], OUTMATCHED)
	var real := Planner.against(chosen, OUTMATCHED, ["enemy_path_known"])
	assert_true(float(real["success"]) < float(chosen["success"]))
	assert_almost(float(real["success"]), float(Planner.evaluate([], OUTMATCHED)["success"]))
	assert_almost(float(real["trust_cost"]), float(chosen["trust_cost"]))
	assert_eq(real["minutes"], chosen["minutes"])
