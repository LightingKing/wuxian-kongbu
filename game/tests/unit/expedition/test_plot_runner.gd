extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const ExpeditionState = preload("res://core/expedition/expedition_state.gd")
const PlotRunner = preload("res://core/expedition/plot_runner.gd")


func _state() -> RefCounted:
	var chars := {}
	for id in ["zheng_zha", "zhang_jie"]:
		chars[id] = Character.new(id, id, {})
	var st := ExpeditionState.new()
	var members: Array[String] = ["zheng_zha", "zhang_jie"]
	st.setup(Scenario.load_file("res://tests/fixtures/mini_scenario.json"), chars, members)
	return st


func _event(st: RefCounted, id: String) -> Dictionary:
	for ev: Dictionary in st.scenario.events():
		if ev["id"] == id:
			return ev
	return {}


func _types(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for e in events:
		out.append(String(e["type"]))
	return out


func test_next_timed_in_order() -> void:
	var st := _state()
	assert_eq(PlotRunner.next_timed(st)["id"], "rules_talk")
	st.fired["rules_talk"] = "original"
	assert_eq(PlotRunner.next_timed(st)["id"], "mercs_arrive")
	st.fired["mercs_arrive"] = "original"
	st.fired["queen_shutdown"] = "original"
	assert_true(PlotRunner.next_timed(st).is_empty())


func test_original_event() -> void:
	var st := _state()
	var events: Array[Dictionary] = []
	PlotRunner.fire(st, _event(st, "rules_talk"), events)
	assert_eq(st.fired["rules_talk"], "original")
	assert_eq(_types(events), ["plot_event", "dialogue", "bonus"] as Array[String])
	assert_eq(st.ledger[0]["char"], "zhang_jie")
	assert_almost(float(st.ledger[0]["points"]), 100.0)


## 剧情惯性：改写条件成立时，原效果被替代，剧情偏移量加上惯性等级。
func test_alteration_adds_deviation() -> void:
	var st := _state()
	st.flags["threatened_queen"] = true
	var events: Array[Dictionary] = []
	PlotRunner.fire(st, _event(st, "queen_shutdown"), events)
	assert_eq(st.fired["queen_shutdown"], "altered")
	assert_eq(st.deviation, 1)
	assert_true(bool(st.npcs["matthew"]["alive"]))
	assert_false(st.flags.has("lights_out"))
	assert_eq(events[0]["label"], "威胁火焰女皇，断电被推迟")


func test_original_queen_shutdown_kills_matthew() -> void:
	var st := _state()
	var events: Array[Dictionary] = []
	PlotRunner.fire(st, _event(st, "queen_shutdown"), events)
	assert_true(bool(st.flags["lights_out"]))
	assert_false(bool(st.npcs["matthew"]["alive"]))
	assert_eq(st.tether["npc"], "kaplan")
	assert_true(_types(events).has("tether_transferred"))


## 条件事件：到激光通道触发陷阱 → 发起战斗；有人提醒过 → 改写为救下马修、开门、解除绑定，并连锁出偏移事件。
func test_conditional_battle() -> void:
	var st := _state()
	var events: Array[Dictionary] = []
	PlotRunner.run_conditional(st, events)
	assert_eq(events.size(), 0)
	st.squads["s1"]["location"] = "laser"
	PlotRunner.run_conditional(st, events)
	assert_eq(st.fired["laser_trap"], "original")
	assert_eq(st.pending_battle["location"], "laser")
	assert_eq(st.pending_battle["squad"], "s1")
	assert_almost(st.characters["zheng_zha"].fear, 30.0)
	assert_true(_types(events).has("battle_request"))


func test_conditional_alteration_chain() -> void:
	var st := _state()
	st.flags["warned_laser"] = true
	st.squads["s1"]["location"] = "laser"
	var events: Array[Dictionary] = []
	PlotRunner.run_conditional(st, events)
	assert_eq(st.fired["laser_trap"], "altered")
	assert_eq(st.deviation, 2)
	assert_true(st.pending_battle.is_empty())
	assert_true(st.is_path_open("laser", "control"))
	assert_true(st.tether.is_empty())
	assert_true(bool(st.flags["side:save_matthew"]))
	assert_eq(st.fired["lickers_early"], "original")
	assert_true(bool(st.flags["lickers_early"]))
	var kinds: Array = []
	for l: Dictionary in st.ledger:
		if l["char"] == "zheng_zha":
			kinds.append([l["kind"], l["points"], l["grade"]])
	assert_eq(kinds, [["side_plot", 5000.0, "B"], ["bonus", 500.0, ""]])
	assert_almost(st.characters["zheng_zha"].attributes.total("spirit"), 120.0)
	assert_almost(st.characters["zheng_zha"].attributes.total("nerve_reaction"), 130.0)


func test_battle_avoided_when_nobody_there() -> void:
	var st := _state()
	var events: Array[Dictionary] = []
	PlotRunner.apply_effect(st, {"battle": {"location": "sewer", "enemies": [{"def": "zombie", "count": 1}]}}, "", events)
	assert_eq(_types(events), ["battle_avoided"] as Array[String])
	assert_true(st.pending_battle.is_empty())


func test_recipients() -> void:
	var st := _state()
	st.characters["zhang_jie"].alive = false
	assert_eq(PlotRunner.recipients(st, ["zheng_zha", "zhang_jie"], ""), ["zheng_zha"] as Array[String])
	assert_eq(PlotRunner.recipients(st, "present", "car"), ["zheng_zha"] as Array[String])
	assert_eq(PlotRunner.recipients(st, "present", "hall").size(), 0)
	assert_eq(PlotRunner.recipients(st, "all", ""), ["zheng_zha"] as Array[String])


func test_misc_effects() -> void:
	var st := _state()
	var events: Array[Dictionary] = []
	var effects: Array = [
		{"npc_move": {"npc": "matthew", "to": "hall"}},
		{"close_path": ["car", "hall"]},
		{"penalty": {"points": -1000, "label": "杀死新人", "recipients": ["zheng_zha"]}},
		{"end": "escaped"},
	]
	PlotRunner.apply_effects(st, effects, "", events)
	assert_eq(st.npcs["matthew"]["location"], "hall")
	assert_false(st.is_path_open("car", "hall"))
	assert_almost(float(st.ledger[0]["points"]), -1000.0)
	assert_eq(st.outcome, "escaped")
