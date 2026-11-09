# 计划 18：像素战斗舞台 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 回到用户定下的美术方向（规格 11："战斗什么的只要 2D 像素人就可以"）：战斗不再是一屏卡片，而是 480×270 的像素舞台整数放大 4 倍铺满屏幕，Q 版像素小人站在地面上，按战斗事件出手、受击、倒地；界面和中文按原生分辨率叠在上面。缺正式美术的单位先用代码画的全身小人占位，正式的小人和背景由 Codex 按新任务卡 006 生成。

**Architecture:** 新增两个界面层脚本：`ui/battle/sprite_source.gd` 决定每个单位、每个地点用哪套图（`art/battle/` 下的正式图 → 像素试验留下的郑吒和研究员丧尸 → 代码画的全身小人；背景同理，最后退到代码画的墙和地面），并先确认 `.tres` 引用的 PNG 在本机（图片不进仓库）；`ui/battle/battle_stage.gd` 是 SubViewport 像素层：放背景、按排和槽位摆小人、按战斗事件用 Tween 播出手前冲、受击闪白后仰、治疗泛绿、倒地，黑暗战斗整体压暗；脚下的血条和当前行动者的名字在原生覆盖层。`battle_screen.gd` 改成"舞台在底、半透明面板在上"：顶栏、左右名单、中间行动列表和日志。`BattleView.units()` 多给角色 id 和敌人种类。规则层不动。

**Tech Stack:** Godot 4.7.2（SubViewport、AnimatedSprite2D、SpriteFrames、Tween）、像素试验（任务卡 003）的调色板与图集规格。

**依据：** 设计规格 11（玩法画面全部用像素；内部 480×270、SubViewport 整数放大 4 倍、最近邻；界面和文字不进像素层；战斗小人 48×48 单帧、约 32px 高、我方朝右敌方朝左、待机/攻击/受击/倒地；背景下方约 40% 是地面，会动的危险不画进背景）。

**本计划已在临时目录跑通：456 个无界面测试全过、`SCRIPT ERROR 0`、M1 切片验收 0 失败；窗口模式截图确认像素舞台、占位小人、试验图集都按规格显示。**

**执行环境注意：**
- 仓库根目录：`I:\workspace\mobilegame\wuxian-kongbu\`；命令都在仓库根目录执行（Git Bash）。
- 只跑某个测试：`WSLENV=TEST_FILTER TEST_FILTER=<文件名> bash game/tools/run_tests.sh`。
- 文本文件 **LF**、UTF-8 无 BOM；GDScript 用 **Tab**。
- 跑测试不生成 `.gd.uid`，导入工程（Task 2）才会。
- **只提交，不推送。**
- 临时验证目录是 `_work/plan_check_p18/game`（任务卡在 `_work/plan_check_p18/docs/`）。
- **切片验收会清空 `user://` 下的三个存档槽**，只在改了工程名的副本里跑（Task 2 Step 2）。

---

## 设计要点

- **像素层与原生层分开**：背景和小人在 480×270 的 SubViewport 里（最近邻、像素对齐），整张纹理用 TextureRect 放大到 1920×1080；血条、名字、名单、按钮、日志都是普通 Control，按原生分辨率画，中文不糊。
- **站位**：我方在左、敌方在右，前排（row 0）离中线最近，每排往后 52px；同一排最多 4 人，往下 17px、往外 14px 错开表现纵深；脚底都落在下方 40% 的地面上。z 顺序按脚底高度。
- **人多不挤**：场上只给每个人脚下一条血条，名字只标当前行动者；完整的名字、生命、恐惧、弹药、状态在左右两列名单里。
- **动作由事件驱动**：`action`（技能）→ 出手者朝前冲 6px 再回来、播 attack；`damage` → 目标闪白、后仰 3px、播 hit；`heal` → 泛绿；`death` → 倒地（有逐帧就播 down，静态占位就转 90° 压暗）。逻辑上的死亡（`dead`）和画面上的倒地（`laid`）分开记：动画还在播时，倒地排在动画后面，免得受击闪色冲掉倒地的灰色。不在场景树里（无界面测试）时只摆姿势不播动画。
- **缺图有退路，没有报错**：`.tres` 是文本、进仓库，但它引用的 PNG 只在本机；`SpriteSource.usable()` 先查依赖文件都在才加载。正式图到位后（任务卡 006）不用改代码。
- **图集对齐**：正方形单帧（人形 48，大型敌人更大）四边留 8px、脚踩在底边往上 8px；代码画的占位按底边对齐。

**不在本计划范围**：地点探索画面和主神空间改成像素场景（等任务卡 006 的背景到位后再做）；技能、道具、状态的像素图标；颗粒和暗角后处理；激光通道的效果层；文档对齐、平衡、`tr()`（计划 19）。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `game/ui/battle/sprite_source.gd` | 每个单位、每个地点用哪套图；依赖检查；代码画的全身小人和备用背景 |
| `game/ui/battle/battle_stage.gd` | 像素层、站位、血条与当前名字、按事件播动作、倒地 |
| `game/ui/battle/battle_screen.gd` | 舞台在底、半透明面板在上的新布局 |
| `game/ui/battle/battle_view.gd` | 单位列表多给角色 id 和敌人种类 |
| `game/ui/main.gd` | 开战时把地点传给战斗界面（选背景） |
| `docs/codex-tasks/006-m1-battle-sprites.md` | 给 Codex 的出图任务：7 个轮回者、4 种敌人、9 张背景 |

---

## Task 1：像素舞台

**Files:**
- Create: `game/ui/battle/sprite_source.gd`、`game/ui/battle/battle_stage.gd`
- Modify: `game/ui/battle/battle_screen.gd`、`game/ui/battle/battle_view.gd`、`game/ui/main.gd`
- Test: `game/tests/unit/ui/test_battle_stage.gd`（新）

- [ ] **Step 1：写测试 `game/tests/unit/ui/test_battle_stage.gd`**

```gdscript
extends "res://tests/test_case.gd"
## 像素战斗舞台：480×270 像素层、整数放大 4 倍、站位、缺图时的退路、按事件和单位状态摆姿势。

const SpriteSource = preload("res://ui/battle/sprite_source.gd")
const BattleStage = preload("res://ui/battle/battle_stage.gd")
const BattleScreen = preload("res://ui/battle/battle_screen.gd")
const BattleView = preload("res://ui/battle/battle_view.gd")
const Battle = preload("res://core/battle/battle.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
const Character = preload("res://core/model/character.gd")
const Rng = preload("res://core/util/rng.gd")

const TRIAL_PNG := "res://art/pixel_test/zheng_zha/sprite-sheet-alpha.png"


func _battle(dark: bool = false) -> RefCounted:
	var hero := Character.new("hero", "英雄", {})
	var mate := Character.new("mate", "队友", {})
	var units: Array[RefCounted] = [
		UnitFactory.from_character(hero, "ally", 0, ["punch"], "player"),
		UnitFactory.from_character(mate, "ally", 1, ["punch"], "player"),
		UnitFactory.from_enemy("zombie", "zombie_1", 0),
		UnitFactory.from_enemy("zombie", "zombie_2", 0),
	]
	var b := Battle.new()
	b.setup(units, {"dark": dark}, Rng.new(3))
	return b


## 没有任何美术的单位：代码画的像素小人做一张静态 idle；没有的动作都退回 idle。
func test_static_fallback() -> void:
	var f := SpriteSource.frames("nobody_here", "ally")
	assert_true(f.has_animation("idle"))
	assert_eq(f.get_frame_count("idle"), 1)
	assert_false(SpriteSource.animated(f))
	assert_eq(SpriteSource.action_name(f, "attack"), "idle")
	assert_eq(SpriteSource.key_of("zombie_3", "", "zombie", "enemy"), "zombie")
	assert_eq(SpriteSource.key_of("zheng_zha", "zheng_zha", "", "ally"), "zheng_zha")


## 图集资源只有在它引用的 PNG 也在本机时才用（图片不进仓库）；背景总是 480×270。
func test_usable_and_background() -> void:
	assert_false(SpriteSource.usable("res://nope/sprite_frames.tres"))
	var trial := String(SpriteSource.TRIAL_FRAMES["zheng_zha"])
	assert_eq(SpriteSource.usable(trial), FileAccess.file_exists(TRIAL_PNG))
	assert_eq(Vector2i(SpriteSource.background("nowhere").get_size()), Vector2i(480, 270))
	var img := SpriteSource.fallback_background().get_image()
	assert_eq(img.get_size(), Vector2i(480, 270))
	assert_eq(img.get_pixel(240, 200), SpriteSource.FLOOR, "下面 40% 是地面")


## 舞台：像素层 480×270、最近邻、放大 4 倍铺满 1920×1080；我方在左、敌方在右，前排离中线近。
func test_stage_layout() -> void:
	var b := _battle()
	var view := BattleView.new(b)
	var stage := BattleStage.new()
	stage.setup(view.units(), "", false)
	assert_eq(stage.viewport.size, Vector2i(480, 270))
	assert_eq(stage.viewport.canvas_item_default_texture_filter, Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
	assert_eq(stage.display.size, Vector2(1920, 1080))
	assert_eq(stage.sprites.size(), 4)
	var hero: Vector2 = stage.feet["hero"]
	var mate: Vector2 = stage.feet["mate"]
	var z1: Vector2 = stage.feet["zombie_1"]
	assert_true(hero.x < 240.0 and z1.x > 240.0)
	assert_true(mate.x < hero.x, "后排在前排后面")
	assert_true(z1.y >= 162.0, "站在下面 40% 的地面上")
	assert_eq(stage.shade.color, Color.WHITE)
	assert_eq(String((stage.tags["hero"]["name"] as Label).text), "英雄")
	stage.free()


## 单位倒下：不在场景树里时直接摆成倒地姿势、名字变灰；黑暗中的战斗整体压暗。
func test_sync_lays_down_dead() -> void:
	var b := _battle(true)
	var view := BattleView.new(b)
	var stage := BattleStage.new()
	stage.setup(view.units(), "", true)
	assert_true(stage.shade.color != Color.WHITE)
	var z: RefCounted = b.field.get_unit("zombie_1")
	z.hp = 0.0
	z.alive = false
	stage.play([{"type": "death", "target": "zombie_1"}])
	stage.sync(view.units())
	assert_true(stage.dead.has("zombie_1"))
	assert_true(stage.laid.has("zombie_1"))
	var s: AnimatedSprite2D = stage.sprites["zombie_1"]
	if SpriteSource.animated(s.sprite_frames):
		assert_true(["down", "death"].has(String(s.animation)), "有逐帧动作时播倒地")
	else:
		assert_true(absf(s.rotation_degrees) > 45.0, "静态帧转倒")
	assert_false(stage.dead.has("hero"))
	stage.free()


## 战斗界面：舞台在最底下，左右名单各列一方，按行动能推进。
func test_battle_screen() -> void:
	var b := _battle()
	var screen := BattleScreen.new()
	screen.setup(b, "control")
	assert_true(screen.get_child(0) == screen.stage)
	assert_eq(screen.ally_list.get_child_count(), 2)
	assert_eq(screen.enemy_list.get_child_count(), 2)
	var before := (b.history as Array).size()
	screen.press_action(0)
	assert_true((b.history as Array).size() > before)
	screen.free()
```

- [ ] **Step 2：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_battle_stage bash game/tools/run_tests.sh | tail -3`

预期：`test_battle_stage.gd` 加载失败（`sprite_source.gd`、`battle_stage.gd` 还不存在），出现 `SCRIPT ERROR`。

- [ ] **Step 3：创建 `game/ui/battle/sprite_source.gd`**

```gdscript
extends RefCounted
## 战斗小人与战斗背景从哪来（设计规格 11：Q 版像素小人，单帧 48×48，我方朝右、敌方朝左；背景 480×270）。
## 小人按顺序找：
##   1. res://art/battle/<key>/sprite_frames.tres（任务卡 006 由 Codex 生成；图片只在本机，不进仓库）；
##   2. 像素试验（任务卡 003）留下的两套：郑吒、研究员丧尸（给普通丧尸用）；
##   3. 都没有就用代码画一张静态帧：人物画一个 Q 版全身小人（配色取 pixel_art.gd 的 PEOPLE），
##      敌人用 pixel_art.gd 的敌人图；动作靠位移和闪色补。
## .tres 是文本、进仓库，但它引用的 PNG 不进仓库，所以先查依赖是否都在，缺了就跳过，免得加载报错。
## 动作名统一成 idle / attack / hit / down；试验图里丧尸的倒地叫 death，按 down 用。

const PixelArt = preload("res://core/art/pixel_art.gd")

const ART_FRAMES := "res://art/battle/%s/sprite_frames.tres"
const ART_BG := "res://art/battle/bg_%s.png"
const TRIAL_FRAMES := {
	"zheng_zha": "res://art/pixel_test/zheng_zha/sprite_frames.tres",
	"zombie": "res://art/pixel_test/zombie_scientist/sprite_frames.tres",
}
const TRIAL_BG := "res://art/pixel_test/bg_lab_corridor_pixel.png"
const BG_SIZE := Vector2i(480, 270)
## 共用调色板里的几种颜色，画缺图时的备用背景。
const WALL_TOP := Color("0B0F1A")
const WALL_LOW := Color("20283B")
const FLOOR := Color("30384A")
const FLOOR_LINE := Color("263C54")
const HORIZON := Color("141B2B")

static var _frames_cache: Dictionary = {}


## 单位用哪套图：轮回者按角色 id，敌人按敌人种类（zombie_3 用 zombie）。
static func key_of(unit_id: String, character_id: String, def_id: String, side: String) -> String:
	if side == "ally":
		return character_id if character_id != "" else unit_id
	return def_id if def_id != "" else unit_id


static func frames(key: String, side: String) -> SpriteFrames:
	var ck := key + ":" + side
	if _frames_cache.has(ck):
		return _frames_cache[ck]
	var found: SpriteFrames = null
	for path: String in [ART_FRAMES % key, String(TRIAL_FRAMES.get(key, ""))]:
		if path == "" or not usable(path):
			continue
		var res := load(path) as SpriteFrames
		if res != null and res.has_animation("idle"):
			found = res
			break
	if found == null:
		found = _static_frames(key, side)
	_frames_cache[ck] = found
	return found


## 有没有真正的逐帧动作（代码画的静态帧只有一张 idle）。
static func animated(f: SpriteFrames) -> bool:
	return f.has_animation("attack") and f.get_frame_count("attack") > 1


## 动作名对不上时的替代：down 找不到就找 death，再找不到就 idle。
static func action_name(f: SpriteFrames, action: String) -> String:
	if f.has_animation(action):
		return action
	if action == "down" and f.has_animation("death"):
		return "death"
	return "idle"


## 战斗背景：art/battle/bg_<地点>.png → 像素试验的走廊 → 代码画的墙和地面。尺寸不对的不用。
static func background(location: String) -> Texture2D:
	for path: String in [ART_BG % location, TRIAL_BG]:
		if location == "" and path != TRIAL_BG:
			continue
		if usable(path):
			var tex := load(path) as Texture2D
			if tex != null and Vector2i(tex.get_size()) == BG_SIZE:
				return tex
	return fallback_background()


## 代码画的备用背景：上面是渐暗的墙，下面 40% 是地面（留给三排站位），地面有横线。
static func fallback_background() -> Texture2D:
	var img := Image.create(BG_SIZE.x, BG_SIZE.y, false, Image.FORMAT_RGBA8)
	var horizon := int(BG_SIZE.y * 0.6)
	for y in BG_SIZE.y:
		var c: Color
		if y < horizon:
			c = WALL_TOP.lerp(WALL_LOW, float(y) / float(horizon))
		elif y < horizon + 3:
			c = HORIZON
		else:
			c = FLOOR_LINE if (y - horizon) % 12 == 0 else FLOOR
		for x in BG_SIZE.x:
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## 资源存在、而且它依赖的文件（图集 PNG）也都在本机。
static func usable(path: String) -> bool:
	if not ResourceLoader.exists(path):
		return false
	for dep: String in ResourceLoader.get_dependencies(path):
		var cut := dep.rfind("res://")
		if cut < 0:
			continue
		var dep_path := dep.substr(cut).get_slice("::", 0)
		if not ResourceLoader.exists(dep_path) and not FileAccess.file_exists(dep_path):
			return false
	return true


static func _static_frames(key: String, side: String) -> SpriteFrames:
	var f := SpriteFrames.new()
	if f.has_animation("default"):
		f.rename_animation("default", "idle")
	elif not f.has_animation("idle"):
		f.add_animation("idle")
	var person := side == "ally" or PixelArt.PEOPLE.has(key)
	f.add_frame("idle", figure(key, side) if person else PixelArt.unit(key, side))
	f.set_animation_loop("idle", true)
	return f


## 代码画的 Q 版全身小人：24×34，约 2.5 头身，脚在最底一行；我方朝右，敌方朝左。
static func figure(key: String, side: String) -> Texture2D:
	var colors: Array = PixelArt.PEOPLE.get(key, ["#4a5568", "#e0bb95", "#2b2119"])
	var shirt := Color(String(colors[0]))
	var skin := Color(String(colors[1]))
	var hair := Color(String(colors[2]))
	var pants := shirt.darkened(0.55)
	var dark := PixelArt.DARK
	var img := Image.create(24, 34, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_box(img, 6, 0, 12, 12, dark)
	_box(img, 7, 1, 10, 10, skin)
	_box(img, 7, 1, 10, 3, hair)
	_box(img, 7, 4, 2, 3, hair)
	var eye := 12 if side == "ally" else 9
	_box(img, eye, 6, 1, 2, dark)
	_box(img, eye + 3, 6, 1, 2, dark)
	_box(img, 6, 12, 12, 12, dark)
	_box(img, 7, 12, 10, 11, shirt)
	_box(img, 4, 13, 3, 9, dark)
	_box(img, 5, 13, 2, 7, shirt)
	_box(img, 5, 20, 2, 2, skin)
	_box(img, 17, 13, 3, 9, dark)
	_box(img, 17, 13, 2, 7, shirt)
	_box(img, 17, 20, 2, 2, skin)
	_box(img, 7, 23, 10, 9, dark)
	_box(img, 8, 23, 3, 8, pants)
	_box(img, 13, 23, 3, 8, pants)
	_box(img, 7, 32, 4, 2, dark)
	_box(img, 13, 32, 4, 2, dark)
	return ImageTexture.create_from_image(img)


static func _box(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), c)
```

- [ ] **Step 4：创建 `game/ui/battle/battle_stage.gd`**

```gdscript
extends Control
## 像素战斗舞台（设计规格 11）：480×270 的 SubViewport，最近邻、整数放大 4 倍铺满 1920×1080。
## 像素层里只有背景和小人；脚下的血条和当前行动者的名字画在原生分辨率的覆盖层上，保证中文清晰
## （人多时名字会挤成一团，所以只给轮到的那个人标名字，其余的看两侧名单）。
## 只读 BattleView 给的单位列表，按战斗事件播动作（出手前冲、受击闪白后仰、治疗泛绿、倒地），不碰规则。

const SpriteSource = preload("res://ui/battle/sprite_source.gd")
const UiTheme = preload("res://ui/ui_theme.gd")

const PIXEL_SIZE := Vector2i(480, 270)
const SCALE := 4
## 站位（像素层坐标，脚底点）：前排离中线近；同一排往下、往外错开，表现纵深。
const ALLY_FRONT_X := 196.0
const ENEMY_FRONT_X := 284.0
const ROW_GAP := 52.0
const SLOT_DX := 14.0
const SLOT_DY := 17.0
const FOOT_Y := 190.0
## 图集单帧是正方形（人形 48×48，大型敌人更大），四边留 8px 安全边、脚踩在底边往上 8px（任务卡 003 的统一基线：48 格脚在第 40 行）。
const CELL := 48
const CELL_MARGIN := 8.0
## 每一步动作的时长（秒）。
const STEP := 0.09

var viewport: SubViewport
var display: TextureRect
var background: Sprite2D
var shade: CanvasModulate
var overlay: Control
## 单位 id → AnimatedSprite2D / {"name": Label, "hp": ProgressBar} / 脚底点（像素层）/ 朝向（我方 1、敌方 −1）。
var sprites: Dictionary = {}
var tags: Dictionary = {}
var feet: Dictionary = {}
var facing: Dictionary = {}
## dead：已经知道不在场的单位（逻辑）；laid：已经摆成倒地姿势的（画面）。动画播完前两者可能不一致。
var dead: Dictionary = {}
var laid: Dictionary = {}
var _tween: Tween


## units：BattleView.units() 的结果；location：战斗地点（选背景）；dark：黑暗中的战斗整体压暗。
func setup(units: Array[Dictionary], location: String = "", dark: bool = false) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.size = PIXEL_SIZE
	viewport.disable_3d = true
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.snap_2d_transforms_to_pixel = true
	viewport.snap_2d_vertices_to_pixel = true
	add_child(viewport)
	background = Sprite2D.new()
	background.centered = false
	background.texture = SpriteSource.background(location)
	viewport.add_child(background)
	shade = CanvasModulate.new()
	shade.color = Color(0.5, 0.5, 0.62) if dark else Color.WHITE
	viewport.add_child(shade)
	display = TextureRect.new()
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.position = Vector2.ZERO
	display.size = Vector2(PIXEL_SIZE * SCALE)
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	_place_units(units)
	sync(units)


## 每排一个 slot 计数：前排 row 0 离中线最近。
static func foot_of(side: String, row: int, slot: int) -> Vector2:
	if side == "ally":
		return Vector2(ALLY_FRONT_X - row * ROW_GAP - slot * SLOT_DX, FOOT_Y + slot * SLOT_DY)
	return Vector2(ENEMY_FRONT_X + row * ROW_GAP + slot * SLOT_DX, FOOT_Y + slot * SLOT_DY)


func _place_units(units: Array[Dictionary]) -> void:
	var slots := {}
	for u: Dictionary in units:
		var id := String(u["id"])
		var side := String(u["side"])
		var row := int(u["row"])
		var k := "%s:%d" % [side, row]
		var slot := int(slots.get(k, 0))
		slots[k] = slot + 1
		var foot := foot_of(side, row, slot)
		feet[id] = foot
		facing[id] = 1.0 if side == "ally" else -1.0
		var key := SpriteSource.key_of(id, String(u.get("character_id", "")), String(u.get("def_id", "")), side)
		var s := AnimatedSprite2D.new()
		s.name = id
		s.sprite_frames = SpriteSource.frames(key, side)
		s.centered = false
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.position = _sprite_origin(s, foot)
		s.z_index = int(foot.y)
		s.play("idle")
		viewport.add_child(s)
		sprites[id] = s
		var hp := UiTheme.bar(UiTheme.OK, 6)
		hp.size = Vector2(80, 6)
		hp.position = Vector2(foot.x * SCALE - 40.0, foot.y * SCALE + 4.0)
		overlay.add_child(hp)
		var name := UiTheme.label(String(u["name"]), 16, UiTheme.ACCENT2)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.size = Vector2(160, 22)
		name.position = Vector2(foot.x * SCALE - 80.0, foot.y * SCALE + 12.0)
		name.visible = false
		overlay.add_child(name)
		tags[id] = {"name": name, "hp": hp}


## 图集帧（正方形、至少 48）按统一脚底基线对齐；代码画的静态帧按底边对齐。
func _sprite_origin(s: AnimatedSprite2D, foot: Vector2) -> Vector2:
	var tex := s.sprite_frames.get_frame_texture("idle", 0)
	var size := tex.get_size() if tex != null else Vector2(CELL, CELL)
	if int(size.x) == int(size.y) and int(size.x) >= CELL:
		return foot - Vector2(size.x / 2.0, size.y - CELL_MARGIN)
	return foot - Vector2(size.x / 2.0, size.y)


## 按单位列表刷新血条、名字颜色、当前行动者高亮；死了的摆成倒地姿势。
func sync(units: Array[Dictionary]) -> void:
	for u: Dictionary in units:
		var id := String(u["id"])
		if not tags.has(id):
			continue
		var hp: ProgressBar = tags[id]["hp"]
		hp.max_value = maxf(float(u["hp_max"]), 1.0)
		hp.value = maxf(float(u["hp"]), 0.0)
		hp.add_theme_stylebox_override("fill", UiTheme.bar_fill(UiTheme.ACCENT if hp.value / hp.max_value < 0.3 else UiTheme.OK))
		var name: Label = tags[id]["name"]
		var gone := not bool(u["alive"]) or bool(u.get("fled", false))
		name.visible = bool(u["current"])
		hp.visible = not gone
		if gone and not dead.has(id):
			dead[id] = true
			# 动画还在播：等它播到这里再倒下，免得受击闪色把倒地的灰色冲掉。
			if _tween != null and _tween.is_valid() and _tween.is_running():
				_tween.tween_callback(_lay_down.bind(id, bool(u.get("fled", false))))
			else:
				_lay_down(id, bool(u.get("fled", false)))


## 按一批战斗事件播动作；不在场景树里（无界面测试）时直接跳过，状态由 sync 摆正。
func play(events: Array) -> void:
	if not is_inside_tree():
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	var steps := 0
	for e: Dictionary in events.slice(maxi(0, events.size() - 30)):
		match String(e.get("type", "")):
			"action":
				var act: Dictionary = e.get("action", {})
				if String(act.get("type", "")) == "skill":
					steps += _lunge(String(e["unit"]))
			"damage":
				steps += _flash(String(e["target"]), Color(2.2, 2.2, 2.2), true)
			"heal":
				steps += _flash(String(e["target"]), Color(0.6, 1.8, 0.7), false)
			"death":
				var id := String(e["target"])
				if sprites.has(id) and not laid.has(id):
					_tween.tween_callback(_lay_down.bind(id, false))
					steps += 1
	if steps == 0:
		_tween.kill()
		return
	_tween.tween_callback(_back_to_idle)


func _lunge(id: String) -> int:
	if not sprites.has(id) or laid.has(id):
		return 0
	var s: AnimatedSprite2D = sprites[id]
	var home := _sprite_origin(s, feet[id])
	_tween.tween_callback(s.play.bind(SpriteSource.action_name(s.sprite_frames, "attack")))
	_tween.tween_property(s, "position", home + Vector2(6.0 * float(facing[id]), 0.0), STEP)
	_tween.tween_property(s, "position", home, STEP)
	return 1


func _flash(id: String, color: Color, knock: bool) -> int:
	if not sprites.has(id) or laid.has(id):
		return 0
	var s: AnimatedSprite2D = sprites[id]
	var home := _sprite_origin(s, feet[id])
	if knock:
		_tween.tween_callback(s.play.bind(SpriteSource.action_name(s.sprite_frames, "hit")))
	_tween.tween_property(s, "modulate", color, STEP * 0.5)
	if knock:
		_tween.parallel().tween_property(s, "position", home - Vector2(3.0 * float(facing[id]), 0.0), STEP * 0.5)
	_tween.tween_property(s, "modulate", Color.WHITE, STEP)
	if knock:
		_tween.parallel().tween_property(s, "position", home, STEP)
	return 1


## 倒地：有逐帧动作就播 down/death；静态帧就转 90° 压暗。逃走的人直接淡出。
func _lay_down(id: String, fled: bool) -> void:
	if not sprites.has(id) or laid.has(id):
		return
	dead[id] = true
	laid[id] = true
	var s: AnimatedSprite2D = sprites[id]
	if fled:
		s.visible = false
		return
	if SpriteSource.animated(s.sprite_frames):
		var anim := SpriteSource.action_name(s.sprite_frames, "down")
		s.sprite_frames.set_animation_loop(anim, false)
		s.play(anim)
	else:
		s.rotation_degrees = -90.0 * float(facing[id])
		s.position = feet[id] - Vector2(0.0, 6.0)
	s.modulate = Color(0.55, 0.55, 0.6)


func _back_to_idle() -> void:
	for id: String in sprites:
		if not dead.has(id):
			var s: AnimatedSprite2D = sprites[id]
			s.play("idle")
			s.position = _sprite_origin(s, feet[id])
			s.modulate = Color.WHITE
```

- [ ] **Step 5：改写 `game/ui/battle/battle_view.gd`**

```gdscript
extends RefCounted
## 战斗界面的取数层：把 Battle 的状态整理成单位卡、时间轴和可点的行动列表。
## 界面只调用 act(index)，拿回事件；规则全在 core/battle。

const BattleData = preload("res://core/battle/battle_data.gd")
const EventText = preload("res://ui/event_text.gd")

var b: RefCounted
var names: Dictionary = {}


func _init(battle: RefCounted) -> void:
	b = battle
	for u: RefCounted in b.field.units:
		names[u.id] = u.display_name


func current() -> Dictionary:
	if b.current == null:
		return {}
	return {"id": b.current.id, "name": b.current.display_name}


func finished() -> bool:
	return b.outcome != "ongoing"


func outcome() -> String:
	return b.outcome


## 战斗目标：守门/撑时间，还是清场。
func objective() -> String:
	if b.survive_until >= 0.0:
		return "守住这里：撑到时间轴 %d（现在 %d）" % [int(b.survive_until), int(b.ctb.now)]
	return "消灭所有敌人"


## 敌人下一步想干什么；判断力越高，看到得越多（0 只知道要动，1 知道技能，2 知道目标）。
func intents() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u: RefCounted in b.field.units:
		if u.side != "enemy" or not u.in_play():
			continue
		var v: Dictionary = b.intent_view(u.id, b.intel)
		var text := "准备行动"
		if bool(v.get("known", false)):
			var kind := String(v.get("kind", ""))
			if kind == "attack" or kind == "support":
				text = String(v.get("skill_name", "攻击"))
				if v.has("targets"):
					var who: Array[String] = []
					for t in v["targets"]:
						who.append(_target_label(String(t)))
					text += " → " + "、".join(who)
			else:
				text = "换位或防御"
		out.append({"id": u.id, "name": _short_name(u.id), "text": text})
		if out.size() >= 4:
			break
	return out


func timeline() -> Array[String]:
	var out: Array[String] = []
	for id: String in b.timeline(8):
		out.append(String(names.get(id, id)))
	return out


## 战场上的单位，己方在前、敌方在后；同一边按排、再按 id 排。
func units() -> Array[Dictionary]:
	var list: Array = b.field.units.duplicate()
	list.sort_custom(func(a: RefCounted, c: RefCounted) -> bool:
		if a.side != c.side:
			return a.side == "ally"
		if a.row != c.row:
			return a.row < c.row
		return a.id < c.id)
	var out: Array[Dictionary] = []
	for u: RefCounted in list:
		var statuses := _status_names(u)
		if u.side == "ally" and u.controller == "ai":
			statuses.insert(0, "不听指挥")
		out.append({
			"id": u.id,
			"name": _short_name(u.id),
			"character_id": u.character_id,
			"def_id": u.def_id,
			"side": u.side,
			"row": u.row,
			"hp": u.hp,
			"hp_max": u.hp_max,
			"fear": u.fear,
			"alive": u.alive,
			"fled": u.fled,
			"current": b.current != null and b.current.id == u.id,
			"statuses": statuses,
			"ammo": int(u.resources.get("ammo", -1)),
		})
	return out


func _status_names(u: RefCounted) -> Array[String]:
	var out: Array[String] = []
	var all := BattleData.statuses()
	for s: Dictionary in u.statuses:
		var id := String(s["id"])
		out.append(String((all[id] as Dictionary).get("name", id)) if all.has(id) else id)
	return out


## 可点的行动，每项带序号；act(index) 用同一个序号。
func actions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var legal: Array[Dictionary] = b.legal_actions()
	for i in legal.size():
		out.append({"index": i, "label": _label(legal[i])})
	return out


## 同一技能对多个目标时合成一组，界面先选技能再选目标，免得二十个一样的按钮。
func groups() -> Array[Dictionary]:
	var legal: Array[Dictionary] = b.legal_actions()
	var order: Array[String] = []
	var by_key := {}
	for i in legal.size():
		var key := _group_key(legal[i])
		if not by_key.has(key):
			by_key[key] = {"key": key, "label": "", "indices": []}
			order.append(key)
		(by_key[key]["indices"] as Array).append(i)
	var out: Array[Dictionary] = []
	for key in order:
		var g: Dictionary = by_key[key]
		var idx: Array = g["indices"]
		g["label"] = _label(legal[int(idx[0])]) if idx.size() == 1 else "%s（%d 个目标）" % [_skill_name(legal[int(idx[0])]), idx.size()]
		out.append(g)
	return out


func _group_key(a: Dictionary) -> String:
	var t := String(a["type"])
	if t == "skill":
		return "skill:" + String(a["skill"])
	if t == "move":
		return "move:%d" % int(a["row"])
	return t


func _skill_name(a: Dictionary) -> String:
	var skill := String(a.get("skill", ""))
	return String(BattleData.skill(skill).get("name", skill))


func _label(a: Dictionary) -> String:
	var t := String(a["type"])
	match t:
		"skill":
			var title := _skill_name(a)
			var who: Array[String] = []
			for id: String in a.get("targets", []):
				who.append(_target_label(id))
			return "%s → %s" % [title, "、".join(who)] if not who.is_empty() else title
		"move":
			return "换到第 %d 排" % (int(a["row"]) + 1)
		"defend":
			return "防御"
		"gene_lock":
			return "开启基因锁"
		"retreat":
			return "撤退"
	return t


## 只带编号的名字，给意图面板用。
func _short_name(id: String) -> String:
	var name := String(names.get(id, id))
	var tail := id.get_slice("_", id.get_slice_count("_") - 1)
	if tail.is_valid_int():
		name += "#" + tail
	return name


## 目标标签：名字后面加编号和剩余生命，十个丧尸才分得清。
func _target_label(id: String) -> String:
	var name := _short_name(id)
	var tail := id.get_slice("_", id.get_slice_count("_") - 1)
	if tail.is_valid_int():
		name += "#" + tail
	var u: RefCounted = b.field.get_unit(id)
	if u != null:
		name += "（%d）" % int(u.hp)
	return name


func act(index: int) -> Array[Dictionary]:
	var legal: Array[Dictionary] = b.legal_actions()
	if index < 0 or index >= legal.size():
		return []
	return b.act(legal[index])


func log_tail(n: int = 6) -> Array[String]:
	var out: Array[String] = []
	var start := maxi(0, b.history.size() - n)
	for i in range(start, b.history.size()):
		var line := EventText.describe(b.history[i], names)
		if line != "":
			out.append(line)
	return out
```

- [ ] **Step 6：改写 `game/ui/battle/battle_screen.gd`**

```gdscript
extends Control
## 战斗界面（M1 可玩层）：铺满全屏的像素战斗舞台（battle_stage.gd），上面叠原生分辨率的界面——
## 顶栏（轮到谁、时间轴、敌方意图）、左右两列名单（血、恐惧、弹药、状态）、中间的行动列表和战斗日志。
## 先选技能再选目标；只调用 BattleView；规则和 AI 在 core/battle。

signal finished

const BattleView = preload("res://ui/battle/battle_view.gd")
const BattleStage = preload("res://ui/battle/battle_stage.gd")
const UiTheme = preload("res://ui/ui_theme.gd")
const PixelArt = preload("res://core/art/pixel_art.gd")
const Sfx = preload("res://core/audio/sfx.gd")

## 半透明面板：压在像素画面上，看得清字也不完全挡住背景。
const GLASS := Color(0.04, 0.05, 0.08, 0.78)

var view: RefCounted
var stage: Control
var header: Label
var timeline_label: Label
var enemy_list: VBoxContainer
var ally_list: VBoxContainer
var action_box: VBoxContainer
var log_label: RichTextLabel
var intent_label: Label
var cards: Dictionary = {}
var open_indices: Array = []
var _done := false


## location：战斗地点（选像素背景）。
func setup(battle: RefCounted, location: String = "") -> void:
	view = BattleView.new(battle)
	_build(location, bool(battle.dark))
	refresh()


func _glass(pos: Vector2, size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.size = size
	var sb := StyleBoxFlat.new()
	sb.bg_color = GLASS
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	add_child(p)
	return p


func _build(location: String, dark: bool) -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	stage = BattleStage.new()
	stage.setup(view.units(), location, dark)
	add_child(stage)

	var top := _glass(Vector2(20, 12), Vector2(1880, 92))
	var top_box := VBoxContainer.new()
	top_box.add_theme_constant_override("separation", 2)
	top.add_child(top_box)
	header = UiTheme.label("战斗", 26, UiTheme.ACCENT)
	top_box.add_child(header)
	timeline_label = UiTheme.label("", 17, UiTheme.MUTED)
	top_box.add_child(timeline_label)
	intent_label = UiTheme.label("", 17, UiTheme.ACCENT2)
	top_box.add_child(intent_label)

	var left := _glass(Vector2(20, 116), Vector2(300, 520))
	ally_list = VBoxContainer.new()
	ally_list.add_theme_constant_override("separation", 4)
	left.add_child(ally_list)
	var right := _glass(Vector2(1600, 116), Vector2(300, 520))
	enemy_list = VBoxContainer.new()
	enemy_list.add_theme_constant_override("separation", 4)
	right.add_child(enemy_list)

	var action_panel := _glass(Vector2(340, 116), Vector2(1240, 300))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	action_panel.add_child(scroll)
	action_box = VBoxContainer.new()
	action_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_box.add_theme_constant_override("separation", 6)
	scroll.add_child(action_box)

	var log_panel := _glass(Vector2(340, 426), Vector2(1240, 210))
	log_label = UiTheme.rich(17)
	log_panel.add_child(log_label)


## 名单里的一行：像素头像 + 名字 + 血条 + 恐惧条 + 脚注（弹药/状态）。
func _card(u: Dictionary) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(276, 56)
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PANEL_LIGHT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	p.add_child(row)
	var face := TextureRect.new()
	face.texture = PixelArt.unit(String(u["id"]), String(u["side"]))
	face.custom_minimum_size = Vector2(30, 30)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(face)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 2)
	row.add_child(box)
	var name_label := UiTheme.label("", 15)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.clip_text = true
	box.add_child(name_label)
	var hp := UiTheme.bar(UiTheme.OK, 6)
	box.add_child(hp)
	var fear := UiTheme.bar(UiTheme.ACCENT2, 4)
	box.add_child(fear)
	var foot := UiTheme.label("", 12, UiTheme.MUTED)
	foot.clip_text = true
	foot.autowrap_mode = TextServer.AUTOWRAP_OFF
	foot.visible = false
	box.add_child(foot)
	cards[String(u["id"])] = {"name": name_label, "hp": hp, "fear": fear, "foot": foot}
	return p


func refresh() -> void:
	var cur: Dictionary = view.current()
	header.text = "战斗" + ((" · 轮到 " + String(cur["name"])) if not cur.is_empty() else "") + " ｜ " + view.objective()
	timeline_label.text = "时间轴：" + " → ".join(view.timeline())
	var intents: Array[String] = []
	for i: Dictionary in view.intents():
		intents.append("%s：%s" % [String(i["name"]), String(i["text"])])
	intent_label.text = "敌方意图（判断力 %d/2）：%s" % [int(view.b.intel), "；".join(intents)] if not intents.is_empty() else ""
	for list: VBoxContainer in [enemy_list, ally_list]:
		for c in list.get_children():
			list.remove_child(c)
			c.queue_free()
	var units: Array[Dictionary] = view.units()
	stage.sync(units)
	for u: Dictionary in units:
		var list: VBoxContainer = ally_list if String(u["side"]) == "ally" else enemy_list
		var p := _card(u)
		var c: Dictionary = cards[u["id"]]
		var name_label: Label = c["name"]
		name_label.text = "%s  %d/%d" % [String(u["name"]), int(maxf(float(u["hp"]), 0.0)), int(float(u["hp_max"]))]
		name_label.add_theme_color_override("font_color", UiTheme.TEXT if bool(u["alive"]) else UiTheme.MUTED)
		var hp_bar: ProgressBar = c["hp"]
		hp_bar.max_value = maxf(float(u["hp_max"]), 1.0)
		hp_bar.value = maxf(float(u["hp"]), 0.0)
		var hp_ratio := float(u["hp"]) / maxf(float(u["hp_max"]), 1.0)
		hp_bar.add_theme_stylebox_override("fill", UiTheme.bar_fill(UiTheme.ACCENT if hp_ratio < 0.3 else UiTheme.OK))
		var fear_bar: ProgressBar = c["fear"]
		fear_bar.max_value = 100.0
		fear_bar.value = clampf(float(u["fear"]), 0.0, 100.0)
		var foot: Label = c["foot"]
		var bits: Array[String] = []
		if int(u["ammo"]) >= 0:
			bits.append("弹 %d" % int(u["ammo"]))
		for st in u["statuses"]:
			bits.append(String(st))
		foot.text = " ".join(bits)
		foot.visible = foot.text != ""
		if bool(u["current"]):
			p.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PANEL_LIGHT, UiTheme.ACCENT, 8))
		elif not bool(u["alive"]):
			p.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.DARK, UiTheme.DARK, 8))
		list.add_child(p)

	for c in action_box.get_children():
		action_box.remove_child(c)
		c.queue_free()
	if view.finished():
		action_box.add_child(UiTheme.label("战斗结束：" + view.outcome(), 24, UiTheme.ACCENT2))
		if not _done:
			_done = true
			finished.emit.call_deferred()
		return
	var actions: Array[Dictionary] = view.actions()
	if not open_indices.is_empty():
		var back := UiTheme.button("← 返回", 18)
		back.pressed.connect(func() -> void:
			open_indices = []
			refresh())
		action_box.add_child(back)
		for i in open_indices:
			var b := UiTheme.button(String(actions[int(i)]["label"]), 18)
			b.pressed.connect(press_action.bind(int(i)))
			action_box.add_child(b)
	else:
		for g: Dictionary in view.groups():
			var b := UiTheme.button(String(g["label"]), 19)
			var indices: Array = g["indices"]
			if indices.size() == 1:
				b.pressed.connect(press_action.bind(int(indices[0])))
			else:
				b.pressed.connect(_open.bind(indices))
			action_box.add_child(b)
	log_label.text = "\n".join(view.log_tail(9))


func _open(indices: Array) -> void:
	open_indices = indices.duplicate()
	refresh()


func press_action(index: int) -> void:
	var before := (view.b.history as Array).size()
	view.act(index)
	var events: Array = (view.b.history as Array).slice(before)
	Sfx.play_for_events(events)
	stage.play(events)
	open_indices = []
	refresh()
```

- [ ] **Step 7：改写 `game/ui/main.gd`**

```gdscript
extends Control
## 游戏入口：标题画面 → 新游戏/读档 → 远征 → 战斗 → 结算 → 主神空间休整。
## 只做流程和换屏；远征与战斗的状态都在 Session / Expedition / Battle 里。
## 对话也在这里接线：AiService → Dialogue → 对话框，没配密钥就自动走离线兜底。
## PC 版外壳：标题画面、三个存档槽、设置、Esc 暂停菜单都在这里挂。

const Session = preload("res://core/session/session.gd")
const ExpeditionScreen = preload("res://ui/expedition/expedition_screen.gd")
const BattleScreen = preload("res://ui/battle/battle_screen.gd")
const HubScreen = preload("res://ui/hub/hub_screen.gd")
const UiTheme = preload("res://ui/ui_theme.gd")
const Battle = preload("res://core/battle/battle.gd")
const AiService = preload("res://ai/ai_service.gd")
const AiSettings = preload("res://ai/ai_settings.gd")
const HttpTransport = preload("res://ai/http_transport.gd")
const Persona = preload("res://ai/persona.gd")
const Dialogue = preload("res://core/dialogue/dialogue.gd")
const Gag = preload("res://core/dialogue/gag.gd")
const DialoguePanel = preload("res://ui/dialogue/dialogue_panel.gd")
const EventText = preload("res://ui/event_text.gd")
const DataLoader = preload("res://core/util/data_loader.gd")
const Slots = preload("res://core/save/slots.gd")
const Settings = preload("res://core/settings/settings.gd")
const TitleScreen = preload("res://ui/title_screen.gd")
const PauseMenu = preload("res://ui/pause_menu.gd")
const Sfx = preload("res://core/audio/sfx.gd")
const Cutscene = preload("res://ui/cutscene.gd")
const PortraitSource = preload("res://core/art/portrait_source.gd")
const Companion = preload("res://core/hub/companion.gd")

const ZHSHEN_FAQ := "res://data/ai/zhushen_faq.json"
## 主神不许说出口的词（校验层会拦，泄露就换离线回答）。
const ZHSHEN_FORBIDDEN: Array[String] = ["下一部", "剧情", "原著", "郑吒会"]

var session: RefCounted
var content: Control
var bar: ColorRect
var header: Label
var menu_button: Button
var battle_screen: Control = null
var title_screen: Control = null
var pause: Control = null
## 窗口模式与主音量，存 user://settings.json。
var settings: Dictionary = Settings.defaults()
## 自动存档：阶段/地点/天数一变就落盘，退出后"继续游戏"能接着玩。
var _auto_key := ""
## AI 接入层与对话层；离线时 ai.online() 为 false，全部走脚本兜底。
var ai: RefCounted
var dialogue: RefCounted
var panel: Control = null


func _ready() -> void:
	theme = UiTheme.build()
	_build_frame()
	add_child(Sfx.new())
	settings = Settings.load_settings()
	Settings.apply(settings)
	_show_title()


func _build_frame() -> void:
	UiTheme.paint_bg(self)
	bar = ColorRect.new()
	bar.color = UiTheme.PANEL
	bar.position = Vector2(0, 0)
	bar.size = Vector2(1920, 56)
	add_child(bar)
	header = UiTheme.label("无限恐怖", 24, UiTheme.ACCENT2)
	header.position = Vector2(30, 12)
	header.size = Vector2(1200, 34)
	add_child(header)

	menu_button = UiTheme.button("菜单（Esc）", 18)
	menu_button.position = Vector2(1700, 6)
	menu_button.size = Vector2(190, 44)
	menu_button.pressed.connect(_open_pause)
	add_child(menu_button)

	content = Control.new()
	content.position = Vector2(0, 56)
	content.size = Vector2(1920, 1024)
	add_child(content)

	_show_frame(false)


## 标题画面要整屏，游戏里让出顶部 56px 的状态栏。
func _show_frame(playing: bool) -> void:
	bar.visible = playing
	header.visible = playing
	menu_button.visible = playing
	content.position = Vector2(0, 56) if playing else Vector2(0, 0)
	content.size = Vector2(1920, 1024) if playing else Vector2(1920, 1080)


func _clear() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	battle_screen = null
	if panel != null:
		panel.queue_free()
		panel = null


func _names() -> Dictionary:
	var out := {}
	for id: String in session.game.characters:
		out[id] = session.game.characters[id].display_name
	return out


func _set_status(text: String) -> void:
	header.text = "无限恐怖 · M1 · " + text


func _show_expedition() -> void:
	_clear()
	var screen := ExpeditionScreen.new()
	screen.setup(session.expedition, _names())
	screen.battle_needed.connect(_on_battle_needed)
	screen.ended.connect(_on_expedition_ended)
	screen.talk_requested.connect(_on_talk)
	screen.persuade_requested.connect(_on_persuade_free)
	screen.cutscene_requested.connect(_on_cutscene)
	content.add_child(screen)
	_set_status("生化危机一")


func _on_battle_needed() -> void:
	if battle_screen != null or session.blocked_reason() != "battle":
		return
	var units: Array[RefCounted] = session.expedition.battle_units({})
	if units.is_empty():
		return
	var b := Battle.new()
	b.setup(units, session.expedition.battle_options(), session.game.rng)
	var screen := BattleScreen.new()
	screen.setup(b, String(session.expedition.st.pending_battle.get("location", "")))
	screen.finished.connect(_on_battle_finished.bind(b))
	_clear()
	content.add_child(screen)
	battle_screen = screen
	var loc := String(session.expedition.st.pending_battle.get("location", ""))
	_set_status("战斗中 · " + String(session.expedition.st.scenario.location(loc).get("name", loc)))


func _on_battle_finished(b: RefCounted) -> void:
	if battle_screen == null:
		return
	session.expedition.report_battle(b)
	battle_screen = null
	if session.phase == "expedition" and session.expedition_over():
		_on_expedition_ended()
	else:
		_show_expedition()


func _on_expedition_ended() -> void:
	if session.phase != "expedition":
		return
	var results: Dictionary = session.settle()
	if session.phase == "lost":
		_show_lost()
		return
	Sfx.play("coin")
	_show_result(results)


## 全员死亡：没有主神空间可回。铁人模式删档（失败就是失败）；宽松模式可以回标题读档。
func _show_lost() -> void:
	_clear()
	var box := VBoxContainer.new()
	box.position = Vector2(300, 160)
	box.size = Vector2(1320, 700)
	box.add_theme_constant_override("separation", 16)
	content.add_child(box)
	box.add_child(UiTheme.label("任务失败：全员死亡。", 36, UiTheme.ACCENT))
	for id: String in session.game.characters:
		var ch: RefCounted = session.game.characters[id]
		box.add_child(UiTheme.label("%s：%s" % [ch.display_name, String(ch.flags.get("death", ch.flags.get("erased", "死亡")))], 20, UiTheme.MUTED))
	if session.iron_man:
		Slots.erase(Slots.AUTO)
		box.add_child(UiTheme.label("铁人模式：失败就是失败。这一局的存档已经删除。", 22, UiTheme.TEXT))
	else:
		box.add_child(UiTheme.label("宽松模式：回到标题，从存档槽读回去再试一次。", 22, UiTheme.TEXT))
	var back := UiTheme.button("回到标题", 24)
	back.custom_minimum_size = Vector2(320, 60)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_show_title)
	box.add_child(back)
	_set_status("任务失败")


func _show_result(results: Dictionary) -> void:
	_clear()
	var box := VBoxContainer.new()
	box.position = Vector2(300, 90)
	box.size = Vector2(1320, 860)
	box.add_theme_constant_override("separation", 14)
	content.add_child(box)

	var title := UiTheme.label("任务结束：%s" % String(session.expedition.st.outcome), 34, UiTheme.ACCENT2)
	box.add_child(title)
	box.add_child(UiTheme.label("倒计时 %d 分钟 · 存活结算" % int(session.expedition.st.clock), 20, UiTheme.MUTED))
	var fr: Dictionary = session.film_report
	if not fr.is_empty():
		box.add_child(UiTheme.label("幸存 %d/%d · 主神评价 %d → %d" % [int(fr["survivors"]), int(fr["members"]), int(fr["rating_before"]), int(fr["rating_after"])], 20, UiTheme.MUTED))
		var guide := String(fr.get("tour_guide", ""))
		if guide != "":
			box.add_child(UiTheme.label("%s 带新人认识了光球和房间：规则百科新增 %d 条。" % [session.game.characters[guide].display_name, (fr.get("tour_entries", []) as Array).size()], 20, UiTheme.MUTED))
		else:
			box.add_child(UiTheme.label("没有老手带你们认识主神空间，规矩只能自己去问主神。", 20, UiTheme.MUTED))
	for id: String in results:
		var r: Dictionary = results[id]
		var name: String = session.game.characters[id].display_name if session.game.characters.has(id) else id
		if bool(r.get("dead", false)):
			box.add_child(UiTheme.label("%s：死亡（%s）" % [name, String(r.get("reason", ""))], 22, UiTheme.MUTED))
			continue
		var line := "%s：%d 点" % [name, int(r["final_points"])]
		var tickets: Array = r.get("tickets", [])
		if not tickets.is_empty():
			line += " · " + "、".join(tickets) + " 级支线"
		box.add_child(UiTheme.label(line, 24, UiTheme.TEXT))
	var go := UiTheme.button("进入主神空间", 24)
	go.custom_minimum_size = Vector2(320, 60)
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	go.pressed.connect(_on_enter_hub)
	box.add_child(go)
	_set_status("结算完成")


func _on_enter_hub() -> void:
	if session.enter_hub():
		_show_hub()


func _show_hub() -> void:
	if session.hub == null:
		return
	_clear()
	var screen := HubScreen.new()
	screen.setup(session)
	screen.departed.connect(_show_done)
	screen.zhushen_requested.connect(_on_ask_zhushen)
	screen.companion_talk_requested.connect(_on_companion_talk)
	content.add_child(screen)
	_set_status("主神空间")


func _show_done() -> void:
	_clear()
	var box := VBoxContainer.new()
	box.position = Vector2(300, 160)
	box.size = Vector2(1320, 600)
	box.add_theme_constant_override("separation", 16)
	content.add_child(box)
	box.add_child(UiTheme.label("二十道光柱降下。", 36, UiTheme.ACCENT2))
	for f: Dictionary in session.farewells:
		box.add_child(UiTheme.label("%s：「%s」" % [String(f["name"]), String(f["line"])], 24, UiTheme.TEXT))
	box.add_child(UiTheme.label("下一部：异形一（内容与界面在后续计划里做）。", 22, UiTheme.TEXT))
	_set_status("M1 结束")


## ---- 标题与存档槽 ----

func _show_title() -> void:
	session = null
	battle_screen = null
	_close_pause()
	_clear()
	_show_frame(false)
	var t := TitleScreen.new()
	t.set_settings(settings)
	t.new_game.connect(_new_game)
	t.load_slot.connect(_load_slot)
	t.quit_game.connect(_quit_game)
	t.settings_changed.connect(_on_settings_changed)
	content.add_child(t)
	title_screen = t


func _new_game(iron: bool = false) -> void:
	title_screen = null
	session = Session.new()
	session.start_m1(1, iron)
	_setup_ai()
	_show_frame(true)
	_show_expedition()


func _load_slot(slot: int) -> void:
	var s := Slots.read(slot)
	if s == null:
		_set_status("存档位 %d 读不出来" % slot)
		return
	title_screen = null
	session = s
	battle_screen = null
	_setup_ai()
	_show_frame(true)
	if session.phase == "expedition":
		_show_expedition()
	elif session.phase == "done":
		_show_done()
	else:
		_show_hub()


func _on_settings_changed(next: Dictionary) -> void:
	settings = next
	Settings.save_settings(settings)


## ---- 暂停菜单 ----

func _open_pause() -> void:
	if session == null or pause != null:
		return
	pause = PauseMenu.new()
	pause.resume.connect(_close_pause)
	pause.save_slot.connect(_on_save_slot)
	pause.load_slot.connect(_on_load_slot)
	pause.to_title.connect(_show_title)
	pause.quit_game.connect(_quit_game)
	add_child(pause)
	pause.set_iron_man(session.iron_man)
	pause.open_for("")


func _close_pause() -> void:
	if pause == null:
		return
	pause.queue_free()
	pause = null


func _on_save_slot(slot: int) -> void:
	if session == null or not session.can_save_manually():
		return
	var err: int = Slots.write(slot, session)
	if pause != null:
		pause.set_status("已保存到槽 %d" % slot if err == OK else "保存失败（%d）" % err)


func _on_load_slot(slot: int) -> void:
	_close_pause()
	_load_slot(slot)


func _quit_game() -> void:
	get_tree().quit()


## 自动存档：阶段、所在地点、休整天数任何一项变了就落一次盘。
## 只在远征/结算/休整里存，第一部结束（done）不覆盖旧档。
func _process(_delta: float) -> void:
	_autosave_tick()


func _autosave_tick() -> void:
	if session == null or String(session.phase) == "done" or String(session.phase) == "lost":
		return
	var key := auto_key()
	if key == _auto_key:
		return
	_auto_key = key
	Slots.write(Slots.AUTO, session)


## 当前应该落在自动档上的状态指纹（验收脚本与测试也用它）。
func auto_key() -> String:
	if session == null:
		return ""
	var loc := ""
	if String(session.phase) == "expedition":
		loc = _location_id()
	return "%s|%s|%d" % [String(session.phase), loc, int(session.day)]


## Esc：标题画面先关覆盖层；游戏里先关对话框，再关暂停菜单，最后打开暂停菜单。
func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.keycode != KEY_ESCAPE:
		return
	if title_screen != null and is_instance_valid(title_screen):
		if title_screen.handle_escape():
			accept_event()
		return
	if panel != null and is_instance_valid(panel):
		panel.press_close()
		accept_event()
		return
	if pause != null:
		_close_pause()
	else:
		_open_pause()
	accept_event()


## 建 AI 接入层（HTTP 节点挂在自己身上才能联网）和对话层；读档后重调一次即可换掉 store。
func _setup_ai() -> void:
	if ai == null:
		var transport := HttpTransport.new()
		transport.name = "AiTransport"
		add_child(transport)
		ai = AiService.new(AiSettings.load_settings(), transport)
	dialogue = Dialogue.new(ai, _personas(), session.dialogues)


func _personas() -> Dictionary:
	var out := {}
	for id: String in Persona.load_all():
		out[id] = Persona.from_data(id)
	return out


func _location_id() -> String:
	if session.expedition == null:
		return ""
	var st: RefCounted = session.expedition.st
	for sid: String in st.squads:
		if (st.squads[sid]["members"] as Array).has("zheng_zha"):
			return String(st.squads[sid]["location"])
	return String(st.scenario.data["start_location"])


func _location_name() -> String:
	var id := _location_id()
	if id == "":
		return ""
	return String(session.expedition.st.scenario.location(id).get("name", id))


func _situation() -> String:
	return dialogue.situation_text(_location_name(), int(session.expedition.st.clock))


## 当前屏如果是远征界面就返回它（说服要问它谁最适合开口）。
func _expedition_screen() -> Control:
	if content.get_child_count() == 0:
		return null
	var c: Control = content.get_child(content.get_child_count() - 1)
	return c if c.has_method("press_talk") else null


func _open_panel(title: String, subtitle: String, mode: String) -> void:
	if panel != null:
		panel.queue_free()
		panel = null
	var p := DialoguePanel.new()
	add_child(p)
	p.open_for(title, subtitle, mode)
	p.closed.connect(func() -> void:
		if panel == p:
			panel = null
		p.queue_free()
	)
	panel = p


func _source_text(source: String) -> String:
	match source:
		"ai":
			return "在线 · " + _model_name()
		"replay":
			return "回放（这句话说过）"
		"none":
			return "（没有这个人设）"
	return "离线 · 脚本台词"


func _model_name() -> String:
	if ai == null:
		return ""
	return String((ai.settings["tiers"]["fast"] as Dictionary).get("model", ""))


## 有图就播，没图直接跳过——不能因为缺一张 CG 把流程卡死。
func _on_cutscene(cg_name: String, text: String) -> void:
	var screen := _expedition_screen()
	if not PortraitSource.has_cg(cg_name):
		if screen != null:
			screen.press_cutscene_done()
		return
	var c := Cutscene.new()
	c.name = "Cutscene"
	add_child(c)
	c.open_for(cg_name, text)
	c.finished.connect(func() -> void:
		c.queue_free()
		if screen != null and is_instance_valid(screen):
			screen.press_cutscene_done()
	)


func _on_talk(npc_id: String) -> void:
	var title: String = dialogue.display_name(npc_id)
	_open_panel(title, "%s · 第 %d 分钟" % [_location_name(), int(session.expedition.st.clock)], "talk")
	var p: Control = panel
	p.set_portrait(npc_id)
	p.set_status("……")
	dialogue.say(npc_id, "", _situation(), func(res: Dictionary) -> void:
		if panel != p:
			return
		p.push(title, String(res["say"]))
		p.set_status(_source_text(String(res["source"])))
	)
	p.submitted.connect(_on_said.bind(npc_id))


func _on_said(text: String, npc_id: String) -> void:
	var p: Control = panel
	if p == null:
		return
	p.push("我", text)
	# 禁言：说漏了就在这句话下面当场结算，玩家立刻知道哪句中招。
	if Gag.is_leak(text):
		_push_events(session.expedition.leak("zheng_zha"), p)
	p.set_status("……")
	p.set_replies([])
	dialogue.say(npc_id, text, _situation(), func(res: Dictionary) -> void:
		if panel != p:
			return
		p.push(dialogue.display_name(npc_id), String(res["say"]))
		p.set_status(_source_text(String(res["source"])))
		_after_said(npc_id, p)
	)


## 说过话就涨信任；到剧本给的门槛，对方会说一句实话，可能给线索。队友还会对拍板的人多一点信任（关系网，有上限）。
func _after_said(npc_id: String, p: Control) -> void:
	var screen := _expedition_screen()
	if screen == null:
		return
	_push_events(session.talked(npc_id), p)
	var def: Dictionary = screen.view.trust_def(npc_id)
	if def.is_empty():
		return
	for ev: Dictionary in dialogue.add_trust(npc_id, 1, def):
		if String(ev.get("line", "")) != "":
			p.push(dialogue.display_name(npc_id), String(ev["line"]))
		_push_events(session.expedition.apply_effects(ev["effects"], _location_id()), p)
	screen.refresh()


func _push_events(events: Array, p: Control) -> void:
	var names := _event_names()
	for e: Dictionary in events:
		var text := EventText.describe(e, names)
		if text != "":
			p.push("（结果）", text)


## 事件文本要的不只是人名：地点、剧情事件、线索都得有中文名，不然日志里全是 id。
func _event_names() -> Dictionary:
	var out := _names()
	if session.expedition == null:
		return out
	var sc: RefCounted = session.expedition.st.scenario
	for loc_id: String in sc.data.get("locations", {}):
		out[loc_id] = String(sc.location(loc_id).get("name", loc_id))
	for ev: Dictionary in sc.events():
		out[String(ev["id"])] = String(ev.get("label", ev["id"]))
	for npc_id: String in sc.data.get("npcs", {}):
		out[npc_id] = String(sc.data["npcs"][npc_id].get("name", npc_id))
	for fact_id: String in sc.data.get("facts", {}):
		var f: Dictionary = sc.data["facts"][fact_id]
		var statement := String(f.get("statement", fact_id))
		out[fact_id] = statement
		for clue_id: String in f.get("clues", {}):
			out[clue_id] = statement
	return out


func _on_persuade_free() -> void:
	var screen := _expedition_screen()
	if screen == null:
		return
	var check: Dictionary = session.expedition.st.pending_check
	if check.is_empty():
		return
	if not bool(session.expedition.can_persuade(String(screen.view.best_thinker_id()))["ok"]):
		return
	var npc := String(check["npc"])
	_open_panel("%s · 说服" % dialogue.display_name(npc), String(check["goal"]), "persuade")
	panel.set_portrait(npc)
	panel.push("（局面）", "要让对方点头：%s" % String(check["goal"]))
	panel.persuading.connect(_on_persuade_text)


func _on_persuade_text(text: String) -> void:
	var p: Control = panel
	var screen := _expedition_screen()
	if p == null or screen == null:
		return
	var check: Dictionary = session.expedition.st.pending_check
	if check.is_empty():
		p.push("（提示）", "现在没有要说服的人。")
		return
	var npc := String(check["npc"])
	p.push("我", text)
	p.set_status("……")
	dialogue.rate(npc, text, String(check["goal"]), check.get("keywords", []), _situation(), func(res: Dictionary) -> void:
		if panel != p:
			return
		p.push("（判定）", "说服力 %d/3。%s" % [int(res["level"]), String(res["reason"])])
		_push_events(session.expedition.resolve_persuasion(int(res["level"])), p)
		p.set_status(_source_text(String(res["source"])))
		screen.refresh()
	)


func _on_ask_zhushen() -> void:
	_open_panel("主神", "巨大的光球悬在头顶，没有表情。", "talk")
	panel.set_portrait("zhushen")
	panel.push("主神", "问。")
	panel.submitted.connect(_on_zhushen_question)


func _on_zhushen_question(text: String) -> void:
	var p: Control = panel
	if p == null:
		return
	p.push("我", text)
	p.set_status("……")
	dialogue.ask_zhushen(text, _zhushen_faq(), ZHSHEN_FORBIDDEN, func(res: Dictionary) -> void:
		if panel != p:
			return
		p.push("主神", String(res["answer"]))
		p.set_status(_source_text(String(res["source"])))
		# 问到哪条规则，规则百科就记下哪条（主神只答规则，所以按关键词判，不看 AI 怎么措辞）。
		_push_events(session.game.codex.unlock_by_question(text), p)
	)


## 在房间里跟造物说话：人设来自造人时的设定（萝丽是 luo_li）；每天第一次说话涨亲密。
func _on_companion_talk(companion_id: String) -> void:
	var c := Companion.find(session.game, companion_id)
	var persona := String(c.get("persona", ""))
	if c.is_empty() or persona == "" or not dialogue.has_persona(persona):
		return
	_open_panel(String(c["name"]), "主神空间 · %s的房间" % session.game.characters[String(c["creator"])].display_name, "talk")
	var p: Control = panel
	p.set_portrait(persona)
	p.set_status("……")
	dialogue.say(persona, "", _room_situation(c), func(res: Dictionary) -> void:
		if panel != p:
			return
		p.push(String(c["name"]), String(res["say"]))
		p.set_status(_source_text(String(res["source"])))
	)
	p.submitted.connect(_on_companion_said.bind(companion_id))


func _on_companion_said(text: String, companion_id: String) -> void:
	var p: Control = panel
	var c := Companion.find(session.game, companion_id)
	if p == null or c.is_empty():
		return
	p.push("我", text)
	p.set_status("……")
	dialogue.say(String(c["persona"]), text, _room_situation(c), func(res: Dictionary) -> void:
		if panel != p:
			return
		p.push(String(c["name"]), String(res["say"]))
		p.set_status(_source_text(String(res["source"])))
		_push_events(session.hub.companion_talked(companion_id), p)
		var screen := content.get_child(0) if content.get_child_count() > 0 else null
		if screen != null and screen.has_method("press_visit"):
			screen.refresh()
	)


func _room_situation(c: Dictionary) -> String:
	return "主神空间，%s的房间。休整第 %d 天，再过 %d 天就要进下一部片。她现在的心情 %d、亲密 %d，她想：%s。" % [
		session.game.characters[String(c["creator"])].display_name, int(session.hub.day), int(session.hub.days_left()),
		int(float(c["mood"])), int(float(c["intimacy"])), Companion.wish(c)]


func _zhushen_faq() -> Array:
	var res := DataLoader.load_json(ZHSHEN_FAQ)
	if not res.ok:
		return []
	return (res.data as Dictionary).get("faq", [])
```

- [ ] **Step 8：运行，确认通过**

Run: `bash game/tools/run_tests.sh > _work/p18_task1.txt 2>&1; echo "exit=$?"; tail -1 _work/p18_task1.txt; echo "SCRIPT ERROR: $(grep -c 'SCRIPT ERROR' _work/p18_task1.txt)"`

预期：`共 456 个测试，失败 0 个`、`SCRIPT ERROR: 0`。

- [ ] **Step 9：提交**

```bash
git add game/ui/battle/sprite_source.gd game/ui/battle/battle_stage.gd game/ui/battle/battle_view.gd game/ui/battle/battle_screen.gd game/ui/main.gd game/tests/unit/ui/test_battle_stage.gd
git commit -m "feat(battle): 像素战斗舞台：480×270 放大 4 倍，像素小人按事件出手受击倒地，界面叠在原生层" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

## Task 2：出图任务卡与验收

**Files:**
- Create: `docs/codex-tasks/006-m1-battle-sprites.md`

- [ ] **Step 1：创建 `docs/codex-tasks/006-m1-battle-sprites.md`**

```markdown
# 任务卡 006：M1 战斗像素小人与战斗背景

## 目标
计划 18 把战斗画面换成了像素舞台（480×270 像素层，整数放大 4 倍），但现在只有像素试验（任务卡 003）留下的郑吒和研究员丧尸两套图，其余人物是代码画的占位小人。这张卡给《生化危机一》的战斗出正式的像素小人和战斗背景：**7 个轮回者 + 4 种敌人 + 9 张背景**。

做完之后不用改任何代码：游戏会自动找到 `game/art/battle/` 下的新图并替换占位。

## 先读
- `AGENTS.md`（尤其"图片不进仓库""只修改允许的路径"）
- 设计规格 `docs/superpowers/specs/2026-11-05-wuxian-kongbu-game-design.md` 第 11 节（像素玩法画面的尺寸、朝向、动作、背景构图）
- `docs/codex-tasks/003-pixel-style-test.md` 和 `docs/art/pixel-test-report.md`（已验收的流程、调色板、遇到的问题）
- `art_src/pixel_test/README.md`（003 的复现步骤）
- `game/ui/battle/sprite_source.gd`（游戏怎么找图：路径、动作名、缺图时的退路）

## 允许修改
- `game/art/battle/`（新建）
- `art_src/battle/`（新建：原图、中间文件、提示词、报告、QA）
- 本任务卡末尾的"完成汇报"

不要改 `game/` 下的任何代码、数据、测试，也不要改 `project.godot`。

## 产出路径与格式

| 类型 | 路径 | 格式 |
|---|---|---|
| 小人图集 | `game/art/battle/<id>/sprite-sheet-alpha.png` | RGBA 透明底，4 行 × 4 列，单帧正方形 |
| 图集说明 | `game/art/battle/<id>/manifest.json` | sprite-gen 原生 manifest |
| 动作资源 | `game/art/battle/<id>/sprite_frames.tres` | Godot SpriteFrames，动作名见下 |
| 战斗背景 | `game/art/battle/bg_<地点>.png` | 480×270，不透明 |
| 提示词、报告、QA | `art_src/battle/` | Markdown / JSON，含每个成品的 SHA-256 |

**动作名必须是** `idle`（4fps，循环）、`attack`、`hit`、`down`（6fps，不循环），每个 4 帧。行顺序 idle → attack → hit → down。敌人的倒地也叫 `down`（不要叫 `death`）。

**脚底基线**：单帧四边留 8px 安全边，脚踩在底边往上 8px 的那一行（48 格就是第 40 行，跟 003 一样，用 foot-centroid / bottom 对齐、ground_frames）。倒地帧自然变矮，不要拉伸到站立高度。

**朝向**：我方朝右，敌方朝左。不要靠镜像翻转出朝向。

## 清单

### 轮回者（朝右，单帧 48×48，人物约 32px 高，Q 版 2.5～3 头身）

| id | 人物 | 32px 下要看得出的特征（以 `game/art/portraits/<id>.png` 和 `art_src/prompts/<id>.md` 为准） |
|---|---|---|
| `zheng_zha` | 郑吒 | 黑短发、灰白短袖衬衫、深色裤子、手枪（可以从 003 的郑吒定稿出正式版） |
| `zhang_jie` | 张杰 | 寸头、深灰上衣、老兵体格、沙漠之鹰 |
| `zhan_lan` | 詹岚 | 长黑发、浅色外套 |
| `li_xiao_yi` | 李萧毅 | 瘦、校服外套 |
| `mu_gang` | 牟钢 | 壮、工装背心、手臂露出 |
| `xiao_pang_zi` | 小胖子 | 圆脸、T 恤、缩着肩 |
| `zhong_nian_fu_nv` | 中年妇女 | 针织外套、头发挽起 |

attack 按各自的招式画：郑吒、张杰是举枪射击（有枪口火光）；其他人是挥拳。

### 敌人（朝左）

| id | 敌人 | 单帧 | 要点 |
|---|---|---|---|
| `zombie` | 丧尸 | 48×48 | 普通丧尸（实验区员工、保安混搭的通用造型），苍白、衣服破烂；attack 是扑咬 |
| `zombie_dog` | 丧尸犬 | 48×48 | 四足，皮肉溃烂；attack 是扑咬 |
| `licker` | 爬行者 | 64×64 | 四足爬行、无皮肤肌肉外露、长舌、巨爪；attack 用爪击，体型明显比丧尸大 |
| `training_dummy` | 训练傀儡 | 48×48 | 主神空间训练场的金属假人；attack 四帧可以就是 idle 的轻微晃动 |

### 战斗背景（480×270，不透明，侧视宽景，下方约 40% 是平整开阔的地面）

| 文件 | 地点 | 要点 |
|---|---|---|
| `bg_car.png` | 高速车厢 | 地铁/高速列车车厢内部，冷蓝灯，座椅 |
| `bg_hall.png` | 蜂巢入口大厅 | 豪宅地下入口改造的大厅，大理石地面 |
| `bg_stairs.png` | 楼梯井 | 金属楼梯平台，管线 |
| `bg_laser.png` | 激光通道 | 白色金属走廊、尽头一道门；**不画激光**（激光由游戏做成效果层） |
| `bg_control.png` | 火焰女皇主机房 | 成排机柜、中央全息投影台（不画人） |
| `bg_corridor.png` | 实验区走廊 | 可以从 003 的走廊背景定稿 |
| `bg_freezer.png` | 冷冻仓库 | 冷柜、结霜、冷光 |
| `bg_sewer.png` | 下水道 | 拱形隧道、浅水、管口 |
| `bg_training.png` | 主神空间训练场 | 空旷的金属训练大厅，冷白光（以后给对练用） |

背景只画环境，不画人物、文字、UI；不要画会动的危险物（激光、火焰）。

## 流程（沿用 003）
1. 每个小人先依据动漫立绘出一张 Q 版像素基础图，再走 prepare → 原生 gen-set → extract → compose-atlas。统一 cell、logical_height、`pixel_unfake=true`、foot-centroid/bottom、ground_frames。
2. 首次 extract 前写入 `palette.lock.json`，颜色全部取自 `game/art/pixel_test/palette.hex`（32 色共用调色板）；关闭 outline。
3. 背景用 003 的整场景转换方式（`game/tools/pixelize_scene.py`）映射到同一调色板，不裁切、不抖动。
4. 生成 `sprite_frames.tres` 的方式同 003；动作名按本卡统一成 idle / attack / hit / down。
5. **只用 codex 登录渠道（sprite-gen `gen --provider codex`）。不要用 `pixel-draw`。** 如果 codex 渠道不可用，停下来在完成汇报里写明，等用户决定；不要自己切换到别的 provider 或按调用计费的接口。

## 分批做
- **第一批（先验收）**：`zheng_zha`、`zhang_jie`、`zombie`、`bg_control.png`。做完先停，等 Claude 看图确认。
- **第二批**：其余 5 个轮回者、`zombie_dog`、`licker`、`training_dummy`。
- **第三批**：其余 8 张背景。

## 验收标准
- 尺寸、透明、行列、动作名、帧数、fps 符合上表；颜色全部在共用调色板里。
- 朝向正确，脚底基线统一，站立高度约 32px（爬行者按体型）。
- 同一角色四个动作能看出是同一个人（发型、服装配色一致）；32px 看不清五官、手指是正常的，不要求。
- 背景地面在下方约 40%，没有人物、文字、激光。
- 在游戏里看效果：把 `game/` 复制到一个临时目录，**先把副本 `project.godot` 里的 `config/name` 改掉**（切片验收会清空存档槽，存档目录跟着工程名走），再在副本里运行
  `godot --path <副本>/game -s res://tools/verify_m1_slice.gd -- --capture`，
  截图在 `<副本>/art_src/qa/m1_slice_battle.png`，应该看到新的小人站在火焰女皇主机房背景上。
- 仓库根目录 `bash game/tools/run_tests.sh` 全部通过（只出图，测试数不变）。

## 不要做的事
- 不要把 png 提交进仓库（`git add -f` 也不行）；提交提示词、报告、manifest、`sprite_frames.tres` 和 SHA-256。
- 不要改游戏代码、数据、测试；不要动 `_work/`。
- 不要为了"更好看"改人物设定。

## 完成汇报
在本文件末尾追加：每批出了哪些、路径、尺寸、SHA-256、用了几次生图、遇到的问题；以及你认为描述有歧义、需要 Claude 补设定的地方。
```

- [ ] **Step 2：在改名的副本里跑切片验收（顺带截图）**

```bash
rm -rf _work/p18_verify && mkdir -p _work/p18_verify && cp -r game _work/p18_verify/game
sed -i 's/^config\/name=.*/config\/name="无限恐怖_验收p18"/' _work/p18_verify/game/project.godot
timeout 300 godot --headless --path _work/p18_verify/game -s res://tools/verify_m1_slice.gd 2>&1 | tail -3; echo "exit=${PIPESTATUS[0]}"
timeout 300 godot --path _work/p18_verify/game -s res://tools/verify_m1_slice.gd -- --capture 2>&1 | tail -1
ls _work/p18_verify/art_src/qa/m1_slice_battle.png
```

预期：两次都是 `M1 切片验证：失败 0 项`；截图里能看到像素背景、左边的我方小人、右边的丧尸、两侧名单和中间的行动列表。

- [ ] **Step 3：跑全量与导入**

```bash
bash game/tools/run_tests.sh > _work/p18_run.txt 2>&1; echo "tests exit=$?"; tail -1 _work/p18_run.txt; echo "SCRIPT ERROR: $(grep -c 'SCRIPT ERROR' _work/p18_run.txt)"
godot --headless --path game --import > _work/p18_imp.txt 2>&1; echo "import exit=$?"
git status --short | sort
```

预期：`共 456 个测试，失败 0 个`、`SCRIPT ERROR: 0`、`import exit=0`；`git status` 多出任务卡和三个 `.uid`（`sprite_source.gd.uid`、`battle_stage.gd.uid`、`test_battle_stage.gd.uid`）。

- [ ] **Step 4：提交任务卡与 uid**

```bash
git add docs/codex-tasks/006-m1-battle-sprites.md game/ui/battle/sprite_source.gd.uid game/ui/battle/battle_stage.gd.uid game/tests/unit/ui/test_battle_stage.gd.uid
git commit -m "docs(art): 任务卡 006，M1 战斗像素小人与战斗背景" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log --oneline -1
```

- [ ] **Step 5：更新 README 进度并提交**

```bash
python -I -X utf8 - <<'EOF'
p = "README.md"
s = open(p, encoding="utf-8").read()
o = "- 计划 17（萝丽有了心情、亲密、依赖、安心和愿望，能陪她、一起训练、AI 对话，走光柱时有告别；休整每天早上有晨会（结盟、新人去留等六件）；新游戏可选铁人模式，全员死亡显示失败画面、铁人模式删档）已完成，累计 451 个无界面测试。\n"
n = o + "- 计划 18（像素战斗舞台：480×270 放大 4 倍，Q 版像素小人站在地面上按事件出手、受击、倒地，界面叠在原生层；缺图时用代码画的全身小人占位；正式小人和背景见任务卡 006）已完成，累计 456 个无界面测试。\n"
assert s.count(o) == 1
open(p, "w", encoding="utf-8", newline="\n").write(s.replace(o, n))
print("ok")
EOF
git add README.md
git commit -m "docs: 计划 18 完成，更新进度" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log --oneline -1
git status --short
```

- [ ] **Step 6：验收检查**

```bash
git log --oneline -5
grep -c $'\r' game/ui/battle/battle_stage.gd game/ui/battle/sprite_source.gd docs/codex-tasks/006-m1-battle-sprites.md
for f in ui/battle/sprite_source.gd ui/battle/battle_stage.gd ui/battle/battle_view.gd ui/battle/battle_screen.gd ui/main.gd tests/unit/ui/test_battle_stage.gd; do cmp -s "game/$f" "_work/plan_check_p18/game/$f" || echo "DIFF $f"; done
cmp -s docs/codex-tasks/006-m1-battle-sprites.md _work/plan_check_p18/docs/codex-tasks/006-m1-battle-sprites.md || echo "DIFF task card"
echo "compare done"
test -z "$(git diff --name-only origin/main..HEAD | grep -iE '\.(png|jpe?g|webp|gif|wav|ogg)$')" && echo "no media"
```

预期：三个 `grep -c` 都是 `0`；`compare done` 前没有 `DIFF`；`no media`。
