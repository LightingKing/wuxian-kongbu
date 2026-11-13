extends SceneTree
## 计划 21 / 任务卡 007：给探索画面截图，看地图、行走图、灯光放进游戏里是什么样子。
## 用法（要窗口，不能 --headless）：godot --path game -s res://tools/field_capture.gd
## 输出：仓库根目录 art_src/qa/field_<序号>_<内容>.png（1920×1080）：开场对话框，八个地点各一张，
## 然后列车上的近视野、"在场的人"名单、瑞恩的人物卡（计划 23）。
## 只截图，不写存档。截地点时直接把分队放到那个地点（跳过路上的剧情和战斗），剧情人物按开局的位置站；
## 站台大厅那张把车上的剧情人物也挪下车（和真玩时一样，他们跟你们一起下车）。

const Session = preload("res://core/session/session.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const FieldScreen = preload("res://ui/field/field_screen.gd")

const SCENARIO := "res://data/scenarios/biohazard1/scenario.json"

var n := 0


func _initialize() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	n += 1
	var dir := ProjectSettings.globalize_path("res://").path_join("../art_src/qa")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("field_%02d_%s.png" % [n, name])
	root.get_texture().get_image().save_png(path)
	print("截图 ", path)


func _field(s: RefCounted) -> Control:
	var names := {}
	for id: String in s.game.characters:
		names[id] = s.game.characters[id].display_name
	var f := FieldScreen.new()
	root.add_child(f)
	f.setup(s.expedition, names)
	return f


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var s := Session.new()
	s.start_m1(1)
	var f := _field(s)
	await create_timer(1.6).timeout
	await _shot("car_opening")
	f.queue_free()
	await process_frame
	var locations: Dictionary = Scenario.load_file(SCENARIO).data["locations"]
	for loc: String in locations:
		var s2 := Session.new()
		s2.start_m1(1)
		var g := _field(s2)
		g.press_choice("listen")
		g.flush_messages()
		var sid: String = g.view.squad_id()
		s2.expedition.st.squads[sid]["location"] = loc
		if loc == "hall":
			for npc_id: String in s2.expedition.st.npcs:
				if String(s2.expedition.st.npcs[npc_id]["location"]) == "car":
					s2.expedition.st.npcs[npc_id]["location"] = "hall"
		g.refresh()
		g.flush_messages()
		g._show_next()
		await create_timer(0.9).timeout
		await _shot(loc)
		g.queue_free()
		await process_frame
	var s3 := Session.new()
	s3.start_m1(1)
	var h := _field(s3)
	h.press_choice("listen")
	h.flush_messages()
	h._show_next()
	h.set_wide(false)
	await create_timer(1.8).timeout
	await _shot("car_near_spread")
	h.set_wide(true)
	h.open_roster()
	await _shot("car_roster")
	s3.expedition.talk_topic("ryan", "ryan_look", 0)
	h.open_card("ryan")
	await _shot("car_card_ryan")
	h.queue_free()
	await process_frame
	print("共截图 ", n)
	quit(0)
