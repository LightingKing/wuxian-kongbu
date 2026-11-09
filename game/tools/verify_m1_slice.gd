extends SceneTree
## M1 可玩切片的无头验收：加载主场景，按真实界面路径走一遍
## 听规则 → 大厅 → 楼梯井（扶人）→ 激光通道（救马修）→ 主机房 → 丧尸战 → 留守
## → 威胁火焰女皇 → 断电 → 撑到回归 → 结算 → 主神空间 → 存档/读档。
## 用法：godot --headless --path game -s res://tools/verify_m1_slice.gd
## 加 --capture（不带 --headless）可以截一张结算后的图到 art_src/qa/。

const SAVE_PATH := "user://verify_m1_slice.json"

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var packed := load("res://ui/main.tscn") as PackedScene
	_expect(packed != null, "主场景可以加载")
	if packed == null:
		_finish()
		return
	var main: Control = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var screen: Control = main.content.get_child(0)
	_expect(screen.has_method("press_choice"), "开局显示地点图界面")
	_expect(String(main.session.phase) == "expedition", "开局在远征阶段")
	_expect(int(main.session.game.characters.size()) == 7, "七名轮回者")

	_expect(screen.press_choice("listen"), "开场选择：听规则")
	_expect(screen.press_move("hall"), "走到大厅")
	_expect(screen.press_move("stairs"), "走到楼梯井")
	_expect(screen.press_choice("help"), "扶掉队的新人")
	_expect(screen.press_move("laser"), "走进激光通道")
	_expect(screen.press_choice("save_matthew"), "拖着马修贴门")
	_expect(screen.press_move("control"), "进入主机房")
	_expect(int(main.session.expedition.st.clock) == 45, "第 45 分钟到达主机房")
	_expect(main.session.expedition.st.tether.is_empty(), "救下马修后绑定解除")
	await _shot("m1_slice_expedition.png")

	screen.press_rest(25)
	await process_frame
	await process_frame
	var battle: Control = main.content.get_child(0)
	_expect(battle.has_method("press_action"), "第 70 分钟进入战斗界面")
	await _shot("m1_slice_battle.png")
	var guard := 0
	while battle.has_method("press_action") and not bool(battle.view.finished()) and guard < 400:
		battle.press_action(0)
		guard += 1
	_expect(guard < 400, "战斗在 400 个行动内结束")
	await process_frame
	await process_frame
	screen = main.content.get_child(0)
	_expect(screen.has_method("press_choice"), "战斗结束回到地点图")
	_expect(int(main.session.expedition.st.clock) == 70, "战斗结束停在第 70 分钟")
	_expect(main.session.expedition.st.pending_battle.is_empty(), "战斗已回报")

	screen.press_rest(20)
	await process_frame
	_expect(screen.press_choice("stay"), "第 90 分钟选择留守主机房")
	screen.press_rest(35)
	await process_frame
	_expect(screen.press_persuade(3), "第 125 分钟威胁火焰女皇")
	screen.press_rest(40)
	_expect(int(main.session.expedition.st.clock) == 165, "断电事件在第 160 分钟发生")
	screen.press_rest(5)
	screen.press_rest(17)
	await process_frame
	await process_frame
	_expect(String(main.session.phase) == "settlement", "撑到 3:07 后进入结算")
	_expect(_found_text(main.content, "6500"), "郑吒结算 6500 点")
	_expect(_found_text(main.content, "B 级支线"), "B 级支线入账")

	var hub_btn := _find_button(main.content, "进入主神空间")
	_expect(hub_btn != null, "结算界面有进入主神空间的按钮")
	if hub_btn != null:
		hub_btn.emit_signal("pressed")
		await process_frame
	_expect(String(main.session.phase) == "hub", "进入主神空间")
	_expect(_found_text(main.content, "第 1 天"), "休整第 1 天")

	main._on_save()
	main._on_load()
	await process_frame
	_expect(String(main.session.phase) == "hub", "读档回到主神空间")
	_expect(int(main.session.game.characters["zheng_zha"].points) == 6500, "读档后点数还在")

	await _shot("m1_slice_hub.png")

	_finish()


## 加 --capture 时把当前画面存到 art_src/qa/（只在非 headless 下有意义）。
func _shot(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://").path_join("../art_src/qa")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name))


func _expect(cond: bool, message: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL " + message)


func _found_text(node: Node, needle: String) -> bool:
	if node is Label and String(node.text).contains(needle):
		return true
	if node is Button and String(node.text).contains(needle):
		return true
	for c in node.get_children():
		if _found_text(c, needle):
			return true
	return false


func _find_button(node: Node, text: String) -> Button:
	if node is Button and String(node.text) == text:
		return node
	for c in node.get_children():
		var b := _find_button(c, text)
		if b != null:
			return b
	return null


func _finish() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("M1 切片验证：失败 %d 项" % failures)
	quit(0 if failures == 0 else 1)
