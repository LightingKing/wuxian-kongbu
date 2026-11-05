extends RefCounted
## 核心规则常量（data/rules/core_rules.json）。第一次访问时加载并缓存。

const DataLoader = preload("res://core/util/data_loader.gd")
const PATH := "res://data/rules/core_rules.json"

static var _cache: Dictionary = {}


static func get_rules() -> Dictionary:
	if _cache.is_empty():
		var res := DataLoader.load_json(PATH)
		assert(res.ok, res.error)
		_cache = res.data
	return _cache


static func get_value(section: String, key: String) -> Variant:
	return get_rules()[section][key]
