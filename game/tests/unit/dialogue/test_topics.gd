extends "res://tests/test_case.gd"
## 固定话题：话题文件完整；什么时候能聊（地点、信任、先聊过哪个）；列车上剧情人物听不见、只能看看；
## 聊第一次才跑效果；回答按情况变；人物卡要点；聊过的话题跟着存档走。

const Topics = preload("res://core/dialogue/topics.gd")
const Campaign = preload("res://core/campaign/campaign.gd")
const GameState = preload("res://core/model/game_state.gd")
const ExpeditionState = preload("res://core/expedition/expedition_state.gd")

const SQUAD: Array[String] = ["zheng_zha", "zhang_jie", "zhan_lan", "li_xiao_yi", "mu_gang", "xiao_pang_zi", "zhong_nian_fu_nv"]


const CHAPTER := "res://data/scenarios/biohazard1/chapter.json"


func _start() -> RefCounted:
	return Campaign.start(GameState.new(1), CHAPTER)


func _ids(list: Array) -> Array[String]:
	var out: Array[String] = []
	for t: Dictionary in list:
		out.append(String(t["id"]))
	return out


## 话题文件：id 不重复、都有问题和回答、after 指向存在的话题、人物都存在；在场的 13 个人（除了你自己）每人都有话题。
func test_topics_file_valid() -> void:
	var s := _start()
	var sc: RefCounted = s.st.scenario
	var people: Array = sc.data["npcs"].keys()
	people.append_array(SQUAD)
	var errors: Array[String] = Topics.validate(sc, people)
	assert_eq(errors.size(), 0, "\n".join(errors))
	for id in ["zhang_jie", "zhan_lan", "li_xiao_yi", "mu_gang", "xiao_pang_zi", "zhong_nian_fu_nv", "matthew", "alice", "ryan", "matt", "kaplan", "jd", "rain"]:
		assert_true(Topics.defs(s.st, id).size() >= 2, "%s 至少两个话题" % id)


## 列车上：剧情人物和你们在同一节车里，但听不见你们说话（原著：车减速之前）——只能"看看"。下了车就能聊了。
func test_unheard_on_the_train() -> void:
	var s := _start()
	var st: RefCounted = s.st
	assert_eq(String(st.npcs["matthew"]["location"]), "car", "雇佣兵和你们在同一趟车上")
	assert_false(Topics.can_hear(st, "matthew"))
	assert_true(Topics.can_hear(st, "zhang_jie"), "轮回者总听得见")
	assert_eq(_ids(Topics.available(st, "matthew", 0)), ["matthew_look"] as Array[String])
	s.choose("listen")
	s.move("s1", "hall")
	assert_eq(String(st.npcs["matthew"]["location"]), "hall")
	assert_true(Topics.can_hear(st, "matthew"))
	assert_eq(_ids(Topics.available(st, "matthew", 0)), ["matthew_where"] as Array[String], "看看的话题收起来了；先问去哪")


## 信任门槛和先后：张杰的枪要信任 2，经历要信任 3；马修先回答去哪，才会说他不信任你们。
func test_trust_and_after() -> void:
	var s := _start()
	var st: RefCounted = s.st
	assert_eq(_ids(Topics.available(st, "zhang_jie", 0)), ["zhang_jie_who", "zhang_jie_rules", "zhang_jie_plan"] as Array[String])
	assert_true(_ids(Topics.available(st, "zhang_jie", 2)).has("zhang_jie_gun"))
	assert_false(_ids(Topics.available(st, "zhang_jie", 2)).has("zhang_jie_past"))
	assert_true(_ids(Topics.available(st, "zhang_jie", 3)).has("zhang_jie_past"))
	assert_false(_ids(Topics.available(st, "li_xiao_yi", 0)).has("li_xiao_yi_warn"), "提醒他嘴上留神只在站台上、聊过以后")
	s.choose("listen")
	s.move("s1", "hall")
	assert_false(_ids(Topics.available(st, "matthew", 0)).has("matthew_doubt"))
	s.talk_topic("matthew", "matthew_where", 0)
	assert_true(_ids(Topics.available(st, "matthew", 0)).has("matthew_doubt"))


## 聊一个话题：第一次标成聊过、跑效果（线索、百科）；再问一遍照样回答，但不再跑效果；聊不了的返回空。
func test_talk_topic_effects_once() -> void:
	var s := _start()
	var ex: RefCounted = s
	assert_eq(ex.talk_topic("zhang_jie", "zhang_jie_gun", 0), {}, "信任不够聊不了")
	var r: Dictionary = ex.talk_topic("zhang_jie", "zhang_jie_gun", 2)
	assert_true(bool(r["new"]))
	assert_true(String(r["text"]).contains("沙漠之鹰"))
	assert_true(ex.st.topics_seen.has("zhang_jie_gun"))
	assert_true(ex.st.intel.clues_found.has("desert_eagle"), "给了线索")
	var again: Dictionary = ex.talk_topic("zhang_jie", "zhang_jie_gun", 2)
	assert_false(bool(again["new"]))
	assert_eq((again["events"] as Array).size(), 0)
	var rules: Dictionary = ex.talk_topic("zhang_jie", "zhang_jie_rules", 0)
	var types: Array = []
	for e: Dictionary in rules["events"]:
		types.append(String(e["type"]))
	assert_true(types.has("topic_talked"))


## 回答跟着情况变：张杰在车上和在站台上说的不一样；小胖子怕起来说的话不一样。
func test_variants() -> void:
	var s := _start()
	var st: RefCounted = s.st
	var plan: Dictionary = Topics.find(st, "zhang_jie", "zhang_jie_plan")
	assert_true(Topics.text_of(st, "zhang_jie", plan).contains("等车停了"))
	s.choose("listen")
	s.move("s1", "hall")
	assert_true(Topics.text_of(st, "zhang_jie", plan).contains("主电脑"))
	var status: Dictionary = Topics.find(st, "xiao_pang_zi", "xiao_pang_zi_status")
	st.characters["xiao_pang_zi"].fear = 10.0
	assert_true(Topics.text_of(st, "xiao_pang_zi", status).contains("跑不快"))
	st.characters["xiao_pang_zi"].fear = 60.0
	assert_true(Topics.text_of(st, "xiao_pang_zi", status).contains("腿软"))


## 人物卡要点：聊过的话题的 card；没聊过的话题数。瑞恩想起车上藏了东西，给"瑞恩在列车上藏了东西"的线索。
func test_notes_and_ryan_clue() -> void:
	var s := _start()
	var ex: RefCounted = s
	assert_eq(Topics.notes(ex.st, "ryan").size(), 0)
	var total: int = Topics.unseen_count(ex.st, "ryan")
	ex.talk_topic("ryan", "ryan_look", 0)
	assert_eq(Topics.notes(ex.st, "ryan").size(), 1)
	assert_true(Topics.notes(ex.st, "ryan")[0].contains("商业间谍"), "郑吒认得他")
	assert_eq(Topics.unseen_count(ex.st, "ryan"), total - 1)
	ex.choose("listen")
	ex.move("s1", "hall")
	ex.talk_topic("ryan", "ryan_who", 0)
	ex.talk_topic("ryan", "ryan_train", 0)
	assert_true(ex.st.intel.clues_found.has("ryan_memory"))
	assert_true(Topics.has_new(ex.st, "matt", 0))


## 聊过的话题跟着存档走；旧存档没有这一项也读得进来。
func test_topics_seen_saved() -> void:
	var s := _start()
	s.talk_topic("zhan_lan", "zhan_lan_who", 0)
	var d: Dictionary = s.st.to_dict()
	var st2 := ExpeditionState.new()
	st2.load_dict(d, s.st.scenario, s.st.characters)
	assert_true(st2.topics_seen.has("zhan_lan_who"))
	d.erase("topics_seen")
	var st3 := ExpeditionState.new()
	st3.load_dict(d, s.st.scenario, s.st.characters)
	assert_eq(st3.topics_seen.size(), 0)
