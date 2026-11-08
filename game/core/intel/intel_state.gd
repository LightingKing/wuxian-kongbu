extends RefCounted
## 信息模型（设计规格 3.8，核心机制分析 9.3A、9.4）：每条隐藏事实对队伍有四种状态——
##   unknown（未知）→ hinted（有线索）→ inferred（有推论，带可信度）→ confirmed（已确认）。
## 智者用线索做推理，得出推论和可信度；推论可能是错的。两个智者结论一致时可信度叠加，不一致时标成"有争议"。
## 事实的定义来自剧本：{"statement", "domain", "truth", "difficulty", "clues": {线索 id: 权重}}。
## 随机数由调用方传入（roll 在 0~1 之间）。

var facts: Dictionary = {}
var clues_found: Dictionary = {}
## 事实 id → {"conclusion": bool, "confidence": float, "by": [角色 id], "contested": bool}
var inferences: Dictionary = {}
## 事实 id → 真相
var confirmed: Dictionary = {}


func load_facts(defs: Dictionary) -> void:
	facts = defs.duplicate(true)


func status(fact_id: String) -> String:
	if confirmed.has(fact_id):
		return "confirmed"
	if inferences.has(fact_id):
		return "inferred"
	if clue_weight(fact_id) > 0.0:
		return "hinted"
	return "unknown"


## 已找到的线索权重之和，最多算 1。
func clue_weight(fact_id: String) -> float:
	var w := 0.0
	var clues: Dictionary = facts[fact_id].get("clues", {})
	for c: String in clues:
		if clues_found.has(c):
			w += float(clues[c])
	return minf(w, 1.0)


func add_clue(clue_id: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if clues_found.has(clue_id):
		return events
	clues_found[clue_id] = true
	events.append({"type": "clue_found", "clue": clue_id})
	for f: String in facts:
		if (facts[f].get("clues", {}) as Dictionary).has(clue_id):
			events.append({"type": "fact_hinted", "fact": f})
	return events


## 推理准确度：0.3 + (智力 − 100) / 400 + 线索 × 0.4 + 领域熟悉度 × 0.2 + 天才 0.1 − 难度 × 0.3，限制在 0.05~0.97。
## 领域熟悉度在 flags.domains 里（0~1），天才是 flags.talents 里的 "genius"。
static func accuracy(thinker: RefCounted, fact: Dictionary, clue_w: float) -> float:
	var a := 0.3
	a += (thinker.attributes.total("intelligence") - 100.0) / 400.0
	a += clue_w * 0.4
	a += float((thinker.flags.get("domains", {}) as Dictionary).get(String(fact.get("domain", "")), 0.0)) * 0.2
	if (thinker.flags.get("talents", []) as Array).has("genius"):
		a += 0.1
	a -= float(fact.get("difficulty", 0.0)) * 0.3
	return clampf(a, 0.05, 0.97)


## 推理一条事实。roll < 准确度时得出正确结论，否则得出相反的结论；智者自己报的可信度就是准确度。
func deduce(fact_id: String, thinker: RefCounted, roll: float) -> Dictionary:
	if confirmed.has(fact_id):
		return {"type": "deduce_skipped", "fact": fact_id, "reason": "confirmed"}
	var w := clue_weight(fact_id)
	if w <= 0.0:
		return {"type": "deduce_skipped", "fact": fact_id, "reason": "no_clues"}
	var fact: Dictionary = facts[fact_id]
	var acc := accuracy(thinker, fact, w)
	var conclusion: bool = bool(fact["truth"]) if roll < acc else not bool(fact["truth"])
	var inf: Dictionary = inferences.get(fact_id, {})
	if inf.is_empty():
		inf = {"conclusion": conclusion, "confidence": acc, "by": [thinker.id], "contested": false}
	elif bool(inf["conclusion"]) == conclusion:
		inf["confidence"] = 1.0 - (1.0 - float(inf["confidence"])) * (1.0 - acc)
		(inf["by"] as Array).append(thinker.id)
	else:
		inf["contested"] = true
		(inf["by"] as Array).append(thinker.id)
		if acc > float(inf["confidence"]):
			inf["conclusion"] = conclusion
			inf["confidence"] = acc
	inferences[fact_id] = inf
	return {"type": "inference", "fact": fact_id, "conclusion": inf["conclusion"], "confidence": inf["confidence"], "by": thinker.id, "contested": inf["contested"]}


## 真相揭晓（剧情证实、亲眼看到）。返回事件里带着之前的推论对不对。
func confirm(fact_id: String) -> Dictionary:
	var truth: bool = bool(facts[fact_id]["truth"])
	confirmed[fact_id] = truth
	var was: Variant = null
	if inferences.has(fact_id):
		was = bool(inferences[fact_id]["conclusion"]) == truth
	return {"type": "fact_confirmed", "fact": fact_id, "truth": truth, "inference_was_right": was}


func to_dict() -> Dictionary:
	return {
		"facts": facts.duplicate(true),
		"clues_found": clues_found.duplicate(),
		"inferences": inferences.duplicate(true),
		"confirmed": confirmed.duplicate(),
	}


func load_dict(d: Dictionary) -> void:
	facts = (d["facts"] as Dictionary).duplicate(true)
	clues_found = (d["clues_found"] as Dictionary).duplicate()
	inferences = (d["inferences"] as Dictionary).duplicate(true)
	confirmed = (d["confirmed"] as Dictionary).duplicate()
