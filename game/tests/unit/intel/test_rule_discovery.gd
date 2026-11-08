extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const GameState = preload("res://core/model/game_state.gd")
const RuleDiscovery = preload("res://core/intel/rule_discovery.gd")


func _chu_xuan() -> RefCounted:
	var c := Character.new("chu_xuan", "楚轩", {"intelligence": 220})
	c.flags["talents"] = ["genius", "tech_talent"]
	c.films_completed = 1
	return c


func test_rules_load() -> void:
	assert_eq(RuleDiscovery.rules().size(), 8)
	assert_eq(RuleDiscovery.rules()["parts_blueprints"]["unlocks"], "catalog:parts_blueprints")


## 楚轩在异形一之后的三项规则发现（设计规格 9.8）。
func test_chu_xuan_discoveries() -> void:
	var g := GameState.new(1)
	g.flags["seen_human_creation"] = true
	var d := RuleDiscovery.new()
	var events: Array[Dictionary] = d.discover_all([_chu_xuan()], g)
	var found: Array = []
	for e in events:
		found.append(e["rule"])
	assert_true(found.has("bodyguard_human"))
	assert_true(found.has("parts_blueprints"))
	assert_true(found.has("record_travel"))
	assert_false(found.has("cold_storage"))
	assert_true(d.is_unlocked("catalog:parts_blueprints"))
	assert_false(d.is_unlocked("hub:cold_storage"))


## 普通人发现不了；缺什么都列出来。
func test_unmet_conditions() -> void:
	var g := GameState.new(1)
	var zz := Character.new("zheng_zha", "郑吒", {})
	assert_eq(RuleDiscovery.unmet("bodyguard_human", zz, g), ["intelligence", "flag:seen_human_creation"] as Array[String])
	assert_eq(RuleDiscovery.unmet("parts_blueprints", zz, g), ["intelligence", "talent:tech_talent"] as Array[String])
	var d := RuleDiscovery.new()
	assert_eq(d.try_discover("record_travel", zz, g)["type"], "rule_not_found")
	assert_eq(d.discover_all([zz], g).size(), 0)


func test_discover_once_and_encyclopedia() -> void:
	var g := GameState.new(1)
	var d := RuleDiscovery.new()
	var chu := _chu_xuan()
	assert_eq(d.try_discover("record_travel", chu, g)["type"], "rule_discovered")
	assert_eq(d.try_discover("record_travel", chu, g)["type"], "rule_known")
	assert_eq(d.encyclopedia(), [{"rule": "record_travel", "name": "“记录”可以回旧片和现实", "by": "chu_xuan"}] as Array[Dictionary])


func test_dead_thinkers_discover_nothing() -> void:
	var g := GameState.new(1)
	var chu := _chu_xuan()
	chu.alive = false
	assert_eq(RuleDiscovery.new().discover_all([chu], g).size(), 0)


func test_round_trip() -> void:
	var g := GameState.new(1)
	var d := RuleDiscovery.new()
	d.try_discover("record_travel", _chu_xuan(), g)
	var copy := RuleDiscovery.new()
	copy.load_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	assert_true(copy.is_unlocked("hub:record_travel"))
