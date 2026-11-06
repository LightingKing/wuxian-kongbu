extends SceneTree
## 用法：godot --headless --path game -s res://tools/import_sprite_atlas.gd -- [manifest.json ...]
## 先运行 godot --headless --editor --path game --import，使 PNG 成为可引用的纹理资源。

const DEFAULT_MANIFESTS: Array[String] = [
	"res://art/style_test/anim/zheng_zha/manifest.json",
	"res://art/style_test/anim/zombie_scientist/manifest.json",
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var paths: Array[String] = []
	paths.assign(arguments if not arguments.is_empty() else DEFAULT_MANIFESTS)
	var pending: Array[Dictionary] = []
	for supplied_path: String in paths:
		var path: String = supplied_path if supplied_path.ends_with(".json") else supplied_path.path_join("manifest.json")
		path = project_resource_path(path)
		if path.is_empty() or not FileAccess.file_exists(path):
			_fail("找不到工程内的 manifest：%s" % supplied_path)
			return
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
			_fail("manifest JSON 无效：%s" % path)
			return
		var manifest: Dictionary = parser.data
		var atlas_name: Variant = manifest.get("sprite_sheet_alpha")
		if not atlas_name is String or atlas_name.is_empty() or atlas_name.is_absolute_path():
			_fail("sprite_sheet_alpha 必须是相对图片路径：%s" % path)
			return
		var atlas_path: String = project_resource_path(path.get_base_dir().path_join(atlas_name))
		if atlas_path.is_empty() or not FileAccess.file_exists(atlas_path):
			_fail("找不到工程内的图集：%s" % atlas_name)
			return
		var texture := ResourceLoader.load(atlas_path) as Texture2D
		if texture == null:
			_fail("图集尚未导入；请先以编辑器导入工程：%s" % atlas_path)
			return
		var result: Dictionary = build_sprite_frames(manifest, texture)
		if result.has("error"):
			_fail("%s：%s" % [path, result["error"]])
			return
		var output_path: String = project_resource_path(path.get_base_dir().path_join("sprite_frames.tres"))
		if output_path.is_empty():
			_fail("输出路径必须位于工程内：%s" % path)
			return
		pending.append({"frames": result["frames"], "path": output_path})
	# 先验证所有输入，再保存，避免一个损坏的 manifest 覆盖前面已存在的资源。
	for item: Dictionary in pending:
		var frames: SpriteFrames = item["frames"]
		var output_path: String = item["path"]
		var error: Error = ResourceSaver.save(frames, output_path)
		if error != OK:
			_fail("保存失败（%s）：%s" % [error_string(error), output_path])
			return
		print("已生成 %s：%s" % [output_path, ", ".join(frames.get_animation_names())])
	quit(0)


func _fail(message: String) -> void:
	printerr(message)
	quit(1)


static func project_resource_path(path: String) -> String:
	# res://../ 在协议字符串上 simplify_path 后仍保留；必须先展开绝对路径再判边界。
	var project: String = ProjectSettings.globalize_path("res://").replace("\\", "/").simplify_path().trim_suffix("/")
	var absolute: String = ProjectSettings.globalize_path(path).replace("\\", "/")
	if absolute.is_relative_path():
		absolute = project.path_join(absolute)
	absolute = absolute.simplify_path()
	var prefix: String = project + "/"
	var comparison: String = absolute
	if OS.get_name() == "Windows":
		prefix = prefix.to_lower()
		comparison = comparison.to_lower()
	if not comparison.begins_with(prefix):
		return ""
	return ProjectSettings.localize_path(absolute)


static func build_sprite_frames(manifest: Dictionary, atlas: Texture2D) -> Dictionary:
	if atlas == null:
		return {"error": "图集纹理为空"}
	var layout: Variant = manifest.get("frame_layout")
	var animation: Variant = manifest.get("animation")
	if not layout is Dictionary or not animation is Dictionary:
		return {"error": "缺少 frame_layout 或 animation"}
	var rows: Variant = layout.get("rows")
	var timings: Variant = animation.get("rows")
	if not rows is Dictionary or rows.is_empty() or not timings is Dictionary:
		return {"error": "动画行为空或格式错误"}
	if rows.size() != timings.size():
		return {"error": "frame_layout 与 animation 的状态不一致"}
	for dimension: String in ["sheetWidth", "sheetHeight"]:
		if not _integer(layout.get(dimension)) or int(layout[dimension]) <= 0:
			return {"error": "图集尺寸必须为正整数"}
	if int(layout["sheetWidth"]) != atlas.get_width() or int(layout["sheetHeight"]) != atlas.get_height():
		return {"error": "声明尺寸与图集实际尺寸不一致"}
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	var shared_regions: Dictionary = {}
	for state: Variant in rows:
		if not state is String or state.is_empty() or not timings.has(state):
			return {"error": "动画名称为空或缺少对应时序"}
		var rectangles: Variant = rows[state]
		var timing: Variant = timings[state]
		if not rectangles is Array or rectangles.is_empty() or not timing is Dictionary:
			return {"error": "%s 的帧或时序格式错误" % state}
		if not _positive_number(timing.get("fps")) or not timing.get("loop") is bool:
			return {"error": "%s 必须声明有效 fps 和布尔 loop" % state}
		if timing.has("frames") and (not _integer(timing["frames"]) or int(timing["frames"]) != rectangles.size()):
			return {"error": "%s 的帧计数与矩形数量不一致" % state}
		var durations: Variant = timing.get("durations_ms", [])
		if not durations is Array or (timing.has("durations_ms") and durations.size() != rectangles.size()):
			return {"error": "%s 的 durations_ms 数量不一致" % state}
		var fps: float = float(timing["fps"])
		var name := StringName(state)
		frames.add_animation(name)
		frames.set_animation_speed(name, fps)
		frames.set_animation_loop(name, bool(timing["loop"]))
		for index: int in rectangles.size():
			var entry: Variant = rectangles[index]
			if not entry is Dictionary:
				return {"error": "%s 帧 %d 不是矩形" % [state, index]}
			for key: String in ["x", "y", "w", "h"]:
				if not _integer(entry.get(key)):
					return {"error": "%s 帧 %d 的矩形坐标必须为整数" % [state, index]}
			var rectangle := Rect2i(int(entry["x"]), int(entry["y"]), int(entry["w"]), int(entry["h"]))
			if rectangle.position.x < 0 or rectangle.position.y < 0 or rectangle.size.x <= 0 or rectangle.size.y <= 0:
				return {"error": "%s 帧 %d 的矩形范围无效" % [state, index]}
			if rectangle.end.x > atlas.get_width() or rectangle.end.y > atlas.get_height():
				return {"error": "%s 帧 %d 超出图集" % [state, index]}
			var duration: float = 1.0
			if not durations.is_empty():
				if not _positive_number(durations[index]):
					return {"error": "%s 帧 %d 的时长无效" % [state, index]}
				# Godot 的相对时长 / fps = 秒；保留 manifest 的毫秒取整或非等时帧。
				duration = float(durations[index]) * fps / 1000.0
			if not shared_regions.has(rectangle):
				var region := AtlasTexture.new()
				region.atlas = atlas
				region.region = Rect2(rectangle)
				region.filter_clip = true
				shared_regions[rectangle] = region
			frames.add_frame(name, shared_regions[rectangle], duration)
	return {"frames": frames}


static func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value))


static func _positive_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) > 0.0
