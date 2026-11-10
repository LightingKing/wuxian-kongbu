extends "res://tests/test_case.gd"
## RPG 式探索：地图数据、门与入口、寻路；场景里台词进对话框、选择弹窗口、走动、进门、搜索、说话、黑暗。

const FieldMap = preload("res://ui/field/field_map.gd")
const FieldScreen = preload("res://ui/field/field_screen.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const Session = preload("res://core/session/session.gd")

const MAPS := "res://data/maps/biohazard1.json"
const SCENARIO := "res://data/scenarios/biohazard1/scenario.json"


func _screen(seed_value: int = 1) -> Control:
	var s := Session.new()
	s.start_m1(seed_value)
	var names := {}
	for id: String in s.game.characters:
		names[id] = s.game.characters[id].display_name
	var f := FieldScreen.new()
	f.setup(s.expedition, names)
	return f


## 八个地点都有图；门只通向剧本里相邻的地点，相邻的地点都有门；入口、柜子、站位都走得到。
func test_maps_valid() -> void:
	var errors := FieldMap.validate(MAPS, Scenario.load_file(SCENARIO))
	assert_eq(errors.size(), 0, "\n".join(errors))


## 门通向哪、从哪进来站哪；寻路绕开墙和挡路的人。
func test_doors_entries_and_path() -> void:
	var hall: RefCounted = FieldMap.make(MAPS, "hall")
	assert_eq(hall.door_dest(Vector2i(0, 7)), "car")
	assert_eq(hall.door_dest(Vector2i(14, 0)), "stairs")
	assert_eq(hall.door_dest(Vector2i(15, 15)), "sewer")
	assert_eq(hall.door_dest(Vector2i(5, 5)), "")
	assert_eq(hall.entry_cell("car"), Vector2i(1, 7))
	assert_eq(hall.entry_cell("stairs"), Vector2i(14, 1))
	var p: Array[Vector2i] = hall.path(Vector2i(1, 7), Vector2i(14, 1))
	assert_true(p.size() > 0)
	assert_eq(p[p.size() - 1], Vector2i(14, 1))
	for c in p:
		assert_true(hall.walkable(c))
	assert_eq(hall.path(Vector2i(1, 7), Vector2i(0, 0)).size(), 0, "墙走不到")
	var blocked := {Vector2i(2, 7): true}
	for c in hall.path(Vector2i(1, 7), Vector2i(3, 7), blocked):
		assert_false(blocked.has(c), "绕开挡路的人")


## 开局：主角站在车厢开场点；张杰讲规则一句句进对话框；看完弹出选择窗口；选了就收起。
func test_opening_messages_then_choice() -> void:
	var f := _screen()
	assert_eq(f.loc, "car")
	assert_eq(f.cell, Vector2i(3, 7))
	assert_eq(f.player_id, "zheng_zha")
	assert_eq(f.followers.size(), 6)
	assert_true(f.box.visible)
	assert_eq(f.box_name.text, "张杰")
	assert_true(f.box_text.text.contains("菜鸟们"))
	assert_true(f.busy(), "对话没看完不能走")
	var guard := 0
	while f.box.visible and guard < 20:
		f._show_next()
		guard += 1
	assert_true(f.choice_panel.visible)
	assert_true(f.press_choice("listen"))
	assert_false(f.choice_panel.visible)
	f.flush_messages()
	f._show_next()
	assert_false(f.busy())
	f.free()


## 走动：撞墙只转身；往右走一格；进门去大厅（花 10 分钟），站在门里一格；雇佣兵到了，挡着路。
func test_walk_and_door() -> void:
	var f := _screen()
	f.press_choice("listen")
	f.flush_messages()
	f._show_next()
	f.step("up")
	assert_eq(f.cell, Vector2i(3, 6), "往上一格是地面")
	f.step("up")
	f.step("up")
	assert_eq(f.cell, Vector2i(3, 4), "座位之间的空当能走进去")
	f.step("up")
	assert_eq(f.cell, Vector2i(3, 4), "墙挡路")
	assert_eq(f.facing, "up")
	f.step("right")
	assert_eq(f.cell, Vector2i(3, 4), "座位挡路")
	f.step("down")
	f.step("right")
	assert_eq(f.cell, Vector2i(4, 5))
	assert_true(f.press_move("hall"))
	assert_eq(f.loc, "hall")
	assert_eq(f.cell, f.fmap.entry_cell("car"))
	assert_eq(int(f.view.ex.st.clock), 10)
	assert_eq(f.npc_sprites.size(), 7, "雇佣兵在大厅")
	var blocked: Dictionary = f._blocked()
	assert_eq(blocked.size(), 7)
	f.free()


## 对着柜子按确认就搜索；对着剧情人物按确认就说话。
func test_interact_search_and_talk() -> void:
	var f := _screen()
	f.press_choice("listen")
	f.flush_messages()
	f._show_next()
	f.cell = Vector2i(1, 8)
	f.facing = "down"
	f.interact()
	assert_true(f.view.ex.st.searched.has("car"), "车厢搜过了")
	f.flush_messages()
	f._show_next()
	f.press_move("hall")
	f.flush_messages()
	f._show_next()
	var talked: Array = []
	f.talk_requested.connect(func(id: String) -> void: talked.append(id))
	var mc: Vector2i = f.npc_cells["matthew"]
	f.cell = mc + Vector2i(0, 1)
	f.facing = "up"
	f.interact()
	assert_eq(talked, ["matthew"])
	f.free()


## 点地面：算出一条路，排进走路队列。
func test_click_to_walk() -> void:
	var f := _screen()
	f.press_choice("listen")
	f.flush_messages()
	f._show_next()
	f.click_cell(Vector2i(10, 8))
	assert_true(f.path_queue.size() > 0)
	assert_eq(f.path_queue[f.path_queue.size() - 1], Vector2i(10, 8))
	f.click_cell(Vector2i(29, 7))
	assert_eq(String(f.path_then.get("door", "")), "hall", "点门：走到门边再进去")
	f.free()


## 楼梯井是黑的：手电筒遮罩打开；换屏回来还站在原地。
func test_dark_and_memory() -> void:
	var f := _screen()
	f.press_choice("listen")
	f.press_move("hall")
	f.press_move("stairs")
	assert_eq(f.loc, "stairs")
	f.flush_messages()
	f._show_next()
	assert_true(f.dark.visible)
	var ex: RefCounted = f.view.ex
	var where: Vector2i = f.cell
	f.free()
	var g := FieldScreen.new()
	g.setup(ex, {})
	assert_eq(g.loc, "stairs")
	assert_eq(g.cell, where)
	g.free()
