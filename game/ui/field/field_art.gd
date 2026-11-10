extends RefCounted
## 探索画面的图从哪来（设计规格 11；任务卡 007）：
##   地图：res://art/field/maps/<地点>.png，480×256 不透明的整张俯视像素图（RPG Maker 的"远景图"画法：
##        整张画好，碰撞仍按 data/maps 里的字符格子）。没有就用代码画的占位图块拼。
##   行走图：res://art/field/walkers/<id>.png，4 列 × 4 行；行是朝向（下、左、右、上），
##        列是走路的四帧（站立、迈一只脚、站立、迈另一只脚）；单帧 = 整张的宽、高各除以 4（规格 32×32，脚踩最下面一行）。
##        没有就用代码画的 16×24 占位小人（配色取 pixel_art.gd 的 PEOPLE）。
##   光：灯和手电筒用的贴图（径向渐变、锥形）、人物脚下的影子。
## 正式图不进仓库；刚放进来、还没被 Godot 导入的图直接读文件（同 portrait_source.gd）。

const PixelArt = preload("res://ui/art/pixel_art.gd")

const TILE := 16
const WALK_W := 16
const WALK_H := 24
const OUTLINE := Color("0b0f1a")
## 行走图里朝向对应的行；"第几帧"对应的列：0 站立，1、2 两只脚各迈一步（第 2 列是另一张站立帧，走路时不用）。
const SHEET_ROWS := {"down": 0, "left": 1, "right": 2, "up": 3}
const SHEET_COLS: Array[int] = [0, 1, 3]
const LIGHT_SIZE := 128

## 主题 → [地面, 地面花纹, 墙, 墙顶线, 家具, 家具亮面]（颜色都取自共用调色板 art/pixel_test/palette.hex）
const THEMES := {
	"train": ["30384a", "3f5b73", "20283b", "465064", "263c54", "60859a"],
	"hall": ["626d7b", "89939b", "30384a", "465064", "465064", "afb8bb"],
	"stairs": ["465064", "30384a", "141b2b", "20283b", "626d7b", "89939b"],
	"laser": ["afb8bb", "d3d9d6", "89939b", "d3d9d6", "943c4b", "c15a60"],
	"control": ["263c54", "3f5b73", "141b2b", "20283b", "3f5b73", "60859a"],
	"corridor": ["556869", "7d8d88", "37494b", "556869", "7d8d88", "abb8a6"],
	"freezer": ["8fb1bc", "afb8bb", "60859a", "8fb1bc", "d0d5bc", "ecebdd"],
	"sewer": ["37494b", "263c54", "20283b", "30384a", "465064", "626d7b"],
}

## 正式图放在哪；测试会把它指到 user:// 下的临时目录。
static var art_root := "res://art/field/"
static var _tiles: Dictionary = {}
static var _walkers: Dictionary = {}
static var _files: Dictionary = {}
static var _light: Texture2D = null
static var _cone: Texture2D = null
static var _shadow: Texture2D = null


## 换了图想立刻看到（或测试换了 art_root），清一下缓存。
static func clear_cache() -> void:
	_walkers.clear()
	_files.clear()


static func _load(path: String) -> Texture2D:
	if _files.has(path):
		return _files[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D
	if tex == null and FileAccess.file_exists(path):
		var img := Image.load_from_file(ProjectSettings.globalize_path(path))
		if img != null and not img.is_empty():
			tex = ImageTexture.create_from_image(img)
	_files[path] = tex
	return tex


static func _c(theme: String, i: int) -> Color:
	var t: Array = THEMES.get(theme, THEMES["hall"])
	return Color(String(t[i]))


# ---------------------------------------------------------------- 地图

## 整张画好的地图；没有返回 null（场景就用占位图块拼）。
static func map_image(loc: String) -> Texture2D:
	return _load(art_root + "maps/" + loc + ".png")


## 占位图块。ch 是地图里的字符；face：这块墙下面是屋里，画成看得到高度的墙面（RPG Maker 式的立体感）。
static func tile(theme: String, ch: String, face: bool = false) -> Texture2D:
	var key := "%s:%s:%s" % [theme, ch, face]
	if _tiles.has(key):
		return _tiles[key]
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var floor := _c(theme, 0)
	match ch:
		"#":
			if face:
				var wall := _c(theme, 2).lightened(0.12)
				img.fill(wall)
				img.fill_rect(Rect2i(0, 0, TILE, 2), _c(theme, 3))
				for x in [0, 8]:
					img.fill_rect(Rect2i(x, 2, 1, TILE - 5), wall.darkened(0.25))
				img.fill_rect(Rect2i(0, TILE - 3, TILE, 3), _c(theme, 2).darkened(0.35))
			else:
				img.fill(_c(theme, 2).darkened(0.55))
				img.fill_rect(Rect2i(0, TILE - 1, TILE, 1), _c(theme, 3).darkened(0.3))
		"=":
			img.fill(_c(theme, 1))
			img.set_pixel(4, 6, floor)
			img.set_pixel(12, 13, floor)
		"~":
			img.fill(Color("263c54"))
			img.fill_rect(Rect2i(2, 5, 6, 1), Color("3f5b73"))
			img.fill_rect(Rect2i(9, 11, 5, 1), Color("3f5b73"))
		"o", "x":
			img.fill(floor)
			img.fill_rect(Rect2i(1, 2, TILE - 2, TILE - 3), OUTLINE)
			img.fill_rect(Rect2i(2, 3, TILE - 4, TILE - 6), _c(theme, 4))
			img.fill_rect(Rect2i(3, 4, TILE - 6, 3), _c(theme, 5))
			img.fill_rect(Rect2i(2, TILE - 2, TILE - 4, 1), floor.darkened(0.4))
		"S":
			img.fill(floor)
			img.fill_rect(Rect2i(1, 1, TILE - 2, TILE - 2), OUTLINE)
			img.fill_rect(Rect2i(2, 2, TILE - 4, TILE - 4), Color("b78b57"))
			img.fill_rect(Rect2i(2, 7, TILE - 4, 1), Color("76545b"))
			img.fill_rect(Rect2i(7, 9, 2, 2), Color("f1dea6"))
		"D":
			img.fill(Color("0b0f1a"))
			img.fill_rect(Rect2i(0, 0, TILE, 1), _c(theme, 3))
			img.fill_rect(Rect2i(0, 0, 1, TILE), _c(theme, 3))
			img.fill_rect(Rect2i(TILE - 1, 0, 1, TILE), _c(theme, 3))
		_:
			img.fill(floor)
			img.set_pixel(3, 4, _c(theme, 1))
			img.set_pixel(11, 12, _c(theme, 1))
	var tex := ImageTexture.create_from_image(img)
	_tiles[key] = tex
	return tex


# ---------------------------------------------------------------- 行走小人

static func _sheet(key: String) -> Texture2D:
	return _load(art_root + "walkers/" + key + ".png")


static func has_sheet(key: String) -> bool:
	return _sheet(key) != null


## 行走小人一帧的大小（场景按脚底中点对齐）。
static func walker_size(key: String) -> Vector2i:
	var sheet := _sheet(key)
	if sheet == null:
		return Vector2i(WALK_W, WALK_H)
	return Vector2i(sheet.get_width() / 4, sheet.get_height() / 4)


## 行走小人的一帧。dir：down / up / left / right；frame：0 站立，1、2 迈步。
static func walker(key: String, dir: String, frame: int) -> Texture2D:
	var ck := "%s:%s:%d" % [key, dir, frame]
	if _walkers.has(ck):
		return _walkers[ck]
	var tex: Texture2D
	var sheet := _sheet(key)
	if sheet != null:
		var size := Vector2i(sheet.get_width() / 4, sheet.get_height() / 4)
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(SHEET_COLS[clampi(frame, 0, 2)] * size.x, int(SHEET_ROWS.get(dir, 0)) * size.y, size.x, size.y)
		tex = at
	else:
		tex = _placeholder(key, dir, frame)
	_walkers[ck] = tex
	return tex


static func _placeholder(key: String, dir: String, frame: int) -> Texture2D:
	var colors: Array = PixelArt.PEOPLE.get(key, ["#4a5568", "#e0bb95", "#2b2119"])
	var shirt := Color(String(colors[0]))
	var skin := Color(String(colors[1]))
	var hair := Color(String(colors[2]))
	var pants := shirt.darkened(0.55)
	var img := Image.create(WALK_W, WALK_H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# 头（10×10，带描边）
	img.fill_rect(Rect2i(3, 0, 10, 10), OUTLINE)
	img.fill_rect(Rect2i(4, 1, 8, 8), skin)
	match dir:
		"up":
			img.fill_rect(Rect2i(4, 1, 8, 8), hair)
		"left":
			img.fill_rect(Rect2i(4, 1, 8, 3), hair)
			img.fill_rect(Rect2i(9, 1, 3, 7), hair)
			img.set_pixel(5, 5, OUTLINE)
		"right":
			img.fill_rect(Rect2i(4, 1, 8, 3), hair)
			img.fill_rect(Rect2i(4, 1, 3, 7), hair)
			img.set_pixel(10, 5, OUTLINE)
		_:
			img.fill_rect(Rect2i(4, 1, 8, 3), hair)
			img.set_pixel(6, 5, OUTLINE)
			img.set_pixel(9, 5, OUTLINE)
	# 身体
	img.fill_rect(Rect2i(3, 10, 10, 8), OUTLINE)
	img.fill_rect(Rect2i(4, 10, 8, 7), shirt)
	if dir == "left" or dir == "right":
		var arm_x := 6 if frame == 1 else (9 if frame == 2 else 7)
		img.fill_rect(Rect2i(arm_x, 12, 2, 4), skin)
	else:
		img.fill_rect(Rect2i(2, 11, 2, 5), shirt)
		img.fill_rect(Rect2i(12, 11, 2, 5), shirt)
		img.fill_rect(Rect2i(2, 16, 2, 1), skin)
		img.fill_rect(Rect2i(12, 16, 2, 1), skin)
	# 腿：迈步时一条腿短一截
	var left_len := 5 if frame != 1 else 3
	var right_len := 5 if frame != 2 else 3
	img.fill_rect(Rect2i(4, 18, 3, left_len), pants)
	img.fill_rect(Rect2i(9, 18, 3, right_len), pants)
	img.fill_rect(Rect2i(4, 18 + left_len, 3, 1), OUTLINE)
	img.fill_rect(Rect2i(9, 18 + right_len, 3, 1), OUTLINE)
	return ImageTexture.create_from_image(img)


## 人物脚下的影子：12×5 的半透明椭圆，贴图中心对准脚底。
static func shadow_texture() -> Texture2D:
	if _shadow != null:
		return _shadow
	var img := Image.create(12, 5, false, Image.FORMAT_RGBA8)
	for y in 5:
		for x in 12:
			var d := Vector2((x + 0.5 - 6.0) / 6.0, (y + 0.5 - 2.5) / 2.5).length()
			img.set_pixel(x, y, Color(0, 0, 0, 0.38 if d <= 1.0 else 0.0))
	_shadow = ImageTexture.create_from_image(img)
	return _shadow


# ---------------------------------------------------------------- 光

## 灯光贴图：128×128 的径向渐变，中心最亮、到边上变黑（PointLight2D 和自发光光晕共用）。
static func light_texture() -> Texture2D:
	if _light != null:
		return _light
	var n := LIGHT_SIZE
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var center := Vector2(n / 2.0 - 0.5, n / 2.0 - 0.5)
	for y in n:
		for x in n:
			var t := clampf(1.0 - Vector2(x, y).distance_to(center) / (n / 2.0), 0.0, 1.0)
			var a := t * t * (3.0 - 2.0 * t)
			img.set_pixel(x, y, Color(a, a, a, a))
	_light = ImageTexture.create_from_image(img)
	return _light


## 手电筒的光锥：128×128，从左边正中往右张开约 54 度，越远越暗。灯放在主角身上、贴图往右偏 64 像素，按朝向转。
static func cone_texture() -> Texture2D:
	if _cone != null:
		return _cone
	var n := LIGHT_SIZE
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var v := Vector2(x + 0.5, y + 0.5 - n / 2.0)
			var dist := v.length() / n
			var ang := absf(atan2(v.y, v.x))
			var edge := clampf((0.47 - ang) / 0.14, 0.0, 1.0)
			var fall := pow(clampf(1.0 - dist, 0.0, 1.0), 1.2)
			var a := edge * fall
			img.set_pixel(x, y, Color(a, a, a, a))
	_cone = ImageTexture.create_from_image(img)
	return _cone
