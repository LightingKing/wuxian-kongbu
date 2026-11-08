extends RefCounted
## 兑换目录（data/hub/exchange_catalog.json）。每一项：名字、大类、系列、价格、效果积木，以及前置、能量要求、素质门槛、是否血统、是否消耗品。
## 大类：tech（科技）、magic（魔法传说）、enhance（强化：血统、内功、技能）、item（道具与消耗品）。
## 目录里写的价格必须和定价公式算出来的一致（原著价格就是这样被锁住的）。

const DataLoader = preload("res://core/util/data_loader.gd")
const BattleData = preload("res://core/battle/battle_data.gd")
const Pricing = preload("res://core/hub/pricing.gd")

const PATH := "res://data/hub/exchange_catalog.json"
const REQUIRED: Array[String] = ["name", "category", "series", "price", "blocks"]
const CATEGORIES: Array[String] = ["tech", "magic", "enhance", "item"]
const BLOCK_KINDS: Array[String] = ["attr", "energy", "skill", "ability", "passive", "item", "side_effect"]

static var _cache: Dictionary = {}


static func entries() -> Dictionary:
	if _cache.is_empty():
		var res := DataLoader.load_json(PATH)
		assert(res.ok, res.error)
		_cache = res.data["entries"]
	return _cache


static func has(id: String) -> bool:
	return entries().has(id)


static func entry(id: String) -> Dictionary:
	return entries()[id]


static func by_category(category: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in entries():
		if entries()[id]["category"] == category:
			out.append(id)
	return out


static func validate() -> Array[String]:
	var errors: Array[String] = []
	for id: String in entries():
		var e: Dictionary = entries()[id]
		var missing := DataLoader.missing_keys(e, REQUIRED, "兑换项 " + id)
		if not missing.is_empty():
			errors.append_array(missing)
			continue
		if not CATEGORIES.has(String(e["category"])):
			errors.append("兑换项 %s 的大类无效" % id)
		for r: String in e.get("requires", []):
			if not has(r):
				errors.append("兑换项 %s 的前置 %s 不存在" % [id, r])
		for b: Dictionary in e["blocks"]:
			var kinds := 0
			for k in BLOCK_KINDS:
				if b.has(k):
					kinds += 1
			if kinds != 1:
				errors.append("兑换项 %s 有一块积木的类型不明确" % id)
			if b.has("skill") and not BattleData.skills().has(String(b["skill"])):
				errors.append("兑换项 %s 的技能 %s 不在战斗技能里" % [id, b["skill"]])
			if Pricing.parse_tier(String(b.get("tier", "")))["grade"] == "?":
				errors.append("兑换项 %s 的 tier 写法无效" % id)
		var expected := Pricing.price(e)
		var listed: Dictionary = e["price"]
		if int(listed["points"]) != int(expected["points"]) or String(listed["tier"]) != String(expected["tier"]):
			errors.append("兑换项 %s 的价格 %s 和公式 %s 不一致" % [id, listed, expected])
		if int(expected["points"]) < 0:
			errors.append("兑换项 %s 的点数为负" % id)
	return errors
