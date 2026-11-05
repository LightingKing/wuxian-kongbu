extends RefCounted
## 带种子的随机数。规则层的所有随机都走这里；存档保存 seed 和 state，读档后序列不变。
## seed/state 是 64 位整数，JSON 的 double 存不下，所以序列化成字符串。

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value


func randf() -> float:
	return _rng.randf()


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func chance(probability: float) -> bool:
	return _rng.randf() < probability


func to_dict() -> Dictionary:
	return {"seed": str(_rng.seed), "state": str(_rng.state)}


func load_dict(d: Dictionary) -> void:
	_rng.seed = String(d["seed"]).to_int()
	_rng.state = String(d["state"]).to_int()
