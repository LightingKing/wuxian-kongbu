extends RefCounted
## 离线兜底（设计规格 8.1"离线兜底"）：没有网络、没有配置、AI 出错或输出不合格时，用规则给出确定的意图。
## 同一个任务 id 总是得到同一个结果（按 id 的哈希选台词），所以兜底也能复现。
##   npc_line：从人设的 fallback_lines 里按 id 选一句；没有就说"……"。
##   choose：选 fallback 分最高的选项，同分取第一个。
##   persuade：说辞里命中几个 keywords 就是几级（最多 3）；没有关键词时，说辞超过 20 字算 1 级，否则 0 级。
##   zhushen_answer：在 faq 里找第一个命中关键词的回答；都没命中就拒绝回答。
##   replies：用任务给的 default_replies，没有就用三句通用回复。

const REFUSAL := "此问题超出你的权限。"
const DEFAULT_REPLIES: Array[String] = ["明白了。", "我不同意。", "再说清楚一点。"]


static func respond(task: Dictionary, persona: RefCounted) -> Dictionary:
	match String(task["kind"]):
		"npc_line":
			return {"say": _line(task, persona)}
		"choose":
			var best: Dictionary = {}
			for o: Dictionary in task.get("options", []):
				if best.is_empty() or float(o.get("fallback", 0.0)) > float(best.get("fallback", 0.0)):
					best = o
			return {"choice": String(best.get("id", "")), "say": ""}
		"persuade":
			var argument := String(task.get("argument", ""))
			var keywords: Array = task.get("keywords", [])
			var level := 0
			if keywords.is_empty():
				level = 1 if argument.length() > 20 else 0
			else:
				for k: String in keywords:
					if argument.contains(k):
						level += 1
			return {"level": mini(level, 3), "reason": "离线判定"}
		"zhushen_answer":
			var question := String(task.get("question", ""))
			for item: Dictionary in task.get("faq", []):
				for k: String in item["keywords"]:
					if question.contains(k):
						return {"answer": String(item["answer"]), "refuse": false}
			return {"answer": REFUSAL, "refuse": true}
		"replies":
			var replies: Array = task.get("default_replies", DEFAULT_REPLIES)
			return {"replies": replies.duplicate()}
	return {}


static func _line(task: Dictionary, persona: RefCounted) -> String:
	if persona == null or persona.fallback_lines.is_empty():
		return "……"
	var i: int = absi(String(task["id"]).hash()) % persona.fallback_lines.size()
	return persona.fallback_lines[i]
