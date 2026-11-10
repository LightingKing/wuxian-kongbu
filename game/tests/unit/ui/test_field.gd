extends "res://tests/test_case.gd"
## RPG 式探索：地图数据、门与入口、寻路；场景里台词进对话框、选择弹窗口、走动、进门、搜索、说话、黑暗；
## 灯光、正式图（整张地图、行走图）、队友站位、互动提示、打字效果、给 Codex 的版式图和对位图。

const FieldMap = preload("res://ui/field/field_map.gd")
const FieldScreen = preload("res://ui/field/field_screen.gd")
const FieldArt = preload("res://ui/field/field_art.gd")
const FieldGuide = preload("res://ui/field/field_guide.gd")
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


## 灯光：每个地点按地图打灯、压环境光；激光通道墙上的发射器是自发光光晕；黑暗地点换成手电筒；火焰女皇的投影发红光。
func test_lights_and_ambient() -> void:
	var f := _screen()
	f.press_choice("listen")
	assert_eq(f.light_root.get_child_count(), (f.fmap.lights() as Array).size())
	assert_eq(f.canvas_mod.color, f.fmap.ambient())
	assert_false(f.dark.visible, "车厢不黑")
	f.press_move("hall")
	assert_eq(f.light_root.get_child_count(), 4, "大厅四盏吊灯")
	f.press_move("stairs")
	assert_true(f.dark.visible)
	assert_eq(f.canvas_mod.color, FieldScreen.DARK_AMBIENT, "黑暗地点只剩手电筒")
	f.free()
	var laser: RefCounted = FieldMap.make(MAPS, "laser")
	assert_eq((laser.glows() as Array).size(), 12, "两排激光发射器")
	var control: RefCounted = FieldMap.make(MAPS, "control")
	assert_true((control.lights() as Array).size() <= FieldMap.MAX_LIGHTS)


## 有 Codex 画的整张地图和行走图就用：地图盖掉占位图块，行走图按 4×4 切帧，脚底对齐格子。
func test_painted_map_and_walker_sheet() -> void:
	var dir := "user://test_field_art/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir + "maps"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir + "walkers"))
	var map_img := Image.create(480, 256, false, Image.FORMAT_RGBA8)
	map_img.fill(Color("30384a"))
	map_img.save_png(ProjectSettings.globalize_path(dir + "maps/car.png"))
	var sheet := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	sheet.fill_rect(Rect2i(8, 4, 16, 28), Color("3a4a78"))
	sheet.save_png(ProjectSettings.globalize_path(dir + "walkers/zheng_zha.png"))
	var old_root := FieldArt.art_root
	FieldArt.art_root = dir
	FieldArt.clear_cache()
	var f := _screen()
	assert_true(f.ground.visible, "画好的地图")
	assert_false(f.tiles.visible, "占位图块收起来")
	assert_eq(FieldArt.walker_size("zheng_zha"), Vector2i(32, 32))
	var down0 := FieldArt.walker("zheng_zha", "down", 0) as AtlasTexture
	assert_eq(down0.region, Rect2(0, 0, 32, 32))
	var up_step := FieldArt.walker("zheng_zha", "up", 2) as AtlasTexture
	assert_eq(up_step.region, Rect2(96, 96, 32, 32), "第 4 行（上）第 4 列（迈另一只脚）")
	assert_eq(f.player.offset, Vector2(-16, -32), "脚底中点对齐格子")
	assert_eq(FieldArt.walker_size("zhang_jie"), Vector2i(FieldArt.WALK_W, FieldArt.WALK_H), "没有行走图的还用占位小人")
	f.free()
	FieldArt.art_root = old_root
	FieldArt.clear_cache()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + "maps/car.png"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + "walkers/zheng_zha.png"))


## 一进场队友就围在主角身边（各站一格、都能走）；面前的柜子、门、人会提示能做什么。
func test_formation_and_prompts() -> void:
	var f := _screen()
	f.press_choice("listen")
	f.flush_messages()
	f._show_next()
	var taken := {}
	for i in f.followers.size():
		var c: Vector2i = f.trail[i + 1]
		assert_true(f.followers[i].visible, "队友看得见")
		assert_true(f.fmap.walkable(c))
		assert_false(taken.has(c), "不叠在一起")
		taken[c] = true
	assert_false(taken.has(f.cell))
	f.cell = Vector2i(1, 8)
	f.facing = "down"
	assert_eq(f.prompt_text(), "Enter 调查")
	f.cell = Vector2i(28, 7)
	f.facing = "right"
	assert_true(f.prompt_text().begins_with("前往："))
	f.cell = f.trail[1] + Vector2i(0, -1) if f.fmap.walkable(f.trail[1] + Vector2i(0, -1)) else f.trail[1] + Vector2i(0, 1)
	f.facing = f._dir_between(f.cell, f.trail[1])
	assert_true(f.prompt_text().begins_with("Enter 说话："))
	f.cell = Vector2i(10, 7)
	f.facing = "down"
	assert_eq(f.prompt_text(), "", "面前是空地")
	f.free()


## 台词一个字一个字打出来（在场景树里才打字，测试里手动设成"还没打完"）：确认键先把这句显示完，再按才到下一句。
func test_typewriter_and_advance() -> void:
	var f := _screen()
	f.messages.clear()
	f.messages.append({"id": "zhang_jie", "name": "张杰", "text": "第一句"})
	f.messages.append({"id": "", "name": "", "text": "第二句"})
	f._hide_box()
	f._show_next()
	assert_eq(f.box_text.text, "第一句")
	assert_eq(f.box_text.visible_characters, -1, "不在场景树里不打字")
	f.box_text.visible_characters = 1
	f._advance()
	assert_eq(f.box_text.visible_characters, -1, "一下子显示完")
	assert_eq(f.box_text.text, "第一句", "还停在这一句")
	f._advance()
	assert_eq(f.box_text.text, "第二句")
	assert_false(f.box_face.visible, "旁白没有立绘")
	f.free()


## 给 Codex 的版式图和对位图：版式图一格一色、480×256；对位图放大 4 倍、挡路的格子盖红；行走图检查尺寸和透明。
func test_field_guide() -> void:
	var car: RefCounted = FieldMap.make(MAPS, "car")
	var g := FieldGuide.guide(car)
	assert_eq(g.get_size(), Vector2i(480, 256))
	assert_eq(g.get_pixel(8, 8), FieldGuide.COLORS["top"], "第 0 行是墙顶")
	assert_eq(g.get_pixel(29 * 16 + 8, 7 * 16 + 8), FieldGuide.COLORS["D"], "右边的门")
	assert_eq(g.get_pixel(1 * 16 + 8, 9 * 16 + 8), FieldGuide.COLORS["S"], "柜子")
	assert_eq(g.get_pixel(5 * 16 + 8, 3 * 16 + 8), FieldGuide.COLORS["face"], "座位上面那排墙看得到墙面")
	var painted := Image.create(480, 256, false, Image.FORMAT_RGBA8)
	painted.fill(Color(0.5, 0.5, 0.5))
	var o := FieldGuide.overlay(car, painted)
	assert_eq(o.get_size(), Vector2i(1920, 1024))
	var wall_px := o.get_pixel(32, 32)
	assert_true(wall_px.r > wall_px.g + 0.15, "墙格盖红")
	var floor_px := o.get_pixel(10 * 64 + 32, 7 * 64 + 32)
	assert_almost(floor_px.r, floor_px.g, 0.02, "地面不盖色")
	var ok_sheet := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	ok_sheet.fill(Color(0, 0, 0, 0))
	ok_sheet.set_pixel(5, 5, Color.WHITE)
	assert_eq(FieldGuide.check_sheet(ok_sheet).size(), 0)
	var bad := Image.create(100, 100, false, Image.FORMAT_RGBA8)
	assert_eq(FieldGuide.check_sheet(bad).size(), 1)
