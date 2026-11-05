extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")


func test_new_character_full_hp_and_newbie() -> void:
	var c := Character.new("zheng_zha", "郑吒")
	assert_almost(c.hp, c.hp_max())
	assert_true(c.is_newbie())
	c.films_completed = 1
	assert_false(c.is_newbie())


func test_round_trip_through_json() -> void:
	var c := Character.new("zhan_lan", "詹岚", {"spirit": 130})
	c.points = 1500
	c.tickets.add("D", 2)
	c.gene_lock_stage = 1
	c.flags["writer"] = true
	var d := Character.new()
	d.load_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(d.id, "zhan_lan")
	assert_eq(d.points, 1500)
	assert_eq(d.tickets.counts["D"], 2)
	assert_eq(d.gene_lock_stage, 1)
	assert_almost(d.attributes.total("spirit"), 130.0)
	assert_true(d.flags["writer"])
