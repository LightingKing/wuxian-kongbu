extends RefCounted
## 界面配色与字体：中文字体用系统字体（Windows 的微软雅黑 / 安卓的 Noto Sans CJK），不往仓库塞字体文件。
## 界面统一从这里取颜色，别在各处写死。

const BG := Color("12141a")
const PANEL := Color("1b1f28")
const PANEL_LIGHT := Color("232936")
const LINE := Color("39414f")
const TEXT := Color("e6e9ef")
const MUTED := Color("9aa4b2")
const ACCENT := Color("d8534f")
const ACCENT2 := Color("e0a458")
const OK := Color("6fbf73")
const DARK := Color("0b0d12")


static func build() -> Theme:
	var t := Theme.new()
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Noto Sans SC", "Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "SimHei", "sans-serif"])
	if f.font_names.size() > 0:
		t.default_font = f
	t.default_font_size = 22
	t.set_stylebox("normal", "Button", panel_style(PANEL_LIGHT, LINE, 6))
	t.set_stylebox("hover", "Button", panel_style(PANEL, ACCENT2, 6))
	t.set_stylebox("pressed", "Button", panel_style(ACCENT, ACCENT, 6))
	t.set_stylebox("disabled", "Button", panel_style(PANEL, DARK, 6))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", MUTED)
	return t


static func panel_style(bg: Color = PANEL, border: Color = LINE, radius: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


static func button(text: String, size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, 52)
	b.focus_mode = Control.FOCUS_NONE
	return b


## 地点图上的地点按钮：有边框、有底色，选中/不可走时颜色不同。
static func map_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_stylebox_override("normal", panel_style(PANEL_LIGHT, LINE, 6))
	b.add_theme_stylebox_override("hover", panel_style(PANEL, ACCENT2, 6))
	b.add_theme_stylebox_override("pressed", panel_style(ACCENT, ACCENT, 6))
	b.add_theme_stylebox_override("disabled", panel_style(PANEL, DARK, 6))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.focus_mode = Control.FOCUS_NONE
	return b


## 血量/恐惧这类细条：背景深、填充色可换。
static func bar(color: Color, height: int = 8) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, height)
	pb.add_theme_stylebox_override("background", panel_style(DARK, DARK, 3))
	pb.add_theme_stylebox_override("fill", bar_fill(color))
	return pb


static func bar_fill(color: Color) -> StyleBoxFlat:
	var f := StyleBoxFlat.new()
	f.bg_color = color
	f.set_corner_radius_all(3)
	return f


static func label(text: String, size: int = 22, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func rich(size: int = 20) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = false
	r.scroll_following = true
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_color_override("default_color", TEXT)
	return r


static func paint_bg(node: Control) -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(bg)
