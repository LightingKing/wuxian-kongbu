extends Control
## 对话框（覆盖在远征/主神空间之上）：只管画、收输入、发信号，台词与检定都在 core/dialogue。
## 两种模式：talk（自由说话，NPC 回一句）和 persuade（玩家说一段，评说服力等级）。
## 候选回复是给手机用的：点一句就当自己说的话，不用打字。

signal submitted(text: String)
signal persuading(text: String)
signal reply_picked(text: String)
signal closed

const UiTheme = preload("res://ui/ui_theme.gd")
const PixelArt = preload("res://core/art/pixel_art.gd")
const PortraitSource = preload("res://core/art/portrait_source.gd")

var panel: Panel
var title_label: Label
var sub_label: Label
var log_label: RichTextLabel
var reply_box: HBoxContainer
var input: LineEdit
var send_button: Button
var status_label: Label
## 右侧立绘位：现在放放大后的像素头像占位，等 Codex 的剧情立绘到位后换成贴图。
var portrait: TextureRect
var portrait_caption: Label
var mode: String = "talk"
var _lines: Array[String] = []
var _built := false


func _ready() -> void:
	build()


## 幂等：界面里 _ready 调一次，测试里直接调。
func build() -> void:
	if _built:
		return
	_built = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var mask := ColorRect.new()
	mask.color = Color(0, 0, 0, 0.78)
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(mask)

	panel = Panel.new()
	panel.position = Vector2(340, 130)
	panel.size = Vector2(1240, 800)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PANEL, UiTheme.LINE, 10))
	add_child(panel)

	title_label = UiTheme.label("", 28, UiTheme.ACCENT2)
	title_label.position = Vector2(28, 20)
	title_label.size = Vector2(900, 38)
	panel.add_child(title_label)
	sub_label = UiTheme.label("", 16, UiTheme.MUTED)
	sub_label.position = Vector2(30, 58)
	sub_label.size = Vector2(1000, 24)
	panel.add_child(sub_label)

	var close_button := UiTheme.button("×", 24)
	close_button.position = Vector2(1150, 18)
	close_button.size = Vector2(60, 48)
	close_button.pressed.connect(_on_close)
	panel.add_child(close_button)

	log_label = UiTheme.rich(21)
	log_label.bbcode_enabled = true
	log_label.position = Vector2(28, 96)
	log_label.size = Vector2(800, 470)
	panel.add_child(log_label)

	reply_box = HBoxContainer.new()
	reply_box.position = Vector2(28, 578)
	reply_box.size = Vector2(800, 56)
	reply_box.add_theme_constant_override("separation", 10)
	panel.add_child(reply_box)

	input = LineEdit.new()
	input.position = Vector2(28, 650)
	input.size = Vector2(600, 54)
	input.placeholder_text = "说点什么……"
	input.add_theme_font_size_override("font_size", 20)
	input.text_submitted.connect(func(_t: String) -> void: _on_send())
	panel.add_child(input)

	send_button = UiTheme.button("说", 21)
	send_button.position = Vector2(644, 650)
	send_button.size = Vector2(184, 54)
	send_button.pressed.connect(_on_send)
	panel.add_child(send_button)

	status_label = UiTheme.label("", 16, UiTheme.MUTED)
	status_label.position = Vector2(28, 722)
	status_label.size = Vector2(800, 24)
	panel.add_child(status_label)

	var frame := Panel.new()
	frame.position = Vector2(856, 96)
	frame.size = Vector2(356, 650)
	frame.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.DARK, UiTheme.LINE, 8))
	panel.add_child(frame)
	portrait = TextureRect.new()
	portrait.position = Vector2(14, 14)
	portrait.size = Vector2(328, 492)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(portrait)
	portrait_caption = UiTheme.label("", 15, UiTheme.MUTED)
	portrait_caption.position = Vector2(14, 516)
	portrait_caption.size = Vector2(328, 110)
	frame.add_child(portrait_caption)


## 打开对话框：清空记录、设定称呼与副标题。
func open_for(title: String, subtitle: String, dialogue_mode: String = "talk") -> void:
	build()
	_lines.clear()
	log_label.text = ""
	clear_replies()
	title_label.text = title
	sub_label.text = subtitle
	set_mode(dialogue_mode)
	set_status("")
	set_portrait("")
	show()
	if is_inside_tree():
		input.grab_focus()


func set_mode(dialogue_mode: String) -> void:
	mode = dialogue_mode
	if send_button != null:
		send_button.text = "说服" if mode == "persuade" else "说"
		input.placeholder_text = "想好怎么说……（说辞越切中要害，说服力越高）" if mode == "persuade" else "说点什么……"


## 追加一句。子串里带 [ 或 ] 会被当 BBCode，先转义。
func push(speaker: String, text: String) -> void:
	build()
	var safe := text.replace("[", "［").replace("]", "］")
	var who := "[color=#e0a458]%s[/color]" % speaker.replace("[", "［").replace("]", "］")
	_lines.append("%s\n%s" % [who, safe])
	log_label.text = "\n\n".join(_lines)


func set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


## 候选回复按钮；点一下等于说这句话。
func set_replies(list: Array) -> void:
	build()
	clear_replies()
	for r in list:
		var text := String(r)
		var b := UiTheme.button(text, 17)
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			reply_picked.emit(text)
			_on_send(text)
		)
		reply_box.add_child(b)


func clear_replies() -> void:
	if reply_box == null:
		return
	for c in reply_box.get_children():
		reply_box.remove_child(c)
		c.queue_free()


func _on_send(forced: String = "") -> void:
	var text := forced.strip_edges() if forced != "" else String(input.text).strip_edges()
	if text == "":
		return
	input.text = ""
	if mode == "persuade":
		persuading.emit(text)
	else:
		submitted.emit(text)


## 立绘位：有正式立绘（res://art/portraits/<id>.png）就用，没有退回像素头像。
func set_portrait(id: String) -> void:
	build()
	if id == "":
		portrait.texture = null
		portrait_caption.text = ""
		return
	portrait.texture = PortraitSource.portrait(id)
	if PortraitSource.has_portrait(id):
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		portrait_caption.text = "%s\n\n半身立绘 512×768" % id
	else:
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait_caption.text = "%s\n\n立绘位（%d×%d 像素头像占位）\n正式立绘 512×768 · 待生成" % [id, PixelArt.UNIT_SIZE, PixelArt.UNIT_SIZE]


## 供测试与验收脚本用：等于点了"说"。
func press_send(text: String = "") -> void:
	_on_send(text)


## 供测试与验收脚本用：点第 index 个候选回复。
func press_reply(index: int) -> void:
	if reply_box == null or index < 0 or index >= reply_box.get_child_count():
		return
	var b: Button = reply_box.get_child(index)
	b.pressed.emit()


func press_close() -> void:
	_on_close()


func _on_close() -> void:
	hide()
	closed.emit()
