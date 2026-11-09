extends "res://tests/test_case.gd"

const Campaign = preload("res://core/campaign/campaign.gd")
const GameState = preload("res://core/model/game_state.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const BattleData = preload("res://core/battle/battle_data.gd")
const Persona = preload("res://ai/persona.gd")
const Talents = preload("res://core/model/talents.gd")

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


## 章节的议程块：开局就记下张杰的半引导者异常和"按张杰定难度"的决定，各带主神理由。
func test_chapter_agenda() -> void:
	var g := GameState.new(1)
	Campaign.start(g, CHAPTER)
	var id: String = g.agenda.open_anomaly("half_guide", "zhang_jie")
	assert_eq(id, "anomaly_1")
	var kinds: Array = []
	for d: Dictionary in g.agenda.decisions:
		kinds.append(String(d["kind"]))
		assert_true(String(d["reason"]) != "", "每个决定都要有主神理由")
	assert_eq(kinds, ["add_anomaly", "difficulty_anchor"])
	Campaign.apply_agenda(g, Campaign.load_chapter(CHAPTER), "biohazard1")
	assert_eq(g.agenda.open_anomalies().size(), 1, "同一异常不重复记")


## 张杰讲规则：开场就进三条百科；认真听再加五条，质疑的只有开场那三条。
func test_opening_codex() -> void:
	var g := GameState.new(1)
	var ex := Campaign.start(g, CHAPTER)
	assert_eq(g.codex.order, ["survive_points", "go_home", "watch_tasks"])
	ex.choose("listen")
	assert_eq(g.codex.order.size(), 8)
	assert_true(g.codex.is_known("tether"))
	var g2 := GameState.new(1)
	var ex2 := Campaign.start(g2, CHAPTER)
	ex2.choose("doubt")
	assert_eq(g2.codex.order.size(), 3)
	assert_almost(g2.relations.value("zhang_jie", "zheng_zha", "trust"), 45.0)


## 嘲讽张杰：他对郑吒信任 40、怨恨 15，服从度不到 40，下一场战斗由 AI 接管。
func test_mock_makes_zhang_jie_disobey() -> void:
	var g := GameState.new(1)
	var ex := Campaign.start(g, CHAPTER)
	var events: Array[Dictionary] = ex.choose("mock")
	assert_true(_types(events).has("relation_event"))
	assert_almost(g.relations.value("zhang_jie", "zheng_zha", "trust"), 40.0)
	assert_almost(g.relations.value("zhang_jie", "zheng_zha", "resentment"), 15.0)
	assert_false(ex.obeys("zhang_jie"))
	assert_true(ex.obeys("zhan_lan"))
	assert_true(ex.obeys("zheng_zha"), "拍板的人自己永远听自己的")
	ex.st.pending_battle = {"location": "car", "squad": "s1", "enemies": [{"def": "zombie", "count": 1}], "dark": false, "survive_until": -1.0, "after_victory": [], "after_defeat": []}
	assert_eq(ex.disobedient(), ["zhang_jie"] as Array[String])
	for u: RefCounted in ex.battle_units({}):
		if u.side == "ally":
			assert_eq(u.controller, "ai" if u.character_id == "zhang_jie" else "player", u.character_id)


## 扔下掉队的人：在场的人对郑吒信任 −10（两个当事人也只算一次），掉到 40，不听指挥；
## 一起打过一仗（并肩作战 +5）又回到听指挥。
func test_leave_costs_trust_until_fought_together() -> void:
	var g := GameState.new(1)
	var ex := Campaign.start(g, CHAPTER)
	ex.choose("doubt")
	ex.move("s1", "hall")
	ex.move("s1", "stairs")
	ex.choose("leave")
	assert_almost(g.relations.value("zhan_lan", "zheng_zha", "trust"), 40.0)
	assert_false(ex.obeys("zhan_lan"))
	assert_false(ex.obeys("li_xiao_yi"))
	ex.st.pending_battle = {"location": "stairs", "squad": "s1", "enemies": [{"def": "zombie", "count": 1}], "dark": false, "survive_until": -1.0, "after_victory": [], "after_defeat": []}
	var events := _win(ex)
	assert_true(_types(events).has("bonded"))
	assert_almost(g.relations.value("zhan_lan", "zheng_zha", "trust"), 45.0)
	assert_true(ex.obeys("zhan_lan"))


## 站位：抗打（肌肉 + 细胞活力）的一半站前排。七个人时张杰、牟钢、郑吒、李萧毅在前；
## 只剩四个人时张杰、郑吒在前，詹岚在后排（近战够不着）。分队共用的道具还是郑吒背。
func test_formation_tough_in_front() -> void:
	var g := GameState.new(1)
	var ex := Campaign.start(g, CHAPTER)
	ex.choose("listen")
	ex.st.pending_battle = {"location": "car", "squad": "s1", "enemies": [{"def": "zombie", "count": 1}], "dark": false, "survive_until": -1.0, "after_victory": [], "after_defeat": []}
	var rows := {}
	for u: RefCounted in ex.battle_units({}):
		if u.side == "ally":
			rows[u.character_id] = u.row
	assert_eq(rows, {"zhang_jie": 0, "mu_gang": 0, "zheng_zha": 0, "li_xiao_yi": 0, "zhan_lan": 1, "zhong_nian_fu_nv": 1, "xiao_pang_zi": 1})
	assert_eq(String(ex.st.pending_battle["carrier"]), "zheng_zha")
	for c in ["mu_gang", "xiao_pang_zi", "zhong_nian_fu_nv"]:
		g.characters[c].alive = false
	rows = {}
	for u: RefCounted in ex.battle_units({}):
		if u.side == "ally":
			rows[u.character_id] = u.row
	assert_eq(rows, {"zhang_jie": 0, "zheng_zha": 0, "li_xiao_yi": 1, "zhan_lan": 1})


## 规格 9.3：爬行者破内门之后是"坚持到倒计时结束"，不是清场。
func test_inner_lickers_hold_out() -> void:
	var sc := Scenario.load_file(SCENARIO)
	var found := false
	for ev: Dictionary in sc.events():
		if String(ev["id"]) == "lickers_inner":
			for e: Dictionary in ev["effects"]:
				if e.has("battle"):
					found = true
					assert_almost(float(e["battle"]["survive_until"]), 400.0)
	assert_true(found)


## 走到激光通道门口：听规则 → 大厅 → 楼梯井（扶掉队的人）→ 激光通道。
func _to_laser() -> RefCounted:
	var ex := _start()
	ex.choose("listen")
	ex.move("s1", "hall")
	ex.move("s1", "stairs")
	ex.choose("help")
	ex.move("s1", "laser")
	ex.dismiss_cutscene()
	# 激光通道里先说通马修（难度 1，等级 2 必成），才轮到救人选择。
	assert_eq(String(ex.st.pending_check.get("id", "")), "convince_matthew", "激光通道要先过说服马修")
	ex.resolve_persuasion(2)
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
	# 救命之恩：被扶的人对郑吒信任 +25；旁观的人 +5（两个当事人只算一次）。
	assert_almost(ex.game.relations.value("xiao_pang_zi", "zheng_zha", "trust"), 75.0)
	assert_almost(ex.game.relations.value("zhan_lan", "zheng_zha", "trust"), 55.0)
	# 队伍肯停下来等：小胖子"傻人有傻福"、中年妇女"稳住人心"觉醒，后者让同地点其他人恐惧 −10。
	assert_true(Talents.is_awake(ex.st.characters["xiao_pang_zi"], "lucky"))
	assert_true(Talents.is_awake(ex.st.characters["zhong_nian_fu_nv"], "calm_voice"))
	assert_almost(ex.st.characters["zheng_zha"].fear, 14.5 * 100.0 / 110.0 - 10.0)


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
	# 同伴在面前被抹杀：郑吒的"不屈"觉醒。
	assert_true(Talents.is_awake(ex.st.characters["zheng_zha"], "iron_will"))


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
	# 救下马修，在场的人看在眼里：扶人 +5、救马修 +5。
	assert_almost(ex.game.relations.value("zhan_lan", "zheng_zha", "trust"), 60.0)
	assert_almost(ex.game.relations.value("zhan_lan", "zheng_zha", "awe"), 30.0)
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
	# 眼看牟钢死在激光里：在场的人对郑吒信任 −10（扶人时 +5，现在 45）。
	assert_almost(ex.game.relations.value("zhan_lan", "zheng_zha", "trust"), 45.0)


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
	ex.dismiss_cutscene()
	assert_eq(String(ex.st.pending_check.get("id", "")), "convince_matthew")
	ex.resolve_persuasion(2)
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
	var zl_trust: float = g.relations.value("zhan_lan", "zheng_zha", "trust")
	ex.choose("stay")
	assert_true(bool(ex.st.flags["stay_control"]))
	assert_almost(g.relations.value("zhan_lan", "zheng_zha", "trust"), zl_trust + 8.0, 0.0001, "詹岚的提议被采纳")
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
	assert_eq(int(results["zhang_jie"]["final_points"]), 1100, "张杰只拿存活 1000 和自己的讲解奖励 100")
	assert_eq(int(results["mu_gang"]["final_points"]), 1000, "个人支线不发给别人")
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
	var zl_trust: float = ex.game.relations.value("zhan_lan", "zheng_zha", "trust")
	ex.choose("follow")
	assert_almost(ex.game.relations.value("zhan_lan", "zheng_zha", "trust"), zl_trust - 5.0, 0.0001, "詹岚的提议被驳回")
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
