extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
const BattleData = preload("res://core/battle/battle_data.gd")
const CombatMath = preload("res://core/battle/combat_math.gd")
const Statuses = preload("res://core/battle/statuses.gd")


func _human(muscle: float = 100.0) -> RefCounted:
	var ch := Character.new("h", "新人", {"muscle": muscle})
	var skills: Array[String] = []
	return UnitFactory.from_character(ch, "ally", 0, skills)


func test_pistol_vs_zombie() -> void:
	var dmg := CombatMath.damage(_human(), UnitFactory.from_enemy("zombie", "z", 0), BattleData.skill("pistol_shot"), 0.5)
	assert_almost(dmg, 16.0)


## 原著：手枪对爬行者几乎无效。
func test_pistol_vs_licker_nearly_useless() -> void:
	var licker := UnitFactory.from_enemy("licker", "l", 0)
	assert_almost(CombatMath.damage(_human(), licker, BattleData.skill("pistol_shot"), 0.5), 2.0)
	assert_almost(CombatMath.damage(_human(), licker, BattleData.skill("grenade"), 0.5), 45.0)


func test_muscle_scales_melee_only() -> void:
	var z := UnitFactory.from_enemy("zombie", "z", 0)
	var strong := _human(150.0)
	assert_almost(CombatMath.damage(strong, z, BattleData.skill("punch"), 0.5), 12.0)
	assert_almost(CombatMath.damage(strong, z, BattleData.skill("pistol_shot"), 0.5), 16.0)


func test_variance_bounds() -> void:
	var z := UnitFactory.from_enemy("zombie", "z", 0)
	var skill := BattleData.skill("desert_eagle")
	assert_almost(CombatMath.damage(_human(), z, skill, 0.0), 27.0)
	assert_almost(CombatMath.damage(_human(), z, skill, 1.0), 33.0)


func test_defend_and_gene_lock() -> void:
	var z := UnitFactory.from_enemy("zombie", "z", 0)
	var h := _human()
	var bite := BattleData.skill("zombie_bite")
	Statuses.apply(h, "defending")
	assert_almost(CombatMath.damage(z, h, bite, 0.5), 9.0)
	Statuses.apply(h, "gene_lock")
	assert_almost(CombatMath.damage(h, z, BattleData.skill("pistol_shot"), 0.5), 24.0)


func test_non_damage_skill() -> void:
	assert_almost(CombatMath.damage(_human(), _human(), BattleData.skill("first_aid_spray"), 0.5), 0.0)


func test_hit_chance_uses_speed_difference() -> void:
	var h := _human()
	var pistol := BattleData.skill("pistol_shot")
	assert_almost(CombatMath.hit_chance(h, UnitFactory.from_enemy("zombie", "z", 0), pistol, false), 0.86)
	assert_almost(CombatMath.hit_chance(h, UnitFactory.from_enemy("licker", "l", 0), pistol, false), 0.76)


## 黑暗中人类命中下降，爬行者靠热感和嗅觉，不受影响。
func test_darkness() -> void:
	var h := _human()
	var licker := UnitFactory.from_enemy("licker", "l", 0)
	assert_almost(CombatMath.hit_chance(h, licker, BattleData.skill("pistol_shot"), true), 0.51)
	var claw := BattleData.skill("licker_claw")
	assert_almost(CombatMath.hit_chance(licker, h, claw, true), CombatMath.hit_chance(licker, h, claw, false))


func test_hit_chance_clamped_and_auto_hit() -> void:
	var h := _human()
	var z := UnitFactory.from_enemy("zombie", "z", 0)
	Statuses.apply(h, "blind")
	h.base_speed = 1.0
	assert_almost(CombatMath.hit_chance(h, z, BattleData.skill("pistol_shot"), true), 0.05)
	assert_almost(CombatMath.hit_chance(h, h, BattleData.skill("first_aid_spray"), true), 1.0)
