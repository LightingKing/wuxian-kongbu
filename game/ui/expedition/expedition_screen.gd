extends Control
## 地点图 + 手表 + 事件流（M1 可玩层的远征界面）。
## 只调用 ExpeditionView，规则在 core；界面负责画和把点击交回去。

signal battle_needed
signal ended
## 想跟某个人说话（剧情人物或队友）。
signal talk_requested(npc_id: String)
## 想用自由说辞（交给 AI 评分）过当前的说服检定。
signal persuade_requested
## 剧情插图（CG）该出场了。
signal cutscene_requested(name: String, text: String)

const ExpeditionView = preload("res://ui/expedition/expedition_view.gd")
const UiTheme = preload("res://ui/ui_theme.gd")
const BattleData = preload("res://core/battle/battle_data.gd")
const PixelArt = preload("res://ui/art/pixel_art.gd")


## 画通路的小画布：地点按钮是它的子节点。
class MapCanvas extends Control:
	var ex: RefCounted
	## 剧本里的坐标整体平移多少，地图才居中。
	var shift := Vector2.ZERO

	func _draw() -> void:
		if ex == null:
			return
		for p: Dictionary in ex.st.scenario.data["paths"]:
			var a: Array = ex.st.scenario.location(String(p["a"])).get("pos", [0, 0])
			var b: Array = ex.st.scenario.location(String(p["b"])).get("pos", [0, 0])
			var open: bool = ex.st.is_path_open(String(p["a"]), String(p["b"]))
			var color := Color("39414f") if open else Color("0b0d12")
			draw_line(Vector2(float(a[0]) + 88, float(a[1]) + 30) + shift, Vector2(float(b[0]) + 88, float(b[1]) + 30) + shift, color, 5.0, true)

	## 让所有地点按钮（196×62）的外框落在 area 的正中。
	func center_in(area: Vector2) -> void:
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for id: String in ex.st.scenario.data["locations"]:
			var pos: Array = ex.st.scenario.location(id).get("pos", [0, 0])
			var v := Vector2(float(pos[0]), float(pos[1]))
			lo = Vector2(minf(lo.x, v.x), minf(lo.y, v.y))
			hi = Vector2(maxf(hi.x, v.x + 196.0), maxf(hi.y, v.y + 62.0))
		shift = ((area - (hi - lo)) / 2.0 - lo).round()

var view: RefCounted
var map_canvas: MapCanvas
var location_buttons: Dictionary = {}
var watch_label: RichTextLabel
var member_label: RichTextLabel
var log_label: RichTextLabel
var pending_box: VBoxContainer
var action_box: HBoxContainer
var item_box: HBoxContainer
var talk_box: HBoxContainer
var title_label: Label
var search_button: Button
var chosen_keywords: Array[String] = []
var _pending_id := ""
var _cutscene_sent := ""
var _ended_sent := false


func setup(expedition: RefCounted, char_names: Dictionary) -> void:
	view = ExpeditionView.new(expedition, char_names)
	_build()
	refresh()


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.paint_bg(self)
	var left := PanelContainer.new()
	left.position = Vector2(30, 30)
	left.size = Vector2(930, 1020)
	left.add_theme_stylebox_override("panel", UiTheme.panel_style())
	add_child(left)
	map_canvas = MapCanvas.new()
	map_canvas.ex = view.ex
	map_canvas.custom_minimum_size = Vector2(900, 980)
	map_canvas.center_in(Vector2(900, 920))
	left.add_child(map_canvas)

	title_label = UiTheme.label(tr("生化危机一 · 蜂巢"), 30, UiTheme.ACCENT2)
	title_label.position = Vector2(1000, 26)
	title_label.size = Vector2(880, 44)
	add_child(title_label)

	watch_label = UiTheme.rich(22)
	watch_label.position = Vector2(1000, 80)
	watch_label.size = Vector2(880, 150)
	add_child(watch_label)

	member_label = UiTheme.rich(18)
	member_label.bbcode_enabled = true
	member_label.scroll_active = false
	member_label.position = Vector2(1000, 232)
	member_label.size = Vector2(880, 176)
	add_child(member_label)

	talk_box = HBoxContainer.new()
	talk_box.position = Vector2(1000, 410)
	talk_box.size = Vector2(880, 48)
	talk_box.add_theme_constant_override("separation", 8)
	add_child(talk_box)

	pending_box = VBoxContainer.new()
	pending_box.position = Vector2(1000, 464)
	pending_box.size = Vector2(880, 176)
	pending_box.add_theme_constant_override("separation", 8)
	add_child(pending_box)

	item_box = HBoxContainer.new()
	item_box.position = Vector2(1000, 644)
	item_box.size = Vector2(880, 50)
	item_box.add_theme_constant_override("separation", 10)
	add_child(item_box)

	action_box = HBoxContainer.new()
	action_box.position = Vector2(1000, 700)
	action_box.size = Vector2(880, 52)
	action_box.add_theme_constant_override("separation", 10)
	add_child(action_box)

	log_label = UiTheme.rich(19)
	log_label.position = Vector2(1000, 760)
	log_label.size = Vector2(880, 242)
	add_child(log_label)

	search_button = UiTheme.button(tr("搜索"), 20)
	search_button.pressed.connect(_on_search)
	action_box.add_child(search_button)
	var rest10 := UiTheme.button(tr("休息 10 分钟"), 20)
	rest10.pressed.connect(_on_rest10)
	action_box.add_child(rest10)
	var rest30 := UiTheme.button(tr("休息 30 分钟"), 20)
	rest30.pressed.connect(_on_rest30)
	action_box.add_child(rest30)
	var deduce_btn := UiTheme.button(tr("推理"), 20)
	deduce_btn.pressed.connect(_on_deduce)
	action_box.add_child(deduce_btn)

	for loc_id: String in view.ex.st.scenario.data["locations"]:
		var btn := UiTheme.map_button("")
		btn.icon = PixelArt.place(loc_id)
		btn.add_theme_constant_override("icon_max_width", 22)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var pos: Array = view.ex.st.scenario.location(loc_id).get("pos", [0, 0])
		btn.position = Vector2(float(pos[0]), float(pos[1])) + map_canvas.shift
		btn.size = Vector2(196, 62)
		btn.pressed.connect(_on_location.bind(loc_id))
		map_canvas.add_child(btn)
		location_buttons[loc_id] = btn
	var legend := UiTheme.label(tr("● 你在这里　→ 点一下就过去（走路要花时间）　人：有剧情人物　险：搜索可能遇敌"), 16, UiTheme.MUTED)
	legend.position = Vector2(16, 936)
	legend.size = Vector2(880, 30)
	map_canvas.add_child(legend)


func refresh() -> void:
	title_label.text = "生化危机一 · 蜂巢 · 第 %d 分钟" % int(view.ex.st.clock)
	var w: Dictionary = view.watch()
	var left := int(w["remaining_minutes"])
	watch_label.text = "%s\n剩余 %d:%02d · 击杀 %d（%.1f 点）" % [String(w["main_task"]), left / 60, left % 60, int(w["kills"]), float(w["kill_points"])]
	if String(w["tether"]) != "":
		watch_label.text += "\n绑定：" + String(w["tether"])
	if bool(w["gag"]):
		watch_label.text += "\n禁言：剧情人物在场时泄露主神信息，每句 -10"
	if bool(w["dark"]):
		watch_label.text += "\n[全黑] 恐惧持续上升"

	var lines: Array[String] = []
	for m: Dictionary in view.members():
		var color := "#e6e9ef" if bool(m["alive"]) else "#5a6270"
		var hp := "%d/%d" % [int(m["hp"]), int(m["hp_max"])]
		var tail := "  [感染]" if bool(m["infected"]) else ""
		lines.append("[color=%s]%s  %s  恐惧 %d%s[/color]" % [color, String(m["name"]), hp, int(m["fear"]), tail])
	member_label.text = "\n".join(lines)

	var items := {}
	for m: Dictionary in view.map():
		items[m["id"]] = m
	for loc_id: String in location_buttons:
		var b: Button = location_buttons[loc_id]
		var item: Dictionary = items.get(loc_id, {})
		var text: String = String(item.get("name", loc_id))
		var go := bool(item.get("adjacent", false)) and bool(item.get("open", true)) and not bool(item.get("here", false))
		if bool(item.get("here", false)):
			text = "● " + text
		elif go:
			text = "→ " + text
		else:
			text = "  " + text
		if (item.get("npcs", []) as Array).size() > 0:
			text += " 人"
		if bool(item.get("risk", false)):
			text += " 险"
		b.text = text
		var reachable := bool(item.get("here", false)) or (bool(item.get("adjacent", false)) and bool(item.get("open", true)))
		b.disabled = not reachable
		b.add_theme_color_override("font_color", UiTheme.ACCENT2 if go else UiTheme.TEXT)
		var tint := Color(0.78, 0.84, 1.0, 1.0) if bool(item.get("dark", false)) else Color.WHITE
		b.modulate = tint if reachable else tint * Color(0.75, 0.75, 0.75, 1.0)

	_maybe_cutscene()
	_build_talk()
	_build_pending()
	_build_items()
	var here_info: Dictionary = view.ex.st.scenario.location(view.location())
	search_button.text = "搜索（有风险）" if here_info.has("search_encounter") else "搜索"
	log_label.text = "\n".join(view.log_tail(12))
	if view.pending().get("kind", "") == "battle":
		battle_needed.emit.call_deferred()
	if view.ended() and not _ended_sent:
		_ended_sent = true
		ended.emit.call_deferred()


func _build_pending() -> void:
	for c in pending_box.get_children():
		pending_box.remove_child(c)
		c.queue_free()
	var p: Dictionary = view.pending()
	if p.is_empty():
		if not view.ended():
			pending_box.add_child(UiTheme.label(tr("现在没有要你决定的事。"), 21, UiTheme.ACCENT2))
			pending_box.add_child(UiTheme.label(tr("点地图上标 → 的地点前进，或者搜索、休息让时间往前走；剧情到点会自己发生。"), 18, UiTheme.MUTED))
			if String(view.watch()["tether"]) != "":
				pending_box.add_child(UiTheme.label(tr("手表绑定着人：别离他太远，他走了你也得跟上。"), 18, UiTheme.MUTED))
		return
	var kind := String(p["kind"])
	if kind == "choice":
		pending_box.add_child(UiTheme.label(String(p["prompt"]), 22, UiTheme.ACCENT2))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		for o: Dictionary in p["options"]:
			var b := UiTheme.button(String(o["text"]), 19)
			b.pressed.connect(press_choice.bind(String(o["id"])))
			row.add_child(b)
		pending_box.add_child(row)
	elif kind == "check":
		if String(p["id"]) != _pending_id:
			_pending_id = String(p["id"])
			chosen_keywords.clear()
		pending_box.add_child(UiTheme.label(tr("%s：%s（难度 %d）") % [String(p["npc"]), String(p["goal"]), int(p["difficulty"])], 21, UiTheme.ACCENT2))
		if not bool(p["fact_ready"]):
			pending_box.add_child(UiTheme.label(tr("你还没有把握开口。先推理出：%s") % String(p["fact_name"]), 18, UiTheme.MUTED))
			var row0 := HBoxContainer.new()
			row0.add_theme_constant_override("separation", 10)
			var think := UiTheme.button(tr("推理（10 分钟）"), 19)
			think.pressed.connect(press_deduce)
			row0.add_child(think)
			var force := UiTheme.button(tr("硬扛（放弃说服）"), 19)
			force.pressed.connect(press_persuade.bind(0))
			row0.add_child(force)
			pending_box.add_child(row0)
			return
		pending_box.add_child(UiTheme.label(tr("让 %s 开口（已选 %d 个关键词）") % [String(p["thinker"]), chosen_keywords.size()], 18, UiTheme.MUTED))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		for k: String in p["keywords"]:
			var on := chosen_keywords.has(k)
			var b := UiTheme.button(("✓ " if on else "") + k, 18)
			b.toggle_mode = true
			b.button_pressed = on
			b.toggled.connect(func(pressed: bool) -> void:
				if pressed:
					chosen_keywords.append(k)
				else:
					chosen_keywords.erase(k)
				refresh())
			row.add_child(b)
		pending_box.add_child(row)
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 10)
		var talk := UiTheme.button(tr("开口"), 20)
		talk.custom_minimum_size = Vector2(180, 46)
		talk.pressed.connect(press_persuade_keywords)
		row2.add_child(talk)
		var force := UiTheme.button(tr("硬扛（放弃说服）"), 19)
		force.pressed.connect(press_persuade.bind(0))
		row2.add_child(force)
		var free := UiTheme.button(tr("自己说（AI 评分）"), 19)
		free.pressed.connect(press_persuade_free)
		row2.add_child(free)
		pending_box.add_child(row2)
	elif kind == "battle":
		pending_box.add_child(UiTheme.label(tr("战斗：%s") % "、".join(p["enemies"]), 22, UiTheme.ACCENT))


## 键盘：1~9 直接选当前待选项，PC 上不用把手从键盘挪到鼠标。
func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	var idx := int(k.keycode) - int(KEY_1)
	if idx < 0 or idx > 8:
		return
	var p: Dictionary = view.pending()
	if String(p.get("kind", "")) != "choice":
		return
	var opts: Array = p["options"]
	if idx >= opts.size():
		return
	if press_choice(String(opts[idx]["id"])):
		accept_event()


## 有插图要播就通知一次；播完（pending 清空）后复位，下一次还能触发。
func _maybe_cutscene() -> void:
	var p: Dictionary = view.pending()
	if String(p.get("kind", "")) != "cutscene":
		_cutscene_sent = ""
		return
	var n := String(p["name"])
	if n == _cutscene_sent:
		return
	_cutscene_sent = n
	cutscene_requested.emit.call_deferred(n, String(p.get("text", "")))


## 插图播完：交回 core 并刷新。
func press_cutscene_done() -> void:
	view.dismiss_cutscene()
	refresh()


## 列出能搭话的人：最多四个，多的先不显示。
func _build_talk() -> void:
	for c in talk_box.get_children():
		talk_box.remove_child(c)
		c.queue_free()
	var targets: Array[Dictionary] = view.talk_targets()
	if targets.is_empty():
		talk_box.add_child(UiTheme.label(tr("这里没有能说话的人。"), 17, UiTheme.MUTED))
		return
	var head := UiTheme.label(tr("搭话："), 17, UiTheme.MUTED)
	head.custom_minimum_size = Vector2(62, 44)
	talk_box.add_child(head)
	for i in mini(targets.size(), 4):
		var t: Dictionary = targets[i]
		var b := UiTheme.button(String(t["name"]), 17)
		b.custom_minimum_size = Vector2(160, 44)
		b.pressed.connect(press_talk.bind(String(t["id"])))
		talk_box.add_child(b)


func press_talk(npc_id: String) -> bool:
	var ids: Array[String] = []
	for t: Dictionary in view.talk_targets():
		ids.append(String(t["id"]))
	if not ids.has(npc_id):
		return false
	talk_requested.emit(npc_id)
	return true


func press_persuade_free() -> bool:
	if view.pending().get("kind", "") != "check":
		return false
	persuade_requested.emit()
	return true


func press_move(loc_id: String) -> bool:
	if not view.can_move(loc_id):
		return false
	view.move(loc_id)
	refresh()
	return true


func press_choice(option_id: String) -> bool:
	if view.pending().get("kind", "") != "choice":
		return false
	view.choose(option_id)
	refresh()
	return true


func press_persuade(level: int) -> bool:
	if view.pending().get("kind", "") != "check":
		return false
	view.persuade(level)
	refresh()
	return true


## 供验收脚本用：直接选中几个关键词。
func select_keywords(keys: Array) -> void:
	chosen_keywords.clear()
	for k: String in keys:
		chosen_keywords.append(k)
	refresh()


## 关键词说服用：不选关键词就开口等于没说。
func press_persuade_keywords() -> bool:
	if chosen_keywords.is_empty():
		return false
	view.persuade_with(chosen_keywords)
	chosen_keywords.clear()
	refresh()
	return true


func press_item(char_id: String, item_id: String) -> void:
	view.use_item(char_id, item_id)
	refresh()


func _build_items() -> void:
	for c in item_box.get_children():
		item_box.remove_child(c)
		c.queue_free()
	var actions: Array[Dictionary] = view.item_actions()
	for i in mini(actions.size(), 4):
		var a: Dictionary = actions[i]
		var b := UiTheme.button(String(a["label"]), 18)
		b.pressed.connect(press_item.bind(String(a["char"]), String(a["item"])))
		item_box.add_child(b)


func press_rest(minutes: int) -> void:
	view.rest(minutes)
	refresh()


func press_search() -> void:
	view.search()
	refresh()


func press_deduce() -> void:
	var thinker := ""
	var best := -1.0
	for sid: String in view.ex.st.squads:
		for c: String in view.ex.st.living_members(sid):
			var ch: RefCounted = view.ex.st.characters[c]
			var iq := float(ch.attributes.total("intelligence"))
			if iq > best:
				best = iq
				thinker = c
	if thinker != "":
		view.deduce("queen_controls_lasers", thinker)
	refresh()


func _on_location(loc_id: String) -> void:
	press_move(loc_id)


func _on_search() -> void:
	press_search()


func _on_rest10() -> void:
	press_rest(10)


func _on_rest30() -> void:
	press_rest(30)


func _on_deduce() -> void:
	press_deduce()
