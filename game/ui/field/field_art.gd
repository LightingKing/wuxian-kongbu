extends RefCounted
## 探索地图的占位像素图（在 Codex 画出正式图块和行走图之前）：
##   图块 16×16，按地点主题配色（颜色都取自共用调色板 art/pixel_test/palette.hex）；
##   行走小人 16×24，四个朝向，每个朝向站立 + 两帧迈步；配色取 pixel_art.gd 的 PEOPLE；
##   黑暗地点的手电筒遮罩：中间透亮、往外渐黑。
## 正式图到位后（res://art/field/...），只要把这里的函数换成读图，场景代码不用改。

const PixelArt = preload("res://ui/art/pixel_art.gd")

const TILE := 16
const WALK_W := 16
const WALK_H := 24
const OUTLINE := Color("0b0f1a")

## 主题 → [地面, 地面花纹, 墙, 墙顶线, 家具, 家具亮面]
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

static var _tiles: Dictionary = {}
static var _walkers: Dictionary = {}
static var _flash: Texture2D = null


static func _c(theme: String, i: int) -> Color:
	var t: Array = THEMES.get(theme, THEMES["hall"])
	return Color(String(t[i]))


## 一种地面/墙/门/家具的图块。ch 是地图里的字符。
static func tile(theme: String, ch: String) -> Texture2D:
	var key := theme + ":" + ch
	if _tiles.has(key):
		return _tiles[key]
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var floor := _c(theme, 0)
	match ch:
		"#":
			img.fill(_c(theme, 2))
			img.fill_rect(Rect2i(0, 0, TILE, 2), _c(theme, 3))
			img.fill_rect(Rect2i(0, TILE - 1, TILE, 1), OUTLINE)
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


## 行走小人。dir：down / up / left / right；frame：0 站立，1、2 迈步。
static func walker(key: String, dir: String, frame: int) -> Texture2D:
	var ck := "%s:%s:%d" % [key, dir, frame]
	if _walkers.has(ck):
		return _walkers[ck]
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
	var tex := ImageTexture.create_from_image(img)
	_walkers[ck] = tex
	return tex


## 黑暗地点的手电筒遮罩：480×270（场景里放大 2 倍盖住全屏），中间半径 22 像素透亮，到 60 像素几乎全黑。贴图中心对准主角。
static func flashlight() -> Texture2D:
	if _flash != null:
		return _flash
	var w := 480
	var h := 270
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var center := Vector2(w / 2.0, h / 2.0)
	for y in h:
		for x in w:
			var d := Vector2(x, y).distance_to(center)
			var a := clampf((d - 22.0) / 38.0, 0.0, 1.0) * 0.93
			img.set_pixel(x, y, Color(0.02, 0.03, 0.06, a))
	_flash = ImageTexture.create_from_image(img)
	return _flash
