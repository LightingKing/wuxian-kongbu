extends "res://tests/test_case.gd"
## 训练场对练：耗 1 天、出伤害战报、不动角色本身（不受伤、不耗弹药）。

const Character = preload("res://core/model/character.gd")
const GameState = preload("res://core/model/game_state.gd")
const Hub = preload("res://core/hub/hub.gd")


func _game() -> RefCounted:
	var g := GameState.new(1)
	var c := Character.new("zheng_zha", "郑吒", {})
	c.points = 6500
	c.skills = ["punch", "pistol_shot_limited"]
	c.items = {"ammo": 12}
	g.add_character(c)
	return g


func _hub(g: RefCounted, days: int = 9) -> RefCounted:
	var h := Hub.new()
	h.start(g, days)
	h.rest(1)
	return h


func test_spar_costs_a_day_and_reports_damage() -> void:
	var g := _game()
	var h := _hub(g)
	var before: int = h.day
	var events: Array[Dictionary] = h.spar("zheng_zha", "punch")
	var done: Dictionary = {}
	for e: Dictionary in events:
		if String(e["type"]) == "spar_done":
			done = e
	assert_false(done.is_empty(), "要有 spar_done 事件")
	assert_eq(int(h.day), before + 1, "对练耗 1 天")
	assert_eq(String(done["skill"]), "punch")
	assert_true(float(done["damage"]) > 0.0, "打木桩要有伤害，实际 %s" % done["damage"])
	assert_true(int(done["rounds"]) > 0)


func test_spar_does_not_hurt_the_character() -> void:
	var g := _game()
	var h := _hub(g)
	var c: RefCounted = g.characters["zheng_zha"]
	var hp: float = c.hp
	var ammo: float = float(c.items["ammo"])
	h.spar("zheng_zha", "pistol_shot_limited")
	assert_eq(c.hp, hp, "对练用副本，角色不掉血")
	assert_eq(float(c.items["ammo"]), ammo, "对练不耗弹药")


func test_spar_needs_more_damage_after_attribute_gain() -> void:
	var g := _game()
	var h := _hub(g)
	var low := _damage(h, "punch")
	var c: RefCounted = g.characters["zheng_zha"]
	c.attributes.add_trained("muscle", 100.0)
	c.attributes.add_trained("nerve_reaction", 100.0)
	var high := _damage(h, "punch")
	assert_true(high > low, "属性涨了，对练伤害要看得见差别：%s → %s" % [low, high])


func _damage(h: RefCounted, skill_id: String) -> float:
	var events: Array[Dictionary] = h.spar("zheng_zha", skill_id)
	for e: Dictionary in events:
		if String(e["type"]) == "spar_done":
			return float(e["damage"])
	return -1.0


func test_spar_rejects_unknown_skill() -> void:
	var g := _game()
	var h := _hub(g)
	assert_eq(h.spar("zheng_zha", "qigong_wave")[0], {"type": "hub_refused", "reason": "unknown_skill"})


func test_spar_blocked_on_last_day() -> void:
	var g := _game()
	var h := _hub(g)
	h.rest(h.days_left() - 1)
	assert_eq(h.spar("zheng_zha", "punch")[0], {"type": "hub_refused", "reason": "no_days"})
