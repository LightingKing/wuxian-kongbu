extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const GameState = preload("res://core/model/game_state.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const Expedition = preload("res://core/expedition/expedition.gd")
const Persuasion = preload("res://core/expedition/persuasion.gd")
const IntelState = preload("res://core/intel/intel_state.gd")


func _scenario() -> RefCounted:
	return Scenario.new({
		"id": "talk", "name": "说服测试", "start_location": "a", "duration_minutes": 60, "main_task": "活着",
		"locations": {"a": {"name": "A"}},
		"paths": [],
		"npcs": {"queen": {"name": "火焰女皇", "location": "a"}},
		"watch": {},
		"facts": {"queen_controls": {"statement": "火焰女皇控制激光", "domain": "biohazard", "truth": true, "difficulty": 0.4, "clues": {"console": 1.0}}},
		"events": [{"id": "talk", "when": {"party_at": "a"}, "location": "a", "effects": [
			{"persuade": {"id": "ask", "npc": "queen", "goal": "逼她用激光", "difficulty": 2,
				"requires_fact": "queen_controls", "keywords": ["威胁", "断电", "激光", "关闭"],
				"success": [{"set_flag": "ok"}], "failure": [{"set_flag": "no"}]}},
		]}],
	})


func _start(intelligence: float = 100.0) -> RefCounted:
	var g := GameState.new(1)
	g.add_character(Character.new("hero", "英雄", {"intelligence": intelligence}))
	var ex := Expedition.new()
	var members: Array[String] = ["hero"]
	ex.start(g, _scenario(), members)
	return ex


func test_level_scoring() -> void:
	var check := {"keywords": ["威胁", "断电", "激光", "关闭"]}
	var normal := Character.new("n", "N", {"intelligence": 100})
	var smart := Character.new("s", "S", {"intelligence": 150})
	var intel := IntelState.new()
	assert_eq(Persuasion.level(check, [], normal, intel), 0)
	assert_eq(Persuasion.level(check, ["威胁"], normal, intel), 1)
	assert_eq(Persuasion.level(check, ["威胁", "断电", "激光"], normal, intel), 3)
	assert_eq(Persuasion.level(check, ["威胁", "断电"], smart, intel), 3)


## 没有推理出事实就开不了口：按失败处理，并报告 persuade_blocked。
func test_blocked_without_fact() -> void:
	var ex := _start()
	assert_eq(ex.st.pending_check["id"], "ask")
	var events: Array[Dictionary] = ex.persuade_with(["威胁", "断电", "激光"], "hero")
	assert_eq(events[0]["type"], "persuade_blocked")
	assert_true(bool(ex.st.flags["no"]))
	assert_true(ex.st.pending_check.is_empty())


## 推理出来之后，三个关键词压过难度 2，成功。
func test_success_after_deduction() -> void:
	var ex := _start(150.0)
	ex.st.intel.confirmed["queen_controls"] = true
	var events: Array[Dictionary] = ex.persuade_with(["威胁", "断电", "激光"], "hero")
	assert_eq(events[0]["type"], "persuade_result")
	assert_true(bool(events[0]["success"]))
	assert_true(bool(ex.st.flags["ok"]))
	assert_false(bool(ex.st.flags.get("no", false)))
