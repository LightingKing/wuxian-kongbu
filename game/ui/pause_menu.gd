extends Control
## 暂停菜单（游戏内按 Esc）：继续、存到三个槽、从槽读取、回标题、退出。
## 只发信号；存读档的实做在 main.gd，菜单只负责显示摘要。

signal resume
signal save_slot(slot: int)
signal load_slot(slot: int)
signal to_title
signal quit_game

const UiTheme = preload("res://ui/ui_theme.gd")
const Slots = preload("res://core/save/slots.gd")

var status_label: Label
var slot_labels: Array[Label] = []
var save_buttons: Array[Button] = []
var load_buttons: Array[Button] = []
var panel: Panel
var _built := false
## 存读档那一块（铁人模式整块藏起来）。
var slot_section: Array[Control] = []
var iron_label: Label


func _ready() -> void:
	build()


func build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mask := ColorRect.new()
	mask.color = Color(0, 0, 0, 0.62)
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(mask)

	panel = Panel.new()
	panel.position = Vector2(600, 250)
	panel.size = Vector2(720, 560)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PANEL, UiTheme.LINE, 10))
	add_child(panel)

	var box := VBoxContainer.new()
	box.position = Vector2(30, 24)
	box.size = Vector2(660, 512)
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(UiTheme.label(tr("暂停"), 30, UiTheme.ACCENT2))

	var resume_button := UiTheme.button(tr("继续游戏"), 22)
	resume_button.custom_minimum_size = Vector2(300, 56)
	resume_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	resume_button.pressed.connect(press_resume)
	box.add_child(resume_button)

	iron_label = UiTheme.label(tr("铁人模式：游戏自动保存，不能手动存档或读档。"), 18, UiTheme.MUTED)
	iron_label.visible = false
	box.add_child(iron_label)
	var save_title := UiTheme.label(tr("保存到"), 18, UiTheme.MUTED)
	box.add_child(save_title)
	slot_section.append(save_title)
	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 10)
	for i in range(1, Slots.COUNT + 1):
		var b := UiTheme.button(tr("槽 %d") % i, 18)
		b.custom_minimum_size = Vector2(120, 48)
		b.pressed.connect(press_save.bind(i))
		save_row.add_child(b)
		save_buttons.append(b)
	box.add_child(save_row)
	slot_section.append(save_row)

	var load_title := UiTheme.label(tr("读取"), 18, UiTheme.MUTED)
	box.add_child(load_title)
	slot_section.append(load_title)
	var load_row := HBoxContainer.new()
	load_row.add_theme_constant_override("separation", 10)
	for i in range(1, Slots.COUNT + 1):
		var b := UiTheme.button(tr("槽 %d") % i, 18)
		b.custom_minimum_size = Vector2(120, 48)
		b.pressed.connect(press_load.bind(i))
		load_row.add_child(b)
		load_buttons.append(b)
	box.add_child(load_row)
	slot_section.append(load_row)

	for i in range(1, Slots.COUNT + 1):
		var l := UiTheme.label(tr(""), 16, UiTheme.MUTED)
		l.custom_minimum_size = Vector2(660, 22)
		box.add_child(l)
		slot_labels.append(l)
		slot_section.append(l)

	status_label = UiTheme.label(tr(""), 18, UiTheme.ACCENT2)
	status_label.custom_minimum_size = Vector2(660, 26)
	box.add_child(status_label)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	var title_button := UiTheme.button(tr("回标题"), 20)
	title_button.custom_minimum_size = Vector2(180, 52)
	title_button.pressed.connect(press_title)
	bottom.add_child(title_button)
	var quit_button := UiTheme.button(tr("退出游戏"), 20)
	quit_button.custom_minimum_size = Vector2(180, 52)
	quit_button.pressed.connect(press_quit)
	bottom.add_child(quit_button)
	box.add_child(bottom)


## 打开时刷新三个槽的摘要；调用方可以顺带给一句状态（例如"已保存"）。
func open_for(status: String = "") -> void:
	build()
	visible = true
	refresh()
	set_status(status if status != "" else "Esc 关闭菜单")


func refresh() -> void:
	if not _built:
		return
	for row: Dictionary in Slots.all_summaries():
		var i := int(row["slot"]) - 1
		var text := "槽 %d　%s" % [int(row["slot"]), String(row["label"])]
		if bool(row["exists"]):
			text += "　%s" % String(row["saved_at"])
		slot_labels[i].text = text
		load_buttons[i].disabled = not bool(row["exists"])


## 铁人模式：藏起存读档，只留继续、回标题、退出。
func set_iron_man(on: bool) -> void:
	build()
	for c in slot_section:
		c.visible = not on
	iron_label.visible = on
	panel.size = Vector2(720, 300) if on else Vector2(720, 560)
	panel.position = Vector2(600, 390) if on else Vector2(600, 250)


func set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func press_resume() -> void:
	visible = false
	resume.emit()


func press_save(slot: int) -> void:
	if not Slots.valid(slot) or iron_label.visible:
		return
	save_slot.emit(slot)
	refresh()


func press_load(slot: int) -> void:
	if iron_label.visible or not bool(Slots.summary(slot)["exists"]):
		return
	visible = false
	load_slot.emit(slot)


func press_title() -> void:
	visible = false
	to_title.emit()


func press_quit() -> void:
	quit_game.emit()
