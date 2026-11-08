extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const GameState = preload("res://core/model/game_state.gd")
const Hub = preload("res://core/hub/hub.gd")


func _game() -> RefCounted:
	var g := GameState.new(1)
	for id in ["zheng_zha", "zhang_jie", "newbie"]:
		var c := Character.new(id, id, {})
		c.points = 6502
		c.tickets.add("B", 1)
		g.add_character(c)
	return g


func _hub(g: RefCounted, days: int = 9) -> RefCounted:
	var h := Hub.new()
	h.start(g, days)
	return h


## 原著惯例：回归当晚不兑换，只结算和造人。
func test_return_night() -> void:
	var g := _game()
	var h := _hub(g)
	var events: Array[Dictionary] = h.exchange("zheng_zha", "desert_eagle")
	assert_eq(events[0], {"type": "hub_refused", "reason": "return_night"})
	events = h.create_human("zheng_zha", "萝丽", {"spirit": 150})
	assert_eq(events[0]["type"], "human_created")
	h.rest(1)
	events = h.exchange("zheng_zha", "desert_eagle")
	assert_eq(events[0]["type"], "exchange_done")


func test_days_and_fear() -> void:
	var g := _game()
	var h := _hub(g)
	g.characters["newbie"].fear = 40.0
	var events: Array[Dictionary] = h.rest(2)
	assert_eq(h.day, 2)
	assert_eq(h.days_left(), 7)
	assert_almost(g.characters["newbie"].fear, 10.0)
	assert_eq(events[1], {"type": "day_passed", "day": 2, "days_left": 7})
	assert_eq(h.rest(8)[0]["reason"], "no_days")
	h.rest(7)
	assert_true(h.can_depart())


## 训练提升熟练度；最后一天强制休息，不能占用。
func test_train() -> void:
	var g := _game()
	var h := _hub(g)
	var zz: RefCounted = g.characters["zheng_zha"]
	zz.abilities.append("red_flame")
	zz.proficiency["red_flame"] = 0.3
	h.train("zheng_zha", "red_flame", 2)
	assert_almost(float(zz.proficiency["red_flame"]), 0.8)
	assert_eq(h.day, 2)
	assert_eq(h.train("zheng_zha", "red_flame", 7)[0]["reason"], "no_days")
	assert_eq(h.train("zheng_zha", "flying", 1)[0]["reason"], "unknown_skill")
	h.train("zheng_zha", "red_flame", 6)
	assert_almost(float(zz.proficiency["red_flame"]), 1.0)


## 修复：轻伤"修补" 400，重伤按伤势涨到 2000；可以由别人付；满血不要钱。
func test_repair() -> void:
	var g := _game()
	var h := _hub(g)
	var zz: RefCounted = g.characters["zheng_zha"]
	assert_eq(h.repair_cost("zheng_zha"), 0)
	zz.hp = zz.hp_max() * 0.6
	assert_eq(h.repair_cost("zheng_zha"), 400)
	zz.hp = zz.hp_max() * 0.25
	assert_eq(h.repair_cost("zheng_zha"), 1200)
	zz.hp = 0.0
	assert_eq(h.repair_cost("zheng_zha"), 2000)
	zz.flags["gene_lock_aftereffect"] = true
	h.repair("zheng_zha", "zhang_jie")
	assert_almost(zz.hp, zz.hp_max())
	assert_eq(zz.points, 6502)
	assert_eq(g.characters["zhang_jie"].points, 4502)
	assert_false(zz.flags.has("gene_lock_aftereffect"))
	assert_eq(h.repair("zheng_zha")[0]["reason"], "not_injured")


## 造人：第一个免费，之后 500 点；素质最多两倍常人。
func test_create_human() -> void:
	var g := _game()
	var h := _hub(g)
	var first: Array[Dictionary] = h.create_human("zheng_zha", "萝丽", {"spirit": 150, "muscle": 300})
	assert_eq(int(first[0]["cost"]), 0)
	assert_almost(float(first[0]["companion"]["attributes"]["muscle"]), 200.0)
	var second: Array[Dictionary] = h.create_human("zheng_zha", "保镖", {})
	assert_eq(int(second[0]["cost"]), 500)
	assert_eq(g.characters["zheng_zha"].points, 6002)
	assert_eq(g.companions.size(), 2)
	assert_eq(g.companions[1]["id"], "zheng_zha_human_2")


func test_buy_attribute() -> void:
	var g := _game()
	var h := _hub(g)
	h.rest(1)
	h.buy_attribute("newbie", "nerve_reaction", 100)
	assert_eq(g.characters["newbie"].points, 5502)
	assert_almost(g.characters["newbie"].attributes.total("nerve_reaction"), 200.0)
	assert_eq(h.buy_attribute("newbie", "muscle", 1000)[0]["reason"], "not_enough_points")


func test_tickets() -> void:
	var g := _game()
	var h := _hub(g)
	h.split_ticket("zheng_zha", "B")
	assert_eq(int(g.characters["zheng_zha"].tickets.counts["C"]), 3)
	h.merge_tickets("zheng_zha", "C")
	assert_eq(int(g.characters["zheng_zha"].tickets.counts["B"]), 1)
	assert_eq(h.split_ticket("zheng_zha", "D")[0]["reason"], "cannot_split")


## 每人每次休整只能给别人代兑一次。
func test_gift_once_per_rest() -> void:
	var g := _game()
	var h := _hub(g)
	h.rest(1)
	var first: Array[Dictionary] = h.exchange("newbie", "desert_eagle", {"payer": "zhang_jie"})
	assert_eq(first[0]["type"], "exchange_done")
	var second: Array[Dictionary] = h.exchange("zheng_zha", "desert_eagle", {"payer": "zhang_jie"})
	assert_eq(second[0]["reasons"], ["gift_used"])
	var own: Array[Dictionary] = h.exchange("zhang_jie", "desert_eagle")
	assert_eq(own[0]["type"], "exchange_done")


func test_save_round_trip() -> void:
	var g := _game()
	var h := _hub(g)
	h.rest(3)
	h.exchange("newbie", "desert_eagle", {"payer": "zhang_jie"})
	var copy := Hub.new()
	copy.load_dict(JSON.parse_string(JSON.stringify(h.to_dict())), g)
	assert_eq(copy.to_dict(), h.to_dict())
	assert_eq(copy.days_left(), 6)
