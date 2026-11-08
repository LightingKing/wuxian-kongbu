extends "res://tests/test_case.gd"

const AiSettings = preload("res://ai/ai_settings.gd")
const AiService = preload("res://ai/ai_service.gd")
const Persona = preload("res://ai/persona.gd")


## 假传输层：记下收到的请求，同步回调一个预设的响应。
class FakeTransport extends RefCounted:
	var requests: Array[Dictionary] = []
	var response: Dictionary = {}

	func send(req: Dictionary, done: Callable) -> void:
		requests.append(req)
		done.call(response)


func _anthropic_reply(text: String, stop: String = "end_turn") -> Dictionary:
	return {"ok": true, "status": 200, "body": JSON.stringify({"stop_reason": stop, "content": [{"type": "text", "text": text}]}), "error": ""}


func _service(t: RefCounted) -> RefCounted:
	var s := AiSettings.defaults()
	s["api_key"] = "sk-test"
	return AiService.new(s, t)


func _ask(svc: RefCounted, task: Dictionary, persona: RefCounted = null) -> Dictionary:
	var box := {}
	svc.ask(task, persona, func(result: Dictionary) -> void: box["r"] = result)
	return box["r"]


const LINE_TASK := {"id": "bh1:matthew:1", "kind": "npc_line", "tier": "fast", "situation": "车厢里，雇佣兵刚闯进来"}


func test_ai_path() -> void:
	var t := FakeTransport.new()
	t.response = _anthropic_reply("{\"say\": \"你们是谁？\"}")
	var svc := _service(t)
	var r := _ask(svc, LINE_TASK, Persona.from_data("matthew"))
	assert_eq(r, {"id": "bh1:matthew:1", "intent": {"say": "你们是谁？"}, "source": "ai", "reason": ""})
	assert_eq(t.requests.size(), 1)
	var body: Dictionary = JSON.parse_string(t.requests[0]["body"])
	assert_eq(body["model"], "claude-haiku-5-5")
	assert_true(String(body["system"][0]["text"]).contains("主神空间"))
	assert_true(String(body["system"][1]["text"]).contains("马修·艾迪森"))
	assert_true(String(body["messages"][0]["content"]).contains("雇佣兵刚闯进来"))
	assert_eq(int(svc.stats["ai"]), 1)


## 同一个任务第二次直接用记录，不再调用模型（读档可复现）。
func test_replay() -> void:
	var t := FakeTransport.new()
	t.response = _anthropic_reply("{\"say\": \"第一次\"}")
	var svc := _service(t)
	_ask(svc, LINE_TASK)
	t.response = _anthropic_reply("{\"say\": \"第二次\"}")
	var again := _ask(svc, LINE_TASK)
	assert_eq(again["source"], "replay")
	assert_eq(again["intent"], {"say": "第一次"})
	assert_eq(t.requests.size(), 1)
	var restored := _service(FakeTransport.new())
	restored.replay.load_dict(JSON.parse_string(JSON.stringify(svc.replay.to_dict())))
	assert_eq(_ask(restored, LINE_TASK)["intent"], {"say": "第一次"})


## 没配置（没有密钥）就离线兜底，不调用传输层。
func test_offline_fallback() -> void:
	var saved := OS.get_environment("ANTHROPIC_API_KEY")
	OS.unset_environment("ANTHROPIC_API_KEY")
	var t := FakeTransport.new()
	var svc := AiService.new(AiSettings.defaults(), t)
	assert_false(svc.online())
	var r := _ask(svc, LINE_TASK, Persona.from_data("matthew"))
	assert_eq(r["source"], "fallback")
	assert_eq(r["reason"], "offline")
	assert_eq(t.requests.size(), 0)
	assert_true(Persona.from_data("matthew").fallback_lines.has(String(r["intent"]["say"])))
	assert_eq(_ask(AiService.new(), {"id": "x", "kind": "replies"})["source"], "fallback")
	if saved != "":
		OS.set_environment("ANTHROPIC_API_KEY", saved)


## AI 出错或输出不合格时走兜底，并记下原因。
func test_failures_fall_back() -> void:
	var cases := [
		[{"ok": false, "status": 0, "body": "", "error": "result_4"}, "transport:result_4"],
		[_anthropic_reply("", "refusal"), "refusal"],
		[{"ok": true, "status": 529, "body": JSON.stringify({"error": {"message": "overloaded"}}), "error": ""}, "http_529 overloaded"],
		[_anthropic_reply("我不想用 JSON"), "invalid:not_object"],
		[_anthropic_reply("{\"choice\": \"fly\", \"say\": \"\"}"), "invalid:illegal_choice"],
	]
	var task := {"id": "c", "kind": "choose", "options": [{"id": "stay", "text": "留下"}, {"id": "go", "text": "走"}]}
	for c in cases:
		var t := FakeTransport.new()
		t.response = c[0]
		var svc := _service(t)
		var r := _ask(svc, task)
		assert_eq(r["source"], "fallback", String(c[1]))
		assert_eq(r["reason"], String(c[1]))
		assert_eq(r["intent"], {"choice": "stay", "say": ""})
		assert_eq(String(svc.stats["last_error"]), String(c[1]))


## 主神问答走 strong 档（Opus），带拒答回退。
func test_strong_tier_request() -> void:
	var t := FakeTransport.new()
	t.response = _anthropic_reply("{\"answer\": \"是真实的生命。\", \"refuse\": false}")
	var svc := _service(t)
	var task := {"id": "q1", "kind": "zhushen_answer", "tier": "strong", "question": "造出来的人是真的吗？", "forbidden": ["恶魔小队"]}
	var r := _ask(svc, task, Persona.from_data("zhushen"))
	assert_eq(r["intent"], {"answer": "是真实的生命。", "refuse": false})
	var body: Dictionary = JSON.parse_string(t.requests[0]["body"])
	assert_eq(body["model"], "claude-opus-5-5")
	assert_eq(body["fallbacks"], "default")
	assert_eq(body["output_config"]["format"]["schema"]["required"], ["answer", "refuse"])
