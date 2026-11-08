extends "res://tests/test_case.gd"

const Ctb = preload("res://core/battle/ctb.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")


func _unit(id: String, speed: float) -> RefCounted:
	var u := UnitFactory.from_enemy("zombie", id, 0)
	u.base_speed = speed
	return u


func _run(ctb: RefCounted, units: Array[RefCounted], n: int) -> Array[String]:
	var order: Array[String] = []
	for i in n:
		var u: RefCounted = ctb.next_actor(units)
		order.append(u.id)
		ctb.advance(u, 1.0)
	return order


func test_delay_formula() -> void:
	var ctb := Ctb.new()
	assert_almost(ctb.delay(100.0, 1.0), 100.0)
	assert_almost(ctb.delay(200.0, 1.0), 50.0)
	assert_almost(ctb.delay(100.0, 0.6), 60.0)


## 速度 200 的单位每行动两次，速度 100 的行动一次。
func test_double_speed_acts_twice() -> void:
	var ctb := Ctb.new()
	var fast := _unit("fast", 200.0)
	var slow := _unit("slow", 100.0)
	var units: Array[RefCounted] = [slow, fast]
	for u in units:
		ctb.init_unit(u)
	var order := _run(ctb, units, 6)
	assert_eq(order.count("fast"), 4, str(order))
	assert_eq(order.count("slow"), 2, str(order))
	assert_eq(order[0], "fast")


## 时间相同时，先加入战场的先动。
func test_tie_keeps_insertion_order() -> void:
	var ctb := Ctb.new()
	var a := _unit("a", 100.0)
	var b := _unit("b", 100.0)
	var units: Array[RefCounted] = [a, b]
	for u in units:
		ctb.init_unit(u)
	assert_eq(_run(ctb, units, 4), ["a", "b", "a", "b"] as Array[String])


## 爬行者的舌头先手：initiative 0.3。
func test_initiative_acts_first() -> void:
	var ctb := Ctb.new()
	var human := _unit("human", 100.0)
	var licker := UnitFactory.from_enemy("licker", "licker", 0)
	var units: Array[RefCounted] = [human, licker]
	for u in units:
		ctb.init_unit(u)
	assert_eq(ctb.next_actor(units).id, "licker")


func test_preview_does_not_change_units() -> void:
	var ctb := Ctb.new()
	var fast := _unit("fast", 200.0)
	var slow := _unit("slow", 100.0)
	var units: Array[RefCounted] = [slow, fast]
	for u in units:
		ctb.init_unit(u)
	var before: float = fast.next_time
	var p := ctb.preview(units, 10)
	assert_eq(p.size(), 10)
	assert_almost(fast.next_time, before)
	assert_eq(p.slice(0, 6), _run(ctb, units, 6))


func test_dead_units_skipped() -> void:
	var ctb := Ctb.new()
	var a := _unit("a", 300.0)
	var b := _unit("b", 100.0)
	var units: Array[RefCounted] = [a, b]
	for u in units:
		ctb.init_unit(u)
	a.alive = false
	assert_eq(ctb.next_actor(units).id, "b")
	assert_eq(ctb.preview(units, 3), ["b", "b", "b"] as Array[String])
	b.fled = true
	assert_eq(ctb.next_actor(units), null)
