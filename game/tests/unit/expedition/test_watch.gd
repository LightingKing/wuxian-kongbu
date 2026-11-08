extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const ExpeditionState = preload("res://core/expedition/expedition_state.gd")
const Watch = preload("res://core/expedition/watch.gd")


func _state() -> RefCounted:
	var chars := {}
	for id in ["zheng_zha", "newbie"]:
		chars[id] = Character.new(id, id, {})
	var st := ExpeditionState.new()
	var members: Array[String] = ["zheng_zha", "newbie"]
	st.setup(Scenario.load_file("res://tests/fixtures/mini_scenario.json"), chars, members)
	return st


func _types(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for e in events:
		out.append(String(e["type"]))
	return out


func test_fear_scaled_by_spirit() -> void:
	var ch := Character.new("c", "c", {"spirit": 200})
	assert_almost(Watch.add_fear(ch, 20.0), 10.0)
	assert_almost(Watch.add_fear(ch, -50.0), -10.0)
	ch.fear = 95.0
	assert_almost(Watch.add_fear(ch, 20.0), 5.0)


## 黑暗中每 10 分钟恐惧 +3。
func test_darkness_raises_fear() -> void:
	var st := _state()
	st.squads["s1"]["location"] = "stairs"
	st.npcs["matthew"]["location"] = "stairs"
	var events: Array[Dictionary] = []
	Watch.pass_time(st, 20, events)
	assert_eq(st.clock, 20)
	assert_almost(st.characters["zheng_zha"].fear, 6.0)
	assert_true(_types(events).has("fear_changed"))


## 百米绑定：在绑定对象所在地点或相邻地点都可以。
func test_tether_in_range() -> void:
	var st := _state()
	st.squads["s1"]["location"] = "hall"
	var events: Array[Dictionary] = []
	Watch.pass_time(st, 30, events)
	assert_false(_types(events).has("tether_warning"))
	assert_true(st.tether_out.is_empty())


## 超出范围：先警告，连续超出 10 分钟以上被抹杀。
func test_tether_warning_then_erase() -> void:
	var st := _state()
	var group: Array[String] = ["newbie"]
	var sid: String = st.split("s1", group)
	st.squads[sid]["location"] = "stairs"
	var events: Array[Dictionary] = []
	Watch.check_tether(st, 0, events)
	assert_eq(_types(events), ["tether_warning"] as Array[String])
	events.clear()
	Watch.pass_time(st, 10, events)
	assert_true(st.is_alive("newbie"))
	Watch.pass_time(st, 1, events)
	assert_false(st.is_alive("newbie"))
	assert_eq(st.characters["newbie"].flags["erased"], "tether")
	assert_true(_types(events).has("erased"))
	assert_true(st.is_alive("zheng_zha"))


## 回到范围内，超出计时清零。
func test_tether_reset_when_back() -> void:
	var st := _state()
	st.squads["s1"]["location"] = "stairs"
	var events: Array[Dictionary] = []
	Watch.pass_time(st, 8, events)
	st.squads["s1"]["location"] = "car"
	Watch.pass_time(st, 1, events)
	assert_true(st.tether_out.is_empty())
	st.squads["s1"]["location"] = "stairs"
	Watch.pass_time(st, 8, events)
	assert_true(st.is_alive("zheng_zha"))


## 绑定对象死亡：转移给卡普兰；卡普兰也死了就解除。
func test_tether_transfer_and_release() -> void:
	var st := _state()
	var events: Array[Dictionary] = []
	st.npcs["matthew"]["alive"] = false
	Watch.on_tether_npc_died(st, events)
	assert_eq(st.tether["npc"], "kaplan")
	st.npcs["kaplan"]["alive"] = false
	Watch.on_tether_npc_died(st, events)
	assert_true(st.tether.is_empty())
	assert_eq(_types(events), ["tether_transferred", "tether_released"] as Array[String])


## 禁言：剧情人物在场时泄露主神信息，每句扣 10 点；不在场不扣。
func test_gag_penalty() -> void:
	var st := _state()
	var events: Array[Dictionary] = []
	assert_true(Watch.leak(st, "zheng_zha", events))
	assert_eq(st.ledger[0], {"char": "zheng_zha", "kind": "penalty", "points": -10.0, "label": "泄露主神信息", "grade": ""})
	st.squads["s1"]["location"] = "sewer"
	assert_false(Watch.leak(st, "zheng_zha", events))
	assert_eq(st.ledger.size(), 1)


## 倒计时结束：回归，时间不会超过时限。
func test_countdown_returns() -> void:
	var st := _state()
	var events: Array[Dictionary] = []
	Watch.pass_time(st, 115, events)
	assert_eq(st.outcome, "ongoing")
	Watch.pass_time(st, 30, events)
	assert_eq(st.clock, 120)
	assert_eq(st.outcome, "returned")
	Watch.pass_time(st, 30, events)
	assert_eq(st.clock, 120)


func test_wipe() -> void:
	var st := _state()
	var events: Array[Dictionary] = []
	Watch.erase(st, "zheng_zha", "tether", events)
	assert_eq(st.outcome, "ongoing")
	Watch.erase(st, "newbie", "tether", events)
	assert_eq(st.outcome, "wiped")


func test_view() -> void:
	var st := _state()
	st.clock = 30
	st.kill_counts["zheng_zha"] = 4
	st.kill_points["zheng_zha"] = 0.4
	var v := Watch.view(st, "zheng_zha")
	assert_eq(v["main_task"], "存活 2 小时")
	assert_eq(v["remaining_minutes"], 90)
	assert_eq(v["kills"], 4)
	assert_eq(v["constraints"][0], {"kind": "tether", "npc": "matthew", "max_hops": 1, "out_minutes": -1})
	assert_eq(v["constraints"][1], {"kind": "gag", "penalty": -10})
