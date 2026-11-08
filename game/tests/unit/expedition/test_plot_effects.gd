extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const GameState = preload("res://core/model/game_state.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const Expedition = preload("res://core/expedition/expedition.gd")
const Watch = preload("res://core/expedition/watch.gd")

const FIXTURE := "res://tests/fixtures/mini_scenario.json"


func _game(ids: Array[String] = ["hero", "mate"]) -> RefCounted:
	var g := GameState.new(1)
	for id in ids:
		g.add_character(Character.new(id, id, {}))
	return g


## 一条 a—b 的直线剧本，剧情人物在 a；事件由调用方给。
func _scenario(events: Array, watch: Dictionary = {}) -> RefCounted:
	return Scenario.new({
		"id": "fx", "name": "效果测试", "start_location": "a", "duration_minutes": 120, "main_task": "活着",
		"locations": {"a": {"name": "A"}, "b": {"name": "B"}},
		"paths": [{"a": "a", "b": "b", "minutes": 5}],
		"npcs": {"vip": {"name": "VIP", "location": "a"}},
		"watch": watch,
		"events": events,
	})


func _types(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for e in events:
		out.append(String(e["type"]))
	return out


func _start(sc: RefCounted, ids: Array[String] = ["hero", "mate"]) -> RefCounted:
	var ex := Expedition.new()
	var members: Array[String] = ids.duplicate()
	ex.start(_game(ids), sc, members)
	return ex


## 选择：出现时其他行动都要等；选完应用选项的效果；选项 id 不对不生效。
func test_choice_blocks_and_applies() -> void:
	var ex := _start(_scenario([
		{"id": "pick", "when": {"party_at": "a"}, "location": "a", "effects": [
			{"choice": {"id": "pick_one", "prompt": "选一个", "options": [
				{"id": "yes", "text": "好", "effects": [
					{"set_flag": "picked"},
					{"give": {"recipients": ["hero"], "skill": "pistol_shot"}},
					{"damage": {"amount": 30, "recipients": ["hero"], "reason": "trap"}},
				]},
				{"id": "no", "text": "不", "effects": [{"set_flag": "refused"}]},
			]}}
		]},
	]))
	assert_eq(ex.st.pending_choice["id"], "pick_one")
	assert_eq(ex.move("s1", "b")[0]["reason"], "choice_pending")
	assert_eq(ex.choose("nope")[0]["reason"], "bad_option")
	assert_false(ex.st.pending_choice.is_empty())
	var events: Array[Dictionary] = ex.choose("yes")
	assert_true(_types(events).has("choice_made"))
	assert_true(bool(ex.st.flags["picked"]))
	assert_true(ex.st.characters["hero"].skills.has("pistol_shot"))
	assert_almost(ex.st.characters["hero"].hp, 110.0)
	assert_eq(ex.st.clock, 0)


## 抹杀：选项直接把人抹掉，全员被抹掉就是全灭。
func test_erase_wipes() -> void:
	var ex := _start(_scenario([
		{"id": "pick", "when": {"party_at": "a"}, "effects": [
			{"choice": {"id": "die", "prompt": "?", "options": [
				{"id": "yes", "text": "走", "effects": [{"erase": {"targets": ["hero"], "reason": "tether"}}]},
				{"id": "no", "text": "留", "effects": []},
			]}}
		]},
	]), ["hero"])
	ex.choose("yes")
	var events: Array[Dictionary] = ex.choose("no")
	assert_true(_types(events).has("invalid_action"))
	assert_false(ex.st.characters["hero"].alive)
	assert_eq(ex.st.characters["hero"].flags["erased"], "tether")
	assert_eq(ex.finish()["hero"], {"dead": true, "reason": "tether"})


## 说服：等对话层给等级；高于难度成功、低于失败；结果效果落地；期间其他行动被挡。
func test_persuade_success_and_failure() -> void:
	var ok := _start(_scenario([
		{"id": "talk", "when": {"party_at": "a"}, "location": "a", "effects": [
			{"persuade": {"id": "ask", "npc": "vip", "goal": "开门", "difficulty": 2, "keywords": ["威胁"],
				"success": [{"set_flag": "opened"}], "failure": [{"set_flag": "refused"}]}}
		]},
	]))
	assert_eq(ok.st.pending_check["id"], "ask")
	assert_eq(ok.move("s1", "b")[0]["reason"], "check_pending")
	ok.resolve_persuasion(3)
	assert_true(bool(ok.st.flags["opened"]))
	var bad := _start(_scenario([
		{"id": "talk", "when": {"party_at": "a"}, "location": "a", "effects": [
			{"persuade": {"id": "ask", "npc": "vip", "goal": "开门", "difficulty": 3, "keywords": [],
				"success": [{"set_flag": "opened"}], "failure": [{"set_flag": "refused"}]}}
		]},
	]))
	bad.resolve_persuasion(0)
	assert_true(bool(bad.st.flags["refused"]))
	assert_eq(bad.resolve_persuasion(1)[0]["reason"], "no_check")


## 移动队员、剧情伤害致死、延迟推进时钟。
func test_move_damage_and_delay() -> void:
	var ex := _start(_scenario([
		{"id": "move", "when": {"party_at": "a"}, "effects": [
			{"move_members": {"members": ["hero"], "to": "b"}},
			{"delay": {"minutes": 15}},
			{"damage": {"amount": 999, "recipients": ["hero"], "reason": "trap"}},
		]},
	]))
	assert_eq(ex.st.clock, 15)
	assert_eq(ex.st.location_of("hero"), "b")
	assert_eq(ex.st.location_of("mate"), "a")
	assert_false(ex.st.characters["hero"].alive)
	assert_eq(ex.st.characters["hero"].flags["death"], "trap")
	assert_eq(ex.st.outcome, "ongoing")


## 感染：带出战斗的感染到点就变丧尸；解毒剂能解除。
func test_infection_and_antidote() -> void:
	var ex := _start(_scenario([]))
	ex.st.infected["hero"] = 0
	ex.rest("s1", 59)
	assert_true(ex.st.characters["hero"].alive)
	ex.rest("s1", 1)
	assert_false(ex.st.characters["hero"].alive)
	assert_true(bool(ex.st.characters["hero"].flags["turned"]))

	var cured := _start(_scenario([]))
	cured.st.infected["hero"] = 30
	cured.st.characters["hero"].items["antidote"] = 1.0
	cured.use_item("hero", "antidote")
	assert_false(cured.st.infected.has("hero"))
	assert_false(cured.st.characters["hero"].items.has("antidote"))


## 断电后全黑：watch.dark_flag 为真时，所有地点都按黑暗加恐惧。
func test_dark_flag() -> void:
	var ex := _start(_scenario([], {"dark_flag": "power_out"}))
	var evs: Array[Dictionary] = []
	Watch.pass_time(ex.st, 10, evs)
	assert_almost(ex.st.characters["hero"].fear, 0.0)
	ex.st.flags["power_out"] = true
	Watch.pass_time(ex.st, 10, evs)
	assert_almost(ex.st.characters["hero"].fear, 3.0)


## 等待选择时存档，读档后照样能选。
func test_save_with_pending_choice() -> void:
	var ex := _start(_scenario([
		{"id": "pick", "when": {"party_at": "a"}, "effects": [
			{"choice": {"id": "pick_one", "prompt": "?", "options": [
				{"id": "yes", "text": "好", "effects": [{"set_flag": "picked"}]},
				{"id": "no", "text": "不", "effects": []},
			]}}
		]},
	]))
	var saved: Dictionary = JSON.parse_string(JSON.stringify(ex.to_dict()))
	var g := _game()
	var loaded := Expedition.new()
	loaded.load_dict(saved, g, _scenario([
		{"id": "pick", "when": {"party_at": "a"}, "effects": [
			{"choice": {"id": "pick_one", "prompt": "?", "options": [
				{"id": "yes", "text": "好", "effects": [{"set_flag": "picked"}]},
				{"id": "no", "text": "不", "effects": []},
			]}}
		]},
	]))
	assert_eq(loaded.st.pending_choice["id"], "pick_one")
	loaded.choose("yes")
	assert_true(bool(loaded.st.flags["picked"]))
