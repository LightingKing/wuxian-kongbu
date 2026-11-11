extends RefCounted
## 一个地点的 Tiled 地图（计划 22；设计 2026-11-10 第 2 节）。
## 文件：data/maps/<剧本>/<地点>.tmj（Tiled 1.11 的 JSON，图块数据用 CSV 数组），图块集是 .tsj（也是 JSON）。
## 这里只管数据：图层、图块属性、物件；能不能走、门、入口、寻路、整套校验。
## 画面在 field_tiles.gd（建 TileSet、填图块层）和 field_screen.gd（摆图层、镜头、人物）。
##
## 认得的东西：
##   图层：tilelayer "floor" / "walls" / "decor" / "over"（over 画在人物上面、不挡路）；objectgroup（物件层，名字随意）。
##   图块属性：blocks（bool，挡路）、kind（string，灰盒占位用：floor carpet water wall wall_face prop laser search door）。
##     写在图块集上的同名属性是这个集里每块图块的默认值（例如"实验室墙壁"整集都挡路），单块图块上写的会盖过它。
##   地图属性：theme（灰盒配色）、ambient（环境光颜色）。
##   物件（Tiled 里的"类"）：door{to}、arrive{from | start, facing}、search、npc{id}、npc_spot{order}、
##     light{color, radius, energy, flicker}、glow{color, radius}。物件按左上角落在哪一格算格子；门可以是好几格的长条。
##   颜色按 Tiled 的写法 #AARRGGBB 读（#RRGGBB 也认）。

const DataLoader = preload("res://core/util/data_loader.gd")

const DIRS := {"left": Vector2i(-1, 0), "right": Vector2i(1, 0), "up": Vector2i(0, -1), "down": Vector2i(0, 1)}
const LAYERS: Array[String] = ["floor", "walls", "decor", "over"]
const SOLID_LAYERS: Array[String] = ["floor", "walls", "decor"]
const FLIP_H := 0x80000000
const FLIP_V := 0x40000000
const FLIP_D := 0x20000000
const GID_MASK := 0x0FFFFFFF
## 一张图最多几盏灯：兼容渲染器里一个物体最多受 8 盏灯影响，要给手电筒（两盏）和火焰女皇的投影留位置。
const MAX_LIGHTS := 5

static var _cache: Dictionary = {}

var file_path: String = ""
var loc: String = ""
var size := Vector2i(30, 16)
var tile := 16
var props: Dictionary = {}
## 每个图块集：{firstgid, name, path, columns, tilecount, image, imagewidth, imageheight, margin, spacing, props, tiles: {本地编号: 属性}}
var tilesets: Array[Dictionary] = []
## 图层名 → 每格的原始 gid（含翻转位），按行排。
var layers: Dictionary = {}
## 每个物件：{type, name, cell, cells(Rect2i), props}
var objects: Array[Dictionary] = []
## 读图时发现的问题（validate 会一起报）。
var load_errors: Array[String] = []
var _doors: Dictionary = {}


## 读某个地点的图；没有这个文件返回 null。读过的图会缓存（地图数据读进来以后不再改）。
static func make(dir: String, location: String) -> RefCounted:
	var file := dir.path_join(location + ".tmj")
	if _cache.has(file):
		return _cache[file]
	if not FileAccess.file_exists(file):
		return null
	var m := new()
	m.loc = location
	m._load(file)
	_cache[file] = m
	return m


## 测试或改了地图文件之后想重新读，清缓存。
static func clear_cache() -> void:
	_cache.clear()


## Tiled 的颜色：#AARRGGBB（或 #RRGGBB）。
static func color(v: Variant, fallback: Color = Color.WHITE) -> Color:
	var s := String(v)
	if s.length() == 9 and s.begins_with("#"):
		return Color("#" + s.substr(3, 6) + s.substr(1, 2))
	if s.length() == 7 and s.begins_with("#") and Color.html_is_valid(s):
		return Color(s)
	return fallback


static func _props(arr: Variant) -> Dictionary:
	var out := {}
	if arr is Array:
		for p: Dictionary in arr:
			out[String(p["name"])] = p.get("value")
	return out


func _load(file: String) -> void:
	file_path = file
	var res := DataLoader.load_json(file)
	if not res.ok:
		load_errors.append(String(res.error))
		return
	var d: Dictionary = res.data
	if bool(d.get("infinite", false)):
		load_errors.append("%s 是无限地图，不支持" % file)
	size = Vector2i(int(d.get("width", 0)), int(d.get("height", 0)))
	tile = int(d.get("tilewidth", 16))
	props = _props(d.get("properties", []))
	for ts: Dictionary in d.get("tilesets", []):
		var info := _tileset(file.get_base_dir(), ts)
		if not info.is_empty():
			tilesets.append(info)
	tilesets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["firstgid"]) < int(b["firstgid"]))
	for l: Dictionary in d.get("layers", []):
		match String(l.get("type", "")):
			"tilelayer":
				if l.has("encoding") and String(l["encoding"]) != "csv":
					load_errors.append("%s 的图层 %s 不是 CSV 编码" % [file, l.get("name", "")])
					continue
				var arr: Array[int] = []
				for v in l.get("data", []):
					arr.append(int(v))
				if arr.size() != size.x * size.y:
					load_errors.append("%s 的图层 %s 格数不对" % [file, l.get("name", "")])
				layers[String(l["name"])] = arr
			"objectgroup":
				for o: Dictionary in l.get("objects", []):
					objects.append(_object(o))
	for o in objects:
		if String(o["type"]) == "door":
			var r: Rect2i = o["cells"]
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					_doors[Vector2i(x, y)] = String(o["props"].get("to", ""))


func _tileset(base_dir: String, ts: Dictionary) -> Dictionary:
	var info := ts.duplicate()
	var ts_dir := base_dir
	if ts.has("source"):
		var src := base_dir.path_join(String(ts["source"])).simplify_path()
		var res := DataLoader.load_json(src)
		if not res.ok:
			load_errors.append("图块集读不出来：%s" % src)
			return {}
		info = (res.data as Dictionary).duplicate()
		info["firstgid"] = ts["firstgid"]
		info["path"] = src
		ts_dir = src.get_base_dir()
	var tiles := {}
	for t: Dictionary in info.get("tiles", []):
		tiles[int(t["id"])] = _props(t.get("properties", []))
	return {
		"firstgid": int(info["firstgid"]),
		"name": String(info.get("name", "")),
		"path": String(info.get("path", "")),
		"columns": maxi(1, int(info.get("columns", 1))),
		"tilecount": int(info.get("tilecount", 0)),
		"image": ts_dir.path_join(String(info.get("image", ""))).simplify_path() if String(info.get("image", "")) != "" else "",
		"imagewidth": int(info.get("imagewidth", 0)),
		"imageheight": int(info.get("imageheight", 0)),
		"margin": int(info.get("margin", 0)),
		"spacing": int(info.get("spacing", 0)),
		"props": _props(info.get("properties", [])),
		"tiles": tiles,
	}


func _object(o: Dictionary) -> Dictionary:
	var x0 := floori(float(o.get("x", 0.0)) / tile)
	var y0 := floori(float(o.get("y", 0.0)) / tile)
	var w := maxi(1, ceili(float(o.get("width", 0.0)) / tile))
	var h := maxi(1, ceili(float(o.get("height", 0.0)) / tile))
	return {
		"type": String(o.get("type", o.get("class", ""))),
		"name": String(o.get("name", "")),
		"cell": Vector2i(x0, y0),
		"cells": Rect2i(x0, y0, w, h),
		"props": _props(o.get("properties", [])),
	}


# ---------------------------------------------------------------- 图块

func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


## 某层某格的原始 gid（含翻转位）；图外或没有这层返回 0。
func tile_at(layer: String, c: Vector2i) -> int:
	if not inside(c) or not layers.has(layer):
		return 0
	return int(layers[layer][c.y * size.x + c.x])


## 原始 gid → {set: 图块集序号, id: 集内编号, flip_h, flip_v, flip_d}；空格或编号越界返回空字典。
func resolve(raw: int) -> Dictionary:
	var gid := raw & GID_MASK
	if gid == 0:
		return {}
	for i in range(tilesets.size() - 1, -1, -1):
		var ts: Dictionary = tilesets[i]
		if gid >= int(ts["firstgid"]):
			var local := gid - int(ts["firstgid"])
			if local >= int(ts["tilecount"]):
				return {}
			return {"set": i, "id": local, "flip_h": (raw & FLIP_H) != 0, "flip_v": (raw & FLIP_V) != 0, "flip_d": (raw & FLIP_D) != 0}
	return {}


## 一块图块的属性：图块集的属性当默认值，再用这块图块自己的属性盖上去。
func tile_props(raw: int) -> Dictionary:
	var r := resolve(raw)
	if r.is_empty():
		return {}
	var ts: Dictionary = tilesets[int(r["set"])]
	var own: Dictionary = (ts["tiles"] as Dictionary).get(int(r["id"]), {})
	var defaults: Dictionary = ts["props"]
	if defaults.is_empty():
		return own
	var out := defaults.duplicate()
	out.merge(own, true)
	return out


## 这格最上面那块图块的 kind（装饰 > 墙 > 地面）；都没有返回空字符串。
func kind_at(c: Vector2i) -> String:
	for l: String in ["decor", "walls", "floor"]:
		var raw := tile_at(l, c)
		if raw & GID_MASK != 0:
			return String(tile_props(raw).get("kind", ""))
	return ""


# ---------------------------------------------------------------- 格子

## 能走：在图里、是门，或者有地面而且三层里没有挡路的图块。
func walkable(c: Vector2i) -> bool:
	if not inside(c):
		return false
	if is_door(c):
		return true
	if tile_at("floor", c) & GID_MASK == 0:
		return false
	for l in SOLID_LAYERS:
		if bool(tile_props(tile_at(l, c)).get("blocks", false)):
			return false
	return true


func is_door(c: Vector2i) -> bool:
	return _doors.has(c)


func is_search(c: Vector2i) -> bool:
	for o in _of("search"):
		if (o["cells"] as Rect2i).has_point(c):
			return true
	return false


func theme() -> String:
	return String(props.get("theme", ""))


func ambient() -> Color:
	return color(props.get("ambient", "#ffffffff"))


func _of(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o in objects:
		if String(o["type"]) == kind:
			out.append(o)
	return out


## 这扇门通向哪个地点；不是门返回空字符串。
func door_dest(c: Vector2i) -> String:
	return String(_doors.get(c, ""))


## 地图上的门通向的地点（按物件顺序，不重复）。
func door_dests() -> Array[String]:
	var out: Array[String] = []
	for o in _of("door"):
		var to := String(o["props"].get("to", ""))
		if to != "" and not out.has(to):
			out.append(to)
	return out


## 通向 dest 的门格，按行、列排序。
func door_cells(dest: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in _doors:
		if String(_doors[c]) == dest:
			out.append(c)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out


func _arrive(from_loc: String) -> Dictionary:
	for o in _of("arrive"):
		var p: Dictionary = o["props"]
		if from_loc == "" and bool(p.get("start", false)):
			return o
		if from_loc != "" and String(p.get("from", "")) == from_loc:
			return o
	return {}


## 从隔壁地点 from_loc 进来时站的格子：地图上的到达点；没画就站在那扇门往里一格。
func entry_cell(from_loc: String) -> Vector2i:
	var a := _arrive(from_loc)
	if not a.is_empty():
		return a["cell"]
	var doors := door_cells(from_loc)
	if doors.is_empty():
		return start_cell()
	for d: Vector2i in DIRS.values():
		var n: Vector2i = doors[0] + d
		if inside(n) and not is_door(n) and walkable(n):
			return n
	return doors[0]


## 进门以后面朝哪：到达点写了就按写的；否则背对那扇门。
func entry_facing(from_loc: String) -> String:
	var a := _arrive(from_loc)
	if not a.is_empty() and String(a["props"].get("facing", "")) != "":
		return String(a["props"]["facing"])
	var doors := door_cells(from_loc)
	if doors.is_empty():
		return "down"
	var d: Vector2i = entry_cell(from_loc) - doors[0]
	for k: String in DIRS:
		if DIRS[k] == d:
			return k
	return "down"


## 开场站的格子：标了 start 的到达点；没有就站在第一扇门里面。
func start_cell() -> Vector2i:
	var a := _arrive("")
	if not a.is_empty():
		return a["cell"]
	var dests := door_dests()
	if not dests.is_empty():
		return entry_cell(dests[0])
	for y in size.y:
		for x in size.x:
			if walkable(Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i.ZERO


## 开场面朝哪：标了 start 的到达点写的朝向；没有就按第一扇门进来的朝向。
func start_facing() -> String:
	var a := _arrive("")
	if not a.is_empty() and String(a["props"].get("facing", "")) != "":
		return String(a["props"]["facing"])
	var dests := door_dests()
	return entry_facing(dests[0]) if not dests.is_empty() else "down"


func search_cell() -> Vector2i:
	var s := _of("search")
	return s[0]["cell"] if not s.is_empty() else Vector2i(-1, -1)


func is_fixed_npc(npc_id: String) -> bool:
	for o in _of("npc"):
		if String(o["props"].get("id", "")) == npc_id:
			return true
	return false


## 第 index 个剧情人物站哪：有固定站位（npc 物件）的用固定站位，其余按 npc_spot 的 order 顺序。
func npc_cell(npc_id: String, index: int) -> Vector2i:
	for o in _of("npc"):
		if String(o["props"].get("id", "")) == npc_id:
			return o["cell"]
	var spots := _of("npc_spot")
	if spots.is_empty():
		return start_cell()
	spots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["props"].get("order", 0)) < int(b["props"].get("order", 0)))
	return spots[index % spots.size()]["cell"]


## 灯：[{cell, color, radius（格）, energy, flicker}]。
func lights() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o in _of("light"):
		var p: Dictionary = o["props"]
		out.append({"cell": o["cell"], "color": color(p.get("color", "#ffffffff")), "radius": float(p.get("radius", 4.0)), "energy": float(p.get("energy", 1.0)), "flicker": bool(p.get("flicker", false))})
	return out


## 自发光的小光晕（激光发射器、屏幕、指示灯）：[{cell, color, radius}]。
func glows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o in _of("glow"):
		var p: Dictionary = o["props"]
		out.append({"cell": o["cell"], "color": color(p.get("color", "#ffffffff")), "radius": float(p.get("radius", 1.0))})
	return out


## 能走的相邻格（不含 blocked 里的格子）。
func neighbors(c: Vector2i, blocked: Dictionary = {}) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d: Vector2i in DIRS.values():
		var n: Vector2i = c + d
		if walkable(n) and not blocked.has(n):
			out.append(n)
	return out


## 广度优先寻路：从 from 走到 to（to 必须能走），绕开 blocked。返回不含起点的格子序列；走不到返回空数组。
func path(from: Vector2i, to: Vector2i, blocked: Dictionary = {}) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if from == to or not walkable(to) or blocked.has(to):
		return empty
	var prev := {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == to:
			break
		for n in neighbors(c, blocked):
			if not prev.has(n):
				prev[n] = c
				queue.append(n)
	if not prev.has(to):
		return empty
	var out: Array[Vector2i] = []
	var c2: Vector2i = to
	while c2 != from:
		out.push_front(c2)
		c2 = prev[c2]
	return out


func _reachable(from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for n in neighbors(c):
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen


# ---------------------------------------------------------------- 校验

## 检查一个剧本的全部地图：每个地点都有图、读得出来、图块编号都在图块集里；
## 门只通向剧本里相邻的地点、相邻的地点都有门、门上没有挡路的图块；
## 开场点、每个入口、柜子、剧情人物站位都走得到，而且彼此连通（地图内部不会卡死）；灯的数量、位置、颜色合法；
## 目录里没有剧本以外的地图。
static func validate(dir: String, scenario: RefCounted) -> Array[String]:
	var errors: Array[String] = []
	var locations: Dictionary = scenario.data["locations"]
	for loc_id: String in locations:
		var m: RefCounted = make(dir, loc_id)
		if m == null:
			errors.append("地点 %s 没有地图" % loc_id)
			continue
		for e: String in m.load_errors:
			errors.append(e)
		errors.append_array(m._check_tiles())
		var neighbors_of: Array[String] = scenario.neighbors(loc_id)
		for dest: String in m.door_dests():
			if not neighbors_of.has(dest):
				errors.append("%s 有通向 %s 的门，但剧本里它们不相邻" % [loc_id, dest])
		for c: Vector2i in m._doors:
			for l: String in SOLID_LAYERS:
				if bool(m.tile_props(m.tile_at(l, c)).get("blocks", false)):
					errors.append("%s 的门格 %s 上有挡路的图块" % [loc_id, c])
		for n in neighbors_of:
			if not m.door_dests().has(n):
				errors.append("%s 和 %s 相邻，但地图上没有门" % [loc_id, n])
		var start: Vector2i = m.start_cell()
		if not m.walkable(start):
			errors.append("%s 的开场点不能走" % loc_id)
		var reach: Dictionary = m._reachable(start)
		for dest: String in m.door_dests():
			var e: Vector2i = m.entry_cell(dest)
			if not m.walkable(e) or not reach.has(e):
				errors.append("%s 从 %s 进来的入口不能走或和开场点不连通" % [loc_id, dest])
		var s: Vector2i = m.search_cell()
		if s.x < 0:
			errors.append("%s 没有可以搜索的柜子" % loc_id)
		else:
			var touch := false
			for d: Vector2i in DIRS.values():
				if reach.has(s + d):
					touch = true
			if not touch:
				errors.append("%s 的柜子够不着" % loc_id)
		for o: Dictionary in m.objects:
			var t := String(o["type"])
			if (t == "npc" or t == "npc_spot") and not m.walkable(o["cell"]):
				errors.append("%s 的人物站位 %s 不能走" % [loc_id, o["cell"]])
			if (t == "light" or t == "glow") and not m.inside(o["cell"]):
				errors.append("%s 的 %s 在图外" % [loc_id, t])
			if (t == "light" or t == "glow") and color(o["props"].get("color", ""), Color(0, 0, 0, 0)) == Color(0, 0, 0, 0):
				errors.append("%s 的 %s 颜色写错了" % [loc_id, t])
		if m.lights().size() > MAX_LIGHTS:
			errors.append("%s 的灯超过 %d 盏" % [loc_id, MAX_LIGHTS])
		if m.props.has("ambient") and color(m.props["ambient"], Color(0, 0, 0, 0)) == Color(0, 0, 0, 0):
			errors.append("%s 的环境光颜色写错了" % loc_id)
	var d := DirAccess.open(dir)
	if d != null:
		for f in d.get_files():
			if f.ends_with(".tmj") and not locations.has(f.get_basename()):
				errors.append("地图 %s 不是剧本里的地点" % f)
	return errors


func _check_tiles() -> Array[String]:
	var out: Array[String] = []
	if tilesets.is_empty():
		out.append("%s 没有图块集" % loc)
	for name: String in layers:
		var arr: Array = layers[name]
		for i in arr.size():
			var raw := int(arr[i])
			if raw & GID_MASK != 0 and resolve(raw).is_empty():
				out.append("%s 的图层 %s 第 %d 格的图块编号不在任何图块集里" % [loc, name, i])
				break
	return out
