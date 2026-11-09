extends Control
## 主神空间（M1 休整）：兑换、属性、修复、造人、训练、休息与出发。
## 只调用 HubView；规则在 core/hub。

signal departed
## 想向主神提问。
signal zhushen_requested

const HubView = preload("res://ui/hub/hub_view.gd")
const UiTheme = preload("res://ui/ui_theme.gd")
const Sfx = preload("res://core/audio/sfx.gd")

const ATTRS := {
	"intelligence": "智力", "spirit": "精神力", "cell_vitality": "细胞活力",
	"nerve_reaction": "神经反应", "muscle": "肌肉强度", "immunity": "免疫力",
}

var view: RefCounted
var selected: String = "zheng_zha"
var tab: String = "exchange"
var category: String = ""
var confirm_entry: String = ""
var status_label: Label
var day_label: Label
var char_box: VBoxContainer
var tab_box: HBoxContainer
var content_box: VBoxContainer
var rest_button: Button
var depart_button: Button
var name_edit: LineEdit


func setup(session: RefCounted) -> void:
	view = HubView.new(session)
	_build()
	refresh()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiTheme.paint_bg(self)
	day_label = UiTheme.label("", 30, UiTheme.ACCENT2)
	day_label.position = Vector2(30, 20)
	day_label.size = Vector2(380, 40)
	add_child(day_label)
	var sub := UiTheme.label("兑换、修复、造人不耗天；训练和休息耗天。第 9 天黄昏走光柱。", 16, UiTheme.MUTED)
	sub.position = Vector2(30, 62)
	sub.size = Vector2(380, 44)
	add_child(sub)

	char_box = VBoxContainer.new()
	char_box.position = Vector2(30, 120)
	char_box.size = Vector2(380, 560)
	char_box.add_theme_constant_override("separation", 6)
	add_child(char_box)

	rest_button = UiTheme.button("休息一天", 20)
	rest_button.position = Vector2(30, 720)
	rest_button.size = Vector2(180, 52)
	rest_button.pressed.connect(press_rest)
	add_child(rest_button)
	depart_button = UiTheme.button("走光柱", 20)
	depart_button.position = Vector2(230, 720)
	depart_button.size = Vector2(180, 52)
	depart_button.pressed.connect(press_depart)
	add_child(depart_button)

	var ask := UiTheme.button("问主神", 20)
	ask.position = Vector2(30, 792)
	ask.size = Vector2(380, 52)
	ask.pressed.connect(press_ask_zhushen)
	add_child(ask)

	tab_box = HBoxContainer.new()
	tab_box.position = Vector2(450, 24)
	tab_box.size = Vector2(1420, 52)
	tab_box.add_theme_constant_override("separation", 10)
	add_child(tab_box)
	for t in [["兑换", "exchange"], ["属性", "attr"], ["修复", "repair"], ["造人", "human"], ["训练", "train"], ["对练", "spar"]]:
		var b := UiTheme.button(String(t[0]), 20)
		b.pressed.connect(open_tab.bind(String(t[1])))
		tab_box.add_child(b)

	var panel := PanelContainer.new()
	panel.position = Vector2(450, 90)
	panel.size = Vector2(1420, 760)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	content_box = VBoxContainer.new()
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 8)
	scroll.add_child(content_box)

	status_label = UiTheme.label("", 19, UiTheme.ACCENT2)
	status_label.position = Vector2(450, 866)
	status_label.size = Vector2(1420, 60)
	add_child(status_label)


func refresh() -> void:
	day_label.text = "主神空间 · " + view.day_text()
	rest_button.text = "休息一天（剩 %d 天）" % view.days_left()
	rest_button.disabled = view.can_depart()
	depart_button.visible = view.can_depart()

	for c in char_box.get_children():
		char_box.remove_child(c)
		c.queue_free()
	for ch: Dictionary in view.characters():
		var t := "%s\n%d 点 · 生命 %d/%d · 恐惧 %d" % [String(ch["name"]), int(ch["points"]), int(ch["hp"]), int(ch["hp_max"]), int(ch["fear"])]
		var tickets := ""
		for g: String in ["D", "C", "B", "A", "S"]:
			if int((ch["tickets"] as Dictionary).get(g, 0)) > 0:
				tickets += "%s×%d " % [g, int(ch["tickets"][g])]
		if tickets != "":
			t += "\n" + tickets
		var b := UiTheme.button(t, 17)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(select_char.bind(String(ch["id"])))
		if not bool(ch["alive"]):
			t += "\n（死亡）"
			b.text = t
			b.modulate = Color(0.6, 0.62, 0.68, 1.0)
		elif String(ch["id"]) == selected:
			b.modulate = Color(1.0, 0.82, 0.55, 1.0)
		char_box.add_child(b)

	for c in tab_box.get_children():
		var b := c as Button
		b.modulate = Color(1.0, 0.82, 0.55, 1.0) if _tab_of(b.text) == tab else Color.WHITE

	for c in content_box.get_children():
		content_box.remove_child(c)
		c.queue_free()
	match tab:
		"exchange": _build_exchange()
		"attr": _build_attr()
		"repair": _build_repair()
		"human": _build_human()
		"train": _build_train()
		"spar": _build_spar()


func _tab_of(text: String) -> String:
	var table := {"兑换": "exchange", "属性": "attr", "修复": "repair", "造人": "human", "训练": "train", "对练": "spar"}
	return String(table.get(text, ""))


func _char() -> RefCounted:
	return view.game.characters[selected]


func _build_exchange() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for c in [["全部", ""], ["强化", "enhance"], ["科技", "tech"], ["魔法", "magic"], ["道具", "item"]]:
		var b := UiTheme.button(String(c[0]), 18)
		b.pressed.connect(_set_category.bind(String(c[1])))
		if category == String(c[1]):
			b.modulate = Color(1.0, 0.82, 0.55, 1.0)
		row.add_child(b)
	content_box.add_child(row)
	if view.hub.day == 0:
		content_box.add_child(UiTheme.label("回归当晚不兑换。先造人，或者直接休息到第 2 天。", 20, UiTheme.MUTED))

	if confirm_entry != "":
		var warn := HBoxContainer.new()
		warn.add_theme_constant_override("separation", 10)
		warn.add_child(UiTheme.label("双血统冲突：坚持兑换有 70% 几率变成非人。", 20, UiTheme.ACCENT))
		var yes := UiTheme.button("仍然兑换", 18)
		yes.pressed.connect(_do_buy.bind(confirm_entry, true))
		warn.add_child(yes)
		var no := UiTheme.button("取消", 18)
		no.pressed.connect(func() -> void:
			confirm_entry = ""
			refresh())
		warn.add_child(no)
		content_box.add_child(warn)

	for e: Dictionary in view.entries(selected, category):
		var label := "%s   %d 点" % [String(e["name"]), int(e["points"])]
		if String(e["tier"]) != "":
			label += " · " + String(e["tier"]) + " 级"
		if bool(e["owned"]):
			label += "  [已拥有]"
		elif not bool(e["ok"]):
			label += "  (" + "、".join(e["reasons"]) + ")"
		var b := UiTheme.button(label, 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not bool(e["ok"])
		b.pressed.connect(press_entry.bind(String(e["id"])))
		content_box.add_child(b)


func _build_attr() -> void:
	var ch := _char()
	for k: String in ATTRS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var v := UiTheme.label("%s：%d" % [String(ATTRS[k]), int(ch.attributes.total(k))], 20)
		v.custom_minimum_size = Vector2(320, 40)
		row.add_child(v)
		var b := UiTheme.button("+10（100 点）", 18)
		b.custom_minimum_size = Vector2(200, 40)
		b.disabled = view.hub.day == 0 or ch.points < 100
		b.pressed.connect(press_attr.bind(k))
		row.add_child(b)
		content_box.add_child(row)
	content_box.add_child(UiTheme.label("10 点奖励点数 = 1 点属性（原著）。", 18, UiTheme.MUTED))


func _build_repair() -> void:
	var list: Array[Dictionary] = view.repairs()
	if list.is_empty():
		content_box.add_child(UiTheme.label("没有人受伤。", 20, UiTheme.MUTED))
		return
	for r: Dictionary in list:
		var b := UiTheme.button("%s  生命 %d/%d   修复 %d 点" % [String(r["name"]), int(r["hp"]), int(r["hp_max"]), int(r["cost"])], 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = _char().points < int(r["cost"])
		b.pressed.connect(press_repair.bind(String(r["id"])))
		content_box.add_child(b)


func _build_human() -> void:
	var made: Array = view.companions()
	content_box.add_child(UiTheme.label("造人：第一个免费，之后 500 点；素质最多约常人两倍，回归当晚就能造。", 19, UiTheme.MUTED))
	for c: Dictionary in made:
		content_box.add_child(UiTheme.label("已有造物：%s（制造者 %s）" % [String(c["name"]), String(c["creator"])], 20))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	name_edit = LineEdit.new()
	name_edit.text = "萝丽"
	name_edit.custom_minimum_size = Vector2(260, 48)
	name_edit.add_theme_font_size_override("font_size", 20)
	row.add_child(name_edit)
	var b := UiTheme.button("造人", 20)
	b.custom_minimum_size = Vector2(160, 48)
	b.disabled = made.size() > 0 and _char().points < 500
	b.pressed.connect(func() -> void:
		press_create(name_edit.text))
	row.add_child(b)
	content_box.add_child(row)


func _build_train() -> void:
	var list: Array[Dictionary] = view.trainable(selected)
	if list.is_empty():
		content_box.add_child(UiTheme.label("没有需要练的技能：低级别的兑换一上手就是熟练的，A 级以上才要练。", 19, UiTheme.MUTED))
		return
	for t: Dictionary in list:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var l := UiTheme.label("%s  熟练度 %.0f%%" % [String(t["name"]), float(t["proficiency"]) * 100.0], 20)
		l.custom_minimum_size = Vector2(420, 44)
		row.add_child(l)
		for days in [1, 2, 3]:
			var b := UiTheme.button("练 %d 天" % days, 18)
			b.custom_minimum_size = Vector2(120, 44)
			b.disabled = view.hub.day + days > view.hub.days_total - 1
			b.pressed.connect(press_train.bind(String(t["id"]), days))
			row.add_child(b)
		content_box.add_child(row)


## 对练：拿招式跟训练傀儡打一场，看伤害数字。耗 1 天，不伤人不耗道具。
func _build_spar() -> void:
	content_box.add_child(UiTheme.label("跟训练傀儡打一场（耗 1 天，不掉血、不耗弹药），用来看兑换前后的差别。", 18, UiTheme.MUTED))
	var list: Array[Dictionary] = view.sparrable(selected)
	if list.is_empty():
		content_box.add_child(UiTheme.label("这个人还没有能上场的招式。", 19, UiTheme.MUTED))
		return
	for t: Dictionary in list:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var l := UiTheme.label(String(t["name"]), 20)
		l.custom_minimum_size = Vector2(420, 44)
		row.add_child(l)
		var b := UiTheme.button("打一场（1 天）", 18)
		b.custom_minimum_size = Vector2(160, 44)
		b.disabled = view.hub.day + 1 > view.hub.days_total - 1
		b.pressed.connect(press_spar.bind(String(t["id"])))
		row.add_child(b)
		content_box.add_child(row)


func press_spar(skill_id: String) -> void:
	var events: Array[Dictionary] = view.spar(selected, skill_id)
	Sfx.play_for_events(events)
	status_label.text = _describe(events)
	refresh()


func _set_category(c: String) -> void:
	category = c
	refresh()


func select_char(id: String) -> void:
	selected = id
	refresh()


func open_tab(t: String) -> void:
	tab = t
	confirm_entry = ""
	refresh()


func press_entry(entry_id: String) -> void:
	var e: Dictionary = {}
	for item: Dictionary in view.entries(selected):
		if String(item["id"]) == entry_id:
			e = item
	if e.is_empty():
		return
	if (e["warnings"] as Array).has("bloodline_risk"):
		confirm_entry = entry_id
		refresh()
		return
	_do_buy(entry_id, false)


func _do_buy(entry_id: String, accept_risk: bool) -> void:
	confirm_entry = ""
	var events: Array[Dictionary] = view.buy(selected, entry_id, accept_risk)
	Sfx.play_for_events(events)
	status_label.text = _describe(events)
	refresh()


func press_attr(attr: String) -> void:
	var events: Array[Dictionary] = view.buy_attribute(selected, attr, 10)
	Sfx.play_for_events(events)
	status_label.text = _describe(events)
	refresh()


func press_repair(char_id: String) -> void:
	var events: Array[Dictionary] = view.repair(char_id)
	Sfx.play_for_events(events)
	status_label.text = _describe(events)
	refresh()


func press_create(name: String) -> void:
	var events: Array[Dictionary] = view.create_human(selected, name)
	Sfx.play_for_events(events)
	status_label.text = _describe(events)
	refresh()


func press_train(skill_id: String, days: int) -> void:
	var events: Array[Dictionary] = view.train(selected, skill_id, days)
	Sfx.play_for_events(events)
	status_label.text = _describe(events)
	refresh()


func press_rest() -> void:
	status_label.text = _describe(view.rest(1))
	refresh()


func press_ask_zhushen() -> void:
	zhushen_requested.emit()


func press_depart() -> bool:
	if not view.can_depart():
		return false
	session_depart()
	return true


func session_depart() -> void:
	if view.session.depart():
		departed.emit()


func _describe(events: Array[Dictionary]) -> String:
	if events.is_empty():
		return ""
	var e: Dictionary = events[0]
	match String(e["type"]):
		"exchange_done":
			return "兑换完成：" + String(e["entry"])
		"exchange_refused":
			return "主神拒绝了：" + "、".join(e["reasons"])
		"exchange_warning":
			return "需要确认血统风险"
		"attribute_bought":
			return "属性 +%d，花掉 %d 点" % [int(e["amount"]), int(e["cost"])]
		"repaired":
			return "修复完成，花掉 %d 点" % int(e["cost"])
		"human_created":
			return "造人完成：%s" % String((e["companion"] as Dictionary)["name"])
		"trained":
			return "训练完成：%s 熟练度 %.0f%%" % [String(e["skill"]), float(e["proficiency"]) * 100.0]
		"spar_done":
			return "对练：%s 打出 %d 伤害（%d 回合，%s），熟练度 %.0f%%" % [
				String(e["skill"]), int(float(e["damage"])), int(e["rounds"]),
				"打赢" if String(e["outcome"]) == "victory" else "没打完",
				float(e["proficiency"]) * 100.0]
		"day_passed":
			return "第 %d 天" % int(e["day"])
		"hub_refused":
			return HubView.reason_text(String(e["reason"]))
		"bloodline_mutation":
			return "血统冲突爆发：变成了非人"
		"bloodline_safe":
			return "运气不错，血统没有冲突"
	return String(e["type"])
