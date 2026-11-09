extends RefCounted
## 整局游戏状态。存档就是它的 to_dict()。

const Rng = preload("res://core/util/rng.gd")
const Character = preload("res://core/model/character.gd")
const Agenda = preload("res://core/director/agenda.gd")

const SAVE_VERSION := 1

var rng: RefCounted = Rng.new(0)
var characters: Dictionary = {}  # id -> Character
var team_rating: int = 0  # 主神评价分（核心机制分析 2.2）
var films_record: Array = []  # 经历过的片的 id；团灭时清空
var mode: Dictionary = {"content": "canon", "control": "team"}
var iron_man: bool = true
## 造物（人造人）：{"id", "name", "creator", "attributes"}。制造者死亡，造物随之消失（设计规格 6.6）。
var companions: Array = []
var flags: Dictionary = {}
## 主神议程（设计规格 5.5）：课程阶段、异常、潜力突升、恶魔小队复制体和每个决定的理由。玩家看不见，随存档走。
var agenda: RefCounted = Agenda.new()


func _init(seed_value: int = 0) -> void:
	rng = Rng.new(seed_value)


func add_character(c: RefCounted) -> void:
	characters[c.id] = c


func living_characters() -> Array:
	return characters.values().filter(func(c): return c.alive)


func to_dict() -> Dictionary:
	var chars := {}
	for id in characters:
		chars[id] = characters[id].to_dict()
	return {
		"version": SAVE_VERSION,
		"rng": rng.to_dict(),
		"characters": chars,
		"team_rating": team_rating,
		"films_record": films_record.duplicate(),
		"mode": mode.duplicate(),
		"iron_man": iron_man,
		"companions": companions.duplicate(true),
		"flags": flags.duplicate(true),
		"agenda": agenda.to_dict(),
	}


func load_dict(d: Dictionary) -> void:
	assert(int(d["version"]) == SAVE_VERSION, "存档版本不匹配")
	rng.load_dict(d["rng"])
	characters.clear()
	for id in d["characters"]:
		var c := Character.new()
		c.load_dict(d["characters"][id])
		characters[id] = c
	team_rating = int(d["team_rating"])
	films_record = (d["films_record"] as Array).duplicate()
	mode = (d["mode"] as Dictionary).duplicate()
	iron_man = bool(d["iron_man"])
	companions = (d.get("companions", []) as Array).duplicate(true)
	flags = (d["flags"] as Dictionary).duplicate(true)
	agenda = Agenda.new()
	if d.has("agenda"):
		agenda.load_dict(d["agenda"])
