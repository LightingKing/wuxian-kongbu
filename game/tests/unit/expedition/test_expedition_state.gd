extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const ExpeditionState = preload("res://core/expedition/expedition_state.gd")

const FIXTURE := "res://tests/fixtures/mini_scenario.json"


func _state() -> RefCounted:
	var chars := {}
	for id in ["zheng_zha", "zhang_jie", "newbie"]:
		chars[id] = Character.new(id, id, {})
	var st := ExpeditionState.new()
	var members: Array[String] = ["zheng_zha", "zhang_jie", "newbie"]
	st.setup(Scenario.load_file(FIXTURE), chars, members)
	return st


func test_setup() -> void:
	var st := _state()
	assert_eq(st.clock, 0)
	assert_eq(st.location_of("zheng_zha"), "car")
	assert_eq(st.members_at("car").size(), 3)
	assert_true(st.party_at("car"))
	assert_eq(st.npcs["matthew"]["location"], "car")
	assert_eq(st.tether["npc"], "matthew")
	assert_true(st.is_path_open("car", "hall"))
	assert_false(st.is_path_open("control", "laser"))


func test_split_and_merge() -> void:
	var st := _state()
	var group: Array[String] = ["newbie"]
	var sid: String = st.split("s1", group)
	assert_eq(sid, "s2")
	assert_eq(st.squad_of("newbie"), "s2")
	assert_eq(st.living_members("s1"), ["zheng_zha", "zhang_jie"] as Array[String])
	st.squads["s2"]["items"]["grenade"] = 1.0
	st.squads["s2"]["location"] = "hall"
	assert_false(st.merge("s1", "s2"))
	st.squads["s2"]["location"] = "car"
	assert_true(st.merge("s1", "s2"))
	assert_false(st.squads.has("s2"))
	assert_eq(st.living_members("s1").size(), 3)
	assert_almost(float(st.squads["s1"]["items"]["grenade"]), 1.0)


func test_split_rejects_bad_input() -> void:
	var st := _state()
	var everyone: Array[String] = ["zheng_zha", "zhang_jie", "newbie"]
	var stranger: Array[String] = ["alice"]
	var none: Array[String] = []
	assert_eq(st.split("s1", everyone), "")
	assert_eq(st.split("s1", stranger), "")
	assert_eq(st.split("s1", none), "")
	assert_eq(st.split("s9", stranger), "")


func test_dead_members_filtered() -> void:
	var st := _state()
	st.characters["newbie"].alive = false
	assert_eq(st.all_living().size(), 2)
	assert_false(st.is_alive("newbie"))
	assert_eq(st.roster.size(), 3)


func test_save_round_trip() -> void:
	var st := _state()
	var group: Array[String] = ["newbie"]
	st.split("s1", group)
	st.clock = 42
	st.flags["warned_laser"] = true
	st.tether_out["newbie"] = 5
	st.kill_counts["zheng_zha"] = 3
	st.add_ledger("zheng_zha", "bonus", 500.0, "精神临界值突破")
	var text := JSON.stringify(st.to_dict())
	var parsed: Dictionary = JSON.parse_string(text)
	var copy := ExpeditionState.new()
	copy.load_dict(parsed, Scenario.load_file(FIXTURE), st.characters)
	assert_eq(copy.to_dict(), st.to_dict())
	assert_eq(copy.squad_of("newbie"), "s2")
	assert_eq(copy.tether_out["newbie"], 5)
