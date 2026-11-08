extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
const Battlefield = preload("res://core/battle/battlefield.gd")
const UtilityAi = preload("res://core/battle/utility_ai.gd")
const Statuses = preload("res://core/battle/statuses.gd")


func _human(id: String, row: int, skills: Array[String], resources: Dictionary = {}) -> RefCounted:
	return UnitFactory.from_character(Character.new(id, id, {}), "ally", row, skills, "ai", resources)


func _field(units: Array[RefCounted]) -> RefCounted:
	var f := Battlefield.new()
	for u in units:
		f.add(u)
	return f


## 丧尸偏好咬已经受伤的人（设计规格 4.6）。
func test_zombie_bites_wounded() -> void:
	var none: Array[String] = []
	var a := _human("a", 0, none)
	var b := _human("b", 0, none)
	b.hp -= 10.0
	var z := UnitFactory.from_enemy("zombie", "z", 0)
	var f := _field([a, b, z])
	var action := UtilityAi.choose(f, z, false, false)
	assert_eq(action, {"type": "skill", "skill": "zombie_bite", "targets": ["b"]})


func test_prefers_killing_blow() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 0, skills)
	var z1 := UnitFactory.from_enemy("zombie", "z1", 0)
	var z2 := UnitFactory.from_enemy("zombie", "z2", 1)
	z2.hp = 10.0
	var f := _field([h, z1, z2])
	assert_eq(UtilityAi.choose(f, h, false, false)["targets"], ["z2"])


func test_heals_badly_hurt_ally() -> void:
	var skills: Array[String] = ["pistol_shot", "first_aid_spray"]
	var medic := _human("medic", 1, skills, {"spray": 1})
	var none: Array[String] = []
	var hurt := _human("hurt", 0, none)
	hurt.hp = 30.0
	var f := _field([medic, hurt, UnitFactory.from_enemy("zombie", "z1", 0)])
	assert_eq(UtilityAi.choose(f, medic, false, false), {"type": "skill", "skill": "first_aid_spray", "targets": ["hurt"]})


func test_cures_infection() -> void:
	var skills: Array[String] = ["pistol_shot", "antidote"]
	var medic := _human("medic", 1, skills, {"antidote": 1})
	var none: Array[String] = []
	var bitten := _human("bitten", 0, none)
	Statuses.apply(bitten, "infection")
	var f := _field([medic, bitten, UnitFactory.from_enemy("zombie", "z1", 0)])
	assert_eq(UtilityAi.choose(f, medic, false, false)["skill"], "antidote")


## 只会近战、够不着的时候往前挪。
func test_melee_unit_moves_forward() -> void:
	var none: Array[String] = []
	var f := _field([_human("a", 0, none), UnitFactory.from_enemy("zombie", "z", 2)])
	var z: RefCounted = f.get_unit("z")
	assert_eq(UtilityAi.choose(f, z, false, false), {"type": "move", "row": 1})


func test_licker_targets_threat() -> void:
	var none: Array[String] = []
	var weak := _human("weak", 0, none)
	var strong := UnitFactory.from_character(Character.new("strong", "strong", {"muscle": 200}), "ally", 0, none)
	var licker := UnitFactory.from_enemy("licker", "l", 0)
	var f := _field([weak, strong, licker])
	assert_eq(UtilityAi.choose(f, licker, false, false)["targets"], ["strong"])


func test_choice_is_deterministic() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 0, skills)
	var f := _field([h, UnitFactory.from_enemy("zombie", "z1", 0), UnitFactory.from_enemy("zombie", "z2", 0)])
	var first := UtilityAi.choose(f, h, false, false)
	for i in 5:
		assert_eq(UtilityAi.choose(f, h, false, false), first)
	assert_eq(first["targets"], ["z1"])


func test_intent_view_levels() -> void:
	var z := UnitFactory.from_enemy("zombie", "z", 0)
	assert_false(bool(UtilityAi.intent_view(z, 2)["known"]))
	z.intent = {"type": "skill", "skill": "zombie_bite", "targets": ["a"]}
	assert_eq(UtilityAi.intent_view(z, 0), {"known": true, "kind": "attack"})
	assert_eq(UtilityAi.intent_view(z, 1), {"known": true, "kind": "attack", "skill": "zombie_bite", "skill_name": "撕咬"})
	assert_eq(UtilityAi.intent_view(z, 2)["targets"], ["a"])
	z.intent = {"type": "move", "row": 1}
	assert_eq(UtilityAi.intent_view(z, 2), {"known": true, "kind": "maneuver"})
