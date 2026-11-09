extends Control
## 剧情插图（CG）覆盖层：铺满全屏的图 + 一句字幕，任意键或点击继续。
## 图来自 `res://art/cg/<name>.png`；没有这张图时 main 会直接跳过，不弹这个层。

signal finished

const UiTheme = preload("res://ui/ui_theme.gd")
const PortraitSource = preload("res://core/art/portrait_source.gd")

var art: TextureRect
var caption: Label
var hint: Label
var cg_name: String = ""
var _can_close := false
var _built := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	build()


## 幂等；测试里直接调。
func build() -> void:
	if _built:
		return
	_built = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.96)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)

	art = TextureRect.new()
	art.position = Vector2.ZERO
	art.size = Vector2(1920, 1080)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)

	var band := ColorRect.new()
	band.color = Color(0, 0, 0, 0.62)
	band.position = Vector2(0, 892)
	band.size = Vector2(1920, 188)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)

	caption = UiTheme.label("", 25, UiTheme.TEXT)
	caption.position = Vector2(160, 936)
	caption.size = Vector2(1600, 76)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)

	hint = UiTheme.label("点击或按任意键继续", 17, UiTheme.MUTED)
	hint.position = Vector2(1500, 1018)
	hint.size = Vector2(360, 28)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	hint.visible = false


func open_for(name: String, text: String) -> void:
	build()
	cg_name = name
	art.texture = PortraitSource.cg(name)
	caption.text = text
	hint.visible = false
	_can_close = false
	show()
	# 只淡入画本身，底色始终不透明——否则下层界面会透过来。
	art.modulate.a = 0.0
	if is_inside_tree():
		var t := create_tween()
		t.tween_property(art, "modulate:a", 1.0, 0.3)
		t.tween_callback(func() -> void:
			_can_close = true
			hint.visible = true)
	else:
		art.modulate.a = 1.0
		_can_close = true
		hint.visible = true


## 供测试与验收脚本调用：直接关掉。
func press_continue() -> void:
	finished.emit()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and _can_close:
		accept_event()
		press_continue()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and _can_close:
		accept_event()
		press_continue()
