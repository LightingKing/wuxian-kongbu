extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
const Battlefield = preload("res://core/battle/battlefield.gd")
const BattleData = preload("res://core/battle/battle_data.gd")
const Targeting = preload("res://core/battle/targeting.gd")
const Statuses = preload("res://core/battle/statuses.gd")


func _human(id: String, row: int, skills: Array[String], resources: Dictionary = {}) -> RefCounted:
	return UnitFactory.from_character(Character.new(id, id, {}), "ally", row, skills, "player", resources)


func _field(units: Array[RefCounted]) -> RefCounted:
	var f := Battlefield.new()
	for u in units:
		f.add(u)
	return f


## 近战只能打对方前排；前排打空了，中排顶上来。
func test_melee_hits_front_row_only() -> void:
	var skills: Array[String] = ["punch"]
	var h := _human("h", 0, skills)
	var z1 := UnitFactory.from_enemy("zombie", "z1", 0)
	var z2 := UnitFactory.from_enemy("zombie", "z2", 1)
	var f := _field([h, z1, z2])
	var punch := BattleData.skill("punch")
	assert_eq(Targeting.target_choices(f, h, punch), [["z1"]] as Array[Array])
	z1.alive = false
	assert_eq(Targeting.target_choices(f, h, punch), [["z2"]] as Array[Array])


func test_ranged_hits_any_row() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 2, skills)
	var f := _field([h, UnitFactory.from_enemy("zombie", "z1", 0), UnitFactory.from_enemy("zombie", "z2", 2)])
	assert_eq(Targeting.target_choices(f, h, BattleData.skill("pistol_shot")).size(), 2)


func test_row_and_all_targets() -> void:
	var skills: Array[String] = ["grenade", "encourage"]
	var h := _human("h", 1, skills, {"grenade": 1})
	var h2 := _human("h2", 0, skills)
	var f := _field([h, h2, UnitFactory.from_enemy("zombie", "z1", 0), UnitFactory.from_enemy("zombie", "z2", 0), UnitFactory.from_enemy("zombie", "z3", 2)])
	assert_eq(Targeting.target_choices(f, h, BattleData.skill("grenade")), [["z1", "z2"], ["z3"]] as Array[Array])
	assert_eq(Targeting.target_choices(f, h, BattleData.skill("encourage")), [["h", "h2"]] as Array[Array])


func test_user_row_restriction() -> void:
	var skills: Array[String] = ["punch"]
	var h := _human("h", 2, skills)
	var f := _field([h, UnitFactory.from_enemy("zombie", "z1", 0)])
	assert_false(Targeting.usable(f, h, "punch"))
	h.row = 1
	assert_true(Targeting.usable(f, h, "punch"))


func test_cost_and_cooldown() -> void:
	var skills: Array[String] = ["grenade", "encourage"]
	var h := _human("h", 1, skills)
	var f := _field([h, UnitFactory.from_enemy("zombie", "z1", 0)])
	assert_false(Targeting.usable(f, h, "grenade"))
	h.resources["grenade"] = 1
	assert_true(Targeting.usable(f, h, "grenade"))
	assert_true(Targeting.usable(f, h, "encourage"))
	h.cooldowns["encourage"] = 2
	assert_false(Targeting.usable(f, h, "encourage"))


func test_legal_actions_order() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 1, skills)
	var f := _field([h, UnitFactory.from_enemy("zombie", "z1", 0)])
	var actions := Targeting.legal_actions(f, h, true)
	assert_eq(actions[0], {"type": "skill", "skill": "pistol_shot", "targets": ["z1"]})
	assert_eq(actions[1], {"type": "move", "row": 0})
	assert_eq(actions[2], {"type": "move", "row": 2})
	assert_eq(actions[3], {"type": "defend"})
	assert_eq(actions[4], {"type": "retreat"})
	assert_eq(actions.size(), 5)
	assert_false(Targeting.legal_actions(f, h, false).has({"type": "retreat"}))


## 基因锁二阶起才能主动开启，已经开着就不能再开。
func test_gene_lock_action() -> void:
	var skills: Array[String] = []
	var h := _human("h", 0, skills)
	var f := _field([h, UnitFactory.from_enemy("zombie", "z1", 0)])
	h.gene_lock_stage = 1
	assert_false(Targeting.legal_actions(f, h, false).has({"type": "gene_lock"}))
	h.gene_lock_stage = 2
	assert_true(Targeting.legal_actions(f, h, false).has({"type": "gene_lock"}))
	Statuses.apply(h, "gene_lock")
	assert_false(Targeting.legal_actions(f, h, false).has({"type": "gene_lock"}))


func test_is_legal() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 0, skills)
	var f := _field([h, UnitFactory.from_enemy("zombie", "z1", 0)])
	assert_true(Targeting.is_legal(f, h, {"type": "skill", "skill": "pistol_shot", "targets": ["z1"]}, false))
	assert_false(Targeting.is_legal(f, h, {"type": "skill", "skill": "pistol_shot", "targets": ["h"]}, false))
	assert_false(Targeting.is_legal(f, h, {"type": "skill", "skill": "punch", "targets": ["z1"]}, false))
