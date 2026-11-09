extends RefCounted
## 兑换目录（data/hub/exchange_catalog.json）。每一项：名字、大类、系列、价格、效果积木，以及前置、能量要求、素质门槛、是否血统、是否消耗品。
## 大类：tech（科技）、magic（魔法传说）、enhance（强化：血统、内功、技能）、item（道具与消耗品）。
## 目录里写的价格必须和定价公式算出来的一致（原著价格就是这样被锁住的）。
## 按系列拆文件（设计规格 7.2）：主文件放原著锚点条目，"includes" 列出 data/hub/catalog/ 下按系列分的文件，加载时合并；id 不许重复。
## 每一项都要真能用：技能积木对应战斗技能；消耗品要有技能会用掉它；要求的能量要有条目能提供。

const DataLoader = preload("res://core/util/data_loader.gd")
const BattleData = preload("res://core/battle/battle_data.gd")
const Pricing = preload("res://core/hub/pricing.gd")

const PATH := "res://data/hub/exchange_catalog.json"
const REQUIRED: Array[String] = ["name", "category", "series", "price", "blocks"]
const CATEGORIES: Array[String] = ["tech", "magic", "enhance", "item"]
const BLOCK_KINDS: Array[String] = ["attr", "energy", "skill", "ability", "passive", "item", "side_effect"]
## 不靠技能、自己起作用的道具（重生十字章在战斗里自动复活）。
const PASSIVE_ITEMS: Array[String] = ["rebirth_cross"]

static var _cache: Dictionary = {}


## 合并时发现的重复 id（validate 报告）。
static var _duplicates: Array[String] = []


static func entries() -> Dictionary:
	if _cache.is_empty():
		var res := DataLoader.load_json(PATH)
		assert(res.ok, res.error)
		var merged: Dictionary = (res.data["entries"] as Dictionary).duplicate()
		for path: String in res.data.get("includes", []):
			var part := DataLoader.load_json(path)
			assert(part.ok, part.error)
			for id: String in part.data["entries"]:
				if merged.has(id):
					_duplicates.append(id)
				merged[id] = part.data["entries"][id]
		_cache = merged
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
	for id in _duplicates:
		errors.append("兑换项 %s 在多个目录文件里重复" % id)
	var consumed := {}
	for s_id: String in BattleData.skills():
		for k: String in BattleData.skill(s_id).get("cost", {}):
			consumed[k] = true
	var pools := {}
	for id: String in entries():
		for b: Dictionary in entries()[id]["blocks"]:
			if b.has("energy"):
				pools[String(b["energy"])] = true
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
			if b.has("item") and not consumed.has(String(b["item"])) and not PASSIVE_ITEMS.has(String(b["item"])):
				errors.append("兑换项 %s 的道具 %s 没有任何技能用得上" % [id, b["item"]])
			if Pricing.parse_tier(String(b.get("tier", "")))["grade"] == "?":
				errors.append("兑换项 %s 的 tier 写法无效" % id)
		var need := String(e.get("requires_energy", ""))
		if need != "" and not pools.has(need):
			errors.append("兑换项 %s 要求的能量 %s 没有条目提供" % [id, need])
		var expected := Pricing.price(e)
		var listed: Dictionary = e["price"]
		if int(listed["points"]) != int(expected["points"]) or String(listed["tier"]) != String(expected["tier"]):
			errors.append("兑换项 %s 的价格 %s 和公式 %s 不一致" % [id, listed, expected])
		if int(expected["points"]) < 0:
			errors.append("兑换项 %s 的点数为负" % id)
	return errors
