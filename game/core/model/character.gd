extends RefCounted
## 一个轮回者。点数和支线是个人的（原著里每人各自结算、各自兑换）。

const Attributes = preload("res://core/model/attributes.gd")
const PlotTickets = preload("res://core/economy/plot_tickets.gd")
const DerivedStats = preload("res://core/model/derived_stats.gd")
const GeneLock = preload("res://core/model/gene_lock.gd")

var id: String = ""
var display_name: String = ""
var attributes: RefCounted = Attributes.new()
var tickets: RefCounted = PlotTickets.new()
var points: int = 0
## 改阶数时同步 B 级及以上兑换属性的发挥率（设计规格 3.4）。
var gene_lock_stage: int = 0:
	set(value):
		gene_lock_stage = value
		if attributes != null:
			attributes.high_mult = GeneLock.effectiveness(value)
var fear: float = 0.0
var hp: float = 0.0
var alive: bool = true
var films_completed: int = 0
var revived_once: bool = false
var flags: Dictionary = {}
## 已兑换的兑换项 id（不含消耗品）。
var owned: Array[String] = []
## 战斗技能 id（battle/skills.json）。
var skills: Array[String] = []
## 还不能在战斗里直接用的能力（以后的计划逐步接入），例如红炎、轻功。
var abilities: Array[String] = []
## 技能熟练度 0~1：A 级以上兑换来的"只是心法"，要训练才能发挥（设计规格 6.2）。
var proficiency: Dictionary = {}
## 能量池上限，例如 {"neili": 30, "blood": 30}。
var energy: Dictionary = {}
## 道具数量，例如 {"grenade": 2}。
var items: Dictionary = {}


func _init(char_id: String = "", name: String = "", attr_values: Dictionary = {}) -> void:
	id = char_id
	display_name = name
	attributes = Attributes.new(attr_values)
	gene_lock_stage = 0
	hp = hp_max()


func hp_max() -> float:
	return float(DerivedStats.compute(attributes)["hp_max"])


## 原著：未完成过任何一部片的人算新人（复活免费）。
func is_newbie() -> bool:
	return films_completed == 0


## 带进战斗的资源：能量池加道具。
func battle_resources() -> Dictionary:
	var out := energy.duplicate()
	for k: String in items:
		out[k] = float(out.get(k, 0.0)) + float(items[k])
	return out


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"attributes": attributes.to_dict(),
		"tickets": tickets.to_dict(),
		"points": points,
		"gene_lock_stage": gene_lock_stage,
		"fear": fear,
		"hp": hp,
		"alive": alive,
		"films_completed": films_completed,
		"revived_once": revived_once,
		"flags": flags.duplicate(true),
		"owned": owned.duplicate(),
		"skills": skills.duplicate(),
		"abilities": abilities.duplicate(),
		"proficiency": proficiency.duplicate(),
		"energy": energy.duplicate(),
		"items": items.duplicate(),
	}


func load_dict(d: Dictionary) -> void:
	id = String(d["id"])
	display_name = String(d["display_name"])
	attributes.load_dict(d["attributes"])
	tickets.load_dict(d["tickets"])
	points = int(d["points"])
	gene_lock_stage = int(d["gene_lock_stage"])
	fear = float(d["fear"])
	hp = float(d["hp"])
	alive = bool(d["alive"])
	films_completed = int(d["films_completed"])
	revived_once = bool(d["revived_once"])
	flags = (d["flags"] as Dictionary).duplicate(true)
	owned.assign(d.get("owned", []))
	skills.assign(d.get("skills", []))
	abilities.assign(d.get("abilities", []))
	proficiency = (d.get("proficiency", {}) as Dictionary).duplicate()
	energy = (d.get("energy", {}) as Dictionary).duplicate()
	items = (d.get("items", {}) as Dictionary).duplicate()
