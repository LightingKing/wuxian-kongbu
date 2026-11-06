extends Control
## F6 运行此场景。动画数据来自导入后的 SpriteFrames，预览不改写战斗规则。

const CHARACTER_IDS: Array[String] = ["zheng_zha", "zombie_scientist"]
const STATES: Array = [["idle", "attack", "hit", "down"], ["idle", "attack", "hit", "death"]]

var sprites: Array[AnimatedSprite2D] = []
var state_index: int = 0
var paused: bool = false
var automatic: bool = true
var ready_to_play: bool = false
var _remaining: float = 0.0
var _state_label: Label
var _frame_labels: Array[Label] = []
var _pause_button: Button
var _resume_after_pause: Array[bool] = []


func _ready() -> void:
	_build_ui()
	for index: int in CHARACTER_IDS.size():
		var path: String = "res://art/style_test/anim/%s/sprite_frames.tres" % CHARACTER_IDS[index]
		if not ResourceLoader.exists(path):
			_state_label.text = tr("动画资源未就绪，请先完成素材生成和导入。")
			return
		var frames := ResourceLoader.load(path) as SpriteFrames
		if frames == null:
			_state_label.text = tr("动画资源无法读取。")
			return
		for state: String in STATES[index]:
			if not frames.has_animation(state) or frames.get_frame_count(state) == 0:
				_state_label.text = tr("动画状态不完整。")
				return
		var sprite := AnimatedSprite2D.new()
		sprite.name = CHARACTER_IDS[index]
		sprite.sprite_frames = frames
		sprite.centered = false
		var maximum := Vector2.ZERO
		for state: StringName in frames.get_animation_names():
			for frame: int in frames.get_frame_count(state):
				maximum = maximum.max(frames.get_frame_texture(state, frame).get_size())
		var fit_scale: float = minf(1.0, minf(800.0 / maximum.x, 740.0 / maximum.y))
		sprite.scale = Vector2.ONE * fit_scale
		sprite.position = Vector2(492.0 + index * 936.0 - maximum.x * fit_scale / 2.0, 906.0 - maximum.y * fit_scale)
		add_child(sprite)
		sprites.append(sprite)
		_resume_after_pause.append(false)
	ready_to_play = true
	show_state(0)


func _process(delta: float) -> void:
	if not ready_to_play:
		return
	for index: int in sprites.size():
		var sprite: AnimatedSprite2D = sprites[index]
		_frame_labels[index].text = tr("第 %d / %d 帧") % [sprite.frame + 1, sprite.sprite_frames.get_frame_count(sprite.animation)]
	if not paused and automatic:
		_remaining -= delta
		if _remaining <= 0.0:
			show_state((state_index + 1) % 4)


func show_state(index: int) -> void:
	if not ready_to_play:
		return
	state_index = posmod(index, 4)
	var labels: Array[String] = [tr("待机"), tr("攻击"), tr("受击"), tr("倒地 / 死亡")]
	_state_label.text = labels[state_index]
	_remaining = 0.0
	for character: int in sprites.size():
		var sprite: AnimatedSprite2D = sprites[character]
		var state := StringName(STATES[character][state_index])
		var frames: SpriteFrames = sprite.sprite_frames
		var length: float = 0.0
		for frame: int in frames.get_frame_count(state):
			length += frames.get_frame_duration(state, frame) / frames.get_animation_speed(state)
		_remaining = maxf(_remaining, length * (2.0 if frames.get_animation_loop(state) else 1.0) + 0.75)
		sprite.stop()
		sprite.play(state)
		_resume_after_pause[character] = paused
		if paused:
			sprite.pause()


func set_paused(value: bool) -> void:
	if paused == value:
		return
	paused = value
	_pause_button.text = tr("继续") if paused else tr("暂停")
	for index: int in sprites.size():
		var sprite: AnimatedSprite2D = sprites[index]
		if paused:
			_resume_after_pause[index] = sprite.is_playing()
			sprite.pause()
		elif _resume_after_pause[index]:
			sprite.play()
			_resume_after_pause[index] = false


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			set_paused(not paused)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_RIGHT:
			show_state(state_index + 1)
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	theme = Theme.new()
	theme.default_font_size = 24
	var background := ColorRect.new()
	background.color = Color("181a20")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_add_label(tr("战斗动作试验"), Rect2(48, 24, 1824, 48), 32)
	_add_label(tr("郑吒"), Rect2(48, 88, 888, 40), 26)
	_add_label(tr("研究员丧尸"), Rect2(984, 88, 888, 40), 26)
	for index: int in 2:
		var panel := ColorRect.new()
		panel.position = Vector2(48 + index * 936, 140)
		panel.size = Vector2(888, 770)
		panel.color = Color("242730")
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(panel)
		_frame_labels.append(_add_label("", Rect2(48 + index * 936, 912, 888, 32), 20))
	_state_label = _add_label(tr("正在准备"), Rect2(48, 956, 420, 64), 28)
	var controls := HBoxContainer.new()
	controls.position = Vector2(540, 956)
	controls.add_theme_constant_override("separation", 24)
	add_child(controls)
	_pause_button = Button.new()
	_pause_button.text = tr("暂停")
	_pause_button.custom_minimum_size = Vector2(220, 64)
	_pause_button.pressed.connect(func() -> void: set_paused(not paused))
	controls.add_child(_pause_button)
	var next := Button.new()
	next.text = tr("下个动作")
	next.custom_minimum_size = Vector2(220, 64)
	next.pressed.connect(func() -> void: show_state(state_index + 1))
	controls.add_child(next)
	var autoplay := CheckButton.new()
	autoplay.text = tr("自动轮播")
	autoplay.button_pressed = true
	autoplay.custom_minimum_size = Vector2(240, 64)
	autoplay.toggled.connect(func(value: bool) -> void: automatic = value)
	controls.add_child(autoplay)
	_add_label(tr("空格：暂停或继续    →：下个动作"), Rect2(48, 1032, 1824, 28), 18)


func _add_label(text: String, rectangle: Rect2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rectangle.position
	label.size = rectangle.size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	return label
