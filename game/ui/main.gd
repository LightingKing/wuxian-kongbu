extends Control
## M1 可玩切片的入口：新游戏 → 远征 → 战斗 → 结算 → 主神空间休整。
## 只做流程和换屏；远征与战斗的状态都在 Session / Expedition / Battle 里。

const Session = preload("res://core/session/session.gd")
const ExpeditionScreen = preload("res://ui/expedition/expedition_screen.gd")
const BattleScreen = preload("res://ui/battle/battle_screen.gd")
const UiTheme = preload("res://ui/ui_theme.gd")
const Battle = preload("res://core/battle/battle.gd")

const SAVE_PATH := "user://m1_save.json"

var session: RefCounted
var content: Control
var header: Label
var save_button: Button
var load_button: Button
var battle_screen: Control = null


func _ready() -> void:
	theme = UiTheme.build()
	_build_frame()
	session = Session.new()
	session.start_m1(1)
	_show_expedition()


func _build_frame() -> void:
	UiTheme.paint_bg(self)
	var bar := ColorRect.new()
	bar.color = UiTheme.PANEL
	bar.position = Vector2(0, 0)
	bar.size = Vector2(1920, 56)
	add_child(bar)
	header = UiTheme.label("无限恐怖 · M1 可玩切片", 24, UiTheme.ACCENT2)
	header.position = Vector2(30, 12)
	header.size = Vector2(900, 34)
	add_child(header)

	save_button = UiTheme.button("保存", 18)
	save_button.position = Vector2(1560, 6)
	save_button.size = Vector2(150, 44)
	save_button.pressed.connect(_on_save)
	add_child(save_button)
	load_button = UiTheme.button("读档", 18)
	load_button.position = Vector2(1720, 6)
	load_button.size = Vector2(150, 44)
	load_button.pressed.connect(_on_load)
	add_child(load_button)

	content = Control.new()
	content.position = Vector2(0, 56)
	content.size = Vector2(1920, 1024)
	add_child(content)


func _clear() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	battle_screen = null


func _names() -> Dictionary:
	var out := {}
	for id: String in session.game.characters:
		out[id] = session.game.characters[id].display_name
	return out


func _set_status(text: String) -> void:
	header.text = "无限恐怖 · M1 · " + text


func _show_expedition() -> void:
	_clear()
	var screen := ExpeditionScreen.new()
	screen.setup(session.expedition, _names())
	screen.battle_needed.connect(_on_battle_needed)
	screen.ended.connect(_on_expedition_ended)
	content.add_child(screen)
	_set_status("生化危机一")


func _on_battle_needed() -> void:
	if battle_screen != null or session.blocked_reason() != "battle":
		return
	var units: Array[RefCounted] = session.expedition.battle_units({})
	if units.is_empty():
		return
	var b := Battle.new()
	b.setup(units, session.expedition.battle_options(), session.game.rng)
	var screen := BattleScreen.new()
	screen.setup(b)
	screen.finished.connect(_on_battle_finished.bind(b))
	_clear()
	content.add_child(screen)
	battle_screen = screen
	var loc := String(session.expedition.st.pending_battle.get("location", ""))
	_set_status("战斗中 · " + String(session.expedition.st.scenario.location(loc).get("name", loc)))


func _on_battle_finished(b: RefCounted) -> void:
	if battle_screen == null:
		return
	session.expedition.report_battle(b)
	battle_screen = null
	if session.phase == "expedition" and session.expedition_over():
		_on_expedition_ended()
	else:
		_show_expedition()


func _on_expedition_ended() -> void:
	if session.phase != "expedition":
		return
	var results: Dictionary = session.settle()
	_show_result(results)


func _show_result(results: Dictionary) -> void:
	_clear()
	var box := VBoxContainer.new()
	box.position = Vector2(300, 90)
	box.size = Vector2(1320, 860)
	box.add_theme_constant_override("separation", 14)
	content.add_child(box)

	var title := UiTheme.label("任务结束：%s" % String(session.expedition.st.outcome), 34, UiTheme.ACCENT2)
	box.add_child(title)
	box.add_child(UiTheme.label("倒计时 %d 分钟 · 存活结算" % int(session.expedition.st.clock), 20, UiTheme.MUTED))
	for id: String in results:
		var r: Dictionary = results[id]
		var name: String = session.game.characters[id].display_name if session.game.characters.has(id) else id
		if bool(r.get("dead", false)):
			box.add_child(UiTheme.label("%s：死亡（%s）" % [name, String(r.get("reason", ""))], 22, UiTheme.MUTED))
			continue
		var line := "%s：%d 点" % [name, int(r["final_points"])]
		var tickets: Array = r.get("tickets", [])
		if not tickets.is_empty():
			line += " · " + "、".join(tickets) + " 级支线"
		box.add_child(UiTheme.label(line, 24, UiTheme.TEXT))
	var go := UiTheme.button("进入主神空间", 24)
	go.custom_minimum_size = Vector2(320, 60)
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	go.pressed.connect(_on_enter_hub)
	box.add_child(go)
	_set_status("结算完成")


func _on_enter_hub() -> void:
	if session.enter_hub():
		_show_hub()


func _show_hub() -> void:
	_clear()
	var box := VBoxContainer.new()
	box.position = Vector2(300, 110)
	box.size = Vector2(1320, 800)
	box.add_theme_constant_override("separation", 16)
	content.add_child(box)
	box.add_child(UiTheme.label("主神空间 · 第 %d 天 / 9" % session.day, 36, UiTheme.ACCENT2))
	box.add_child(UiTheme.label("回归当晚只结算和造人；兑换、修复、训练从第 2 天开始。M1 的休息期界面在后续计划里展开。", 20, UiTheme.MUTED))
	var zheng: RefCounted = session.game.characters.get("zheng_zha")
	if zheng != null:
		box.add_child(UiTheme.label("郑吒：%d 点 · 支线 B×%d" % [zheng.points, int(zheng.tickets.counts["B"])], 24, UiTheme.TEXT))
	if session.day < 9:
		var next := UiTheme.button("推进一天", 22)
		next.custom_minimum_size = Vector2(240, 56)
		next.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		next.pressed.connect(func() -> void:
			session.advance_day()
			_show_hub())
		box.add_child(next)
	else:
		var go := UiTheme.button("走光柱（下一部：异形）", 22)
		go.custom_minimum_size = Vector2(360, 56)
		go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		go.pressed.connect(func() -> void:
			session.depart()
			_show_done())
		box.add_child(go)
	_set_status("主神空间 · 第 %d 天" % session.day)


func _show_done() -> void:
	_clear()
	var box := VBoxContainer.new()
	box.position = Vector2(300, 160)
	box.size = Vector2(1320, 600)
	box.add_theme_constant_override("separation", 16)
	content.add_child(box)
	box.add_child(UiTheme.label("二十道光柱降下。", 36, UiTheme.ACCENT2))
	box.add_child(UiTheme.label("下一部：异形一（内容与界面在后续计划里做）。", 22, UiTheme.TEXT))
	_set_status("M1 结束")


func _on_save() -> void:
	var err: int = session.save_to(SAVE_PATH)
	_set_status("已保存" if err == OK else "保存失败（%d）" % err)


func _on_load() -> void:
	var s := Session.load_from(SAVE_PATH)
	if s == null:
		_set_status("没有可读的存档")
		return
	session = s
	battle_screen = null
	if session.phase == "expedition":
		_show_expedition()
	elif session.phase == "done":
		_show_done()
	else:
		_show_hub()
