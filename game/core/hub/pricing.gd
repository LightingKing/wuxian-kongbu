extends RefCounted
## 兑换定价公式（设计规格 7.2，核心机制分析 4.4）。兑换项由效果积木组成，公式把积木换算成"价值"，再拆成支线等级和点数。
## 原著规律：
##   - 属性积木：10 点 = 1 点属性；
##   - 无限弹药（unlimited）× 20；
##   - 魔法传说类（magic）× 2（只乘非属性积木）；
##   - 有副作用的打折（side_effect 积木的 discount）；
## 等级 = 积木里最高的 tier（这件东西的"档次"），点数 = 价值 − 所需支线的折算值（D 500、C 1400、B 2400）。
## 折算值用原著三件纯属性的兑换项标定：低级气功 500+D、T 病毒 1500+C、蜘蛛侠基因 2000+B。A、S 的折算值还没有原著锚点，先占位。
## tier 写法："" 不要支线；"D"、"C"、"B"、"A"、"S"；"2B" 表示两个 B（原著的双 B）。

const DataLoader = preload("res://core/util/data_loader.gd")
const Rules = preload("res://core/util/rules.gd")

const RULES_PATH := "res://data/hub/hub_rules.json"
const GRADES: Array[String] = ["D", "C", "B", "A", "S"]

static var _rules: Dictionary = {}


static func rules() -> Dictionary:
	if _rules.is_empty():
		var res := DataLoader.load_json(RULES_PATH)
		assert(res.ok, res.error)
		_rules = res.data
	return _rules


## "2B" → {"grade": "B", "count": 2}；"" → {"grade": "", "count": 0}。写错时 grade 为 "?"。
static func parse_tier(tier: String) -> Dictionary:
	if tier == "":
		return {"grade": "", "count": 0}
	var count := 1
	var grade := tier
	if tier.length() == 2 and tier[0].is_valid_int():
		count = tier[0].to_int()
		grade = tier[1]
	if not GRADES.has(grade) or count < 1:
		return {"grade": "?", "count": 0}
	return {"grade": grade, "count": count}


## 用于比较高低：先比等级，再比个数。
static func tier_rank(tier: String) -> int:
	var t := parse_tier(tier)
	if t["count"] == 0:
		return 0
	return (GRADES.find(String(t["grade"])) + 1) * 10 + int(t["count"])


static func ticket_worth(tier: String) -> float:
	var t := parse_tier(tier)
	if int(t["count"]) == 0:
		return 0.0
	return float(rules()["ticket_value"][t["grade"]]) * int(t["count"])


static func block_value(block: Dictionary, category: String) -> float:
	if block.has("attr"):
		var sum := 0.0
		for k: String in block["attr"]:
			sum += float(block["attr"][k])
		return sum * float(Rules.get_rules()["points_per_attribute"])
	var mult := float(rules()["category_mult"].get(category, 1.0))
	if block.has("item"):
		return float(block["count"]) * float(block["unit_value"]) * mult
	var v := float(block.get("value", 0.0))
	if bool(block.get("unlimited", false)):
		v *= float(rules()["unlimited_mult"])
	return v * mult


static func value(entry: Dictionary) -> float:
	var total := 0.0
	var discount := 1.0
	for b: Dictionary in entry["blocks"]:
		if b.has("side_effect"):
			discount *= float(b["discount"])
		else:
			total += block_value(b, String(entry["category"]))
	return total * discount


## 积木里最高的 tier。
static func tier_of(entry: Dictionary) -> String:
	var best := ""
	for b: Dictionary in entry["blocks"]:
		var t := String(b.get("tier", ""))
		if tier_rank(t) > tier_rank(best):
			best = t
	return best


## 公式算出的价格 {"points": int, "tier": String}。
static func price(entry: Dictionary) -> Dictionary:
	var tier := tier_of(entry)
	return {"points": roundi(value(entry) - ticket_worth(tier)), "tier": tier}
