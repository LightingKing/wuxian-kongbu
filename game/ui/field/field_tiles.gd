extends RefCounted
## 把 TiledMap 的图块集变成 Godot 的 TileSet，并把图层填进 TileMapLayer（计划 22）。
## 每个 Tiled 图块集一个 TileSetAtlasSource，来源编号 = 图块集序号。
## 图块集的图片在就用图片（res://art/tiles/...，不进仓库）；不在就按每块图块的 kind 属性画灰盒占位
## （配色跟地图的 theme，见 field_art.gd 的 tile_image），所以自动测试和正式图到之前都能跑。
## 标了 greybox 属性的图块集（data/maps/tilesets/greybox.tsj）总是运行时画：它的图片只是给 Tiled 看的，各地点要按自己的主题配色。
## 翻转：Tiled 的水平、垂直、对角翻转 → Godot 备选图块编号里的 TRANSFORM_FLIP_H、FLIP_V、TRANSPOSE 位。

const FieldArt = preload("res://ui/field/field_art.gd")

## 图块的 kind → 灰盒用的字符；没写 kind 的按挡不挡路画成墙或地面。
const KIND_CHAR := {
	"floor": ".", "carpet": "=", "water": "~", "wall": "#", "wall_face": "#",
	"prop": "o", "laser": "x", "search": "S", "door": "D",
}

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


## 这张地图用的 TileSet（按地图文件和主题缓存）。
static func tileset(map: RefCounted) -> TileSet:
	var key := "%s:%s" % [map.file_path, map.theme()]
	if _cache.has(key):
		return _cache[key]
	var ts := TileSet.new()
	ts.tile_size = Vector2i(map.tile, map.tile)
	for i in map.tilesets.size():
		var info: Dictionary = map.tilesets[i]
		var src := TileSetAtlasSource.new()
		var use_image := String(info["image"]) != "" and not bool((info["props"] as Dictionary).get("greybox", false))
		var tex := FieldArt.load_texture(String(info["image"])) if use_image else null
		if tex == null:
			tex = greybox_texture(info, map.theme(), map.tile)
		else:
			src.margins = Vector2i(int(info["margin"]), int(info["margin"]))
			src.separation = Vector2i(int(info["spacing"]), int(info["spacing"]))
		src.texture = tex
		src.texture_region_size = Vector2i(map.tile, map.tile)
		var cols := int(info["columns"])
		for id in int(info["tilecount"]):
			src.create_tile(Vector2i(id % cols, id / cols))
		ts.add_source(src, i)
	_cache[key] = ts
	return ts


## 图块集图片不在时的灰盒图：和原图同样的行列，每块按 kind 画。
static func greybox_texture(info: Dictionary, theme: String, tile: int) -> Texture2D:
	return ImageTexture.create_from_image(greybox_image(info, theme, tile))


static func greybox_image(info: Dictionary, theme: String, tile: int) -> Image:
	var cols := int(info["columns"])
	var count := int(info["tilecount"])
	var rows := maxi(1, ceili(float(count) / cols))
	var img := Image.create(cols * tile, rows * tile, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var tiles: Dictionary = info["tiles"]
	for id in count:
		var p: Dictionary = tiles.get(id, {})
		var kind := String(p.get("kind", "wall" if bool(p.get("blocks", false)) else "floor"))
		var ch := String(KIND_CHAR.get(kind, "."))
		var src := FieldArt.tile_image(theme, ch, kind == "wall_face")
		if src.get_width() != tile or src.get_height() != tile:
			src = src.duplicate() as Image
			src.resize(tile, tile, Image.INTERPOLATE_NEAREST)
		img.blit_rect(src, Rect2i(0, 0, tile, tile), Vector2i((id % cols) * tile, (id / cols) * tile))
	return img


## Tiled 的翻转位 → Godot 备选图块编号。
static func alt_for(r: Dictionary) -> int:
	var a := 0
	if bool(r.get("flip_h", false)):
		a |= TileSetAtlasSource.TRANSFORM_FLIP_H
	if bool(r.get("flip_v", false)):
		a |= TileSetAtlasSource.TRANSFORM_FLIP_V
	if bool(r.get("flip_d", false)):
		a |= TileSetAtlasSource.TRANSFORM_TRANSPOSE
	return a


## 把地图的一层填进 TileMapLayer（先清空）。没有这层就留空。
static func fill(layer: TileMapLayer, map: RefCounted, name: String) -> void:
	layer.tile_set = tileset(map)
	layer.clear()
	if not map.layers.has(name):
		return
	for y in map.size.y:
		for x in map.size.x:
			var c := Vector2i(x, y)
			var r: Dictionary = map.resolve(map.tile_at(name, c))
			if r.is_empty():
				continue
			var cols := int(map.tilesets[int(r["set"])]["columns"])
			var id := int(r["id"])
			layer.set_cell(c, int(r["set"]), Vector2i(id % cols, id / cols), alt_for(r))
