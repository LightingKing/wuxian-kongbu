extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
const Battle = preload("res://core/battle/battle.gd")
const Statuses = preload("res://core/battle/statuses.gd")
const Rng = preload("res://core/util/rng.gd")


func _human(id: String, row: int, skills: Array[String], controller: String = "player", resources: Dictionary = {}) -> RefCounted:
	return UnitFactory.from_character(Character.new(id, id, {}), "ally", row, skills, controller, resources)


## 速度很慢的丧尸：测试里它基本不会抢在我方前面行动。
func _slow_zombie(id: String, hp: float = 40.0) -> RefCounted:
	var z := UnitFactory.from_enemy("zombie", id, 0)
	z.base_speed = 10.0
	z.hp = hp
	z.hp_max = hp
	return z


func _types(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for e in events:
		out.append(String(e["type"]))
	return out


func _find(events: Array[Dictionary], type: String) -> Dictionary:
	for e in events:
		if e["type"] == type:
			return e
	return {}


func test_setup_waits_for_player() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 0, skills)
	var b := Battle.new()
	var units: Array[RefCounted] = [h, _slow_zombie("z")]
	var events := b.setup(units, {}, Rng.new(1))
	assert_eq(events[0]["type"], "battle_start")
	assert_eq(b.outcome, "ongoing")
	assert_eq(b.current, h)
	assert_true(b.legal_actions().has({"type": "skill", "skill": "pistol_shot", "targets": ["z"]}))
	assert_eq(b.timeline(10).size(), 10)
	assert_eq(b.timeline(10)[0], "h")


## 爬行者登场：新人恐惧 +15；舌头先手，先于玩家行动。
func test_fear_aura_and_licker_first() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 0, skills)
	var licker := UnitFactory.from_enemy("licker", "l", 0)
	var b := Battle.new()
	var units: Array[RefCounted] = [h, licker]
	var events := b.setup(units, {}, Rng.new(3))
	var fear := _find(events, "fear_changed")
	assert_eq(fear["reason"], "enemy_appear")
	assert_almost(float(fear["amount"]), 15.0)
	var first_turn := _find(events, "turn_start")
	assert_eq(first_turn["unit"], "l")


func test_invalid_action_rejected() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 0, skills)
	var b := Battle.new()
	var units: Array[RefCounted] = [h, _slow_zombie("z")]
	b.setup(units, {}, Rng.new(1))
	var events := b.act({"type": "skill", "skill": "grenade", "targets": ["z"]})
	assert_eq(_types(events), ["invalid_action"] as Array[String])
	assert_eq(b.current, h)


func test_player_kills_zombie_and_wins() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 0, skills)
	var b := Battle.new()
	var units: Array[RefCounted] = [h, _slow_zombie("z", 1.0)]
	b.setup(units, {}, Rng.new(7))
	var guard := 0
	while b.outcome == "ongoing" and guard < 20:
		b.act({"type": "skill", "skill": "pistol_shot", "targets": ["z"]})
		guard += 1
	assert_eq(b.outcome, "victory")
	assert_eq(b.history[b.history.size() - 1], {"type": "battle_end", "outcome": "victory"})
	assert_true(_types(b.history).has("death"))


func test_enemy_intent_is_planned() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 0, skills)
	var b := Battle.new()
	var units: Array[RefCounted] = [h, _slow_zombie("z")]
	b.setup(units, {}, Rng.new(1))
	assert_eq(b.intent_view("z", 2), {"known": true, "kind": "attack", "skill": "zombie_bite", "skill_name": "撕咬", "targets": ["h"]})
	assert_eq(b.intent_view("z", 0), {"known": true, "kind": "attack"})


## 队友死亡：其他人恐惧 +20。
func test_ally_death_raises_fear() -> void:
	var none: Array[String] = []
	var dying := _human("dying", 0, none, "ai")
	dying.hp = 3.0
	Statuses.apply(dying, "bleed")
	var watcher := _human("watcher", 0, none)
	var b := Battle.new()
	var units: Array[RefCounted] = [dying, watcher, _slow_zombie("z")]
	var events := b.setup(units, {}, Rng.new(1))
	assert_false(dying.alive)
	assert_eq(_find(events, "death")["target"], "dying")
	var last_fear: Dictionary = {}
	for e in events:
		if e["type"] == "fear_changed" and e["target"] == "watcher":
			last_fear = e
	assert_eq(last_fear["reason"], "ally_death")
	assert_almost(watcher.fear, 3.0 + 20.0)
	assert_eq(b.current, watcher)


## 感染倒计时走完：变成丧尸，算死亡。
func test_infection_turns_ally() -> void:
	var none: Array[String] = []
	var bitten := _human("bitten", 0, none, "ai")
	Statuses.apply(bitten, "infection")
	bitten.statuses[0]["remaining"] = 1
	var other := _human("other", 0, none)
	var b := Battle.new()
	var units: Array[RefCounted] = [bitten, other, _slow_zombie("z")]
	var events := b.setup(units, {}, Rng.new(1))
	assert_true(bitten.turned)
	assert_eq(_find(events, "death"), {"type": "death", "target": "bitten", "turned": true})


## 持续伤害把生命打到 25% 以下，触发一次觉醒检定（成功或失败都会有事件）。
func test_low_hp_triggers_awaken_check() -> void:
	var none: Array[String] = []
	var h := _human("h", 0, none)
	h.hp = h.hp_max * 0.25 + 2.0
	Statuses.apply(h, "bleed")
	var b := Battle.new()
	var units: Array[RefCounted] = [h, _slow_zombie("z")]
	var events := b.setup(units, {}, Rng.new(1))
	var types := _types(events)
	assert_true(types.has("gene_lock_awaken") or types.has("awaken_failed"), str(types))
	assert_true(h.low_hp_checked)


## 恐慌时不听指挥：玩家的单位自动乱动，恐慌结束后才把控制权交回玩家。
func test_panic_takes_control() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 0, skills)
	Statuses.apply(h, "panic")
	var b := Battle.new()
	var units: Array[RefCounted] = [h, _slow_zombie("z", 500.0)]
	var events := b.setup(units, {}, Rng.new(5))
	var panic_count := 0
	for t in _types(events):
		if t.begins_with("panic_") or t == "fled":
			panic_count += 1
	assert_eq(panic_count, 2)
	assert_false(Statuses.has(h, "panic"))
	assert_eq(b.current, h)


func test_survive_until() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 0, skills, "ai")
	var z := UnitFactory.from_enemy("zombie", "z", 0)
	z.hp = 1000.0
	z.hp_max = 1000.0
	var b := Battle.new()
	var units: Array[RefCounted] = [h, z]
	b.setup(units, {"survive_until": 300.0}, Rng.new(2))
	assert_eq(b.outcome, "survived")
	assert_true(h.alive)


## 重生十字章：死亡时消耗一次，以 30% 生命复活。
func test_rebirth_cross_revives() -> void:
	var none: Array[String] = []
	var h := _human("h", 0, none, "player", {"rebirth_cross": 1})
	h.hp = 3.0
	Statuses.apply(h, "bleed")
	var b := Battle.new()
	var units: Array[RefCounted] = [h, _slow_zombie("z")]
	var events := b.setup(units, {}, Rng.new(1))
	assert_eq(_find(events, "revived"), {"type": "revived", "target": "h", "hp": 42.0})
	assert_true(h.alive)
	assert_eq(h.revive_charges, 0)
	assert_eq(b.current, h)


func test_retreat() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 0, skills)
	var b := Battle.new()
	var units: Array[RefCounted] = [h, _slow_zombie("z")]
	b.setup(units, {"allow_retreat": true}, Rng.new(1))
	var events := b.act({"type": "retreat"})
	assert_eq(b.outcome, "retreat")
	assert_eq(events[events.size() - 1], {"type": "battle_end", "outcome": "retreat"})
	assert_eq(b.legal_actions().size(), 0)


## 黑暗：我方每次轮到自己，恐惧 +4。
func test_darkness_adds_fear() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 0, skills)
	var b := Battle.new()
	var units: Array[RefCounted] = [h, _slow_zombie("z", 500.0)]
	b.setup(units, {"dark": true}, Rng.new(1))
	assert_almost(h.fear, 3.0 + 4.0)
	b.act({"type": "defend"})
	assert_almost(h.fear, 3.0 + 8.0)


## 鼓舞冷却 3：用完之后接下来三次轮到自己都不能用。
func test_cooldown_blocks_reuse() -> void:
	var skills: Array[String] = ["encourage"]
	var h := _human("h", 0, skills)
	var b := Battle.new()
	var units: Array[RefCounted] = [h, _slow_zombie("z", 500.0)]
	b.setup(units, {}, Rng.new(1))
	var encourage := {"type": "skill", "skill": "encourage", "targets": ["h"]}
	b.act(encourage)
	for i in 3:
		assert_false(b.legal_actions().has(encourage), "第 %d 次" % i)
		b.act({"type": "defend"})
	assert_true(b.legal_actions().has(encourage))


func test_items_are_consumed() -> void:
	var skills: Array[String] = ["grenade"]
	var h := _human("h", 0, skills, "player", {"grenade": 1})
	var b := Battle.new()
	var units: Array[RefCounted] = [h, _slow_zombie("z1", 500.0), _slow_zombie("z2", 500.0)]
	b.setup(units, {}, Rng.new(1))
	b.act({"type": "skill", "skill": "grenade", "targets": ["z1", "z2"]})
	assert_almost(float(h.resources["grenade"]), 0.0)
	assert_false(b.legal_actions().has({"type": "skill", "skill": "grenade", "targets": ["z1", "z2"]}))


## 双方都打不动对方时，行动次数到上限就结束，避免死循环。
func test_timeout_guard() -> void:
	var none: Array[String] = []
	var h := _human("h", 0, none, "ai")
	var z := UnitFactory.from_enemy("zombie", "z", 0)
	z.skills.clear()
	var b := Battle.new()
	var units: Array[RefCounted] = [h, z]
	b.setup(units, {}, Rng.new(1))
	assert_eq(b.outcome, "timeout")
	assert_eq(b.action_count, 2000)
