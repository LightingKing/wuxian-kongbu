extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const ExpeditionState = preload("res://core/expedition/expedition_state.gd")
const ExpeditionSettlement = preload("res://core/expedition/expedition_settlement.gd")


func _state() -> RefCounted:
	var chars := {}
	for id in ["zheng_zha", "zhang_jie", "newbie"]:
		chars[id] = Character.new(id, id, {})
	var st := ExpeditionState.new()
	var members: Array[String] = ["zheng_zha", "zhang_jie", "newbie"]
	st.setup(Scenario.load_file("res://tests/fixtures/mini_scenario.json"), chars, members)
	return st


## 原著：郑吒第一部 6502 点 = 存活 1000 + 救下马修（B 级支线）5000 + 精神临界值突破 500 + 击杀 2。
func test_zheng_zha_6502() -> void:
	var st := _state()
	st.kill_points["zheng_zha"] = 2.4
	st.add_ledger("zheng_zha", "side_plot", 5000.0, "救下马修", "B")
	st.add_ledger("zheng_zha", "bonus", 500.0, "精神临界值突破")
	var results := ExpeditionSettlement.settle_all(st)
	assert_eq(int(results["zheng_zha"]["final_points"]), 6502)
	var zz: RefCounted = st.characters["zheng_zha"]
	assert_eq(zz.points, 6502)
	assert_true(zz.tickets.has_at_least("B"))
	assert_eq(zz.films_completed, 1)
	assert_true(st.settled)


func test_entries() -> void:
	var st := _state()
	st.add_ledger("zhang_jie", "bonus", 100.0, "讲解规则")
	var entries := ExpeditionSettlement.entries_for(st, "zhang_jie")
	assert_eq(entries.size(), 2)
	assert_eq(entries[0]["kind"], "survival")
	assert_eq(entries[1]["label"], "讲解规则")
	st.characters["newbie"].alive = false
	assert_eq(ExpeditionSettlement.entries_for(st, "newbie").size(), 0)


func test_dead_are_not_settled() -> void:
	var st := _state()
	st.characters["newbie"].alive = false
	st.characters["newbie"].flags["erased"] = "tether"
	var results := ExpeditionSettlement.settle_all(st)
	assert_eq(results["newbie"], {"dead": true, "reason": "tether"})
	assert_eq(st.characters["newbie"].films_completed, 0)


## 点数为负：被主神抹杀（原著）。
func test_negative_points_erased() -> void:
	var st := _state()
	st.add_ledger("newbie", "penalty", -1000.0, "杀死新人")
	st.add_ledger("newbie", "penalty", -10.0, "泄露主神信息")
	var results := ExpeditionSettlement.settle_all(st)
	assert_true(bool(results["newbie"]["erased"]))
	assert_false(st.characters["newbie"].alive)
	assert_eq(st.characters["newbie"].flags["erased"], "negative_points")
