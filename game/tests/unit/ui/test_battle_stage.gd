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
