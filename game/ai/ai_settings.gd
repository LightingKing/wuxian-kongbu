extends RefCounted
## AI 服务设置（设计规格 8.1"模型服务""模型分档"）。存在 user://ai_settings.json，不进仓库（里面有密钥）。
## provider：anthropic（Anthropic Messages API）、openai_compatible（OpenAI 兼容网关）或 offline（不联网，全部走脚本兜底）。
## base_url：anthropic 填到域名为止（https://api.anthropic.com），请求发到 base_url + "/v1/messages"；
##           openai_compatible 填到 /v1 为止（例如 https://你的网关/v1），请求发到 base_url + "/chat/completions"。
## 两档模型：strong 用于出题、许愿、对手队长这类低频高价值的决策；fast 用于 NPC 日常对话。
## provider 是 anthropic 且 api_key 为空时，读环境变量 ANTHROPIC_API_KEY。

const PATH := "user://ai_settings.json"


static func defaults() -> Dictionary:
	return {
		"provider": "anthropic",
		"base_url": "https://api.anthropic.com",
		"api_key": "",
		"timeout_seconds": 60,
		"tiers": {
			"strong": {"model": "claude-opus-5-5", "effort": "high", "max_tokens": 16000, "fallbacks": true},
			"fast": {"model": "claude-haiku-5-5", "effort": "low", "max_tokens": 4096, "fallbacks": false},
		},
	}


## 读设置：文件里的值覆盖默认值（tiers 按档合并）；文件不存在或坏了就用默认值。
static func load_settings(path: String = PATH) -> Dictionary:
	var s := defaults()
	if not FileAccess.file_exists(path):
		return s
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return s
	var parsed: Variant = json.data
	if not parsed is Dictionary:
		return s
	for k: String in parsed:
		if k == "tiers" and parsed[k] is Dictionary:
			for tier: String in parsed[k]:
				var merged: Dictionary = (s["tiers"].get(tier, {}) as Dictionary).duplicate()
				merged.merge(parsed[k][tier], true)
				s["tiers"][tier] = merged
		else:
			s[k] = parsed[k]
	return s


static func save_settings(s: Dictionary, path: String = PATH) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(s, "\t"))
	f.close()
	return OK


## 实际使用的密钥：设置里的，或者（anthropic 时）环境变量。
static func api_key(s: Dictionary) -> String:
	var key := String(s.get("api_key", ""))
	if key == "" and s.get("provider", "") == "anthropic":
		key = OS.get_environment("ANTHROPIC_API_KEY")
	return key


## 能不能联网调用：offline 不行；没有地址不行；anthropic 必须有密钥（OpenAI 兼容网关可以不要密钥）。
static func is_configured(s: Dictionary) -> bool:
	var provider := String(s.get("provider", "offline"))
	if provider == "offline" or String(s.get("base_url", "")) == "":
		return false
	if provider == "anthropic":
		return api_key(s) != ""
	return provider == "openai_compatible"
