extends RefCounted
## 凝聚力及其作用（设计规格 7.4，核心机制分析 8.2）：服从、冲突升级、投票、恐惧传染、救援意愿。
## 全部从关系网（relations.gd）算出来；个人倾向（忠诚等，0~100）放在 traits：角色 id → {"loyalty": ...}，没有就按 50。

## 冲突升级阶梯：不满 → 顶撞 → 抗命 → 擅自行动 → 私藏或偷窃 → 叛逃或转队 → 背刺谋杀。
const STAGES: Array[String] = ["none", "discontent", "talk_back", "disobey", "act_alone", "hoard", "defect", "betray"]
const STAGE_THRESHOLDS: Array[float] = [20.0, 35.0, 50.0, 60.0, 70.0, 80.0, 90.0]


## 一个人对另一个人的"好"：信任 × 0.5 + 好感 × 0.3 + 敬畏 × 0.2 − 怨恨 × 0.5。
static func regard(rel: RefCounted, a: String, b: String) -> float:
	return rel.value(a, b, "trust") * 0.5 + rel.value(a, b, "affection") * 0.3 + rel.value(a, b, "awe") * 0.2 - rel.value(a, b, "resentment") * 0.5


## 团队凝聚力（0~100）：所有有序成员对的"好"的平均。默认关系下是 44。
static func cohesion(rel: RefCounted, members: Array) -> float:
	var total := 0.0
	var n := 0
	for a: String in members:
		for b: String in members:
			if a != b:
				total += regard(rel, a, b)
				n += 1
	return clampf(total / float(n), 0.0, 100.0) if n > 0 else 100.0


## 服从度：信任 × 0.5 + 敬畏 × 0.4 + 忠诚 × 0.2 − 怨恨 × 0.5。不到 40 的人不听指挥（扮演整队时转为 AI 控制，可能抗命）。
static func obedience(rel: RefCounted, member: String, leader: String, traits: Dictionary = {}) -> float:
	var loyalty := float((traits.get(member, {}) as Dictionary).get("loyalty", 50.0))
	return rel.value(member, leader, "trust") * 0.5 + rel.value(member, leader, "awe") * 0.4 + loyalty * 0.2 - rel.value(member, leader, "resentment") * 0.5


static func obeys(rel: RefCounted, member: String, leader: String, traits: Dictionary = {}) -> bool:
	return obedience(rel, member, leader, traits) >= 40.0


## 冲突升级到第几级：不满值 = 怨恨 − 信任 × 0.3 + (50 − 忠诚) × 0.2，按阈值落在阶梯上。
static func conflict_stage(rel: RefCounted, member: String, leader: String, traits: Dictionary = {}) -> String:
	var loyalty := float((traits.get(member, {}) as Dictionary).get("loyalty", 50.0))
	var grievance: float = rel.value(member, leader, "resentment") - rel.value(member, leader, "trust") * 0.3 + (50.0 - loyalty) * 0.2
	var stage := 0
	for i in STAGE_THRESHOLDS.size():
		if grievance >= STAGE_THRESHOLDS[i]:
			stage = i + 1
	return STAGES[stage]


## 投票（中洲队传统）：提议人投赞成；其他人的支持度 = (对提议人的信任 − 50) / 50 + 自己的立场（−1~1），大于 0 投赞成。过半数通过。
static func vote(rel: RefCounted, proposer: String, members: Array, stance: Dictionary = {}) -> Dictionary:
	var yes: Array = [proposer]
	var no: Array = []
	for m: String in members:
		if m == proposer:
			continue
		var support: float = (rel.value(m, proposer, "trust") - 50.0) / 50.0 + float(stance.get(m, 0.0))
		if support > 0.0:
			yes.append(m)
		else:
			no.append(m)
	return {"yes": yes, "no": no, "passed": yes.size() * 2 > members.size()}


## 恐惧传染倍率：凝聚力越低，一个人崩溃越容易带垮一片（0.5~1.5）。
static func fear_contagion(cohesion_value: float) -> float:
	return clampf(1.0 + (50.0 - cohesion_value) / 100.0, 0.5, 1.5)


## AI 队友愿不愿意冒险救人：信任 + 好感 − 怨恨 ≥ 100。
static func willing_to_rescue(rel: RefCounted, rescuer: String, victim: String) -> bool:
	return rel.value(rescuer, victim, "trust") + rel.value(rescuer, victim, "affection") - rel.value(rescuer, victim, "resentment") >= 100.0
