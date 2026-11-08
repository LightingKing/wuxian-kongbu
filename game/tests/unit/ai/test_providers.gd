extends "res://tests/test_case.gd"

const AiSettings = preload("res://ai/ai_settings.gd")
const Providers = preload("res://ai/providers.gd")

const SCHEMA := {"type": "object", "properties": {"say": {"type": "string"}}, "required": ["say"], "additionalProperties": false}


func _anthropic() -> Dictionary:
	var s := AiSettings.defaults()
	s["api_key"] = "sk-test"
	return s


func test_anthropic_request_shape() -> void:
	var req := Providers.build_request(_anthropic(), "strong", "世界设定", "人设与局面", "请回答", SCHEMA)
	assert_eq(req["url"], "https://api.anthropic.com/v1/messages")
	var headers: PackedStringArray = req["headers"]
	assert_true(headers.has("x-api-key: sk-test"))
	assert_true(headers.has("anthropic-version: 2026-10-21"))
	assert_true(headers.has("anthropic-beta: server-side-fallback-2026-07-01"))
	var body: Dictionary = JSON.parse_string(req["body"])
	assert_eq(body["model"], "claude-opus-5-5")
	assert_eq(int(body["max_tokens"]), 16000)
	assert_eq(body["system"][0], {"type": "text", "text": "世界设定", "cache_control": {"type": "ephemeral"}})
	assert_eq(body["system"][1], {"type": "text", "text": "人设与局面"})
	assert_eq(body["messages"], [{"role": "user", "content": "请回答"}])
	assert_eq(body["output_config"]["effort"], "high")
	assert_eq(body["output_config"]["format"], {"type": "json_schema", "schema": SCHEMA})
	assert_eq(body["fallbacks"], "default")
	assert_false(body.has("temperature"))
	assert_false(body.has("thinking"))
	assert_almost(float(req["timeout"]), 60.0)


## fast 档（Haiku）没有服务端拒答回退，不发 fallbacks 和 beta 头；没有 schema 时不发 format。
func test_fast_tier_without_fallbacks() -> void:
	var req := Providers.build_request(_anthropic(), "fast", "L", "C", "P", {})
	var headers: PackedStringArray = req["headers"]
	for h in headers:
		assert_false(h.begins_with("anthropic-beta"), h)
	var body: Dictionary = JSON.parse_string(req["body"])
	assert_eq(body["model"], "claude-haiku-5-5")
	assert_false(body.has("fallbacks"))
	assert_eq(body["output_config"], {"effort": "low"})


func test_openai_compatible_request_shape() -> void:
	var s := AiSettings.defaults()
	s["provider"] = "openai_compatible"
	s["base_url"] = "https://gw.example/v1/"
	s["api_key"] = "gw-key"
	var req := Providers.build_request(s, "fast", "L", "C", "P", SCHEMA)
	assert_eq(req["url"], "https://gw.example/v1/chat/completions")
	assert_true((req["headers"] as PackedStringArray).has("Authorization: Bearer gw-key"))
	var body: Dictionary = JSON.parse_string(req["body"])
	assert_eq(body["messages"], [{"role": "system", "content": "L\n\nC"}, {"role": "user", "content": "P"}])
	s["api_key"] = ""
	for h in (Providers.build_request(s, "fast", "L", "C", "P", {})["headers"] as PackedStringArray):
		assert_false(h.begins_with("Authorization"), h)


## 只读 text 块：思考块跳过，多个 text 块连起来。
func test_parse_anthropic_text() -> void:
	var body := JSON.stringify({
		"stop_reason": "end_turn",
		"content": [
			{"type": "thinking", "thinking": ""},
			{"type": "text", "text": "{\"say\": "},
			{"type": "text", "text": "\"你好\"}"},
		],
	})
	assert_eq(Providers.parse_response("anthropic", 200, body), {"ok": true, "text": "{\"say\": \"你好\"}", "error": ""})


func test_parse_anthropic_failures() -> void:
	assert_eq(Providers.parse_response("anthropic", 200, JSON.stringify({"stop_reason": "refusal", "content": []}))["error"], "refusal")
	assert_eq(Providers.parse_response("anthropic", 200, JSON.stringify({"stop_reason": "max_tokens", "content": []}))["error"], "truncated")
	var err := Providers.parse_response("anthropic", 401, JSON.stringify({"type": "error", "error": {"type": "authentication_error", "message": "invalid x-api-key"}}))
	assert_false(bool(err["ok"]))
	assert_eq(err["error"], "http_401 invalid x-api-key")
	assert_eq(Providers.parse_response("anthropic", 200, "<html>")["error"], "bad_json")


func test_parse_openai() -> void:
	var ok := JSON.stringify({"choices": [{"finish_reason": "stop", "message": {"role": "assistant", "content": "{\"say\": \"嗯\"}"}}]})
	assert_eq(Providers.parse_response("openai_compatible", 200, ok)["text"], "{\"say\": \"嗯\"}")
	var filtered := JSON.stringify({"choices": [{"finish_reason": "content_filter", "message": {"content": ""}}]})
	assert_eq(Providers.parse_response("openai_compatible", 200, filtered)["error"], "refusal")
	var cut := JSON.stringify({"choices": [{"finish_reason": "length", "message": {"content": "{"}}]})
	assert_eq(Providers.parse_response("openai_compatible", 200, cut)["error"], "truncated")
	assert_eq(Providers.parse_response("openai_compatible", 200, JSON.stringify({"choices": []}))["error"], "no_choices")
	assert_eq(Providers.parse_response("openai_compatible", 502, "")["error"], "http_502 ")
