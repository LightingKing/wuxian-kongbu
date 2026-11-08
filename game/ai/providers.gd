extends RefCounted
## 服务商适配：把一次 AI 调用组装成 HTTP 请求，再把 HTTP 响应解析成文字。纯函数，不联网，方便测试。
## Anthropic（Messages API，接口版本 2026-10-21）：
##   - system 分两块：第一块是静态的世界设定，带 cache_control（提示缓存）；第二块是人设、记忆和局面（每次不同，放在缓存之后）；
##   - output_config：effort（思考深度），以及要求按 JSON Schema 输出（结构化输出）；
##   - strong 档默认开服务端拒答回退（fallbacks: "default"，beta 头 server-side-fallback-2026-07-01）；fast 档（Haiku）没有服务端回退，不发；
##   - 不发 temperature（这个接口版本已不接受）；
##   - 只读 type 为 text 的内容块（思考块等跳过）；stop_reason 为 refusal 算失败，max_tokens 算输出被截断。
## OpenAI 兼容：/chat/completions，system 合成一条消息；finish_reason 为 content_filter 算拒答，length 算截断。

const ANTHROPIC_VERSION := "2026-10-21"
const FALLBACK_BETA := "server-side-fallback-2026-07-01"

const AiSettings = preload("res://ai/ai_settings.gd")


## 返回 {"url": String, "headers": PackedStringArray, "body": String, "timeout": float}
static func build_request(s: Dictionary, tier: String, lore: String, context: String, prompt: String, schema: Dictionary) -> Dictionary:
	var t: Dictionary = s["tiers"][tier]
	var base := String(s["base_url"]).rstrip("/")
	var key := AiSettings.api_key(s)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var body := {}
	var url := ""
	if s["provider"] == "anthropic":
		url = base + "/v1/messages"
		headers.append("x-api-key: " + key)
		headers.append("anthropic-version: " + ANTHROPIC_VERSION)
		var output_config := {"effort": String(t["effort"])}
		if not schema.is_empty():
			output_config["format"] = {"type": "json_schema", "schema": schema}
		body = {
			"model": String(t["model"]),
			"max_tokens": int(t["max_tokens"]),
			"system": [
				{"type": "text", "text": lore, "cache_control": {"type": "ephemeral"}},
				{"type": "text", "text": context},
			],
			"messages": [{"role": "user", "content": prompt}],
			"output_config": output_config,
		}
		if bool(t.get("fallbacks", false)):
			body["fallbacks"] = "default"
			headers.append("anthropic-beta: " + FALLBACK_BETA)
	else:
		url = base + "/chat/completions"
		if key != "":
			headers.append("Authorization: Bearer " + key)
		body = {
			"model": String(t["model"]),
			"max_tokens": int(t["max_tokens"]),
			"messages": [
				{"role": "system", "content": lore + "\n\n" + context},
				{"role": "user", "content": prompt},
			],
		}
	return {"url": url, "headers": headers, "body": JSON.stringify(body), "timeout": float(s.get("timeout_seconds", 60))}


## 返回 {"ok": bool, "text": String, "error": String}
static func parse_response(provider: String, status: int, body: String) -> Dictionary:
	var json := JSON.new()
	var data: Variant = json.data if json.parse(body) == OK else null
	if status != 200:
		var msg := ""
		if data is Dictionary and data.get("error") is Dictionary:
			msg = String(data["error"].get("message", ""))
		return {"ok": false, "text": "", "error": "http_%d %s" % [status, msg]}
	if not data is Dictionary:
		return {"ok": false, "text": "", "error": "bad_json"}
	if provider == "anthropic":
		var stop := String(data.get("stop_reason", ""))
		if stop == "refusal":
			return {"ok": false, "text": "", "error": "refusal"}
		if stop == "max_tokens":
			return {"ok": false, "text": "", "error": "truncated"}
		var parts: Array[String] = []
		for block: Dictionary in data.get("content", []):
			if block.get("type", "") == "text":
				parts.append(String(block.get("text", "")))
		return {"ok": true, "text": "".join(parts), "error": ""}
	var choices: Array = data.get("choices", [])
	if choices.is_empty():
		return {"ok": false, "text": "", "error": "no_choices"}
	var finish := String(choices[0].get("finish_reason", ""))
	if finish == "content_filter":
		return {"ok": false, "text": "", "error": "refusal"}
	if finish == "length":
		return {"ok": false, "text": "", "error": "truncated"}
	var message: Dictionary = choices[0].get("message", {})
	return {"ok": true, "text": String(message.get("content", "")), "error": ""}
