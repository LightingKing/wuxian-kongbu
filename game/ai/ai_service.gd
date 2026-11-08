extends RefCounted
## AI 接入层的入口（设计规格 8.1、10.2）：core 交来一个任务，这里返回一个经过校验的意图。
## 流程：已有记录 → 直接用（replay）；没配置或没有传输层 → 离线兜底；否则组装请求 → 发出 → 解析 → 校验 → 合格就用，否则兜底。
## 结果（交给 done 回调）：{"id", "intent", "source": "ai" / "fallback" / "replay", "reason"}。每次的结果都写进记录。
## 传输层（transport）是任何带 send(request: Dictionary, done: Callable) 方法的对象：
##   真实的是 http_transport.gd（一个 Node）；测试里用假的。done 收到 {"ok", "status", "body", "error"}。

const AiSettings = preload("res://ai/ai_settings.gd")
const Providers = preload("res://ai/providers.gd")
const Intents = preload("res://ai/intents.gd")
const Fallback = preload("res://ai/fallback.gd")
const Lore = preload("res://ai/lore.gd")
const AiLog = preload("res://ai/ai_log.gd")

var settings: Dictionary = AiSettings.defaults()
var transport: Object = null
var replay: RefCounted = AiLog.new()
## 计数：ai、fallback、replay 各走了几次；最近的错误。
var stats: Dictionary = {"ai": 0, "fallback": 0, "replay": 0, "last_error": ""}


func _init(s: Dictionary = {}, t: Object = null) -> void:
	if not s.is_empty():
		settings = s
	transport = t


func online() -> bool:
	return transport != null and AiSettings.is_configured(settings)


## task 见 intents.gd 开头；persona 是 persona.gd（可以为 null，例如只要候选回复时）。
func ask(task: Dictionary, persona: RefCounted, done: Callable) -> void:
	var id := String(task["id"])
	if replay.has(id):
		stats["replay"] = int(stats["replay"]) + 1
		var entry: Dictionary = replay.get_entry(id)
		done.call({"id": id, "intent": entry["intent"], "source": "replay", "reason": String(entry.get("reason", ""))})
		return
	if not online():
		_fallback(task, persona, "offline", done)
		return
	var kind := String(task["kind"])
	var context: String = persona.context_text() if persona != null else ""
	var req := Providers.build_request(settings, String(task.get("tier", "fast")), Lore.text(), context, Intents.user_prompt(task), Intents.schema(kind))
	transport.send(req, func(resp: Dictionary) -> void: _on_response(task, persona, resp, done))


func _on_response(task: Dictionary, persona: RefCounted, resp: Dictionary, done: Callable) -> void:
	if not bool(resp.get("ok", false)):
		_fallback(task, persona, "transport:" + String(resp.get("error", "")), done)
		return
	var parsed := Providers.parse_response(String(settings["provider"]), int(resp.get("status", 0)), String(resp.get("body", "")))
	if not parsed["ok"]:
		_fallback(task, persona, String(parsed["error"]), done)
		return
	var kind := String(task["kind"])
	var v := Intents.validate(kind, Intents.extract_json(String(parsed["text"])), task)
	if not v["ok"]:
		_fallback(task, persona, "invalid:" + ",".join(v["errors"]), done)
		return
	var id := String(task["id"])
	replay.put(id, {"intent": v["intent"], "source": "ai", "reason": ""})
	stats["ai"] = int(stats["ai"]) + 1
	done.call({"id": id, "intent": v["intent"], "source": "ai", "reason": ""})


func _fallback(task: Dictionary, persona: RefCounted, reason: String, done: Callable) -> void:
	var id := String(task["id"])
	var intent := Fallback.respond(task, persona)
	replay.put(id, {"intent": intent, "source": "fallback", "reason": reason})
	stats["fallback"] = int(stats["fallback"]) + 1
	if reason != "offline":
		stats["last_error"] = reason
	done.call({"id": id, "intent": intent, "source": "fallback", "reason": reason})
