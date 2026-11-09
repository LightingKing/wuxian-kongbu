extends RefCounted
## 存档槽：三个手动位（user://save_1.json ~ save_3.json）+ 一个自动位（user://save_auto.json）。
## 自动位走同一个格式，换地点、战斗后、结算、休整每天由 main 落盘，标题画面可直接继续。
## 标题画面只要摘要，所以 summary() 直接读 JSON 顶层，不重建 Session（不然每次开标题都要加载剧本）。

const SaveService = preload("res://core/save/save_service.gd")
const Session = preload("res://core/session/session.gd")

const COUNT := 3
## 自动存档位，只能读不能手动写（写由 main 在关键节点触发）。
const AUTO := 0
const FILE_FORMAT := "user://save_%d.json"
const AUTO_FILE := "user://save_auto.json"


static func path(slot: int) -> String:
	if slot == AUTO:
		return AUTO_FILE
	return FILE_FORMAT % slot


static func valid(slot: int) -> bool:
	return slot == AUTO or (slot >= 1 and slot <= COUNT)


static func write(slot: int, session: RefCounted) -> Error:
	if not valid(slot) or session == null:
		return ERR_INVALID_PARAMETER
	return SaveService.write_dict(path(slot), session.to_dict())


## 读不到或坏了返回 null。
static func read(slot: int) -> RefCounted:
	if not valid(slot):
		return null
	return Session.load_from(path(slot))


static func erase(slot: int) -> void:
	if not valid(slot):
		return
	if FileAccess.file_exists(path(slot)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path(slot)))


## 标题/暂停菜单用：{"slot", "exists", "phase", "day", "clock", "label", "points", "saved_at"}。
static func summary(slot: int) -> Dictionary:
	if not valid(slot):
		return {"slot": slot, "exists": false, "label": "无效存档位"}
	var d := SaveService.read_dict(path(slot))
	if d.is_empty():
		return {"slot": slot, "exists": false, "label": "空"}
	var ex: Dictionary = d.get("expedition", {})
	return {
		"slot": slot,
		"auto": slot == AUTO,
		"exists": true,
		"phase": String(d.get("phase", "")),
		"day": int(d.get("day", 0)),
		"clock": int(ex.get("clock", 0)),
		"outcome": String(ex.get("outcome", "")),
		"label": _label(d),
		"points": _points(d),
		"saved_at": _time_text(slot),
	}


static func all_summaries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in range(1, COUNT + 1):
		out.append(summary(i))
	return out


static func _label(d: Dictionary) -> String:
	var ex: Dictionary = d.get("expedition", {})
	match String(d.get("phase", "")):
		"expedition":
			return "生化危机一 · 第 %d 分钟" % int(ex.get("clock", 0))
		"settlement":
			return "刚回归 · 待结算"
		"hub":
			return "主神空间 · 第 %d 天" % int(d.get("day", 0))
		"done":
			return "第一部结束"
	return "未知进度"


## 郑吒的点数，给标题画面一点进度感；没有就返回 -1。
static func _points(d: Dictionary) -> int:
	var game: Dictionary = d.get("game", {})
	var chars: Dictionary = game.get("characters", {})
	if not chars.has("zheng_zha"):
		return -1
	return int((chars["zheng_zha"] as Dictionary).get("points", -1))


static func _time_text(slot: int) -> String:
	var t := int(FileAccess.get_modified_time(path(slot)))
	if t <= 0:
		return ""
	var d := Time.get_datetime_dict_from_unix_time(t)
	return "%02d-%02d %02d:%02d" % [int(d["month"]), int(d["day"]), int(d["hour"]), int(d["minute"])]
