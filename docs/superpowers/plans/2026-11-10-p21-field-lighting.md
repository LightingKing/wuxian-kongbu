# 计划 21：探索画面的光照、正式图接口与对话框 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用户看了计划 20 的可行走场景说"会不会太简陋，你都达不到 08 年的水平吗"。差距主要在两处：一是地图和小人还是代码画的占位方块（08 年的 RPG Maker 同人游戏用的是美术画好的图块）；二是画面没有氛围（没有光、没有影子，对话框也简陋）。本计划先把引擎这一侧做到位：每个地点有环境光和灯，黑暗地点只剩手电筒的光锥；人物脚下有影子；对话框改成视觉小说式（大立绘站在左边、一个字一个字打出来）；左上、右上的信息收紧；面前能互动的东西头顶有提示；进新地点时地名淡入淡出；队友一进场就站在主角身后。同时把正式图的接口接好（Codex 画的整张地图、四方向行走图放进来就自动替换占位），给 Codex 准备版式图、对位图和截图工具，并写好任务卡 007。规则层一行不改。

**Architecture:**
- `data/maps/biohazard1.json`：每张图加 `ambient`（环境光颜色）、`lights`（点光：位置、颜色、半径、亮度、是否闪烁）、`glows`（自发光小光晕：激光发射器、屏幕、指示灯）。
- `ui/field/field_map.gd`：加墙面判断 `wall_face()`（墙下面是屋里就画出墙的高度）、灯光取值；校验灯的位置、颜色、数量（兼容渲染器里一个物体最多受 8 盏灯影响，一张图最多 5 盏，给手电筒和火焰女皇留位置）。
- `ui/field/field_art.gd`：先找 `res://art/field/maps/<地点>.png`（480×256 整张俯视像素图，RPG Maker 的"远景图"画法）和 `res://art/field/walkers/<id>.png`（4×4 行走图，行是朝向、列是走路四帧），找不到再用占位；新增径向灯光贴图、手电筒光锥、脚下影子。
- `ui/field/field_screen.gd`：像素层里加 `CanvasModulate`（环境光）、`PointLight2D`（灯、手电筒、火焰女皇的红光）、单独一层的自发光光晕（不被环境光压暗）；行走小人按脚底中点对齐（任意帧尺寸都能放）；对话框、提示、地名横幅、队友站位。
- `ui/field/field_guide.gd` + `tools/field_guides.gd`：版式图（一格一色，照着画）、对位图（画好的图放大 4 倍盖上碰撞颜色）、行走图尺寸检查。
- `tools/field_capture.gd`：开场对话框和八个地点各截一张图（Codex 验收和我们自己看图都用它）。
- `docs/codex-tasks/007-m1-field-art.md`：正式图任务卡（8 张地图 + 15 套行走图，分三批，只用 codex 渠道）。

**Tech Stack:** Godot 4.7.2（SubViewport、CanvasModulate、PointLight2D、CanvasLayer、AtlasTexture、Tween）。

**依据：** 用户反馈（2026-11-10："会不会太简陋，你都达不到08年的水平吗"）；设计规格 11（像素画面、黑暗靠光照）；任务卡 003 的像素流程（已经证明 codex 渠道能出 08 年水平以上的像素场景图）。

**本计划已在临时目录跑通：472 个无界面测试全过、`SCRIPT ERROR 0`、M1 切片验收 0 失败；窗口模式截图确认八个地点的灯光、黑暗地点的手电筒光锥、火焰女皇的红光、视觉小说式对话框和互动提示按预期显示。**

**执行环境注意：**
- 仓库根目录：`I:\workspace\mobilegame\wuxian-kongbu\`；命令都在仓库根目录执行（Git Bash）。
- 文本文件 **LF**、UTF-8 无 BOM；GDScript 用 **Tab**。
- 跑测试不生成 `.gd.uid`，导入工程（Task 2）才会。
- **只提交，不推送。**
- 临时验证目录是 `_work/plan_check_p21/game`。
- **切片验收会用到存档槽**，开头备份、结束放回（计划 19 起）。

---

## 设计要点

- **光**：每个地点一个环境光颜色压暗画面，再按地图打几盏点光（车厢吸顶灯、大厅吊灯、走廊灯管、主机房的青色屏幕光），个别灯会闪。像素层是 480×256，光的渐变也按这个分辨率算，放大 4 倍后是像素风的光斑。
- **黑暗**：楼梯井、冷冻仓库、下水道（以及断电后）环境光几乎全黑，主角手里的手电筒按朝向照出一道光锥，身边有一圈微光。旧的整屏遮罩去掉。
- **自发光光晕**：激光发射器的红灯、机柜屏幕、指示灯放在单独的画布层，不被环境光压暗，黑暗里也看得见。
- **影子**：每个人脚下一个半透明椭圆；火焰女皇是全息投影，没有影子，自带一盏闪烁的红光。
- **正式图接口**：整张地图 480×256（碰撞还是按字符格子）；行走图 128×128、4×4、单帧 32×32，行是下、左、右、上，列是站立、迈步、站立、迈步。行走小人按脚底中点对齐，所以占位小人（16×24）和正式行走图（32×32）都能直接放。没有正式图时，占位图块的墙下面是屋里就画成看得到高度的墙面。
- **对话框**：底部整条，说话的人有立绘时，立绘站在左边、下半身藏在对话框后面；台词一个字一个字打出来，确认键先显示完这一句、再按才到下一句；旁白没有立绘。
- **信息收紧**：左上角只写地点、时间、任务（有击杀才写击杀）；右上角队伍名单收窄，血量按比例变色，有恐惧、感染才写。
- **互动提示**：面前是柜子、人、门时，在它头顶提示"Enter 调查""Enter 说话：某某""前往：某地"。
- **队友站位**：一进场就站在主角身后（身后没地方就站两边，不站正前方），第一步以后排成一路跟着走；换屏回来站回原位。
- **给 Codex 的工具**：版式图让生成的地图和碰撞格子对得上；对位图一眼看出哪里对不上；截图工具看放进游戏的效果。

**不在本计划范围**：正式地图和行走图本身（任务卡 007，Codex 出）；主神空间可行走化（下一个计划）；地图上看得见的敌人；剧情人物沿路走动的动画；光照遮挡（墙挡光）。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `game/data/maps/biohazard1.json` | 每张图加环境光、灯、自发光光晕 |
| `game/ui/field/field_map.gd` | 墙面判断、灯光取值、灯光校验 |
| `game/ui/field/field_art.gd` | 正式图优先（整张地图、4×4 行走图），占位图块带墙面；灯光、光锥、影子贴图 |
| `game/ui/field/field_guide.gd` | 版式图、对位图、行走图检查 |
| `game/ui/field/field_screen.gd` | 光照、影子、对话框、提示、地名横幅、队友站位 |
| `game/tools/field_guides.gd` | 导出版式图和对位图、检查正式图（Codex 用） |
| `game/tools/field_capture.gd` | 探索画面截图（Codex 和验收都用） |
| `game/tests/unit/ui/test_field.gd` | 加灯光、正式图、站位与提示、打字、版式图的测试 |
| `docs/codex-tasks/007-m1-field-art.md` | 任务卡：8 张地图 + 15 套行走图 |

---

## Task 1：光照、正式图接口、对话框

**Files:**
- Create: `game/ui/field/field_guide.gd`、`game/tools/field_guides.gd`、`game/tools/field_capture.gd`
- Modify: `game/data/maps/biohazard1.json`、`game/ui/field/field_map.gd`、`game/ui/field/field_art.gd`、`game/ui/field/field_screen.gd`、`game/tests/unit/ui/test_field.gd`

- [ ] **Step 1：写测试 `game/tests/unit/ui/test_field.gd`**

```gdscript
extends "res://tests/test_case.gd"
## RPG 式探索：地图数据、门与入口、寻路；场景里台词进对话框、选择弹窗口、走动、进门、搜索、说话、黑暗；
## 灯光、正式图（整张地图、行走图）、队友站位、互动提示、打字效果、给 Codex 的版式图和对位图。

const FieldMap = preload("res://ui/field/field_map.gd")
const FieldScreen = preload("res://ui/field/field_screen.gd")
const FieldArt = preload("res://ui/field/field_art.gd")
const FieldGuide = preload("res://ui/field/field_guide.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const Session = preload("res://core/session/session.gd")

const MAPS := "res://data/maps/biohazard1.json"
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
	var errors := FieldMap.validate(MAPS, Scenario.load_file(SCENARIO))
	assert_eq(errors.size(), 0, "\n".join(errors))


## 门通向哪、从哪进来站哪；寻路绕开墙和挡路的人。
func test_doors_entries_and_path() -> void:
	var hall: RefCounted = FieldMap.make(MAPS, "hall")
	assert_eq(hall.door_dest(Vector2i(0, 7)), "car")
	assert_eq(hall.door_dest(Vector2i(14, 0)), "stairs")
	assert_eq(hall.door_dest(Vector2i(15, 15)), "sewer")
	assert_eq(hall.door_dest(Vector2i(5, 5)), "")
	assert_eq(hall.entry_cell("car"), Vector2i(1, 7))
	assert_eq(hall.entry_cell("stairs"), Vector2i(14, 1))
	var p: Array[Vector2i] = hall.path(Vector2i(1, 7), Vector2i(14, 1))
	assert_true(p.size() > 0)
	assert_eq(p[p.size() - 1], Vector2i(14, 1))
	for c in p:
		assert_true(hall.walkable(c))
	assert_eq(hall.path(Vector2i(1, 7), Vector2i(0, 0)).size(), 0, "墙走不到")
	var blocked := {Vector2i(2, 7): true}
	for c in hall.path(Vector2i(1, 7), Vector2i(3, 7), blocked):
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
	assert_eq(f.light_root.get_child_count(), 4, "大厅四盏吊灯")
	f.press_move("stairs")
	assert_true(f.dark.visible)
	assert_eq(f.canvas_mod.color, FieldScreen.DARK_AMBIENT, "黑暗地点只剩手电筒")
	f.free()
	var laser: RefCounted = FieldMap.make(MAPS, "laser")
	assert_eq((laser.glows() as Array).size(), 12, "两排激光发射器")
	var control: RefCounted = FieldMap.make(MAPS, "control")
	assert_true((control.lights() as Array).size() <= FieldMap.MAX_LIGHTS)


## 有 Codex 画的整张地图和行走图就用：地图盖掉占位图块，行走图按 4×4 切帧，脚底对齐格子。
func test_painted_map_and_walker_sheet() -> void:
	var dir := "user://test_field_art/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir + "maps"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir + "walkers"))
	var map_img := Image.create(480, 256, false, Image.FORMAT_RGBA8)
	map_img.fill(Color("30384a"))
	map_img.save_png(ProjectSettings.globalize_path(dir + "maps/car.png"))
	var sheet := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	sheet.fill_rect(Rect2i(8, 4, 16, 28), Color("3a4a78"))
	sheet.save_png(ProjectSettings.globalize_path(dir + "walkers/zheng_zha.png"))
	var old_root := FieldArt.art_root
	FieldArt.art_root = dir
	FieldArt.clear_cache()
	var f := _screen()
	assert_true(f.ground.visible, "画好的地图")
	assert_false(f.tiles.visible, "占位图块收起来")
	assert_eq(FieldArt.walker_size("zheng_zha"), Vector2i(32, 32))
	var down0 := FieldArt.walker("zheng_zha", "down", 0) as AtlasTexture
	assert_eq(down0.region, Rect2(0, 0, 32, 32))
	var up_step := FieldArt.walker("zheng_zha", "up", 2) as AtlasTexture
	assert_eq(up_step.region, Rect2(96, 96, 32, 32), "第 4 行（上）第 4 列（迈另一只脚）")
	assert_eq(f.player.offset, Vector2(-16, -32), "脚底中点对齐格子")
	assert_eq(FieldArt.walker_size("zhang_jie"), Vector2i(FieldArt.WALK_W, FieldArt.WALK_H), "没有行走图的还用占位小人")
	f.free()
	FieldArt.art_root = old_root
	FieldArt.clear_cache()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + "maps/car.png"))
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


## 给 Codex 的版式图和对位图：版式图一格一色、480×256；对位图放大 4 倍、挡路的格子盖红；行走图检查尺寸和透明。
func test_field_guide() -> void:
	var car: RefCounted = FieldMap.make(MAPS, "car")
	var g := FieldGuide.guide(car)
	assert_eq(g.get_size(), Vector2i(480, 256))
	assert_eq(g.get_pixel(8, 8), FieldGuide.COLORS["top"], "第 0 行是墙顶")
	assert_eq(g.get_pixel(29 * 16 + 8, 7 * 16 + 8), FieldGuide.COLORS["D"], "右边的门")
	assert_eq(g.get_pixel(1 * 16 + 8, 9 * 16 + 8), FieldGuide.COLORS["S"], "柜子")
	assert_eq(g.get_pixel(5 * 16 + 8, 3 * 16 + 8), FieldGuide.COLORS["face"], "座位上面那排墙看得到墙面")
	var painted := Image.create(480, 256, false, Image.FORMAT_RGBA8)
	painted.fill(Color(0.5, 0.5, 0.5))
	var o := FieldGuide.overlay(car, painted)
	assert_eq(o.get_size(), Vector2i(1920, 1024))
	var wall_px := o.get_pixel(32, 32)
	assert_true(wall_px.r > wall_px.g + 0.15, "墙格盖红")
	var floor_px := o.get_pixel(10 * 64 + 32, 7 * 64 + 32)
	assert_almost(floor_px.r, floor_px.g, 0.02, "地面不盖色")
	var ok_sheet := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	ok_sheet.fill(Color(0, 0, 0, 0))
	ok_sheet.set_pixel(5, 5, Color.WHITE)
	assert_eq(FieldGuide.check_sheet(ok_sheet).size(), 0)
	var bad := Image.create(100, 100, false, Image.FORMAT_RGBA8)
	assert_eq(FieldGuide.check_sheet(bad).size(), 1)
```

- [ ] **Step 2：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_field bash game/tools/run_tests.sh | tail -3`

预期：`test_field.gd` 加载失败（`field_guide.gd` 还不存在），出现 `SCRIPT ERROR`。

- [ ] **Step 3：改写 `game/data/maps/biohazard1.json`**

```json
{
	"version": 1,
	"tile": 16,
	"size": [30, 16],
	"legend": {"#": "wall", ".": "floor", "=": "floor", "~": "water", "o": "prop", "x": "prop", "S": "search", "D": "door"},
	"maps": {
		"car": {
			"theme": "train",
			"doors": {"hall": "right"},
			"start": [3, 7],
			"npc_spots": [[8, 5], [12, 5], [16, 5], [20, 5], [8, 9], [12, 9], [16, 9], [20, 9]],
			"ambient": "#a3abbd",
			"lights": [
				{"at": [5, 7], "color": "#eef3ff", "radius": 6.0, "energy": 0.45},
				{"at": [12, 7], "color": "#eef3ff", "radius": 6.0, "energy": 0.45},
				{"at": [19, 7], "color": "#eef3ff", "radius": 6.0, "energy": 0.45, "flicker": true},
				{"at": [26, 7], "color": "#eef3ff", "radius": 6.0, "energy": 0.45}
			],
			"glows": [
				{"at": [28, 6], "color": "#7fd0ff88", "radius": 0.8},
				{"at": [28, 9], "color": "#7fd0ff88", "radius": 0.8}
			],
			"rows": [
				"##############################",
				"##############################",
				"##############################",
				"##############################",
				"#oo.oo.oo.oo.oo.oo.oo.oo.oo..#",
				"#............................#",
				"#============================#",
				"#============================D",
				"#============================D",
				"#S...........................#",
				"#oo.oo.oo.oo.oo.oo.oo.oo.oo..#",
				"##############################",
				"##############################",
				"##############################",
				"##############################",
				"##############################"
			]
		},
		"hall": {
			"theme": "hall",
			"doors": {"stairs": "top", "car": "left", "sewer": "bottom"},
			"npc_spots": [[10, 5], [12, 5], [14, 5], [16, 5], [18, 5], [11, 9], [17, 9], [14, 10]],
			"ambient": "#7a7264",
			"lights": [
				{"at": [8, 4], "color": "#ffd49a", "radius": 7.0, "energy": 0.85},
				{"at": [21, 4], "color": "#ffd49a", "radius": 7.0, "energy": 0.85},
				{"at": [8, 11], "color": "#ffd49a", "radius": 7.0, "energy": 0.85},
				{"at": [21, 11], "color": "#ffd49a", "radius": 7.0, "energy": 0.85, "flicker": true}
			],
			"glows": [],
			"rows": [
				"##############DD##############",
				"#............................#",
				"#..o......................o..#",
				"#............................#",
				"#.......==============.......#",
				"#.....o.==============.o.....#",
				"#.......==============.......#",
				"D.......==============.......#",
				"D.......==============.......#",
				"#.......==============.......#",
				"#.....o.==============.o.....#",
				"#.......==============.......#",
				"#..o.....................o..S#",
				"#............................#",
				"#............................#",
				"##############DD##############"
			]
		},
		"stairs": {
			"theme": "stairs",
			"doors": {"laser": "top", "hall": "bottom"},
			"npc_spots": [[11, 3], [13, 3], [15, 3], [17, 3], [12, 6], [14, 6], [16, 6], [18, 6]],
			"ambient": "#2a3040",
			"lights": [
				{"at": [10, 2], "color": "#ff4a3a", "radius": 4.0, "energy": 0.8, "flicker": true},
				{"at": [19, 12], "color": "#ff4a3a", "radius": 3.0, "energy": 0.5}
			],
			"glows": [
				{"at": [10, 2], "color": "#ff4a3a99", "radius": 1.0},
				{"at": [19, 12], "color": "#ff4a3a77", "radius": 0.8}
			],
			"rows": [
				"##############DD##############",
				"#########............#########",
				"#########.o........o.#########",
				"#########............#########",
				"#########............#########",
				"#########oooooo......#########",
				"#########............#########",
				"#########............#########",
				"#########......oooooo#########",
				"#########............#########",
				"#########............#########",
				"#########oooooo......#########",
				"#########............#########",
				"#########.S..........#########",
				"#########............#########",
				"##############DD##############"
			]
		},
		"laser": {
			"theme": "laser",
			"doors": {"stairs": "left", "control": "right"},
			"npc_spots": [[24, 6], [22, 6], [24, 9], [22, 9], [20, 6], [20, 9], [26, 6], [26, 9]],
			"ambient": "#c4cad2",
			"lights": [
				{"at": [7, 7], "color": "#f2f6ff", "radius": 7.0, "energy": 0.28},
				{"at": [15, 7], "color": "#f2f6ff", "radius": 7.0, "energy": 0.28},
				{"at": [23, 7], "color": "#f2f6ff", "radius": 7.0, "energy": 0.28}
			],
			"glows": [
				{"at": [2, 4], "color": "#ff3b3bbb", "radius": 1.1},
				{"at": [7, 4], "color": "#ff3b3bbb", "radius": 1.1},
				{"at": [12, 4], "color": "#ff3b3bbb", "radius": 1.1},
				{"at": [17, 4], "color": "#ff3b3bbb", "radius": 1.1},
				{"at": [22, 4], "color": "#ff3b3bbb", "radius": 1.1},
				{"at": [27, 4], "color": "#ff3b3bbb", "radius": 1.1},
				{"at": [2, 11], "color": "#ff3b3bbb", "radius": 1.1},
				{"at": [7, 11], "color": "#ff3b3bbb", "radius": 1.1},
				{"at": [12, 11], "color": "#ff3b3bbb", "radius": 1.1},
				{"at": [17, 11], "color": "#ff3b3bbb", "radius": 1.1},
				{"at": [22, 11], "color": "#ff3b3bbb", "radius": 1.1},
				{"at": [27, 11], "color": "#ff3b3bbb", "radius": 1.1}
			],
			"rows": [
				"##############################",
				"##############################",
				"##############################",
				"##############################",
				"##x####x####x####x####x####x##",
				"#............................#",
				"#............................#",
				"D............................D",
				"D............................D",
				"#............................#",
				"#.S..........................#",
				"##x####x####x####x####x####x##",
				"##############################",
				"##############################",
				"##############################",
				"##############################"
			]
		},
		"control": {
			"theme": "control",
			"doors": {"laser": "left", "corridor": "right"},
			"npc_fixed": {"red_queen": [14, 7]},
			"npc_spots": [[8, 3], [10, 3], [12, 3], [17, 3], [19, 3], [8, 11], [10, 11], [19, 11]],
			"ambient": "#3c4a68",
			"lights": [
				{"at": [6, 4], "color": "#7fd0ff", "radius": 4.0, "energy": 0.6},
				{"at": [21, 4], "color": "#7fd0ff", "radius": 4.0, "energy": 0.6},
				{"at": [6, 10], "color": "#7fd0ff", "radius": 4.0, "energy": 0.6},
				{"at": [21, 10], "color": "#7fd0ff", "radius": 4.0, "energy": 0.6}
			],
			"glows": [
				{"at": [3, 1], "color": "#7fd0ff88", "radius": 0.8},
				{"at": [7, 1], "color": "#7fd0ff88", "radius": 0.8},
				{"at": [11, 1], "color": "#7fd0ff88", "radius": 0.8},
				{"at": [16, 1], "color": "#7fd0ff88", "radius": 0.8},
				{"at": [20, 1], "color": "#7fd0ff88", "radius": 0.8},
				{"at": [24, 1], "color": "#7fd0ff88", "radius": 0.8},
				{"at": [3, 14], "color": "#7fd0ff88", "radius": 0.8},
				{"at": [7, 14], "color": "#7fd0ff88", "radius": 0.8},
				{"at": [11, 14], "color": "#7fd0ff88", "radius": 0.8},
				{"at": [16, 14], "color": "#7fd0ff88", "radius": 0.8},
				{"at": [20, 14], "color": "#7fd0ff88", "radius": 0.8},
				{"at": [24, 14], "color": "#7fd0ff88", "radius": 0.8}
			],
			"rows": [
				"##############################",
				"#o.o.o.o.o.o..o.o.o.o.o.o.o.o#",
				"#............................#",
				"#............................#",
				"#....oooo..........oooo......#",
				"#............................#",
				"#............ooo.............#",
				"D............................D",
				"D............................D",
				"#............................#",
				"#....oooo..........oooo......#",
				"#............................#",
				"#............................#",
				"#S...........................#",
				"#o.o.o.o.o.o..o.o.o.o.o.o.o.o#",
				"##############################"
			]
		},
		"corridor": {
			"theme": "corridor",
			"doors": {"control": "left", "freezer": "right", "sewer": "bottom"},
			"npc_spots": [[6, 6], [9, 6], [12, 6], [15, 6], [18, 6], [21, 6], [6, 9], [9, 9]],
			"ambient": "#56645e",
			"lights": [
				{"at": [5, 7], "color": "#e6ffe9", "radius": 5.0, "energy": 0.8},
				{"at": [12, 7], "color": "#e6ffe9", "radius": 5.0, "energy": 0.8, "flicker": true},
				{"at": [19, 7], "color": "#e6ffe9", "radius": 5.0, "energy": 0.8},
				{"at": [26, 7], "color": "#e6ffe9", "radius": 5.0, "energy": 0.8},
				{"at": [15, 12], "color": "#e6ffe9", "radius": 3.0, "energy": 0.5}
			],
			"glows": [],
			"rows": [
				"##############################",
				"##############################",
				"##############################",
				"##############################",
				"##############################",
				"#oo.oo.oo.oo.oo.oo.oo.oo.oo..#",
				"#............................#",
				"D............................D",
				"D............................D",
				"#............................#",
				"#..S....oo.oo....oo.oo.oo....#",
				"##############..##############",
				"##############..##############",
				"##############..##############",
				"##############..##############",
				"##############DD##############"
			]
		},
		"freezer": {
			"theme": "freezer",
			"doors": {"corridor": "left"},
			"npc_spots": [[10, 5], [14, 5], [18, 5], [22, 5], [10, 10], [14, 10], [18, 10], [22, 10]],
			"ambient": "#203040",
			"lights": [
				{"at": [8, 3], "color": "#a8eaff", "radius": 3.0, "energy": 0.45},
				{"at": [18, 3], "color": "#a8eaff", "radius": 3.0, "energy": 0.45},
				{"at": [8, 12], "color": "#a8eaff", "radius": 3.0, "energy": 0.4, "flicker": true}
			],
			"glows": [
				{"at": [3, 2], "color": "#a8eaff66", "radius": 0.9},
				{"at": [8, 2], "color": "#a8eaff66", "radius": 0.9},
				{"at": [13, 2], "color": "#a8eaff66", "radius": 0.9},
				{"at": [18, 2], "color": "#a8eaff66", "radius": 0.9},
				{"at": [23, 2], "color": "#a8eaff66", "radius": 0.9}
			],
			"rows": [
				"##############################",
				"##############################",
				"#oooo.oooo.oooo.oooo.oooo....#",
				"#............................#",
				"#............................#",
				"#............................#",
				"#............................#",
				"D............................#",
				"D............................#",
				"#............................#",
				"#............................#",
				"#............................#",
				"#oooo.oooo.oooo.oooo.oooo..S.#",
				"#............................#",
				"##############################",
				"##############################"
			]
		},
		"sewer": {
			"theme": "sewer",
			"doors": {"hall": "left", "corridor": "right"},
			"npc_spots": [[8, 5], [11, 5], [14, 5], [17, 5], [20, 5], [8, 10], [11, 10], [14, 10]],
			"ambient": "#182024",
			"lights": [
				{"at": [14, 5], "color": "#9ab89a", "radius": 3.5, "energy": 0.4, "flicker": true}
			],
			"glows": [],
			"rows": [
				"##############################",
				"##############################",
				"##############################",
				"##############################",
				"##############################",
				"#............................#",
				"#~~~~~~~~~~~~~~~~~~~~~~~~~~~~#",
				"D............................D",
				"D............................D",
				"#~~~~~~~~~~~~~~~~~~~~~~~~~~~~#",
				"#.........................S..#",
				"##############################",
				"##############################",
				"##############################",
				"##############################",
				"##############################"
			]
		}
	}
}
```

- [ ] **Step 4：改写 `game/ui/field/field_map.gd`**

```gdscript
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
```

- [ ] **Step 5：改写 `game/ui/field/field_art.gd`**

```gdscript
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
```

- [ ] **Step 6：创建 `game/ui/field/field_guide.gd`**

```gdscript
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
```

- [ ] **Step 7：改写 `game/ui/field/field_screen.gd`**

```gdscript
extends Control
## 地点场景：RPG 式探索（设计规格 5.1、11）。
## 像素层 480×256（30×16 格，每格 16 像素），整数放大 4 倍正好铺满顶栏下面的 1920×1024；
## 主角（拍板的人）用方向键 / WASD 走，队友跟在后面；对着人按 Enter 说话，对着柜子按 Enter 搜索；
## 走进门就去隔壁地点（时间照规则推进）；点地面会自己走过去。
## 画面：有 Codex 画好的整张地图和行走图就用（field_art.gd），没有用占位图块；
## 每个地点有环境光和灯（data/maps 里的 ambient / lights / glows），黑暗地点只剩主角手里的手电筒；人物脚下有影子。
## 剧情事件不堆在日志里：台词一句一句打字出在底部的对话框里（左边是立绘），选择弹选项窗口，说服弹说服窗口，
## 其他结果在右边飘一条提示；完整记录按 L 看。规则全在 core，这里只调 ExpeditionView。
## 对外的 press_* 方法和信号跟旧的地点图界面一样，main.gd 和切片验收不用改。

signal battle_needed
signal ended
signal talk_requested(npc_id: String)
signal persuade_requested
signal cutscene_requested(name: String, text: String)

const ExpeditionView = preload("res://ui/expedition/expedition_view.gd")
const FieldMap = preload("res://ui/field/field_map.gd")
const FieldArt = preload("res://ui/field/field_art.gd")
const UiTheme = preload("res://ui/ui_theme.gd")
const EventText = preload("res://ui/event_text.gd")
const PortraitSource = preload("res://ui/art/portrait_source.gd")

const MAPS := "res://data/maps/biohazard1.json"
const PIXEL := Vector2i(480, 256)
const SCALE := 4
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


## 占位图块拼的地图（没有整张画好的地图时用）。墙下面是屋里的画成墙面，有立体感。
class TileLayer extends Node2D:
	var fmap: RefCounted

	func _draw() -> void:
		if fmap == null:
			return
		for y in fmap.size.y:
			for x in fmap.size.x:
				var c := Vector2i(x, y)
				draw_texture(FieldArt.tile(fmap.theme(), fmap.char_at(c), fmap.wall_face(c)), Vector2(x * TILE, y * TILE))


var view: RefCounted
var fmap: RefCounted
var loc: String = ""
var viewport: SubViewport
var display: TextureRect
var ground: Sprite2D
var tiles: TileLayer
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
	_memory[view.ex.get_instance_id()] = {"loc": loc, "cell": cell, "facing": facing, "seen": seen, "trail": trail.duplicate()}


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
	viewport = SubViewport.new()
	viewport.size = PIXEL
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.snap_2d_transforms_to_pixel = true
	add_child(viewport)
	ground = Sprite2D.new()
	ground.centered = false
	viewport.add_child(ground)
	tiles = TileLayer.new()
	viewport.add_child(tiles)
	light_root = Node2D.new()
	viewport.add_child(light_root)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	viewport.add_child(actors)
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
	display.size = Vector2(PIXEL * SCALE)
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)

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

	hint_label = UiTheme.label(tr("方向键 / WASD 走动 · Enter 说话、调查 · 点地面自动走过去 · L 记录 · Esc 菜单"), 16, UiTheme.MUTED)
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


# ---------------------------------------------------------------- 进地点、摆人、打光

## 进入（或刷新）一个地点：读图、打光、摆剧情人物、主角和队友。from_loc 是从哪个地点走来的；mem 是换屏前记住的位置。
func _enter(new_loc: String, from_loc: String, mem: Dictionary = {}) -> void:
	var first_time := loc != new_loc
	loc = new_loc
	fmap = FieldMap.make(MAPS, loc)
	var painted := FieldArt.map_image(loc)
	ground.texture = painted
	ground.visible = painted != null
	tiles.visible = painted == null
	tiles.fmap = fmap
	tiles.queue_redraw()
	_build_lights()
	var restored: bool = String(mem.get("loc", "")) == loc and fmap.walkable(mem["cell"])
	if restored:
		cell = mem["cell"]
		facing = String(mem.get("facing", "down"))
	elif from_loc != "":
		cell = fmap.entry_cell(from_loc)
		facing = _facing_from(from_loc)
	else:
		cell = fmap.start_cell()
		# 开场点（车厢）面朝第一扇门；没有开场点时站在第一扇门里面，面朝屋里。
		for dest: String in fmap.data.get("doors", {}):
			var doors: Array[Vector2i] = fmap.door_cells(dest)
			if not doors.is_empty():
				facing = _dir_between(cell, doors[0]) if fmap.data.has("start") else _facing_from(dest)
			break
	path_queue.clear()
	for c in actors.get_children():
		actors.remove_child(c)
		c.queue_free()
	followers.clear()
	follower_ids.clear()
	npc_sprites.clear()
	npc_cells.clear()
	_place_npcs()
	var squad: Array[String] = _squad()
	player_id = squad[0] if not squad.is_empty() else ""
	player = _walker(player_id)
	for i in range(1, squad.size()):
		follower_ids.append(squad[i])
		followers.append(_walker(squad[i]))
	var old: Array = mem.get("trail", []) if restored else []
	trail = _initial_trail(cell, squad.size(), old)
	_draw_actors()
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
	var back: Vector2i = -FieldMap.DIRS[facing]
	var side := Vector2i(back.y, back.x)
	var dist := {start: 0}
	var queue: Array[Vector2i] = [start]
	var cands: Array[Vector2i] = []
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if int(dist[c]) >= 5:
			continue
		for d: Vector2i in FieldMap.DIRS.values():
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


## 进门后面朝屋里。
func _facing_from(from_loc: String) -> String:
	var d: Vector2i = fmap.entry_cell(from_loc) - (fmap.door_cells(from_loc)[0] if not fmap.door_cells(from_loc).is_empty() else fmap.entry_cell(from_loc))
	for k: String in FieldMap.DIRS:
		if FieldMap.DIRS[k] == d:
			return k
	return "down"


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
		var p := _light(Color(String(l.get("color", "#ffffff"))), float(l.get("radius", 4.0)), float(l.get("energy", 1.0)))
		p.position = _center(Vector2i(int(l["at"][0]), int(l["at"][1])))
		light_root.add_child(p)
		if bool(l.get("flicker", false)):
			flickers.append({"node": p, "base": p.energy, "phase": 1.7 * k})
		k += 1
	for g: Dictionary in fmap.glows():
		var s := Sprite2D.new()
		s.texture = FieldArt.light_texture()
		s.material = _additive
		s.modulate = Color(String(g.get("color", "#ffffff")))
		s.scale = Vector2.ONE * float(g.get("radius", 1.0)) * TILE * 2.0 / FieldArt.LIGHT_SIZE
		s.position = _center(Vector2i(int(g["at"][0]), int(g["at"][1])))
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
		if not (fmap.data.get("npc_fixed", {}) as Dictionary).has(npc_id):
			i += 1
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
		var c: Vector2i = trail[mini(i + 1, trail.size() - 1)]
		followers[i].position = _pixel(c)
		followers[i].visible = c != cell
		followers[i].texture = FieldArt.walker(follower_ids[i], _dir_between(c, trail[mini(i, trail.size() - 1)]), 0)
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
		if SILENT_TYPES.has(t):
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
	if moving or busy():
		prompt.visible = false
		return
	if not path_queue.is_empty():
		var next: Vector2i = path_queue.pop_front()
		var d := _dir_between(cell, next)
		if next - cell != FieldMap.DIRS[d]:
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
		if k.keycode == KEY_L:
			_toggle_log()
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
		click_cell(Vector2i(floori(mb.position.x / (TILE * SCALE)), floori(mb.position.y / (TILE * SCALE))))
	accept_event()


func _on_box_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()


## 面前一格能做什么：调查柜子、跟谁说话、去哪个地点；什么都没有返回空字符串。
func prompt_text() -> String:
	var t: Vector2i = cell + FieldMap.DIRS[facing]
	if fmap.is_search(t):
		return tr("Enter 调查（搜过了）") if view.ex.st.searched.has(loc) else tr("Enter 调查")
	for id: String in npc_cells:
		if npc_cells[id] == t and _can_talk(id):
			return tr("Enter 说话：%s") % String(view.names.get(id, id))
	for i in follower_ids.size():
		if trail[mini(i + 1, trail.size() - 1)] == t and _can_talk(follower_ids[i]):
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
	var t: Vector2i = cell + FieldMap.DIRS[facing]
	var at := Vector2((t.x * TILE + TILE / 2.0) * SCALE, (t.y * TILE - 14) * SCALE)
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
	var target: Vector2i = cell + FieldMap.DIRS[d]
	if fmap.is_door(target):
		_go_door(fmap.door_dest(target))
		return
	if not fmap.walkable(target) or _blocked().has(target):
		_draw_actors()
		return
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


## 对着前面一格按确认：柜子 → 搜索；剧情人物或队友 → 说话；门 → 过去。
func interact() -> void:
	var target: Vector2i = cell + FieldMap.DIRS[facing]
	if fmap.is_search(target):
		press_search()
		return
	for id: String in npc_cells:
		if npc_cells[id] == target:
			press_talk(id)
			return
	for i in follower_ids.size():
		if trail[mini(i + 1, trail.size() - 1)] == target:
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
		for d: Vector2i in FieldMap.DIRS.values():
			if fmap.walkable(c + d) and not fmap.is_door(c + d):
				goal = c + d
	elif fmap.is_search(c) or blocked.has(c):
		then = {"interact": true, "face": c}
		goal = Vector2i(-1, -1)
		var best := 99999
		for d: Vector2i in FieldMap.DIRS.values():
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
```

- [ ] **Step 8：创建 `game/tools/field_guides.gd`**

```gdscript
extends SceneTree
## 任务卡 007：导出每个地点的版式图（照着画整张地图），检查已经画好的地图和行走图。
## 用法（仓库根目录）：godot --headless --path game -s res://tools/field_guides.gd
## 输出（都在仓库根目录的 art_src/field/ 下，图片不进仓库）：
##   guides/<地点>.png      480×256，一格一色的版式图（图例见 ui/field/field_guide.gd 的 COLORS）
##   guides/<地点>_x4.png   同一张放大 4 倍（1920×1024），给生图当构图参考
##   qa/<地点>_overlay.png  已经有 game/art/field/maps/<地点>.png 时：画好的图放大 4 倍，盖上碰撞颜色和格线
## 同时检查：地图是不是 480×256、不透明；game/art/field/walkers/ 下的行走图是不是 4×4、单帧 32×32、有透明。
## 有问题时退出码为 1，并逐条打印。

const FieldMap = preload("res://ui/field/field_map.gd")
const FieldArt = preload("res://ui/field/field_art.gd")
const FieldGuide = preload("res://ui/field/field_guide.gd")

const MAPS := "res://data/maps/biohazard1.json"
const MAP_SIZE := Vector2i(480, 256)


func _initialize() -> void:
	var out := ProjectSettings.globalize_path("res://").path_join("../art_src/field")
	DirAccess.make_dir_recursive_absolute(out.path_join("guides"))
	DirAccess.make_dir_recursive_absolute(out.path_join("qa"))
	var problems: Array[String] = []
	var all := FieldMap.load_file(MAPS)
	for loc: String in all["maps"]:
		var m: RefCounted = FieldMap.make(MAPS, loc)
		var g := FieldGuide.guide(m)
		g.save_png(out.path_join("guides/%s.png" % loc))
		var g4 := g.duplicate() as Image
		g4.resize(g.get_width() * FieldGuide.ZOOM, g.get_height() * FieldGuide.ZOOM, Image.INTERPOLATE_NEAREST)
		g4.save_png(out.path_join("guides/%s_x4.png" % loc))
		var painted := FieldArt.map_image(loc)
		if painted == null:
			print("%s：版式图已导出，还没有画好的地图" % loc)
			continue
		var img := painted.get_image()
		if img.get_size() != MAP_SIZE:
			problems.append("%s：地图是 %s，应该是 %s" % [loc, img.get_size(), MAP_SIZE])
		if img.detect_alpha() != Image.ALPHA_NONE:
			problems.append("%s：地图有透明像素，应该不透明" % loc)
		FieldGuide.overlay(m, img).save_png(out.path_join("qa/%s_overlay.png" % loc))
		print("%s：版式图、对位图已导出" % loc)
	var walkers := "res://art/field/walkers/"
	var dir := DirAccess.open(walkers)
	if dir != null:
		for file in dir.get_files():
			if not file.ends_with(".png"):
				continue
			var tex := FieldArt._load(walkers + file)
			if tex == null:
				problems.append("行走图 %s 读不出来" % file)
				continue
			for p in FieldGuide.check_sheet(tex.get_image()):
				problems.append("行走图 %s：%s" % [file, p])
			print("行走图 %s：%s" % [file, tex.get_size()])
	for p in problems:
		print("问题：", p)
	print("完成，问题 %d 个" % problems.size())
	quit(1 if not problems.is_empty() else 0)
```

- [ ] **Step 9：创建 `game/tools/field_capture.gd`**

```gdscript
extends SceneTree
## 计划 21 / 任务卡 007：给探索画面截图，看地图、行走图、灯光放进游戏里是什么样子。
## 用法（要窗口，不能 --headless）：godot --path game -s res://tools/field_capture.gd
## 输出：仓库根目录 art_src/qa/field_<序号>_<内容>.png（1920×1080）：开场对话框，然后八个地点各一张。
## 只截图，不写存档。截地点时直接把分队放到那个地点（跳过路上的剧情和战斗），剧情人物按开局的位置站。

const Session = preload("res://core/session/session.gd")
const FieldMap = preload("res://ui/field/field_map.gd")
const FieldScreen = preload("res://ui/field/field_screen.gd")

const MAPS := "res://data/maps/biohazard1.json"

var n := 0


func _initialize() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	n += 1
	var dir := ProjectSettings.globalize_path("res://").path_join("../art_src/qa")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("field_%02d_%s.png" % [n, name])
	root.get_texture().get_image().save_png(path)
	print("截图 ", path)


func _field(s: RefCounted) -> Control:
	var names := {}
	for id: String in s.game.characters:
		names[id] = s.game.characters[id].display_name
	var f := FieldScreen.new()
	root.add_child(f)
	f.setup(s.expedition, names)
	return f


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var s := Session.new()
	s.start_m1(1)
	var f := _field(s)
	await create_timer(1.6).timeout
	await _shot("car_opening")
	f.queue_free()
	await process_frame
	var all := FieldMap.load_file(MAPS)
	for loc: String in all["maps"]:
		var s2 := Session.new()
		s2.start_m1(1)
		var g := _field(s2)
		g.press_choice("listen")
		g.flush_messages()
		var sid: String = g.view.squad_id()
		s2.expedition.st.squads[sid]["location"] = loc
		g.refresh()
		g.flush_messages()
		g._show_next()
		await create_timer(0.9).timeout
		await _shot(loc)
		g.queue_free()
		await process_frame
	print("共截图 ", n)
	quit(0)
```

- [ ] **Step 10：运行，确认通过**

Run: `bash game/tools/run_tests.sh > _work/p21_task1.txt 2>&1; echo "exit=$?"; tail -1 _work/p21_task1.txt; echo "SCRIPT ERROR: $(grep -c 'SCRIPT ERROR' _work/p21_task1.txt)"`

预期：`共 472 个测试，失败 0 个`、`SCRIPT ERROR: 0`。

- [ ] **Step 11：导出版式图（工具能跑）**

Run: `timeout 120 godot --headless --path game -s res://tools/field_guides.gd 2>&1 | tail -2; ls art_src/field/guides | wc -l`

预期：`完成，问题 0 个`；`16`（八个地点各两张）。图片在 `art_src/` 下，被 `.gitignore` 忽略。

- [ ] **Step 12：提交**

```bash
git add game/data/maps/biohazard1.json game/ui/field game/tools/field_guides.gd game/tools/field_capture.gd game/tests/unit/ui/test_field.gd
git commit -m "feat(field): 探索画面加环境光、灯、手电筒光锥、影子；对话框改成大立绘加打字；接好 Codex 正式地图和行走图的接口" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

## Task 2：任务卡 007

- [ ] **Step 1：创建 `docs/codex-tasks/007-m1-field-art.md`**

```markdown
# 任务卡 007：M1 探索画面的整张地图与行走图

## 目标
计划 20、21 把《生化危机一》的探索改成了 RPG Maker 式的可行走场景：俯视、方向键走、队友跟在后面、走进门去隔壁、剧情在对话框里演。引擎已经有了灯光（环境光、吊灯、灯管、应急灯、黑暗里的手电筒）、人物影子、带立绘的对话框，但**地图和小人还是代码画的占位方块**。用户看了说"太简陋，连 08 年的 RPG Maker 同人游戏都不如"。

这张卡出正式图：**8 张整张地图 + 15 套四方向行走图**。做完不用改代码：游戏会自动读 `game/art/field/` 下的图，替换占位。

## 先读
- `AGENTS.md`（尤其"图片不进仓库""只修改允许的路径"）
- 设计规格 `docs/superpowers/specs/2026-11-05-wuxian-kongbu-game-design.md` 第 11 节
- `docs/codex-tasks/003-pixel-style-test.md`、`docs/art/pixel-test-report.md`（已验收的像素流程、32 色共用调色板、整张场景图怎么转像素）
- `docs/codex-tasks/006-m1-battle-sprites.md`（战斗小人的人物特征表；同一个人物在两边要认得出是同一个人）
- `game/ui/field/field_art.gd`（游戏怎么找图、行走图怎么切帧）
- `game/ui/field/field_guide.gd`（版式图的图例颜色、对位图怎么画）
- `game/data/maps/biohazard1.json`（每个地点的字符格子、门、灯和光晕的位置）

## 允许修改
- `game/art/field/`（新建）
- `art_src/field/`（新建：版式图、原图、中间文件、提示词、报告、QA）
- 本任务卡末尾的"完成汇报"

不要改 `game/` 下的任何代码、数据、测试，也不要改 `project.godot`。

## 产出路径与格式

| 类型 | 路径 | 格式 |
|---|---|---|
| 整张地图 | `game/art/field/maps/<地点>.png` | 480×256，不透明 |
| 行走图 | `game/art/field/walkers/<id>.png` | 128×128 RGBA，4 列 × 4 行，单帧 32×32 |
| 版式图、对位图、截图 | `art_src/field/guides/`、`art_src/field/qa/`、`art_src/qa/` | 工具自动生成 |
| 提示词、报告、SHA-256 | `art_src/field/` | Markdown / JSON |

## 画面规格

### 地图
- **视角**：RPG Maker 式 3/4 俯视。地面从正上方看；墙、柜子、座椅、机柜看得到顶面和朝向镜头的正面；屋子上沿的墙画出一格高的墙面（版式图里浅灰的"墙面"格）。
- **尺寸**：480×256 像素 = 30×16 格，每格 16 像素；游戏里整数放大 4 倍。颜色全部取自 `game/art/pixel_test/palette.hex`。
- **必须和碰撞格子对上**（碰撞以 `biohazard1.json` 为准，不能改它）：
  - 墙、家具设备、柜子、门的格子画成对应的东西；
  - 地面格（`.` 地面、`=` 过道或地毯、`~` 浅水）上只画地面：可以有花纹、污渍、文件、血迹、电线、水渍，**不能画会挡路的东西**；
  - 家具可以往上伸进上一格最多 6 像素（看得到顶面），不要更多。
- `S` 格是可以搜索的柜子或箱子：画得醒目些，让玩家看得出"这个能翻"。
- `D` 格是门：画成开着的门洞或通道，看得出能走出去。
- **光交给游戏**：游戏会压环境光、打灯（`lights`）、叠自发光光晕（`glows`）。地图本身画成照明均匀、偏中性的底图，不要画大块明暗、光斑、光束和投影；但灯具本身（吸顶灯、吊灯、灯管、应急灯、屏幕、指示灯）要画出来，位置和 `lights`、`glows` 的格子一致。
- 不画人物、文字、UI、标志；不画激光（激光是游戏的效果层）。

### 行走图
- 128×128，4 列 × 4 行，单帧 32×32，透明底，alpha 只有 0 和 255，颜色取自共用调色板。
- **行**（从上到下）：面朝下（朝镜头）、面朝左、面朝右、面朝上（背对镜头）。
- **列**（从左到右）：站立、迈一只脚、站立、迈另一只脚。游戏走路时轮流用第 2、4 列，停下用第 1 列。
- Q 版 2.5～3 头身，可见高度 24～30 像素，水平居中，**脚踩在单帧最下面一行**（第 31 行）；四个方向、四帧的脚底在同一条线上。
- 面朝右那一行可以是面朝左的水平镜像（这张卡允许，跟 006 不同）。
- 发型、服装配色和立绘 `game/art/portraits/<id>.png`、提示词 `art_src/prompts/<id>.md`、006 的战斗小人一致。

## 清单

### 地图（每张 480×256）
括号里是 `biohazard1.json` 的格子坐标（x, y），从左上角 (0, 0) 数起。

| 文件 | 地点 | 画什么 |
|---|---|---|
| `car.png` | 高速车厢 | 高速列车车厢内部。上下两排 `o` 是座椅（两两一组，中间的空当能走进去）；中间 `=` 是过道防滑地面；右边 `D` 是通往大厅的车门；左下 `S` 是行李柜。上沿墙面画车窗（窗外漆黑），车厢外面（第 0～3、11～15 行）画成车体外壳或黑暗的隧道。吸顶灯在过道 (5,7) (12,7) (19,7) (26,7)，车门旁两个蓝色指示灯 (28,6) (28,9)。 |
| `hall.png` | 蜂巢入口大厅 | 豪宅地下入口改造成的大厅，大理石地面；中间 `=` 是一大块地毯；四个 `o` 是柱子或花架；上方 `D` 是通往楼梯井的金属门，左边 `D` 是通往车厢的站台入口，下方 `D` 是通往下水道的检修铁栅门；右下 `S` 是前台档案柜。吊灯在 (8,4) (21,4) (8,11) (21,11)。 |
| `stairs.png` | 楼梯井 | 狭窄的金属楼梯井，两边是厚墙；`o` 横条是平台栏杆和管线，中间能走的是平台和楼梯段（台阶画在能走的格子上，看起来能踩）；`S` 是消防箱。红色应急灯 (10,2) (19,12)。这里平时全黑，玩家只靠手电筒看。 |
| `laser.png` | 激光通道 | 白色金属走廊，上下墙上的 `x` 是激光发射器（墙上的小装置带红色指示灯，**不画激光束**）；左右 `D` 是门；`S` 是墙边的设备箱。顶灯 (7,7) (15,7) (23,7)。 |
| `control.png` | 火焰女皇主机房 | 上下两排 `o` 是机柜（屏幕亮青色，位置对应 `glows`）；四组 `oooo` 是控制台；中央 `ooo` 是全息投影台（火焰女皇站在 (14,7)，**不画人**）；`S` 是工具柜；左右 `D` 是门。青色灯 (6,4) (21,4) (6,10) (21,10)。 |
| `corridor.png` | 实验区走廊 | 实验区走廊：上排 `o` 是实验台和柜子，下排 `oo` 是设备；中下方的竖通道通往下水道（最下面的 `D`）；左右 `D` 是门；`S` 是储物柜。荧光灯管 (5,7) (12,7) (19,7) (26,7) (15,12)。 |
| `freezer.png` | 冷冻仓库 | 上下两排 `oooo` 是冷冻柜（结霜、冷蓝色，柜门灯对应 `glows`）；`S` 是一个冷冻储物格；左边 `D` 是门。冷柜灯 (8,3) (18,3) (8,12)。这里平时全黑。 |
| `sewer.png` | 下水道 | 下水道隧道：上下两条 `~` 是浅水沟（能走），中间 `.` 是走道；左右 `D` 是检修口；`S` 是排水口旁的工具箱。(14,5) 有一束从上方格栅漏下来的光。这里平时全黑。 |

### 行走图（15 套）
**轮回者**（特征同 006 卡的表格）：`zheng_zha` 郑吒、`zhang_jie` 张杰、`zhan_lan` 詹岚、`li_xiao_yi` 李萧毅、`mu_gang` 牟钢、`xiao_pang_zi` 小胖子、`zhong_nian_fu_nv` 中年妇女。

**剧情人物**（以立绘和 `art_src/prompts/<id>.md` 为准）：

| id | 人物 | 32px 下要看得出的特征 |
|---|---|---|
| `matthew` | 马修·艾迪森 | 雇佣兵队长，深肤色、极短黑发、黑色战术背心 |
| `alice` | 艾丽丝 | 栗棕色短发到下颌，按立绘的服装配色 |
| `rain` | 雷恩 | 女雇佣兵，黑色短发、战术背心、体格结实 |
| `jd` | J·D | 男雇佣兵，黑色短发、深灰作战服 |
| `ryan` | 瑞恩 | 女雇佣兵，深棕色单马尾、深灰作战服 |
| `kaplan` | 卡普兰 | 技术员，深棕短发、细框眼镜、灰蓝工装 |
| `matt` | 马特 | 普通市民，深棕短发、灰蓝冲锋衣 |
| `red_queen` | 火焰女皇 | 小女孩的全息投影；画成正常配色的小女孩即可（游戏会给她叠半透明红色和红光） |

## 工具（都在仓库根目录运行）
1. **导出版式图**：`godot --headless --path game -s res://tools/field_guides.gd`，生成 `art_src/field/guides/<地点>.png`（480×256，一格一色）和 `<地点>_x4.png`（1920×1024）。图例：墙顶 `#15171c`、墙面 `#5b6170`、地面 `#cfc8b8`、过道或地毯 `#b39a72`、浅水 `#4f86b8`、家具设备 `#8a5a2a`、激光发射器 `#c03030`、可搜索的柜子 `#e8c040`、门 `#3fae5a`。
2. **生图**：把 `_x4` 版式图当构图参考（渠道支持参考图就带上），提示词写清视角、每类格子画什么、本卡"地图"一节的要求。渠道的画布比例和 30:16 不同时，把版式图等比放进画布、四周留边，生成后按同样位置裁回。
3. **转像素**：用 003 的 `game/tools/pixelize_scene.py`，`--width 480 --height 256`，映射到共用调色板，不抖动。
4. **对位检查**：成品放进 `game/art/field/maps/` 后再跑一次 `field_guides.gd`，会生成 `art_src/field/qa/<地点>_overlay.png`：画好的图放大 4 倍，挡路的格子盖红、门盖绿、柜子盖黄，带格线。**红色要正好盖住墙和家具，红格外面的地面上不能露出家具。**对不上就重画或修原图再转像素，不要改 `biohazard1.json`。同一个工具也检查行走图的尺寸和透明；退出码 0 才算过。
5. **看游戏里的样子**：`godot --path game -s res://tools/field_capture.gd`（要窗口），截图在 `art_src/qa/field_*.png`：开场对话框 + 8 个地点（带灯光、黑暗地点带手电筒）。这个工具不写存档。

## 流程
- 地图：每张先出一张俯视场景图，再按上面 2～4 步转像素、对位。
- 行走图：每个人物先出一张 Q 版像素基础图（可以复用 006 的基础图），再走 sprite-gen 的 prepare → gen-set → extract → compose-atlas：cell 32，四行动作依次是面朝下、左、右、上的走路，每行 4 帧，`pixel_unfake=true`，首次 extract 前写 `palette.lock.json`（颜色取自 `palette.hex`），脚底用 foot-centroid / bottom 对齐到最下面一行，关闭 outline。
- **只用 codex 登录渠道（sprite-gen `gen --provider codex`）。不要用 `pixel-draw`。**codex 渠道不可用就停下来，在完成汇报里写明，等用户决定；不要自己换别的 provider 或按调用计费的接口。

## 分批做
- **第一批（先验收）**：`car.png`、`zheng_zha`、`zhang_jie`。做完先停，等 Claude 看图确认。
- **第二批**：其余 7 张地图。
- **第三批**：其余 5 个轮回者和 8 个剧情人物。

## 验收标准
- `field_guides.gd` 退出码 0；每张对位图里墙和家具都在红格里，地面上没有挡路的东西。
- 地图 480×256、不透明、颜色在调色板里；行走图 128×128、单帧 32×32、alpha 只有 0 和 255、脚底同一条线。
- `field_capture.gd` 的截图里：地图替换了占位方块；人物站在地面上（不会看起来站在桌子或座椅上）；灯具的位置和游戏打的灯对得上；黑暗地点手电筒照到的地方看得清。
- 仓库根目录 `bash game/tools/run_tests.sh` 全部通过（只出图，测试数不变）。

## 不要做的事
- 不要把 png 提交进仓库（`git add -f` 也不行）；提交提示词、报告和 SHA-256。
- 不要改游戏代码、数据、测试；不要动 `_work/`。
- 不要参照或模仿任何现成游戏的地图和美术（包括以前的《无限恐怖》同人游戏和 RPG Maker 自带素材），只借用 RPG Maker 式的视角和格子画法。
- 不要为了"更好看"改人物设定或地图布局。

## 完成汇报
在本文件末尾追加：每批出了哪些、路径、尺寸、SHA-256、用了几次生图、遇到的问题（尤其对位不准的地方）；以及你认为描述有歧义、需要 Claude 补设定的地方。
```

- [ ] **Step 2：提交**

```bash
git add docs/codex-tasks/007-m1-field-art.md
git commit -m "docs: 任务卡 007（M1 探索画面的整张地图与行走图）" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

## Task 3：验收

- [ ] **Step 1：在改名的副本里跑切片验收**

```bash
rm -rf _work/p21_verify && mkdir -p _work/p21_verify && cp -r game _work/p21_verify/game
sed -i 's/^config\/name=.*/config\/name="无限恐怖_验收p21"/' _work/p21_verify/game/project.godot
timeout 300 godot --headless --path _work/p21_verify/game -s res://tools/verify_m1_slice.gd 2>&1 | tail -1; echo "exit=${PIPESTATUS[0]}"
```

预期：`M1 切片验证：失败 0 项`，`exit=0`。

- [ ] **Step 2：跑全量与导入，提交 uid**

```bash
bash game/tools/run_tests.sh > _work/p21_run.txt 2>&1; echo "tests exit=$?"; tail -1 _work/p21_run.txt; echo "SCRIPT ERROR: $(grep -c 'SCRIPT ERROR' _work/p21_run.txt)"
godot --headless --path game --import > _work/p21_imp.txt 2>&1; echo "import exit=$?"
git status --short | sort
git add game/ui/field/field_guide.gd.uid game/tools/field_guides.gd.uid game/tools/field_capture.gd.uid
git commit -m "chore: 版式图、截图工具脚本的 uid" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

预期：`共 472 个测试，失败 0 个`、`SCRIPT ERROR: 0`、`import exit=0`；`git status` 列出三个新 `.uid`。

- [ ] **Step 3：窗口模式截图看一遍**

Run: `rm -rf art_src/qa/field_*.png; timeout 180 godot --path game -s res://tools/field_capture.gd 2>&1 | tail -1`

预期：`共截图 9`；打开 `art_src/qa/field_*.png` 看：车厢开场对话框有张杰的大立绘；八个地点都有灯光，楼梯井、冷冻仓库、下水道是黑的、只有手电筒光锥；主机房的火焰女皇发红光；队友站在主角身后。

- [ ] **Step 4：更新 README 进度并提交**

```bash
python -I -X utf8 - <<'EOF'
p = "README.md"
s = open(p, encoding="utf-8").read()
o = "- 制作节奏：按原著顺序"
n = "- 计划 21（探索画面的氛围和正式图接口：每个地点有环境光和灯，黑暗地点只剩手电筒光锥，人物有影子；对话框改成大立绘加打字效果；面前能互动的东西有提示；Codex 画的整张地图和四方向行走图放进 `game/art/field/` 就自动替换占位；给 Codex 的版式图、对位图、截图工具和任务卡 007）已完成，累计 472 个无界面测试。\n" + o
assert s.count(o) == 1
open(p, "w", encoding="utf-8", newline="\n").write(s.replace(o, n))
print("ok")
EOF
git add README.md
git commit -m "docs: 计划 21 完成，更新进度" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log --oneline -5
git status --short
```

- [ ] **Step 5：验收检查**

```bash
grep -c $'\r' game/ui/field/field_screen.gd game/data/maps/biohazard1.json docs/codex-tasks/007-m1-field-art.md
for f in data/maps/biohazard1.json ui/field/field_map.gd ui/field/field_art.gd ui/field/field_guide.gd ui/field/field_screen.gd tools/field_guides.gd tools/field_capture.gd tests/unit/ui/test_field.gd; do cmp -s "game/$f" "_work/plan_check_p21/game/$f" || echo "DIFF $f"; done
cmp -s docs/codex-tasks/007-m1-field-art.md _work/plan_check_p21/docs/codex-tasks/007-m1-field-art.md || echo "DIFF card"
echo "compare done"
test -z "$(git diff --name-only origin/main..HEAD | grep -iE '\.(png|jpe?g|webp|gif|wav|ogg)$')" && echo "no media"
```

预期：三个 `grep -c` 都是 `0`；`compare done` 前没有 `DIFF`；`no media`。
