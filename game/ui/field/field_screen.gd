extends Control
## 地点场景：RPG 式探索（设计规格 5.1、11；设计 2026-11-10 第 2 节）。
## 地图是 Tiled 文件（tiled_map.gd 读、field_tiles.gd 填进 TileMapLayer：地面、墙、装饰在人物下面，上层在人物上面）；
## 像素层 480×256（一屏 30×16 格，每格 16 像素），整数放大 4 倍铺满顶栏下面的 1920×1024；
## 地图比一屏大时 Camera2D 跟着主角走（自带平滑、地图边界、一点拖拽边距），走完一步再跟。
## 主角（拍板的人）用方向键 / WASD 走，队友跟在后面；对着人按 Enter 说话，对着柜子按 Enter 搜索；
## 走进门就去隔壁地点（时间照规则推进）；点地面会自己走过去（先按镜头位置换算格子）。
## 两档视野（设计 2026-11-12 第 6 节）：近 = 480×256 放大 4 倍（一屏 30×16 格），远 = 640×341 放大 3 倍（一屏 40×21 格），V 切换。
## 人多也走得开：主角停下来一会儿，队友就散开站到附近；顶着剧情人物走一会儿，对方会和你换个位置让路。
## 走近的人头顶显示名字，有新话题的带"…"；T 打开"在场的人"，可以直接找任何人说话或者看人物卡。
## 画面：图块集的图片在就用，不在就画灰盒；有 Codex 的行走图就用（field_art.gd），没有用占位小人；
## 每个地点有环境光和灯（data/maps 里的 ambient / lights / glows），黑暗地点只剩主角手里的手电筒；人物脚下有影子。
## 剧情事件不堆在日志里：台词一句一句打字出在底部的对话框里（左边是立绘），选择弹选项窗口，说服弹说服窗口，
## 其他结果在右边飘一条提示；完整记录按 L 看。规则全在 core，这里只调 ExpeditionView。
## 对外的 press_* 方法和信号跟旧的地点图界面一样，main.gd 和切片验收不用改。

signal battle_needed
signal ended
signal talk_requested(npc_id: String)
signal persuade_requested
signal cutscene_requested(name: String, text: String)
signal view_changed(wide: bool)

const ExpeditionView = preload("res://ui/expedition/expedition_view.gd")
const TiledMap = preload("res://ui/field/tiled_map.gd")
const FieldTiles = preload("res://ui/field/field_tiles.gd")
const FieldArt = preload("res://ui/field/field_art.gd")
const UiTheme = preload("res://ui/ui_theme.gd")
const EventText = preload("res://ui/event_text.gd")
const PortraitSource = preload("res://ui/art/portrait_source.gd")
const Topics = preload("res://core/dialogue/topics.gd")
const Cohesion = preload("res://core/social/cohesion.gd")
const DataLoader = preload("res://core/util/data_loader.gd")

const VIEW_NEAR := Vector2i(480, 256)
const VIEW_FAR := Vector2i(640, 341)
## 主角停下来多久以后队友散开（秒）；顶着剧情人物走多久对方让路（秒）。
const SPREAD_DELAY := 1.2
const GIVE_WAY_DELAY := 0.35
## 头顶名字在多少格以内显示。
const NAME_RANGE := 6
const TILE := 16
const STEP_TIME := 0.13
## 脚底离格子下沿几像素（站在格子中间偏下，看起来踩在地上）。
const FOOT_LIFT := 2
## 打字速度：每秒几个字。
const REVEAL_CPS := 45.0
const GLASS := Color(0.04, 0.05, 0.08, 0.82)
const BOX_BG := Color(0.03, 0.04, 0.07, 0.94)
## 黑暗地点的环境光：几乎全黑，只看得到手电筒照到的地方。
const DARK_AMBIENT := Color("0b0e16")
const FACING_ANGLE := {"right": 0.0, "down": PI / 2.0, "left": PI, "up": -PI / 2.0}
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

## 换屏（打完仗回来、关掉对话框）以后还站在原地、队友还在身后、已经播过的事件不再播：按远征对象记住。
static var _memory: Dictionary = {}
## 只给验收脚本用：台词不进对话框，直接跳到"等玩家做的事"（脚本直接读 core 的结果，不点对话框）。
static var skip_messages := false
## 地图目录（每个地点一个 <地点>.tmj）；测试会把它指到 tests/fixtures 下的地图。
static var maps_dir := "res://data/maps/biohazard1"
## 视野：true = 远（一屏 40×21 格）。main 从设置里读，切换时存回设置。
static var wide := true


var view: RefCounted
var fmap: RefCounted
## 这一屏像素层的大小和放大倍数（随视野变）。
var pixel_size := VIEW_FAR
var scale_factor := 3
## 对话记忆（main 传进来的 session.dialogues）：人物卡和"…"要看对话信任。
var dialogue_store: Dictionary = {}
## 队友散开了：各自站在 spread_cells 里，不在主角身后排队。
var spread := false
var spread_cells: Array[Vector2i] = []
## 被你挤开换过位置的剧情人物：人物 id → 现在站的格子（只在这个地点有效）。
var npc_override: Dictionary = {}
var _idle := 0.0
var _bump_id := ""
var _bump_since := 0.0
var _new_topics: Dictionary = {}
var name_layer: Control
var name_labels: Dictionary = {}
var roster_panel: PanelContainer
var roster_box: VBoxContainer
var roster_scroll: ScrollContainer
var card_panel: PanelContainer
var card_face: TextureRect
var card_title: Label
var card_body: RichTextLabel
var card_id := ""
var loc: String = ""
var viewport: SubViewport
var display: TextureRect
## 图层名（floor / walls / decor / over）→ TileMapLayer。
var map_layers: Dictionary = {}
var camera: Camera2D
var light_root: Node2D
var glow_layer: CanvasLayer
var canvas_mod: CanvasModulate
var actors: Node2D
var dark: Node2D
var flash: PointLight2D
var aura: PointLight2D
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
var flickers: Array[Dictionary] = []
var _pending_id := ""
var _cutscene_sent := ""
var _ended_sent := false
var _battle_sent := false
var _time := 0.0
var _reveal := 0.0
var _additive: CanvasItemMaterial

var hud: PanelContainer
var hud_label: RichTextLabel
var party: PanelContainer
var party_label: RichTextLabel
var box: PanelContainer
var box_face: TextureRect
var box_margin: MarginContainer
var box_name: Label
var box_text: Label
var box_more: Label
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
var prompt: PanelContainer
var prompt_label: Label
var banner: Label


func setup(expedition: RefCounted, char_names: Dictionary) -> void:
	view = ExpeditionView.new(expedition, char_names)
	_build()
	var mem: Dictionary = _memory.get(expedition.get_instance_id(), {})
	seen = int(mem.get("seen", 0))
	_enter(view.location(), "", mem)
	refresh()


## 记住现在站哪、队友站哪、播到第几条事件。
func _remember() -> void:
	_memory[view.ex.get_instance_id()] = {
		"loc": loc, "cell": cell, "facing": facing, "seen": seen, "trail": trail.duplicate(),
		"followers": follower_ids.duplicate(), "spread": spread, "spread_cells": spread_cells.duplicate(),
		"npc_override": npc_override.duplicate(),
	}


# ---------------------------------------------------------------- 搭界面

func _style(bg: Color, radius: int, mx: int, my: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = UiTheme.LINE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my
	return sb


func _glass(pos: Vector2, size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.size = size
	p.add_theme_stylebox_override("panel", _style(GLASS, 8, 16, 10))
	add_child(p)
	return p


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.paint_bg(self)
	_additive = CanvasItemMaterial.new()
	_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	pixel_size = VIEW_FAR if wide else VIEW_NEAR
	scale_factor = 3 if wide else 4
	viewport = SubViewport.new()
	viewport.size = pixel_size
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.snap_2d_transforms_to_pixel = true
	add_child(viewport)
	for layer_name: String in ["floor", "walls", "decor"]:
		var layer := TileMapLayer.new()
		layer.name = layer_name
		viewport.add_child(layer)
		map_layers[layer_name] = layer
	light_root = Node2D.new()
	viewport.add_child(light_root)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	viewport.add_child(actors)
	var over := TileMapLayer.new()
	over.name = "over"
	viewport.add_child(over)
	map_layers["over"] = over
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.drag_horizontal_enabled = true
	camera.drag_vertical_enabled = true
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		camera.set_drag_margin(side, 0.12)
	viewport.add_child(camera)
	dark = Node2D.new()
	dark.visible = false
	viewport.add_child(dark)
	flash = PointLight2D.new()
	flash.texture = FieldArt.cone_texture()
	flash.offset = Vector2(FieldArt.LIGHT_SIZE / 2.0, 0)
	flash.color = Color("fff1c8")
	flash.energy = 1.35
	dark.add_child(flash)
	aura = PointLight2D.new()
	aura.texture = FieldArt.light_texture()
	aura.texture_scale = 0.8
	aura.color = Color("ffe9b8")
	aura.energy = 0.5
	dark.add_child(aura)
	canvas_mod = CanvasModulate.new()
	viewport.add_child(canvas_mod)
	glow_layer = CanvasLayer.new()
	glow_layer.layer = 1
	viewport.add_child(glow_layer)
	display = TextureRect.new()
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.size = Vector2(pixel_size * scale_factor)
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)
	name_layer = Control.new()
	name_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_layer)

	hud = _glass(Vector2(16, 12), Vector2(560, 0))
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_label = UiTheme.rich(17)
	hud_label.bbcode_enabled = true
	hud_label.scroll_active = false
	hud_label.fit_content = true
	hud_label.custom_minimum_size = Vector2(528, 0)
	hud.add_child(hud_label)
	party = _glass(Vector2(1664, 12), Vector2(240, 0))
	party.mouse_filter = Control.MOUSE_FILTER_IGNORE
	party_label = UiTheme.rich(15)
	party_label.bbcode_enabled = true
	party_label.scroll_active = false
	party_label.fit_content = true
	party_label.custom_minimum_size = Vector2(208, 0)
	party.add_child(party_label)

	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(1384, 240)
	toast_box.size = Vector2(520, 400)
	toast_box.add_theme_constant_override("separation", 6)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_box)

	banner = UiTheme.label(tr(""), 34, UiTheme.ACCENT2)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.position = Vector2(560, 120)
	banner.size = Vector2(800, 50)
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	banner.add_theme_constant_override("outline_size", 8)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate.a = 0.0
	add_child(banner)

	prompt = PanelContainer.new()
	prompt.add_theme_stylebox_override("panel", _style(GLASS, 6, 10, 4))
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_label = UiTheme.label(tr(""), 17, UiTheme.TEXT)
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	prompt.add_child(prompt_label)
	prompt.visible = false
	add_child(prompt)

	hint_label = UiTheme.label(tr("方向键 / WASD 走动 · Enter 说话、调查 · 点地面自动走过去 · T 在场的人 · V 视野 · L 记录 · Esc 菜单"), 16, UiTheme.MUTED)
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

	# 对话框：底部整条；有立绘时立绘站在左边、下半身藏在对话框后面（视觉小说的摆法）。
	box_face = TextureRect.new()
	box_face.position = Vector2(64, 236)
	box_face.size = Vector2(480, 720)
	box_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	box_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_face.visible = false
	add_child(box_face)
	box = PanelContainer.new()
	box.position = Vector2(40, 784)
	box.size = Vector2(1840, 228)
	var bsb := _style(BOX_BG, 12, 28, 18)
	bsb.border_color = Color("3a4a78")
	bsb.set_border_width_all(2)
	box.add_theme_stylebox_override("panel", bsb)
	add_child(box)
	box_margin = MarginContainer.new()
	box.add_child(box_margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	box_margin.add_child(col)
	box_name = UiTheme.label(tr(""), 26, UiTheme.ACCENT2)
	col.add_child(box_name)
	box_text = UiTheme.label(tr(""), 26)
	box_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(box_text)
	box_more = UiTheme.label(tr("▼"), 18, UiTheme.MUTED)
	box_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(box_more)
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

	roster_panel = _glass(Vector2(500, 110), Vector2(920, 0))
	roster_scroll = ScrollContainer.new()
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	roster_panel.add_child(roster_scroll)
	roster_box = VBoxContainer.new()
	roster_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_box.add_theme_constant_override("separation", 4)
	roster_scroll.add_child(roster_box)
	roster_panel.visible = false

	card_panel = _glass(Vector2(380, 130), Vector2(1160, 780))
	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 24)
	card_panel.add_child(card_row)
	card_face = TextureRect.new()
	card_face.custom_minimum_size = Vector2(360, 540)
	card_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_row.add_child(card_face)
	var card_col := VBoxContainer.new()
	card_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_col.add_theme_constant_override("separation", 10)
	card_row.add_child(card_col)
	card_title = UiTheme.label(tr(""), 30, UiTheme.ACCENT2)
	card_col.add_child(card_title)
	card_body = UiTheme.rich(19)
	card_body.bbcode_enabled = true
	card_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_col.add_child(card_body)
	var card_buttons := HBoxContainer.new()
	card_buttons.add_theme_constant_override("separation", 10)
	card_col.add_child(card_buttons)
	var card_talk := UiTheme.button(tr("说话"), 20)
	card_talk.focus_mode = Control.FOCUS_NONE
	card_talk.pressed.connect(func() -> void:
		var id := card_id
		close_panels()
		press_talk(id))
	card_buttons.add_child(card_talk)
	var card_back := UiTheme.button(tr("返回"), 20)
	card_back.focus_mode = Control.FOCUS_NONE
	card_back.pressed.connect(close_panels)
	card_buttons.add_child(card_back)
	card_panel.visible = false


# ---------------------------------------------------------------- 进地点、摆人、打光

## 进入（或刷新）一个地点：读图、打光、摆剧情人物、主角和队友。from_loc 是从哪个地点走来的；mem 是换屏前记住的位置。
func _enter(new_loc: String, from_loc: String, mem: Dictionary = {}) -> void:
	var first_time := loc != new_loc
	loc = new_loc
	fmap = TiledMap.make(maps_dir, loc)
	for layer_name: String in map_layers:
		FieldTiles.fill(map_layers[layer_name], fmap, layer_name)
	_set_camera_limits()
	_build_lights()
	var restored: bool = String(mem.get("loc", "")) == loc and fmap.walkable(mem["cell"])
	if restored:
		cell = mem["cell"]
		facing = String(mem.get("facing", "down"))
	elif from_loc != "":
		cell = fmap.entry_cell(from_loc)
		facing = fmap.entry_facing(from_loc)
	else:
		cell = fmap.start_cell()
		facing = fmap.start_facing()
	path_queue.clear()
	for c in actors.get_children():
		actors.remove_child(c)
		c.queue_free()
	for id: String in name_labels:
		(name_labels[id] as Control).queue_free()
	name_labels.clear()
	followers.clear()
	follower_ids.clear()
	npc_sprites.clear()
	npc_cells.clear()
	npc_override = (mem.get("npc_override", {}) as Dictionary).duplicate() if restored else {}
	_place_npcs()
	var squad: Array[String] = _squad()
	player_id = squad[0] if not squad.is_empty() else ""
	player = _walker(player_id)
	var order: Array[String] = []
	for i in range(1, squad.size()):
		order.append(squad[i])
	var mem_order: Array = mem.get("followers", []) if restored else []
	if mem_order.size() == order.size() and not mem_order.is_empty():
		var same := true
		for id in mem_order:
			if not order.has(String(id)):
				same = false
		if same:
			order.clear()
			for id in mem_order:
				order.append(String(id))
	for id in order:
		follower_ids.append(id)
		followers.append(_walker(id))
	var old: Array = mem.get("trail", []) if restored else []
	trail = _initial_trail(cell, squad.size(), old)
	spread = false
	spread_cells.clear()
	if restored and bool(mem.get("spread", false)):
		var cells: Array = mem.get("spread_cells", [])
		if cells.size() == followers.size():
			spread = true
			for c in cells:
				spread_cells.append(Vector2i(c))
	_idle = 0.0
	_refresh_new_topics()
	_draw_actors()
	_snap_camera()
	_remember()
	if first_time and not restored:
		_show_banner(String(view.names.get(loc, loc)))


## 队友站的位置：换屏回来按记住的；否则站在主角身后（走得到的格子里，越靠主角正后方越优先；
## 身后没地方就站两边，不站到主角正前方；避开墙、门和剧情人物）。
## 第一步时各自挪到前一个人原来的位置，之后就排成一路跟着走。
func _initial_trail(start: Vector2i, count: int, old: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if old.size() == count and not old.is_empty() and Vector2i(old[0]) == start:
		for c in old:
			out.append(Vector2i(c))
		return out
	out.append(start)
	var blocked := _blocked()
	var back: Vector2i = -TiledMap.DIRS[facing]
	var side := Vector2i(back.y, back.x)
	var dist := {start: 0}
	var queue: Array[Vector2i] = [start]
	var cands: Array[Vector2i] = []
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if int(dist[c]) >= 5:
			continue
		for d: Vector2i in TiledMap.DIRS.values():
			var n: Vector2i = c + d
			if dist.has(n) or not fmap.walkable(n) or fmap.is_door(n) or blocked.has(n):
				continue
			dist[n] = int(dist[c]) + 1
			queue.append(n)
			cands.append(n)
	var score := func(c: Vector2i) -> float:
		var off := c - start
		var along := off.x * back.x + off.y * back.y
		var across := absi(off.x * side.x + off.y * side.y)
		var s := across * 2.5 + (float(along) if along > 0 else 4.0 - along * 3.0)
		if along < 0 and across == 0:
			s += 4.0
		return s + c.y * 0.001 + c.x * 0.00001
	cands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return score.call(a) < score.call(b))
	for c in cands:
		if out.size() >= count:
			break
		out.append(c)
	while out.size() < count:
		out.append(start)
	return out


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


## 一个行走小人：脚底中点对齐格子，脚下有影子。
func _walker(key: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	var size := FieldArt.walker_size(key)
	s.offset = Vector2(-floorf(size.x / 2.0), -size.y)
	s.texture = FieldArt.walker(key, "down", 0)
	s.set_meta("key", key)
	var sh := Sprite2D.new()
	sh.texture = FieldArt.shadow_texture()
	sh.show_behind_parent = true
	s.add_child(sh)
	actors.add_child(s)
	return s


## 这个地点的灯和自发光光晕（光晕在环境光管不到的那一层，黑暗里也亮）。
func _build_lights() -> void:
	for holder: Node in [light_root, glow_layer]:
		for c in holder.get_children():
			holder.remove_child(c)
			c.queue_free()
	flickers.clear()
	var k := 0
	for l: Dictionary in fmap.lights():
		var p := _light(l["color"], float(l["radius"]), float(l["energy"]))
		p.position = _center(l["cell"])
		light_root.add_child(p)
		if bool(l["flicker"]):
			flickers.append({"node": p, "base": p.energy, "phase": 1.7 * k})
		k += 1
	for g: Dictionary in fmap.glows():
		var s := Sprite2D.new()
		s.texture = FieldArt.light_texture()
		s.material = _additive
		s.modulate = g["color"]
		s.scale = Vector2.ONE * float(g["radius"]) * TILE * 2.0 / FieldArt.LIGHT_SIZE
		s.position = _center(g["cell"])
		glow_layer.add_child(s)


## 一盏点光：radius 是格数。
func _light(color: Color, radius: float, energy: float) -> PointLight2D:
	var p := PointLight2D.new()
	p.texture = FieldArt.light_texture()
	p.texture_scale = radius * TILE * 2.0 / FieldArt.LIGHT_SIZE
	p.color = color
	p.energy = energy
	return p


## 这个地点上活着的剧情人物，按地图的站位摆。火焰女皇是全息投影：半透明、发红光、没有影子。
func _place_npcs() -> void:
	var i := 0
	for npc_id: String in view.ex.st.npcs:
		var n: Dictionary = view.ex.st.npcs[npc_id]
		if String(n["location"]) != loc or not bool(n["alive"]):
			continue
		var c: Vector2i = fmap.npc_cell(npc_id, i)
		if not fmap.is_fixed_npc(npc_id):
			i += 1
		if npc_override.has(npc_id) and fmap.walkable(npc_override[npc_id]):
			c = npc_override[npc_id]
		var s := _walker(npc_id)
		if npc_id == "red_queen":
			s.modulate = Color(1.0, 0.45, 0.45, 0.72)
			s.get_child(0).visible = false
			var glow := _light(Color("ff5a5a"), 3.5, 0.9)
			glow.position = Vector2(0, -10)
			s.add_child(glow)
			flickers.append({"node": glow, "base": glow.energy, "phase": 0.4})
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
	var kept: Array[Dictionary] = []
	for f: Dictionary in flickers:
		if is_instance_valid(f["node"]) and (f["node"] as Node).get_parent() == light_root:
			kept.append(f)
	flickers = kept
	_place_npcs()
	_draw_actors()


## 格子的脚底中点（行走小人的位置）。
func _pixel(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE / 2.0, c.y * TILE + TILE - FOOT_LIFT)


func _center(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE / 2.0, c.y * TILE + TILE / 2.0)


func _draw_actors() -> void:
	if player != null:
		player.position = _pixel(cell)
		player.texture = FieldArt.walker(player_id, facing, 0)
	for i in followers.size():
		var c: Vector2i = follower_cell(i)
		followers[i].position = _pixel(c)
		followers[i].visible = c != cell
		var look: Vector2i = cell if spread else trail[mini(i, trail.size() - 1)]
		followers[i].texture = FieldArt.walker(follower_ids[i], _dir_between(c, look), 0)
	for id: String in npc_sprites:
		var s: Sprite2D = npc_sprites[id]
		var c: Vector2i = npc_cells[id]
		s.position = _pixel(c)
		s.texture = FieldArt.walker(id, _dir_between(c, cell), 0)
	_update_lighting()
	_update_prompt()


func _dir_between(a: Vector2i, b: Vector2i) -> String:
	var d := b - a
	if absi(d.x) > absi(d.y):
		return "right" if d.x > 0 else "left"
	if d.y < 0:
		return "up"
	return "down"


## 镜头边界：地图比一屏大时贴着地图边；比一屏小的那个方向把地图放在正中间（四周露出背景）。
func _set_camera_limits() -> void:
	var map_px: Vector2i = fmap.size * TILE
	var pad_x := maxi(0, pixel_size.x - map_px.x) / 2
	var pad_y := maxi(0, pixel_size.y - map_px.y) / 2
	camera.limit_left = -pad_x
	camera.limit_top = -pad_y
	camera.limit_right = -pad_x + maxi(map_px.x, pixel_size.x)
	camera.limit_bottom = -pad_y + maxi(map_px.y, pixel_size.y)


## 切换视野：远（一屏 40×21 格，放大 3 倍）或近（一屏 30×16 格，放大 4 倍）。
func set_wide(on: bool) -> void:
	wide = on
	pixel_size = VIEW_FAR if on else VIEW_NEAR
	scale_factor = 3 if on else 4
	if viewport == null:
		return
	viewport.size = pixel_size
	display.size = Vector2(pixel_size * scale_factor)
	if fmap != null:
		_set_camera_limits()
		_snap_camera()
		_update_prompt()


## 镜头对准的位置：主角胸口（脚底往上 8 像素）。
func _camera_target() -> Vector2:
	return player.position + Vector2(0, -8) if player != null else Vector2(pixel_size) / 2.0


## 换地点、换屏回来时镜头直接到位、主角在正中（不从上一个位置滑过来，拖拽边距这一下也不算）。
func _snap_camera() -> void:
	camera.position = _camera_target()
	if camera.is_inside_tree():
		camera.drag_horizontal_enabled = false
		camera.drag_vertical_enabled = false
		camera.reset_smoothing()
		camera.force_update_scroll()
		camera.drag_horizontal_enabled = true
		camera.drag_vertical_enabled = true


## 屏幕左上角对着的世界像素（不在场景树里时镜头不起作用，就是原点）。
func view_origin() -> Vector2:
	if not camera.is_inside_tree():
		return Vector2.ZERO
	return (camera.get_screen_center_position() - Vector2(pixel_size) / 2.0).round()


## 地点画面上的一点（场景控件里的坐标）→ 地图格子，算上镜头滚动。
func cell_at(screen_pos: Vector2) -> Vector2i:
	var px := screen_pos / scale_factor + view_origin()
	return Vector2i(floori(px.x / TILE), floori(px.y / TILE))


## 环境光：黑暗地点几乎全黑、打开手电筒；其余按地图的环境光。
func _update_lighting() -> void:
	var w: Dictionary = view.watch()
	var is_dark := bool(w["dark"])
	dark.visible = is_dark
	canvas_mod.color = DARK_AMBIENT if is_dark else fmap.ambient()
	_follow_flashlight()


func _follow_flashlight() -> void:
	if player == null:
		return
	dark.position = player.position + Vector2(0, -8)
	flash.rotation = float(FACING_ANGLE.get(facing, PI / 2.0))


## 进新地点时屏幕上方淡入淡出一下地名。
func _show_banner(text: String) -> void:
	banner.text = text
	if not is_inside_tree():
		return
	banner.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.35)
	tw.tween_interval(1.4)
	tw.tween_property(banner, "modulate:a", 0.0, 0.6)


# ---------------------------------------------------------------- 刷新：事件 → 对话框、提示、窗口

func refresh() -> void:
	_ingest()
	if view.location() != loc and view.location() != "":
		var from := loc
		_enter(view.location(), from if view.ex.st.scenario.neighbors(view.location()).has(from) else "")
	else:
		_sync_npcs()
	_refresh_new_topics()
	_update_hud()
	if not box.visible:
		_show_next()
	_update_prompt()
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
		if SILENT_TYPES.has(t) or t == "topic_talked":
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
	p.add_theme_stylebox_override("panel", _style(GLASS, 6, 10, 6))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	toast_box.add_child(p)
	while toast_box.get_child_count() > 6:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	if is_inside_tree():
		var tw := p.create_tween()
		tw.tween_interval(4.2)
		tw.tween_property(p, "modulate:a", 0.0, 0.8)
		tw.tween_callback(p.queue_free)


## 对话框里放下一句（一个字一个字打出来）；没有了就处理等着玩家的事（插图、选择、说服、战斗、结束）。
## 有插图要播时先播插图（剧本里插图总是那件事的第一个效果），播完（press_cutscene_done）再接着出台词。
func _show_next() -> void:
	var p: Dictionary = view.pending()
	if String(p.get("kind", "")) == "cutscene":
		_hide_box()
		action_bar.visible = false
		var n := String(p["name"])
		if n != _cutscene_sent:
			_cutscene_sent = n
			cutscene_requested.emit.call_deferred(n, String(p.get("text", "")))
		return
	if skip_messages:
		messages.clear()
	if messages.is_empty():
		_hide_box()
		hint_label.visible = true
		_after_messages()
		return
	var m: Dictionary = messages.pop_front()
	box.visible = true
	action_bar.visible = false
	hint_label.visible = false
	prompt.visible = false
	choice_panel.visible = false
	check_panel.visible = false
	var id := String(m["id"])
	box_name.text = String(m["name"]) if String(m["name"]) != "" else tr("——")
	box_text.text = String(m["text"])
	_reveal = 0.0
	box_text.visible_characters = 0 if is_inside_tree() else -1
	var has_face := id != "" and id != "narrator" and PortraitSource.has_portrait(id)
	box_face.texture = PortraitSource.portrait(id) if has_face else null
	box_face.visible = has_face
	box_margin.add_theme_constant_override("margin_left", 500 if has_face else 0)


func _hide_box() -> void:
	box.visible = false
	box_face.visible = false


## 确认键 / 点击：字还没打完就一下子显示完，打完了就下一句。
func _advance() -> void:
	if box_text.visible_characters >= 0:
		box_text.visible_characters = -1
		return
	_show_next()


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


## 左上角：地点、时间、任务；右上角：队伍。都按内容收紧大小。
func _update_hud() -> void:
	var w: Dictionary = view.watch()
	var left := int(w["remaining_minutes"])
	var lines: Array[String] = []
	var top := "[color=#e8a33d][font_size=20]%s[/font_size][/color]　第 %d 分钟 · 剩余 [color=#e8a33d]%d:%02d[/color]" % [String(view.names.get(loc, loc)), int(view.ex.st.clock), left / 60, left % 60]
	if int(w["kills"]) > 0:
		top += " · 击杀 %d（%.1f 点）" % [int(w["kills"]), float(w["kill_points"])]
	lines.append(top)
	lines.append("[color=#aab2c0]%s[/color]" % String(w["main_task"]))
	var extra: Array[String] = []
	if String(w["tether"]) != "":
		extra.append("绑定：" + String(w["tether"]))
	if bool(w["gag"]):
		extra.append("禁言：剧情人物面前别提主神")
	if bool(w["dark"]):
		extra.append("[color=#d8534f]全黑，恐惧持续上升[/color]")
	if not extra.is_empty():
		lines.append("[color=#aab2c0]%s[/color]" % " · ".join(extra))
	hud_label.text = "\n".join(lines)
	var plines: Array[String] = []
	for m: Dictionary in view.members():
		if not bool(m["alive"]):
			plines.append("[color=#5a6270]%s　阵亡[/color]" % String(m["name"]))
			continue
		var hp_ratio := float(m["hp"]) / maxf(1.0, float(m["hp_max"]))
		var hp_color := "#7fd08a" if hp_ratio > 0.6 else ("#e8a33d" if hp_ratio > 0.3 else "#d8534f")
		var fear := int(m["fear"])
		var fear_text := "　[color=#b48ad8]恐惧 %d[/color]" % fear if fear > 0 else ""
		plines.append("%s　[color=%s]%d/%d[/color]%s%s" % [String(m["name"]), hp_color, int(m["hp"]), int(m["hp_max"]), fear_text, "　[color=#d8534f]感染[/color]" if bool(m["infected"]) else ""])
	party_label.text = "\n".join(plines)
	if is_inside_tree():
		_fit_panels.call_deferred()


func _fit_panels() -> void:
	hud.reset_size()
	party.reset_size()
	party.position.x = 1904 - party.size.x


# ---------------------------------------------------------------- 输入与走动

## 有对话、窗口、等待中的事，或者上面盖着别的面板（对话框、暂停、插图）时不能走。
func busy() -> bool:
	if box.visible or choice_panel.visible or check_panel.visible or log_panel.visible:
		return true
	if roster_panel.visible or card_panel.visible:
		return true
	if not view.pending().is_empty() or view.ended():
		return true
	var host := get_parent().get_parent() if get_parent() != null else null
	if host != null:
		if host.get("pause") != null or host.get("panel") != null or host.get_node_or_null("Cutscene") != null:
			return true
	return false


func _process(delta: float) -> void:
	_time += delta
	_animate(delta)
	camera.position = _camera_target()
	if moving or busy():
		prompt.visible = false
		return
	if not path_queue.is_empty():
		var next: Vector2i = path_queue.pop_front()
		var d := _dir_between(cell, next)
		if next - cell != TiledMap.DIRS[d]:
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
	_bump_id = ""
	_idle += delta
	if not spread and _idle >= SPREAD_DELAY and not followers.is_empty():
		spread_out()
	_update_prompt()


## 每帧的小动画：打字、灯闪、手电筒跟着人、对话框的继续箭头。
func _animate(delta: float) -> void:
	if box.visible and box_text.visible_characters >= 0:
		_reveal += delta * REVEAL_CPS
		box_text.visible_characters = int(_reveal)
		if box_text.visible_characters >= box_text.text.length():
			box_text.visible_characters = -1
	box_more.modulate.a = 0.0 if box_text.visible_characters >= 0 else 0.55 + 0.45 * sin(_time * 5.0)
	for f: Dictionary in flickers:
		var node: PointLight2D = f["node"]
		if not is_instance_valid(node):
			continue
		var ph: float = f["phase"]
		var e: float = float(f["base"]) * (0.88 + 0.12 * sin(_time * 11.0 + ph) * sin(_time * 4.3 + ph * 2.0))
		if fmod(_time + ph, 5.0) < 0.14:
			e *= 0.3
		node.energy = e
	if dark.visible:
		_follow_flashlight()
	_update_names()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		if box.visible and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.keycode == KEY_SPACE or k.keycode == KEY_Z):
			_advance()
			accept_event()
			return
		if choice_panel.visible:
			var idx := int(k.keycode) - int(KEY_1)
			var p: Dictionary = view.pending()
			if idx >= 0 and idx < 9 and String(p.get("kind", "")) == "choice" and idx < (p["options"] as Array).size():
				press_choice(String(p["options"][idx]["id"]))
				accept_event()
			return
		if (roster_panel.visible or card_panel.visible) and (k.keycode == KEY_ESCAPE or k.keycode == KEY_T):
			close_panels()
			accept_event()
			return
		if k.keycode == KEY_L:
			_toggle_log()
			accept_event()
			return
		if k.keycode == KEY_T and not busy():
			open_roster()
			accept_event()
			return
		if k.keycode == KEY_V and not box.visible:
			set_wide(not wide)
			view_changed.emit(wide)
			_toast(tr("视野：远（一屏 40×21 格）") if wide else tr("视野：近（一屏 30×16 格）"))
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
		_advance()
	elif not busy():
		click_cell(cell_at(mb.position))
	accept_event()


func _on_box_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()


## 面前一格能做什么：调查柜子、跟谁说话、去哪个地点；什么都没有返回空字符串。
func prompt_text() -> String:
	var t: Vector2i = cell + TiledMap.DIRS[facing]
	if fmap.is_search(t):
		return tr("Enter 调查（搜过了）") if view.ex.st.searched.has(loc) else tr("Enter 调查")
	for id: String in npc_cells:
		if npc_cells[id] == t and _can_talk(id):
			if not Topics.can_hear(view.ex.st, id):
				return tr("Enter 看看：%s") % String(view.names.get(id, id))
			return tr("Enter 说话：%s") % String(view.names.get(id, id))
	for i in follower_ids.size():
		if follower_cell(i) == t and _can_talk(follower_ids[i]):
			return tr("Enter 说话：%s") % String(view.names.get(follower_ids[i], follower_ids[i]))
	if fmap.is_door(t):
		var dest: String = fmap.door_dest(t)
		return tr("前往：%s") % String(view.names.get(dest, dest))
	return ""


func _can_talk(id: String) -> bool:
	for t: Dictionary in view.talk_targets():
		if String(t["id"]) == id:
			return true
	return false


## 面前有能互动的东西时，在它头顶上提示一下。
func _update_prompt() -> void:
	var text := prompt_text() if fmap != null else ""
	if text == "" or moving or busy():
		prompt.visible = false
		return
	prompt_label.text = text
	prompt.reset_size()
	var t: Vector2i = cell + TiledMap.DIRS[facing]
	var at := (Vector2(t.x * TILE + TILE / 2.0, t.y * TILE - 14) - view_origin()) * scale_factor
	prompt.position = Vector2(clampf(at.x - prompt.size.x / 2.0, 8.0, 1912.0 - prompt.size.x), clampf(at.y - prompt.size.y, 8.0, 960.0))
	prompt.visible = true


## 别人占着的格子（剧情人物）。队友不挡路。
func _blocked() -> Dictionary:
	var out := {}
	for id: String in npc_cells:
		out[npc_cells[id]] = true
	return out


## 朝 d 走一格：撞墙就只转身；走进门就去隔壁。
func step(d: String) -> void:
	facing = d
	var target: Vector2i = cell + TiledMap.DIRS[d]
	if fmap.is_door(target):
		_go_door(fmap.door_dest(target))
		return
	if not fmap.walkable(target):
		_draw_actors()
		return
	var blocker := _npc_at(target)
	if blocker != "":
		if fmap.is_fixed_npc(blocker) or not _give_way(blocker):
			_draw_actors()
			return
	_bump_id = ""
	_idle = 0.0
	if spread:
		_gather()
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
	prompt.visible = false
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


## 第 i 个队友现在站的格子：散开时是散开的位置，否则是主角走过的足迹。
func follower_cell(i: int) -> Vector2i:
	if spread and i < spread_cells.size():
		return spread_cells[i]
	return trail[mini(i + 1, trail.size() - 1)]


func _npc_at(c: Vector2i) -> String:
	for id: String in npc_cells:
		if npc_cells[id] == c:
			return id
	return ""


## 顶着一个剧情人物：先只是转身对着他（这样能说话）；一直顶着超过 GIVE_WAY_DELAY 秒，他和你换个位置让路。
## 返回 true 表示这一步可以走过去（他已经挪到你原来的格子）。
func _give_way(npc_id: String) -> bool:
	if _bump_id != npc_id:
		_bump_id = npc_id
		_bump_since = _time
		return false
	if _time - _bump_since < GIVE_WAY_DELAY:
		return false
	npc_cells[npc_id] = cell
	npc_override[npc_id] = cell
	_bump_id = ""
	if npc_sprites.has(npc_id):
		var s: Sprite2D = npc_sprites[npc_id]
		if is_inside_tree():
			create_tween().tween_property(s, "position", _pixel(cell), STEP_TIME)
		else:
			s.position = _pixel(cell)
	return true


## 散开：每个队友挑附近一个空格站过去（离主角 2～4 步，避开门、剧情人物和别的队友），面朝主角。
func spread_out() -> void:
	if followers.is_empty():
		return
	var taken := {cell: true}
	for id: String in npc_cells:
		taken[npc_cells[id]] = true
	var dist := {cell: 0}
	var queue: Array[Vector2i] = [cell]
	var cands: Array[Vector2i] = []
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if int(dist[c]) >= 4:
			continue
		for d: Vector2i in TiledMap.DIRS.values():
			var n: Vector2i = c + d
			if dist.has(n) or not fmap.walkable(n) or fmap.is_door(n) or taken.has(n):
				continue
			dist[n] = int(dist[c]) + 1
			queue.append(n)
			if int(dist[n]) >= 2:
				cands.append(n)
	var picked: Array[Vector2i] = []
	for i in followers.size():
		var from: Vector2i = follower_cell(i)
		var best := Vector2i(-9999, -9999)
		var best_score := INF
		for c in cands:
			if picked.has(c):
				continue
			var near_mate := 0
			for p in picked:
				if absi(p.x - c.x) + absi(p.y - c.y) <= 1:
					near_mate += 1
			var s := float(absi(c.x - from.x) + absi(c.y - from.y)) + near_mate * 3.0 + c.y * 0.001 + c.x * 0.00001
			if s < best_score:
				best_score = s
				best = c
		picked.append(best if best.x > -9999 else from)
	var old: Array[Vector2i] = []
	for i in followers.size():
		old.append(follower_cell(i))
	spread_cells = picked
	spread = true
	_remember()
	for i in followers.size():
		var path: Array[Vector2i] = []
		if old[i] != picked[i]:
			path = fmap.path(old[i], picked[i], {})
		if not is_inside_tree() or path.is_empty():
			followers[i].position = _pixel(picked[i])
			followers[i].visible = picked[i] != cell
			followers[i].texture = FieldArt.walker(follower_ids[i], _dir_between(picked[i], cell), 0)
			continue
		var tw := create_tween()
		var prev: Vector2i = old[i]
		var frame := 1
		for c in path:
			var s: Sprite2D = followers[i]
			var dir := _dir_between(prev, c)
			var key: String = follower_ids[i]
			var f := frame
			tw.tween_callback(func() -> void:
				s.visible = true
				s.texture = FieldArt.walker(key, dir, f))
			tw.tween_property(s, "position", _pixel(c), STEP_TIME * 1.3)
			prev = c
			frame = 3 - frame
		var sp: Sprite2D = followers[i]
		var k2: String = follower_ids[i]
		var end: Vector2i = picked[i]
		tw.tween_callback(func() -> void:
			sp.texture = FieldArt.walker(k2, _dir_between(end, cell), 0))


## 归队：散开的队友按离主角远近排好，重新排成一路跟在后面。
func _gather() -> void:
	var idx: Array[int] = []
	for i in followers.size():
		idx.append(i)
	idx.sort_custom(func(a: int, b: int) -> bool:
		var ca: Vector2i = spread_cells[a]
		var cb: Vector2i = spread_cells[b]
		return absi(ca.x - cell.x) + absi(ca.y - cell.y) < absi(cb.x - cell.x) + absi(cb.y - cell.y))
	var f2: Array[Sprite2D] = []
	var id2: Array[String] = []
	var tr2: Array[Vector2i] = [cell]
	for i in idx:
		f2.append(followers[i])
		id2.append(follower_ids[i])
		tr2.append(spread_cells[i])
	followers = f2
	follower_ids = id2
	trail = tr2
	spread = false
	spread_cells.clear()


## 对着前面一格按确认：柜子 → 搜索；剧情人物或队友 → 说话；门 → 过去。
func interact() -> void:
	var target: Vector2i = cell + TiledMap.DIRS[facing]
	if fmap.is_search(target):
		press_search()
		return
	for id: String in npc_cells:
		if npc_cells[id] == target:
			press_talk(id)
			return
	for i in follower_ids.size():
		if follower_cell(i) == target:
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
		for d: Vector2i in TiledMap.DIRS.values():
			if fmap.walkable(c + d) and not fmap.is_door(c + d):
				goal = c + d
	elif fmap.is_search(c) or blocked.has(c):
		then = {"interact": true, "face": c}
		goal = Vector2i(-1, -1)
		var best := 99999
		for d: Vector2i in TiledMap.DIRS.values():
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


# ---------------------------------------------------------------- 人：名字、在场的人、人物卡

## 对话信任（0～5）：main 传进来的对话记忆里读。
func trust_of(id: String) -> int:
	return int((dialogue_store.get(id, {}) as Dictionary).get("trust", 0))


func _refresh_new_topics() -> void:
	_new_topics.clear()
	if view == null:
		return
	for id in present_people():
		if id != player_id and _can_talk(id) and Topics.has_new(view.ex.st, id, trust_of(id)):
			_new_topics[id] = true


## 这个地点上的人：主角、队友、活着的剧情人物（按这个顺序）。
func present_people() -> Array[String]:
	var out: Array[String] = []
	if player_id != "":
		out.append(player_id)
	for id in follower_ids:
		out.append(id)
	for id: String in npc_sprites:
		out.append(id)
	return out


## 有没有还没聊过的话题（头上的"…"、名单上的"有新话题"）。
func has_new_topic(id: String) -> bool:
	return _new_topics.has(id)


func _sprite_of(id: String) -> Sprite2D:
	if id == player_id:
		return player
	var i := follower_ids.find(id)
	if i >= 0:
		return followers[i]
	return npc_sprites.get(id, null)


## 走近的人头顶显示名字；有新话题的后面带"…"。对话框、窗口开着时不显示。
func _update_names() -> void:
	var showing := not busy() and fmap != null
	var near := {}
	if showing:
		for id in present_people():
			if id == player_id:
				continue
			var s := _sprite_of(id)
			if s == null or not s.visible:
				continue
			var c := Vector2i(floori(s.position.x / TILE), floori((s.position.y - 1) / TILE))
			if absi(c.x - cell.x) + absi(c.y - cell.y) <= NAME_RANGE:
				near[id] = s
	for id: String in name_labels.keys():
		if not near.has(id):
			(name_labels[id] as Control).visible = false
	# 近的人先摆；和已经摆好的名字叠在一起就往上挪一行，还叠就不显示（面前那个人的名字提示框里有）。
	var order: Array[String] = []
	for id: String in near:
		order.append(id)
	var me: Vector2 = player.position if player != null else Vector2.ZERO
	order.sort_custom(func(a: String, b: String) -> bool:
		return (near[a] as Sprite2D).position.distance_squared_to(me) < (near[b] as Sprite2D).position.distance_squared_to(me))
	var placed: Array[Rect2] = []
	for id in order:
		var l: Label = name_labels.get(id, null)
		if l == null:
			l = UiTheme.label(tr(""), 16, UiTheme.TEXT)
			l.autowrap_mode = TextServer.AUTOWRAP_OFF
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			l.add_theme_constant_override("outline_size", 6)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			name_layer.add_child(l)
			name_labels[id] = l
		l.text = String(view.names.get(id, id)) + (" …" if has_new_topic(id) else "")
		l.add_theme_color_override("font_color", UiTheme.ACCENT2 if has_new_topic(id) else UiTheme.TEXT)
		l.reset_size()
		var s: Sprite2D = near[id]
		var head := s.position + Vector2(0, -FieldArt.walker_size(String(s.get_meta("key", id))).y - 3)
		var at := (head - view_origin()) * scale_factor
		var rect := Rect2(Vector2(at.x - l.size.x / 2.0, at.y - l.size.y), l.size).grow(2.0)
		if _overlaps(rect, placed):
			rect.position.y -= l.size.y
		if _overlaps(rect, placed):
			l.visible = false
			continue
		placed.append(rect)
		l.position = rect.position + Vector2(2, 2)
		l.visible = true


func _overlaps(rect: Rect2, others: Array[Rect2]) -> bool:
	for o in others:
		if rect.intersects(o):
			return true
	return false


## 关掉"在场的人"和人物卡。
func close_panels() -> void:
	roster_panel.visible = false
	card_panel.visible = false


## T：在场的人。每人一行：名字、身份、状态，"说话"和"人物卡"两个按钮；有新话题的标出来。
func open_roster() -> void:
	card_panel.visible = false
	_clear(roster_box)
	var head := UiTheme.label(tr("在场的人（T / Esc 关闭）"), 24, UiTheme.ACCENT2)
	head.autowrap_mode = TextServer.AUTOWRAP_OFF
	roster_box.add_child(head)
	for id in present_people():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var who := String(view.names.get(id, id))
		var tag := tr("（你）") if id == player_id else (tr("剧情人物") if view.ex.st.npcs.has(id) else tr("轮回者"))
		var extra := ""
		if id != player_id and not Topics.can_hear(view.ex.st, id):
			extra = tr(" · 听不见你们说话")
		elif has_new_topic(id):
			extra = tr(" · 有新话题")
		var l := UiTheme.label(tr("%s　%s%s") % [who, tag, extra], 18, UiTheme.ACCENT2 if has_new_topic(id) else UiTheme.TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size = Vector2(560, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(l)
		if id != player_id:
			var talk := UiTheme.button(tr("看看") if not Topics.can_hear(view.ex.st, id) else tr("说话"), 17)
			talk.focus_mode = Control.FOCUS_NONE
			talk.custom_minimum_size = Vector2(0, 36)
			talk.pressed.connect(func() -> void:
				close_panels()
				press_talk(id))
			row.add_child(talk)
		var card := UiTheme.button(tr("人物卡"), 17)
		card.focus_mode = Control.FOCUS_NONE
		card.custom_minimum_size = Vector2(0, 36)
		card.pressed.connect(open_card.bind(id))
		row.add_child(card)
		roster_box.add_child(row)
	# 人多了（主神空间以后会更多）就在名单里滚动，面板不超出屏幕。
	roster_scroll.custom_minimum_size = Vector2(880, minf(roster_box.get_combined_minimum_size().y, 800.0))
	roster_scroll.scroll_vertical = 0
	roster_panel.reset_size()
	roster_panel.visible = true


## 人物卡上的内容（测试也用）：{title, lines: [一行一项], notes: [聊出来的要点], unseen: 没聊过的话题数}。
func card_info(id: String) -> Dictionary:
	var st: RefCounted = view.ex.st
	var lines: Array[String] = []
	var is_npc: bool = st.npcs.has(id)
	if id == player_id:
		lines.append(tr("身份：轮回者（你自己）"))
	elif is_npc:
		lines.append(tr("身份：剧情人物"))
	else:
		lines.append(tr("身份：轮回者"))
	if st.characters.has(id):
		var ch: RefCounted = st.characters[id]
		var status := tr("血 %d/%d · 恐惧 %d") % [int(ch.hp), int(ch.hp_max()), int(ch.fear)]
		if st.infected.has(id):
			status += tr(" · 已感染")
		lines.append(status)
	elif is_npc:
		lines.append(tr("状态：活着") if bool(st.npcs[id]["alive"]) else tr("状态：已死亡"))
	if id != player_id:
		if is_npc:
			lines.append(tr("对你的信任：%d / 5") % trust_of(id))
			if not Topics.can_hear(st, id):
				lines.append(tr("现在听不见你们说话（列车减速之前）"))
		else:
			var game: RefCounted = view.ex.game
			var leader: String = game.leader
			lines.append(tr("对你的信任 %d · 服从 %d") % [int(game.relations.value(id, leader, "trust")), int(Cohesion.obedience(game.relations, id, leader))])
	var notes: Array[String] = Topics.notes(st, id)
	if id == player_id:
		notes = [_persona_background(id)]
	return {"title": String(view.names.get(id, id)), "lines": lines, "notes": notes, "unseen": Topics.unseen_count(st, id) if id != player_id else 0}


func _persona_background(id: String) -> String:
	var res := DataLoader.load_json("res://data/ai/personas.json")
	if not res.ok:
		return ""
	return String((((res.data as Dictionary).get("personas", {}) as Dictionary).get(id, {}) as Dictionary).get("background", ""))


func open_card(id: String) -> void:
	roster_panel.visible = false
	card_id = id
	var info := card_info(id)
	card_title.text = String(info["title"])
	var parts: Array[String] = []
	for line: String in info["lines"]:
		parts.append(line)
	parts.append("")
	parts.append("[color=#e8a33d]了解到的[/color]")
	var notes: Array = info["notes"]
	if notes.is_empty():
		parts.append("[color=#aab2c0]还不了解。找%s聊聊。[/color]" % String(info["title"]))
	for n in notes:
		parts.append("· " + String(n))
	if int(info["unseen"]) > 0:
		parts.append("")
		parts.append("[color=#aab2c0]还有 %d 个话题没聊过（有的要更熟才会说）。[/color]" % int(info["unseen"]))
	card_body.text = "\n".join(parts)
	card_face.texture = PortraitSource.portrait(id)
	card_panel.visible = true


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
	_hide_box()


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
	if not _can_talk(npc_id):
		return false
	talk_requested.emit(npc_id)
	return true


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
