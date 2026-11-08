extends "res://tests/test_case.gd"

const Relations = preload("res://core/social/relations.gd")
const Cohesion = preload("res://core/social/cohesion.gd")

const TEAM := ["zheng_zha", "zhang_jie", "zhan_lan", "newbie"]


func test_default_cohesion() -> void:
	var r := Relations.new()
	assert_almost(Cohesion.cohesion(r, TEAM), 44.0)
	assert_almost(Cohesion.cohesion(r, ["solo"]), 100.0)


func test_events_move_cohesion() -> void:
	var r := Relations.new()
	r.apply_event("saved_life", "zheng_zha", "zhan_lan", TEAM)
	var up := Cohesion.cohesion(r, TEAM)
	assert_true(up > 44.0)
	r.apply_event("left_to_die", "zhang_jie", "newbie", TEAM)
	assert_true(Cohesion.cohesion(r, TEAM) < up)


## 信任低、怨恨高的人不听指挥；忠诚能拉回一点。
func test_obedience() -> void:
	var r := Relations.new()
	assert_almost(Cohesion.obedience(r, "newbie", "zheng_zha"), 25.0 + 8.0 + 10.0)
	assert_true(Cohesion.obeys(r, "newbie", "zheng_zha"))
	r.apply_event("used_as_bait", "zheng_zha", "newbie")
	assert_false(Cohesion.obeys(r, "newbie", "zheng_zha"))
	assert_true(Cohesion.obeys(r, "newbie", "zheng_zha", {"newbie": {"loyalty": 200.0}}))


## 冲突升级阶梯：怨恨积累，从"不满"一路升到"背刺"。
func test_conflict_ladder() -> void:
	var r := Relations.new()
	assert_eq(Cohesion.conflict_stage(r, "newbie", "leader"), "none")
	r.change("newbie", "leader", {"resentment": 45, "trust": -30})
	assert_eq(Cohesion.conflict_stage(r, "newbie", "leader"), "talk_back")
	r.change("newbie", "leader", {"resentment": 60, "trust": -20})
	assert_eq(Cohesion.conflict_stage(r, "newbie", "leader"), "betray")
	assert_eq(Cohesion.conflict_stage(r, "newbie", "leader", {"newbie": {"loyalty": 150.0}}), "defect")


## 投票：信任提议人的人赞成；立场能压过信任。过半数通过。
func test_vote() -> void:
	var r := Relations.new()
	r.change("zhan_lan", "zheng_zha", {"trust": 20})
	r.change("newbie", "zheng_zha", {"trust": -20})
	var result := Cohesion.vote(r, "zheng_zha", TEAM)
	assert_eq(result["yes"], ["zheng_zha", "zhan_lan"])
	assert_eq(result["no"], ["zhang_jie", "newbie"])
	assert_false(bool(result["passed"]))
	result = Cohesion.vote(r, "zheng_zha", TEAM, {"zhang_jie": 0.5})
	assert_true(bool(result["passed"]))


func test_fear_contagion_and_rescue() -> void:
	assert_almost(Cohesion.fear_contagion(50.0), 1.0)
	assert_almost(Cohesion.fear_contagion(10.0), 1.4)
	assert_almost(Cohesion.fear_contagion(100.0), 0.5)
	var r := Relations.new()
	assert_true(Cohesion.willing_to_rescue(r, "a", "b"))
	r.change("a", "b", {"resentment": 10})
	assert_false(Cohesion.willing_to_rescue(r, "a", "b"))
