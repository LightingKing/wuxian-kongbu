extends Control
## 地点场景：RPG 式探索（设计规格 5.1、11）。
## 像素层 480×256（30×16 格，每格 16 像素），整数放大 4 倍正好铺满顶栏下面的 1920×1024；
## 主角（拍板的人）用方向键 / WASD 走，队友跟在后面；对着人按 Enter 说话，对着柜子按 Enter 搜索；
## 走进门就去隔壁地点（时间照规则推进）；点地面会自己走过去。
## 剧情事件不再堆在日志里：台词一句一句出在底部的对话框里（带立绘），选择弹选项窗口，说服弹说服窗口，
## 其他结果在右边飘一条提示；完整记录按 L 看。规则全在 core，这里只调 ExpeditionView。
## 对外的 press_* 方法和信号跟旧的地点图界面一样，main.gd 和切片验收不用改。

signal battle_needed
signal ended
signal talk_requested(npc_id: String)
signal persuade_requested
signal cutscene_requested(name: String, text: String)

const ExpeditionView = preload("res://ui/expedition/expedition_view.gd")
const FieldMap = preload("res://ui/field/field_map.gd")
const FieldArt = preload("res://ui/field/field_art.gd")
const UiTheme = preload("res://ui/ui_theme.gd")
const EventText = preload("res://ui/event_text.gd")
const PortraitSource = preload("res://ui/art/portrait_source.gd")

const MAPS := "res://data/maps/biohazard1.json"
const PIXEL := Vector2i(480, 256)
const SCALE := 4
const TILE := 16
const STEP_TIME := 0.13
const GLASS := Color(0.04, 0.05, 0.08, 0.82)
## 这些结果算"剧情"，放进对话框让玩家看清楚；其余的飘提示。
const STORY_TYPES: Array[String] = [
	"erased", "char_died", "tether_warning", "tether_transferred", "tether_released", "side_plot_done",
	"bonus", "penalty", "talent_awakened", "clue_found", "searched", "search_encounter", "persuade_result",
	"persuade_blocked", "returned", "wiped", "plot_altered", "infection_turned", "inference",
]
## 这些不用说（画面本身已经表现了，或者马上会弹窗口）。
const SILENT_TYPES: Array[String] = [
	"move_start", "arrived", "choice_request", "choice_made", "persuade_request", "cutscene",
	"cutscene_dismissed", "plot_event", "flag_set", "npc_moved", "path_changed", "battle_request",
	"expedition_start", "given", "codex_request", "relation_request", "members_moved",
]
const KEYS := {
	"left": [KEY_LEFT, KEY_A], "right": [KEY_RIGHT, KEY_D], "up": [KEY_UP, KEY_W], "down": [KEY_DOWN, KEY_S],
}

## 换屏（打完仗回来、关掉对话框）以后还站在原地、已经播过的事件不再播：按远征对象记住。
static var _memory: Dictionary = {}
## 只给验收脚本用：台词不进对话框，直接跳到"等玩家做的事"（脚本直接读 core 的结果，不点对话框）。
static var skip_messages := false


## 画地图的一层。
class TileLayer extends Node2D:
	var fmap: RefCounted

	func _draw() -> void:
		if fmap == null:
			return
		for y in fmap.size.y:
			for x in fmap.size.x:
				var c := Vector2i(x, y)
				draw_texture(FieldArt.tile(fmap.theme(), fmap.char_at(c)), Vector2(x * TILE, y * TILE))


var view: RefCounted
var fmap: RefCounted
var loc: String = ""
var viewport: SubViewport
var display: TextureRect
var tiles: TileLayer
var actors: Node2D
var dark: Sprite2D
var player: Sprite2D
var player_id: String = ""
var followers: Array[Sprite2D] = []
var follower_ids: Array[String] = []
var npc_sprites: Dictionary = {}
var npc_cells: Dictionary = {}
var cell := Vector2i.ZERO
var facing: String = "down"
var trail: Array[Vector2i] = []
var moving := false
var walk_frame := 1
var path_queue: Array[Vector2i] = []
var path_then: Dictionary = {}
var messages: Array[Dictionary] = []
var seen := 0
var chosen_keywords: Array[String] = []
var _pending_id := ""
var _cutscene_sent := ""
var _ended_sent := false
var _battle_sent := false

var hud_label: RichTextLabel
var party_label: RichTextLabel
var box: PanelContainer
var box_face: TextureRect
var box_name: Label
var box_text: Label
var choice_panel: PanelContainer
var choice_box: VBoxContainer
var check_panel: PanelContainer
var check_box: VBoxContainer
var toast_box: VBoxContainer
var action_bar: HBoxContainer
var item_box: VBoxContainer
var log_panel: PanelContainer
var log_label: RichTextLabel
var hint_label: Label


func setup(expedition: RefCounted, char_names: Dictionary) -> void:
	view = ExpeditionView.new(expedition, char_names)
	_build()
	var mem: Dictionary = _memory.get(expedition.get_instance_id(), {})
	seen = int(mem.get("seen", 0))
	_enter(view.location(), "", mem)
	refresh()


## 记住现在站哪、播到第几条事件。
func _remember() -> void:
	_memory[view.ex.get_instance_id()] = {"loc": loc, "cell": cell, "facing": facing, "seen": seen}


# ---------------------------------------------------------------- 搭界面

func _glass(pos: Vector2, size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.size = size
	var sb := StyleBoxFlat.new()
	sb.bg_color = GLASS
	sb.border_color = UiTheme.LINE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	add_child(p)
	return p


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.paint_bg(self)
	viewport = SubViewport.new()
	viewport.size = PIXEL
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.snap_2d_transforms_to_pixel = true
	add_child(viewport)
	tiles = TileLayer.new()
	viewport.add_child(tiles)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	viewport.add_child(actors)
	dark = Sprite2D.new()
	dark.texture = FieldArt.flashlight()
	dark.scale = Vector2(2, 2)
	dark.z_index = 100
	dark.visible = false
	viewport.add_child(dark)
	display = TextureRect.new()
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.size = Vector2(PIXEL * SCALE)
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)

	var hud := _glass(Vector2(16, 12), Vector2(820, 118))
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_label = UiTheme.rich(18)
	hud_label.bbcode_enabled = true
	hud_label.scroll_active = false
	hud.add_child(hud_label)
	var party := _glass(Vector2(1544, 12), Vector2(360, 196))
	party.mouse_filter = Control.MOUSE_FILTER_IGNORE
	party_label = UiTheme.rich(16)
	party_label.bbcode_enabled = true
	party_label.scroll_active = false
	party.add_child(party_label)

	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(1384, 222)
	toast_box.size = Vector2(520, 400)
	toast_box.add_theme_constant_override("separation", 6)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_box)

	hint_label = UiTheme.label(tr("方向键 / WASD 走动 · Enter 说话、调查 · 点地面自动走过去 · L 记录 · Esc 菜单"), 16, UiTheme.MUTED)
	hint_label.position = Vector2(20, 990)
	hint_label.size = Vector2(1100, 26)
	add_child(hint_label)

	action_bar = HBoxContainer.new()
	action_bar.position = Vector2(1060, 966)
	action_bar.size = Vector2(844, 50)
	action_bar.add_theme_constant_override("separation", 8)
	action_bar.alignment = BoxContainer.ALIGNMENT_END
	add_child(action_bar)
	for spec in [[tr("休息 10 分钟"), press_rest.bind(10)], [tr("休息 30 分钟"), press_rest.bind(30)], [tr("推理"), press_deduce], [tr("道具"), _toggle_items], [tr("记录"), _toggle_log]]:
		var b := UiTheme.button(String(spec[0]), 18)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[1])
		action_bar.add_child(b)
	item_box = VBoxContainer.new()
	item_box.position = Vector2(1440, 760)
	item_box.size = Vector2(464, 200)
	item_box.add_theme_constant_override("separation", 6)
	item_box.visible = false
	add_child(item_box)

	box = _glass(Vector2(140, 742), Vector2(1640, 262))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	box.add_child(row)
	box_face = TextureRect.new()
	box_face.custom_minimum_size = Vector2(160, 240)
	box_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	box_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(box_face)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	row.add_child(col)
	box_name = UiTheme.label(tr(""), 24, UiTheme.ACCENT2)
	col.add_child(box_name)
	box_text = UiTheme.label(tr(""), 24)
	box_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(box_text)
	col.add_child(UiTheme.label(tr("Enter / 空格 / 点击 继续 ▼"), 15, UiTheme.MUTED))
	box.gui_input.connect(_on_box_input)
	box.visible = false

	choice_panel = _glass(Vector2(460, 300), Vector2(1000, 300))
	choice_box = VBoxContainer.new()
	choice_box.add_theme_constant_override("separation", 10)
	choice_panel.add_child(choice_box)
	choice_panel.visible = false

	check_panel = _glass(Vector2(300, 260), Vector2(1320, 380))
	check_box = VBoxContainer.new()
	check_box.add_theme_constant_override("separation", 10)
	check_panel.add_child(check_box)
	check_panel.visible = false

	log_panel = _glass(Vector2(240, 140), Vector2(1440, 760))
	log_label = UiTheme.rich(18)
	log_panel.add_child(log_label)
	log_panel.visible = false


# ---------------------------------------------------------------- 进地点、摆人

## 进入（或刷新）一个地点：读图、摆主角、队友、剧情人物。from_loc 是从哪个地点走来的；mem 是换屏前记住的位置。
func _enter(new_loc: String, from_loc: String, mem: Dictionary = {}) -> void:
	loc = new_loc
	fmap = FieldMap.make(MAPS, loc)
	tiles.fmap = fmap
	tiles.queue_redraw()
	if String(mem.get("loc", "")) == loc and fmap.walkable(mem["cell"]):
		cell = mem["cell"]
		facing = String(mem.get("facing", "down"))
	elif from_loc != "":
		cell = fmap.entry_cell(from_loc)
		facing = _facing_from(from_loc)
	else:
		cell = fmap.start_cell()
	trail.clear()
	path_queue.clear()
	for c in actors.get_children():
		actors.remove_child(c)
		c.queue_free()
	followers.clear()
	follower_ids.clear()
	npc_sprites.clear()
	npc_cells.clear()
	var squad: Array[String] = _squad()
	player_id = squad[0] if not squad.is_empty() else ""
	player = _walker(player_id)
	for i in range(1, squad.size()):
		follower_ids.append(squad[i])
		followers.append(_walker(squad[i]))
	for i in squad.size():
		trail.append(cell)
	_place_npcs()
	_draw_actors()
	_remember()


## 进门后面朝屋里。
func _facing_from(from_loc: String) -> String:
	var d: Vector2i = fmap.entry_cell(from_loc) - (fmap.door_cells(from_loc)[0] if not fmap.door_cells(from_loc).is_empty() else fmap.entry_cell(from_loc))
	for k: String in FieldMap.DIRS:
		if FieldMap.DIRS[k] == d:
			return k
	return "down"


## 当前分队活着的人：拍板的人排第一（他就是玩家操纵的主角）。
func _squad() -> Array[String]:
	var out: Array[String] = []
	var sid: String = view.squad_id()
	if sid == "":
		return out
	var living: Array[String] = view.ex.st.living_members(sid)
	var leader: String = view.ex.game.leader
	if living.has(leader):
		out.append(leader)
	for c in living:
		if c != leader:
			out.append(c)
	return out


func _walker(key: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	s.texture = FieldArt.walker(key, "down", 0)
	s.set_meta("key", key)
	actors.add_child(s)
	return s


## 这个地点上活着的剧情人物，按地图的站位摆。火焰女皇是全息投影，半透明。
func _place_npcs() -> void:
	var i := 0
	for npc_id: String in view.ex.st.npcs:
		var n: Dictionary = view.ex.st.npcs[npc_id]
		if String(n["location"]) != loc or not bool(n["alive"]):
			continue
		var c: Vector2i = fmap.npc_cell(npc_id, i)
		if not (fmap.data.get("npc_fixed", {}) as Dictionary).has(npc_id):
			i += 1
		var s := _walker(npc_id)
		if npc_id == "red_queen":
			s.modulate = Color(1.0, 0.45, 0.45, 0.7)
		npc_sprites[npc_id] = s
		npc_cells[npc_id] = c


## 剧情人物进出（npc_move、死亡）以后重新摆一遍，不动主角。
func _sync_npcs() -> void:
	for id: String in npc_sprites:
		var s: Sprite2D = npc_sprites[id]
		actors.remove_child(s)
		s.queue_free()
	npc_sprites.clear()
	npc_cells.clear()
	_place_npcs()
	_draw_actors()


func _pixel(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE, c.y * TILE - (FieldArt.WALK_H - TILE))


func _draw_actors() -> void:
	if player != null:
		player.position = _pixel(cell)
		player.texture = FieldArt.walker(player_id, facing, 0)
	for i in followers.size():
		var c: Vector2i = trail[mini(i + 1, trail.size() - 1)]
		followers[i].position = _pixel(c)
		followers[i].visible = c != cell
		followers[i].texture = FieldArt.walker(follower_ids[i], _dir_between(c, trail[mini(i, trail.size() - 1)]), 0)
	for id: String in npc_sprites:
		var s: Sprite2D = npc_sprites[id]
		var c: Vector2i = npc_cells[id]
		s.position = _pixel(c)
		s.texture = FieldArt.walker(id, _dir_between(c, cell), 0)
	_update_dark()


func _dir_between(a: Vector2i, b: Vector2i) -> String:
	var d := b - a
	if absi(d.x) > absi(d.y):
		return "right" if d.x > 0 else "left"
	if d.y < 0:
		return "up"
	return "down"


func _update_dark() -> void:
	var w: Dictionary = view.watch()
	dark.visible = bool(w["dark"])
	if player != null:
		dark.position = player.position + Vector2(TILE / 2.0, FieldArt.WALK_H - 6)


# ---------------------------------------------------------------- 刷新：事件 → 对话框、提示、窗口

func refresh() -> void:
	_ingest()
	if view.location() != loc and view.location() != "":
		var from := loc
		_enter(view.location(), from if view.ex.st.scenario.neighbors(view.location()).has(from) else "")
	else:
		_sync_npcs()
	_update_hud()
	if not box.visible:
		_show_next()
	_remember()


## 把还没播过的事件变成对话框台词或右边的提示。
func _ingest() -> void:
	var hist: Array = view.ex.history
	var toasts: Array[String] = []
	for i in range(seen, hist.size()):
		var e: Dictionary = hist[i]
		var t := String(e.get("type", ""))
		if t == "dialogue":
			var speaker := String(e.get("speaker", ""))
			messages.append({"id": speaker, "name": "" if speaker == "narrator" else String(view.names.get(speaker, speaker)), "text": String(e.get("text", ""))})
			continue
		if SILENT_TYPES.has(t):
			continue
		if t == "fear_changed" and (["darkness", "rest"].has(String(e.get("reason", ""))) or absf(float(e.get("amount", 0.0))) < 5.0):
			continue
		var line := EventText.describe(e, view.names)
		if line == "":
			continue
		if STORY_TYPES.has(t):
			messages.append({"id": "", "name": "", "text": line})
		else:
			toasts.append(line)
	seen = hist.size()
	for line in toasts.slice(maxi(0, toasts.size() - 5)):
		_toast(line)


func _toast(text: String) -> void:
	var l := UiTheme.label(text, 17, UiTheme.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = GLASS
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	toast_box.add_child(p)
	while toast_box.get_child_count() > 6:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	if is_inside_tree():
		get_tree().create_timer(5.0).timeout.connect(func() -> void:
			if is_instance_valid(p):
				p.queue_free())


## 对话框里放下一句；没有了就处理等着玩家的事（插图、选择、说服、战斗、结束）。
## 有插图要播时先播插图（剧本里插图总是那件事的第一个效果），播完（press_cutscene_done）再接着出台词。
func _show_next() -> void:
	var p: Dictionary = view.pending()
	if String(p.get("kind", "")) == "cutscene":
		box.visible = false
		action_bar.visible = false
		var n := String(p["name"])
		if n != _cutscene_sent:
			_cutscene_sent = n
			cutscene_requested.emit.call_deferred(n, String(p.get("text", "")))
		return
	if skip_messages:
		messages.clear()
	if messages.is_empty():
		box.visible = false
		hint_label.visible = true
		_after_messages()
		return
	var m: Dictionary = messages.pop_front()
	box.visible = true
	action_bar.visible = false
	hint_label.visible = false
	choice_panel.visible = false
	check_panel.visible = false
	var id := String(m["id"])
	box_name.text = String(m["name"]) if String(m["name"]) != "" else tr("——")
	box_text.text = String(m["text"])
	box_face.texture = PortraitSource.portrait(id) if id != "" and id != "narrator" else null
	box_face.visible = box_face.texture != null


func _after_messages() -> void:
	var p: Dictionary = view.pending()
	var kind := String(p.get("kind", ""))
	choice_panel.visible = false
	check_panel.visible = false
	if kind != "cutscene":
		_cutscene_sent = ""
	if kind != "battle":
		_battle_sent = false
	match kind:
		"cutscene":
			var n := String(p["name"])
			if n != _cutscene_sent:
				_cutscene_sent = n
				cutscene_requested.emit.call_deferred(n, String(p.get("text", "")))
		"choice":
			_build_choice(p)
		"check":
			_build_check(p)
		"battle":
			if not _battle_sent:
				_battle_sent = true
				battle_needed.emit.call_deferred()
	action_bar.visible = not (choice_panel.visible or check_panel.visible)
	if view.ended() and not _ended_sent:
		_ended_sent = true
		ended.emit.call_deferred()


func _build_choice(p: Dictionary) -> void:
	_clear(choice_box)
	choice_box.add_child(UiTheme.label(String(p["prompt"]), 22, UiTheme.ACCENT2))
	var opts: Array = p["options"]
	for i in opts.size():
		var o: Dictionary = opts[i]
		var b := UiTheme.button(tr("%d. %s") % [i + 1, String(o["text"])], 20)
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(press_choice.bind(String(o["id"])))
		choice_box.add_child(b)
	choice_panel.size = Vector2(1000, 90 + 58 * opts.size())
	choice_panel.visible = true


func _build_check(p: Dictionary) -> void:
	_clear(check_box)
	if String(p["id"]) != _pending_id:
		_pending_id = String(p["id"])
		chosen_keywords.clear()
	check_box.add_child(UiTheme.label(tr("%s：%s（难度 %d）") % [String(p["npc"]), String(p["goal"]), int(p["difficulty"])], 22, UiTheme.ACCENT2))
	if not bool(p["fact_ready"]):
		check_box.add_child(UiTheme.label(tr("你还没有把握开口。先推理出：%s") % String(p["fact_name"]), 18, UiTheme.MUTED))
		var row0 := HBoxContainer.new()
		row0.add_theme_constant_override("separation", 10)
		var think := UiTheme.button(tr("推理（10 分钟）"), 19)
		think.focus_mode = Control.FOCUS_NONE
		think.pressed.connect(press_deduce)
		row0.add_child(think)
		var give_up := UiTheme.button(tr("硬扛（放弃说服）"), 19)
		give_up.focus_mode = Control.FOCUS_NONE
		give_up.pressed.connect(press_persuade.bind(0))
		row0.add_child(give_up)
		check_box.add_child(row0)
		check_panel.visible = true
		return
	check_box.add_child(UiTheme.label(tr("让 %s 开口：选几个要说到的点（已选 %d 个）") % [String(p["thinker"]), chosen_keywords.size()], 18, UiTheme.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for k: String in p["keywords"]:
		var on := chosen_keywords.has(k)
		var b := UiTheme.button(("✓ " if on else "") + k, 19)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			if chosen_keywords.has(k):
				chosen_keywords.erase(k)
			else:
				chosen_keywords.append(k)
			_build_check(view.pending()))
		row.add_child(b)
	check_box.add_child(row)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	var say := UiTheme.button(tr("开口"), 20)
	say.focus_mode = Control.FOCUS_NONE
	say.custom_minimum_size = Vector2(180, 48)
	say.pressed.connect(press_persuade_keywords)
	row2.add_child(say)
	var give_up2 := UiTheme.button(tr("硬扛（放弃说服）"), 19)
	give_up2.focus_mode = Control.FOCUS_NONE
	give_up2.pressed.connect(press_persuade.bind(0))
	row2.add_child(give_up2)
	var free := UiTheme.button(tr("自己说（AI 评分）"), 19)
	free.focus_mode = Control.FOCUS_NONE
	free.pressed.connect(press_persuade_free)
	row2.add_child(free)
	check_box.add_child(row2)
	check_panel.visible = true


func _clear(c: Control) -> void:
	for n in c.get_children():
		c.remove_child(n)
		n.queue_free()


func _update_hud() -> void:
	var w: Dictionary = view.watch()
	var left := int(w["remaining_minutes"])
	var lines: Array[String] = []
	lines.append("[color=#e8a33d]%s[/color]　第 %d 分钟 · 剩余 %d:%02d · 击杀 %d（%.1f 点）" % [String(view.names.get(loc, loc)), int(view.ex.st.clock), left / 60, left % 60, int(w["kills"]), float(w["kill_points"])])
	lines.append(String(w["main_task"]))
	var extra: Array[String] = []
	if String(w["tether"]) != "":
		extra.append("绑定：" + String(w["tether"]))
	if bool(w["gag"]):
		extra.append("禁言：剧情人物面前别提主神")
	if bool(w["dark"]):
		extra.append("[color=#d8534f]全黑，恐惧持续上升[/color]")
	if not extra.is_empty():
		lines.append(" · ".join(extra))
	hud_label.text = "\n".join(lines)
	var plines: Array[String] = []
	for m: Dictionary in view.members():
		var color := "#e6e9ef" if bool(m["alive"]) else "#5a6270"
		plines.append("[color=%s]%s  %d/%d  恐惧 %d%s[/color]" % [color, String(m["name"]), int(m["hp"]), int(m["hp_max"]), int(m["fear"]), "  感染" if bool(m["infected"]) else ""])
	party_label.text = "\n".join(plines)


# ---------------------------------------------------------------- 输入与走动

## 有对话、窗口、等待中的事，或者上面盖着别的面板（对话框、暂停、插图）时不能走。
func busy() -> bool:
	if box.visible or choice_panel.visible or check_panel.visible or log_panel.visible:
		return true
	if not view.pending().is_empty() or view.ended():
		return true
	var host := get_parent().get_parent() if get_parent() != null else null
	if host != null:
		if host.get("pause") != null or host.get("panel") != null or host.get_node_or_null("Cutscene") != null:
			return true
	return false


func _process(_delta: float) -> void:
	if moving or busy():
		return
	if not path_queue.is_empty():
		var next: Vector2i = path_queue.pop_front()
		var d := _dir_between(cell, next)
		if next - cell != FieldMap.DIRS[d]:
			path_queue.clear()
			return
		step(d)
		if path_queue.is_empty() and not path_then.is_empty():
			var then := path_then
			path_then = {}
			_do_then(then)
		return
	for d: String in KEYS:
		for k: int in KEYS[d]:
			if Input.is_physical_key_pressed(k):
				step(d)
				return


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		if box.visible and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.keycode == KEY_SPACE or k.keycode == KEY_Z):
			_show_next()
			accept_event()
			return
		if choice_panel.visible:
			var idx := int(k.keycode) - int(KEY_1)
			var p: Dictionary = view.pending()
			if idx >= 0 and idx < 9 and String(p.get("kind", "")) == "choice" and idx < (p["options"] as Array).size():
				press_choice(String(p["options"][idx]["id"]))
				accept_event()
			return
		if k.keycode == KEY_L:
			_toggle_log()
			accept_event()
			return
		if not busy() and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.keycode == KEY_SPACE or k.keycode == KEY_Z):
			interact()
			accept_event()
			return


## 点地图：整屏控件自己收鼠标（点在对话框、窗口、按钮上的不会到这里）。
func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if box.visible:
		_show_next()
	elif not busy():
		click_cell(Vector2i(floori(mb.position.x / (TILE * SCALE)), floori(mb.position.y / (TILE * SCALE))))
	accept_event()


func _on_box_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_show_next()
		accept_event()


## 别人占着的格子（剧情人物）。队友不挡路。
func _blocked() -> Dictionary:
	var out := {}
	for id: String in npc_cells:
		out[npc_cells[id]] = true
	return out


## 朝 d 走一格：撞墙就只转身；走进门就去隔壁。
func step(d: String) -> void:
	facing = d
	var target: Vector2i = cell + FieldMap.DIRS[d]
	if fmap.is_door(target):
		_go_door(fmap.door_dest(target))
		return
	if not fmap.walkable(target) or _blocked().has(target):
		_draw_actors()
		return
	var before: Array[Vector2i] = trail.duplicate()
	trail.push_front(target)
	trail.resize(maxi(1, follower_ids.size() + 1))
	cell = target
	walk_frame = 3 - walk_frame
	_remember()
	if not is_inside_tree():
		_draw_actors()
		return
	moving = true
	var tw := create_tween().set_parallel(true)
	player.texture = FieldArt.walker(player_id, facing, walk_frame)
	tw.tween_property(player, "position", _pixel(cell), STEP_TIME)
	for i in followers.size():
		var c: Vector2i = trail[mini(i + 1, trail.size() - 1)]
		var was: Vector2i = before[mini(i + 1, before.size() - 1)]
		followers[i].visible = c != cell
		followers[i].texture = FieldArt.walker(follower_ids[i], _dir_between(was, c), walk_frame)
		tw.tween_property(followers[i], "position", _pixel(c), STEP_TIME)
	tw.chain().tween_callback(func() -> void:
		moving = false
		_draw_actors())


## 对着前面一格按确认：柜子 → 搜索；剧情人物或队友 → 说话；门 → 过去。
func interact() -> void:
	var target: Vector2i = cell + FieldMap.DIRS[facing]
	if fmap.is_search(target):
		press_search()
		return
	for id: String in npc_cells:
		if npc_cells[id] == target:
			press_talk(id)
			return
	for i in follower_ids.size():
		if trail[mini(i + 1, trail.size() - 1)] == target:
			press_talk(follower_ids[i])
			return
	if fmap.is_door(target):
		_go_door(fmap.door_dest(target))


## 点了地图上的某一格：走过去；点的是门、柜子或人，就走到旁边再进门 / 搜索 / 说话。
func click_cell(c: Vector2i) -> void:
	if not fmap.inside(c):
		return
	path_queue.clear()
	path_then = {}
	var blocked := _blocked()
	var goal := c
	var then := {}
	if fmap.is_door(c):
		then = {"door": fmap.door_dest(c), "face": c}
		goal = Vector2i(-1, -1)
		for d: Vector2i in FieldMap.DIRS.values():
			if fmap.walkable(c + d) and not fmap.is_door(c + d):
				goal = c + d
	elif fmap.is_search(c) or blocked.has(c):
		then = {"interact": true, "face": c}
		goal = Vector2i(-1, -1)
		var best := 99999
		for d: Vector2i in FieldMap.DIRS.values():
			var n: Vector2i = c + d
			if fmap.walkable(n) and not blocked.has(n) and not fmap.is_door(n):
				var len: int = 0 if n == cell else fmap.path(cell, n, blocked).size()
				if (n == cell or len > 0) and len < best:
					best = len
					goal = n
	if goal.x < 0:
		return
	if goal == cell:
		_do_then(then)
		return
	path_queue = fmap.path(cell, goal, blocked)
	path_then = then


func _do_then(then: Dictionary) -> void:
	if then.has("face"):
		facing = _dir_between(cell, then["face"])
		_draw_actors()
	if then.has("door"):
		_go_door(String(then["door"]))
	elif bool(then.get("interact", false)):
		interact()


## 走进门：规则允许就去隔壁（时间照走），否则说明为什么不行。
func _go_door(dest: String) -> void:
	if dest == "":
		return
	if not view.can_move(dest):
		var why := tr("门打不开。") if view.blocked_reason() == "" else tr("现在走不开。")
		_toast(why)
		_draw_actors()
		return
	var from := loc
	view.move(dest)
	if view.location() == dest:
		_enter(dest, from)
	refresh()


func _toggle_log() -> void:
	log_panel.visible = not log_panel.visible
	if log_panel.visible:
		log_label.text = "\n".join(view.log_tail(40))


func _toggle_items() -> void:
	item_box.visible = not item_box.visible
	_clear(item_box)
	if not item_box.visible:
		return
	var acts: Array[Dictionary] = view.item_actions()
	if acts.is_empty():
		item_box.add_child(UiTheme.label(tr("现在没有能用的道具。"), 17, UiTheme.MUTED))
	for a: Dictionary in acts:
		var b := UiTheme.button(String(a["label"]), 17)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			press_item(String(a["char"]), String(a["item"]))
			item_box.visible = false)
		item_box.add_child(b)


# ---------------------------------------------------------------- 对外的动作（界面按钮、main、验收脚本共用）

## 把还没看的台词直接跳过（脚本和测试用；玩家是一句句点过去的）。
func flush_messages() -> void:
	messages.clear()
	box.visible = false


func press_move(loc_id: String) -> bool:
	if not view.can_move(loc_id):
		return false
	flush_messages()
	_go_door(loc_id)
	return true


func press_choice(option_id: String) -> bool:
	if view.pending().get("kind", "") != "choice":
		return false
	flush_messages()
	choice_panel.visible = false
	view.choose(option_id)
	refresh()
	return true


func press_persuade(level: int) -> bool:
	if view.pending().get("kind", "") != "check":
		return false
	flush_messages()
	check_panel.visible = false
	view.persuade(level)
	refresh()
	return true


func select_keywords(keys: Array) -> void:
	chosen_keywords.clear()
	for k: String in keys:
		chosen_keywords.append(k)


func press_persuade_keywords() -> bool:
	if chosen_keywords.is_empty() or view.pending().get("kind", "") != "check":
		return false
	flush_messages()
	check_panel.visible = false
	view.persuade_with(chosen_keywords)
	chosen_keywords.clear()
	refresh()
	return true


func press_persuade_free() -> bool:
	if view.pending().get("kind", "") != "check":
		return false
	persuade_requested.emit()
	return true


func press_talk(npc_id: String) -> bool:
	for t: Dictionary in view.talk_targets():
		if String(t["id"]) == npc_id:
			talk_requested.emit(npc_id)
			return true
	return false


func press_rest(minutes: int) -> void:
	if view.blocked_reason() != "":
		return
	flush_messages()
	view.rest(minutes)
	refresh()


func press_search() -> void:
	if view.blocked_reason() != "":
		return
	view.search()
	refresh()


func press_deduce() -> void:
	var thinker: String = view.best_thinker_id()
	if thinker != "":
		view.deduce("queen_controls_lasers", thinker)
	refresh()


func press_item(char_id: String, item_id: String) -> void:
	view.use_item(char_id, item_id)
	refresh()


func press_cutscene_done() -> void:
	view.dismiss_cutscene()
	refresh()
