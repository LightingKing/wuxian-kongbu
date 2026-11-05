extends "res://tests/test_case.gd"

const Rng = preload("res://core/util/rng.gd")


func test_same_seed_same_sequence() -> void:
	var a := Rng.new(42)
	var b := Rng.new(42)
	for i in 5:
		assert_eq(a.randi_range(0, 1000), b.randi_range(0, 1000), "第 %d 次" % i)


func test_save_and_restore_continues_sequence() -> void:
	var a := Rng.new(7)
	a.randf()
	a.randf()
	var saved := a.to_dict()
	var expected := [a.randi_range(0, 99999), a.randi_range(0, 99999)]
	var b := Rng.new(0)
	b.load_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_eq([b.randi_range(0, 99999), b.randi_range(0, 99999)], expected)


func test_chance_extremes() -> void:
	var r := Rng.new(1)
	assert_false(r.chance(0.0))
	assert_true(r.chance(1.0))
