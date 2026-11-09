extends "res://tests/test_case.gd"

const Session = preload("res://core/session/session.gd")
const ExpeditionView = preload("res://ui/expedition/expedition_view.gd")
const BattleView = preload("res://ui/battle/battle_view.gd")
const Character = preload("res://core/model/character.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
const Battle = preload("res://core/battle/battle.gd")
const Rng = preload("res://core/util/rng.gd")


func _view() -> RefCounted:
	var s := Session.new()
	s.start_m1(1)
	var names := {}
	for id: String in s.game.characters:
		names[id] = s.game.characters[id].display_name
	return ExpeditionView.new(s.expedition, names)


func _names(v: RefCounted) -> Dictionary:
	var out := {}
	for m: Dictionary in v.members():
		out[m["id"]] = m["name"]
	return out


## 地图：8 个地点都有坐标；起点在车厢，大厅相邻，激光通道不直接相邻。
func test_map() -> void:
	var v := _view()
	var m: Array[Dictionary] = v.map()
	assert_eq(m.size(), 8)
	var by_id := {}
	for item: Dictionary in m:
		by_id[item["id"]] = item
	assert_true(by_id["car"]["here"])
	assert_true(by_id["hall"]["adjacent"])
	assert_false(by_id["laser"]["adjacent"])
	assert_eq(by_id["control"]["pos"], Vector2(700, 280))
	assert_false(by_id["stairs"]["searched"])
	assert_true(by_id["stairs"]["dark"])


func test_watch_and_members() -> void:
	var v := _view()
	var w: Dictionary = v.watch()
	assert_eq(w["remaining_minutes"], 187)
	assert_true(String(w["main_task"]).contains("3 小时"))
	assert_eq(w["tether"], "")
	assert_eq(v.members().size(), 7)
	assert_eq(v.pending()["kind"], "choice")
	assert_eq(v.pending()["options"].size(), 3)


## 走到大厅：雇佣兵登场、绑定生效，事件流里有对话。
func test_move_and_tether() -> void:
	var v := _view()
	v.choose("listen")
	var events: Array[Dictionary] = v.move("hall")
	assert_eq(v.location(), "hall")
	assert_true(v.watch()["tether"].contains("马修"))
	var log: Array[String] = v.log_tail(12)
	assert_true("\n".join(log).contains("马修·艾迪森"))
	assert_true(events.size() > 0)
	assert_false(v.can_move("laser"))


## 战斗视图：单位卡、时间轴、行动列表、打完有结果。
func test_battle_view() -> void:
	var hero := Character.new("hero", "英雄", {})
	var units: Array[RefCounted] = [
		UnitFactory.from_character(hero, "ally", 0, ["punch"], "player"),
		UnitFactory.from_enemy("zombie", "zombie_1", 0),
	]
	var b := Battle.new()
	b.setup(units, {}, Rng.new(3))
	var bv := BattleView.new(b)
	assert_eq(bv.units().size(), 2)
	assert_eq(bv.timeline().size(), 8)
	assert_true(bv.current().has("name"))
	var acts: Array[Dictionary] = bv.actions()
	assert_true(acts.size() > 0)
	assert_true(String(acts[0]["label"]).contains("拳脚"))
	var guard := 0
	while not bv.finished() and guard < 50:
		var list: Array[Dictionary] = bv.actions()
		if list.is_empty():
			break
		bv.act(0)
		guard += 1
	assert_true(bv.finished())
	assert_true(bv.log_tail(10).size() > 0)


## 不听指挥的队友（AI 接管）在单位卡的状态里第一个标出来。
func test_battle_view_marks_disobedient() -> void:
	var hero := Character.new("hero", "英雄", {})
	var mate := Character.new("mate", "队友", {})
	var units: Array[RefCounted] = [
		UnitFactory.from_character(hero, "ally", 0, ["punch"], "player"),
		UnitFactory.from_character(mate, "ally", 0, ["punch"], "ai"),
		UnitFactory.from_enemy("zombie", "zombie_1", 0),
	]
	var b := Battle.new()
	b.setup(units, {}, Rng.new(3))
	var bv := BattleView.new(b)
	for u: Dictionary in bv.units():
		if String(u["id"]) == "mate":
			assert_eq(String((u["statuses"] as Array)[0]), "不听指挥")
		elif String(u["id"]) == "hero":
			assert_false((u["statuses"] as Array).has("不听指挥"))
