extends RefCounted
## 一局游戏（设计规格 2、10.2）：把 GameState、当前远征、阶段和休整天数装在一起。
## 阶段：expedition（在片子里）→ settlement（刚回归，结算完）→ hub（主神空间休整 9 天）→ done（下一次出发，M2 未做）。
## 界面只读这里的 game / expedition，并调用这里的方法推进；存档就是 to_dict()。

const GameState = preload("res://core/model/game_state.gd")
const Campaign = preload("res://core/campaign/campaign.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const Expedition = preload("res://core/expedition/expedition.gd")
const SaveService = preload("res://core/save/save_service.gd")
const Hub = preload("res://core/hub/hub.gd")
const Agenda = preload("res://core/director/agenda.gd")

const VERSION := 1
const M1_CHAPTER := "res://data/scenarios/biohazard1/chapter.json"
const PHASES: Array[String] = ["expedition", "settlement", "hub", "done"]
const REST_DAYS := 9

var game: RefCounted
var expedition: RefCounted
## 休整期的主神空间（settlement / hub 阶段才有）。
var hub: RefCounted
var phase: String = "expedition"
var chapter_path: String = ""
## 休整第几天（settlement 时为 1）。
var day: int = 0
## 上一次结算的结果（角色 id → 结算条目），给结算界面用。
var settlement: Dictionary = {}
## 对话记忆与信任：npc_id → {"memories": [...], "trust": 0~5}。core/dialogue 直接读写这个字典。
var dialogues: Dictionary = {}
## 上一部片的总评（结算界面用）：{"film", "members", "survivors", "rating_before", "rating_after", "reasons"}。
var film_report: Dictionary = {}


## 开一局：建 GameState、按章节装配七名轮回者、开始第一部片。
func start(chapter: String, seed_value: int = 0) -> bool:
	chapter_path = chapter
	game = GameState.new(seed_value)
	expedition = Campaign.start(game, chapter)
	if expedition == null:
		return false
	phase = "expedition"
	hub = null
	day = 0
	settlement = {}
	dialogues = {}
	film_report = {}
	return true


func start_m1(seed_value: int = 0) -> bool:
	return start(M1_CHAPTER, seed_value)


func in_expedition() -> bool:
	return phase == "expedition" and expedition != null


func expedition_over() -> bool:
	return expedition != null and String(expedition.st.outcome) != "ongoing"


## 现在为什么不能行动："" 表示可以，否则是 battle / choice / check / ended。
func blocked_reason() -> String:
	if not in_expedition():
		return "ended"
	if expedition.st.outcome != "ongoing":
		return "ended"
	if not expedition.st.pending_cutscene.is_empty():
		return "cutscene"
	if not expedition.st.pending_battle.is_empty():
		return "battle"
	if not expedition.st.pending_check.is_empty():
		return "check"
	if not expedition.st.pending_choice.is_empty():
		return "choice"
	return ""


## 片子结束（回归、全灭或剧本结局）后结算一次，进入 settlement 阶段。
func settle() -> Dictionary:
	if phase != "expedition" or not expedition_over():
		return {}
	settlement = expedition.finish()
	film_report = _rate_film()
	hub = Hub.new()
	hub.start(game, REST_DAYS)
	phase = "settlement"
	day = hub.day
	return settlement


## 主神按这部片的结果调整评价（设计规格 7.3）：本该团灭的片活下来七成以上 +1、所有人都死过清零。
## 半引导者这类异常没解除时，主神记一条"继续加压"的决定。
func _rate_film() -> Dictionary:
	var st: RefCounted = expedition.st
	var film: String = st.scenario.id
	var ag: Dictionary = Campaign.load_chapter(chapter_path).get("agenda", {})
	var survivors := 0
	for c: String in st.roster:
		if st.is_alive(c):
			survivors += 1
	var result := {
		"expected_wipe": bool(ag.get("expected_wipe", false)),
		"members": st.roster.size(),
		"survivors": survivors,
		"captain_died": false,
		"all_died": survivors == 0,
	}
	var r := Agenda.update_rating(game, result)
	game.agenda.record(film, "rating", r, "幸存 %d/%d：%s" % [survivors, st.roster.size(), "、".join(r["reasons"]) if not (r["reasons"] as Array).is_empty() else "评价不变"])
	for a: Dictionary in game.agenda.open_anomalies():
		game.agenda.record(film, "keep_pressure", {"anomaly": a["id"]}, "异常（%s）还没解除，下一部继续按最强者定难度。" % String(a["kind"]))
	return {
		"film": film, "members": st.roster.size(), "survivors": survivors,
		"rating_before": int(r["before"]), "rating_after": int(r["after"]), "reasons": (r["reasons"] as Array).duplicate(),
	}


func enter_hub() -> bool:
	if phase != "settlement":
		return false
	phase = "hub"
	return true


func advance_day() -> bool:
	if phase != "hub" or hub == null or hub.can_depart():
		return false
	hub.rest(1)
	day = hub.day
	return true


func can_depart() -> bool:
	return phase == "hub" and hub != null and hub.can_depart()


## 走光柱出发；M2 的内容还没做，先把阶段停在 done。
func depart() -> bool:
	if not can_depart():
		return false
	phase = "done"
	return true


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"phase": phase,
		"chapter": chapter_path,
		"day": day,
		"game": game.to_dict() if game != null else {},
		"expedition": expedition.to_dict() if expedition != null else {},
		"hub": hub.to_dict() if hub != null else {},
		"settlement": settlement.duplicate(true),
		"dialogues": dialogues.duplicate(true),
		"film_report": film_report.duplicate(true),
	}


## 读档失败返回 false（版本不对、字段缺失、剧本读不到）。
func load_dict(d: Dictionary) -> bool:
	if int(d.get("version", 0)) != VERSION or not d.has("game") or not d.has("chapter"):
		return false
	chapter_path = String(d["chapter"])
	var chapter := Campaign.load_chapter(chapter_path)
	if chapter.is_empty():
		return false
	game = GameState.new()
	game.load_dict(d["game"])
	phase = String(d.get("phase", "expedition"))
	if not PHASES.has(phase):
		return false
	day = int(d.get("day", 0))
	settlement = (d.get("settlement", {}) as Dictionary).duplicate(true)
	dialogues = (d.get("dialogues", {}) as Dictionary).duplicate(true)
	film_report = (d.get("film_report", {}) as Dictionary).duplicate(true)
	var h: Dictionary = d.get("hub", {})
	if not h.is_empty():
		hub = Hub.new()
		hub.load_dict(h, game)
		day = hub.day
	var e: Dictionary = d.get("expedition", {})
	if e.is_empty():
		expedition = null
		return phase != "expedition"
	var sc := Scenario.load_file(String(chapter["scenario"]))
	if sc == null:
		return false
	expedition = Expedition.new()
	expedition.load_dict(e, game, sc)
	return true


func save_to(path: String) -> Error:
	return SaveService.write_dict(path, to_dict())


static func load_from(path: String) -> RefCounted:
	var d := SaveService.read_dict(path)
	if d.is_empty():
		return null
	var s := new()
	if not s.load_dict(d):
		return null
	return s
