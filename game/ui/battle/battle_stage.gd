extends Control
## 像素战斗舞台（设计规格 11）：480×270 的 SubViewport，最近邻、整数放大 4 倍铺满 1920×1080。
## 像素层里只有背景和小人；脚下的血条和当前行动者的名字画在原生分辨率的覆盖层上，保证中文清晰
## （人多时名字会挤成一团，所以只给轮到的那个人标名字，其余的看两侧名单）。
## 只读 BattleView 给的单位列表，按战斗事件播动作（出手前冲、受击闪白后仰、治疗泛绿、倒地），不碰规则。

const SpriteSource = preload("res://ui/battle/sprite_source.gd")
const UiTheme = preload("res://ui/ui_theme.gd")

const PIXEL_SIZE := Vector2i(480, 270)
const SCALE := 4
## 站位（像素层坐标，脚底点）：前排离中线近；同一排往下、往外错开，表现纵深。
const ALLY_FRONT_X := 196.0
const ENEMY_FRONT_X := 284.0
const ROW_GAP := 52.0
const SLOT_DX := 14.0
const SLOT_DY := 17.0
const FOOT_Y := 190.0
## 图集单帧是正方形（人形 48×48，大型敌人更大），四边留 8px 安全边、脚踩在底边往上 8px（任务卡 003 的统一基线：48 格脚在第 40 行）。
const CELL := 48
const CELL_MARGIN := 8.0
## 每一步动作的时长（秒）。
const STEP := 0.09

var viewport: SubViewport
var display: TextureRect
var background: Sprite2D
var shade: CanvasModulate
var overlay: Control
## 单位 id → AnimatedSprite2D / {"name": Label, "hp": ProgressBar} / 脚底点（像素层）/ 朝向（我方 1、敌方 −1）。
var sprites: Dictionary = {}
var tags: Dictionary = {}
var feet: Dictionary = {}
var facing: Dictionary = {}
## dead：已经知道不在场的单位（逻辑）；laid：已经摆成倒地姿势的（画面）。动画播完前两者可能不一致。
var dead: Dictionary = {}
var laid: Dictionary = {}
var _tween: Tween


## units：BattleView.units() 的结果；location：战斗地点（选背景）；dark：黑暗中的战斗整体压暗。
func setup(units: Array[Dictionary], location: String = "", dark: bool = false) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.size = PIXEL_SIZE
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.snap_2d_transforms_to_pixel = true
	viewport.snap_2d_vertices_to_pixel = true
	add_child(viewport)
	background = Sprite2D.new()
	background.centered = false
	background.texture = SpriteSource.background(location)
	viewport.add_child(background)
	shade = CanvasModulate.new()
	shade.color = Color(0.5, 0.5, 0.62) if dark else Color.WHITE
	viewport.add_child(shade)
	display = TextureRect.new()
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.position = Vector2.ZERO
	display.size = Vector2(PIXEL_SIZE * SCALE)
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	_place_units(units)
	sync(units)


## 每排一个 slot 计数：前排 row 0 离中线最近。
static func foot_of(side: String, row: int, slot: int) -> Vector2:
	if side == "ally":
		return Vector2(ALLY_FRONT_X - row * ROW_GAP - slot * SLOT_DX, FOOT_Y + slot * SLOT_DY)
	return Vector2(ENEMY_FRONT_X + row * ROW_GAP + slot * SLOT_DX, FOOT_Y + slot * SLOT_DY)


func _place_units(units: Array[Dictionary]) -> void:
	var slots := {}
	for u: Dictionary in units:
		var id := String(u["id"])
		var side := String(u["side"])
		var row := int(u["row"])
		var k := "%s:%d" % [side, row]
		var slot := int(slots.get(k, 0))
		slots[k] = slot + 1
		var foot := foot_of(side, row, slot)
		feet[id] = foot
		facing[id] = 1.0 if side == "ally" else -1.0
		var key := SpriteSource.key_of(id, String(u.get("character_id", "")), String(u.get("def_id", "")), side)
		var s := AnimatedSprite2D.new()
		s.name = id
		s.sprite_frames = SpriteSource.frames(key, side)
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = _sprite_origin(s, foot)
		s.z_index = int(foot.y)
		s.play("idle")
		viewport.add_child(s)
		sprites[id] = s
		var hp := UiTheme.bar(UiTheme.OK, 6)
		hp.size = Vector2(80, 6)
		hp.position = Vector2(foot.x * SCALE - 40.0, foot.y * SCALE + 4.0)
		overlay.add_child(hp)
		var name := UiTheme.label(String(u["name"]), 16, UiTheme.ACCENT2)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.size = Vector2(160, 22)
		name.position = Vector2(foot.x * SCALE - 80.0, foot.y * SCALE + 12.0)
		name.visible = false
		overlay.add_child(name)
		tags[id] = {"name": name, "hp": hp}


## 图集帧（正方形、至少 48）按统一脚底基线对齐；代码画的静态帧按底边对齐。
func _sprite_origin(s: AnimatedSprite2D, foot: Vector2) -> Vector2:
	var tex := s.sprite_frames.get_frame_texture("idle", 0)
	var size := tex.get_size() if tex != null else Vector2(CELL, CELL)
	if int(size.x) == int(size.y) and int(size.x) >= CELL:
		return foot - Vector2(size.x / 2.0, size.y - CELL_MARGIN)
	return foot - Vector2(size.x / 2.0, size.y)


## 按单位列表刷新血条、名字颜色、当前行动者高亮；死了的摆成倒地姿势。
func sync(units: Array[Dictionary]) -> void:
	for u: Dictionary in units:
		var id := String(u["id"])
		if not tags.has(id):
			continue
		var hp: ProgressBar = tags[id]["hp"]
		hp.max_value = maxf(float(u["hp_max"]), 1.0)
		hp.value = maxf(float(u["hp"]), 0.0)
		hp.add_theme_stylebox_override("fill", UiTheme.bar_fill(UiTheme.ACCENT if hp.value / hp.max_value < 0.3 else UiTheme.OK))
		var name: Label = tags[id]["name"]
		var gone := not bool(u["alive"]) or bool(u.get("fled", false))
		name.visible = bool(u["current"])
		hp.visible = not gone
		if gone and not dead.has(id):
			dead[id] = true
			# 动画还在播：等它播到这里再倒下，免得受击闪色把倒地的灰色冲掉。
			if _tween != null and _tween.is_valid() and _tween.is_running():
				_tween.tween_callback(_lay_down.bind(id, bool(u.get("fled", false))))
			else:
				_lay_down(id, bool(u.get("fled", false)))


## 按一批战斗事件播动作；不在场景树里（无界面测试）时直接跳过，状态由 sync 摆正。
func play(events: Array) -> void:
	if not is_inside_tree():
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	var steps := 0
	for e: Dictionary in events.slice(maxi(0, events.size() - 30)):
		match String(e.get("type", "")):
			"action":
				var act: Dictionary = e.get("action", {})
				if String(act.get("type", "")) == "skill":
					steps += _lunge(String(e["unit"]))
			"damage":
				steps += _flash(String(e["target"]), Color(2.2, 2.2, 2.2), true)
			"heal":
				steps += _flash(String(e["target"]), Color(0.6, 1.8, 0.7), false)
			"death":
				var id := String(e["target"])
				if sprites.has(id) and not laid.has(id):
					_tween.tween_callback(_lay_down.bind(id, false))
					steps += 1
	if steps == 0:
		_tween.kill()
		return
	_tween.tween_callback(_back_to_idle)


func _lunge(id: String) -> int:
	if not sprites.has(id) or laid.has(id):
		return 0
	var s: AnimatedSprite2D = sprites[id]
	var home := _sprite_origin(s, feet[id])
	_tween.tween_callback(s.play.bind(SpriteSource.action_name(s.sprite_frames, "attack")))
	_tween.tween_property(s, "position", home + Vector2(6.0 * float(facing[id]), 0.0), STEP)
	_tween.tween_property(s, "position", home, STEP)
	return 1


func _flash(id: String, color: Color, knock: bool) -> int:
	if not sprites.has(id) or laid.has(id):
		return 0
	var s: AnimatedSprite2D = sprites[id]
	var home := _sprite_origin(s, feet[id])
	if knock:
		_tween.tween_callback(s.play.bind(SpriteSource.action_name(s.sprite_frames, "hit")))
	_tween.tween_property(s, "modulate", color, STEP * 0.5)
	if knock:
		_tween.parallel().tween_property(s, "position", home - Vector2(3.0 * float(facing[id]), 0.0), STEP * 0.5)
	_tween.tween_property(s, "modulate", Color.WHITE, STEP)
	if knock:
		_tween.parallel().tween_property(s, "position", home, STEP)
	return 1


## 倒地：有逐帧动作就播 down/death；静态帧就转 90° 压暗。逃走的人直接淡出。
func _lay_down(id: String, fled: bool) -> void:
	if not sprites.has(id) or laid.has(id):
		return
	dead[id] = true
	laid[id] = true
	var s: AnimatedSprite2D = sprites[id]
	if fled:
		s.visible = false
		return
	if SpriteSource.animated(s.sprite_frames):
		var anim := SpriteSource.action_name(s.sprite_frames, "down")
		s.sprite_frames.set_animation_loop(anim, false)
		s.play(anim)
	else:
		s.rotation_degrees = -90.0 * float(facing[id])
		s.position = feet[id] - Vector2(0.0, 6.0)
	s.modulate = Color(0.55, 0.55, 0.6)


func _back_to_idle() -> void:
	for id: String in sprites:
		if not dead.has(id):
			var s: AnimatedSprite2D = sprites[id]
			s.play("idle")
			s.position = _sprite_origin(s, feet[id])
			s.modulate = Color.WHITE
