extends "res://tests/test_case.gd"
## Tiled 地图：读 .tmj / .tsj（两个图块集、翻转位、物件、属性、#AARRGGBB 颜色），能不能走、门、入口、站位、灯；
## 填进 TileMapLayer（图块集编号、图集坐标、翻转）；图片不在时的灰盒图；第一部片 8 张图整套校验。

const TiledMap = preload("res://ui/field/tiled_map.gd")
const FieldTiles = preload("res://ui/field/field_tiles.gd")
const Scenario = preload("res://core/expedition/scenario.gd")

const TINY := "res://tests/fixtures/maps/tiny"
const FILM1 := "res://data/maps/biohazard1"
const SCENARIO := "res://data/scenarios/biohazard1/scenario.json"


func _room() -> RefCounted:
	return TiledMap.make(TINY, "room")


## 地图大小、图块集按 firstgid 排好；gid 换算成"第几个图块集的第几块"，翻转位读得出来。
func test_tilesets_and_gids() -> void:
	var m := _room()
	assert_true(m != null)
	assert_eq(m.load_errors.size(), 0, "\n".join(m.load_errors))
	assert_eq(m.size, Vector2i(6, 4))
	assert_eq(m.tile, 16)
	assert_eq(m.tilesets.size(), 2)
	assert_eq(int(m.tilesets[1]["firstgid"]), 5)
	var rug: Dictionary = m.resolve(m.tile_at("floor", Vector2i(3, 1)))
	assert_eq(int(rug["set"]), 1)
	assert_eq(int(rug["id"]), 0)
	assert_true(rug["flip_h"], "水平翻转")
	assert_false(rug["flip_v"])
	var lamp: Dictionary = m.resolve(m.tile_at("over", Vector2i(1, 1)))
	assert_eq(int(lamp["id"]), 1)
	assert_true(lamp["flip_v"] and lamp["flip_d"], "垂直 + 对角翻转")
	assert_eq(m.resolve(0), {}, "空格")
	assert_eq(m.resolve(99), {}, "编号超出图块集")
	assert_true(bool(m.tile_props(m.tile_at("walls", Vector2i(0, 0))).get("blocks", false)))
	assert_eq(m.kind_at(Vector2i(2, 2)), "prop", "装饰层盖在地面上")
	assert_eq(m.kind_at(Vector2i(3, 1)), "carpet")
	assert_eq(String(m.tile_props(m.tile_at("over", Vector2i(1, 1))).get("kind", "")), "rug", "没写属性的图块用图块集上的默认值")
	assert_eq(String(m.tile_props(m.tile_at("floor", Vector2i(3, 1))).get("kind", "")), "carpet", "自己写了的盖过默认值")


## 能走：有地面、三层都不挡路；门能走；墙、箱子、没有地面的格子、图外都不能走。
func test_walkable() -> void:
	var m := _room()
	assert_true(m.walkable(Vector2i(1, 1)))
	assert_true(m.walkable(Vector2i(3, 1)), "翻转过的地毯也是地面")
	assert_true(m.walkable(Vector2i(5, 1)), "门")
	assert_false(m.walkable(Vector2i(0, 1)), "墙")
	assert_false(m.walkable(Vector2i(2, 2)), "箱子挡路")
	assert_false(m.walkable(Vector2i(-1, 1)), "图外")
	var p: Array[Vector2i] = m.path(Vector2i(1, 1), Vector2i(3, 2))
	assert_true(p.size() > 0)
	assert_false(p.has(Vector2i(2, 2)), "绕开箱子")


## 物件：门（长条）、到达点（含开场点和朝向）、柜子、固定站位和按顺序的站位。
func test_objects() -> void:
	var m := _room()
	assert_eq(m.door_dest(Vector2i(5, 2)), "outside")
	assert_eq(m.door_dest(Vector2i(1, 1)), "")
	assert_eq(m.door_cells("outside"), [Vector2i(5, 1), Vector2i(5, 2)] as Array[Vector2i])
	assert_eq(m.door_dests(), ["outside"] as Array[String])
	assert_eq(m.entry_cell("outside"), Vector2i(4, 1))
	assert_eq(m.entry_facing("outside"), "left")
	assert_eq(m.start_cell(), Vector2i(1, 1), "Tiled 新版写成 class 的物件也认")
	assert_eq(m.start_facing(), "right")
	assert_eq(m.search_cell(), Vector2i(2, 2))
	assert_true(m.is_search(Vector2i(2, 2)))
	assert_true(m.is_fixed_npc("boss"))
	assert_eq(m.npc_cell("boss", 5), Vector2i(1, 2))
	assert_eq(m.npc_cell("someone", 0), Vector2i(4, 2), "order 0")
	assert_eq(m.npc_cell("someone", 1), Vector2i(3, 2), "order 1")
	assert_eq(m.npc_cell("someone", 2), Vector2i(4, 2), "人比站位多就从头再排")


## 颜色按 Tiled 的 #AARRGGBB 读；灯和光晕的属性。
func test_colors_and_lights() -> void:
	var m := _room()
	assert_eq(TiledMap.color("#ff336699"), Color("#336699"))
	assert_almost(TiledMap.color("#80ff0000").a, 128.0 / 255.0, 0.001)
	assert_eq(TiledMap.color("#336699"), Color("#336699"))
	assert_eq(TiledMap.color("nope", Color.BLACK), Color.BLACK)
	assert_eq(m.theme(), "hall")
	assert_eq(m.ambient(), Color("#808080"))
	var l: Dictionary = m.lights()[0]
	assert_eq(l["cell"], Vector2i(2, 1))
	assert_eq(l["color"], Color("#336699"))
	assert_almost(float(l["radius"]), 3.0)
	assert_almost(float(l["energy"]), 0.5)
	assert_true(l["flicker"])
	var g: Dictionary = m.glows()[0]
	assert_eq(g["cell"], Vector2i(4, 1))
	assert_almost((g["color"] as Color).r, 1.0, 0.001)


## 填进 TileMapLayer：图块集编号、图集坐标、翻转都对；图片不在时用同样行列的灰盒图。
func test_fill_layers_and_greybox() -> void:
	var m := _room()
	var floor := TileMapLayer.new()
	FieldTiles.fill(floor, m, "floor")
	assert_eq(floor.get_cell_source_id(Vector2i(1, 1)), 0)
	assert_eq(floor.get_cell_atlas_coords(Vector2i(5, 2)), Vector2i(1, 1), "门是 a 的第 3 块：第 2 行第 2 列")
	assert_eq(floor.get_cell_source_id(Vector2i(3, 1)), 1)
	assert_eq(floor.get_cell_alternative_tile(Vector2i(3, 1)), TileSetAtlasSource.TRANSFORM_FLIP_H)
	assert_eq(floor.get_cell_source_id(Vector2i(0, 0)), -1, "空格")
	var over := TileMapLayer.new()
	FieldTiles.fill(over, m, "over")
	assert_eq(over.get_cell_atlas_coords(Vector2i(1, 1)), Vector2i(1, 0))
	assert_eq(over.get_cell_alternative_tile(Vector2i(1, 1)), TileSetAtlasSource.TRANSFORM_FLIP_V | TileSetAtlasSource.TRANSFORM_TRANSPOSE)
	var img := FieldTiles.greybox_image(m.tilesets[0], "hall", 16)
	assert_eq(img.get_size(), Vector2i(32, 32), "2 列 × 2 行")
	assert_true(img.get_pixel(8, 8).a > 0.9, "第一块（地面）画出来了")
	floor.free()
	over.free()


## 第一部片 8 张图整套校验通过。列车和站台大厅（计划 23 加大）用实验室图块；其余还是灰盒图。
func test_film1_maps_valid() -> void:
	var errors: Array[String] = TiledMap.validate(FILM1, Scenario.load_file(SCENARIO))
	assert_eq(errors.size(), 0, "\n".join(errors))
	var hall: RefCounted = TiledMap.make(FILM1, "hall")
	assert_eq(hall.size, Vector2i(71, 22), "站台连着入口大厅")
	assert_eq(hall.tilesets.size(), 3, "实验室的地面、墙壁、物件三个图块集")
	assert_eq(hall.door_dest(Vector2i(9, 18)), "car")
	assert_eq(hall.door_dest(Vector2i(52, 4)), "stairs")
	assert_eq(hall.door_dest(Vector2i(58, 20)), "sewer")
	assert_eq(hall.entry_cell("car"), Vector2i(9, 17))
	assert_eq(hall.entry_facing("car"), "up")
	assert_true(bool(hall.tile_props(hall.tile_at("walls", Vector2i(0, 0))).get("blocks", false)), "实验室墙壁整集挡路")
	assert_eq(hall.search_cell(), Vector2i(68, 19), "储物柜")
	assert_eq(int(hall.props.get("crowd", 0)), 14)
	var car: RefCounted = TiledMap.make(FILM1, "car")
	assert_eq(car.size, Vector2i(105, 23), "四节车厢")
	assert_eq(car.tilesets.size(), 3)
	assert_eq(car.start_cell(), Vector2i(4, 11))
	assert_eq(car.start_facing(), "right", "开场面朝车头")
	assert_false(car.walkable(Vector2i(5, 4)), "车厢壁")
	var stairs: RefCounted = TiledMap.make(FILM1, "stairs")
	assert_true(bool((stairs.tilesets[0]["props"] as Dictionary).get("greybox", false)))
	var tex: Texture2D = (FieldTiles.tileset(stairs).get_source(0) as TileSetAtlasSource).texture
	assert_eq(tex.get_size(), Vector2(48, 48))
	var expected := FieldTiles.greybox_image(stairs.tilesets[0], stairs.theme(), 16)
	assert_eq(tex.get_image().get_pixel(8, 8), expected.get_pixel(8, 8), "灰盒图块集按地点主题现画（本机导出的 greybox.png 只给 Tiled 看）")
	var control: RefCounted = TiledMap.make(FILM1, "control")
	assert_eq(control.npc_cell("red_queen", 0), Vector2i(14, 7))
	assert_true(control.max_lights_in_window() <= TiledMap.MAX_LIGHTS)
	assert_eq(TiledMap.make(FILM1, "laser").glows().size(), 12, "两排激光发射器")
	assert_eq(TiledMap.make(FILM1, "nowhere"), null)
