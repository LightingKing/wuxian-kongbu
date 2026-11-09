extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const GameState = preload("res://core/model/game_state.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const Expedition = preload("res://core/expedition/expedition.gd")
const Battle = preload("res://core/battle/battle.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
const BattleData = preload("res://core/battle/battle_data.gd")
const Rng = preload("res://core/util/rng.gd")


func _scenario(chance: float) -> RefCounted:
	return Scenario.new({
		"id": "pressure", "name": "搜索压力", "start_location": "a", "duration_minutes": 120, "main_task": "活着",
		"locations": {
			"a": {"name": "A", "search_minutes": 15, "search": [{"item": "ammo", "count": 2}],
				"search_encounter": {"chance": chance, "intro": "声音引来了东西。", "enemies": [{"def": "zombie", "count": 1, "row": 0}]}},
			"b": {"name": "B"},
		},
		"paths": [{"a": "a", "b": "b", "minutes": 5}],
		"npcs": {},
		"watch": {},
		"events": [],
	})


func _start(chance: float, intelligence: float = 100.0) -> RefCounted:
	var g := GameState.new(1)
	g.add_character(Character.new("hero", "英雄", {"intelligence": intelligence}))
	var ex := Expedition.new()
	var members: Array[String] = ["hero"]
	ex.start(g, _scenario(chance), members)
	return ex


## 搜索要花时间，还可能把敌人引过来；东西照样拿到。
func test_search_can_trigger_encounter() -> void:
	var ex := _start(1.0)
	var events: Array[Dictionary] = ex.search("s1")
	assert_eq(ex.st.clock, 15)
	assert_eq(ex.st.pending_battle["location"], "a")
	assert_almost(float(ex.st.squads["s1"]["items"]["ammo"]), 2.0)
	var types: Array[String] = []
	for e in events:
		types.append(String(e["type"]))
	assert_true(types.has("search_encounter"))
	assert_true(types.has("battle_request"))


func test_search_quiet_when_chance_zero() -> void:
	var ex := _start(0.0)
	ex.search("s1")
	assert_true(ex.st.pending_battle.is_empty())


## 坚持目标：时间轴一到就结束为 survived，按胜利回报。
func test_survive_objective() -> void:
	var ex := _start(0.0)
	ex.st.pending_battle = {"location": "a", "squad": "s1", "enemies": [{"def": "zombie", "count": 1, "row": 0}],
		"dark": false, "survive_until": 1.0, "after_victory": [], "after_defeat": []}
	var units: Array[RefCounted] = ex.battle_units({})
	var b := Battle.new()
	b.setup(units, ex.battle_options(), Rng.new(1))
	assert_eq(b.outcome, "survived")
	var events: Array[Dictionary] = ex.report_battle(b)
	assert_true(ex.st.pending_battle.is_empty())
	assert_eq(events[events.size() - 1]["type"], "battle_resolved")


## 判断力：队伍里最聪明的人决定能看穿多少敌人意图。
func test_intel_from_team() -> void:
	var ex := _start(0.0, 130.0)
	ex.st.pending_battle = {"location": "a", "squad": "s1", "enemies": [{"def": "zombie", "count": 1, "row": 0}], "dark": false}
	assert_eq(int(ex.battle_options()["intel"]), 1)
	ex.st.characters["hero"].attributes.base["intelligence"] = 165.0
	assert_eq(int(ex.battle_options()["intel"]), 2)


## 手枪要子弹：没子弹时手枪不在合法行动里。
func test_ammo_gates_pistol() -> void:
	assert_eq(float(BattleData.skill("pistol_shot_limited")["cost"]["ammo"]), 1.0)
	var ch := Character.new("hero", "英雄", {})
	ch.skills.assign(["pistol_shot_limited"])
	ch.items = {"ammo": 1}
	var units: Array[RefCounted] = [
		UnitFactory.from_character(ch, "ally", 0, ["pistol_shot_limited"], "player", ch.battle_resources()),
		UnitFactory.from_enemy("zombie", "zombie_1", 0),
	]
	var b := Battle.new()
	b.setup(units, {}, Rng.new(1))
	assert_eq(b.current.id, "hero")
	var has_pistol := false
	for a: Dictionary in b.legal_actions():
		if String(a.get("skill", "")) == "pistol_shot_limited":
			has_pistol = true
	assert_true(has_pistol)
	b.current.resources["ammo"] = 0.0
	for a: Dictionary in b.legal_actions():
		assert_false(String(a.get("skill", "")) == "pistol_shot_limited")
