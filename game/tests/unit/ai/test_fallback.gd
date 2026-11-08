extends "res://tests/test_case.gd"

const Fallback = preload("res://ai/fallback.gd")
const Persona = preload("res://ai/persona.gd")
const Intents = preload("res://ai/intents.gd")


## 同一个任务 id 总是同一句台词，而且是人设里的台词。
func test_npc_line_is_deterministic() -> void:
	var m := Persona.from_data("matthew")
	var task := {"id": "bh1:matthew:car:1", "kind": "npc_line"}
	var a := Fallback.respond(task, m)
	assert_eq(Fallback.respond(task, m), a)
	assert_true(m.fallback_lines.has(String(a["say"])))
	assert_eq(Fallback.respond(task, null), {"say": "……"})


func test_choose_highest_fallback_score() -> void:
	var task := {"id": "c", "kind": "choose", "options": [{"id": "a", "text": "A"}, {"id": "b", "text": "B", "fallback": 2}, {"id": "c", "text": "C", "fallback": 2}]}
	assert_eq(Fallback.respond(task, null), {"choice": "b", "say": ""})
	task["options"] = [{"id": "x", "text": "X"}, {"id": "y", "text": "Y"}]
	assert_eq(Fallback.respond(task, null)["choice"], "x")


func test_persuade_keywords() -> void:
	var task := {"id": "p", "kind": "persuade", "argument": "我知道电影的剧情，激光通道有陷阱，跟着我能活下去", "keywords": ["剧情", "陷阱", "活下去", "钱"]}
	assert_eq(Fallback.respond(task, null)["level"], 3)
	task["keywords"] = []
	assert_eq(Fallback.respond(task, null)["level"], 1)
	task["argument"] = "求你了"
	assert_eq(Fallback.respond(task, null)["level"], 0)


func test_zhushen_faq_or_refuse() -> void:
	var task := {"id": "q", "kind": "zhushen_answer", "question": "造出来的人是不是真的？", "faq": [{"keywords": ["造", "人造人"], "answer": "是真实的生命。"}]}
	assert_eq(Fallback.respond(task, null), {"answer": "是真实的生命。", "refuse": false})
	task["question"] = "主神空间是谁建的？"
	assert_eq(Fallback.respond(task, null), {"answer": "此问题超出你的权限。", "refuse": true})


func test_replies() -> void:
	assert_eq(Fallback.respond({"id": "r", "kind": "replies"}, null)["replies"], ["明白了。", "我不同意。", "再说清楚一点。"])
	assert_eq(Fallback.respond({"id": "r", "kind": "replies", "default_replies": ["是", "否"]}, null)["replies"], ["是", "否"])


## 兜底的输出本身也要能通过意图校验。
func test_fallback_outputs_validate() -> void:
	var tasks: Array[Dictionary] = [
		{"id": "1", "kind": "npc_line"},
		{"id": "2", "kind": "choose", "options": [{"id": "a", "text": "A"}]},
		{"id": "3", "kind": "persuade", "argument": "x"},
		{"id": "4", "kind": "zhushen_answer", "question": "?", "forbidden": ["秘密"]},
		{"id": "5", "kind": "replies"},
	]
	for t in tasks:
		var v := Intents.validate(String(t["kind"]), Fallback.respond(t, Persona.from_data("zhushen")), t)
		assert_true(bool(v["ok"]), "%s %s" % [t["kind"], v["errors"]])
