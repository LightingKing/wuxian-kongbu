extends RefCounted
## 对话层（设计规格 8.1）：把"玩家说了什么"交给 AI 接入层，换成 NPC 的台词或说服力等级。
## 没有密钥、断网、模型答得不合格时，ai/fallback.gd 给一份确定的答案，所以离线也能玩，只是台词固定。
## 记忆与信任存在 store（就是 Session.dialogues），直接随存档走，不需要额外的序列化。
##   store[npc_id] = {"memories": [String], "trust": 0~5}
## 任务 id 用内容哈希而不是递增序号：同一句话说第二次会命中回放，不重复花钱。

const Persona = preload("res://ai/persona.gd")

const TRUST_MAX := 5
const MAX_REPLY_CHOICES := 3


var service: RefCounted
var personas: Dictionary = {}
var store: Dictionary = {}
## 本次会话的对话记录：[{"speaker", "text"}]，不存档（存档只留记忆与信任）。
var log_lines: Array[Dictionary] = []
## 最近一次结果是 "ai"、"fallback" 还是 "replay"，界面拿它显示"在线/离线"。
var last_source: String = ""


func _init(svc: RefCounted, persona_map: Dictionary, save_store: Dictionary) -> void:
	service = svc
	personas = persona_map
	store = save_store


## 这个角色有没有人设（没有就说明它不该由 AI 驱动）。
func has_persona(npc_id: String) -> bool:
	return personas.has(npc_id)


func persona(npc_id: String) -> RefCounted:
	return personas.get(npc_id, null)


func display_name(npc_id: String) -> String:
	var p: RefCounted = persona(npc_id)
	return p.name if p != null else npc_id


func online() -> bool:
	return service != null and service.online()


## 一段能塞进 prompt 的局面摘要；界面按当前地点和时钟拼。
func situation_text(location_name: String, clock: int) -> String:
	return "生化危机一，蜂巢。现在是第 %d 分钟，你在%s。" % [clock, location_name]


## 以 npc 的身份回一句。done 收到 {"say", "source"}。
func say(npc_id: String, line: String, situation: String, done: Callable) -> void:
	var p: RefCounted = persona(npc_id)
	if p == null:
		done.call({"say": "……", "source": "none"})
		return
	var said := line.strip_edges()
	if said != "":
		remember(npc_id, "他对我说：" + said.left(60))
	var task := {
		"id": "line:%s:%s" % [npc_id, said.md5_text().left(10)],
		"kind": "npc_line",
		"tier": "fast",
		"situation": situation,
	}
	service.ask(task, p, func(res: Dictionary) -> void:
		var intent: Dictionary = res["intent"]
		var text := String(intent.get("say", "……"))
		last_source = String(res["source"])
		text = _vary(text, p)
		log_lines.append({"speaker": p.name, "text": text})
		remember(npc_id, "我说：" + text.left(60))
		done.call({"say": text, "source": last_source})
	)


## 给玩家几句可点的回复（手机上比打字省事）。done 收到 {"replies": [String], "source"}。
func suggest(npc_id: String, situation: String, defaults: Array, done: Callable) -> void:
	var p: RefCounted = persona(npc_id)
	var task := {
		"id": "replies:%s:%s" % [npc_id, situation.md5_text().left(10)],
		"kind": "replies",
		"tier": "fast",
		"situation": situation,
		"default_replies": defaults,
	}
	service.ask(task, p, func(res: Dictionary) -> void:
		var intent: Dictionary = res["intent"]
		var list: Array = (intent.get("replies", defaults) as Array).duplicate()
		last_source = String(res["source"])
		done.call({"replies": list.slice(0, MAX_REPLY_CHOICES), "source": last_source})
	)


## 给一段说辞打 0~3 级（引擎再做检定）。离线时按关键词命中数算，见 fallback.gd。
func rate(npc_id: String, argument: String, goal: String, keywords: Array, situation: String, done: Callable) -> void:
	var p: RefCounted = persona(npc_id)
	var task := {
		"id": "persuade:%s:%s:%s" % [npc_id, goal.md5_text().left(6), argument.md5_text().left(8)],
		"kind": "persuade",
		"tier": "fast",
		"situation": situation,
		"argument": argument,
		"goal": goal,
		"keywords": keywords.duplicate(),
	}
	service.ask(task, p, func(res: Dictionary) -> void:
		var intent: Dictionary = res["intent"]
		last_source = String(res["source"])
		remember(npc_id, "我试着说服他：" + argument.left(50))
		done.call({
			"level": clampi(int(intent.get("level", 0)), 0, 3),
			"reason": String(intent.get("reason", "")),
			"source": last_source,
		})
	)


## 问主神。faq 是离线兜底用的问答表，forbidden 是不许说出口的关键词（校验层会拦）。
func ask_zhushen(question: String, faq: Array, forbidden: Array, done: Callable) -> void:
	var task := {
		"id": "zhushen:%s" % question.md5_text().left(12),
		"kind": "zhushen_answer",
		"tier": "fast",
		"situation": "主神空间。轮回者站在巨大的光球下提问。",
		"question": question,
		"faq": faq,
		"forbidden": forbidden,
	}
	service.ask(task, null, func(res: Dictionary) -> void:
		var intent: Dictionary = res["intent"]
		last_source = String(res["source"])
		var answer := String(intent.get("answer", ""))
		if answer == "":
			answer = "此问题超出你的权限。"
		log_lines.append({"speaker": "主神", "text": answer})
		done.call({"answer": answer, "refuse": bool(intent.get("refuse", false)), "source": last_source})
	)


func trust_of(npc_id: String) -> int:
	return int(_entry(npc_id).get("trust", 0))


## 加减信任（0~5）。跨过 def["at"] 门槛时返回一条 confide 事件，带剧本给的效果。
func add_trust(npc_id: String, delta: int, def: Dictionary) -> Array[Dictionary]:
	var before := trust_of(npc_id)
	var after := clampi(before + delta, 0, TRUST_MAX)
	_entry(npc_id)["trust"] = after
	var at := int(def.get("at", TRUST_MAX + 1))
	if before < at and after >= at:
		return [{
			"type": "confide",
			"npc": npc_id,
			"line": String(def.get("line", "")),
			"effects": (def.get("effects", []) as Array).duplicate(true),
		}]
	return []


func memories_of(npc_id: String) -> Array:
	return _entry(npc_id)["memories"]


## 记一条，超过上限时把最早的两条并成一条（规则与 persona.gd 一致）。
func remember(npc_id: String, text: String) -> void:
	if text.strip_edges() == "":
		return
	var list: Array = _entry(npc_id)["memories"]
	list.append(text)
	while list.size() > Persona.MAX_MEMORIES:
		var merged := ("更早的事：%s；%s" % [list[0], list[1]]).left(Persona.MERGED_MAX)
		list.remove_at(0)
		list[0] = merged
	_sync(npc_id)


## 离线人设只有三句，连着重复很出戏：跟上一条一样就换下一句。
func _vary(text: String, p: RefCounted) -> String:
	if last_source != "fallback" or p.fallback_lines.size() < 2 or log_lines.is_empty():
		return text
	var prev: Dictionary = log_lines[log_lines.size() - 1]
	if String(prev["speaker"]) != p.name or String(prev["text"]) != text:
		return text
	var i: int = p.fallback_lines.find(text)
	if i < 0:
		return text
	return p.fallback_lines[(i + 1) % p.fallback_lines.size()]


## 把 store 里的记忆同步回 persona，下一轮 context_text 才看得到。
func _sync(npc_id: String) -> void:
	var p: RefCounted = persona(npc_id)
	if p != null:
		p.memories.assign(_entry(npc_id)["memories"])


func _entry(npc_id: String) -> Dictionary:
	if not store.has(npc_id):
		store[npc_id] = {"memories": [], "trust": 0}
	return store[npc_id]
