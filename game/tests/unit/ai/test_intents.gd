extends "res://tests/test_case.gd"

const Intents = preload("res://ai/intents.gd")

const CHOOSE_TASK := {"id": "t1", "kind": "choose", "situation": "火焰女皇主机房", "options": [{"id": "stay", "text": "留守主机房"}, {"id": "follow", "text": "跟雇佣兵走"}]}


## 每种意图的 schema 都是结构化输出要求的形状。
func test_schemas() -> void:
	for kind in Intents.KINDS:
		var s := Intents.schema(kind)
		assert_eq(s["type"], "object", kind)
		assert_false(bool(s["additionalProperties"]), kind)
		assert_true((s["required"] as Array).size() > 0, kind)
	assert_eq(Intents.schema("persuade")["properties"]["level"], {"type": "integer"})


func test_user_prompt_lists_options() -> void:
	var p := Intents.user_prompt(CHOOSE_TASK)
	assert_true(p.contains("【局面】火焰女皇主机房"))
	assert_true(p.contains("- stay：留守主机房"))
	assert_true(p.contains("- follow：跟雇佣兵走"))
	assert_true(p.contains("只输出 JSON"))


## 容忍代码块和多余的文字。
func test_extract_json() -> void:
	assert_eq(Intents.extract_json("```json\n{\"say\": \"你好\"}\n```"), {"say": "你好"})
	assert_eq(Intents.extract_json("好的，我的回答是：{\"choice\": \"stay\", \"say\": \"\"} 就这样"), {"choice": "stay", "say": ""})
	assert_eq(Intents.extract_json("没有 JSON"), null)
	assert_eq(Intents.extract_json("{坏掉的}"), null)


func test_validate_npc_line() -> void:
	assert_eq(Intents.validate("npc_line", {"say": "  别跟丢了。 ", "extra": 1}, {}), {"ok": true, "intent": {"say": "别跟丢了。"}, "errors": [] as Array[String]})
	assert_false(bool(Intents.validate("npc_line", {"say": ""}, {})["ok"]))
	assert_eq(Intents.validate("npc_line", {"say": "长".repeat(201)}, {})["errors"], ["too_long"])
	assert_eq(Intents.validate("npc_line", "不是对象", {})["errors"], ["not_object"])


## AI 只能从合法选项里选（引擎裁决）。
func test_validate_choose() -> void:
	assert_true(bool(Intents.validate("choose", {"choice": "stay", "say": "就在这里等。"}, CHOOSE_TASK)["ok"]))
	assert_eq(Intents.validate("choose", {"choice": "fly_away", "say": ""}, CHOOSE_TASK)["errors"], ["illegal_choice"])


func test_validate_persuade() -> void:
	assert_eq(Intents.validate("persuade", {"level": 2, "reason": "有道理"}, {})["intent"], {"level": 2, "reason": "有道理"})
	assert_true(bool(Intents.validate("persuade", {"level": 3.0, "reason": ""}, {})["ok"]))
	assert_eq(Intents.validate("persuade", {"level": 5, "reason": ""}, {})["errors"], ["bad_level"])
	assert_eq(Intents.validate("persuade", {"level": 1.5, "reason": ""}, {})["errors"], ["bad_level"])
	assert_eq(Intents.validate("persuade", {"level": "高", "reason": ""}, {})["errors"], ["bad_level"])


## 主神的回答不能透露秘密；拒绝回答时不检查。
func test_validate_zhushen_secrets() -> void:
	var task := {"forbidden": ["恶魔小队"]}
	assert_true(bool(Intents.validate("zhushen_answer", {"answer": "造出来的人是真实的生命。", "refuse": false}, task)["ok"]))
	assert_eq(Intents.validate("zhushen_answer", {"answer": "恶魔小队的成员是……", "refuse": false}, task)["errors"], ["leaks_secret"])
	assert_true(bool(Intents.validate("zhushen_answer", {"answer": "关于恶魔小队，此问题超出你的权限。", "refuse": true}, task)["ok"]))


func test_validate_replies() -> void:
	var r := Intents.validate("replies", {"replies": ["好。", " ", "不行。", "再想想。"]}, {})
	assert_true(bool(r["ok"]))
	assert_eq(r["intent"]["replies"], ["好。", "不行。", "再想想。"])
	assert_eq(Intents.validate("replies", {"replies": ["只有一句"]}, {})["errors"], ["bad_replies"])
	assert_eq(Intents.validate("dance", {}, {})["errors"], ["unknown_kind"])
