extends Control
## 战斗界面（M1 可玩层）：按排显示战场、行动时间轴、先选技能再选目标、战斗日志。
## 只调用 BattleView；规则和 AI 在 core/battle。

signal finished

const BattleView = preload("res://ui/battle/battle_view.gd")
const UiTheme = preload("res://ui/ui_theme.gd")

var view: RefCounted
var header: Label
var timeline_label: Label
var enemy_grid: GridContainer
var ally_grid: GridContainer
var action_box: VBoxContainer
var log_label: RichTextLabel
var intent_label: Label
var cards: Dictionary = {}
var open_indices: Array = []
var _done := false


func setup(battle: RefCounted) -> void:
	view = BattleView.new(battle)
	_build()
	refresh()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiTheme.paint_bg(self)
	header = UiTheme.label("战斗", 30, UiTheme.ACCENT)
	header.position = Vector2(40, 18)
	header.size = Vector2(1200, 40)
	add_child(header)
	timeline_label = UiTheme.label("", 20, UiTheme.MUTED)
	timeline_label.position = Vector2(40, 60)
	timeline_label.size = Vector2(1240, 30)
	add_child(timeline_label)

	var enemy_title := UiTheme.label("敌方", 22, UiTheme.ACCENT)
	enemy_title.position = Vector2(40, 98)
	enemy_title.size = Vector2(200, 28)
	add_child(enemy_title)
	enemy_grid = GridContainer.new()
	enemy_grid.columns = 5
	enemy_grid.position = Vector2(40, 130)
	enemy_grid.size = Vector2(1240, 210)
	enemy_grid.add_theme_constant_override("h_separation", 10)
	enemy_grid.add_theme_constant_override("v_separation", 8)
	add_child(enemy_grid)

	var ally_title := UiTheme.label("我方", 22, UiTheme.OK)
	ally_title.position = Vector2(40, 356)
	ally_title.size = Vector2(200, 28)
	add_child(ally_title)
	ally_grid = GridContainer.new()
	ally_grid.columns = 7
	ally_grid.position = Vector2(40, 388)
	ally_grid.size = Vector2(1240, 116)
	ally_grid.add_theme_constant_override("h_separation", 10)
	add_child(ally_grid)

	var action_panel := PanelContainer.new()
	action_panel.position = Vector2(1300, 90)
	action_panel.size = Vector2(580, 620)
	action_panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	add_child(action_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	action_panel.add_child(scroll)
	action_box = VBoxContainer.new()
	action_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_box.add_theme_constant_override("separation", 8)
	scroll.add_child(action_box)

	intent_label = UiTheme.label("", 19, UiTheme.ACCENT2)
	intent_label.position = Vector2(40, 520)
	intent_label.size = Vector2(1240, 44)
	add_child(intent_label)
	var log_title := UiTheme.label("战斗日志", 22, UiTheme.MUTED)
	log_title.position = Vector2(40, 570)
	log_title.size = Vector2(300, 28)
	add_child(log_title)
	log_label = UiTheme.rich(19)
	log_label.position = Vector2(40, 604)
	log_label.size = Vector2(1240, 390)
	add_child(log_label)


func _card(u: Dictionary) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(160, 100)
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PANEL_LIGHT))
	var l := UiTheme.label("", 17)
	p.add_child(l)
	cards[u["id"]] = l
	return p


func refresh() -> void:
	var cur: Dictionary = view.current()
	header.text = "战斗" + ((" · 轮到 " + String(cur["name"])) if not cur.is_empty() else "") + " ｜ " + view.objective()
	timeline_label.text = "时间轴：" + " → ".join(view.timeline())
	var intents: Array[String] = []
	for i: Dictionary in view.intents():
		intents.append("%s：%s" % [String(i["name"]), String(i["text"])])
	intent_label.text = "敌方意图（判断力 %d/2）：%s" % [int(view.b.intel), "；".join(intents)] if not intents.is_empty() else ""
	for grid: GridContainer in [enemy_grid, ally_grid]:
		for c in grid.get_children():
			grid.remove_child(c)
			c.queue_free()
	var units: Array[Dictionary] = view.units()
	for u: Dictionary in units:
		var grid: GridContainer = ally_grid if String(u["side"]) == "ally" else enemy_grid
		var p := _card(u)
		var l: Label = cards[u["id"]]
		var status := "、".join(u["statuses"])
		l.text = "%s\nHP %d/%d\n恐惧 %d%s%s" % [
			String(u["name"]), int(u["hp"]), int(u["hp_max"]), int(u["fear"]),
			("\n弹 %d" % int(u["ammo"])) if int(u["ammo"]) >= 0 else "",
			("\n" + status) if status != "" else "",
		]
		l.add_theme_color_override("font_color", UiTheme.TEXT if bool(u["alive"]) else UiTheme.MUTED)
		if bool(u["current"]):
			p.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.ACCENT, UiTheme.ACCENT, 8))
		grid.add_child(p)
		cards[u["id"]] = l

	for c in action_box.get_children():
		action_box.remove_child(c)
		c.queue_free()
	if view.finished():
		action_box.add_child(UiTheme.label("战斗结束：" + view.outcome(), 24, UiTheme.ACCENT2))
		if not _done:
			_done = true
			finished.emit.call_deferred()
		return
	var actions: Array[Dictionary] = view.actions()
	if not open_indices.is_empty():
		var back := UiTheme.button("← 返回", 18)
		back.pressed.connect(func() -> void:
			open_indices = []
			refresh())
		action_box.add_child(back)
		for i in open_indices:
			var b := UiTheme.button(String(actions[int(i)]["label"]), 18)
			b.pressed.connect(press_action.bind(int(i)))
			action_box.add_child(b)
	else:
		for g: Dictionary in view.groups():
			var b := UiTheme.button(String(g["label"]), 19)
			var indices: Array = g["indices"]
			if indices.size() == 1:
				b.pressed.connect(press_action.bind(int(indices[0])))
			else:
				b.pressed.connect(_open.bind(indices))
			action_box.add_child(b)
	log_label.text = "\n".join(view.log_tail(8))


func _open(indices: Array) -> void:
	open_indices = indices.duplicate()
	refresh()


func press_action(index: int) -> void:
	view.act(index)
	open_indices = []
	refresh()
