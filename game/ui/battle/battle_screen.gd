extends Control
## 战斗界面（M1 可玩层）：铺满全屏的像素战斗舞台（battle_stage.gd），上面叠原生分辨率的界面——
## 顶栏（轮到谁、时间轴、敌方意图）、左右两列名单（血、恐惧、弹药、状态）、中间的行动列表和战斗日志。
## 先选技能再选目标；只调用 BattleView；规则和 AI 在 core/battle。

signal finished

const BattleView = preload("res://ui/battle/battle_view.gd")
const BattleStage = preload("res://ui/battle/battle_stage.gd")
const UiTheme = preload("res://ui/ui_theme.gd")
const PixelArt = preload("res://ui/art/pixel_art.gd")
const Sfx = preload("res://ui/audio/sfx.gd")

## 半透明面板：压在像素画面上，看得清字也不完全挡住背景。
const GLASS := Color(0.04, 0.05, 0.08, 0.78)

var view: RefCounted
var stage: Control
var header: Label
var timeline_label: Label
var enemy_list: VBoxContainer
var ally_list: VBoxContainer
var action_box: VBoxContainer
var log_label: RichTextLabel
var intent_label: Label
var cards: Dictionary = {}
var open_indices: Array = []
var _done := false


## location：战斗地点（选像素背景）。
func setup(battle: RefCounted, location: String = "") -> void:
	view = BattleView.new(battle)
	_build(location, bool(battle.dark))
	refresh()


func _glass(pos: Vector2, size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.size = size
	var sb := StyleBoxFlat.new()
	sb.bg_color = GLASS
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	add_child(p)
	return p


func _build(location: String, dark: bool) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	stage = BattleStage.new()
	stage.setup(view.units(), location, dark)
	add_child(stage)

	var top := _glass(Vector2(20, 12), Vector2(1880, 92))
	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 2)
	top.add_child(top_box)
	header = UiTheme.label("战斗", 26, UiTheme.ACCENT)
	top_box.add_child(header)
	timeline_label = UiTheme.label("", 17, UiTheme.MUTED)
	top_box.add_child(timeline_label)
	intent_label = UiTheme.label("", 17, UiTheme.ACCENT2)
	top_box.add_child(intent_label)

	var left := _glass(Vector2(20, 116), Vector2(300, 520))
	ally_list = VBoxContainer.new()
	ally_list.add_theme_constant_override("separation", 4)
	left.add_child(ally_list)
	var right := _glass(Vector2(1600, 116), Vector2(300, 520))
	enemy_list = VBoxContainer.new()
	enemy_list.add_theme_constant_override("separation", 4)
	right.add_child(enemy_list)

	var action_panel := _glass(Vector2(340, 116), Vector2(1240, 300))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	action_panel.add_child(scroll)
	action_box = VBoxContainer.new()
	action_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_box.add_theme_constant_override("separation", 6)
	scroll.add_child(action_box)

	var log_panel := _glass(Vector2(340, 426), Vector2(1240, 210))
	log_label = UiTheme.rich(17)
	log_panel.add_child(log_label)


## 名单里的一行：像素头像 + 名字 + 血条 + 恐惧条 + 脚注（弹药/状态）。
func _card(u: Dictionary) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(276, 56)
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PANEL_LIGHT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	p.add_child(row)
	var face := TextureRect.new()
	face.texture = PixelArt.unit(String(u["id"]), String(u["side"]))
	face.custom_minimum_size = Vector2(30, 30)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(face)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)
	row.add_child(box)
	var name_label := UiTheme.label("", 15)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	box.add_child(name_label)
	var hp := UiTheme.bar(UiTheme.OK, 6)
	box.add_child(hp)
	var fear := UiTheme.bar(UiTheme.ACCENT2, 4)
	box.add_child(fear)
	var foot := UiTheme.label("", 12, UiTheme.MUTED)
	foot.clip_text = true
	foot.autowrap_mode = TextServer.AUTOWRAP_OFF
	foot.visible = false
	box.add_child(foot)
	cards[String(u["id"])] = {"name": name_label, "hp": hp, "fear": fear, "foot": foot}
	return p


func refresh() -> void:
	var cur: Dictionary = view.current()
	header.text = "战斗" + ((" · 轮到 " + String(cur["name"])) if not cur.is_empty() else "") + " ｜ " + view.objective()
	timeline_label.text = "时间轴：" + " → ".join(view.timeline())
	var intents: Array[String] = []
	for i: Dictionary in view.intents():
		intents.append("%s：%s" % [String(i["name"]), String(i["text"])])
	intent_label.text = "敌方意图（判断力 %d/2）：%s" % [int(view.b.intel), "；".join(intents)] if not intents.is_empty() else ""
	for list: VBoxContainer in [enemy_list, ally_list]:
		for c in list.get_children():
			list.remove_child(c)
			c.queue_free()
	var units: Array[Dictionary] = view.units()
	stage.sync(units)
	for u: Dictionary in units:
		var list: VBoxContainer = ally_list if String(u["side"]) == "ally" else enemy_list
		var p := _card(u)
		var c: Dictionary = cards[u["id"]]
		var name_label: Label = c["name"]
		name_label.text = "%s  %d/%d" % [String(u["name"]), int(maxf(float(u["hp"]), 0.0)), int(float(u["hp_max"]))]
		name_label.add_theme_color_override("font_color", UiTheme.TEXT if bool(u["alive"]) else UiTheme.MUTED)
		var hp_bar: ProgressBar = c["hp"]
		hp_bar.max_value = maxf(float(u["hp_max"]), 1.0)
		hp_bar.value = maxf(float(u["hp"]), 0.0)
		var hp_ratio := float(u["hp"]) / maxf(float(u["hp_max"]), 1.0)
		hp_bar.add_theme_stylebox_override("fill", UiTheme.bar_fill(UiTheme.ACCENT if hp_ratio < 0.3 else UiTheme.OK))
		var fear_bar: ProgressBar = c["fear"]
		fear_bar.max_value = 100.0
		fear_bar.value = clampf(float(u["fear"]), 0.0, 100.0)
		var foot: Label = c["foot"]
		var bits: Array[String] = []
		if int(u["ammo"]) >= 0:
			bits.append("弹 %d" % int(u["ammo"]))
		for st in u["statuses"]:
			bits.append(String(st))
		foot.text = " ".join(bits)
		foot.visible = foot.text != ""
		if bool(u["current"]):
			p.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PANEL_LIGHT, UiTheme.ACCENT, 8))
		elif not bool(u["alive"]):
			p.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.DARK, UiTheme.DARK, 8))
		list.add_child(p)

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
	log_label.text = "\n".join(view.log_tail(9))


func _open(indices: Array) -> void:
	open_indices = indices.duplicate()
	refresh()


func press_action(index: int) -> void:
	var before := (view.b.history as Array).size()
	view.act(index)
	var events: Array = (view.b.history as Array).slice(before)
	Sfx.play_for_events(events)
	stage.play(events)
	open_indices = []
	refresh()
