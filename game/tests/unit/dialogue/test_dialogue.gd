extends "res://tests/test_case.gd"
## 对话层：离线搭话、记忆与合并、说服评分、主神问答、信任门槛、回放。

const Dialogue = preload("res://core/dialogue/dialogue.gd")
const AiService = preload("res://ai/ai_service.gd")
const Persona = preload("res://ai/persona.gd")
const Scenario = preload("res://core/expedition/scenario.gd")

const SCENARIO := "res://data/scenarios/biohazard1/scenario.json"


func _offline() -> RefCounted:
	return AiService.new({"provider": "offline"}, null)


func _personas(ids: Array) -> Dictionary:
	var out := {}
	for id: String in ids:
		out[id] = Persona.from_data(id)
	return out


## 离线时回调是同步的，所以直接看 out[0] 就行。
func test_offline_line_uses_persona() -> void:
	var d := Dialogue.new(_offline(), _personas(["kaplan"]), {})
	var out: Array = []
	d.say("kaplan", "", "在蜂巢入口大厅", func(res: Dictionary) -> void: out.append(res))
	assert_eq(out.size(), 1)
	assert_eq(String(out[0]["source"]), "fallback")
	var p: RefCounted = d.persona("kaplan")
	assert_true(p.fallback_lines.has(String(out[0]["say"])), "台词来自人设的 fallback_lines")


func test_unknown_npc_degrades() -> void:
	var d := Dialogue.new(_offline(), {}, {})
	var out: Array = []
	d.say("nobody", "喂", "大厅", func(res: Dictionary) -> void: out.append(res))
	assert_eq(String(out[0]["source"]), "none")
	assert_eq(String(out[0]["say"]), "……")
	assert_false(d.has_persona("nobody"))


func test_memory_grows_and_merges() -> void:
	var d := Dialogue.new(_offline(), _personas(["kaplan"]), {})
	d.remember("kaplan", "第一件事")
	assert_eq(d.memories_of("kaplan").size(), 1)
	assert_true(d.persona("kaplan").memories.has("第一件事"), "记忆同步给了人设")
	for i in 15:
		d.remember("kaplan", "第 %d 条" % i)
	assert_eq(d.memories_of("kaplan").size(), Persona.MAX_MEMORIES)
	assert_true(String(d.memories_of("kaplan")[0]).begins_with("更早的事："), "超上限时最早两条并成一条")
	assert_eq(d.persona("kaplan").memories.size(), Persona.MAX_MEMORIES)


## 说话会同时记玩家和 NPC 两条。
func test_say_records_both_sides() -> void:
	var d := Dialogue.new(_offline(), _personas(["alice"]), {})
	d.say("alice", "激光通道怎么过", "在激光通道", func(_res: Dictionary) -> void: pass)
	var mem: Array = d.memories_of("alice")
	assert_eq(mem.size(), 2)
	assert_true(String(mem[0]).contains("激光通道怎么过"))
	assert_true(String(mem[1]).begins_with("我说："))


## 离线评分：命中几个关键词就是几级，最多 3。
func test_rate_counts_keywords_offline() -> void:
	var d := Dialogue.new(_offline(), _personas(["red_queen"]), {})
	var out: Array = []
	d.rate("red_queen", "断电，不然我用激光烧你", "逼她动手", ["威胁", "断电", "激光"], "主机房", func(r: Dictionary) -> void: out.append(r))
	assert_eq(int(out[0]["level"]), 2)
	assert_eq(String(out[0]["source"]), "fallback")
	out.clear()
	d.rate("red_queen", "求你了", "逼她动手", ["威胁", "断电", "激光"], "主机房", func(r: Dictionary) -> void: out.append(r))
	assert_eq(int(out[0]["level"]), 0)


func test_zhushen_faq_and_refusal() -> void:
	var d := Dialogue.new(_offline(), {}, {})
	var faq := [{"keywords": ["兑换", "强化"], "answer": "回归当晚之后才可以兑换。"}]
	var out: Array = []
	d.ask_zhushen("怎么兑换强化", faq, [], func(r: Dictionary) -> void: out.append(r))
	assert_true(String(out[0]["answer"]).contains("兑换"))
	assert_false(bool(out[0]["refuse"]))
	out.clear()
	d.ask_zhushen("下一部电影是什么", faq, [], func(r: Dictionary) -> void: out.append(r))
	assert_true(bool(out[0]["refuse"]))
	assert_false(String(out[0]["answer"]).contains("兑换"))


## 信任跨过门槛时给一条 confide；同一门槛只触发一次。
func test_trust_confide_once() -> void:
	var d := Dialogue.new(_offline(), _personas(["kaplan"]), {})
	var def := {"at": 2, "line": "……激光是女皇自己控的。", "effects": [{"clue": "queen_console"}]}
	assert_eq(d.add_trust("kaplan", 1, def).size(), 0)
	var ev: Array[Dictionary] = d.add_trust("kaplan", 1, def)
	assert_eq(ev.size(), 1)
	assert_eq(String(ev[0]["type"]), "confide")
	assert_eq(String(ev[0]["npc"]), "kaplan")
	assert_eq((ev[0]["effects"] as Array).size(), 1)
	assert_eq(d.trust_of("kaplan"), 2)
	assert_eq(d.add_trust("kaplan", 1, def).size(), 0, "同一门槛不重复触发")
	assert_eq(d.trust_of("kaplan"), 3)


func test_trust_is_clamped() -> void:
	var d := Dialogue.new(_offline(), {}, {})
	d.add_trust("kaplan", 99, {})
	assert_eq(d.trust_of("kaplan"), Dialogue.TRUST_MAX)
	d.add_trust("kaplan", -99, {})
	assert_eq(d.trust_of("kaplan"), 0)


## 同一句话说第二次走回放，不重复花钱，结果一致。
func test_same_line_replays() -> void:
	var d := Dialogue.new(_offline(), _personas(["kaplan"]), {})
	var first: Array = []
	var second: Array = []
	d.say("kaplan", "你好", "大厅", func(r: Dictionary) -> void: first.append(r))
	d.say("kaplan", "你好", "大厅", func(r: Dictionary) -> void: second.append(r))
	assert_eq(String(first[0]["source"]), "fallback")
	assert_eq(String(second[0]["source"]), "replay")
	assert_eq(String(second[0]["say"]), String(first[0]["say"]))


## 剧本里的信任配置要指向真实存在的人设与线索。
func test_scenario_trust_data() -> void:
	var sc := Scenario.load_file(SCENARIO)
	assert_true(sc.data.has("trust"), "剧本要有 trust 段")
	var personas := Persona.load_all()
	for id: String in sc.data["trust"]:
		var t: Dictionary = sc.data["trust"][id]
		assert_true(personas.has(id), id + " 没有 AI 人设")
		assert_true(int(t["at"]) >= 1, id + " 的门槛要是正数")
		assert_true(String(t["line"]) != "", id + " 要有台词")
		for e: Dictionary in t.get("effects", []):
			assert_true(e.has("clue"), id + " 的信任效果要给线索")
			assert_true((sc.data["facts"]["queen_controls_lasers"]["clues"] as Dictionary).has(String(e["clue"]))
				or (sc.data["facts"]["matthew_doomed"]["clues"] as Dictionary).has(String(e["clue"]))
				or (sc.data["facts"]["zhang_jie_hiding"]["clues"] as Dictionary).has(String(e["clue"])),
				String(e["clue"]) + " 不属于任何事实")
