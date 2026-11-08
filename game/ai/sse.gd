extends RefCounted
## 流式输出（Server-Sent Events）解析（设计规格 8.1"延迟：对话流式输出"）：一段段喂进收到的数据，吐出新增的文字。
## Anthropic：content_block_delta 里 delta.type 为 text_delta 的 text；message_delta 带 stop_reason；message_stop 表示结束。
## OpenAI 兼容：data 里 choices[0].delta.content；finish_reason；data: [DONE] 表示结束。
## 事件之间用空行分隔，数据可能在任何地方被切开，所以先攒在 buffer 里，凑齐一个事件再处理。

var provider: String = "anthropic"
var buffer: String = ""
var text: String = ""
var stop_reason: String = ""
var done: bool = false


func _init(p: String = "anthropic") -> void:
	provider = p


## 喂一段数据，返回这次新增的文字片段。
func feed(chunk: String) -> Array[String]:
	var out: Array[String] = []
	buffer += chunk.replace("\r\n", "\n")
	var sep := buffer.find("\n\n")
	while sep >= 0:
		var event := buffer.substr(0, sep)
		buffer = buffer.substr(sep + 2)
		for line in event.split("\n"):
			if line.begins_with("data:"):
				var piece := _handle(line.substr(5).strip_edges())
				if piece != "":
					out.append(piece)
					text += piece
		sep = buffer.find("\n\n")
	return out


func _handle(data: String) -> String:
	if data == "[DONE]":
		done = true
		return ""
	var json := JSON.new()
	if json.parse(data) != OK or not json.data is Dictionary:
		return ""
	var d: Dictionary = json.data
	if provider == "anthropic":
		match String(d.get("type", "")):
			"content_block_delta":
				var delta: Dictionary = d.get("delta", {})
				if delta.get("type", "") == "text_delta":
					return String(delta.get("text", ""))
			"message_delta":
				stop_reason = String((d.get("delta", {}) as Dictionary).get("stop_reason", ""))
			"message_stop":
				done = true
		return ""
	var choices: Array = d.get("choices", [])
	if choices.is_empty():
		return ""
	var c: Dictionary = choices[0]
	if c.get("finish_reason") != null:
		stop_reason = String(c["finish_reason"])
	var piece: Variant = (c.get("delta", {}) as Dictionary).get("content")
	return String(piece) if piece != null else ""
