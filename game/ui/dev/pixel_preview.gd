extends Control
## F6 运行。像素画面固定为 480×270，文字与剧情立绘绘制在原生画布上。

const PIXEL_SIZE := Vector2i(480, 270)
const DISPLAY_SCALE := 4
const IDS: Array[String] = ["zheng_zha", "zombie_scientist"]
const STATES: Array = [["idle", "attack", "hit", "down"], ["idle", "attack", "hit", "death"]]
const RANK_POSITIONS: Array = [
	[Vector2(84, 154), Vector2(116, 177), Vector2(148, 200)],
	[Vector2(348, 154), Vector2(316, 177), Vector2(284, 200)],
]

var pixel_viewport: SubViewport
var pixel_display: Sprite2D
var background: Sprite2D
var sprites: Array[AnimatedSprite2D] = []
var dialogue_layer: Control
var portrait: TextureRect
var dialogue_label: Label
var mode_button: Button
var state_index: int = 0
var dialogue_mode: bool = false
var ready_to_play: bool = false
var automatic: bool = true
var _remaining: float = 0.0
var _status: Label


func _ready() -> void:
	_build_pixel_layer()
	_build_native_ui()
	_load_assets()


func _build_pixel_layer() -> void:
	pixel_viewport = SubViewport.new()
	pixel_viewport.name = "PixelViewport"
	pixel_viewport.size = PIXEL_SIZE
	pixel_viewport.disable_3d = true
	pixel_viewport.transparent_bg = false
	pixel_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	pixel_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	pixel_viewport.snap_2d_transforms_to_pixel = true
	pixel_viewport.snap_2d_vertices_to_pixel = true
	add_child(pixel_viewport)
	background = Sprite2D.new()
	background.name = "Corridor"
	background.centered = false
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pixel_viewport.add_child(background)
	pixel_display = Sprite2D.new()
	pixel_display.name = "PixelDisplay"
	pixel_display.texture = pixel_viewport.get_texture()
	pixel_display.centered = false
	pixel_display.scale = Vector2.ONE * DISPLAY_SCALE
	pixel_display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(pixel_display)


func _load_assets() -> void:
	var background_path: String = "res://art/pixel_test/bg_lab_corridor_pixel.png"
	if not ResourceLoader.exists(background_path):
		_status.text = tr("像素背景未就绪，请先生成并导入素材。")
		return
	background.texture = load(background_path) as Texture2D
	if background.texture == null or background.texture.get_size() != Vector2(PIXEL_SIZE):
		_status.text = tr("像素背景必须为 480×270。")
		return
	var resources: Array[SpriteFrames] = []
	for character: int in IDS.size():
		var path: String = "res://art/pixel_test/%s/sprite_frames.tres" % IDS[character]
		if not ResourceLoader.exists(path):
			_status.text = tr("像素动作未就绪，请先运行图集导入工具。")
			return
		var frames := load(path) as SpriteFrames
		if frames == null:
			_status.text = tr("像素动作资源无法读取。")
			return
		for state: String in STATES[character]:
			if not frames.has_animation(state) or frames.get_frame_count(state) < 2:
				_status.text = tr("像素动作状态或帧数不完整。")
				return
		resources.append(frames)
	for character: int in IDS.size():
		for rank: int in 3:
			var sprite := AnimatedSprite2D.new()
			sprite.name = "%s_%d" % [IDS[character], rank]
			sprite.sprite_frames = resources[character]
			sprite.centered = false
			sprite.position = RANK_POSITIONS[character][rank]
			sprite.z_index = rank + 1
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			pixel_viewport.add_child(sprite)
			sprites.append(sprite)
	ready_to_play = true
	show_state(0)


func _process(delta: float) -> void:
	if ready_to_play and automatic:
		_remaining -= delta
		if _remaining <= 0.0:
			show_state(state_index + 1)


func show_state(index: int) -> void:
	if not ready_to_play:
		return
	state_index = posmod(index, 4)
	var labels: Array[String] = [tr("待机"), tr("攻击"), tr("受击"), tr("倒地 / 死亡")]
	_status.text = tr("当前动作：%s") % labels[state_index]
	_remaining = 0.0
	for character: int in IDS.size():
		var state := StringName(STATES[character][state_index])
		var frames: SpriteFrames = sprites[character * 3].sprite_frames
		var duration: float = 0.0
		for frame: int in frames.get_frame_count(state):
			duration += frames.get_frame_duration(state, frame) / frames.get_animation_speed(state)
		_remaining = maxf(_remaining, duration * (2.0 if frames.get_animation_loop(state) else 1.0) + 0.8)
		for rank: int in 3:
			var sprite: AnimatedSprite2D = sprites[character * 3 + rank]
			sprite.stop()
			sprite.play(state)


func set_dialogue_mode(value: bool) -> void:
	dialogue_mode = value
	dialogue_layer.visible = value
	mode_button.text = tr("返回战斗（D）") if value else tr("对话模式（D）")


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_D:
			set_dialogue_mode(not dialogue_mode)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_RIGHT:
			show_state(state_index + 1)
			get_viewport().set_input_as_handled()


func _build_native_ui() -> void:
	theme = Theme.new()
	theme.default_font_size = 28
	var header := ColorRect.new()
	header.color = Color(0.025, 0.035, 0.055, 0.8)
	header.size = Vector2(1920, 116)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header)
	_add_label(self, tr("研究所 · 像素风格试验"), Rect2(40, 20, 1000, 44), 32)
	_status = _add_label(self, tr("正在准备素材"), Rect2(40, 68, 1100, 34), 24)
	dialogue_layer = Control.new()
	dialogue_layer.name = "NativeDialogue"
	dialogue_layer.size = Vector2(1920, 1080)
	dialogue_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dialogue_layer)
	var dimmer := ColorRect.new()
	dimmer.name = "Dimmer"
	dimmer.size = Vector2(1920, 1080)
	dimmer.color = Color(0.015, 0.025, 0.05, 0.67)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_layer.add_child(dimmer)
	portrait = TextureRect.new()
	portrait.name = "CalmPortrait"
	portrait.position = Vector2(42, 132)
	portrait.size = Vector2(624, 936)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait_path: String = "res://art/style_test/zheng_zha_portrait_calm.png"
	if ResourceLoader.exists(portrait_path):
		portrait.texture = load(portrait_path) as Texture2D
	dialogue_layer.add_child(portrait)
	var dialogue_box := Panel.new()
	dialogue_box.name = "DialogueBox"
	dialogue_box.position = Vector2(666, 714)
	dialogue_box.size = Vector2(1198, 312)
	dialogue_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("111b29", 0.97)
	panel_style.border_color = Color("71899b")
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	dialogue_box.add_theme_stylebox_override("panel", panel_style)
	dialogue_layer.add_child(dialogue_box)
	_add_label(dialogue_box, tr("郑吒"), Rect2(40, 30, 1118, 50), 32)
	dialogue_label = _add_label(dialogue_box, tr("这是……什么地方？"), Rect2(40, 114, 1118, 88), 42)
	_add_label(dialogue_box, tr("按 D 或点击右上角返回战斗"), Rect2(40, 244, 1118, 36), 22)
	mode_button = Button.new()
	mode_button.name = "ModeButton"
	mode_button.position = Vector2(1512, 28)
	mode_button.custom_minimum_size = Vector2(360, 64)
	mode_button.size = Vector2(360, 64)
	mode_button.pressed.connect(func() -> void: set_dialogue_mode(not dialogue_mode))
	add_child(mode_button)
	set_dialogue_mode(false)


func _add_label(parent: Node, text: String, rectangle: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rectangle.position
	label.size = rectangle.size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
