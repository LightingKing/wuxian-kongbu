extends RefCounted
## 六项基础属性（原著）：智力、精神力、细胞活力、神经反应速度、肌肉组织强度、免疫力强度。常人各约 100。
## base = 自身（天生 + 锻炼，主神评价看不见锻炼部分）；enhanced = 在主神处兑换来的强化量（10 点奖励点数 = 1 点）。
## enhanced_high = B 级及以上兑换项带来的属性，按基因锁发挥率 high_mult 打折（设计规格 3.4），由角色按基因锁阶数设置。

const KEYS: Array[String] = ["intelligence", "spirit", "cell_vitality", "nerve_reaction", "muscle", "immunity"]

var base: Dictionary = {}
var enhanced: Dictionary = {}
var enhanced_high: Dictionary = {}
var high_mult: float = 1.0


func _init(values: Dictionary = {}) -> void:
	for k in KEYS:
		base[k] = float(values.get(k, 100.0))
		enhanced[k] = 0.0
		enhanced_high[k] = 0.0


func total(key: String) -> float:
	return float(base[key]) + float(enhanced[key]) + float(enhanced_high[key]) * high_mult


func add_enhanced(key: String, amount: float) -> void:
	enhanced[key] = float(enhanced[key]) + amount


func add_enhanced_high(key: String, amount: float) -> void:
	enhanced_high[key] = float(enhanced_high[key]) + amount


func add_trained(key: String, amount: float) -> void:
	base[key] = float(base[key]) + amount


func to_dict() -> Dictionary:
	return {"base": base.duplicate(), "enhanced": enhanced.duplicate(), "enhanced_high": enhanced_high.duplicate()}


func load_dict(d: Dictionary) -> void:
	var high: Dictionary = d.get("enhanced_high", {})
	for k in KEYS:
		base[k] = float(d["base"][k])
		enhanced[k] = float(d["enhanced"][k])
		enhanced_high[k] = float(high.get(k, 0.0))
