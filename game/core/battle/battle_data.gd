extends RefCounted
## 战斗数据：规则常量、技能、状态、敌人（设计规格第 4 节）。第一次访问时加载并缓存。

const DataLoader = preload("res://core/util/data_loader.gd")

const RULES_PATH := "res://data/rules/battle_rules.json"
const SKILLS_PATH := "res://data/battle/skills.json"
const STATUSES_PATH := "res://data/battle/statuses.json"
const ENEMIES_PATH := "res://data/battle/enemies.json"

const SKILL_REQUIRED: Array[String] = ["name", "user_rows", "target_side", "reach", "target_rows", "target_type"]
const STATUS_REQUIRED: Array[String] = ["name", "duration", "stack"]
const ENEMY_REQUIRED: Array[String] = ["name", "hp", "speed", "attack_mult", "skills", "ai"]
const TARGET_SIDES: Array[String] = ["enemy", "ally", "self"]
const TARGET_TYPES: Array[String] = ["single", "row", "all"]
const REACHES: Array[String] = ["melee", "ranged"]
const AI_PROFILES: Array[String] = ["nearest", "weakest", "wounded", "threat"]

static var _cache: Dictionary = {}


static func _load(path: String, section: String) -> Dictionary:
	var key := path + "#" + section
	if not _cache.has(key):
		var res := DataLoader.load_json(path)
		assert(res.ok, res.error)
		_cache[key] = res.data if section == "" else res.data[section]
	return _cache[key]


static func rules() -> Dictionary:
	return _load(RULES_PATH, "")


static func skills() -> Dictionary:
	return _load(SKILLS_PATH, "skills")


static func statuses() -> Dictionary:
	return _load(STATUSES_PATH, "statuses")


static func enemies() -> Dictionary:
	return _load(ENEMIES_PATH, "enemies")


## 消耗品技能（item: true）：身上带着它要用掉的东西，就能在战斗里用。返回带着的东西能解锁的技能 id。
static func item_skills(resources: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for id: String in skills():
		var s: Dictionary = skills()[id]
		if not bool(s.get("item", false)):
			continue
		var ok := not (s.get("cost", {}) as Dictionary).is_empty()
		for k: String in s.get("cost", {}):
			if float(resources.get(k, 0.0)) < float(s["cost"][k]):
				ok = false
		if ok:
			out.append(id)
	return out


static func skill(id: String) -> Dictionary:
	return skills()[id]


static func status(id: String) -> Dictionary:
	return statuses()[id]


static func enemy(id: String) -> Dictionary:
	return enemies()[id]


## 检查数据之间的引用和取值范围，返回错误列表（空表示没有问题）。
static func validate() -> Array[String]:
	var errors: Array[String] = []
	var sk := skills()
	var st := statuses()
	for id: String in sk:
		var s: Dictionary = sk[id]
		errors.append_array(DataLoader.missing_keys(s, SKILL_REQUIRED, "技能 " + id))
		if not TARGET_SIDES.has(String(s.get("target_side", ""))):
			errors.append("技能 %s 的 target_side 无效" % id)
		if not TARGET_TYPES.has(String(s.get("target_type", ""))):
			errors.append("技能 %s 的 target_type 无效" % id)
		if not REACHES.has(String(s.get("reach", ""))):
			errors.append("技能 %s 的 reach 无效" % id)
		for a: Dictionary in s.get("applies", []):
			if not st.has(String(a["status"])):
				errors.append("技能 %s 引用了不存在的状态 %s" % [id, a["status"]])
		for c: String in s.get("cleanse", []):
			if not st.has(c):
				errors.append("技能 %s 引用了不存在的状态 %s" % [id, c])
	for id: String in st:
		errors.append_array(DataLoader.missing_keys(st[id], STATUS_REQUIRED, "状态 " + id))
	var en := enemies()
	for id: String in en:
		var e: Dictionary = en[id]
		errors.append_array(DataLoader.missing_keys(e, ENEMY_REQUIRED, "敌人 " + id))
		for s_id: String in e.get("skills", []):
			if not sk.has(s_id):
				errors.append("敌人 %s 引用了不存在的技能 %s" % [id, s_id])
		if not AI_PROFILES.has(String(e.get("ai", ""))):
			errors.append("敌人 %s 的 ai 无效" % id)
	return errors
