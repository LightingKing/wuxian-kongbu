extends "res://tests/test_case.gd"

const Attributes = preload("res://core/model/attributes.gd")
const Character = preload("res://core/model/character.gd")
const GameState = preload("res://core/model/game_state.gd")


## B 级及以上兑换来的属性按基因锁发挥率打折：0 阶 50%，四阶 100%（设计规格 3.4）。
func test_high_grade_attributes_scaled_by_gene_lock() -> void:
	var c := Character.new("zz", "郑吒", {})
	c.attributes.add_enhanced_high("muscle", 100.0)
	c.attributes.add_enhanced("muscle", 10.0)
	assert_almost(c.attributes.total("muscle"), 100.0 + 10.0 + 50.0)
	c.gene_lock_stage = 1
	assert_almost(c.attributes.total("muscle"), 100.0 + 10.0 + 70.0)
	c.gene_lock_stage = 4
	assert_almost(c.attributes.total("muscle"), 210.0)


func test_attributes_round_trip_with_high() -> void:
	var a := Attributes.new()
	a.add_enhanced_high("nerve_reaction", 100.0)
	var b := Attributes.new()
	b.load_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	assert_almost(float(b.enhanced_high["nerve_reaction"]), 100.0)


## 计划 1 的旧存档没有 enhanced_high，读取时按 0 处理。
func test_old_attribute_save_loads() -> void:
	var a := Attributes.new()
	a.load_dict({"base": a.base.duplicate(), "enhanced": a.enhanced.duplicate()})
	assert_almost(a.total("spirit"), 100.0)


func test_character_new_fields_round_trip() -> void:
	var c := Character.new("zz", "郑吒", {})
	c.owned.append("qigong_low")
	c.skills.append("desert_eagle")
	c.abilities.append("red_flame")
	c.proficiency["desert_eagle"] = 0.5
	c.energy["neili"] = 30.0
	c.items["grenade"] = 2.0
	c.gene_lock_stage = 2
	var d := Character.new()
	d.load_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(d.owned, ["qigong_low"] as Array[String])
	assert_eq(d.skills, ["desert_eagle"] as Array[String])
	assert_eq(d.abilities, ["red_flame"] as Array[String])
	assert_almost(float(d.proficiency["desert_eagle"]), 0.5)
	assert_almost(float(d.energy["neili"]), 30.0)
	assert_almost(float(d.items["grenade"]), 2.0)
	assert_almost(d.attributes.high_mult, 0.85)


func test_battle_resources() -> void:
	var c := Character.new("zz", "郑吒", {})
	c.energy["neili"] = 30.0
	c.items["grenade"] = 2.0
	assert_eq(c.battle_resources(), {"neili": 30.0, "grenade": 2.0})


func test_companions_saved() -> void:
	var g := GameState.new(1)
	g.companions.append({"id": "loli", "name": "萝丽", "creator": "zheng_zha", "attributes": {}})
	var h := GameState.new(2)
	h.load_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	assert_eq(h.companions[0]["name"], "萝丽")
