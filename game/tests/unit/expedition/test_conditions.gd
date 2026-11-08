extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const ExpeditionState = preload("res://core/expedition/expedition_state.gd")
const Conditions = preload("res://core/expedition/conditions.gd")


func _state() -> RefCounted:
	var st := ExpeditionState.new()
	var members: Array[String] = ["zheng_zha"]
	st.setup(Scenario.load_file("res://tests/fixtures/mini_scenario.json"), {"zheng_zha": Character.new("zheng_zha", "郑吒", {})}, members)
	return st


func test_empty_condition_holds() -> void:
	assert_true(Conditions.check({}, _state()))


func test_flags() -> void:
	var st := _state()
	assert_false(Conditions.check({"flag": "warned_laser"}, st))
	assert_true(Conditions.check({"not_flag": "warned_laser"}, st))
	st.flags["warned_laser"] = true
	assert_true(Conditions.check({"flag": "warned_laser"}, st))


func test_time() -> void:
	var st := _state()
	st.clock = 30
	assert_true(Conditions.check({"time_at_least": 30}, st))
	assert_false(Conditions.check({"time_at_least": 31}, st))
	assert_true(Conditions.check({"time_before": 31}, st))
	assert_false(Conditions.check({"time_before": 30}, st))


func test_party_and_npcs() -> void:
	var st := _state()
	assert_true(Conditions.check({"party_at": "car"}, st))
	assert_false(Conditions.check({"party_at": "hall"}, st))
	assert_true(Conditions.check({"npc_at": {"npc": "matthew", "location": "car"}}, st))
	assert_true(Conditions.check({"npc_alive": "matthew"}, st))
	st.npcs["matthew"]["alive"] = false
	assert_true(Conditions.check({"npc_dead": "matthew"}, st))
	assert_false(Conditions.check({"npc_alive": "nobody"}, st))


## 所有项都要成立。
func test_multiple_keys_are_and() -> void:
	var st := _state()
	st.flags["a"] = true
	assert_true(Conditions.check({"flag": "a", "party_at": "car"}, st))
	assert_false(Conditions.check({"flag": "a", "party_at": "hall"}, st))


func test_combinators() -> void:
	var st := _state()
	st.deviation = 2
	assert_true(Conditions.check({"deviation_at_least": 2}, st))
	assert_true(Conditions.check({"any": [{"flag": "x"}, {"party_at": "car"}]}, st))
	assert_false(Conditions.check({"all": [{"flag": "x"}, {"party_at": "car"}]}, st))
	assert_true(Conditions.check({"not": {"flag": "x"}}, st))


func test_unknown_key_fails() -> void:
	assert_false(Conditions.check({"moon_is_full": true}, _state()))
