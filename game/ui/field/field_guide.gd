extends RefCounted
## 给画地图的人（Codex，任务卡 007）用的两种图：
##   版式图 guide()：480×256，每格按图例涂一种颜色（墙顶、墙面、地面、地毯/过道、浅水、家具设备、可搜索的柜子、门），
##     照着它画整张俯视地图，家具和墙的位置就和碰撞格子对得上；
##   对位图 overlay()：把画好的地图放大 4 倍，挡路的格子盖红、门盖绿、柜子盖黄，再画上格线，
##     一眼就看得出画面和碰撞是不是一致（红色应该正好盖住墙和家具，地面上不该有红）。
## 行走图检查 check_sheet()：尺寸能被 4 整除、单帧是规格大小、有透明。

const TILE := 16
const ZOOM := 4
const WALKER_FRAME := Vector2i(32, 32)
const COLORS := {
	"top": Color("15171c"), "face": Color("5b6170"), ".": Color("cfc8b8"), "=": Color("b39a72"),
	"~": Color("4f86b8"), "o": Color("8a5a2a"), "x": Color("c03030"), "S": Color("e8c040"), "D": Color("3fae5a"),
}
const TINT_BLOCK := Color(0.9, 0.1, 0.1, 0.34)
const TINT_DOOR := Color(0.1, 0.85, 0.3, 0.42)
const TINT_SEARCH := Color(1.0, 0.85, 0.1, 0.45)
const GRID := Color(1, 1, 1, 0.22)


## 版式图：一格一色。
static func guide(fmap: RefCounted) -> Image:
	var img := Image.create(fmap.size.x * TILE, fmap.size.y * TILE, false, Image.FORMAT_RGBA8)
	for y in fmap.size.y:
		for x in fmap.size.x:
			var c := Vector2i(x, y)
			var ch: String = fmap.char_at(c)
			var key := ch
			if ch == "#":
				key = "face" if fmap.wall_face(c) else "top"
			img.fill_rect(Rect2i(x * TILE, y * TILE, TILE, TILE), COLORS.get(key, COLORS["."]))
	return img


## 对位图：画好的地图放大 4 倍，盖上碰撞颜色和格线。尺寸不对的图先缩放到地图大小。
static func overlay(fmap: RefCounted, painted: Image) -> Image:
	var w: int = fmap.size.x * TILE
	var h: int = fmap.size.y * TILE
	var img := painted.duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	if img.get_size() != Vector2i(w, h):
		img.resize(w, h, Image.INTERPOLATE_NEAREST)
	img.resize(w * ZOOM, h * ZOOM, Image.INTERPOLATE_NEAREST)
	var layer := Image.create(w * ZOOM, h * ZOOM, false, Image.FORMAT_RGBA8)
	layer.fill(Color(0, 0, 0, 0))
	var cell := TILE * ZOOM
	for y in fmap.size.y:
		for x in fmap.size.x:
			var c := Vector2i(x, y)
			var tint := Color(0, 0, 0, 0)
			if fmap.is_door(c):
				tint = TINT_DOOR
			elif fmap.is_search(c):
				tint = TINT_SEARCH
			elif not fmap.walkable(c):
				tint = TINT_BLOCK
			if tint.a > 0.0:
				layer.fill_rect(Rect2i(x * cell, y * cell, cell, cell), tint)
	for x in range(0, w * ZOOM, cell):
		layer.fill_rect(Rect2i(x, 0, 1, h * ZOOM), GRID)
	for y in range(0, h * ZOOM, cell):
		layer.fill_rect(Rect2i(0, y, w * ZOOM, 1), GRID)
	img.blend_rect(layer, Rect2i(0, 0, w * ZOOM, h * ZOOM), Vector2i.ZERO)
	return img


## 行走图的问题（空数组 = 没问题）：4 列 × 4 行、单帧 32×32、有透明像素。
static func check_sheet(img: Image) -> Array[String]:
	var out: Array[String] = []
	var size := img.get_size()
	if size.x % 4 != 0 or size.y % 4 != 0:
		out.append("尺寸 %s 不能被 4 整除" % size)
		return out
	var frame := Vector2i(size.x / 4, size.y / 4)
	if frame != WALKER_FRAME:
		out.append("单帧 %s，规格是 %s" % [frame, WALKER_FRAME])
	if not img.detect_alpha():
		out.append("没有透明像素")
	return out
