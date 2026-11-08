extends "res://tests/test_case.gd"

const Battlefield = preload("res://core/battle/battlefield.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")


func _zombie(id: String, row: int) -> RefCounted:
	return UnitFactory.from_enemy("zombie", id, row)


func test_default_capacity() -> void:
	var f := Battlefield.new()
	assert_eq(f.capacity, 4)
	assert_eq(f.rows, 3)


func test_row_capacity_enforced() -> void:
	var f := Battlefield.new(2)
	assert_true(f.add(_zombie("z1", 0)))
	assert_true(f.add(_zombie("z2", 0)))
	assert_false(f.add(_zombie("z3", 0)))
	assert_true(f.add(_zombie("z3", 1)))
	assert_eq(f.used("enemy", 0), 2)


func test_large_unit_takes_more_slots() -> void:
	var f := Battlefield.new(2)
	var big := _zombie("big", 0)
	big.size = 2
	assert_true(f.add(big))
	assert_false(f.add(_zombie("z1", 0)))


func test_front_row_moves_up_when_emptied() -> void:
	var f := Battlefield.new()
	var front := _zombie("z1", 0)
	f.add(front)
	f.add(_zombie("z2", 1))
	assert_eq(f.front_row("enemy"), 0)
	front.alive = false
	assert_eq(f.front_row("enemy"), 1)
	assert_eq(f.front_row("ally"), -1)


func test_move_adjacent_only() -> void:
	var f := Battlefield.new(1)
	var a := _zombie("z1", 0)
	var b := _zombie("z2", 2)
	f.add(a)
	f.add(b)
	assert_false(f.move(a, 2))
	assert_true(f.move(a, 1))
	assert_eq(a.row, 1)
	assert_false(f.move(b, 1))


func test_dead_units_free_their_slot() -> void:
	var f := Battlefield.new(1)
	var a := _zombie("z1", 0)
	f.add(a)
	a.alive = false
	assert_true(f.can_place("enemy", 0, 1))
	assert_eq(f.side_units("enemy").size(), 0)
	assert_eq(f.get_unit("z1"), a)


func test_opponent() -> void:
	assert_eq(Battlefield.opponent("ally"), "enemy")
	assert_eq(Battlefield.opponent("enemy"), "ally")
