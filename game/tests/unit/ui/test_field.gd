extends "res://tests/test_case.gd"
## RPG 式探索：地图（Tiled）、门与入口、寻路；场景里台词进对话框、选择弹窗口、走动、进门、搜索、说话、黑暗；
## 灯光、行走图、队友站位、互动提示、打字效果；图块层；镜头跟随和边界、镜头滚动后点哪格走哪格（在场景树里测）；
## 计划 23：远 / 近两档视野、小地图居中；队友散开 / 归队、剧情人物让路（换屏回来都记得）；
## 列车上剧情人物听不见、只能看看；"在场的人"名单、人物卡、新话题标记、头顶名字。

const TiledMap = preload("res://ui/field/tiled_map.gd")
const FieldScreen = preload("res://ui/field/field_screen.gd")
const FieldArt = preload("res://ui/field/field_art.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const Session = preload("res://core/session/session.gd")
const Topics = preload("res://core/dialogue/topics.gd")

const MAPS := "res://data/maps/biohazard1"
const BIG := "res://tests/fixtures/maps/big"
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


## 开场规则听完、选了"认真听"，台词都看完，能走了。
func _ready_screen() -> Control:
	var f := _screen()
	f.press_choice("listen")
	f.flush_messages()
	f._show_next()
	return f


## 站到 target 旁边一格（走得到、没人、不是门），面朝它。
func _face(f: Control, target: Vector2i) -> void:
	var blocked: Dictionary = f._blocked()
	for d: String in ["down", "up", "left", "right"]:
		var n: Vector2i = target - TiledMap.DIRS[d]
		if f.fmap.walkable(n) and not blocked.has(n) and not f.fmap.is_door(n):
			f.cell = n
			f.facing = d
			return
	assert_true(false, "%s 旁边没有能站的格子" % target)


## 八个地点都有图；门只通向剧本里相邻的地点，相邻的地点都有门；入口、柜子、站位都走得到；一屏里的灯不超过 5 盏；人站得下。
func test_maps_valid() -> void:
	var errors: Array[String] = TiledMap.validate(MAPS, Scenario.load_file(SCENARIO))
	assert_eq(errors.size(), 0, "\n".join(errors))


## 站台与入口大厅：门通向哪、从哪进来站哪；寻路绕开墙和挡路的人；站台和大厅之间只有一道口子。
func test_doors_entries_and_path() -> void:
	var hall: RefCounted = TiledMap.make(MAPS, "hall")
	assert_eq(hall.size, Vector2i(71, 22))
	assert_eq(hall.door_dest(Vector2i(9, 18)), "car", "站台边上的车门")
	assert_eq(hall.door_dest(Vector2i(52, 4)), "stairs", "大厅北墙的楼梯口")
	assert_eq(hall.door_dest(Vector2i(58, 20)), "sewer", "南墙的检修格栅")
	assert_eq(hall.door_dest(Vector2i(20, 10)), "")
	assert_eq(hall.entry_cell("car"), Vector2i(9, 17))
	assert_eq(hall.entry_facing("car"), "up")
	assert_eq(hall.entry_cell("stairs"), Vector2i(52, 5))
	var p: Array[Vector2i] = hall.path(Vector2i(9, 17), Vector2i(52, 5))
	assert_true(p.size() > 0)
	assert_eq(p[p.size() - 1], Vector2i(52, 5))
	var through := false
	for c in p:
		assert_true(hall.walkable(c))
		if c.x == 35:
			through = true
			assert_true(c.y == 10 or c.y == 11, "从站台进大厅要走中间那道口子")
	assert_true(through)
	assert_eq(hall.path(Vector2i(9, 17), Vector2i(0, 0)).size(), 0, "墙走不到")
	assert_false(hall.walkable(Vector2i(51, 10)), "接待台挡路")
	assert_true(hall.walkable(Vector2i(35, 10)))
	assert_false(hall.walkable(Vector2i(35, 8)))
	var blocked := {Vector2i(10, 17): true}
	for c in hall.path(Vector2i(9, 17), Vector2i(11, 17), blocked):
		assert_false(blocked.has(c), "绕开挡路的人")


## 列车：四节车厢连成一长条，车厢之间的门洞在中间三格；能站 14 个人。
func test_train_map() -> void:
	var car: RefCounted = TiledMap.make(MAPS, "car")
	assert_eq(car.size, Vector2i(105, 23))
	assert_eq(int(car.props.get("crowd", 0)), 14)
	for x: int in [26, 52, 78]:
		assert_false(car.walkable(Vector2i(x, 9)), "车厢隔断")
		for y: int in [11, 12, 13]:
			assert_true(car.walkable(Vector2i(x, y)), "隔断中间的门洞")
	var p: Array[Vector2i] = car.path(car.start_cell(), Vector2i(100, 15))
	assert_true(p.size() > 90, "从最后一节走到最前一节")
	assert_eq(car.door_dest(Vector2i(38, 7)), "hall", "车门在第二节车厢")
	assert_eq(car.entry_cell("hall"), Vector2i(38, 8))
	assert_true(car.is_search(Vector2i(75, 17)), "第三节车厢角落的行李")
	assert_eq(car.max_lights_in_window(), 1, "四盏灯分散在四节车厢，一屏只照到一盏")


## 开局：主角站在最后一节车厢；张杰讲规则一句句进对话框；看完弹出选择窗口；选了就收起。
func test_opening_messages_then_choice() -> void:
	var f := _screen()
	assert_eq(f.loc, "car")
	assert_eq(f.cell, Vector2i(4, 11))
	assert_eq(f.facing, "right")
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


## 走动：座位挡路、车顶是墙；七个剧情人物和你们在同一趟车上；进门去站台（花 10 分钟），站在门里一格。
func test_walk_and_door() -> void:
	var f := _ready_screen()
	assert_eq(f.npc_sprites.size(), 7, "雇佣兵、艾丽丝、瑞恩、马特都在车上")
	f.step("up")
	assert_eq(f.cell, Vector2i(4, 10))
	f.step("up")
	assert_eq(f.cell, Vector2i(4, 9))
	f.step("up")
	assert_eq(f.cell, Vector2i(4, 9), "座位挡路")
	assert_eq(f.facing, "up")
	f.step("right")
	assert_eq(f.cell, Vector2i(5, 9))
	f.step("up")
	f.step("up")
	assert_eq(f.cell, Vector2i(5, 7), "座位之间的过道走得进去")
	f.step("up")
	assert_eq(f.cell, Vector2i(5, 7), "车厢壁挡路")
	assert_true(f.press_move("hall"))
	assert_eq(f.loc, "hall")
	assert_eq(f.cell, Vector2i(9, 17))
	assert_eq(f.facing, "up")
	assert_eq(int(f.view.ex.st.clock), 10)
	assert_eq(f.npc_sprites.size(), 7, "雇佣兵跟着下了车")
	assert_eq(f._blocked().size(), 7)
	f.free()


## 对着行李按确认就搜索。车上的剧情人物听不见：提示"看看"，按确认照样打开对话框（只能看看）；下了车就是"说话"。
func test_interact_search_and_talk() -> void:
	var f := _ready_screen()
	f.cell = Vector2i(74, 17)
	f.facing = "right"
	assert_eq(f.prompt_text(), "Enter 调查")
	f.interact()
	assert_true(f.view.ex.st.searched.has("car"), "车厢搜过了")
	assert_eq(f.npc_sprites.size(), 7, "搜车厢花了时间，他们也还在车上，等你们一起下车")
	f.flush_messages()
	f._show_next()
	var talked: Array = []
	f.talk_requested.connect(func(id: String) -> void: talked.append(id))
	_face(f, f.npc_cells["matthew"])
	assert_true(f.prompt_text().begins_with("Enter 看看："), f.prompt_text())
	f.interact()
	assert_eq(talked, ["matthew"])
	f.press_move("hall")
	f.flush_messages()
	f._show_next()
	_face(f, f.npc_cells["matthew"])
	assert_true(f.prompt_text().begins_with("Enter 说话："), f.prompt_text())
	f.interact()
	assert_eq(talked, ["matthew", "matthew"])
	f.free()


## 点地面：算出一条路，排进走路队列；点门：走到门边再进去。
func test_click_to_walk() -> void:
	var f := _ready_screen()
	f.click_cell(Vector2i(20, 12))
	assert_true(f.path_queue.size() > 0)
	assert_eq(f.path_queue[f.path_queue.size() - 1], Vector2i(20, 12))
	f.click_cell(Vector2i(38, 7))
	assert_eq(String(f.path_then.get("door", "")), "hall", "点门：走到门边再进去")
	assert_eq(f.path_queue[f.path_queue.size() - 1], Vector2i(38, 8))
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


## 灯光：每个地点按地图打灯、压环境光；激光通道墙上的发射器是自发光光晕；黑暗地点换成手电筒。
func test_lights_and_ambient() -> void:
	var f := _screen()
	f.press_choice("listen")
	assert_eq(f.light_root.get_child_count(), 4, "列车四节车厢各一盏顶灯")
	assert_eq(f.canvas_mod.color, f.fmap.ambient())
	assert_false(f.dark.visible, "车厢不黑")
	f.press_move("hall")
	assert_eq(f.light_root.get_child_count(), 7, "站台三盏、大厅三盏顶灯加接待台的台灯")
	f.press_move("stairs")
	assert_true(f.dark.visible)
	assert_eq(f.canvas_mod.color, FieldScreen.DARK_AMBIENT, "黑暗地点只剩手电筒")
	f.free()
	var laser: RefCounted = TiledMap.make(MAPS, "laser")
	assert_eq((laser.glows() as Array).size(), 12, "两排激光发射器")
	var control: RefCounted = TiledMap.make(MAPS, "control")
	assert_true(control.max_lights_in_window() <= TiledMap.MAX_LIGHTS)


## 有 Codex 的行走图就用：按 4×4 切帧（规格单帧 16×32），脚底中点对齐格子；没有的人还用占位小人。
func test_walker_sheet() -> void:
	var dir := "user://test_field_art/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir + "walkers"))
	var sheet := Image.create(64, 128, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	sheet.fill_rect(Rect2i(4, 4, 8, 28), Color("3a4a78"))
	sheet.save_png(ProjectSettings.globalize_path(dir + "walkers/zheng_zha.png"))
	var old_root := FieldArt.art_root
	FieldArt.art_root = dir
	FieldArt.clear_cache()
	var f := _screen()
	assert_eq(FieldArt.walker_size("zheng_zha"), Vector2i(16, 32))
	var down0 := FieldArt.walker("zheng_zha", "down", 0) as AtlasTexture
	assert_eq(down0.region, Rect2(0, 0, 16, 32))
	var up_step := FieldArt.walker("zheng_zha", "up", 2) as AtlasTexture
	assert_eq(up_step.region, Rect2(48, 96, 16, 32), "第 4 行（上）第 4 列（迈另一只脚）")
	assert_eq(f.player.offset, Vector2(-8, -32), "脚底中点对齐格子")
	assert_eq(FieldArt.walker_size("zhang_jie"), Vector2i(FieldArt.WALK_W, FieldArt.WALK_H), "没有行走图的还用占位小人")
	f.free()
	FieldArt.art_root = old_root
	FieldArt.clear_cache()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + "walkers/zheng_zha.png"))


## 一进场队友就围在主角身边（各站一格、都能走）；面前的行李、门、人会提示能做什么。
func test_formation_and_prompts() -> void:
	var f := _ready_screen()
	var taken := {}
	for i in f.followers.size():
		var c: Vector2i = f.follower_cell(i)
		assert_true(f.followers[i].visible, "队友看得见")
		assert_true(f.fmap.walkable(c))
		assert_false(taken.has(c), "不叠在一起")
		taken[c] = true
	assert_false(taken.has(f.cell))
	f.cell = Vector2i(74, 17)
	f.facing = "right"
	assert_eq(f.prompt_text(), "Enter 调查")
	f.cell = Vector2i(38, 8)
	f.facing = "up"
	assert_true(f.prompt_text().begins_with("前往："))
	f.cell = Vector2i(4, 11)
	f.facing = f._dir_between(f.cell, f.follower_cell(0))
	f.cell = f.follower_cell(0) - TiledMap.DIRS[f.facing]
	assert_true(f.prompt_text().begins_with("Enter 说话："), "队友随时能说话")
	f.cell = Vector2i(20, 12)
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


## 图块层：地面、墙、装饰在人物下面，上层在人物上面；列车的地面、车厢壁、行李都填进去了（实验室图块）。
func test_tile_layers() -> void:
	var f := _screen()
	var floor: TileMapLayer = f.map_layers["floor"]
	var walls: TileMapLayer = f.map_layers["walls"]
	var decor: TileMapLayer = f.map_layers["decor"]
	assert_eq(floor.get_cell_source_id(Vector2i(4, 11)), 0, "开场格有地面")
	assert_eq(walls.get_cell_source_id(Vector2i(5, 4)), 1, "车厢壁用墙面图块")
	assert_eq(walls.get_cell_atlas_coords(Vector2i(5, 4)), Vector2i(2, 0))
	assert_eq(decor.get_cell_source_id(Vector2i(75, 17)), 2, "行李用杂物图块")
	assert_eq(decor.get_cell_atlas_coords(Vector2i(75, 17)), Vector2i(35, 11))
	assert_true(floor.get_index() < f.actors.get_index(), "地面在人物下面")
	assert_true(f.map_layers["over"].get_index() > f.actors.get_index(), "上层在人物上面")
	assert_eq(f.camera.limit_left, 0)
	assert_eq(f.camera.limit_right, 105 * 16, "比一屏大的地图：镜头贴着地图边")
	f.free()


## 镜头（在场景树里，近视野）：地图比一屏大时跟着主角，到地图边上停住；镜头滚过以后点哪格就是哪格。
func test_camera_follows_and_clamps() -> void:
	FieldScreen.maps_dir = BIG
	FieldScreen.wide = false
	var f := _screen()
	tree().root.add_child(f)
	f._snap_camera()
	await tree().process_frame
	assert_eq(f.fmap.size, Vector2i(40, 24), "测试用的大地图")
	assert_eq(f.view_origin(), Vector2.ZERO, "开场在左上角，镜头贴着地图左上边")
	assert_eq(f.cell_at(Vector2(4 * 16 * 3 + 8, 4 * 16 * 3 + 8)), Vector2i(3, 3))
	f.cell = Vector2i(20, 12)
	f._draw_actors()
	f._snap_camera()
	await tree().process_frame
	var o: Vector2 = f.view_origin()
	assert_eq(o, Vector2(20 * 16 + 8 - 240, 12 * 16 + 14 - 8 - 128), "主角在屏幕正中")
	assert_eq(f.cell_at(Vector2(240 * 4, 120 * 4)), Vector2i(20, 11), "屏幕正中偏上一点是主角头顶那格")
	f.cell = Vector2i(38, 22)
	f._draw_actors()
	f._snap_camera()
	await tree().process_frame
	assert_eq(f.view_origin(), Vector2(40 * 16 - 480, 24 * 16 - 256), "到了右下角，镜头贴着地图边停住")
	assert_eq(f.cell_at(Vector2.ZERO), Vector2i(10, 8))
	tree().root.remove_child(f)
	f.free()
	FieldScreen.maps_dir = MAPS
	FieldScreen.wide = true


## 两档视野：远（一屏 40×21 格、放大 3 倍，默认）和近（30×16 格、放大 4 倍）；比一屏小的地图在远视野里居中。
func test_view_toggle_and_small_map_centered() -> void:
	FieldScreen.wide = true
	var f := _screen()
	assert_eq(f.pixel_size, FieldScreen.VIEW_FAR)
	assert_eq(f.scale_factor, 3)
	assert_eq(f.viewport.size, Vector2i(640, 341))
	f.press_choice("listen")
	f.press_move("hall")
	f.press_move("stairs")
	assert_eq(f.fmap.size, Vector2i(30, 16))
	assert_eq([f.camera.limit_left, f.camera.limit_top, f.camera.limit_right, f.camera.limit_bottom], [-80, -42, 560, 299], "四周留同样宽的黑边")
	f.set_wide(false)
	assert_false(FieldScreen.wide)
	assert_eq(f.pixel_size, FieldScreen.VIEW_NEAR)
	assert_eq(f.scale_factor, 4)
	assert_eq(f.viewport.size, Vector2i(480, 256))
	assert_eq(f.display.size, Vector2(1920, 1024))
	assert_eq([f.camera.limit_left, f.camera.limit_top, f.camera.limit_right, f.camera.limit_bottom], [0, 0, 480, 256], "正好一屏")
	f.set_wide(true)
	assert_eq(f.display.size, Vector2(1920, 1023))
	f.free()
	FieldScreen.wide = true


## 站着不动一会儿队友就散开（各站一格、不挡门、不站人身上，离主角不远）；一走动又排成一路跟上；换屏回来散开的位置还在。
func test_spread_and_gather() -> void:
	var f := _ready_screen()
	assert_false(f.spread)
	f.spread_out()
	assert_true(f.spread)
	var taken := {f.cell: true}
	var blocked: Dictionary = f._blocked()
	for i in f.followers.size():
		var c: Vector2i = f.follower_cell(i)
		assert_true(f.fmap.walkable(c))
		assert_false(f.fmap.is_door(c))
		assert_false(blocked.has(c), "不站在剧情人物身上")
		assert_false(taken.has(c), "各站一格")
		assert_true(absi(c.x - f.cell.x) + absi(c.y - f.cell.y) <= 4, "离主角不远")
		taken[c] = true
	var ex: RefCounted = f.view.ex
	var cells: Array[Vector2i] = f.spread_cells.duplicate()
	f.free()
	var g := FieldScreen.new()
	g.setup(ex, {})
	assert_true(g.spread, "换屏回来还散着")
	assert_eq(g.spread_cells, cells)
	g.step("right")
	assert_false(g.spread, "一走就归队")
	assert_eq(g.cell, Vector2i(5, 11))
	assert_eq(g.trail.size(), 7)
	assert_eq(g.follower_cell(0), Vector2i(4, 11), "离得最近的跟在正后面")
	g.free()


## 顶着剧情人物走：先只转身对着他（能说话）；顶住一会儿他就和你换位置让路；换屏回来他还站在让开的地方。
func test_npc_gives_way() -> void:
	var f := _ready_screen()
	var mc: Vector2i = f.npc_cells["matthew"]
	_face(f, mc)
	var start: Vector2i = f.cell
	f.step(f.facing)
	assert_eq(f.cell, start, "第一下只是对着他")
	assert_eq(f.npc_cells["matthew"], mc)
	f._time += FieldScreen.GIVE_WAY_DELAY + 0.1
	f.step(f.facing)
	assert_eq(f.cell, mc, "他让开了，你走过去")
	assert_eq(f.npc_cells["matthew"], start, "他站到你原来的格子")
	var ex: RefCounted = f.view.ex
	f.free()
	var g := FieldScreen.new()
	g.setup(ex, {})
	assert_eq(g.npc_cells["matthew"], start, "换屏回来还在那儿")
	g.free()


## "在场的人"：你、六个队友、七个剧情人物；车上的剧情人物标"听不见你们说话"；名单开着时不能走。
func test_roster() -> void:
	var f := _ready_screen()
	var people: Array[String] = f.present_people()
	assert_eq(people.size(), 14)
	assert_eq(people[0], "zheng_zha")
	assert_true(people.has("ryan") and people.has("matt") and people.has("alice"))
	f.open_roster()
	assert_true(f.roster_panel.visible)
	assert_true(f.busy())
	assert_eq(f.roster_box.get_child_count(), 15, "标题加 14 行")
	assert_true(f.roster_scroll.custom_minimum_size.y <= 800.0, "名单不超出屏幕，人多了就滚动")
	assert_true(f.roster_panel.position.y + f.roster_scroll.custom_minimum_size.y < 1000.0)
	var texts: Array[String] = []
	for row in f.roster_box.get_children():
		if row is HBoxContainer:
			texts.append(String(((row as HBoxContainer).get_child(0) as Label).text))
	var deaf := 0
	for t in texts:
		if t.contains("听不见你们说话"):
			deaf += 1
	assert_eq(deaf, 7)
	f.close_panels()
	assert_false(f.busy())
	f.free()


## 人物卡：身份、状态、信任；聊出来的要点一条条记上；还有几个话题没聊过。你自己的卡写你的来历。
func test_cards() -> void:
	var f := _ready_screen()
	var m: Dictionary = f.card_info("matthew")
	assert_eq((m["lines"] as Array)[0], "身份：剧情人物")
	assert_true((m["lines"] as Array).has("现在听不见你们说话（列车减速之前）"))
	assert_true((m["lines"] as Array).has("对你的信任：0 / 5"))
	assert_eq((m["notes"] as Array).size(), 0)
	assert_eq(int(m["unseen"]), 4)
	f.view.ex.talk_topic("matthew", "matthew_look", 0)
	m = f.card_info("matthew")
	assert_eq((m["notes"] as Array).size(), 1)
	assert_eq(int(m["unseen"]), 3)
	f.dialogue_store = {"matthew": {"trust": 3}}
	assert_true((f.card_info("matthew")["lines"] as Array).has("对你的信任：3 / 5"))
	var z: Dictionary = f.card_info("zhang_jie")
	assert_eq((z["lines"] as Array)[0], "身份：轮回者")
	assert_true(String((z["lines"] as Array)[1]).begins_with("血 "))
	assert_true(String((z["lines"] as Array)[2]).begins_with("对你的信任 "))
	var me: Dictionary = f.card_info("zheng_zha")
	assert_eq((me["lines"] as Array)[0], "身份：轮回者（你自己）")
	assert_true(String((me["notes"] as Array)[0]).length() > 0, "你自己的来历")
	f.open_card("ryan")
	assert_true(f.card_panel.visible)
	assert_true(f.card_body.text.contains("还不了解"))
	assert_true(f.busy())
	f.close_panels()
	f.free()


## 新话题标记：有没聊过的话题的人头顶名字后面带"…"；聊完了就没了；走近的人才显示名字。
func test_new_topic_marks_and_names() -> void:
	var f := _ready_screen()
	assert_true(f.has_new_topic("zhang_jie"))
	assert_true(f.has_new_topic("matthew"), "车上能看看他")
	assert_false(f.has_new_topic("zheng_zha"))
	for t: Dictionary in Topics.available(f.view.ex.st, "matthew", 0):
		f.view.ex.talk_topic("matthew", String(t["id"]), 0)
	f.refresh()
	assert_false(f.has_new_topic("matthew"), "能看的都看过了")
	f._update_names()
	var rects: Array[Rect2] = []
	var shown := 0
	for id: String in f.name_labels:
		var l: Label = f.name_labels[id]
		if not l.visible:
			continue
		shown += 1
		assert_true(l.text.ends_with(" …"), "队友都还有话没聊：%s" % l.text)
		var r := Rect2(l.position, l.size)
		for o in rects:
			assert_false(r.intersects(o), "名字不叠在一起")
		rects.append(r)
	assert_true(shown >= 3, "身边的队友显示名字")
	assert_false(f.name_labels.has("matthew"), "离得远的不显示")
	f.free()
