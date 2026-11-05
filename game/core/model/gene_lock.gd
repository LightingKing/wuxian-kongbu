extends RefCounted
## 基因锁阶数 0~5（原著）。发挥率只作用于 B 级及以上兑换项的效果强度（设计规格 3.4）。

const Rules = preload("res://core/util/rules.gd")
const MAX_STAGE := 5


static func effectiveness(stage: int) -> float:
	var table: Array = Rules.get_rules()["gene_lock_effectiveness"]
	return float(table[clampi(stage, 0, MAX_STAGE)])
