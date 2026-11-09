extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const GameState = preload("res://core/model/game_state.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const Expedition = preload("res://core/expedition/expedition.gd")
const Battle = preload("res://core/battle/battle.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
const Rng = preload("res://core/util/rng.gd")

const FIXTURE := "res://tests/fixtures/mini_scenario.json"


## 测试用的假战斗：只需要 history、field.units、outcome 三样。
class FakeField extends RefCounted:
	var units: Array[RefCounted] = []


class FakeBattle extends RefCounted:
	var history: Array[Dictionary] = []
	var field := FakeField.new()
	var outcome := "victory"


func _game() -> RefCounted:
	var g := GameState.new(1)
	for id in ["zheng_zha", "zhang_jie", "newbie"]:
		g.add_character(Character.new(id, id, {}))
	g.characters["zhang_jie"].films_completed = 3
	return g


func _start(g: RefCounted) -> RefCounted:
	var ex := Expedition.new()
	var members: Array[String] = ["zheng_zha", "zhang_jie", "newbie"]
	ex.start(g, Scenario.load_file(FIXTURE), members)
	return ex


func _types(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for e in events:
		out.append(String(e["type"]))
	return out


## 一条直线 a—b—c 的小剧本，剧情人物在 a，绑定 1 格、宽限 10 分钟，没有事件。
func _line_scenario() -> RefCounted:
	return Scenario.new({
		"id": "line", "name": "直线", "start_location": "a", "duration_minutes": 60, "main_task": "存活",
		"locations": {"a": {"name": "A"}, "b": {"name": "B"}, "c": {"name": "C"}},
		"paths": [{"a": "a", "b": "b", "minutes": 5}, {"a": "b", "b": "c", "minutes": 5}],
		"npcs": {"vip": {"name": "VIP", "location": "a", "plot": true}},
		"watch": {"tether": {"npc": "vip", "max_hops": 1, "grace_minutes": 10}},
		"events": [],
	})


func test_start_fires_opening() -> void:
	var g := _game()
	var ex := Expedition.new()
	var members: Array[String] = ["zheng_zha", "zhang_jie", "newbie"]
	var events: Array[Dictionary] = ex.start(g, Scenario.load_file(FIXTURE), members)
	assert_eq(_types(events), ["expedition_start", "plot_event", "dialogue", "bonus"] as Array[String])
	assert_eq(ex.st.clock, 0)
	assert_eq(ex.st.ledger[0]["char"], "zhang_jie")


## 走到大厅要 10 分钟，途中第 10 分钟雇佣兵登场：马修移到大厅，全员恐惧 +10。
func test_move_runs_timed_events() -> void:
	var ex := _start(_game())
	var events: Array[Dictionary] = ex.move("s1", "hall")
	var types := _types(events)
	assert_true(types.find("plot_event") < types.find("arrived"), str(types))
	assert_eq(ex.st.clock, 10)
	assert_eq(ex.st.location_of("zheng_zha"), "hall")
	assert_eq(ex.st.npcs["matthew"]["location"], "hall")
	assert_almost(ex.st.characters["zheng_zha"].fear, 10.0)


func test_invalid_moves() -> void:
	var ex := _start(_game())
	assert_eq(ex.move("s1", "laser")[0]["reason"], "no_path")
	assert_eq(ex.move("s9", "hall")[0]["reason"], "no_squad")
	assert_eq(ex.st.clock, 0)


## 激光通道的门默认关着。
func test_closed_path() -> void:
	var ex := _start(_game())
	ex.st.squads["s1"]["location"] = "laser"
	ex.st.fired["laser_trap"] = "original"
	assert_eq(ex.move("s1", "control")[0]["reason"], "no_path")


func test_search_once() -> void:
	var ex := _start(_game())
	var events: Array[Dictionary] = ex.search("s1")
	assert_eq(events[events.size() - 1]["found"], [{"item": "grenade", "count": 1}])
	assert_almost(float(ex.st.squads["s1"]["items"]["grenade"]), 1.0)
	assert_eq(ex.st.clock, 10)
	assert_eq(ex.search("s1")[0]["type"], "already_searched")
	assert_eq(ex.st.clock, 10)


func test_rest_lowers_fear() -> void:
	var ex := _start(_game())
	ex.st.characters["newbie"].fear = 50.0
	ex.rest("s1", 20)
	assert_eq(ex.st.clock, 20)
	assert_almost(ex.st.characters["newbie"].fear, 50.0 + 10.0 - 10.0)


## 原剧情：走进激光通道 → 陷阱 → 战斗。战斗没打完之前不能做别的事；打完记击杀。
func test_laser_trap_battle() -> void:
	var g := _game()
	var ex := _start(g)
	ex.move("s1", "hall")
	ex.move("s1", "stairs")
	var events: Array[Dictionary] = ex.move("s1", "laser")
	assert_true(_types(events).has("battle_request"), str(_types(events)))
	assert_eq(ex.st.pending_battle["location"], "laser")
	assert_eq(ex.move("s1", "stairs")[0]["reason"], "battle_pending")
	var pistol: Array[String] = ["pistol_shot"]
	var units: Array[RefCounted] = ex.battle_units({"zheng_zha": pistol, "zhang_jie": pistol, "newbie": pistol}, "ai")
	assert_eq(units.size(), 5)
	var b := Battle.new()
	b.setup(units, ex.battle_options(), Rng.new(4))
	assert_eq(b.outcome, "victory")
	var report: Array[Dictionary] = ex.report_battle(b)
	assert_true(_types(report).has("battle_resolved"))
	assert_true(ex.st.pending_battle.is_empty())
	var total_kills := 0
	for c in ["zheng_zha", "zhang_jie", "newbie"]:
		total_kills += int(ex.st.kill_counts.get(c, 0))
	assert_eq(total_kills, 2)


## 击杀奖励按相对威胁算：丧尸基础价 0.1，威胁 120，新人队评价战力 120 → 每只 0.1（原著：10 只丧尸 = 1 点）。
## 杀死新人扣 1000 点。战后写回生命和剩余道具。
func test_report_records_kills_and_penalties() -> void:
	var g := _game()
	var ex := _start(g)
	ex.st.squads["s1"]["items"] = {"grenade": 2.0}
	ex.st.squads["s1"]["location"] = "laser"
	ex.st.pending_battle = {"location": "laser", "squad": "s1", "enemies": [{"def": "zombie", "count": 1}], "dark": false}
	var units: Array[RefCounted] = ex.battle_units({})
	var b := FakeBattle.new()
	b.field.units = units
	units[0].hp = 50.0
	units[0].resources["grenade"] = 1.0
	b.history = [
		{"type": "damage", "source": "zheng_zha", "target": "zombie_1", "amount": 40.0, "hp": 0.0},
		{"type": "death", "target": "zombie_1", "turned": false},
		{"type": "damage", "source": "zhang_jie", "target": "newbie", "amount": 200.0, "hp": -60.0},
		{"type": "death", "target": "newbie", "turned": false},
	]
	units[2].alive = false
	ex.report_battle(b)
	assert_almost(float(ex.st.kill_points["zheng_zha"]), 0.1)
	assert_eq(ex.st.ledger[ex.st.ledger.size() - 1], {"char": "zhang_jie", "kind": "penalty", "points": -1000.0, "label": "杀死新人", "grade": ""})
	assert_almost(g.characters["zheng_zha"].hp, 50.0)
	assert_false(g.characters["newbie"].alive)
	assert_eq(ex.st.squads["s1"]["items"], {"grenade": 1.0})


## 改变剧情：有人提前提醒激光陷阱 → 改写为救下马修（B 级支线 + 5000）、精神临界值突破（+500）、开门、解除绑定，
## 剧情偏移 2 → 连锁事件。之后撑到倒计时结束回归、结算。
func test_altered_plot_and_settlement() -> void:
	var g := _game()
	var ex := _start(g)
	ex.apply_effects([{"set_flag": "warned_laser"}])
	ex.move("s1", "hall")
	ex.move("s1", "stairs")
	var events: Array[Dictionary] = ex.move("s1", "laser")
	var types := _types(events)
	assert_true(types.has("plot_altered"), str(types))
	assert_true(types.has("side_plot_done"))
	assert_true(types.has("tether_released"))
	assert_true(bool(ex.st.flags["lickers_early"]))
	assert_eq(ex.move("s1", "control")[1]["type"], "arrived")
	ex.rest("s1", 200)
	assert_eq(ex.st.outcome, "returned")
	assert_eq(ex.st.clock, 120)
	var results: Dictionary = ex.finish()
	assert_eq(int(results["zheng_zha"]["final_points"]), 1000 + 5000 + 500)
	# 夹具这里写的是 recipients: "present"，验证的就是"发给在场所有人"这条规则。
	assert_eq(int(results["zhang_jie"]["final_points"]), 1000 + 5000 + 500 + 100)
	assert_true(g.characters["zheng_zha"].tickets.has_at_least("B"))
	assert_eq(g.films_record, ["mini_hive"])
	assert_eq(ex.finish(), {})


func test_finish_only_after_end() -> void:
	var ex := _start(_game())
	assert_eq(ex.finish(), {})


## 百米绑定：走到离剧情人物两格的地方先警告，超过宽限时间被抹杀；全员被抹杀即全灭。
func test_tether_erases() -> void:
	var g := _game()
	var ex := Expedition.new()
	var members: Array[String] = ["newbie"]
	ex.start(g, _line_scenario(), members)
	ex.move("s1", "b")
	var events: Array[Dictionary] = ex.move("s1", "c")
	assert_true(_types(events).has("tether_warning"))
	ex.rest("s1", 10)
	assert_true(g.characters["newbie"].alive)
	events = ex.rest("s1", 1)
	assert_false(g.characters["newbie"].alive)
	assert_eq(ex.st.outcome, "wiped")
	assert_eq(ex.finish()["newbie"], {"dead": true, "reason": "tether"})


func test_gag_through_controller() -> void:
	var ex := _start(_game())
	var events: Array[Dictionary] = ex.leak("newbie")
	assert_eq(events[0]["type"], "gag_penalty")
	assert_eq(events[0]["witness"], "matthew")


func test_split_and_merge() -> void:
	var ex := _start(_game())
	var group: Array[String] = ["newbie"]
	var events: Array[Dictionary] = ex.split("s1", group)
	assert_eq(events[0]["squad"], "s2")
	ex.move("s2", "hall")
	assert_eq(ex.merge("s1", "s2")[0]["reason"], "bad_merge")
	ex.move("s1", "hall")
	assert_eq(ex.merge("s1", "s2")[0]["type"], "squads_merged")


func test_watch_view() -> void:
	var ex := _start(_game())
	ex.move("s1", "hall")
	var v: Dictionary = ex.watch_view("zheng_zha")
	assert_eq(v["remaining_minutes"], 110)
	assert_eq(v["constraints"][0]["npc"], "matthew")


## 存档后读档，继续行动的结果和不存档完全一样。
func test_save_and_resume() -> void:
	var g1 := _game()
	var a := _start(g1)
	a.move("s1", "hall")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(a.to_dict()))
	var b := Expedition.new()
	b.load_dict(saved, g1, Scenario.load_file(FIXTURE))
	assert_eq(b.to_dict(), a.to_dict())
	var g2 := _game()
	var c := _start(g2)
	c.move("s1", "hall")
	assert_eq(b.move("s1", "sewer"), c.move("s1", "sewer"))
	assert_eq(b.st.clock, 25)
