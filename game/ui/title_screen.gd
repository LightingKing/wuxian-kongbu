extends Control
## PC 版标题画面：新游戏（先选铁人或宽松）/ 继续（三个存档槽）/ 设置 / 退出。
## 只发信号，不碰 Session；开新游戏、读档、退出的实做在 main.gd。

## iron_man：铁人模式（一个自动存档，不能手动存读，全灭删档）。
signal new_game(iron_man: bool)
signal load_slot(slot: int)
signal quit_game
signal settings_changed(settings: Dictionary)

const UiTheme = preload("res://ui/ui_theme.gd")
const Slots = preload("res://core/save/slots.gd")
const Settings = preload("res://core/settings/settings.gd")

const VERSION_TEXT := "v0.1.0 · 计划 10"

var menu_box: VBoxContainer
var slot_panel: Control
var slot_box: VBoxContainer
var settings_panel: Control
var mode_panel: Control
var mode_button: Button
var volume_label: Label
var hint_label: Label
var settings: Dictionary = Settings.defaults()
var _built := false


func _ready() -> void:
	build()


## 幂等：界面里 _ready 调一次，测试里直接调。
func build() -> void:
	if _built:
		return
	_built = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiTheme.paint_bg(self)

	var title := UiTheme.label("无限恐怖", 84, UiTheme.ACCENT2)
	title.position = Vector2(0, 200)
	title.size = Vector2(1920, 110)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var sub := UiTheme.label("2D 回合制同人游戏 · 第一阶段《生化危机一》", 22, UiTheme.MUTED)
	sub.position = Vector2(0, 312)
	sub.size = Vector2(1920, 34)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	var rule := ColorRect.new()
	rule.color = UiTheme.LINE
	rule.position = Vector2(830, 372)
	rule.size = Vector2(260, 2)
	add_child(rule)

	menu_box = VBoxContainer.new()
	menu_box.position = Vector2(730, 420)
	menu_box.size = Vector2(460, 304)
	menu_box.add_theme_constant_override("separation", 16)
	add_child(menu_box)

	_add_menu("新游戏", press_new)
	_add_menu("继续游戏", open_slots)
	_add_menu("设置", open_settings)
	_add_menu("退出游戏", press_quit)

	var ver := UiTheme.label(VERSION_TEXT, 16, UiTheme.MUTED)
	ver.position = Vector2(60, 1012)
	ver.size = Vector2(600, 24)
	add_child(ver)

	hint_label = UiTheme.label("", 16, UiTheme.MUTED)
	hint_label.position = Vector2(1260, 1012)
	hint_label.size = Vector2(600, 24)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(hint_label)

	_build_slots()
	_build_settings()
	_build_mode()
	set_hint("Enter 确认 · Esc 返回")


func _add_menu(text: String, handler: Callable) -> Button:
	var b := UiTheme.button(text, 24)
	b.custom_minimum_size = Vector2(460, 64)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(handler)
	menu_box.add_child(b)
	return b


func _build_slots() -> void:
	slot_panel = _overlay(900, 560)
	var box := VBoxContainer.new()
	box.position = Vector2(30, 24)
	box.size = Vector2(840, 500)
	box.add_theme_constant_override("separation", 12)
	slot_panel.add_child(box)
	box.add_child(UiTheme.label("选择存档", 28, UiTheme.ACCENT2))
	slot_box = VBoxContainer.new()
	slot_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot_box.add_theme_constant_override("separation", 10)
	box.add_child(slot_box)
	var back := UiTheme.button("返回", 20)
	back.custom_minimum_size = Vector2(140, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(close_slots)
	box.add_child(back)


## 新游戏先选存档方式（设计规格 7.7：推荐铁人模式，另给想体验剧情的人一个宽松选项）。
func _build_mode() -> void:
	mode_panel = _overlay(900, 420)
	var box := VBoxContainer.new()
	box.position = Vector2(30, 24)
	box.size = Vector2(840, 360)
	box.add_theme_constant_override("separation", 14)
	mode_panel.add_child(box)
	box.add_child(UiTheme.label("选择存档方式", 28, UiTheme.ACCENT2))
	var iron := UiTheme.button("铁人模式（推荐）：只有一个自动存档，不能读档重来，全员死亡就删档", 20)
	iron.custom_minimum_size = Vector2(840, 64)
	iron.pressed.connect(press_mode.bind(true))
	box.add_child(iron)
	var loose := UiTheme.button("宽松模式：三个手动存档槽，随时存读，想看剧情选这个", 20)
	loose.custom_minimum_size = Vector2(840, 64)
	loose.pressed.connect(press_mode.bind(false))
	box.add_child(loose)
	var back := UiTheme.button("返回", 20)
	back.custom_minimum_size = Vector2(140, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(close_mode)
	box.add_child(back)


func _build_settings() -> void:
	settings_panel = _overlay(760, 420)
	var box := VBoxContainer.new()
	box.position = Vector2(30, 24)
	box.size = Vector2(700, 360)
	box.add_theme_constant_override("separation", 16)
	settings_panel.add_child(box)
	box.add_child(UiTheme.label("设置", 28, UiTheme.ACCENT2))

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 12)
	mode_row.add_child(UiTheme.label("窗口", 20))
	mode_button = UiTheme.button("", 20)
	mode_button.custom_minimum_size = Vector2(220, 48)
	mode_button.pressed.connect(toggle_mode)
	mode_row.add_child(mode_button)
	box.add_child(mode_row)

	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 12)
	vol_row.add_child(UiTheme.label("主音量", 20))
	var down := UiTheme.button("−", 20)
	down.custom_minimum_size = Vector2(64, 48)
	down.pressed.connect(volume_down)
	vol_row.add_child(down)
	volume_label = UiTheme.label("", 20, UiTheme.ACCENT2)
	volume_label.custom_minimum_size = Vector2(120, 48)
	volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vol_row.add_child(volume_label)
	var up := UiTheme.button("+", 20)
	up.custom_minimum_size = Vector2(64, 48)
	up.pressed.connect(volume_up)
	vol_row.add_child(up)
	box.add_child(vol_row)

	var back := UiTheme.button("返回", 20)
	back.custom_minimum_size = Vector2(140, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(close_settings)
	box.add_child(back)


func _overlay(w: int, h: int) -> Control:
	var mask := ColorRect.new()
	mask.color = Color(0, 0, 0, 0.62)
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_STOP
	mask.visible = false
	add_child(mask)
	var p := Panel.new()
	p.position = Vector2((1920.0 - w) / 2.0, (1080.0 - h) / 2.0)
	p.size = Vector2(w, h)
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PANEL, UiTheme.LINE, 10))
	mask.add_child(p)
	return mask


func set_hint(text: String) -> void:
	if hint_label != null:
		hint_label.text = text


## 设置由 main 传进来，标题画面只负责显示与修改。
func set_settings(s: Dictionary) -> void:
	settings = s.duplicate()
	_refresh_settings()


func _refresh_settings() -> void:
	if mode_button == null:
		return
	mode_button.text = "全屏" if String(settings.get("window_mode", "windowed")) == "fullscreen" else "窗口"
	volume_label.text = "%d%%" % roundi(float(settings.get("volume", 0.8)) * 100.0)


## ---- 供界面与验收脚本调用 ----

func press_new() -> void:
	mode_panel.visible = true
	set_hint("选择存档方式 · Esc 返回")


func press_mode(iron: bool) -> void:
	mode_panel.visible = false
	new_game.emit(iron)


func close_mode() -> void:
	mode_panel.visible = false
	set_hint("Enter 确认 · Esc 返回")


func press_quit() -> void:
	quit_game.emit()


func open_slots() -> void:
	_refresh_slots()
	slot_panel.visible = true
	set_hint("选择存档位 · Esc 返回")


func close_slots() -> void:
	slot_panel.visible = false
	set_hint("Enter 确认 · Esc 返回")


func open_settings() -> void:
	_refresh_settings()
	settings_panel.visible = true
	set_hint("设置窗口与音量 · Esc 返回")


func close_settings() -> void:
	settings_panel.visible = false
	set_hint("Enter 确认 · Esc 返回")


## 三个槽的摘要；标题画面每次打开都重读，存档后不用重启也能看到。
func slot_rows() -> Array[Dictionary]:
	return Slots.all_summaries()


func _refresh_slots() -> void:
	for c in slot_box.get_children():
		slot_box.remove_child(c)
		c.queue_free()
	# 自动存档放在最上面：换地点/战斗后自动落的盘，直接"继续"。
	var auto := Slots.summary(Slots.AUTO)
	if bool(auto["exists"]):
		_add_slot_row(auto, "自动存档（继续）")
	for row: Dictionary in slot_rows():
		_add_slot_row(row, "存档 %d" % int(row["slot"]))


func _add_slot_row(row: Dictionary, prefix: String) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	var text := "%s　%s" % [prefix, String(row["label"])]
	if bool(row["exists"]):
		text += "　%d 点　%s" % [int(row["points"]), String(row["saved_at"])]
	var l := UiTheme.label(text, 19, UiTheme.TEXT if bool(row["exists"]) else UiTheme.MUTED)
	l.custom_minimum_size = Vector2(600, 76)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(l)
	var b := UiTheme.button("读取", 19)
	b.custom_minimum_size = Vector2(140, 52)
	b.disabled = not bool(row["exists"])
	b.pressed.connect(press_slot.bind(int(row["slot"])))
	line.add_child(b)
	slot_box.add_child(line)


func press_slot(slot: int) -> void:
	var row: Dictionary = Slots.summary(slot)
	if not bool(row["exists"]):
		return
	close_slots()
	load_slot.emit(slot)


func toggle_mode() -> void:
	var next := "windowed" if String(settings.get("window_mode", "windowed")) == "fullscreen" else "fullscreen"
	settings = Settings.with_value(settings, "window_mode", next)
	_refresh_settings()
	settings_changed.emit(settings)


func volume_up() -> void:
	_bump_volume(0.1)


func volume_down() -> void:
	_bump_volume(-0.1)


func _bump_volume(delta: float) -> void:
	var v := clampf(snappedf(float(settings.get("volume", 0.8)) + delta, 0.1), 0.0, 1.0)
	settings = Settings.with_value(settings, "volume", v)
	_refresh_settings()
	settings_changed.emit(settings)


## Esc：先关覆盖层，都不开就什么都不做（标题画面不退出）。
func handle_escape() -> bool:
	if mode_panel != null and mode_panel.visible:
		close_mode()
		return true
	if slot_panel.visible:
		close_slots()
		return true
	if settings_panel.visible:
		close_settings()
		return true
	return false
