extends Control
## 游戏入口：标题画面 → 新游戏/读档 → 远征 → 战斗 → 结算 → 主神空间休整。
## 只做流程和换屏；远征与战斗的状态都在 Session / Expedition / Battle 里。
## 对话也在这里接线：AiService → Dialogue → 对话框，没配密钥就自动走离线兜底。
## PC 版外壳：标题画面、三个存档槽、设置、Esc 暂停菜单都在这里挂。

const Session = preload("res://core/session/session.gd")
const ExpeditionScreen = preload("res://ui/expedition/expedition_screen.gd")
const BattleScreen = preload("res://ui/battle/battle_screen.gd")
const HubScreen = preload("res://ui/hub/hub_screen.gd")
const UiTheme = preload("res://ui/ui_theme.gd")
const Battle = preload("res://core/battle/battle.gd")
const AiService = preload("res://ai/ai_service.gd")
const AiSettings = preload("res://ai/ai_settings.gd")
const HttpTransport = preload("res://ai/http_transport.gd")
const Persona = preload("res://ai/persona.gd")
const Dialogue = preload("res://core/dialogue/dialogue.gd")
const DialoguePanel = preload("res://ui/dialogue/dialogue_panel.gd")
const EventText = preload("res://ui/event_text.gd")
const DataLoader = preload("res://core/util/data_loader.gd")
const Slots = preload("res://core/save/slots.gd")
const Settings = preload("res://core/settings/settings.gd")
const TitleScreen = preload("res://ui/title_screen.gd")
const PauseMenu = preload("res://ui/pause_menu.gd")
const Sfx = preload("res://core/audio/sfx.gd")
const Cutscene = preload("res://ui/cutscene.gd")
const PortraitSource = preload("res://core/art/portrait_source.gd")

const ZHSHEN_FAQ := "res://data/ai/zhushen_faq.json"
## 主神不许说出口的词（校验层会拦，泄露就换离线回答）。
const ZHSHEN_FORBIDDEN: Array[String] = ["下一部", "剧情", "原著", "郑吒会"]

var session: RefCounted
var content: Control
var bar: ColorRect
var header: Label
var menu_button: Button
var battle_screen: Control = null
var title_screen: Control = null
var pause: Control = null
## 窗口模式与主音量，存 user://settings.json。
var settings: Dictionary = Settings.defaults()
## AI 接入层与对话层；离线时 ai.online() 为 false，全部走脚本兜底。
var ai: RefCounted
var dialogue: RefCounted
var panel: Control = null


func _ready() -> void:
	theme = UiTheme.build()
	_build_frame()
	add_child(Sfx.new())
	settings = Settings.load_settings()
	Settings.apply(settings)
	_show_title()


func _build_frame() -> void:
	UiTheme.paint_bg(self)
	bar = ColorRect.new()
	bar.color = UiTheme.PANEL
	bar.position = Vector2(0, 0)
	bar.size = Vector2(1920, 56)
	add_child(bar)
	header = UiTheme.label("无限恐怖", 24, UiTheme.ACCENT2)
	header.position = Vector2(30, 12)
	header.size = Vector2(1200, 34)
	add_child(header)

	menu_button = UiTheme.button("菜单（Esc）", 18)
	menu_button.position = Vector2(1700, 6)
	menu_button.size = Vector2(190, 44)
	menu_button.pressed.connect(_open_pause)
	add_child(menu_button)

	content = Control.new()
	content.position = Vector2(0, 56)
	content.size = Vector2(1920, 1024)
	add_child(content)

	_show_frame(false)


## 标题画面要整屏，游戏里让出顶部 56px 的状态栏。
func _show_frame(playing: bool) -> void:
	bar.visible = playing
	header.visible = playing
	menu_button.visible = playing
	content.position = Vector2(0, 56) if playing else Vector2(0, 0)
	content.size = Vector2(1920, 1024) if playing else Vector2(1920, 1080)


func _clear() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	battle_screen = null
	if panel != null:
		panel.queue_free()
		panel = null


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
	screen.talk_requested.connect(_on_talk)
	screen.persuade_requested.connect(_on_persuade_free)
	screen.cutscene_requested.connect(_on_cutscene)
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
	Sfx.play("coin")
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
	if session.hub == null:
		return
	_clear()
	var screen := HubScreen.new()
	screen.setup(session)
	screen.departed.connect(_show_done)
	screen.zhushen_requested.connect(_on_ask_zhushen)
	content.add_child(screen)
	_set_status("主神空间")


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


## ---- 标题与存档槽 ----

func _show_title() -> void:
	session = null
	battle_screen = null
	_close_pause()
	_clear()
	_show_frame(false)
	var t := TitleScreen.new()
	t.set_settings(settings)
	t.new_game.connect(_new_game)
	t.load_slot.connect(_load_slot)
	t.quit_game.connect(_quit_game)
	t.settings_changed.connect(_on_settings_changed)
	content.add_child(t)
	title_screen = t


func _new_game() -> void:
	title_screen = null
	session = Session.new()
	session.start_m1(1)
	_setup_ai()
	_show_frame(true)
	_show_expedition()


func _load_slot(slot: int) -> void:
	var s := Slots.read(slot)
	if s == null:
		_set_status("存档位 %d 读不出来" % slot)
		return
	title_screen = null
	session = s
	battle_screen = null
	_setup_ai()
	_show_frame(true)
	if session.phase == "expedition":
		_show_expedition()
	elif session.phase == "done":
		_show_done()
	else:
		_show_hub()


func _on_settings_changed(next: Dictionary) -> void:
	settings = next
	Settings.save_settings(settings)


## ---- 暂停菜单 ----

func _open_pause() -> void:
	if session == null or pause != null:
		return
	pause = PauseMenu.new()
	pause.resume.connect(_close_pause)
	pause.save_slot.connect(_on_save_slot)
	pause.load_slot.connect(_on_load_slot)
	pause.to_title.connect(_show_title)
	pause.quit_game.connect(_quit_game)
	add_child(pause)
	pause.open_for("")


func _close_pause() -> void:
	if pause == null:
		return
	pause.queue_free()
	pause = null


func _on_save_slot(slot: int) -> void:
	if session == null:
		return
	var err: int = Slots.write(slot, session)
	if pause != null:
		pause.set_status("已保存到槽 %d" % slot if err == OK else "保存失败（%d）" % err)


func _on_load_slot(slot: int) -> void:
	_close_pause()
	_load_slot(slot)


func _quit_game() -> void:
	get_tree().quit()


## Esc：标题画面先关覆盖层；游戏里先关对话框，再关暂停菜单，最后打开暂停菜单。
func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.keycode != KEY_ESCAPE:
		return
	if title_screen != null and is_instance_valid(title_screen):
		if title_screen.handle_escape():
			accept_event()
		return
	if panel != null and is_instance_valid(panel):
		panel.press_close()
		accept_event()
		return
	if pause != null:
		_close_pause()
	else:
		_open_pause()
	accept_event()


## 建 AI 接入层（HTTP 节点挂在自己身上才能联网）和对话层；读档后重调一次即可换掉 store。
func _setup_ai() -> void:
	if ai == null:
		var transport := HttpTransport.new()
		transport.name = "AiTransport"
		add_child(transport)
		ai = AiService.new(AiSettings.load_settings(), transport)
	dialogue = Dialogue.new(ai, _personas(), session.dialogues)


func _personas() -> Dictionary:
	var out := {}
	for id: String in Persona.load_all():
		out[id] = Persona.from_data(id)
	return out


func _location_id() -> String:
	if session.expedition == null:
		return ""
	var st: RefCounted = session.expedition.st
	for sid: String in st.squads:
		if (st.squads[sid]["members"] as Array).has("zheng_zha"):
			return String(st.squads[sid]["location"])
	return String(st.scenario.data["start_location"])


func _location_name() -> String:
	var id := _location_id()
	if id == "":
		return ""
	return String(session.expedition.st.scenario.location(id).get("name", id))


func _situation() -> String:
	return dialogue.situation_text(_location_name(), int(session.expedition.st.clock))


## 当前屏如果是远征界面就返回它（说服要问它谁最适合开口）。
func _expedition_screen() -> Control:
	if content.get_child_count() == 0:
		return null
	var c: Control = content.get_child(content.get_child_count() - 1)
	return c if c.has_method("press_talk") else null


func _open_panel(title: String, subtitle: String, mode: String) -> void:
	if panel != null:
		panel.queue_free()
		panel = null
	var p := DialoguePanel.new()
	add_child(p)
	p.open_for(title, subtitle, mode)
	p.closed.connect(func() -> void:
		if panel == p:
			panel = null
		p.queue_free()
	)
	panel = p


func _source_text(source: String) -> String:
	match source:
		"ai":
			return "在线 · " + _model_name()
		"replay":
			return "回放（这句话说过）"
		"none":
			return "（没有这个人设）"
	return "离线 · 脚本台词"


func _model_name() -> String:
	if ai == null:
		return ""
	return String((ai.settings["tiers"]["fast"] as Dictionary).get("model", ""))


## 有图就播，没图直接跳过——不能因为缺一张 CG 把流程卡死。
func _on_cutscene(cg_name: String, text: String) -> void:
	var screen := _expedition_screen()
	if not PortraitSource.has_cg(cg_name):
		if screen != null:
			screen.press_cutscene_done()
		return
	var c := Cutscene.new()
	c.name = "Cutscene"
	add_child(c)
	c.open_for(cg_name, text)
	c.finished.connect(func() -> void:
		c.queue_free()
		if screen != null and is_instance_valid(screen):
			screen.press_cutscene_done()
	)


func _on_talk(npc_id: String) -> void:
	var title: String = dialogue.display_name(npc_id)
	_open_panel(title, "%s · 第 %d 分钟" % [_location_name(), int(session.expedition.st.clock)], "talk")
	var p: Control = panel
	p.set_portrait(npc_id)
	p.set_status("……")
	dialogue.say(npc_id, "", _situation(), func(res: Dictionary) -> void:
		if panel != p:
			return
		p.push(title, String(res["say"]))
		p.set_status(_source_text(String(res["source"])))
	)
	p.submitted.connect(_on_said.bind(npc_id))


func _on_said(text: String, npc_id: String) -> void:
	var p: Control = panel
	if p == null:
		return
	p.push("我", text)
	p.set_status("……")
	p.set_replies([])
	dialogue.say(npc_id, text, _situation(), func(res: Dictionary) -> void:
		if panel != p:
			return
		p.push(dialogue.display_name(npc_id), String(res["say"]))
		p.set_status(_source_text(String(res["source"])))
		_after_said(npc_id, p)
	)


## 说过话就涨信任；到剧本给的门槛，对方会说一句实话，可能给线索。
func _after_said(npc_id: String, p: Control) -> void:
	var screen := _expedition_screen()
	if screen == null:
		return
	var def: Dictionary = screen.view.trust_def(npc_id)
	if def.is_empty():
		return
	for ev: Dictionary in dialogue.add_trust(npc_id, 1, def):
		if String(ev.get("line", "")) != "":
			p.push(dialogue.display_name(npc_id), String(ev["line"]))
		_push_events(session.expedition.apply_effects(ev["effects"], _location_id()), p)
	screen.refresh()


func _push_events(events: Array, p: Control) -> void:
	var names := _event_names()
	for e: Dictionary in events:
		var text := EventText.describe(e, names)
		if text != "":
			p.push("（结果）", text)


## 事件文本要的不只是人名：地点、剧情事件、线索都得有中文名，不然日志里全是 id。
func _event_names() -> Dictionary:
	var out := _names()
	if session.expedition == null:
		return out
	var sc: RefCounted = session.expedition.st.scenario
	for loc_id: String in sc.data.get("locations", {}):
		out[loc_id] = String(sc.location(loc_id).get("name", loc_id))
	for ev: Dictionary in sc.events():
		out[String(ev["id"])] = String(ev.get("label", ev["id"]))
	for npc_id: String in sc.data.get("npcs", {}):
		out[npc_id] = String(sc.data["npcs"][npc_id].get("name", npc_id))
	for fact_id: String in sc.data.get("facts", {}):
		var f: Dictionary = sc.data["facts"][fact_id]
		var statement := String(f.get("statement", fact_id))
		out[fact_id] = statement
		for clue_id: String in f.get("clues", {}):
			out[clue_id] = statement
	return out


func _on_persuade_free() -> void:
	var screen := _expedition_screen()
	if screen == null:
		return
	var check: Dictionary = session.expedition.st.pending_check
	if check.is_empty():
		return
	if not bool(session.expedition.can_persuade(String(screen.view.best_thinker_id()))["ok"]):
		return
	var npc := String(check["npc"])
	_open_panel("%s · 说服" % dialogue.display_name(npc), String(check["goal"]), "persuade")
	panel.set_portrait(npc)
	panel.push("（局面）", "要让对方点头：%s" % String(check["goal"]))
	panel.persuading.connect(_on_persuade_text)


func _on_persuade_text(text: String) -> void:
	var p: Control = panel
	var screen := _expedition_screen()
	if p == null or screen == null:
		return
	var check: Dictionary = session.expedition.st.pending_check
	if check.is_empty():
		p.push("（提示）", "现在没有要说服的人。")
		return
	var npc := String(check["npc"])
	p.push("我", text)
	p.set_status("……")
	dialogue.rate(npc, text, String(check["goal"]), check.get("keywords", []), _situation(), func(res: Dictionary) -> void:
		if panel != p:
			return
		p.push("（判定）", "说服力 %d/3。%s" % [int(res["level"]), String(res["reason"])])
		_push_events(session.expedition.resolve_persuasion(int(res["level"])), p)
		p.set_status(_source_text(String(res["source"])))
		screen.refresh()
	)


func _on_ask_zhushen() -> void:
	_open_panel("主神", "巨大的光球悬在头顶，没有表情。", "talk")
	panel.set_portrait("zhushen")
	panel.push("主神", "问。")
	panel.submitted.connect(_on_zhushen_question)


func _on_zhushen_question(text: String) -> void:
	var p: Control = panel
	if p == null:
		return
	p.push("我", text)
	p.set_status("……")
	dialogue.ask_zhushen(text, _zhushen_faq(), ZHSHEN_FORBIDDEN, func(res: Dictionary) -> void:
		if panel != p:
			return
		p.push("主神", String(res["answer"]))
		p.set_status(_source_text(String(res["source"])))
	)


func _zhushen_faq() -> Array:
	var res := DataLoader.load_json(ZHSHEN_FAQ)
	if not res.ok:
		return []
	return (res.data as Dictionary).get("faq", [])
