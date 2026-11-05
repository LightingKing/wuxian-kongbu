extends "res://tests/test_case.gd"

const Attributes = preload("res://core/model/attributes.gd")
const DerivedStats = preload("res://core/model/derived_stats.gd")
const GeneLock = preload("res://core/model/gene_lock.gd")


func test_default_is_human_baseline() -> void:
	var a := Attributes.new()
	for k in Attributes.KEYS:
		assert_almost(a.total(k), 100.0, 0.0001, k)


func test_enhanced_adds_to_total() -> void:
	var a := Attributes.new({"muscle": 112})
	a.add_enhanced("muscle", 190)
	assert_almost(a.total("muscle"), 302.0)


func test_derived_for_ordinary_human() -> void:
	var s := DerivedStats.compute(Attributes.new())
	assert_almost(s.hp_max, 140.0)
	assert_almost(s.speed, 100.0)
	assert_almost(s.attack_mult, 1.0)


func test_derived_for_zheng_zha_after_first_rest() -> void:
	# 原著 L605：郑吒第一次休整后为 智187 精232 细胞321 神经287 肌肉302 免疫331
	var a := Attributes.new({"intelligence": 187, "spirit": 232, "cell_vitality": 321, "nerve_reaction": 287, "muscle": 302, "immunity": 331})
	var s := DerivedStats.compute(a)
	assert_almost(s.hp_max, 40.0 + 0.6 * 321.0 + 0.4 * 302.0)
	assert_almost(s.speed, 287.0)
	assert_almost(s.attack_mult, 3.02)


func test_gene_lock_effectiveness_table() -> void:
	assert_almost(GeneLock.effectiveness(0), 0.5)
	assert_almost(GeneLock.effectiveness(4), 1.0)
	assert_almost(GeneLock.effectiveness(9), 1.0, 0.0001, "超出上限按第五阶")
	assert_almost(GeneLock.effectiveness(-1), 0.5, 0.0001, "低于下限按 0 阶")


func test_round_trip() -> void:
	var a := Attributes.new({"spirit": 122})
	a.add_enhanced("spirit", 110)
	var b := Attributes.new()
	b.load_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	assert_almost(b.total("spirit"), 232.0)
