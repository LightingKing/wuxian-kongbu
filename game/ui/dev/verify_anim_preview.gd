extends SceneTree
## 验证导入矩形/时序、全部实际状态播放及演示控制；--unit-only 可在生图前检查输入边界。

const Importer = preload("res://tools/import_sprite_atlas.gd")
const IDS: Array[String] = ["zheng_zha", "zombie_scientist"]

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_verify_contract()
	await _verify_pause_contract()
	if not OS.get_cmdline_user_args().has("--unit-only"):
		for id: String in IDS:
			await _verify_character(id)
		await _verify_preview()
	print("动画导入与预览验证：失败 %d 项" % failures)
	quit(0 if failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL " + message)


func _fixture() -> Dictionary:
	return {
		"frame_layout": {"sheetWidth": 8, "sheetHeight": 4, "rows": {
			"idle": [{"x": 4, "y": 0, "w": 4, "h": 2}, {"x": 0, "y": 0, "w": 4, "h": 2}, {"x": 4, "y": 0, "w": 4, "h": 2}],
			"hit": [{"x": 0, "y": 2, "w": 4, "h": 2}],
		}},
		"animation": {"rows": {
			"idle": {"frames": 3, "fps": 8, "loop": true, "durations_ms": [80, 160, 240]},
			"hit": {"frames": 1, "fps": 12, "loop": false},
		}},
	}


func _verify_contract() -> void:
	var image := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var result: Dictionary = Importer.build_sprite_frames(_fixture(), texture)
	_expect(result.has("frames"), "有效 manifest 应导入")
	if not result.has("frames"):
		return
	var frames: SpriteFrames = result["frames"]
	_expect(frames.get_frame_count(&"idle") == 3, "保留播放顺序和重复帧")
	_expect(frames.get_frame_texture(&"idle", 0) == frames.get_frame_texture(&"idle", 2), "重复矩形共享 AtlasTexture")
	_expect((frames.get_frame_texture(&"idle", 0) as AtlasTexture).region == Rect2(4, 0, 4, 2), "不能按帧序号推断网格")
	_expect(is_equal_approx(frames.get_frame_duration(&"idle", 1) / 8.0, 0.160), "durations_ms 优先于等时 fps")
	_expect(frames.get_animation_speed(&"hit") == 12 and not frames.get_animation_loop(&"hit"), "保留 fps 和非循环标志")
	_expect(frames.get_frame_duration(&"hit", 0) == 1.0, "无 durations_ms 时按 fps 播放")
	var bad: Dictionary = _fixture()
	bad["animation"]["rows"].erase("hit")
	_expect(Importer.build_sprite_frames(bad, texture).has("error"), "拒绝缺失状态时序")
	bad = _fixture()
	bad["frame_layout"]["sheetWidth"] = 9
	_expect(Importer.build_sprite_frames(bad, texture).has("error"), "拒绝错误图集尺寸")
	for invalid_x: Variant in [-1, 0.5, 8]:
		bad = _fixture()
		bad["frame_layout"]["rows"]["idle"][0]["x"] = invalid_x
		_expect(Importer.build_sprite_frames(bad, texture).has("error"), "拒绝无效矩形坐标 %s" % invalid_x)
	for invalid_fps: Variant in [0, -1, "8"]:
		bad = _fixture()
		bad["animation"]["rows"]["idle"]["fps"] = invalid_fps
		_expect(Importer.build_sprite_frames(bad, texture).has("error"), "拒绝无效 fps")
	bad = _fixture()
	bad["animation"]["rows"]["idle"]["durations_ms"] = [80]
	_expect(Importer.build_sprite_frames(bad, texture).has("error"), "拒绝时长数量不匹配")
	bad = _fixture()
	bad["animation"]["rows"]["idle"]["durations_ms"][1] = 0
	_expect(Importer.build_sprite_frames(bad, texture).has("error"), "拒绝零时长")
	bad = _fixture()
	bad["animation"]["rows"]["idle"]["loop"] = "false"
	_expect(Importer.build_sprite_frames(bad, texture).has("error"), "拒绝字符串循环标志")
	for escape: String in ["res://../outside.json", "res://../../outside.png", "res://art/../../../outside.tres", "res://..\\outside.json"]:
		_expect(Importer.project_resource_path(escape).is_empty(), "拒绝工程外路径 " + escape)
	_expect(Importer.project_resource_path("res://art/../ui/dev/anim_preview.tscn") == "res://ui/dev/anim_preview.tscn", "工程内路径规范化")
	print("已验证 manifest 边界、重复矩形及非等时帧。")


func _verify_pause_contract() -> void:
	# 不依赖生图产物，直接使用两个真实 AnimatedSprite2D 验证非循环结束与暂停边界。
	var controller: Control = load("res://ui/dev/anim_preview.gd").new()
	controller.call("_build_ui")
	var image := Image.create(8, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(image)
	var fixtures: Array[AnimatedSprite2D] = []
	for index: int in 2:
		var frames := SpriteFrames.new()
		frames.remove_animation(&"default")
		for name: String in ["idle", "attack", "hit", "down", "death"]:
			frames.add_animation(name)
			frames.set_animation_speed(name, 60.0)
			frames.set_animation_loop(name, name == "idle")
			frames.add_frame(name, texture)
			frames.add_frame(name, texture)
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		root.add_child(sprite)
		fixtures.append(sprite)
	controller.set("sprites", fixtures)
	var resume_flags: Array[bool] = [false, false]
	controller.set("_resume_after_pause", resume_flags)
	controller.set("ready_to_play", true)
	controller.call("show_state", 1)
	await create_timer(0.12).timeout
	_expect(not fixtures[0].is_playing() and fixtures[0].frame == 1, "非循环动作已完成")
	controller.call("set_paused", true)
	controller.call("set_paused", false)
	_expect(not fixtures[0].is_playing() and fixtures[0].frame == 1, "暂停/继续不重播已结束的动作")
	controller.call("set_paused", true)
	controller.call("show_state", 2)
	_expect(fixtures[0].animation == &"hit" and not fixtures[0].is_playing(), "暂停中切换动作保持暂停")
	controller.call("set_paused", false)
	_expect(fixtures[0].is_playing(), "恢复暂停中选定的新动作")
	controller.call("show_state", 0)
	controller.call("set_paused", true)
	controller.call("set_paused", false)
	_expect(fixtures[0].is_playing(), "恢复暂停前正在循环的动作")
	for sprite: AnimatedSprite2D in fixtures:
		sprite.queue_free()
	controller.free()
	print("已验证结束后暂停/继续、暂停中切换和循环恢复。")


func _verify_character(id: String) -> void:
	var directory: String = "res://art/style_test/anim/%s/" % id
	var frames := ResourceLoader.load(directory + "sprite_frames.tres") as SpriteFrames
	_expect(frames != null, id + " 的 SpriteFrames 可加载")
	if frames == null:
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory + "manifest.json"))
	var expected_states: Array[String] = ["idle", "attack", "hit", "down" if id == "zheng_zha" else "death"]
	_expect(frames.get_animation_names().size() == expected_states.size(), id + " 状态总数")
	for state: String in expected_states:
		_expect(frames.has_animation(state), id + " 包含 " + state)
		if not frames.has_animation(state):
			continue
		var rects: Array = data["frame_layout"]["rows"][state]
		var timing: Dictionary = data["animation"]["rows"][state]
		_expect(frames.get_frame_count(state) == rects.size(), id + state + " 帧数量")
		_expect(is_equal_approx(frames.get_animation_speed(state), float(timing["fps"])), id + state + " fps")
		_expect(frames.get_animation_loop(state) == timing["loop"], id + state + " loop")
		var duration: float = 0.0
		for index: int in rects.size():
			var atlas := frames.get_frame_texture(state, index) as AtlasTexture
			var rect: Dictionary = rects[index]
			_expect(atlas != null and atlas.region == Rect2(rect["x"], rect["y"], rect["w"], rect["h"]), id + state + " 明确帧矩形")
			var seconds: float = frames.get_frame_duration(state, index) / frames.get_animation_speed(state)
			var expected: float = float(timing["durations_ms"][index]) / 1000.0 if timing.has("durations_ms") else 1.0 / float(timing["fps"])
			_expect(is_equal_approx(seconds, expected), id + state + " 每帧时长")
			duration += seconds
		var sprite := AnimatedSprite2D.new()
		var events: Dictionary = {"changed": 0, "finished": 0, "looped": 0}
		sprite.sprite_frames = frames
		sprite.speed_scale = 30.0
		sprite.frame_changed.connect(func() -> void: events["changed"] += 1)
		sprite.animation_finished.connect(func() -> void: events["finished"] += 1)
		sprite.animation_looped.connect(func() -> void: events["looped"] += 1)
		root.add_child(sprite)
		sprite.play(state)
		await create_timer(duration / 30.0 + 0.15).timeout
		if bool(timing["loop"]):
			_expect(sprite.is_playing() and int(events["looped"]) > 0, id + state + " 实际循环播放")
		else:
			_expect(not sprite.is_playing() and int(events["finished"]) == 1 and sprite.frame == rects.size() - 1, id + state + " 实际播完停在末帧")
		if rects.size() > 1:
			_expect(int(events["changed"]) > 0, id + state + " 实际推进帧")
		print("已播放 %s/%s：%d 帧，%s fps，loop=%s" % [id, state, rects.size(), timing["fps"], timing["loop"]])
		sprite.queue_free()


func _verify_preview() -> void:
	var packed := load("res://ui/dev/anim_preview.tscn") as PackedScene
	var preview: Control = packed.instantiate()
	root.add_child(preview)
	await process_frame
	_expect(bool(preview.get("ready_to_play")), "预览场景加载两个角色")
	if not bool(preview.get("ready_to_play")):
		preview.queue_free()
		return
	var sprites: Array = preview.get("sprites")
	for index: int in 4:
		preview.call("show_state", index)
		_expect(sprites[0].animation == ["idle", "attack", "hit", "down"][index], "郑吒状态轮换")
		_expect(sprites[1].animation == ["idle", "attack", "hit", "death"][index], "丧尸状态轮换")
	preview.call("show_state", 0)
	preview.call("set_paused", true)
	var progress: float = sprites[0].frame_progress
	await create_timer(0.1).timeout
	_expect(not sprites[0].is_playing() and is_equal_approx(progress, sprites[0].frame_progress), "暂停保持当前帧进度")
	preview.call("set_paused", false)
	_expect(sprites[0].is_playing(), "继续播放")
	preview.set("_remaining", 0.0)
	await process_frame
	await process_frame
	_expect(int(preview.get("state_index")) == 1, "自动轮播推进状态")
	preview.call("show_state", 0)
	preview.set("automatic", false)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var capture_index: int = args.find("--capture")
	if capture_index >= 0 and capture_index + 1 < args.size():
		var output: String = ProjectSettings.globalize_path(args[capture_index + 1])
		var allowed: String = ProjectSettings.globalize_path("res://../art_src/style_test/anim/").simplify_path() + "/"
		_expect(output.simplify_path().begins_with(allowed) and DisplayServer.get_name() != "headless", "截图须写入 art_src 且使用图形渲染")
		if output.simplify_path().begins_with(allowed) and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(output.get_base_dir())
			_expect(root.get_texture().get_image().save_png(output) == OK, "保存预览截图")
	preview.queue_free()
