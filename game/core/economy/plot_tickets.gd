extends RefCounted
## 支线剧情库存（原著）：D < C < B < A < S，1 个高一级 = 3 个低一级（L401）。
## 原著的"双B"指需要 2 个 B，所以库存只按基础等级计数。

const GRADES: Array[String] = ["D", "C", "B", "A", "S"]
const RATIO := 3

var counts: Dictionary = {"D": 0, "C": 0, "B": 0, "A": 0, "S": 0}


func add(grade: String, n: int = 1) -> void:
	assert(GRADES.has(grade), "未知支线等级：" + grade)
	counts[grade] = int(counts[grade]) + n


func has_at_least(grade: String, n: int = 1) -> bool:
	return int(counts[grade]) >= n


func spend(grade: String, n: int = 1) -> bool:
	if not has_at_least(grade, n):
		return false
	counts[grade] = int(counts[grade]) - n
	return true


## 1 个 grade 拆成 3 个低一级；D 不能再拆。
func split(grade: String) -> bool:
	var i := GRADES.find(grade)
	if i <= 0 or not spend(grade, 1):
		return false
	add(GRADES[i - 1], RATIO)
	return true


## 3 个 grade 合成 1 个高一级；S 不能再合。
func merge(grade: String) -> bool:
	var i := GRADES.find(grade)
	if i < 0 or i >= GRADES.size() - 1 or not spend(grade, RATIO):
		return false
	add(GRADES[i + 1], 1)
	return true


func to_dict() -> Dictionary:
	return counts.duplicate()


func load_dict(d: Dictionary) -> void:
	for g in GRADES:
		counts[g] = int(d.get(g, 0))
