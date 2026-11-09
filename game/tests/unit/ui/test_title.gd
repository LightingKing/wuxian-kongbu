extends "res://tests/test_case.gd"
## 标题画面与暂停菜单：信号、槽位列表、空槽不可读、设置切换。

const TitleScreen = preload("res://ui/title_screen.gd")
const PauseMenu = preload("res://ui/pause_menu.gd")
const Slots = preload("res://core/save/slots.gd")
const Session = preload("res://core/session/session.gd")


func before_each() -> void:
	for i in range(1, Slots.COUNT + 1):
		Slots.erase(i)


func _title() -> Control:
	var t := TitleScreen.new()
	t.build()
	t.set_settings({"window_mode": "windowed", "volume": 0.8})
	return t


func test_title_lists_three_slots() -> void:
	var t := _title()
	t.open_slots()
	assert_eq((t.slot_rows() as Array).size(), 3)
	assert_eq(t.slot_box.get_child_count(), 3, "三个槽各一行")
	t.free()


func test_empty_slot_does_not_load() -> void:
	var t := _title()
	var loaded: Array = []
	t.load_slot.connect(func(slot: int) -> void: loaded.append(slot))
	t.press_slot(1)
	assert_eq(loaded.size(), 0, "空槽点了不读档")
	t.free()


func test_filled_slot_emits() -> void:
	var s := Session.new()
	s.start_m1(1)
	Slots.write(2, s)
	var t := _title()
	var loaded: Array = []
	t.load_slot.connect(func(slot: int) -> void: loaded.append(slot))
	t.press_slot(2)
	assert_eq(loaded.size(), 1)
	assert_eq(int(loaded[0]), 2)
	t.free()


func test_new_game_and_quit_signals() -> void:
	var t := _title()
	var events: Array = []
	t.new_game.connect(func() -> void: events.append("new"))
	t.quit_game.connect(func() -> void: events.append("quit"))
	t.press_new()
	t.press_quit()
	assert_eq(events, ["new", "quit"])
	t.free()


func test_settings_toggle_and_volume() -> void:
	var t := _title()
	assert_eq(String(t.mode_button.text), "窗口")
	t.toggle_mode()
	assert_eq(String(t.mode_button.text), "全屏")
	assert_eq(String(t.settings["window_mode"]), "fullscreen")
	t.volume_down()
	assert_almost(float(t.settings["volume"]), 0.7)
	assert_true(String(t.volume_label.text).contains("70"), String(t.volume_label.text))
	t.free()


func test_escape_closes_overlay_first() -> void:
	var t := _title()
	t.open_settings()
	assert_true(t.handle_escape(), "设置开着时 Esc 先关设置")
	assert_false(t.settings_panel.visible)
	assert_false(t.handle_escape(), "都关了就交回上一层")
	t.free()


func test_pause_saves_to_slot_and_reloads() -> void:
	var p := PauseMenu.new()
	p.build()
	p.open_for("")
	var saved: Array = []
	var loaded: Array = []
	p.save_slot.connect(func(slot: int) -> void: saved.append(slot))
	p.load_slot.connect(func(slot: int) -> void: loaded.append(slot))
	p.press_save(2)
	assert_eq(saved, [2])
	p.press_load(1)
	assert_eq(loaded.size(), 0, "空槽不可读")

	var s := Session.new()
	s.start_m1(1)
	Slots.write(1, s)
	p.refresh()
	p.press_load(1)
	assert_eq(loaded, [1])
	p.free()
