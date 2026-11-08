extends "res://tests/test_case.gd"

const UnitFactory = preload("res://core/battle/unit_factory.gd")
const Statuses = preload("res://core/battle/statuses.gd")


func _unit() -> RefCounted:
	return UnitFactory.from_enemy("zombie", "z1", 0)


func test_apply_and_has() -> void:
	var u := _unit()
	var ev := Statuses.apply(u, "bleed")
	assert_eq(ev["type"], "status_applied")
	assert_false(bool(ev["renewed"]))
	assert_true(Statuses.has(u, "bleed"))
	assert_eq(u.statuses.size(), 1)


func test_refresh_resets_duration() -> void:
	var u := _unit()
	Statuses.apply(u, "bleed")
	Statuses.start_of_turn(u)
	assert_eq(int(u.statuses[0]["remaining"]), 2)
	var ev := Statuses.apply(u, "bleed")
	assert_true(bool(ev["renewed"]))
	assert_eq(int(u.statuses[0]["remaining"]), 3)
	assert_eq(u.statuses.size(), 1)


## 感染倒计时不会被再咬一口重置。
func test_keep_does_not_reset() -> void:
	var u := _unit()
	Statuses.apply(u, "infection")
	Statuses.start_of_turn(u)
	Statuses.apply(u, "infection")
	assert_eq(int(u.statuses[0]["remaining"]), 4)


func test_bleed_ticks_three_times() -> void:
	var u := _unit()
	Statuses.apply(u, "bleed")
	for i in 3:
		Statuses.start_of_turn(u)
	assert_almost(u.hp, 40.0 - 15.0)
	assert_false(Statuses.has(u, "bleed"))
	Statuses.start_of_turn(u)
	assert_almost(u.hp, 25.0)


func test_defending_lasts_until_next_turn() -> void:
	var u := _unit()
	Statuses.apply(u, "defending")
	assert_almost(Statuses.mult(u, "damage_taken_mult"), 0.5)
	var events := Statuses.start_of_turn(u)
	assert_false(Statuses.has(u, "defending"))
	assert_eq(events[0]["type"], "status_expired")
	assert_almost(Statuses.mult(u, "damage_taken_mult"), 1.0)


func test_infection_turns_on_fifth_turn() -> void:
	var u := _unit()
	Statuses.apply(u, "infection")
	for i in 4:
		Statuses.start_of_turn(u)
	assert_true(u.alive)
	var events := Statuses.start_of_turn(u)
	assert_false(u.alive)
	assert_true(u.turned)
	assert_eq(events[events.size() - 1]["type"], "infection_turned")


func test_modifiers_and_flags() -> void:
	var u := _unit()
	Statuses.apply(u, "blind")
	Statuses.apply(u, "acid")
	assert_almost(Statuses.sum(u, "hit_mod"), -0.4)
	assert_almost(Statuses.mult(u, "damage_taken_mult"), 1.2)
	Statuses.apply(u, "stun")
	assert_true(Statuses.has_flag(u, "skip_turn"))
	assert_false(Statuses.has_flag(u, "panic"))


func test_remove() -> void:
	var u := _unit()
	Statuses.apply(u, "infection")
	assert_true(Statuses.remove(u, "infection"))
	assert_false(Statuses.remove(u, "infection"))
	assert_false(Statuses.has(u, "infection"))
