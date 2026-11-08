extends RefCounted
## 三排战场（设计规格 4.1）：敌我各有前（0）、中（1）、后（2）三排，每排容量由战斗决定。
## 大型单位占多个格（size）。最前面还有人的那一排算"前排"：前排打空了，中排就顶上来。

const BattleData = preload("res://core/battle/battle_data.gd")

var capacity: int = 4
var rows: int = 3
## 全部单位，按加入顺序；行动顺序打平时按这个顺序。
var units: Array[RefCounted] = []


func _init(row_capacity: int = -1) -> void:
	var r := BattleData.rules()
	rows = int(r["rows"])
	capacity = row_capacity if row_capacity > 0 else int(r["row_capacity_default"])


static func opponent(side: String) -> String:
	return "enemy" if side == "ally" else "ally"


func used(side: String, row: int) -> int:
	var n := 0
	for u in units:
		if u.side == side and u.row == row and u.in_play():
			n += u.size
	return n


func can_place(side: String, row: int, size: int) -> bool:
	return row >= 0 and row < rows and used(side, row) + size <= capacity


func add(u: RefCounted) -> bool:
	if not can_place(u.side, u.row, u.size):
		return false
	units.append(u)
	return true


func get_unit(id: String) -> RefCounted:
	for u in units:
		if u.id == id:
			return u
	return null


func side_units(side: String) -> Array[RefCounted]:
	var out: Array[RefCounted] = []
	for u in units:
		if u.side == side and u.in_play():
			out.append(u)
	return out


func row_units(side: String, row: int) -> Array[RefCounted]:
	var out: Array[RefCounted] = []
	for u in units:
		if u.side == side and u.row == row and u.in_play():
			out.append(u)
	return out


## 该方最前面还有人的一排；整方都没人时返回 -1。
func front_row(side: String) -> int:
	for r in rows:
		if not row_units(side, r).is_empty():
			return r
	return -1


## 换位：只能移到相邻的一排，并且那一排放得下。
func move(u: RefCounted, to_row: int) -> bool:
	if absi(to_row - u.row) != 1 or not can_place(u.side, to_row, u.size):
		return false
	u.row = to_row
	return true
