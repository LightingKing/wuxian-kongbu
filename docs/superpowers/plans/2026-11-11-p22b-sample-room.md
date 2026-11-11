# 计划 22 续：样板房间定稿 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用户在样板房间里比较了两版蜂巢入口大厅（免费的 Land of pixels 实验室图块，原色 / 映射到共用 32 色调色板），选了"共用调色板"。本计划把这一版定为标准：实验室图块集和新的大厅进工程，图块映射工具、来源和许可记录、素材清单、标题画面的致谢页一起做好。

**Architecture:**
- `ui/field/tiled_map.gd`：写在 Tiled 图块集上的属性当作这个集里每块图块的默认值（单块图块上写的会盖过它），这样"实验室墙壁整集挡路"一行就写完，不用给几百块图块逐个写属性；`field_tiles.gd` 画灰盒时同样合并默认值。
- `game/data/maps/tilesets/lab_floor.tsj`、`lab_walls.tsj`、`lab_stuff.tsj`：实验室三张图块图（地面、墙壁、物件）；图片在本机 `game/art/tiles/lab/`，不进仓库。
- `game/tools/palette_map.py`：带透明的像素图映射到共用调色板（用 `pixelize_scene.py` 的最近色规则，不缩放、不抖动、不改透明度），输出含 SHA-256 的报告。
- `game/data/maps/biohazard1/hall.tmj`：样板大厅（34×20，比一屏大，镜头会动）：北墙的电梯通往楼梯井，西墙斑马线门通往车厢，南墙检修格栅通往下水道；接待台、光球灯柱、培养舱、货架、长椅、终端机、可以搜索的储物柜。
- 标题画面加"致谢"，内容来自 `game/data/credits.json`；`art_src/tiles/LICENSES.md` 记来源、许可、署名、改动和重做方法；`art_src/manifest/field.json` 是素材清单（create-game-assets 的格式）。

**Tech Stack:** Godot 4.7.2、Tiled 1.11 JSON、Python 3 + Pillow。

**依据：** 设计 `docs/superpowers/specs/2026-11-10-film1-hub-remake-design.md` 第 3 节（只用免费素材、核对许可、先批准样板房间、统一调色板用同一个确定性映射、素材清单、致谢页）；用户选择（2026-11-11："Shared palette"）。素材：Land of pixels — Laboratory tileset，作者 marceles，CC BY 4.0（https://opengameart.org/content/laboratory-tileset-pixelart-16px ），已下载到本机 `_work/sample_room/dl_lab/`。

**不在本计划范围：** 其余 7 个地点的多屏新地图（计划 23）；正式的人物行走图（任务卡 007）——在那之前本机用同一个包里的研究员、防护服人物临时顶替（本机占位，不进仓库）。

**本计划已在临时目录跑通：480 个无界面测试全过、`SCRIPT ERROR 0`、M1 切片验收 0 失败；三张图块图映射后颜色全在调色板里（10、21、25 色），和用户看过的样板逐字节相同；截图确认大厅在正常流程里显示正确、致谢页排版正常。**

**执行环境注意：**
- 仓库根目录：`I:\workspace\mobilegame\wuxian-kongbu\`；命令都在仓库根目录执行（Git Bash）。
- 文本文件 **LF**、UTF-8 无 BOM；GDScript 用 **Tab**。
- **只提交，不推送。**
- 临时验证目录是 `_work/plan_check_p22b`。
- 图片不进仓库：`game/art/tiles/lab/*.png`、`game/art/field/walkers/*.png` 只在本机。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `game/ui/field/tiled_map.gd` | 图块集属性当默认值 |
| `game/ui/field/field_tiles.gd` | 灰盒也合并默认值 |
| `game/tools/palette_map.py` | 带透明的像素图映射到共用调色板 |
| `game/data/maps/tilesets/lab_*.tsj` | 实验室图块集（三张） |
| `game/data/maps/biohazard1/hall.tmj` | 样板大厅（实验室图块） |
| `game/ui/title_screen.gd` | 致谢页 |
| `game/data/credits.json` | 致谢条目 |
| `game/tests/fixtures/maps/tilesets/b.tsj` | 测试用图块集加一个默认属性 |
| `game/tests/unit/ui/test_field.gd`、`test_tiled_map.gd`、`test_title.gd` | 新大厅、默认属性、致谢页 |
| `art_src/tiles/LICENSES.md` | 来源、许可、署名、改动、重做方法；看过没用的包 |
| `art_src/tiles/lab/*.report.json` | 映射报告（含 SHA-256，生成） |
| `art_src/manifest/field.json` | 素材清单 |

---

## Task 1：实验室图块集和样板大厅

**Files:**
- Create: `game/tools/palette_map.py`、`game/data/maps/tilesets/lab_floor.tsj`、`game/data/maps/tilesets/lab_walls.tsj`、`game/data/maps/tilesets/lab_stuff.tsj`
- Modify: `game/ui/field/tiled_map.gd`、`game/ui/field/field_tiles.gd`、`game/data/maps/biohazard1/hall.tmj`、`game/tests/fixtures/maps/tilesets/b.tsj`、`game/tests/unit/ui/test_field.gd`、`game/tests/unit/ui/test_tiled_map.gd`

- [ ] **Step 1：写测试 `game/tests/unit/ui/test_tiled_map.gd`**

```gdscript
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


## 第一部片 8 张图（从字符草图转过来的灰盒图）整套校验通过；门、入口和原来一样。
func test_film1_maps_valid() -> void:
	var errors: Array[String] = TiledMap.validate(FILM1, Scenario.load_file(SCENARIO))
	assert_eq(errors.size(), 0, "\n".join(errors))
	var hall: RefCounted = TiledMap.make(FILM1, "hall")
	assert_eq(hall.size, Vector2i(34, 20), "样板大厅比一屏大")
	assert_eq(hall.tilesets.size(), 3, "实验室的地面、墙壁、物件三个图块集")
	assert_eq(hall.door_dest(Vector2i(0, 9)), "car")
	assert_eq(hall.door_dest(Vector2i(16, 3)), "stairs")
	assert_eq(hall.door_dest(Vector2i(22, 19)), "sewer")
	assert_eq(hall.entry_cell("car"), Vector2i(1, 9))
	assert_eq(hall.entry_facing("car"), "right")
	assert_true(bool(hall.tile_props(hall.tile_at("walls", Vector2i(0, 0))).get("blocks", false)), "实验室墙壁整集挡路")
	assert_eq(hall.kind_at(Vector2i(5, 5)), "floor")
	assert_eq(hall.search_cell(), Vector2i(32, 18), "储物柜")
	var car: RefCounted = TiledMap.make(FILM1, "car")
	assert_eq(car.start_cell(), Vector2i(3, 7))
	assert_eq(car.start_facing(), "right", "开场面朝去大厅的门")
	assert_eq(car.kind_at(Vector2i(5, 3)), "wall_face", "座位上面那排墙是墙面")
	assert_true(bool((car.tilesets[0]["props"] as Dictionary).get("greybox", false)))
	var tex: Texture2D = (FieldTiles.tileset(car).get_source(0) as TileSetAtlasSource).texture
	assert_eq(tex.get_size(), Vector2(48, 48))
	var expected := FieldTiles.greybox_image(car.tilesets[0], "train", 16)
	assert_eq(tex.get_image().get_pixel(8, 8), expected.get_pixel(8, 8), "灰盒图块集按地点主题现画（本机导出的 greybox.png 只给 Tiled 看）")
	var control: RefCounted = TiledMap.make(FILM1, "control")
	assert_eq(control.npc_cell("red_queen", 0), Vector2i(14, 7))
	assert_true(control.lights().size() <= TiledMap.MAX_LIGHTS)
	assert_eq(TiledMap.make(FILM1, "laser").glows().size(), 12, "两排激光发射器")
	assert_eq(TiledMap.make(FILM1, "nowhere"), null)
```

- [ ] **Step 2：写测试 `game/tests/unit/ui/test_field.gd`**

```gdscript
extends "res://tests/test_case.gd"
## RPG 式探索：地图（Tiled）、门与入口、寻路；场景里台词进对话框、选择弹窗口、走动、进门、搜索、说话、黑暗；
## 灯光、行走图、队友站位、互动提示、打字效果；图块层；镜头跟随和边界、镜头滚动后点哪格走哪格（在场景树里测）。

const TiledMap = preload("res://ui/field/tiled_map.gd")
const FieldScreen = preload("res://ui/field/field_screen.gd")
const FieldArt = preload("res://ui/field/field_art.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const Session = preload("res://core/session/session.gd")

const MAPS := "res://data/maps/biohazard1"
const BIG := "res://tests/fixtures/maps/big"
const SCENARIO := "res://data/scenarios/biohazard1/scenario.json"


func _screen(seed_value: int = 1) -> Control:
	var s := Session.new()
	s.start_m1(seed_value)
	var names := {}
	for id: String in s.game.characters:
		names[id] = s.game.characters[id].display_name
	var f := FieldScreen.new()
	f.setup(s.expedition, names)
	return f


## 八个地点都有图；门只通向剧本里相邻的地点，相邻的地点都有门；入口、柜子、站位都走得到。
func test_maps_valid() -> void:
	var errors: Array[String] = TiledMap.validate(MAPS, Scenario.load_file(SCENARIO))
	assert_eq(errors.size(), 0, "\n".join(errors))


## 门通向哪、从哪进来站哪；寻路绕开墙和挡路的人。
func test_doors_entries_and_path() -> void:
	var hall: RefCounted = TiledMap.make(MAPS, "hall")
	assert_eq(hall.door_dest(Vector2i(0, 9)), "car")
	assert_eq(hall.door_dest(Vector2i(16, 3)), "stairs", "电梯下面的脚垫")
	assert_eq(hall.door_dest(Vector2i(22, 19)), "sewer", "南墙的检修格栅")
	assert_eq(hall.door_dest(Vector2i(5, 5)), "")
	assert_eq(hall.entry_cell("car"), Vector2i(1, 9))
	assert_eq(hall.entry_cell("stairs"), Vector2i(16, 4))
	var p: Array[Vector2i] = hall.path(Vector2i(1, 9), Vector2i(16, 4))
	assert_true(p.size() > 0)
	assert_eq(p[p.size() - 1], Vector2i(16, 4))
	for c in p:
		assert_true(hall.walkable(c))
	assert_eq(hall.path(Vector2i(1, 9), Vector2i(0, 0)).size(), 0, "墙走不到")
	assert_false(hall.walkable(Vector2i(15, 9)), "接待台挡路")
	var blocked := {Vector2i(2, 9): true}
	for c in hall.path(Vector2i(1, 9), Vector2i(3, 9), blocked):
		assert_false(blocked.has(c), "绕开挡路的人")


## 开局：主角站在车厢开场点；张杰讲规则一句句进对话框；看完弹出选择窗口；选了就收起。
func test_opening_messages_then_choice() -> void:
	var f := _screen()
	assert_eq(f.loc, "car")
	assert_eq(f.cell, Vector2i(3, 7))
	assert_eq(f.player_id, "zheng_zha")
	assert_eq(f.followers.size(), 6)
	assert_true(f.box.visible)
	assert_eq(f.box_name.text, "张杰")
	assert_true(f.box_text.text.contains("菜鸟们"))
	assert_true(f.busy(), "对话没看完不能走")
	var guard := 0
	while f.box.visible and guard < 20:
		f._show_next()
		guard += 1
	assert_true(f.choice_panel.visible)
	assert_true(f.press_choice("listen"))
	assert_false(f.choice_panel.visible)
	f.flush_messages()
	f._show_next()
	assert_false(f.busy())
	f.free()


## 走动：撞墙只转身；往右走一格；进门去大厅（花 10 分钟），站在门里一格；雇佣兵到了，挡着路。
func test_walk_and_door() -> void:
	var f := _screen()
	f.press_choice("listen")
	f.flush_messages()
	f._show_next()
	f.step("up")
	assert_eq(f.cell, Vector2i(3, 6), "往上一格是地面")
	f.step("up")
	f.step("up")
	assert_eq(f.cell, Vector2i(3, 4), "座位之间的空当能走进去")
	f.step("up")
	assert_eq(f.cell, Vector2i(3, 4), "墙挡路")
	assert_eq(f.facing, "up")
	f.step("right")
	assert_eq(f.cell, Vector2i(3, 4), "座位挡路")
	f.step("down")
	f.step("right")
	assert_eq(f.cell, Vector2i(4, 5))
	assert_true(f.press_move("hall"))
	assert_eq(f.loc, "hall")
	assert_eq(f.cell, f.fmap.entry_cell("car"))
	assert_eq(int(f.view.ex.st.clock), 10)
	assert_eq(f.npc_sprites.size(), 7, "雇佣兵在大厅")
	var blocked: Dictionary = f._blocked()
	assert_eq(blocked.size(), 7)
	f.free()


## 对着柜子按确认就搜索；对着剧情人物按确认就说话。
func test_interact_search_and_talk() -> void:
	var f := _screen()
	f.press_choice("listen")
	f.flush_messages()
	f._show_next()
	f.cell = Vector2i(1, 8)
	f.facing = "down"
	f.interact()
	assert_true(f.view.ex.st.searched.has("car"), "车厢搜过了")
	f.flush_messages()
	f._show_next()
	f.press_move("hall")
	f.flush_messages()
	f._show_next()
	var talked: Array = []
	f.talk_requested.connect(func(id: String) -> void: talked.append(id))
	var mc: Vector2i = f.npc_cells["matthew"]
	f.cell = mc + Vector2i(0, 1)
	f.facing = "up"
	f.interact()
	assert_eq(talked, ["matthew"])
	f.free()


## 点地面：算出一条路，排进走路队列。
func test_click_to_walk() -> void:
	var f := _screen()
	f.press_choice("listen")
	f.flush_messages()
	f._show_next()
	f.click_cell(Vector2i(10, 8))
	assert_true(f.path_queue.size() > 0)
	assert_eq(f.path_queue[f.path_queue.size() - 1], Vector2i(10, 8))
	f.click_cell(Vector2i(29, 7))
	assert_eq(String(f.path_then.get("door", "")), "hall", "点门：走到门边再进去")
	f.free()


## 楼梯井是黑的：手电筒遮罩打开；换屏回来还站在原地。
func test_dark_and_memory() -> void:
	var f := _screen()
	f.press_choice("listen")
	f.press_move("hall")
	f.press_move("stairs")
	assert_eq(f.loc, "stairs")
	f.flush_messages()
	f._show_next()
	assert_true(f.dark.visible)
	var ex: RefCounted = f.view.ex
	var where: Vector2i = f.cell
	f.free()
	var g := FieldScreen.new()
	g.setup(ex, {})
	assert_eq(g.loc, "stairs")
	assert_eq(g.cell, where)
	g.free()


## 灯光：每个地点按地图打灯、压环境光；激光通道墙上的发射器是自发光光晕；黑暗地点换成手电筒；火焰女皇的投影发红光。
func test_lights_and_ambient() -> void:
	var f := _screen()
	f.press_choice("listen")
	assert_eq(f.light_root.get_child_count(), (f.fmap.lights() as Array).size())
	assert_eq(f.canvas_mod.color, f.fmap.ambient())
	assert_false(f.dark.visible, "车厢不黑")
	f.press_move("hall")
	assert_eq(f.light_root.get_child_count(), 5, "大厅四盏顶灯加接待台的台灯")
	f.press_move("stairs")
	assert_true(f.dark.visible)
	assert_eq(f.canvas_mod.color, FieldScreen.DARK_AMBIENT, "黑暗地点只剩手电筒")
	f.free()
	var laser: RefCounted = TiledMap.make(MAPS, "laser")
	assert_eq((laser.glows() as Array).size(), 12, "两排激光发射器")
	var control: RefCounted = TiledMap.make(MAPS, "control")
	assert_true((control.lights() as Array).size() <= TiledMap.MAX_LIGHTS)


## 有 Codex 的行走图就用：按 4×4 切帧（规格单帧 16×32），脚底中点对齐格子；没有的人还用占位小人。
func test_walker_sheet() -> void:
	var dir := "user://test_field_art/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir + "walkers"))
	var sheet := Image.create(64, 128, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	sheet.fill_rect(Rect2i(4, 4, 8, 28), Color("3a4a78"))
	sheet.save_png(ProjectSettings.globalize_path(dir + "walkers/zheng_zha.png"))
	var old_root := FieldArt.art_root
	FieldArt.art_root = dir
	FieldArt.clear_cache()
	var f := _screen()
	assert_eq(FieldArt.walker_size("zheng_zha"), Vector2i(16, 32))
	var down0 := FieldArt.walker("zheng_zha", "down", 0) as AtlasTexture
	assert_eq(down0.region, Rect2(0, 0, 16, 32))
	var up_step := FieldArt.walker("zheng_zha", "up", 2) as AtlasTexture
	assert_eq(up_step.region, Rect2(48, 96, 16, 32), "第 4 行（上）第 4 列（迈另一只脚）")
	assert_eq(f.player.offset, Vector2(-8, -32), "脚底中点对齐格子")
	assert_eq(FieldArt.walker_size("zhang_jie"), Vector2i(FieldArt.WALK_W, FieldArt.WALK_H), "没有行走图的还用占位小人")
	f.free()
	FieldArt.art_root = old_root
	FieldArt.clear_cache()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + "walkers/zheng_zha.png"))


## 一进场队友就围在主角身边（各站一格、都能走）；面前的柜子、门、人会提示能做什么。
func test_formation_and_prompts() -> void:
	var f := _screen()
	f.press_choice("listen")
	f.flush_messages()
	f._show_next()
	var taken := {}
	for i in f.followers.size():
		var c: Vector2i = f.trail[i + 1]
		assert_true(f.followers[i].visible, "队友看得见")
		assert_true(f.fmap.walkable(c))
		assert_false(taken.has(c), "不叠在一起")
		taken[c] = true
	assert_false(taken.has(f.cell))
	f.cell = Vector2i(1, 8)
	f.facing = "down"
	assert_eq(f.prompt_text(), "Enter 调查")
	f.cell = Vector2i(28, 7)
	f.facing = "right"
	assert_true(f.prompt_text().begins_with("前往："))
	f.cell = f.trail[1] + Vector2i(0, -1) if f.fmap.walkable(f.trail[1] + Vector2i(0, -1)) else f.trail[1] + Vector2i(0, 1)
	f.facing = f._dir_between(f.cell, f.trail[1])
	assert_true(f.prompt_text().begins_with("Enter 说话："))
	f.cell = Vector2i(10, 7)
	f.facing = "down"
	assert_eq(f.prompt_text(), "", "面前是空地")
	f.free()


## 台词一个字一个字打出来（在场景树里才打字，测试里手动设成"还没打完"）：确认键先把这句显示完，再按才到下一句。
func test_typewriter_and_advance() -> void:
	var f := _screen()
	f.messages.clear()
	f.messages.append({"id": "zhang_jie", "name": "张杰", "text": "第一句"})
	f.messages.append({"id": "", "name": "", "text": "第二句"})
	f._hide_box()
	f._show_next()
	assert_eq(f.box_text.text, "第一句")
	assert_eq(f.box_text.visible_characters, -1, "不在场景树里不打字")
	f.box_text.visible_characters = 1
	f._advance()
	assert_eq(f.box_text.visible_characters, -1, "一下子显示完")
	assert_eq(f.box_text.text, "第一句", "还停在这一句")
	f._advance()
	assert_eq(f.box_text.text, "第二句")
	assert_false(f.box_face.visible, "旁白没有立绘")
	f.free()


## 图块层：地面、墙、装饰在人物下面，上层在人物上面；车厢的墙、座位、柜子都填进去了。
func test_tile_layers() -> void:
	var f := _screen()
	var floor: TileMapLayer = f.map_layers["floor"]
	var walls: TileMapLayer = f.map_layers["walls"]
	var decor: TileMapLayer = f.map_layers["decor"]
	assert_eq(floor.get_cell_source_id(Vector2i(3, 7)), 0, "开场格有地面")
	assert_eq(walls.get_cell_atlas_coords(Vector2i(5, 3)), Vector2i(1, 1), "座位上面那排是墙面（灰盒第 5 块）")
	assert_eq(decor.get_cell_atlas_coords(Vector2i(1, 9)), Vector2i(1, 2), "柜子（灰盒第 8 块）")
	assert_true(floor.get_index() < f.actors.get_index(), "地面在人物下面")
	assert_true(f.map_layers["over"].get_index() > f.actors.get_index(), "上层在人物上面")
	assert_eq(f.camera.limit_right, 30 * 16)
	f.free()


## 镜头（在场景树里）：地图比一屏大时跟着主角，到地图边上停住；镜头滚过以后点哪格就是哪格。
func test_camera_follows_and_clamps() -> void:
	FieldScreen.maps_dir = BIG
	var f := _screen()
	tree().root.add_child(f)
	f._snap_camera()
	await tree().process_frame
	assert_eq(f.fmap.size, Vector2i(40, 24), "测试用的大地图")
	assert_eq(f.view_origin(), Vector2.ZERO, "开场在左上角，镜头贴着地图左上边")
	assert_eq(f.cell_at(Vector2(4 * 16 * 3 + 8, 4 * 16 * 3 + 8)), Vector2i(3, 3))
	f.cell = Vector2i(20, 12)
	f._draw_actors()
	f._snap_camera()
	await tree().process_frame
	var o: Vector2 = f.view_origin()
	assert_eq(o, Vector2(20 * 16 + 8 - 240, 12 * 16 + 14 - 8 - 128), "主角在屏幕正中")
	assert_eq(f.cell_at(Vector2(240 * 4, 120 * 4)), Vector2i(20, 11), "屏幕正中偏上一点是主角头顶那格")
	f.cell = Vector2i(38, 22)
	f._draw_actors()
	f._snap_camera()
	await tree().process_frame
	assert_eq(f.view_origin(), Vector2(40 * 16 - 480, 24 * 16 - 256), "到了右下角，镜头贴着地图边停住")
	assert_eq(f.cell_at(Vector2.ZERO), Vector2i(10, 8))
	tree().root.remove_child(f)
	f.free()
	FieldScreen.maps_dir = MAPS
```

- [ ] **Step 3：改写 `game/tests/fixtures/maps/tilesets/b.tsj`**

```json
{
	"type": "tileset", "version": "1.10", "tiledversion": "1.11.0", "name": "b",
	"tilewidth": 16, "tileheight": 16, "columns": 2, "tilecount": 2,
	"image": "b.png", "imagewidth": 32, "imageheight": 16, "margin": 0, "spacing": 0,
	"properties": [{"name": "kind", "type": "string", "value": "rug"}],
	"tiles": [
		{"id": 0, "properties": [{"name": "kind", "type": "string", "value": "carpet"}]}
	]
}
```

- [ ] **Step 4：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=ui/test_ bash game/tools/run_tests.sh | tail -3`

预期：有失败（大厅还是旧的、图块集默认值还不生效）。

- [ ] **Step 5：改写 `game/ui/field/tiled_map.gd`**

```gdscript
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
```

- [ ] **Step 6：改写 `game/ui/field/field_tiles.gd`**

```gdscript
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
		var p: Dictionary = (info["props"] as Dictionary).duplicate()
		p.merge(tiles.get(id, {}), true)
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
```

- [ ] **Step 7：创建 `game/data/maps/tilesets/lab_floor.tsj`**

```json
{
	"type": "tileset",
	"version": "1.10",
	"tiledversion": "1.11.0",
	"name": "lab_floor",
	"tilewidth": 16,
	"tileheight": 16,
	"columns": 11,
	"tilecount": 198,
	"image": "../../../art/tiles/lab/tilesFloor.png",
	"imagewidth": 176,
	"imageheight": 288,
	"margin": 0,
	"spacing": 0,
	"properties": [
		{
			"name": "kind",
			"type": "string",
			"value": "floor"
		}
	]
}
```

- [ ] **Step 8：创建 `game/data/maps/tilesets/lab_walls.tsj`**

```json
{
	"type": "tileset",
	"version": "1.10",
	"tiledversion": "1.11.0",
	"name": "lab_walls",
	"tilewidth": 16,
	"tileheight": 16,
	"columns": 12,
	"tilecount": 192,
	"image": "../../../art/tiles/lab/tilesWalls.png",
	"imagewidth": 192,
	"imageheight": 256,
	"margin": 0,
	"spacing": 0,
	"properties": [
		{
			"name": "blocks",
			"type": "bool",
			"value": true
		},
		{
			"name": "kind",
			"type": "string",
			"value": "wall"
		}
	]
}
```

- [ ] **Step 9：创建 `game/data/maps/tilesets/lab_stuff.tsj`**

```json
{
	"type": "tileset",
	"version": "1.10",
	"tiledversion": "1.11.0",
	"name": "lab_stuff",
	"tilewidth": 16,
	"tileheight": 16,
	"columns": 37,
	"tilecount": 592,
	"image": "../../../art/tiles/lab/tilesStuff.png",
	"imagewidth": 592,
	"imageheight": 256,
	"margin": 0,
	"spacing": 0,
	"properties": [
		{
			"name": "blocks",
			"type": "bool",
			"value": true
		},
		{
			"name": "kind",
			"type": "string",
			"value": "prop"
		}
	]
}
```

- [ ] **Step 10：改写 `game/data/maps/biohazard1/hall.tmj`**

```json
{
	"type": "map",
	"version": "1.10",
	"tiledversion": "1.11.0",
	"orientation": "orthogonal",
	"renderorder": "right-down",
	"infinite": false,
	"width": 34,
	"height": 20,
	"tilewidth": 16,
	"tileheight": 16,
	"compressionlevel": -1,
	"properties": [
		{
			"name": "theme",
			"type": "string",
			"value": "hall"
		},
		{
			"name": "ambient",
			"type": "color",
			"value": "#ff9ea7ba"
		}
	],
	"tilesets": [
		{
			"firstgid": 1,
			"source": "../tilesets/lab_floor.tsj"
		},
		{
			"firstgid": 199,
			"source": "../tilesets/lab_walls.tsj"
		},
		{
			"firstgid": 391,
			"source": "../tilesets/lab_stuff.tsj"
		}
	],
	"layers": [
		{
			"id": 1,
			"name": "floor",
			"type": "tilelayer",
			"x": 0,
			"y": 0,
			"width": 34,
			"height": 20,
			"opacity": 1,
			"visible": true,
			"data": [
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,119,120,121,119,120,121,119,120,121,119,120,121,119,120,190,191,192,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,0,
				0,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,0,
				0,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,0,
				0,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,0,
				0,119,120,121,119,120,121,119,120,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,119,120,121,119,120,121,119,120,0,
				0,130,131,132,130,131,132,130,131,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,130,131,132,130,131,132,130,131,0,
				56,57,120,121,119,120,121,119,120,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,119,120,121,119,120,121,119,120,0,
				67,68,131,132,130,131,132,130,131,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,130,131,132,130,131,132,130,131,0,
				0,119,120,121,119,120,121,119,120,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,119,120,121,119,120,121,119,120,0,
				0,130,131,132,130,131,132,130,131,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,130,131,132,130,131,132,130,131,0,
				0,119,120,121,119,120,121,119,120,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,119,120,121,119,120,121,119,120,0,
				0,130,131,132,130,131,132,130,131,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,130,131,132,130,131,132,130,131,0,
				0,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,0,
				0,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,0,
				0,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,0,
				0,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,185,186,132,130,131,132,130,131,132,130,131,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,196,197,0,0,0,0,0,0,0,0,0,0
			]
		},
		{
			"id": 2,
			"name": "walls",
			"type": "tilelayer",
			"x": 0,
			"y": 0,
			"width": 34,
			"height": 20,
			"opacity": 1,
			"visible": true,
			"data": [
				199,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,203,
				211,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,215,
				211,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,215,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				302,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,290,0,0,314,308,308,308,308,308,308,308,308,285
			]
		},
		{
			"id": 3,
			"name": "decor",
			"type": "tilelayer",
			"x": 0,
			"y": 0,
			"width": 34,
			"height": 20,
			"opacity": 1,
			"visible": true,
			"data": [
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,532,533,534,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,483,484,485,486,487,0,0,0,528,529,0,0,569,570,571,0,0,488,489,490,0,0,556,557,558,559,560,0,0,0,0,
				0,0,0,520,521,522,523,524,0,0,0,0,0,0,643,606,607,608,645,0,525,526,527,0,0,593,594,595,596,597,0,0,0,0,
				0,757,758,759,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,681,682,0,0,
				0,794,795,796,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,868,869,870,0,0,0,0,0,0,718,719,0,0,
				0,831,832,833,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,905,906,907,0,0,0,0,0,0,755,756,0,0,
				0,0,0,0,0,0,0,787,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,787,0,0,0,792,793,0,0,
				0,0,420,457,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,825,826,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,862,863,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,751,752,753,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,788,789,790,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,681,682,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,718,719,0,0,
				0,0,926,927,0,0,0,787,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,787,0,0,0,755,756,0,0,
				0,0,963,964,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,792,793,759,0,
				0,0,0,0,0,0,0,0,0,0,0,0,936,937,938,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,796,0,
				0,0,0,0,0,0,0,0,0,0,0,0,973,974,975,0,0,0,0,0,896,0,0,0,0,896,0,0,0,0,0,0,833,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
			]
		},
		{
			"id": 4,
			"name": "over",
			"type": "tilelayer",
			"x": 0,
			"y": 0,
			"width": 34,
			"height": 20,
			"opacity": 1,
			"visible": true,
			"data": [
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,713,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,713,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,750,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,750,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,713,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,713,0,0,0,0,0,0,0,
				0,0,889,890,0,0,0,750,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,750,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,899,900,901,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,859,0,0,0,0,859,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
			]
		},
		{
			"id": 5,
			"name": "objects",
			"type": "objectgroup",
			"x": 0,
			"y": 0,
			"opacity": 1,
			"visible": true,
			"draworder": "topdown",
			"objects": [
				{
					"id": 1,
					"name": "",
					"type": "door",
					"x": 240,
					"y": 48,
					"width": 48,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "to",
							"type": "string",
							"value": "stairs"
						}
					]
				},
				{
					"id": 2,
					"name": "",
					"type": "door",
					"x": 0,
					"y": 144,
					"width": 16,
					"height": 32,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "to",
							"type": "string",
							"value": "car"
						}
					]
				},
				{
					"id": 3,
					"name": "",
					"type": "door",
					"x": 352,
					"y": 304,
					"width": 32,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "to",
							"type": "string",
							"value": "sewer"
						}
					]
				},
				{
					"id": 4,
					"name": "",
					"type": "arrive",
					"x": 256,
					"y": 64,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "from",
							"type": "string",
							"value": "stairs"
						},
						{
							"name": "facing",
							"type": "string",
							"value": "down"
						}
					]
				},
				{
					"id": 5,
					"name": "",
					"type": "arrive",
					"x": 16,
					"y": 144,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "from",
							"type": "string",
							"value": "car"
						},
						{
							"name": "facing",
							"type": "string",
							"value": "right"
						}
					]
				},
				{
					"id": 6,
					"name": "",
					"type": "arrive",
					"x": 352,
					"y": 288,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "from",
							"type": "string",
							"value": "sewer"
						},
						{
							"name": "facing",
							"type": "string",
							"value": "up"
						}
					]
				},
				{
					"id": 7,
					"name": "",
					"type": "search",
					"x": 512,
					"y": 288,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": []
				},
				{
					"id": 8,
					"name": "",
					"type": "npc_spot",
					"x": 192,
					"y": 128,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "order",
							"type": "int",
							"value": 0
						}
					]
				},
				{
					"id": 9,
					"name": "",
					"type": "npc_spot",
					"x": 224,
					"y": 128,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "order",
							"type": "int",
							"value": 1
						}
					]
				},
				{
					"id": 10,
					"name": "",
					"type": "npc_spot",
					"x": 288,
					"y": 128,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "order",
							"type": "int",
							"value": 2
						}
					]
				},
				{
					"id": 11,
					"name": "",
					"type": "npc_spot",
					"x": 320,
					"y": 128,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "order",
							"type": "int",
							"value": 3
						}
					]
				},
				{
					"id": 12,
					"name": "",
					"type": "npc_spot",
					"x": 192,
					"y": 192,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "order",
							"type": "int",
							"value": 4
						}
					]
				},
				{
					"id": 13,
					"name": "",
					"type": "npc_spot",
					"x": 320,
					"y": 192,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "order",
							"type": "int",
							"value": 5
						}
					]
				},
				{
					"id": 14,
					"name": "",
					"type": "npc_spot",
					"x": 256,
					"y": 192,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "order",
							"type": "int",
							"value": 6
						}
					]
				},
				{
					"id": 15,
					"name": "",
					"type": "npc_spot",
					"x": 256,
					"y": 208,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "order",
							"type": "int",
							"value": 7
						}
					]
				},
				{
					"id": 16,
					"name": "",
					"type": "light",
					"x": 128,
					"y": 112,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#ffe8f0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 7.0
						},
						{
							"name": "energy",
							"type": "float",
							"value": 0.45
						}
					]
				},
				{
					"id": 17,
					"name": "",
					"type": "light",
					"x": 400,
					"y": 112,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#ffe8f0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 7.0
						},
						{
							"name": "energy",
							"type": "float",
							"value": 0.45
						}
					]
				},
				{
					"id": 18,
					"name": "",
					"type": "light",
					"x": 128,
					"y": 240,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#ffe8f0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 7.0
						},
						{
							"name": "energy",
							"type": "float",
							"value": 0.45
						}
					]
				},
				{
					"id": 19,
					"name": "",
					"type": "light",
					"x": 400,
					"y": 240,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#ffe8f0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 7.0
						},
						{
							"name": "energy",
							"type": "float",
							"value": 0.45
						},
						{
							"name": "flicker",
							"type": "bool",
							"value": true
						}
					]
				},
				{
					"id": 20,
					"name": "",
					"type": "light",
					"x": 256,
					"y": 144,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#ff7fd0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 3.0
						},
						{
							"name": "energy",
							"type": "float",
							"value": 0.5
						}
					]
				},
				{
					"id": 21,
					"name": "",
					"type": "glow",
					"x": 112,
					"y": 64,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#aa7fd0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 1.0
						}
					]
				},
				{
					"id": 22,
					"name": "",
					"type": "glow",
					"x": 416,
					"y": 64,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#aa7fd0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 1.0
						}
					]
				},
				{
					"id": 23,
					"name": "",
					"type": "glow",
					"x": 112,
					"y": 208,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#aa7fd0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 1.0
						}
					]
				},
				{
					"id": 24,
					"name": "",
					"type": "glow",
					"x": 416,
					"y": 208,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#aa7fd0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 1.0
						}
					]
				},
				{
					"id": 25,
					"name": "",
					"type": "glow",
					"x": 480,
					"y": 64,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#777fffa0"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 1.2
						}
					]
				},
				{
					"id": 26,
					"name": "",
					"type": "glow",
					"x": 496,
					"y": 64,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#777fffa0"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 1.2
						}
					]
				},
				{
					"id": 27,
					"name": "",
					"type": "glow",
					"x": 480,
					"y": 224,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#777fffa0"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 1.2
						}
					]
				},
				{
					"id": 28,
					"name": "",
					"type": "glow",
					"x": 496,
					"y": 224,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#777fffa0"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 1.2
						}
					]
				}
			]
		}
	],
	"nextlayerid": 6,
	"nextobjectid": 29
}
```

- [ ] **Step 11：创建 `game/tools/palette_map.py`**

```python
#!/usr/bin/env python3
"""把一张带透明的像素图映射到共用调色板（设计 2026-11-10 第 3 节：图块和 Codex 的图都走同一个确定性的映射）。
不缩放、不抖动、不改透明度：每个不透明像素换成调色板里 RGB 距离最近的颜色（和 pixelize_scene.py 用的是同一个最近色规则）。
用法：python -I -X utf8 game/tools/palette_map.py <输入.png> <输出.png> --palette game/art/pixel_test/palette.hex --report <报告.json>
"""

import argparse
import hashlib
import importlib.util
import json
from collections import Counter
from pathlib import Path

from PIL import Image

# 用 pixelize_scene.py 里的调色板读取和距离函数（-I 模式下脚本目录不在 sys.path 里，按文件路径载入）。
_spec = importlib.util.spec_from_file_location("pixelize_scene", Path(__file__).with_name("pixelize_scene.py"))
_ps = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_ps)
load_palette = _ps.load_palette
squared_distance = _ps.squared_distance


def map_to_palette(image: Image.Image, palette: list[tuple[int, int, int]]) -> Image.Image:
	result = image.convert("RGBA")
	px = result.load()
	cache = {}
	for y in range(result.height):
		for x in range(result.width):
			r, g, b, a = px[x, y]
			if a == 0:
				continue
			color = (r, g, b)
			if color not in cache:
				cache[color] = min(palette, key=lambda target: squared_distance(color, target))
			px[x, y] = cache[color] + (a,)
	return result


def sha256(path: Path) -> str:
	return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument("input", type=Path)
	parser.add_argument("output", type=Path)
	parser.add_argument("--palette", required=True, type=Path)
	parser.add_argument("--report", required=True, type=Path)
	args = parser.parse_args()
	palette = load_palette(args.palette)
	with Image.open(args.input) as opened:
		source = opened.convert("RGBA")
	result = map_to_palette(source, palette)
	args.output.parent.mkdir(parents=True, exist_ok=True)
	result.save(args.output, format="PNG")
	with Image.open(args.output) as saved:
		rgba = saved.convert("RGBA")
		used = Counter(p[:3] for p in rgba.get_flattened_data() if p[3] > 0)
		foreign = sorted(set(used) - set(palette))
		report = {
			"kind": "palette-map-report",
			"source": args.input.as_posix(),
			"source_sha256": sha256(args.input),
			"output": args.output.as_posix(),
			"output_sha256": sha256(args.output),
			"size": list(saved.size),
			"palette": args.palette.as_posix(),
			"palette_sha256": sha256(args.palette),
			"used_color_count": len(used),
			"foreign_colors": ["#%02X%02X%02X" % c for c in foreign],
			"size_preserved": saved.size == source.size,
			"method": "Nearest shared palette color by squared RGB distance (pixelize_scene.squared_distance) for every pixel with alpha > 0; alpha, size and transparent pixels unchanged; no dithering.",
			"passed": saved.size == source.size and not foreign,
		}
	args.report.parent.mkdir(parents=True, exist_ok=True)
	args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
	print(args.output.name, "colors", len(used), "passed", report["passed"])
	if not report["passed"]:
		raise SystemExit(1)


if __name__ == "__main__":
	main()
```

- [ ] **Step 12：把实验室三张图块图映射到共用调色板（本机图片，报告进仓库）**

```bash
for s in tilesFloor tilesWalls tilesStuff; do python -I -X utf8 game/tools/palette_map.py "_work/sample_room/dl_lab/x/tiles_laboratory_LandOfPixels/16px/$s.png" "game/art/tiles/lab/$s.png" --palette game/art/pixel_test/palette.hex --report "art_src/tiles/lab/$s.report.json"; done
```

预期：三行 `… passed True`（颜色数 10、21、25）。

- [ ] **Step 13：运行，确认通过**

Run: `bash game/tools/run_tests.sh > _work/p22b_task1.txt 2>&1; echo "exit=$?"; tail -1 _work/p22b_task1.txt; echo "SCRIPT ERROR: $(grep -c 'SCRIPT ERROR' _work/p22b_task1.txt)"`

预期：`共 479 个测试，失败 0 个`（致谢页的测试在 Task 2）、`SCRIPT ERROR: 0`。

- [ ] **Step 14：提交**

```bash
git add game/ui/field/tiled_map.gd game/ui/field/field_tiles.gd game/tools/palette_map.py game/data/maps/tilesets game/data/maps/biohazard1/hall.tmj game/tests/fixtures/maps/tilesets/b.tsj game/tests/unit/ui/test_field.gd game/tests/unit/ui/test_tiled_map.gd art_src/tiles/lab
git commit -m "feat(field): 样板房间定稿：蜂巢入口大厅换成免费实验室图块（共用调色板），图块集属性当默认值，加调色板映射工具" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

## Task 2：致谢页、来源记录、素材清单

**Files:**
- Create: `game/data/credits.json`、`art_src/tiles/LICENSES.md`、`art_src/manifest/field.json`
- Modify: `game/ui/title_screen.gd`、`game/tests/unit/ui/test_title.gd`

- [ ] **Step 1：写测试 `game/tests/unit/ui/test_title.gd`**

```gdscript
extends "res://tests/test_case.gd"
## 标题画面与暂停菜单：信号、槽位列表、空槽不可读、设置切换、致谢页。

const TitleScreen = preload("res://ui/title_screen.gd")
const PauseMenu = preload("res://ui/pause_menu.gd")
const Slots = preload("res://core/save/slots.gd")
const Session = preload("res://core/session/session.gd")


func before_each() -> void:
	for i in range(1, Slots.COUNT + 1):
		Slots.erase(i)


func _title() -> Control:
	var t := TitleScreen.new()
	t.build()
	t.set_settings({"window_mode": "windowed", "volume": 0.8})
	return t


## 致谢页：列出第三方素材的作者、许可和出处；Esc 关掉。
func test_credits_panel() -> void:
	var t := _title()
	assert_false(t.credits_panel.visible)
	t.open_credits()
	assert_true(t.credits_panel.visible)
	assert_true(t.credits_label.text.contains("marceles"), "实验室图块的作者")
	assert_true(t.credits_label.text.contains("CC BY 4.0"))
	assert_true(t.credits_label.text.contains("opengameart.org"))
	assert_true(TitleScreen.credit_entries().size() >= 1)
	assert_true(t.handle_escape(), "Esc 关掉致谢页")
	assert_false(t.credits_panel.visible)
	t.free()


func test_title_lists_three_slots() -> void:
	var t := _title()
	t.open_slots()
	assert_eq((t.slot_rows() as Array).size(), 3)
	assert_eq(t.slot_box.get_child_count(), 3, "三个槽各一行")
	t.free()


func test_empty_slot_does_not_load() -> void:
	var t := _title()
	var loaded: Array = []
	t.load_slot.connect(func(slot: int) -> void: loaded.append(slot))
	t.press_slot(1)
	assert_eq(loaded.size(), 0, "空槽点了不读档")
	t.free()


func test_filled_slot_emits() -> void:
	var s := Session.new()
	s.start_m1(1)
	Slots.write(2, s)
	var t := _title()
	var loaded: Array = []
	t.load_slot.connect(func(slot: int) -> void: loaded.append(slot))
	t.press_slot(2)
	assert_eq(loaded.size(), 1)
	assert_eq(int(loaded[0]), 2)
	t.free()


## 新游戏先弹出存档方式；选了才发信号，带着是不是铁人模式。Esc 先关这个面板。
func test_new_game_and_quit_signals() -> void:
	var t := _title()
	var events: Array = []
	t.new_game.connect(func(iron: bool) -> void: events.append("new:%s" % iron))
	t.quit_game.connect(func() -> void: events.append("quit"))
	t.press_new()
	assert_true(t.mode_panel.visible)
	assert_eq(events, [])
	assert_true(t.handle_escape())
	assert_false(t.mode_panel.visible)
	t.press_new()
	t.press_mode(true)
	assert_false(t.mode_panel.visible)
	t.press_quit()
	assert_eq(events, ["new:true", "quit"])
	t.free()


func test_settings_toggle_and_volume() -> void:
	var t := _title()
	assert_eq(String(t.mode_button.text), "窗口")
	t.toggle_mode()
	assert_eq(String(t.mode_button.text), "全屏")
	assert_eq(String(t.settings["window_mode"]), "fullscreen")
	t.volume_down()
	assert_almost(float(t.settings["volume"]), 0.7)
	assert_true(String(t.volume_label.text).contains("70"), String(t.volume_label.text))
	t.free()


func test_escape_closes_overlay_first() -> void:
	var t := _title()
	t.open_settings()
	assert_true(t.handle_escape(), "设置开着时 Esc 先关设置")
	assert_false(t.settings_panel.visible)
	assert_false(t.handle_escape(), "都关了就交回上一层")
	t.free()


func test_pause_saves_to_slot_and_reloads() -> void:
	var p := PauseMenu.new()
	p.build()
	p.open_for("")
	var saved: Array = []
	var loaded: Array = []
	p.save_slot.connect(func(slot: int) -> void: saved.append(slot))
	p.load_slot.connect(func(slot: int) -> void: loaded.append(slot))
	p.press_save(2)
	assert_eq(saved, [2])
	p.press_load(1)
	assert_eq(loaded.size(), 0, "空槽不可读")

	var s := Session.new()
	s.start_m1(1)
	Slots.write(1, s)
	p.refresh()
	p.press_load(1)
	assert_eq(loaded, [1])
	p.free()


## 铁人模式的暂停菜单：存读档整块藏起来，按了也不发信号。
func test_pause_iron_man_hides_slots() -> void:
	var p := PauseMenu.new()
	p.build()
	p.set_iron_man(true)
	p.open_for("")
	assert_true(p.iron_label.visible)
	assert_false(p.save_buttons[0].get_parent().visible)
	var saved: Array = []
	p.save_slot.connect(func(slot: int) -> void: saved.append(slot))
	p.press_save(1)
	assert_eq(saved, [])
	p.set_iron_man(false)
	assert_false(p.iron_label.visible)
	p.press_save(1)
	assert_eq(saved, [1])
	p.free()
```

- [ ] **Step 2：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_title bash game/tools/run_tests.sh | tail -3`

预期：`test_credits_panel` 失败或报 `SCRIPT ERROR`（还没有致谢页）。

- [ ] **Step 3：创建 `game/data/credits.json`**

```json
{
	"credits": [
		{
			"what": "实验室图块、研究员和防护服行走图（Land of pixels — Laboratory tileset）",
			"who": "marceles",
			"license": "CC BY 4.0",
			"url": "https://opengameart.org/content/laboratory-tileset-pixelart-16px"
		},
		{
			"what": "游戏引擎（Godot Engine）",
			"who": "Godot Engine 贡献者",
			"license": "MIT",
			"url": "https://godotengine.org/license"
		}
	]
}
```

- [ ] **Step 4：改写 `game/ui/title_screen.gd`**

```gdscript
extends Control
## PC 版标题画面：新游戏（先选铁人或宽松）/ 继续（三个存档槽）/ 设置 / 致谢 / 退出。
## 致谢页列出用到的第三方素材和它们要求的署名（data/credits.json）。
## 只发信号，不碰 Session；开新游戏、读档、退出的实做在 main.gd。

## iron_man：铁人模式（一个自动存档，不能手动存读，全灭删档）。
signal new_game(iron_man: bool)
signal load_slot(slot: int)
signal quit_game
signal settings_changed(settings: Dictionary)

const UiTheme = preload("res://ui/ui_theme.gd")
const Slots = preload("res://core/save/slots.gd")
const Settings = preload("res://core/settings/settings.gd")
const DataLoader = preload("res://core/util/data_loader.gd")
const CREDITS := "res://data/credits.json"

const VERSION_TEXT := "v0.1.0 · 计划 10"

var menu_box: VBoxContainer
var slot_panel: Control
var slot_box: VBoxContainer
var settings_panel: Control
var mode_panel: Control
var credits_panel: Control
var credits_label: RichTextLabel
var mode_button: Button
var volume_label: Label
var hint_label: Label
var settings: Dictionary = Settings.defaults()
var _built := false


func _ready() -> void:
	build()


## 幂等：界面里 _ready 调一次，测试里直接调。
func build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.paint_bg(self)

	var title := UiTheme.label(tr("无限恐怖"), 84, UiTheme.ACCENT2)
	title.position = Vector2(0, 200)
	title.size = Vector2(1920, 110)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var sub := UiTheme.label(tr("2D 回合制同人游戏 · 第一阶段《生化危机一》"), 22, UiTheme.MUTED)
	sub.position = Vector2(0, 312)
	sub.size = Vector2(1920, 34)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	var rule := ColorRect.new()
	rule.color = UiTheme.LINE
	rule.position = Vector2(830, 372)
	rule.size = Vector2(260, 2)
	add_child(rule)

	menu_box = VBoxContainer.new()
	menu_box.position = Vector2(730, 420)
	menu_box.size = Vector2(460, 384)
	menu_box.add_theme_constant_override("separation", 16)
	add_child(menu_box)

	_add_menu("新游戏", press_new)
	_add_menu("继续游戏", open_slots)
	_add_menu("设置", open_settings)
	_add_menu("致谢", open_credits)
	_add_menu("退出游戏", press_quit)

	var ver := UiTheme.label(VERSION_TEXT, 16, UiTheme.MUTED)
	ver.position = Vector2(60, 1012)
	ver.size = Vector2(600, 24)
	add_child(ver)

	hint_label = UiTheme.label(tr(""), 16, UiTheme.MUTED)
	hint_label.position = Vector2(1260, 1012)
	hint_label.size = Vector2(600, 24)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(hint_label)

	_build_slots()
	_build_settings()
	_build_mode()
	_build_credits()
	set_hint("Enter 确认 · Esc 返回")


func _add_menu(text: String, handler: Callable) -> Button:
	var b := UiTheme.button(text, 24)
	b.custom_minimum_size = Vector2(460, 64)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(handler)
	menu_box.add_child(b)
	return b


func _build_slots() -> void:
	slot_panel = _overlay(900, 560)
	var box := VBoxContainer.new()
	box.position = Vector2(30, 24)
	box.size = Vector2(840, 500)
	box.add_theme_constant_override("separation", 12)
	_body(slot_panel).add_child(box)
	box.add_child(UiTheme.label(tr("选择存档"), 28, UiTheme.ACCENT2))
	slot_box = VBoxContainer.new()
	slot_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot_box.add_theme_constant_override("separation", 10)
	box.add_child(slot_box)
	var back := UiTheme.button(tr("返回"), 20)
	back.custom_minimum_size = Vector2(140, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(close_slots)
	box.add_child(back)


## 新游戏先选存档方式（设计规格 7.7：推荐铁人模式，另给想体验剧情的人一个宽松选项）。
func _build_mode() -> void:
	mode_panel = _overlay(900, 420)
	var box := VBoxContainer.new()
	box.position = Vector2(30, 24)
	box.size = Vector2(840, 360)
	box.add_theme_constant_override("separation", 14)
	_body(mode_panel).add_child(box)
	box.add_child(UiTheme.label(tr("选择存档方式"), 28, UiTheme.ACCENT2))
	var iron := UiTheme.button(tr("铁人模式（推荐）：只有一个自动存档，不能读档重来，全员死亡就删档"), 20)
	iron.custom_minimum_size = Vector2(840, 64)
	iron.pressed.connect(press_mode.bind(true))
	box.add_child(iron)
	var loose := UiTheme.button(tr("宽松模式：三个手动存档槽，随时存读，想看剧情选这个"), 20)
	loose.custom_minimum_size = Vector2(840, 64)
	loose.pressed.connect(press_mode.bind(false))
	box.add_child(loose)
	var back := UiTheme.button(tr("返回"), 20)
	back.custom_minimum_size = Vector2(140, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(close_mode)
	box.add_child(back)


func _build_settings() -> void:
	settings_panel = _overlay(760, 300)
	var box := VBoxContainer.new()
	box.position = Vector2(30, 24)
	box.size = Vector2(700, 360)
	box.add_theme_constant_override("separation", 16)
	_body(settings_panel).add_child(box)
	box.add_child(UiTheme.label(tr("设置"), 28, UiTheme.ACCENT2))

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 12)
	var mode_name := UiTheme.label(tr("窗口"), 20)
	mode_name.custom_minimum_size = Vector2(110, 48)
	mode_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mode_row.add_child(mode_name)
	mode_button = UiTheme.button(tr(""), 20)
	mode_button.custom_minimum_size = Vector2(220, 48)
	mode_button.pressed.connect(toggle_mode)
	mode_row.add_child(mode_button)
	box.add_child(mode_row)

	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 12)
	var vol_name := UiTheme.label(tr("主音量"), 20)
	vol_name.custom_minimum_size = Vector2(110, 48)
	vol_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	vol_row.add_child(vol_name)
	var down := UiTheme.button(tr("−"), 20)
	down.custom_minimum_size = Vector2(64, 48)
	down.pressed.connect(volume_down)
	vol_row.add_child(down)
	volume_label = UiTheme.label(tr(""), 20, UiTheme.ACCENT2)
	volume_label.custom_minimum_size = Vector2(120, 48)
	volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vol_row.add_child(volume_label)
	var up := UiTheme.button(tr("+"), 20)
	up.custom_minimum_size = Vector2(64, 48)
	up.pressed.connect(volume_up)
	vol_row.add_child(up)
	box.add_child(vol_row)

	var back := UiTheme.button(tr("返回"), 20)
	back.custom_minimum_size = Vector2(140, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(close_settings)
	box.add_child(back)


func _build_credits() -> void:
	credits_panel = _overlay(1000, 560)
	var box := VBoxContainer.new()
	box.position = Vector2(30, 24)
	box.size = Vector2(940, 512)
	box.add_theme_constant_override("separation", 14)
	_body(credits_panel).add_child(box)
	box.add_child(UiTheme.label(tr("致谢"), 28, UiTheme.ACCENT2))
	credits_label = UiTheme.rich(18)
	credits_label.bbcode_enabled = true
	credits_label.custom_minimum_size = Vector2(940, 380)
	box.add_child(credits_label)
	var back := UiTheme.button(tr("返回"), 20)
	back.custom_minimum_size = Vector2(140, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(close_credits)
	box.add_child(back)


## 致谢的条目：[{what, who, license, url}]。
static func credit_entries() -> Array:
	var res := DataLoader.load_json(CREDITS)
	return (res.data as Dictionary).get("credits", []) if res.ok else []


func open_credits() -> void:
	var lines: Array[String] = []
	for c: Dictionary in credit_entries():
		lines.append("[color=#e8a33d]%s[/color]\n%s · %s\n[color=#aab2c0]%s[/color]" % [String(c.get("what", "")), String(c.get("who", "")), String(c.get("license", "")), String(c.get("url", ""))])
	credits_label.text = "\n\n".join(lines)
	credits_panel.visible = true
	set_hint("Esc 返回")


func close_credits() -> void:
	credits_panel.visible = false
	set_hint("Enter 确认 · Esc 返回")


func _overlay(w: int, h: int) -> Control:
	var mask := ColorRect.new()
	mask.color = Color(0, 0, 0, 0.62)
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_STOP
	mask.visible = false
	add_child(mask)
	var p := Panel.new()
	p.position = Vector2((1920.0 - w) / 2.0, (1080.0 - h) / 2.0)
	p.size = Vector2(w, h)
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PANEL, UiTheme.LINE, 10))
	mask.add_child(p)
	return mask


## 弹层里真正放内容的面板（遮罩的第一个子节点，居中）。
func _body(overlay: Control) -> Control:
	return overlay.get_child(0)


func set_hint(text: String) -> void:
	if hint_label != null:
		hint_label.text = text


## 设置由 main 传进来，标题画面只负责显示与修改。
func set_settings(s: Dictionary) -> void:
	settings = s.duplicate()
	_refresh_settings()


func _refresh_settings() -> void:
	if mode_button == null:
		return
	mode_button.text = "全屏" if String(settings.get("window_mode", "windowed")) == "fullscreen" else "窗口"
	volume_label.text = "%d%%" % roundi(float(settings.get("volume", 0.8)) * 100.0)


## ---- 供界面与验收脚本调用 ----

func press_new() -> void:
	mode_panel.visible = true
	set_hint("选择存档方式 · Esc 返回")


func press_mode(iron: bool) -> void:
	mode_panel.visible = false
	new_game.emit(iron)


func close_mode() -> void:
	mode_panel.visible = false
	set_hint("Enter 确认 · Esc 返回")


func press_quit() -> void:
	quit_game.emit()


func open_slots() -> void:
	_refresh_slots()
	slot_panel.visible = true
	set_hint("选择存档位 · Esc 返回")


func close_slots() -> void:
	slot_panel.visible = false
	set_hint("Enter 确认 · Esc 返回")


func open_settings() -> void:
	_refresh_settings()
	settings_panel.visible = true
	set_hint("设置窗口与音量 · Esc 返回")


func close_settings() -> void:
	settings_panel.visible = false
	set_hint("Enter 确认 · Esc 返回")


## 三个槽的摘要；标题画面每次打开都重读，存档后不用重启也能看到。
func slot_rows() -> Array[Dictionary]:
	return Slots.all_summaries()


func _refresh_slots() -> void:
	for c in slot_box.get_children():
		slot_box.remove_child(c)
		c.queue_free()
	# 自动存档放在最上面：换地点/战斗后自动落的盘，直接"继续"。
	var auto := Slots.summary(Slots.AUTO)
	if bool(auto["exists"]):
		_add_slot_row(auto, "自动存档（继续）")
	for row: Dictionary in slot_rows():
		_add_slot_row(row, "存档 %d" % int(row["slot"]))


func _add_slot_row(row: Dictionary, prefix: String) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	var text := "%s　%s" % [prefix, String(row["label"])]
	if bool(row["exists"]):
		text += "　%d 点　%s" % [int(row["points"]), String(row["saved_at"])]
	var l := UiTheme.label(text, 19, UiTheme.TEXT if bool(row["exists"]) else UiTheme.MUTED)
	l.custom_minimum_size = Vector2(600, 76)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(l)
	var b := UiTheme.button(tr("读取"), 19)
	b.custom_minimum_size = Vector2(140, 52)
	b.disabled = not bool(row["exists"])
	b.pressed.connect(press_slot.bind(int(row["slot"])))
	line.add_child(b)
	slot_box.add_child(line)


func press_slot(slot: int) -> void:
	var row: Dictionary = Slots.summary(slot)
	if not bool(row["exists"]):
		return
	close_slots()
	load_slot.emit(slot)


func toggle_mode() -> void:
	var next := "windowed" if String(settings.get("window_mode", "windowed")) == "fullscreen" else "fullscreen"
	settings = Settings.with_value(settings, "window_mode", next)
	_refresh_settings()
	settings_changed.emit(settings)


func volume_up() -> void:
	_bump_volume(0.1)


func volume_down() -> void:
	_bump_volume(-0.1)


func _bump_volume(delta: float) -> void:
	var v := clampf(snappedf(float(settings.get("volume", 0.8)) + delta, 0.1), 0.0, 1.0)
	settings = Settings.with_value(settings, "volume", v)
	_refresh_settings()
	settings_changed.emit(settings)


## Esc：先关覆盖层，都不开就什么都不做（标题画面不退出）。
func handle_escape() -> bool:
	if mode_panel != null and mode_panel.visible:
		close_mode()
		return true
	if slot_panel.visible:
		close_slots()
		return true
	if settings_panel.visible:
		close_settings()
		return true
	if credits_panel.visible:
		close_credits()
		return true
	return false
```

- [ ] **Step 5：创建 `art_src/tiles/LICENSES.md`**

```markdown
# 探索画面用的第三方素材：来源与许可

只用免费素材（用户 2026-11-10 决定）。"免费"不等于许可：每个包都在作者的原页面和包里自带的许可文件核对过。
图片不进仓库（多数许可也不允许转发原图），只在本机 `game/art/` 下；这里记来源、许可、署名和改动，照着可以重新做出同样的文件。

## 正在用的

### Land of pixels — Laboratory tileset（实验室图块）
- 作者：marceles（https://marceles.itch.io/）
- 出处：https://opengameart.org/content/laboratory-tileset-pixelart-16px （文件 `tiles_laboratory_landofpixels_0.zip`）
- 许可：**CC BY 4.0**（https://creativecommons.org/licenses/by/4.0/ ；包里的 `LICENSE.txt` 也写的是这个）。可以使用、修改，**要署名**。
- 署名：游戏标题画面的"致谢"页（`game/data/credits.json`）。
- 用在哪：`game/art/tiles/lab/tilesFloor.png`、`tilesWalls.png`、`tilesStuff.png`（包里 `16px/` 那三张），图块集描述 `game/data/maps/tilesets/lab_floor.tsj`、`lab_walls.tsj`、`lab_stuff.tsj`；第一张用它的地图是 `game/data/maps/biohazard1/hall.tmj`（样板房间：蜂巢入口大厅，用户 2026-11-11 选了"共用调色板"版）。
- 改动：每张都映射到共用 32 色调色板 `game/art/pixel_test/palette.hex`，不缩放、不抖动、不改透明度；工具 `game/tools/palette_map.py`，报告（含原图和成品的 SHA-256）在 `art_src/tiles/lab/*.report.json`。
- 重新做一遍：下载上面的 zip，解压出 `tiles_laboratory_LandOfPixels/16px/` 里的三张，在仓库根目录运行
  `python -I -X utf8 game/tools/palette_map.py <解压目录>/16px/tilesFloor.png game/art/tiles/lab/tilesFloor.png --palette game/art/pixel_test/palette.hex --report art_src/tiles/lab/tilesFloor.report.json`
  （`tilesWalls`、`tilesStuff` 同样各跑一次），对照报告里的 `output_sha256`。
- 同一页还有 `labnpcs.png`（两个研究员、一个防护服人物的四方向走路图，同样 CC BY 4.0）。现在本机把它们裁成我们的行走图格式，临时顶替还没画出来的轮回者和剧情人物（Codex 按任务卡 007 出正式行走图后替换）；只是本机占位，不算正式素材。

## 看过、暂时没用的

| 素材 | 作者 | 许可（原页面 / 包内文件） | 情况 |
|---|---|---|---|
| Interior Tileset 16x16（https://opengameart.org/content/interior-tileset-16x16） | Bonsaiheldin（http://bonsaiheld.org） | CC BY-SA 3.0，要署名 | 家居室内（木地板、地毯、床、窗、门），以后给郑吒的房间、回归现实那一章备用 |
| Colony sim assets（https://opengameart.org/content/colony-sim-assets） | Buch | CC0 | 科幻机械，备用 |
| Dread Rooms #1 — Abandoned Hospital, Free Version（https://pixlog.itch.io/dread-rooms） | PixLog | 包内 LICENSE：可用于自己的项目、可改、可随游戏发布；不能转发素材本身、不能拿去训练 AI；署名非必需。作者说明是 AI 辅助制作 | 免费版只够一间病房，没用 |
| Gridwright Haunted Asylum — Free Sample（https://gridwrightstudio.itch.io/horror-tileset-16x16-pixel-art-asylum-hospital-top-down） | Gridwright | 包内 LICENSE：可用于个人和商业项目、可改；不能转发素材本身、不能训练 AI；**要署名**"Art by Gridwright"并链接 https://gridwrightstudio.itch.io | 免费样本只够一间病房，没用；以后做医疗区或"破败"状态时可以拿病房墙、血迹、纸张 |

itch.io 的页面经网关 192.168.1.2 的 PassWall2（`DEV_TOOLS` 规则加了 `domain:itch.io`、`domain:itch.zone`）才能打开，2026-11-11。
```

- [ ] **Step 6：创建 `art_src/manifest/field.json`**

```json
{
  "schema_version": 1,
  "art_direction_brief": "docs/superpowers/specs/2026-11-10-film1-hub-remake-design.md#3-美术",
  "assets": [
    {
      "id": "lab-tilesFloor",
      "role": "lab floors (blue panels, grey tiles, hazard stripes, grates)",
      "path": "game/art/tiles/lab/tilesFloor.png",
      "status": "approved",
      "technical": {
        "dimensions": "176x288",
        "tile": "16x16",
        "alpha": true,
        "anchor": "grid",
        "frames": 1,
        "filtering": "nearest"
      },
      "visual_locks": [
        "palette",
        "3/4 top-down view",
        "16px grid",
        "outline style"
      ],
      "edits": "mapped to the shared 32-colour palette with game/tools/palette_map.py (report art_src/tiles/lab/tilesFloor.report.json)",
      "source": {
        "kind": "downloaded-free",
        "url_or_tool": "https://opengameart.org/content/laboratory-tileset-pixelart-16px",
        "creator": "marceles (Land of pixels)",
        "created_at": "2026-11-11",
        "license": "CC BY 4.0",
        "attribution": "Land of pixels — Laboratory tileset by marceles (CC BY 4.0), shown on the title screen credits page",
        "prompt_or_source_record": "art_src/tiles/LICENSES.md"
      },
      "verification": {
        "native_scale_reviewed": true,
        "in_engine_reviewed": true,
        "technical_checks_passed": true,
        "approved_by": "user, 2026-11-11 (sample room: shared palette version)"
      }
    },
    {
      "id": "lab-tilesWalls",
      "role": "lab walls (wall top, wall face, side walls, corners, end caps)",
      "path": "game/art/tiles/lab/tilesWalls.png",
      "status": "approved",
      "technical": {
        "dimensions": "192x256",
        "tile": "16x16",
        "alpha": true,
        "anchor": "grid",
        "frames": 1,
        "filtering": "nearest"
      },
      "visual_locks": [
        "palette",
        "3/4 top-down view",
        "16px grid",
        "outline style"
      ],
      "edits": "mapped to the shared 32-colour palette with game/tools/palette_map.py (report art_src/tiles/lab/tilesWalls.report.json)",
      "source": {
        "kind": "downloaded-free",
        "url_or_tool": "https://opengameart.org/content/laboratory-tileset-pixelart-16px",
        "creator": "marceles (Land of pixels)",
        "created_at": "2026-11-11",
        "license": "CC BY 4.0",
        "attribution": "Land of pixels — Laboratory tileset by marceles (CC BY 4.0), shown on the title screen credits page",
        "prompt_or_source_record": "art_src/tiles/LICENSES.md"
      },
      "verification": {
        "native_scale_reviewed": true,
        "in_engine_reviewed": true,
        "technical_checks_passed": true,
        "approved_by": "user, 2026-11-11 (sample room: shared palette version)"
      }
    },
    {
      "id": "lab-tilesStuff",
      "role": "lab objects (elevator door, consoles, screens, tanks, desks, shelves, lamps, benches)",
      "path": "game/art/tiles/lab/tilesStuff.png",
      "status": "approved",
      "technical": {
        "dimensions": "592x256",
        "tile": "16x16",
        "alpha": true,
        "anchor": "grid",
        "frames": 1,
        "filtering": "nearest"
      },
      "visual_locks": [
        "palette",
        "3/4 top-down view",
        "16px grid",
        "outline style"
      ],
      "edits": "mapped to the shared 32-colour palette with game/tools/palette_map.py (report art_src/tiles/lab/tilesStuff.report.json)",
      "source": {
        "kind": "downloaded-free",
        "url_or_tool": "https://opengameart.org/content/laboratory-tileset-pixelart-16px",
        "creator": "marceles (Land of pixels)",
        "created_at": "2026-11-11",
        "license": "CC BY 4.0",
        "attribution": "Land of pixels — Laboratory tileset by marceles (CC BY 4.0), shown on the title screen credits page",
        "prompt_or_source_record": "art_src/tiles/LICENSES.md"
      },
      "verification": {
        "native_scale_reviewed": true,
        "in_engine_reviewed": true,
        "technical_checks_passed": true,
        "approved_by": "user, 2026-11-11 (sample room: shared palette version)"
      }
    }
  ]
}
```

- [ ] **Step 7：运行，确认通过**

Run: `bash game/tools/run_tests.sh > _work/p22b_task2.txt 2>&1; echo "exit=$?"; tail -1 _work/p22b_task2.txt; echo "SCRIPT ERROR: $(grep -c 'SCRIPT ERROR' _work/p22b_task2.txt)"`

预期：`共 480 个测试，失败 0 个`、`SCRIPT ERROR: 0`。

- [ ] **Step 8：提交**

```bash
git add game/data/credits.json game/ui/title_screen.gd game/tests/unit/ui/test_title.gd art_src/tiles/LICENSES.md art_src/manifest/field.json
git commit -m "feat(title): 致谢页；记录实验室图块的来源、许可和改动，建素材清单" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 3：验收

- [ ] **Step 1：本机装上临时替身行走图（不进仓库）**

Run: `mkdir -p game/art/field/walkers && cp _work/sample_room/v_pal/game/art/field/walkers/*.png game/art/field/walkers/ && ls game/art/field/walkers | wc -l && git status --short`

预期：`15`；`git status --short` 只剩 `?? _work/`（图片被 `.gitignore` 忽略）。

- [ ] **Step 2：在改名的副本里跑切片验收**

```bash
rm -rf _work/p22b_verify && mkdir -p _work/p22b_verify && cp -r game _work/p22b_verify/game
sed -i 's/^config\/name=.*/config\/name="无限恐怖_验收p22b"/' _work/p22b_verify/game/project.godot
timeout 300 godot --headless --path _work/p22b_verify/game -s res://tools/verify_m1_slice.gd 2>&1 | tail -1; echo "exit=${PIPESTATUS[0]}"
```

预期：`M1 切片验证：失败 0 项`，`exit=0`。

- [ ] **Step 3：窗口模式截图看一遍**

Run: `rm -f art_src/qa/field_*.png; timeout 180 godot --path game -s res://tools/field_capture.gd 2>&1 | tail -1`

预期：`共截图 9`；`art_src/qa/field_03_hall.png` 是实验室图块的大厅（共用调色板的冷色调），雇佣兵站在接待台周围，队伍在西门边。

- [ ] **Step 4：更新 README 进度并提交**

```bash
python -I -X utf8 - <<'EOF'
p = "README.md"
s = open(p, encoding="utf-8").read()
o = "- 制作节奏：按原著顺序"
n = "- 计划 22 续（样板房间定稿：蜂巢入口大厅换成免费的 Land of pixels 实验室图块（CC BY 4.0，映射到共用 32 色调色板），比一屏大、镜头会动；标题画面加致谢页；素材来源和许可记在 art_src/tiles/LICENSES.md）已完成，累计 480 个无界面测试。\n" + o
assert s.count(o) == 1
open(p, "w", encoding="utf-8", newline="\n").write(s.replace(o, n))
print("ok")
EOF
git add README.md
git commit -m "docs: 计划 22 续完成，更新进度" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log --oneline -4
git status --short
```

- [ ] **Step 5：验收检查**

```bash
grep -c $'\r' game/ui/field/tiled_map.gd game/ui/title_screen.gd game/data/maps/biohazard1/hall.tmj art_src/tiles/LICENSES.md
for f in ui/field/tiled_map.gd ui/field/field_tiles.gd ui/title_screen.gd tools/palette_map.py data/credits.json data/maps/tilesets/lab_floor.tsj data/maps/tilesets/lab_walls.tsj data/maps/tilesets/lab_stuff.tsj data/maps/biohazard1/hall.tmj tests/fixtures/maps/tilesets/b.tsj tests/unit/ui/test_field.gd tests/unit/ui/test_tiled_map.gd tests/unit/ui/test_title.gd art/tiles/lab/tilesFloor.png art/tiles/lab/tilesWalls.png art/tiles/lab/tilesStuff.png; do cmp -s "game/$f" "_work/plan_check_p22b/game/$f" || echo "DIFF $f"; done
for f in art_src/tiles/LICENSES.md art_src/manifest/field.json; do cmp -s "$f" "_work/plan_check_p22b/$f" || echo "DIFF $f"; done
echo "compare done"
test -z "$(git diff --name-only origin/main..HEAD | grep -iE '\.(png|jpe?g|webp|gif|wav|ogg)$')" && echo "no media"
```

预期：四个 `grep -c` 都是 `0`；`compare done` 前没有 `DIFF`（三张图块图在本机，和临时目录的逐字节相同）；`no media`。
