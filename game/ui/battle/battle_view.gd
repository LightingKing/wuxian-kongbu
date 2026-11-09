extends RefCounted
## 战斗界面的取数层：把 Battle 的状态整理成单位卡、时间轴和可点的行动列表。
## 界面只调用 act(index)，拿回事件；规则全在 core/battle。

const BattleData = preload("res://core/battle/battle_data.gd")
const EventText = preload("res://ui/event_text.gd")

var b: RefCounted
var names: Dictionary = {}


func _init(battle: RefCounted) -> void:
	b = battle
	for u: RefCounted in b.field.units:
		names[u.id] = u.display_name


func current() -> Dictionary:
	if b.current == null:
		return {}
	return {"id": b.current.id, "name": b.current.display_name}


func finished() -> bool:
	return b.outcome != "ongoing"


func outcome() -> String:
	return b.outcome


func timeline() -> Array[String]:
	var out: Array[String] = []
	for id: String in b.timeline(8):
		out.append(String(names.get(id, id)))
	return out


## 战场上的单位，己方在前、敌方在后；同一边按排、再按 id 排。
func units() -> Array[Dictionary]:
	var list: Array = b.field.units.duplicate()
	list.sort_custom(func(a: RefCounted, c: RefCounted) -> bool:
		if a.side != c.side:
			return a.side == "ally"
		if a.row != c.row:
			return a.row < c.row
		return a.id < c.id)
	var out: Array[Dictionary] = []
	for u: RefCounted in list:
		out.append({
			"id": u.id,
			"name": u.display_name,
			"side": u.side,
			"row": u.row,
			"hp": u.hp,
			"hp_max": u.hp_max,
			"fear": u.fear,
			"alive": u.alive,
			"fled": u.fled,
			"current": b.current != null and b.current.id == u.id,
			"statuses": _status_names(u),
		})
	return out


func _status_names(u: RefCounted) -> Array[String]:
	var out: Array[String] = []
	var all := BattleData.statuses()
	for s: Dictionary in u.statuses:
		var id := String(s["id"])
		out.append(String((all[id] as Dictionary).get("name", id)) if all.has(id) else id)
	return out


## 可点的行动，每项带序号；act(index) 用同一个序号。
func actions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var legal: Array[Dictionary] = b.legal_actions()
	for i in legal.size():
		out.append({"index": i, "label": _label(legal[i])})
	return out


## 同一技能对多个目标时合成一组，界面先选技能再选目标，免得二十个一样的按钮。
func groups() -> Array[Dictionary]:
	var legal: Array[Dictionary] = b.legal_actions()
	var order: Array[String] = []
	var by_key := {}
	for i in legal.size():
		var key := _group_key(legal[i])
		if not by_key.has(key):
			by_key[key] = {"key": key, "label": "", "indices": []}
			order.append(key)
		(by_key[key]["indices"] as Array).append(i)
	var out: Array[Dictionary] = []
	for key in order:
		var g: Dictionary = by_key[key]
		var idx: Array = g["indices"]
		g["label"] = _label(legal[int(idx[0])]) if idx.size() == 1 else "%s（%d 个目标）" % [_skill_name(legal[int(idx[0])]), idx.size()]
		out.append(g)
	return out


func _group_key(a: Dictionary) -> String:
	var t := String(a["type"])
	if t == "skill":
		return "skill:" + String(a["skill"])
	if t == "move":
		return "move:%d" % int(a["row"])
	return t


func _skill_name(a: Dictionary) -> String:
	var skill := String(a.get("skill", ""))
	return String(BattleData.skill(skill).get("name", skill))


func _label(a: Dictionary) -> String:
	var t := String(a["type"])
	match t:
		"skill":
			var title := _skill_name(a)
			var who: Array[String] = []
			for id: String in a.get("targets", []):
				who.append(_target_label(id))
			return "%s → %s" % [title, "、".join(who)] if not who.is_empty() else title
		"move":
			return "换到第 %d 排" % (int(a["row"]) + 1)
		"defend":
			return "防御"
		"gene_lock":
			return "开启基因锁"
		"retreat":
			return "撤退"
	return t


## 目标标签：名字后面加编号和剩余生命，十个丧尸才分得清。
func _target_label(id: String) -> String:
	var name := String(names.get(id, id))
	var tail := id.get_slice("_", id.get_slice_count("_") - 1)
	if tail.is_valid_int():
		name += "#" + tail
	var u: RefCounted = b.field.get_unit(id)
	if u != null:
		name += "（%d）" % int(u.hp)
	return name


func act(index: int) -> Array[Dictionary]:
	var legal: Array[Dictionary] = b.legal_actions()
	if index < 0 or index >= legal.size():
		return []
	return b.act(legal[index])


func log_tail(n: int = 6) -> Array[String]:
	var out: Array[String] = []
	var start := maxi(0, b.history.size() - n)
	for i in range(start, b.history.size()):
		var line := EventText.describe(b.history[i], names)
		if line != "":
			out.append(line)
	return out
