extends "res://tests/test_case.gd"

const Pricing = preload("res://core/hub/pricing.gd")
const Catalog = preload("res://core/hub/catalog.gd")

## 原著出现过的价格（mechanics.md 第 3.3、4 节）。公式必须从积木把它们算对。
const NOVEL_PRICES := {
	"qigong_low": [500, "D"],
	"qigong_mid": [1200, "C"],
	"qigong_high": [2500, "B"],
	"vampire_baron": [800, "D"],
	"vampire_viscount": [1500, "C"],
	"vampire_count": [3000, "B"],
	"spider_gene": [2000, "B"],
	"t_virus": [1500, "C"],
	"werewolf_high": [2700, "B"],
	"eagle_eye": [1000, "C"],
	"elf_wind_archer": [2000, "C"],
	"red_flame": [2000, "C"],
	"light_kungfu": [2000, "C"],
	"mind_scan": [4000, "C"],
	"mind_focus": [2500, "B"],
	"desert_eagle": [100, ""],
	"gauss_pistol": [1500, "D"],
	"gauss_sniper": [5000, "D"],
	"shield_plate": [1500, "D"],
	"na_ring": [1500, "D"],
	"purifying_sword": [1000, ""],
	"bingning_dan": [1000, "D"],
	"rebirth_cross": [7000, "2B"],
}


func test_novel_prices() -> void:
	for id: String in NOVEL_PRICES:
		var p := Pricing.price(Catalog.entry(id))
		assert_eq(p, {"points": int(NOVEL_PRICES[id][0]), "tier": String(NOVEL_PRICES[id][1])}, id)


## 10 点 = 1 点属性。
func test_attribute_rate() -> void:
	var e := {"category": "enhance", "blocks": [{"attr": {"muscle": 30, "spirit": 20}}]}
	assert_almost(Pricing.value(e), 500.0)
	assert_eq(Pricing.price(e), {"points": 500, "tier": ""})


## 魔法传说类约为科技类的 2 倍；属性积木不翻倍。
func test_magic_doubles() -> void:
	var tech := {"category": "tech", "blocks": [{"passive": "x", "value": 600}]}
	var magic := {"category": "magic", "blocks": [{"passive": "x", "value": 600}, {"attr": {"spirit": 10}}]}
	assert_almost(Pricing.value(tech), 600.0)
	assert_almost(Pricing.value(magic), 1300.0)


## 无限弹药是有限版的 20 倍。
func test_unlimited_ammo() -> void:
	var limited := {"category": "tech", "blocks": [{"ability": "missile", "value": 50}]}
	var unlimited := {"category": "tech", "blocks": [{"ability": "missile", "value": 50, "unlimited": true}]}
	assert_almost(Pricing.value(unlimited), Pricing.value(limited) * 20.0)


func test_side_effect_discount() -> void:
	var e := {"category": "enhance", "blocks": [{"passive": "rage", "value": 3000}, {"side_effect": "berserk", "discount": 0.8}]}
	assert_almost(Pricing.value(e), 2400.0)


func test_tier_parsing() -> void:
	assert_eq(Pricing.parse_tier("2B"), {"grade": "B", "count": 2})
	assert_eq(Pricing.parse_tier("D"), {"grade": "D", "count": 1})
	assert_eq(Pricing.parse_tier(""), {"grade": "", "count": 0})
	assert_eq(Pricing.parse_tier("Z")["grade"], "?")
	assert_true(Pricing.tier_rank("2B") > Pricing.tier_rank("B"))
	assert_true(Pricing.tier_rank("A") > Pricing.tier_rank("2B"))
	assert_almost(Pricing.ticket_worth("2B"), 4800.0)


## 等级取积木里最高的档次。
func test_tier_is_highest_block() -> void:
	var e := {"category": "enhance", "blocks": [{"passive": "a", "value": 1000, "tier": "D"}, {"passive": "b", "value": 2000, "tier": "C"}]}
	assert_eq(Pricing.tier_of(e), "C")
	assert_eq(Pricing.price(e), {"points": 1600, "tier": "C"})
