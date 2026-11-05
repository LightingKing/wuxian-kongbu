extends "res://tests/test_case.gd"

const GameState = preload("res://core/model/game_state.gd")
const Character = preload("res://core/model/character.gd")
const SaveService = preload("res://core/save/save_service.gd")

const PATH := "user://test_save_roundtrip.json"


func test_save_and_load_round_trip() -> void:
	var s := GameState.new(12345)
	var z := Character.new("zheng_zha", "郑吒", {"nerve_reaction": 131})
	z.points = 6502
	z.tickets.add("C", 2)
	s.add_character(z)
	s.add_character(Character.new("zhang_jie", "张杰"))
	s.team_rating = 1
	s.films_record.append("biohazard1")
	assert_eq(SaveService.save_to(PATH, s), OK)
	var loaded: Variant = SaveService.load_from(PATH)
	assert_true(loaded != null)
	assert_eq(loaded.characters.size(), 2)
	assert_eq(loaded.characters["zheng_zha"].points, 6502)
	assert_eq(loaded.characters["zheng_zha"].tickets.counts["C"], 2)
	assert_eq(loaded.team_rating, 1)
	assert_eq(loaded.films_record, ["biohazard1"])
	assert_true(loaded.iron_man)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_rng_sequence_survives_save() -> void:
	var s := GameState.new(99)
	s.rng.randf()
	SaveService.save_to(PATH, s)
	var expected: int = s.rng.randi_range(0, 99999)
	var loaded: Variant = SaveService.load_from(PATH)
	var actual: int = loaded.rng.randi_range(0, 99999)
	assert_eq(actual, expected)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_missing_save_returns_null() -> void:
	assert_true(SaveService.load_from("user://does_not_exist.json") == null)


func test_living_characters() -> void:
	var s := GameState.new()
	var a := Character.new("a", "甲")
	var b := Character.new("b", "乙")
	b.alive = false
	s.add_character(a)
	s.add_character(b)
	assert_eq(s.living_characters().size(), 1)
