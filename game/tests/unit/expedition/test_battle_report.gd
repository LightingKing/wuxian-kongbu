extends "res://tests/test_case.gd"

const UnitFactory = preload("res://core/battle/unit_factory.gd")
const BattleReport = preload("res://core/expedition/battle_report.gd")


func _units() -> Array[RefCounted]:
	var z1 := UnitFactory.from_enemy("zombie", "z1", 0)
	var z2 := UnitFactory.from_enemy("licker", "l1", 0)
	var a := UnitFactory.from_enemy("zombie", "zheng_zha", 0)
	a.side = "ally"
	var b := UnitFactory.from_enemy("zombie", "newbie", 0)
	b.side = "ally"
	var units: Array[RefCounted] = [z1, z2, a, b]
	return units


func test_last_hit_gets_the_kill() -> void:
	var history: Array[Dictionary] = [
		{"type": "damage", "source": "newbie", "target": "z1", "amount": 30.0, "hp": 10.0},
		{"type": "damage", "source": "zheng_zha", "target": "z1", "amount": 16.0, "hp": -6.0},
		{"type": "death", "target": "z1", "turned": false},
		{"type": "damage", "source": "zheng_zha", "target": "l1", "amount": 200.0, "hp": 0.0},
		{"type": "death", "target": "l1", "turned": false},
	]
	var r := BattleReport.summarize(history, _units())
	assert_eq(r["kills"], [
		{"killer": "zheng_zha", "victim": "z1", "def_id": "zombie"},
		{"killer": "zheng_zha", "victim": "l1", "def_id": "licker"},
	])
	assert_eq(r["deaths"], [])


func test_ally_deaths_and_fled() -> void:
	var history: Array[Dictionary] = [
		{"type": "damage", "source": "zheng_zha", "target": "newbie", "amount": 200.0, "hp": -60.0},
		{"type": "death", "target": "newbie", "turned": false},
		{"type": "damage", "source": "z1", "target": "zheng_zha", "amount": 10.0, "hp": 130.0},
		{"type": "death", "target": "zheng_zha", "turned": true},
		{"type": "fled", "unit": "z1"},
	]
	var r := BattleReport.summarize(history, _units())
	assert_eq(r["deaths"], [
		{"id": "newbie", "killer": "zheng_zha", "turned": false},
		{"id": "zheng_zha", "killer": "", "turned": true},
	])
	assert_eq(r["fled"], ["z1"])


func test_no_killer_without_damage() -> void:
	var history: Array[Dictionary] = [{"type": "death", "target": "z1", "turned": false}]
	assert_eq(BattleReport.summarize(history, _units())["kills"][0]["killer"], "")
