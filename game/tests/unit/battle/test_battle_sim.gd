extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
const BattleSim = preload("res://core/battle/battle_sim.gd")


func _seeds(n: int) -> Array[int]:
	var out: Array[int] = []
	for i in n:
		out.append(i + 1)
	return out


## 三个拿手枪的新人。
func _squad(resources: Dictionary = {}) -> Array[RefCounted]:
	var out: Array[RefCounted] = []
	var skills: Array[String] = ["pistol_shot"]
	if resources.has("grenade"):
		skills = ["grenade", "pistol_shot"]
	for i in 3:
		var ch := Character.new("p%d" % i, "新人%d" % i, {})
		out.append(UnitFactory.from_character(ch, "ally", i % 2, skills, "ai", resources))
	return out


func _vs_zombies() -> Array[RefCounted]:
	var units := _squad()
	for i in 3:
		units.append(UnitFactory.from_enemy("zombie", "z%d" % i, 0))
	return units


func _vs_licker() -> Array[RefCounted]:
	var units := _squad()
	units.append(UnitFactory.from_enemy("licker", "licker", 0))
	return units


func _vs_licker_with_grenades() -> Array[RefCounted]:
	var units := _squad({"grenade": 2})
	units.append(UnitFactory.from_enemy("licker", "licker", 0))
	return units


func test_same_seeds_same_result() -> void:
	var a := BattleSim.run(_vs_zombies, {}, _seeds(10))
	var b := BattleSim.run(_vs_zombies, {}, _seeds(10))
	assert_eq(a, b)
	assert_eq(int(a["battles"]), 10)


## 三个拿手枪的人对付三只丧尸：大多能赢。
func test_pistols_beat_zombies() -> void:
	var r := BattleSim.run(_vs_zombies, {}, _seeds(20))
	assert_true(float(r["win_rate"]) >= 0.8, str(r))


## 原著：爬行者是精英，手枪几乎无效，三个拿手枪的新人基本打不过。
func test_pistols_lose_to_licker() -> void:
	var r := BattleSim.run(_vs_licker, {}, _seeds(20))
	assert_true(float(r["win_rate"]) <= 0.2, str(r))


## 换成手榴弹（不吃爬行者的子弹减伤）胜率明显提高。
func test_grenades_help_against_licker() -> void:
	var pistols := BattleSim.run(_vs_licker, {}, _seeds(20))
	var grenades := BattleSim.run(_vs_licker_with_grenades, {}, _seeds(20))
	assert_true(float(grenades["win_rate"]) > float(pistols["win_rate"]) + 0.2, "%s / %s" % [pistols, grenades])


## 黑暗里打丧尸更难：人类命中下降、恐惧上升。
func test_darkness_makes_it_harder() -> void:
	var light := BattleSim.run(_vs_zombies, {}, _seeds(20))
	var dark := BattleSim.run(_vs_zombies, {"dark": true}, _seeds(20))
	assert_true(float(dark["avg_ally_deaths"]) > float(light["avg_ally_deaths"]), "%s / %s" % [light, dark])
