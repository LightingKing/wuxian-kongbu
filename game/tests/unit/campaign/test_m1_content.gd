extends "res://tests/test_case.gd"

const Campaign = preload("res://core/campaign/campaign.gd")
const GameState = preload("res://core/model/game_state.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const BattleData = preload("res://core/battle/battle_data.gd")
const Persona = preload("res://ai/persona.gd")

const CHAPTER := "res://data/scenarios/biohazard1/chapter.json"
const ROSTER := "res://data/characters/m1_roster.json"
const SCENARIO := "res://data/scenarios/biohazard1/scenario.json"

const M1_MEMBERS := ["zheng_zha", "zhang_jie", "zhan_lan", "li_xiao_yi", "mu_gang", "xiao_pang_zi", "zhong_nian_fu_nv"]


## 测试用的假战斗：只需要 history、field.units、outcome 三样。
class FakeField extends RefCounted:
	var units: Array[RefCounted] = []


class FakeBattle extends RefCounted:
	var history: Array[Dictionary] = []
	var field := FakeField.new()
	var outcome := "victory"


func _start() -> RefCounted:
	return Campaign.start(GameState.new(1), CHAPTER)


## 用假战斗把待打的战斗按胜利了结（不产生击杀记录）。
func _win(ex: RefCounted) -> Array[Dictionary]:
	var units: Array[RefCounted] = ex.battle_units({})
	var b := FakeBattle.new()
	b.field.units = units
	return ex.report_battle(b)


func _types(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for e in events:
		out.append(String(e["type"]))
	return out


## 走到激光通道门口：听规则 → 大厅 → 楼梯井（扶掉队的人）→ 激光通道。
func _to_laser() -> RefCounted:
	var ex := _start()
	ex.choose("listen")
	ex.move("s1", "hall")
	ex.move("s1", "stairs")
	ex.choose("help")
	ex.move("s1", "laser")
	return ex


func test_chapter_validates() -> void:
	var ch := Campaign.load_chapter(CHAPTER)
	var errors := Campaign.validate_chapter(ch)
	assert_eq(errors.size(), 0, str(errors))
	assert_eq(String(ch["id"]), "m1")


func test_roster() -> void:
	var roster := Campaign.build_roster(ROSTER)
	assert_eq(roster.size(), 7)
	assert_eq(roster["zhang_jie"].display_name, "张杰")
	assert_eq(int(roster["zhang_jie"].films_completed), 3)
	assert_eq(int(roster["zheng_zha"].films_completed), 0)
	assert_true(roster["zhang_jie"].skills.has("desert_eagle"))
	assert_eq(String(roster["mu_gang"].flags["talent"]), "wheelman")
	assert_true(float(roster["zheng_zha"].flags["potential"]) > 0.5)


## 剧本里的剧情人物和名单上的轮回者都要有 AI 人设，M1 才算能全 AI 驱动对话。
func test_personas_cover_cast() -> void:
	var personas := Persona.load_all()
	var sc := Scenario.load_file(SCENARIO)
	for id: String in sc.data["npcs"]:
		assert_true(personas.has(id), id)
	for id: String in Campaign.build_roster(ROSTER):
		assert_true(personas.has(id), id)
	assert_true(personas.has("zhushen"))
	assert_eq((personas["red_queen"]["fallback_lines"] as Array).size(), 3)


func test_scenario_metadata() -> void:
	var sc := Scenario.load_file(SCENARIO)
	assert_eq(sc.validate().size(), 0, str(sc.validate()))
	assert_eq(String(sc.id), "biohazard1")
	assert_eq(int(sc.data["duration_minutes"]), 187)
	assert_eq((sc.data["locations"] as Dictionary).size(), 8)
	assert_eq((sc.data["npcs"] as Dictionary).size(), 8)
	var choices := 0
	for ev: Dictionary in sc.events():
		for e: Dictionary in ev.get("effects", []):
			if e.has("choice"):
				choices += 1
	assert_true(choices >= 3, str(choices))


## 开局：七个人都在，评价战力 120；开场事件要玩家表态；张杰讲规则拿 100 点。
func test_start_and_opening() -> void:
	var g := GameState.new(1)
	var ex := Campaign.start(g, CHAPTER)
	assert_true(ex != null)
	assert_eq(g.characters.size(), 7)
	assert_almost(ex.rating_power, 120.0)
	assert_eq(ex.st.pending_choice["id"], "opening_attitude")
	assert_eq(ex.move("s1", "hall")[0]["reason"], "choice_pending")
	ex.choose("listen")
	assert_true(bool(ex.st.flags["listened_rules"]))
	assert_eq(ex.st.ledger[0], {"char": "zhang_jie", "kind": "bonus", "points": 100.0, "label": "讲解规则", "grade": ""})


## 扶不扶掉队的新人：扶 = 多花 15 分钟、加恐惧、两人活下来。
func test_lagging_help() -> void:
	var ex := _start()
	ex.choose("listen")
	ex.move("s1", "hall")
	ex.move("s1", "stairs")
	assert_eq(ex.st.clock, 18)
	assert_eq(ex.st.pending_choice["id"], "lag_behind")
	ex.choose("help")
	assert_eq(ex.st.clock, 33)
	assert_true(ex.st.characters["xiao_pang_zi"].alive)
	assert_true(ex.st.characters["zhong_nian_fu_nv"].alive)
	assert_true(bool(ex.st.flags["helped_lagging"]))
	assert_almost(ex.st.characters["zheng_zha"].fear, 14.5 * 100.0 / 110.0)


## 不扶：两个人超出百米被抹杀，队伍不停。
func test_lagging_leave() -> void:
	var ex := _start()
	ex.choose("listen")
	ex.move("s1", "hall")
	ex.move("s1", "stairs")
	ex.choose("leave")
	assert_eq(ex.st.clock, 18)
	assert_false(ex.st.characters["xiao_pang_zi"].alive)
	assert_false(ex.st.characters["zhong_nian_fu_nv"].alive)
	assert_eq(ex.st.characters["xiao_pang_zi"].flags["erased"], "tether")
	assert_false(bool(ex.st.flags.get("helped_lagging", false)))


## 激光通道：按记忆拖着马修贴门 → B 级支线 + 5000、精神临界值突破 +500、绑定解除、门开了。
func test_laser_saves_matthew() -> void:
	var ex := _to_laser()
	assert_eq(ex.st.clock, 40)
	assert_eq(ex.st.pending_choice["id"], "laser_choice")
	assert_true(ex.st.characters["zheng_zha"].skills.has("pistol_shot_limited"))
	var events: Array[Dictionary] = ex.choose("save_matthew")
	assert_true(_types(events).has("side_plot_done"))
	assert_true(_types(events).has("tether_released"))
	assert_true(ex.st.tether.is_empty())
	assert_true(ex.st.is_path_open("laser", "control"))
	assert_true(ex.st.npcs["matthew"]["alive"])
	assert_true(ex.st.characters["mu_gang"].alive)
	assert_almost(ex.st.characters["zheng_zha"].attributes.total("spirit"), 130.0)
	assert_almost(ex.st.characters["zheng_zha"].attributes.total("nerve_reaction"), 135.0)
	assert_true(ex.move("s1", "control")[1]["type"] == "arrived")


## 只顾自己：马修死，绑定转给卡普兰；牟钢在激光里被击毙。
func test_laser_selfish() -> void:
	var ex := _to_laser()
	var events: Array[Dictionary] = ex.choose("self_only")
	assert_false(ex.st.npcs["matthew"]["alive"])
	assert_eq(ex.st.tether["npc"], "kaplan")
	assert_false(ex.st.characters["mu_gang"].alive)
	assert_true(_types(events).has("tether_transferred"))
	assert_false(bool(ex.st.flags.get("side:save_matthew", false)))


## 从线索推理火焰女皇：主机房的对话给线索，詹岚花 10 分钟推出结论（带可信度）。
func test_deduce_from_clues() -> void:
	var ex := _to_laser()
	ex.choose("save_matthew")
	ex.move("s1", "control")
	assert_almost(ex.st.intel.clue_weight("queen_controls_lasers"), 1.0)
	var events: Array[Dictionary] = ex.deduce("queen_controls_lasers", "zhan_lan")
	assert_eq(events[0]["type"], "inference")
	assert_almost(float(events[0]["confidence"]), 0.655)
	assert_eq(ex.st.clock, 55)


## 原剧情路线走到底：丧尸、留守、威胁火焰女皇、断电、内门，撑到 3:07 回归；
## 郑吒 6500 点（存活 1000 + 救马修 5000 + 精神突破 500）和一个 B 级支线。
func test_canon_route_to_return() -> void:
	var g := GameState.new(1)
	var ex := Campaign.start(g, CHAPTER)
	ex.choose("listen")
	ex.move("s1", "hall")
	assert_eq(ex.st.clock, 10)
	assert_eq(ex.st.tether["npc"], "matthew")
	ex.move("s1", "stairs")
	ex.choose("help")
	ex.move("s1", "laser")
	ex.choose("save_matthew")
	ex.move("s1", "control")
	assert_eq(ex.st.clock, 45)
	ex.deduce("queen_controls_lasers", "zhan_lan")
	ex.rest("s1", 15)
	assert_eq(ex.st.clock, 70)
	assert_eq(ex.st.pending_battle["location"], "control")
	_win(ex)
	ex.rest("s1", 20)
	assert_eq(ex.st.clock, 90)
	assert_eq(ex.st.pending_choice["id"], "stay_or_follow")
	ex.choose("stay")
	assert_true(bool(ex.st.flags["stay_control"]))
	ex.rest("s1", 35)
	assert_eq(ex.st.clock, 125)
	assert_eq(ex.st.pending_check["id"], "threaten_queen")
	var talk: Array[Dictionary] = ex.persuade_with(["威胁", "断电", "激光"], "zhan_lan")
	assert_true(bool(talk[0]["success"]))
	assert_true(bool(ex.st.flags["queen_helps"]))
	ex.rest("s1", 40)
	assert_eq(ex.st.clock, 165)
	assert_true(bool(ex.st.flags["power_out"]))
	ex.rest("s1", 5)
	assert_eq(ex.st.clock, 170)
	assert_eq(ex.st.fired["lickers_inner"], "altered")
	assert_true(ex.st.pending_battle.is_empty())
	ex.rest("s1", 17)
	assert_eq(ex.st.clock, 187)
	assert_eq(ex.st.outcome, "returned")
	var results: Dictionary = ex.finish()
	assert_eq(int(results["zheng_zha"]["final_points"]), 6500)
	assert_eq(int(results["zhang_jie"]["final_points"]), 6600)
	assert_true(g.characters["zheng_zha"].tickets.has_at_least("B"))
	assert_eq(g.films_record, ["biohazard1"])


## 下水道路线：分兵后全队在下水道，有丧尸犬和爬行者，撑到最后拿 D 级支线。
func test_sewer_route() -> void:
	var ex := _to_laser()
	ex.choose("save_matthew")
	ex.move("s1", "control")
	ex.rest("s1", 25)
	assert_eq(ex.st.clock, 70)
	_win(ex)
	ex.rest("s1", 20)
	assert_eq(ex.st.clock, 90)
	ex.choose("follow")
	assert_eq(ex.st.location_of("zheng_zha"), "sewer")
	assert_eq(ex.st.npcs["matthew"]["location"], "sewer")
	var sid: String = ex.st.squad_of("zheng_zha")
	ex.rest(sid, 10)
	assert_eq(ex.st.clock, 100)
	assert_eq(ex.st.pending_battle["location"], "sewer")
	_win(ex)
	ex.rest(sid, 50)
	assert_eq(ex.st.clock, 150)
	assert_eq(ex.st.pending_battle["location"], "sewer")
	_win(ex)
	ex.rest(sid, 30)
	assert_eq(ex.st.clock, 180)
	assert_true(bool(ex.st.flags["sewer_out"]))
	ex.rest(sid, 7)
	assert_eq(ex.st.outcome, "returned")
	assert_true(bool(ex.st.flags.get("side:sewer_escape", false)))
