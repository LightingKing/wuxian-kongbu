extends RefCounted
## 一个地点的可行走地图（RPG 式探索，设计规格 5.1、11）。数据在 data/maps/<剧本>.json：
##   每张图 30×16 格，rows 是一行一个字符串；图例：# 墙　. = 地面　~ 浅水　o x 家具设备　S 可搜索的柜子　D 门；
##   doors：隔壁地点 → 门在哪条边（left / right / top / bottom）；start：开场站的格子；
##   npc_fixed：某个剧情人物固定站的格子；npc_spots：其余剧情人物按顺序站的格子；
##   ambient：环境光颜色（压暗整个画面）；lights：灯 [{at, color, radius（格）, energy, flicker}]；
##   glows：自发光的小光晕（激光发射器、屏幕、指示灯），不照亮别的东西 [{at, color, radius}]。
## 这里只管格子：能不能走、门通向哪、从哪个门进来站哪、寻路。走动、画面在 field_screen.gd。

const DataLoader = preload("res://core/util/data_loader.gd")

const DIRS := {"left": Vector2i(-1, 0), "right": Vector2i(1, 0), "up": Vector2i(0, -1), "down": Vector2i(0, 1)}
const WALKABLE := ".=~D"
const SIDE_IN := {"left": Vector2i(1, 0), "right": Vector2i(-1, 0), "top": Vector2i(0, 1), "bottom": Vector2i(0, -1)}
## 一张图最多几盏灯：兼容渲染器里一个物体最多受 8 盏灯影响，要给手电筒（两盏）和火焰女皇的投影留位置。
const MAX_LIGHTS := 5

static var _cache: Dictionary = {}

var loc: String = ""
var data: Dictionary = {}
var size: Vector2i = Vector2i(30, 16)
var tile: int = 16


static func load_file(path: String) -> Dictionary:
	if not _cache.has(path):
		var res := DataLoader.load_json(path)
		assert(res.ok, res.error)
		_cache[path] = res.data
	return _cache[path]


## 读某个地点的图；剧本里没有这张图返回 null。
static func make(path: String, location: String) -> RefCounted:
	var all := load_file(path)
	if not (all["maps"] as Dictionary).has(location):
		return null
	var m := new()
	m.loc = location
	m.data = all["maps"][location]
	m.size = Vector2i(int(all["size"][0]), int(all["size"][1]))
	m.tile = int(all["tile"])
	return m


func theme() -> String:
	return String(data.get("theme", ""))


func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


## 格子上的字符；图外当墙。
func char_at(c: Vector2i) -> String:
	if not inside(c):
		return "#"
	return String(data["rows"][c.y])[c.x]


func walkable(c: Vector2i) -> bool:
	return WALKABLE.contains(char_at(c))


func is_door(c: Vector2i) -> bool:
	return char_at(c) == "D"


func is_search(c: Vector2i) -> bool:
	return char_at(c) == "S"


## 墙的正面：这格是墙、下面一格不是墙（站在屋里看得到这面墙的高度）。
func wall_face(c: Vector2i) -> bool:
	var below := c + Vector2i(0, 1)
	return char_at(c) == "#" and inside(below) and char_at(below) != "#"


## 环境光颜色（没写就是不压暗）。
func ambient() -> Color:
	return Color(String(data.get("ambient", "#ffffff")))


func lights() -> Array:
	return data.get("lights", [])


func glows() -> Array:
	return data.get("glows", [])


## 门在哪条边。
func _side_of(c: Vector2i) -> String:
	if c.x == 0:
		return "left"
	if c.x == size.x - 1:
		return "right"
	if c.y == 0:
		return "top"
	if c.y == size.y - 1:
		return "bottom"
	return ""


## 这扇门通向哪个地点；不是门返回空字符串。
func door_dest(c: Vector2i) -> String:
	if not is_door(c):
		return ""
	var side := _side_of(c)
	for dest: String in data.get("doors", {}):
		if String(data["doors"][dest]) == side:
			return dest
	return ""


func door_cells(dest: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			var c := Vector2i(x, y)
			if door_dest(c) == dest:
				out.append(c)
	return out


## 从隔壁地点 from_loc 进来时站的格子：那扇门往里一格。
func entry_cell(from_loc: String) -> Vector2i:
	var doors := door_cells(from_loc)
	if doors.is_empty():
		return start_cell()
	var d: Vector2i = doors[0]
	return d + SIDE_IN[_side_of(d)]


func start_cell() -> Vector2i:
	if data.has("start"):
		return Vector2i(int(data["start"][0]), int(data["start"][1]))
	for dest: String in data.get("doors", {}):
		return entry_cell(dest)
	return Vector2i(1, 1)


func search_cell() -> Vector2i:
	for y in size.y:
		var row := String(data["rows"][y])
		var x := row.find("S")
		if x >= 0:
			return Vector2i(x, y)
	return Vector2i(-1, -1)


## 第 index 个剧情人物站哪：有固定位置的用固定位置，其余按 npc_spots 顺序。
func npc_cell(npc_id: String, index: int) -> Vector2i:
	var fixed: Dictionary = data.get("npc_fixed", {})
	if fixed.has(npc_id):
		return Vector2i(int(fixed[npc_id][0]), int(fixed[npc_id][1]))
	var spots: Array = data.get("npc_spots", [])
	if spots.is_empty():
		return start_cell()
	var s: Array = spots[index % spots.size()]
	return Vector2i(int(s[0]), int(s[1]))


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


## 检查一个剧本的全部地图：每个地点都有图、尺寸对、门只通向剧本里相邻的地点而且相邻地点都有门、
## 开场点和入口能走、柜子只有一个而且够得着、剧情人物站位能走、所有门互相连通。
static func validate(path_json: String, scenario: RefCounted) -> Array[String]:
	var errors: Array[String] = []
	var all := load_file(path_json)
	for loc_id: String in scenario.data["locations"]:
		var m: RefCounted = make(path_json, loc_id)
		if m == null:
			errors.append("地点 %s 没有地图" % loc_id)
			continue
		var rows: Array = m.data["rows"]
		if rows.size() != m.size.y:
			errors.append("%s 的行数不对" % loc_id)
			continue
		for r in rows:
			if String(r).length() != m.size.x:
				errors.append("%s 有一行宽度不对" % loc_id)
		var neighbors_of: Array[String] = scenario.neighbors(loc_id)
		for dest: String in m.data.get("doors", {}):
			if not neighbors_of.has(dest):
				errors.append("%s 有通向 %s 的门，但剧本里它们不相邻" % [loc_id, dest])
			if m.door_cells(dest).is_empty():
				errors.append("%s 通向 %s 的门那条边上没有 D" % [loc_id, dest])
		for n in neighbors_of:
			if not (m.data.get("doors", {}) as Dictionary).has(n):
				errors.append("%s 和 %s 相邻，但地图上没有门" % [loc_id, n])
		if not m.walkable(m.start_cell()):
			errors.append("%s 的开场点不能走" % loc_id)
		var reach: Dictionary = m._reachable(m.start_cell())
		for dest: String in m.data.get("doors", {}):
			var e: Vector2i = m.entry_cell(dest)
			if not m.walkable(e) or not reach.has(e):
				errors.append("%s 从 %s 进来的入口不能走或走不到" % [loc_id, dest])
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
		for spot in m.data.get("npc_spots", []):
			var c := Vector2i(int(spot[0]), int(spot[1]))
			if not m.walkable(c):
				errors.append("%s 的人物站位 %s 不能走" % [loc_id, c])
		for npc_id: String in m.data.get("npc_fixed", {}):
			if not m.walkable(m.npc_cell(npc_id, 0)):
				errors.append("%s 的 %s 站位不能走" % [loc_id, npc_id])
		if m.data.has("ambient") and not Color.html_is_valid(String(m.data["ambient"])):
			errors.append("%s 的环境光颜色写错了" % loc_id)
		if m.lights().size() > MAX_LIGHTS:
			errors.append("%s 的灯超过 %d 盏" % [loc_id, MAX_LIGHTS])
		for key: String in ["lights", "glows"]:
			for l: Dictionary in m.data.get(key, []):
				var at := Vector2i(int(l["at"][0]), int(l["at"][1]))
				if not m.inside(at):
					errors.append("%s 的 %s 位置 %s 在图外" % [loc_id, key, at])
				if not Color.html_is_valid(String(l.get("color", "#ffffff"))):
					errors.append("%s 的 %s 颜色写错了" % [loc_id, key])
	for loc_id: String in all["maps"]:
		if not (scenario.data["locations"] as Dictionary).has(loc_id):
			errors.append("地图 %s 不是剧本里的地点" % loc_id)
	return errors


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
