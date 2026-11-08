extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
const Statuses = preload("res://core/battle/statuses.gd")


func _zheng_zha() -> RefCounted:
	var ch := Character.new("zheng_zha", "郑吒", {"muscle": 120, "nerve_reaction": 110})
	ch.flags["potential"] = 0.8
	return ch


func test_from_character_uses_derived_stats() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var u := UnitFactory.from_character(_zheng_zha(), "ally", 0, skills, "player", {"grenade": 2})
	assert_almost(u.hp_max, 40.0 + 0.6 * 100.0 + 0.4 * 120.0)
	assert_almost(u.hp, u.hp_max)
	assert_almost(u.speed(), 110.0)
	assert_almost(u.attack_mult(), 1.2)
	assert_true(u.reincarnator)
	assert_true(u.newbie)
	assert_almost(u.potential, 0.8)
	assert_eq(int(u.resources["grenade"]), 2)
	assert_eq(u.controller, "player")


func test_from_enemy_reads_data() -> void:
	var u := UnitFactory.from_enemy("licker", "licker_1", 1)
	assert_eq(u.display_name, "爬行者")
	assert_eq(u.side, "enemy")
	assert_eq(u.row, 1)
	assert_almost(u.hp, 200.0)
	assert_almost(u.initiative, 0.3)
	assert_true(u.has_flag("ignores_darkness"))
	assert_false(u.reincarnator)


func test_gene_lock_status_speeds_up() -> void:
	var skills: Array[String] = []
	var u := UnitFactory.from_character(_zheng_zha(), "ally", 0, skills)
	Statuses.apply(u, "gene_lock")
	assert_almost(u.speed(), 165.0)
	assert_almost(u.attack_mult(), 1.8)


func test_write_back() -> void:
	var ch := _zheng_zha()
	var skills: Array[String] = []
	var u := UnitFactory.from_character(ch, "ally", 0, skills)
	u.hp = 12.0
	u.fear = 55.0
	u.gene_lock_stage = 1
	u.aftereffect = true
	UnitFactory.write_back(u, ch)
	assert_almost(ch.hp, 12.0)
	assert_almost(ch.fear, 55.0)
	assert_eq(ch.gene_lock_stage, 1)
	assert_true(ch.alive)
	assert_true(bool(ch.flags["gene_lock_aftereffect"]))


func test_write_back_turned() -> void:
	var ch := _zheng_zha()
	var skills: Array[String] = []
	var u := UnitFactory.from_character(ch, "ally", 0, skills)
	u.alive = false
	u.turned = true
	u.hp = -3.0
	UnitFactory.write_back(u, ch)
	assert_false(ch.alive)
	assert_almost(ch.hp, 0.0)
	assert_true(bool(ch.flags["turned"]))
