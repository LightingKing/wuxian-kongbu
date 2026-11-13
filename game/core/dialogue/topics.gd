extends RefCounted
## 固定话题（设计 2026-11-12 第 7 节）：不接 AI 也能和每个人聊的内容，照原著写好。
## 数据在剧本目录的 topics.json：{"version": 1, "topics": {人物 id: [话题, ...]}}。一个话题：
##   id      全剧本唯一
##   label   玩家看到的问题（"你是谁？"）
##   when    什么时候能聊（剧本条件，见 conditions.gd），可省
##   trust   对方的对话信任至少多少（0~5，每聊一个新话题 +1），可省
##   after   先聊过哪个话题，可省
##   text    对方的回答；或者 variants：[{fear_min?, when?, text}]，按顺序取第一个符合的（fear_min 看说话人自己的恐惧）
##   card    聊过以后记在人物卡上的一句要点，可省
##   effects 聊第一次时跑的剧情效果（线索、旗标、关系、百科……），可省
## 剧情人物所在的地点写了 unheard（车减速之前的列车，原著 L62）时，他们听不见轮回者说话：
## 只能聊写了 observe 的话题（看看他），也不能自由对话。聊过的话题记在 ExpeditionState.topics_seen。

const DataLoader = preload("res://core/util/data_loader.gd")
const Conditions = preload("res://core/expedition/conditions.gd")

static var _cache: Dictionary = {}


static func path_for(scenario: RefCounted) -> String:
	return "res://data/scenarios/%s/topics.json" % scenario.id


## 这部片全部的话题：人物 id → 话题数组。没有话题文件时是空字典。
static func all_for(scenario: RefCounted) -> Dictionary:
	var path := path_for(scenario)
	if _cache.has(path):
		return _cache[path]
	var out := {}
	if FileAccess.file_exists(path):
		var res := DataLoader.load_json(path)
		if res.ok:
			out = (res.data as Dictionary).get("topics", {})
		else:
			push_error(res.error)
	_cache[path] = out
	return out


static func defs(st: RefCounted, npc_id: String) -> Array:
	return all_for(st.scenario).get(npc_id, [])


## 这个人现在听不听得见轮回者说话：剧情人物在写了 unheard 的地点时听不见；轮回者总听得见。
static func can_hear(st: RefCounted, npc_id: String) -> bool:
	if not st.npcs.has(npc_id):
		return true
	var loc := String(st.npcs[npc_id]["location"])
	return not bool(st.scenario.location(loc).get("unheard", false))


static func _open(st: RefCounted, npc_id: String, t: Dictionary, trust: int) -> bool:
	if t.has("when") and not Conditions.check(t["when"], st):
		return false
	if trust < int(t.get("trust", 0)):
		return false
	if t.has("after") and not st.topics_seen.has(String(t["after"])):
		return false
	if bool(t.get("observe", false)) == can_hear(st, npc_id):
		return false
	return true


## 现在能聊的话题（按数据顺序），每个是原数据的副本，多一个 seen。
static func available(st: RefCounted, npc_id: String, trust: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Dictionary in defs(st, npc_id):
		if _open(st, npc_id, t, trust):
			var c := t.duplicate(true)
			c["seen"] = st.topics_seen.has(String(t["id"]))
			out.append(c)
	return out


## 有没有还没聊过、现在能聊的话题（头上冒"…"）。
static func has_new(st: RefCounted, npc_id: String, trust: int) -> bool:
	for t in available(st, npc_id, trust):
		if not bool(t["seen"]):
			return true
	return false


## 还没聊过的话题一共几个（包括现在还聊不了的）：人物卡上提示"还有几个话题没聊过"。
static func unseen_count(st: RefCounted, npc_id: String) -> int:
	var n := 0
	for t: Dictionary in defs(st, npc_id):
		if not st.topics_seen.has(String(t["id"])):
			n += 1
	return n


static func find(st: RefCounted, npc_id: String, topic_id: String) -> Dictionary:
	for t: Dictionary in defs(st, npc_id):
		if String(t["id"]) == topic_id:
			return t
	return {}


## 回答：有 variants 时取第一个符合的，否则 text。
static func text_of(st: RefCounted, npc_id: String, t: Dictionary) -> String:
	for v: Dictionary in t.get("variants", []):
		if v.has("fear_min"):
			if not st.characters.has(npc_id) or float(st.characters[npc_id].fear) < float(v["fear_min"]):
				continue
		if v.has("when") and not Conditions.check(v["when"], st):
			continue
		return String(v["text"])
	return String(t.get("text", ""))


## 人物卡上的要点：聊过的话题的 card，按数据顺序。
static func notes(st: RefCounted, npc_id: String) -> Array[String]:
	var out: Array[String] = []
	for t: Dictionary in defs(st, npc_id):
		if st.topics_seen.has(String(t["id"])) and String(t.get("card", "")) != "":
			out.append(String(t["card"]))
	return out


## 整个话题文件的问题（测试和校验用）：id 重复、缺回答、after 指向不存在的话题、人物不存在。
static func validate(scenario: RefCounted, known_people: Array) -> Array[String]:
	var errors: Array[String] = []
	var ids := {}
	var topics := all_for(scenario)
	for npc_id: String in topics:
		if not known_people.has(npc_id):
			errors.append("话题里的人物 %s 不存在" % npc_id)
		for t: Dictionary in topics[npc_id]:
			var tid := String(t.get("id", ""))
			if tid == "" or ids.has(tid):
				errors.append("话题 id 为空或重复：%s" % tid)
			ids[tid] = npc_id
			if String(t.get("label", "")) == "":
				errors.append("话题 %s 没有问题" % tid)
			if String(t.get("text", "")) == "" and (t.get("variants", []) as Array).is_empty():
				errors.append("话题 %s 没有回答" % tid)
	for npc_id: String in topics:
		for t: Dictionary in topics[npc_id]:
			if t.has("after") and not ids.has(String(t["after"])):
				errors.append("话题 %s 的 after 指向不存在的话题" % String(t["id"]))
	return errors
