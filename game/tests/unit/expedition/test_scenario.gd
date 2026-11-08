extends "res://tests/test_case.gd"

const Scenario = preload("res://core/expedition/scenario.gd")
const BattleData = preload("res://core/battle/battle_data.gd")

const FIXTURE := "res://tests/fixtures/mini_scenario.json"


func test_fixture_loads_and_validates() -> void:
	var sc := Scenario.load_file(FIXTURE)
	assert_true(sc != null)
	assert_eq(sc.id, "mini_hive")
	var errors: Array[String] = sc.validate()
	assert_eq(errors.size(), 0, str(errors))


func test_path_and_neighbors() -> void:
	var sc := Scenario.load_file(FIXTURE)
	assert_eq(int(sc.path_between("hall", "car")["minutes"]), 10)
	assert_true(sc.path_between("car", "laser").is_empty())
	assert_eq(sc.neighbors("hall"), ["car", "stairs", "sewer"] as Array[String])
	assert_eq(Scenario.path_key("laser", "control"), "control|laser")


func test_hops() -> void:
	var sc := Scenario.load_file(FIXTURE)
	assert_eq(sc.hops("car", "car"), 0)
	assert_eq(sc.hops("car", "hall"), 1)
	assert_eq(sc.hops("car", "laser"), 3)
	assert_eq(sc.hops("sewer", "control"), 4)


func test_validate_catches_errors() -> void:
	var sc := Scenario.new({
		"id": "bad", "name": "坏剧本", "start_location": "nowhere", "duration_minutes": 10, "main_task": "",
		"locations": {"a": {"name": "A"}},
		"paths": [{"a": "a", "b": "b", "minutes": 5}],
		"npcs": {"x": {"name": "X", "location": "a"}},
		"watch": {"tether": {"npc": "ghost"}},
		"events": [
			{"id": "e1", "effects": [{"explode": true}]},
			{"id": "e1", "at": 0, "effects": [{"battle": {"location": "a", "enemies": [{"def": "dragon", "count": 1}]}}]},
		],
	})
	var errors := sc.validate()
	var text := "\n".join(errors)
	assert_true(text.contains("起点"), text)
	assert_true(text.contains("不存在的地点 b"), text)
	assert_true(text.contains("百米绑定"), text)
	assert_true(text.contains("既没有 at 也没有 when"), text)
	assert_true(text.contains("未知效果 explode"), text)
	assert_true(text.contains("重复"), text)
	assert_true(text.contains("dragon"), text)


func test_missing_keys() -> void:
	var errors := Scenario.new({"id": "x"}).validate()
	assert_true(errors.size() > 0)


## 敌人带着击杀基础价和威胁值（结算用，原著：10 只丧尸 = 1 点，爬行者 100 点）。
func test_enemies_have_kill_values() -> void:
	assert_almost(float(BattleData.enemy("zombie")["kill_base"]), 0.1)
	assert_almost(float(BattleData.enemy("licker")["kill_base"]), 100.0)
	assert_almost(float(BattleData.enemy("licker")["threat"]), 300.0)
