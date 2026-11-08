extends "res://tests/test_case.gd"

const BattleData = preload("res://core/battle/battle_data.gd")


func test_all_data_valid() -> void:
	var errors := BattleData.validate()
	assert_eq(errors.size(), 0, str(errors))


func test_m1_enemies_present() -> void:
	for id in ["zombie", "zombie_dog", "licker"]:
		assert_true(BattleData.enemies().has(id), id)


## 原著：爬行者是精英，手枪几乎无效。
func test_licker_resists_bullets() -> void:
	var licker := BattleData.enemy("licker")
	assert_almost(float(licker["tag_mult"]["bullet"]), 0.15)
	assert_true((licker["flags"] as Array).has("ignores_darkness"))


## 原著：被丧尸咬到会感染。
func test_zombie_bite_infects() -> void:
	var applies: Array = BattleData.skill("zombie_bite")["applies"]
	assert_eq(String(applies[0]["status"]), "infection")


func test_rules_values() -> void:
	var r := BattleData.rules()
	assert_eq(int(r["rows"]), 3)
	assert_eq(int(r["row_capacity_default"]), 4)
	assert_eq(int(r["ctb_base_delay"]), 10000)
