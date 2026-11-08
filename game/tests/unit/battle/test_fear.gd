extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
const Fear = preload("res://core/battle/fear.gd")
const Statuses = preload("res://core/battle/statuses.gd")


func _unit(potential: float, newbie: bool, spirit: float = 100.0) -> RefCounted:
	var ch := Character.new("c", "轮回者", {"spirit": spirit})
	ch.flags["potential"] = potential
	if not newbie:
		ch.films_completed = 1
	var skills: Array[String] = []
	return UnitFactory.from_character(ch, "ally", 0, skills)


func test_gain_scaled_by_spirit() -> void:
	var normal := _unit(0.0, true)
	var strong := _unit(0.0, true, 200.0)
	assert_almost(Fear.gain(normal, 20.0), 20.0)
	assert_almost(Fear.gain(strong, 20.0), 10.0)
	assert_almost(Fear.gain(strong, -15.0), -10.0)
	assert_almost(Fear.gain(normal, 500.0), 80.0)


func test_fearless_never_afraid() -> void:
	var z := UnitFactory.from_enemy("zombie", "z", 0)
	assert_almost(Fear.gain(z, 50.0), 0.0)
	assert_almost(Fear.collapse_chance(z), 0.0)
	assert_almost(Fear.awaken_chance(z), 0.0)


func test_awaken_chance_formula() -> void:
	var u := _unit(0.8, true)
	u.fear = 100.0
	assert_almost(Fear.awaken_chance(u), 0.02 + 0.32 + 0.1)
	var vet := _unit(0.3, false)
	vet.fear = 100.0
	assert_almost(Fear.awaken_chance(vet), 0.02 + 0.12 + 0.1 + 0.05)


## 原著：资深者和高潜力者容易觉醒，新人容易崩溃。
func test_newbie_collapses_more() -> void:
	assert_almost(Fear.collapse_chance(_unit(0.0, true)), 0.7)
	assert_almost(Fear.collapse_chance(_unit(0.0, false)), 0.35)
	assert_almost(Fear.collapse_chance(_unit(0.0, false, 200.0)), 0.15)


func test_no_awaken_past_stage_three() -> void:
	var u := _unit(1.0, false)
	u.gene_lock_stage = 3
	assert_almost(Fear.awaken_chance(u), 0.0)


func test_awaken_effects() -> void:
	var u := _unit(0.5, true)
	u.fear = 100.0
	var events := Fear.awaken(u)
	assert_eq(events[0]["type"], "gene_lock_awaken")
	assert_eq(u.gene_lock_stage, 1)
	assert_almost(u.fear, 30.0)
	assert_true(u.aftereffect)
	assert_true(Statuses.has(u, "gene_lock"))


func test_low_hp_check_once() -> void:
	var u := _unit(0.8, true)
	u.hp = u.hp_max * 0.5
	assert_eq(Fear.check_low_hp(u, 0.0).size(), 0)
	u.hp = u.hp_max * 0.2
	var events := Fear.check_low_hp(u, 0.99)
	assert_eq(events[0]["type"], "awaken_failed")
	assert_true(u.low_hp_checked)
	assert_eq(Fear.check_low_hp(u, 0.0).size(), 0)
	assert_eq(u.gene_lock_stage, 0)


func test_low_hp_awaken() -> void:
	var u := _unit(0.8, true)
	u.hp = u.hp_max * 0.2
	var events := Fear.check_low_hp(u, 0.1)
	assert_eq(events[0]["type"], "gene_lock_awaken")
	assert_eq(u.gene_lock_stage, 1)


## 新人恐惧满：觉醒 0.12、崩溃 0.7，其余硬撑。
func test_full_fear_outcomes() -> void:
	var a := _unit(0.0, true)
	a.fear = 100.0
	assert_almost(Fear.awaken_chance(a), 0.12)
	assert_eq(Fear.check_full_fear(a, 0.05)[0]["type"], "gene_lock_awaken")
	var b := _unit(0.0, true)
	b.fear = 100.0
	var collapse := Fear.check_full_fear(b, 0.5)
	assert_eq(collapse[0]["type"], "fear_collapse")
	assert_true(Statuses.has(b, "panic"))
	var c := _unit(0.0, true)
	c.fear = 100.0
	assert_eq(Fear.check_full_fear(c, 0.9)[0]["type"], "fear_endured")
	assert_eq(Fear.check_full_fear(c, 0.0).size(), 0)


func test_check_again_after_fear_drops() -> void:
	var u := _unit(0.0, true)
	u.fear = 100.0
	Fear.check_full_fear(u, 0.9)
	assert_true(u.fear_checked)
	Fear.gain(u, -20.0)
	assert_false(u.fear_checked)
	Fear.gain(u, 50.0)
	assert_eq(Fear.check_full_fear(u, 0.9).size(), 1)
