extends RefCounted
## 主神议程骨架（设计规格 5.5，核心机制分析 1.0~1.4、2.2）：主神是有目的的行动者，为每支队伍维护隐藏议程——
##   标准课程走到哪一步（引导者 → 队长 → 成长窗口 → 团战 → 加难 → 瓶颈试炼 → 终局）；
##   异常（例：张杰这种"半引导者"）与最后通牒；每个人的潜力与潜力突升；被复制进恶魔小队的人；拖后腿的因素；瓶颈。
## 每个决定都附一段隐藏的"主神理由"，写进存档（调试用，也是智者推理的对象）。
## 这里还有两个能算的东西：一部片之后评价怎么变；主神眼中的"评价战力"（用来算相对击杀奖励）。

const DataLoader = preload("res://core/util/data_loader.gd")
const Attributes = preload("res://core/model/attributes.gd")

const PATH := "res://data/director/director_rules.json"

static var _cache: Dictionary = {}

var stage: String = "guide"
## {"id", "kind", "char", "since_film", "note", "resolved_film"}；char 是异常落在谁身上（可为空）。
var anomalies: Array = []
var next_anomaly_no: int = 1
## {"kind", "deadline_film", "note"}；空字典表示没有
var ultimatum: Dictionary = {}
var potentials: Dictionary = {}
var demon_copies: Array = []
var drag_factors: Array = []
var bottlenecks: Dictionary = {}
## 主神的决定和理由：{"film", "kind", "payload", "reason"}
var decisions: Array = []


static func rules() -> Dictionary:
	if _cache.is_empty():
		var res := DataLoader.load_json(PATH)
		assert(res.ok, res.error)
		_cache = res.data
	return _cache


func record(film: String, kind: String, payload: Dictionary, reason: String) -> void:
	decisions.append({"film": film, "kind": kind, "payload": payload.duplicate(true), "reason": reason})


## 课程推进一步；已经到终局时返回 false。
func advance_stage(film: String, reason: String) -> bool:
	var stages: Array = rules()["stages"]
	var i := stages.find(stage)
	if i >= stages.size() - 1:
		return false
	stage = String(stages[i + 1])
	record(film, "advance_stage", {"stage": stage}, reason)
	return true


func add_anomaly(kind: String, film: String, note: String, reason: String, char_id: String = "") -> String:
	var id := "anomaly_%d" % next_anomaly_no
	next_anomaly_no += 1
	anomalies.append({"id": id, "kind": kind, "char": char_id, "since_film": film, "note": note, "resolved_film": ""})
	record(film, "add_anomaly", {"id": id, "kind": kind, "char": char_id}, reason)
	return id


## 同一种异常（落在同一个人身上）还开着吗？返回它的 id，没有返回空字符串。
func open_anomaly(kind: String, char_id: String = "") -> String:
	for a: Dictionary in open_anomalies():
		if a["kind"] == kind and String(a.get("char", "")) == char_id:
			return String(a["id"])
	return ""


func resolve_anomaly(id: String, film: String, reason: String) -> bool:
	for a: Dictionary in anomalies:
		if a["id"] == id and a["resolved_film"] == "":
			a["resolved_film"] = film
			record(film, "resolve_anomaly", {"id": id}, reason)
			return true
	return false


func open_anomalies() -> Array:
	return anomalies.filter(func(a: Dictionary) -> bool: return a["resolved_film"] == "")


func set_ultimatum(kind: String, deadline_film: String, note: String, film: String, reason: String) -> void:
	ultimatum = {"kind": kind, "deadline_film": deadline_film, "note": note}
	record(film, "ultimatum", ultimatum, reason)


## 潜力突升（造人、凭自身属性开锁、心魔突破、顿悟……）。突升够大时，主神会考虑复制进恶魔小队（返回 true）。
func potential_spike(char_id: String, amount: float, film: String, reason: String) -> bool:
	potentials[char_id] = float(potentials.get(char_id, 0.0)) + amount
	record(film, "potential_spike", {"char": char_id, "amount": amount}, reason)
	var consider := amount >= float(rules()["demon_copy_spike"]) and not demon_copies.has(char_id)
	if consider:
		record(film, "consider_demon_copy", {"char": char_id}, "潜力突升够大，值得做对照实验")
	return consider


func copy_to_demon_team(char_id: String, film: String, reason: String) -> void:
	if not demon_copies.has(char_id):
		demon_copies.append(char_id)
	record(film, "demon_copy", {"char": char_id}, reason)


## 一部片之后评价怎么变（核心机制分析 2.2）：
##   result = {"expected_wipe": 主神本来按团灭安排, "members": 人数, "survivors": 活着回来的人数（中途死过又复活的不算活着）,
##             "captain_died": 队长死了, "all_died": 所有人都死过}
##   所有人都死过 → 评价清零，经历过的片的记录消失；
##   活过一部本该团灭的片、损失又小（幸存比例 ≥ 0.7）→ +1；队长死亡 → −1（不低于 0）。
static func update_rating(game_state: RefCounted, result: Dictionary) -> Dictionary:
	var r: Dictionary = rules()["rating"]
	var before: int = game_state.team_rating
	var reasons: Array[String] = []
	if bool(result.get("all_died", false)):
		game_state.team_rating = 0
		game_state.films_record.clear()
		reasons.append("wiped")
		return {"before": before, "after": 0, "reasons": reasons}
	var rating := before
	var members := maxi(1, int(result.get("members", 1)))
	if bool(result.get("expected_wipe", false)) and float(result.get("survivors", 0)) / members >= float(r["low_loss_survivor_ratio"]):
		rating += int(r["survive_wipe_bonus"])
		reasons.append("survived_wipe")
	if bool(result.get("captain_died", false)):
		rating += int(r["captain_death"])
		reasons.append("captain_died")
	game_state.team_rating = maxi(0, rating)
	return {"before": before, "after": game_state.team_rating, "reasons": reasons}


## 评价战力：主神只看得见兑换来的东西，看不见锻炼（base）和基因锁。
## = 基准 × (1 + 评价 × 系数) × 队伍平均"可见属性" / 100，可见属性 = 100 + 兑换属性（enhanced + enhanced_high 全额）÷ 6。
## 新人队伍（评价 0、没兑换）正好是 120，和计划 3 的默认值一致。
static func rating_power(game_state: RefCounted, member_ids: Array) -> float:
	var rp: Dictionary = rules()["rating_power"]
	var total := 0.0
	var n := 0
	for id: String in member_ids:
		var ch: RefCounted = game_state.characters[id]
		if not ch.alive:
			continue
		var visible := 0.0
		for k in Attributes.KEYS:
			visible += float(ch.attributes.enhanced[k]) + float(ch.attributes.enhanced_high[k])
		total += 100.0 + visible / 6.0
		n += 1
	var avg := total / n if n > 0 else 100.0
	return float(rp["base"]) * (1.0 + game_state.team_rating * float(rp["per_rating"])) * avg / 100.0


func to_dict() -> Dictionary:
	return {
		"stage": stage,
		"anomalies": anomalies.duplicate(true),
		"next_anomaly_no": next_anomaly_no,
		"ultimatum": ultimatum.duplicate(true),
		"potentials": potentials.duplicate(),
		"demon_copies": demon_copies.duplicate(),
		"drag_factors": drag_factors.duplicate(true),
		"bottlenecks": bottlenecks.duplicate(true),
		"decisions": decisions.duplicate(true),
	}


func load_dict(d: Dictionary) -> void:
	stage = String(d["stage"])
	anomalies = (d["anomalies"] as Array).duplicate(true)
	next_anomaly_no = int(d["next_anomaly_no"])
	ultimatum = (d["ultimatum"] as Dictionary).duplicate(true)
	potentials = (d["potentials"] as Dictionary).duplicate()
	demon_copies = (d["demon_copies"] as Array).duplicate()
	drag_factors = (d["drag_factors"] as Array).duplicate(true)
	bottlenecks = (d["bottlenecks"] as Dictionary).duplicate(true)
	decisions = (d["decisions"] as Array).duplicate(true)
