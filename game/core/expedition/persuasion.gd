extends RefCounted
## 说服的离线裁决（设计规格 8、9.5.1）：玩家从对方给的关键词里挑话说，匹配得越多越有说服力。
## 需要先推理出某个事实（requires_fact）才开得了口；没有推论时返回 -1，由远征按失败处理。
## 以后接 AI 对话层时，仍然调用 resolve_persuasion(level)，这里只是把"说什么"折算成 0~3 级。

## 返回 0~3；-1 表示"你还没有把握，说不出口"。
static func level(check: Dictionary, keywords: Array, thinker: RefCounted, intel: RefCounted) -> int:
	var fact := String(check.get("requires_fact", ""))
	if fact != "":
		var status: String = intel.status(fact)
		if status != "inferred" and status != "confirmed":
			return -1
	var known: Array = check.get("keywords", [])
	var matched := 0
	for k: String in keywords:
		if known.has(k):
			matched += 1
	var lvl := mini(matched, 3)
	if lvl > 0 and float(thinker.attributes.total("intelligence")) >= 140.0:
		lvl = mini(lvl + 1, 3)
	return lvl
