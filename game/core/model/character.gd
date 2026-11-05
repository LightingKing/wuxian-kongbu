extends RefCounted
## 一个轮回者。点数和支线是个人的（原著里每人各自结算、各自兑换）。

const Attributes = preload("res://core/model/attributes.gd")
const PlotTickets = preload("res://core/economy/plot_tickets.gd")
const DerivedStats = preload("res://core/model/derived_stats.gd")

var id: String = ""
var display_name: String = ""
var attributes: RefCounted = Attributes.new()
var tickets: RefCounted = PlotTickets.new()
var points: int = 0
var gene_lock_stage: int = 0
var fear: float = 0.0
var hp: float = 0.0
var alive: bool = true
var films_completed: int = 0
var revived_once: bool = false
var flags: Dictionary = {}


func _init(char_id: String = "", name: String = "", attr_values: Dictionary = {}) -> void:
	id = char_id
	display_name = name
	attributes = Attributes.new(attr_values)
	hp = hp_max()


func hp_max() -> float:
	return float(DerivedStats.compute(attributes)["hp_max"])


## 原著：未完成过任何一部片的人算新人（复活免费）。
func is_newbie() -> bool:
	return films_completed == 0


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
