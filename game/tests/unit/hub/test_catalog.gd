extends "res://tests/test_case.gd"

const Catalog = preload("res://core/hub/catalog.gd")


func test_catalog_valid() -> void:
	var errors := Catalog.validate()
	assert_eq(errors.size(), 0, "\n".join(errors))


## 设计规格 9.6 的 M1 首批清单都在目录里。
func test_m1_first_batch_present() -> void:
	for id in ["qigong_low", "vampire_baron", "qigong_mid", "vampire_viscount", "t_virus", "spider_gene", "qigong_high", "werewolf_high", "vampire_count", "na_ring", "desert_eagle", "grenade", "first_aid_spray", "antidote"]:
		assert_true(Catalog.has(id), id)


## 原著：高级需要同系低级作前置。
func test_prerequisite_chains() -> void:
	assert_eq(Catalog.entry("qigong_high")["requires"], ["qigong_mid"])
	assert_eq(Catalog.entry("vampire_count")["requires"], ["vampire_viscount"])
	assert_eq(Catalog.entry("na_ring")["requires_energy"], "neili")


func test_by_category() -> void:
	var items := Catalog.by_category("item")
	assert_true(items.has("rebirth_cross"))
	assert_false(items.has("spider_gene"))
	assert_true(Catalog.by_category("magic").has("na_ring"))
