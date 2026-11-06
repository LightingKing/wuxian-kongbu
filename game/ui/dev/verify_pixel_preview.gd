extends SceneTree
## --structure-only 无需新图；--capture 保存战斗、对话、逐帧 QA 与身份对照的真实截图。

const IDS: Array[String] = ["zheng_zha", "zombie_scientist"]
const STATES: Array = [["idle", "attack", "hit", "down"], ["idle", "attack", "hit", "death"]]
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var packed := load("res://ui/dev/pixel_preview.tscn") as PackedScene
	_expect(packed != null, "预览场景可加载")
	if packed == null:
		quit(1)
		return
	var preview: Control = packed.instantiate()
	root.add_child(preview)
	await process_frame
	_verify_structure(preview)
	_verify_dialogue(preview)
	if not OS.get_cmdline_user_args().has("--structure-only"):
		_expect(bool(preview.get("ready_to_play")), "六名演员素材已加载")
		if bool(preview.get("ready_to_play")):
			await _verify_animations(preview)
			if OS.get_cmdline_user_args().has("--capture"):
				await _capture(preview)
	print("像素预览验证：失败 %d 项" % failures)
	preview.queue_free()
	quit(0 if failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL " + message)


func _verify_structure(preview: Control) -> void:
	var viewport: SubViewport = preview.get("pixel_viewport")
	var display: Sprite2D = preview.get("pixel_display")
	var background: Sprite2D = preview.get("background")
	_expect(viewport.size == Vector2i(480, 270), "内部画布 480×270")
	_expect(viewport.canvas_item_default_texture_filter == Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST, "像素画布默认 Nearest")
	_expect(viewport.snap_2d_transforms_to_pixel and viewport.snap_2d_vertices_to_pixel, "像素画布变换及顶点对齐")
	_expect(display.position == Vector2.ZERO and display.scale == Vector2(4, 4) and not display.centered, "像素画布从原点整数四倍铺满")
	_expect(display.texture.get_size() == Vector2(480, 270) and display.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "显示纹理 Nearest")
	_expect(background.position == Vector2.ZERO and background.scale == Vector2.ONE and background.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "背景一比一像素对齐")
	var layer: Control = preview.get("dialogue_layer")
	var portrait: TextureRect = preview.get("portrait")
	var label: Label = preview.get("dialogue_label")
	var button: Button = preview.get("mode_button")
	_expect(not viewport.is_ancestor_of(layer) and layer.get_viewport() == root, "立绘和对话框在原生画布上")
	_expect(portrait.texture != null and portrait.texture.resource_path == "res://art/style_test/zheng_zha_portrait_calm.png", "使用原版平静立绘")
	_expect(label.text == "这是……什么地方？", "中文对话内容")
	_expect(button.size.x >= 48 and button.size.y >= 48, "触屏切换按钮至少 48 像素")
	print("已验证内部画布、最近邻、整数四倍放大与原生立绘/中文界面。")


func _verify_dialogue(preview: Control) -> void:
	var layer: Control = preview.get("dialogue_layer")
	var button: Button = preview.get("mode_button")
	_expect(not layer.visible and not bool(preview.get("dialogue_mode")), "初始为战斗模式")
	var key := InputEventKey.new()
	key.keycode = KEY_D
	key.pressed = true
	preview.call("_unhandled_key_input", key)
	_expect(layer.visible and bool(preview.get("dialogue_mode")), "D 键切换到对话")
	var dimmer := layer.get_node("Dimmer") as ColorRect
	_expect(dimmer.visible and dimmer.color.a > 0.0 and dimmer.color.a < 1.0 and dimmer.size == Vector2(1920, 1080), "对话压暗像素画面")
	button.pressed.emit()
	_expect(not layer.visible and not bool(preview.get("dialogue_mode")), "触屏按钮返回战斗")
	print("已验证 D 键及触屏按钮的模式切换。")


func _verify_animations(preview: Control) -> void:
	preview.set("automatic", false)
	var sprites: Array = preview.get("sprites")
	_expect(sprites.size() == 6, "左右各三名演员")
	if sprites.size() != 6:
		return
	for value: Variant in sprites:
		var sprite: AnimatedSprite2D = value
		_expect(sprite.position == sprite.position.round() and sprite.scale == Vector2.ONE and not sprite.centered, "所有演员整数坐标及原尺寸")
		_expect(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and not sprite.flip_h and not sprite.flip_v, "所有演员最近邻且不镜像")
	for character: int in IDS.size():
		var frames: SpriteFrames = sprites[character * 3].sprite_frames
		_expect(frames.get_animation_names().size() == 4, IDS[character] + " 四个状态")
		for state: String in STATES[character]:
			_expect(frames.has_animation(state), IDS[character] + state + " 状态存在")
			if not frames.has_animation(state):
				continue
			var count: int = frames.get_frame_count(state)
			_expect(count >= 2 and count <= 6, IDS[character] + state + " 2～6 帧")
			_expect(frames.get_animation_loop(state) == (state == "idle"), IDS[character] + state + " 仅待机循环")
			var duration: float = 0.0
			for frame: int in count:
				_expect(frames.get_frame_texture(state, frame).get_size() == Vector2(48, 48), IDS[character] + state + " 48×48 帧")
				duration += frames.get_frame_duration(state, frame) / frames.get_animation_speed(state)
			var sprite := AnimatedSprite2D.new()
			var events: Dictionary = {"changed": 0, "finished": 0, "looped": 0}
			sprite.sprite_frames = frames
			sprite.speed_scale = 20.0
			sprite.visible = false
			sprite.frame_changed.connect(func() -> void: events["changed"] += 1)
			sprite.animation_finished.connect(func() -> void: events["finished"] += 1)
			sprite.animation_looped.connect(func() -> void: events["looped"] += 1)
			root.add_child(sprite)
			sprite.play(state)
			await create_timer(duration / 20.0 + 0.15).timeout
			_expect(int(events["changed"]) > 0, IDS[character] + state + " 实际推进帧")
			if state == "idle":
				_expect(sprite.is_playing() and int(events["looped"]) > 0, IDS[character] + state + " 实际循环播放")
			else:
				_expect(not sprite.is_playing() and int(events["finished"]) == 1 and sprite.frame == count - 1, IDS[character] + state + " 播完停在末帧")
			print("已播放 %s/%s：%d 帧，loop=%s" % [IDS[character], state, count, frames.get_animation_loop(state)])
			sprite.queue_free()
	for index: int in 4:
		preview.call("show_state", index)
		for character: int in 2:
			for rank: int in 3:
				_expect(sprites[character * 3 + rank].animation == StringName(STATES[character][index]), "六名演员同步轮换四个动作")
	preview.call("show_state", 0)
	preview.set("automatic", true)
	preview.set("_remaining", 0.0)
	await process_frame
	await process_frame
	_expect(int(preview.get("state_index")) == 1, "自动轮播推进状态")
	preview.set("automatic", false)
	preview.call("show_state", 0)


func _capture(preview: Control) -> void:
	_expect(DisplayServer.get_name() != "headless", "截图须使用图形渲染")
	if DisplayServer.get_name() == "headless":
		return
	var output: String = ProjectSettings.globalize_path("res://../art_src/pixel_test/")
	_expect(DirAccess.make_dir_recursive_absolute(output) == OK, "创建 art_src 截图目录")
	var sprites: Array = preview.get("sprites")
	preview.call("show_state", 0)
	for sprite: AnimatedSprite2D in sprites:
		sprite.pause()
	for dialogue: bool in [false, true]:
		preview.call("set_dialogue_mode", dialogue)
		var name: String = "godot-dialogue.png" if dialogue else "godot-battle.png"
		await _save_capture(output, name, Vector2i(1920, 1080))
	preview.hide()
	await _capture_atlases(output)
	await _capture_identity(output)


func _save_capture(output: String, name: String, expected_size: Vector2i) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_expect(image.get_size() == expected_size, name + " 实际截图尺寸正确")
	_expect(image.save_png(output.path_join(name)) == OK, "保存 " + name)
	print("已保存实际渲染截图：art_src/pixel_test/" + name)


func _capture_atlases(output: String) -> void:
	var atlases: Array[Texture2D] = []
	var manifests: Array[Dictionary] = []
	for id: String in IDS:
		var directory: String = "res://art/pixel_test/%s/" % id
		atlases.append(load(directory + "sprite-sheet-alpha.png") as Texture2D)
		manifests.append(JSON.parse_string(FileAccess.get_file_as_string(directory + "manifest.json")))
	var left_width: int = atlases[0].get_width() * 4
	var right_width: int = atlases[1].get_width() * 4
	var board_size := Vector2i(maxi(1920, left_width + right_width + 384), maxi(1080, maxi(atlases[0].get_height(), atlases[1].get_height()) * 4 + 312))
	root.size = board_size
	var board: Control = _qa_board(board_size)
	_qa_label(board, tr("逐帧 QA · 完整图集 · Nearest 4×"), Rect2(40, 28, board_size.x - 80, 60), 34)
	_qa_label(board, tr("每格 48×48 → 192×192；左右图集保持原始行列与透明边缘。"), Rect2(40, 92, board_size.x - 80, 40), 24)
	var names: Array[String] = [tr("郑吒（朝右）"), tr("研究员丧尸（朝左）")]
	for character: int in IDS.size():
		var origin := Vector2(160 if character == 0 else left_width + 352, 232)
		var atlas: Texture2D = atlases[character]
		var layout: Dictionary = manifests[character]["frame_layout"]
		_qa_label(board, names[character], Rect2(origin.x - 112, 148, atlas.get_width() * 4 + 112, 40), 28)
		for column: int in atlas.get_width() / 48:
			_qa_label(board, tr("第 %d 帧") % (column + 1), Rect2(origin.x + column * 192, 192, 192, 32), 20)
		for state: String in STATES[character]:
			var rects: Array = layout["rows"][state]
			var row_y: int = int(rects[0]["y"])
			_qa_label(board, state, Rect2(origin.x - 112, origin.y + row_y * 4 + 68, 104, 56), 22)
		for row: int in atlas.get_height() / 48:
			for column: int in atlas.get_width() / 48:
				var cell := ColorRect.new()
				cell.position = origin + Vector2(column * 192, row * 192)
				cell.size = Vector2(192, 192)
				cell.color = Color("2c3848") if (row + column) % 2 == 0 else Color("25303e")
				board.add_child(cell)
		var display := Sprite2D.new()
		display.texture = atlas
		display.centered = false
		display.position = origin
		display.scale = Vector2(4, 4)
		display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		board.add_child(display)
		_expect(display.position == display.position.round() and display.scale == Vector2(4, 4), "QA 图集整数四倍显示")
	await _save_capture(output, "godot-atlas-qa-4x.png", board_size)
	board.queue_free()


func _capture_identity(output: String) -> void:
	root.size = Vector2i(1920, 1080)
	var board: Control = _qa_board(Vector2i(1920, 1080))
	_qa_label(board, tr("角色身份对照 · 像素角色固定 Nearest 4×"), Rect2(40, 28, 1840, 56), 34)
	_qa_label(board, tr("像素格保持原尺寸比例；动漫参考按各栏等比例适配。"), Rect2(40, 92, 1840, 40), 24)
	var headings: Array[String] = [tr("郑吒 · 像素 4×"), tr("郑吒 · 原设定图"), tr("郑吒 · 平静立绘"), tr("丧尸 · 像素 4×"), tr("丧尸 · 原参考图")]
	for column: int in 5:
		_qa_label(board, headings[column], Rect2(column * 384 + 20, 152, 344, 52), 26)
	var references: Array[String] = ["zheng_zha_reference.png", "zheng_zha_portrait_calm.png", "zombie_scientist_attack.png"]
	var reference_columns: Array[int] = [1, 2, 4]
	for index: int in references.size():
		var path: String = "res://art/style_test/" + references[index]
		_expect(ResourceLoader.exists(path), "身份对照参考存在：" + references[index])
		if not ResourceLoader.exists(path):
			continue
		var reference := TextureRect.new()
		reference.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		reference.texture = load(path) as Texture2D
		reference.position = Vector2(reference_columns[index] * 384 + 16, 220)
		reference.size = Vector2(352, 812)
		reference.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		reference.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		board.add_child(reference)
		_expect(reference.size == Vector2(352, 812), "身份对照参考图不撑开固定栏位")
	for character: int in IDS.size():
		var frames := load("res://art/pixel_test/%s/sprite_frames.tres" % IDS[character]) as SpriteFrames
		var column: int = 0 if character == 0 else 3
		for index: int in 2:
			var state: String = "idle" if index == 0 else "attack"
			var sprite := Sprite2D.new()
			sprite.texture = frames.get_frame_texture(state, 0)
			sprite.position = Vector2(column * 384 + 96, 320 + index * 352)
			sprite.centered = false
			sprite.scale = Vector2(4, 4)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			board.add_child(sprite)
			_qa_label(board, state, Rect2(column * 384 + 20, 528 + index * 352, 344, 48), 24)
			_expect(sprite.scale == Vector2(4, 4) and sprite.position == sprite.position.round(), "身份对照像素角色整数四倍显示")
	await _save_capture(output, "godot-identity-comparison-4x.png", Vector2i(1920, 1080))
	board.queue_free()


func _qa_board(board_size: Vector2i) -> Control:
	var board := Control.new()
	board.size = board_size
	root.add_child(board)
	var background := ColorRect.new()
	background.color = Color("17202b")
	background.size = board_size
	board.add_child(background)
	return board


func _qa_label(parent: Control, text: String, rectangle: Rect2, font_size: int) -> void:
	var label := Label.new()
	label.text = tr(text)
	label.position = rectangle.position
	label.size = rectangle.size
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)
