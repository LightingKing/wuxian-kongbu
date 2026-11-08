extends RefCounted
## AI 意图（设计规格 8.1"AI 提议，规则引擎裁决"）：AI 只输出结构化的意图，引擎校验后才执行。
## 任务（task）是 core 交给 AI 层的一份请求，字段：
##   id（稳定的编号，用于回放）、kind（下面五种之一）、tier（"fast" / "strong"）、situation（局面摘要）
##   choose / replies：options = [{"id", "text"}]；persuade：argument（玩家的说辞）、goal（想让对方做什么）；
##   zhushen_answer：question（提问）、forbidden（不能透露的关键词）。
## 五种意图：
##   npc_line        {"say": 台词}
##   choose          {"choice": 选项 id, "say": 台词（可空）}
##   persuade        {"level": 0~3, "reason": 理由}      说服力等级：0 无效、1 弱、2 中、3 强，由引擎再做检定
##   zhushen_answer  {"answer": 回答, "refuse": bool}    回答里出现 forbidden 关键词算不合格
##   replies         {"replies": [2~4 句候选回复]}        手机上给玩家选

const KINDS: Array[String] = ["npc_line", "choose", "persuade", "zhushen_answer", "replies"]
const MAX_SAY := 200
const MAX_REPLY := 60


## 发给 Anthropic 结构化输出的 JSON Schema（所有 object 都要 additionalProperties: false；范围限制不写进 schema，由 validate 检查）。
static func schema(kind: String) -> Dictionary:
	var props := {}
	var required: Array = []
	match kind:
		"npc_line":
			props = {"say": {"type": "string"}}
			required = ["say"]
		"choose":
			props = {"choice": {"type": "string"}, "say": {"type": "string"}}
			required = ["choice", "say"]
		"persuade":
			props = {"level": {"type": "integer"}, "reason": {"type": "string"}}
			required = ["level", "reason"]
		"zhushen_answer":
			props = {"answer": {"type": "string"}, "refuse": {"type": "boolean"}}
			required = ["answer", "refuse"]
		"replies":
			props = {"replies": {"type": "array", "items": {"type": "string"}}}
			required = ["replies"]
	return {"type": "object", "properties": props, "required": required, "additionalProperties": false}


## 发给模型的用户消息：局面、任务要求、输出格式。
static func user_prompt(task: Dictionary) -> String:
	var lines: Array[String] = ["【局面】" + String(task.get("situation", ""))]
	match String(task["kind"]):
		"npc_line":
			lines.append("【任务】以你扮演的角色说一句话（不超过 %d 字）。" % MAX_SAY)
			lines.append("只输出 JSON：{\"say\": \"台词\"}")
		"choose":
			lines.append("【任务】以你扮演的角色，从下面的选项里选一个，并说一句话（可以为空）。")
			for o: Dictionary in task.get("options", []):
				lines.append("- %s：%s" % [o["id"], o["text"]])
			lines.append("只输出 JSON：{\"choice\": \"选项 id\", \"say\": \"台词\"}")
		"persuade":
			lines.append("【任务】玩家想说服你：%s" % String(task.get("goal", "")))
			lines.append("玩家的说辞：" + String(task.get("argument", "")))
			lines.append("按你扮演的角色的立场，评估这番话的说服力：0 无效、1 弱、2 中、3 强。")
			lines.append("只输出 JSON：{\"level\": 0到3的整数, \"reason\": \"理由\"}")
		"zhushen_answer":
			lines.append("【任务】轮回者向主神提问：" + String(task.get("question", "")))
			lines.append("以主神的口吻回答：死板、庄严、不带感情。超出权限或涉及秘密的问题拒绝回答（refuse 为 true）。")
			lines.append("只输出 JSON：{\"answer\": \"回答\", \"refuse\": true 或 false}")
		"replies":
			lines.append("【任务】给玩家写 3 句可选的回复（每句不超过 %d 字），风格各不相同。" % MAX_REPLY)
			lines.append("只输出 JSON：{\"replies\": [\"……\", \"……\", \"……\"]}")
	return "\n".join(lines)


## 从模型的文字里取出 JSON 对象：容忍 ```json 代码块和前后多余的文字。取不出返回 null。
static func extract_json(text: String) -> Variant:
	var start := text.find("{")
	var end := text.rfind("}")
	if start < 0 or end <= start:
		return null
	var json := JSON.new()
	if json.parse(text.substr(start, end - start + 1)) != OK:
		return null
	return json.data if json.data is Dictionary else null


## 返回 {"ok": bool, "intent": Dictionary, "errors": [String]}。intent 只保留规定的字段。
static func validate(kind: String, data: Variant, task: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var intent := {}
	if not data is Dictionary:
		errors.append("not_object")
		return {"ok": false, "intent": intent, "errors": errors}
	match kind:
		"npc_line":
			var say := _text(data, "say", errors)
			if say == "":
				errors.append("empty_say")
			intent = {"say": say}
		"choose":
			var choice := String(data.get("choice", ""))
			var ids: Array = []
			for o: Dictionary in task.get("options", []):
				ids.append(String(o["id"]))
			if not ids.has(choice):
				errors.append("illegal_choice")
			intent = {"choice": choice, "say": _text(data, "say", errors)}
		"persuade":
			var level: Variant = data.get("level")
			if not (level is int or level is float) or float(level) != floorf(float(level)) or float(level) < 0.0 or float(level) > 3.0:
				errors.append("bad_level")
				level = 0
			intent = {"level": int(level), "reason": String(data.get("reason", ""))}
		"zhushen_answer":
			var answer := String(data.get("answer", ""))
			var refuse := bool(data.get("refuse", false))
			if answer == "":
				errors.append("empty_answer")
			if not refuse:
				for word: String in task.get("forbidden", []):
					if answer.contains(word):
						errors.append("leaks_secret")
						break
			intent = {"answer": answer, "refuse": refuse}
		"replies":
			var replies: Array = []
			var raw: Variant = data.get("replies")
			if raw is Array:
				for r in raw:
					var s := String(r).strip_edges()
					if s != "" and s.length() <= MAX_REPLY:
						replies.append(s)
			if replies.size() < 2 or replies.size() > 4:
				errors.append("bad_replies")
			intent = {"replies": replies}
		_:
			errors.append("unknown_kind")
	return {"ok": errors.is_empty(), "intent": intent, "errors": errors}


static func _text(data: Dictionary, key: String, errors: Array[String]) -> String:
	var s := String(data.get(key, "")).strip_edges()
	if s.length() > MAX_SAY:
		errors.append("too_long")
	return s
