extends "res://tests/test_case.gd"

const Morning = preload("res://core/hub/morning.gd")
const Session = preload("res://core/session/session.gd")

const EVENTS := "res://data/hub/m1_morning.json"


func _session() -> RefCounted:
	var s := Session.new()
	s.start_m1(1)
	s.expedition.st.outcome = "returned"
	s.settle()
	s.enter_hub()
	return s


## 挑事件看条件：张杰活着是"结盟"，死了是"没有老手的早晨"；新人去留挑第一个活着的新人，名字填进去。
func test_pick_by_conditions() -> void:
	var s := _session()
	var events: Array = Morning.load_events(EVENTS)
	assert_eq(String(Morning.pick(s.game, events, 1, [])["id"]), "zhang_jie_alliance")
	s.game.characters["zhang_jie"].alive = false
	assert_eq(String(Morning.pick(s.game, events, 1, [])["id"]), "no_veteran")
	s.game.characters["li_xiao_yi"].alive = false
	var ev := Morning.pick(s.game, events, 2, ["no_veteran"])
	assert_eq(String(ev["id"]), "newbie_stays")
	assert_eq(String(ev["who"]), "mu_gang")
	assert_true(String(ev["prompt"]).begins_with("牟钢"))
	assert_eq(Morning.pick(s.game, events, 1, ["no_veteran", "zhang_jie_alliance"]), {}, "第 1 天只有前两件够格")


## 新人都死了：新人去留和借点数都不会发生。
func test_skip_when_nobody_fits() -> void:
	var s := _session()
	for c in ["li_xiao_yi", "mu_gang", "xiao_pang_zi", "zhong_nian_fu_nv"]:
		s.game.characters[c].alive = false
	var events: Array = Morning.load_events(EVENTS)
	var seen := ["zhang_jie_alliance", "zhan_lan_talk"]
	assert_eq(Morning.pick(s.game, events, 9, seen), {})


## 效果：借点数真的转账、关系和恐惧照选项变、百科解锁。
func test_apply_effects() -> void:
	var s := _session()
	var events: Array = Morning.load_events(EVENTS)
	var help := Morning.pick(s.game, events, 4, ["zhang_jie_alliance", "newbie_stays", "zhan_lan_talk"])
	assert_eq(String(help["id"]), "points_help")
	var who := String(help["who"])
	var before: int = s.game.characters["zheng_zha"].points
	var out: Array[Dictionary] = Morning.apply(s.game, help, "give")
	assert_eq(String(out[0]["type"]), "morning_answered")
	assert_eq(s.game.characters["zheng_zha"].points, before - 500)
	assert_eq(s.game.characters[who].points, 1500)
	assert_almost(s.game.relations.value(who, "zheng_zha", "trust"), 65.0)
	var talk := Morning.pick(s.game, events, 3, ["zhang_jie_alliance", "newbie_stays"])
	Morning.apply(s.game, talk, "listen")
	assert_true(s.game.codex.is_known("team_rating"))
	assert_eq(String(Morning.apply(s.game, talk, "nope")[0]["type"]), "morning_refused")


## 休整里：第 1 天早上有晨会；回答后收起；不回答的话第二天早上按默认了结，然后出新的；每件只发生一次；存读档保留。
func test_hub_flow() -> void:
	var s := _session()
	var ev: Array[Dictionary] = s.hub.rest(1)
	assert_true(_has(ev, "morning_event"))
	assert_eq(String(s.hub.morning["id"]), "zhang_jie_alliance")
	var ans: Array[Dictionary] = s.hub.answer_morning("own_way")
	assert_eq(String(ans[0]["type"]), "morning_answered")
	assert_true(s.hub.morning.is_empty())
	assert_almost(s.game.relations.value("zhang_jie", "zheng_zha", "trust"), 45.0)
	ev = s.hub.rest(1)
	assert_eq(String(s.hub.morning["id"]), "newbie_stays")
	ev = s.hub.rest(1)
	var auto := false
	for e in ev:
		if e["type"] == "morning_answered" and bool(e["auto"]):
			auto = true
			assert_eq(String(e["option"]), "let_go")
	assert_true(auto, "没回答的晨会第二天按默认选项了结")
	var t := Session.new()
	assert_true(t.load_dict(s.to_dict()))
	assert_eq(t.hub.morning, s.hub.morning)
	assert_eq(t.hub.morning_seen, s.hub.morning_seen)
	s.hub.rest(6)
	assert_eq(s.hub.morning_seen, ["zhang_jie_alliance", "newbie_stays", "zhan_lan_talk", "points_help"], "张杰活着、萝丽没造出来，这两件不发生")
	assert_true(s.hub.morning.is_empty(), "出发那天没有晨会")


func _has(events: Array[Dictionary], type: String) -> bool:
	for e in events:
		if String(e["type"]) == type:
			return true
	return false
