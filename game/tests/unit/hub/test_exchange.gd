extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const Exchange = preload("res://core/hub/exchange.gd")
const Rng = preload("res://core/util/rng.gd")


func _rich(id: String = "zheng_zha") -> RefCounted:
	var c := Character.new(id, id, {})
	c.points = 20000
	c.tickets.add("D", 3)
	c.tickets.add("C", 3)
	c.tickets.add("B", 3)
	return c


## 郑吒的第一次兑换（原著）：低级气功 500+D、血族男爵 800+D。
func test_buy_qigong_low() -> void:
	var c := _rich()
	var events := Exchange.buy(c, "qigong_low", Rng.new(1))
	assert_eq(events[0]["type"], "exchange_done")
	assert_eq(c.points, 19500)
	assert_eq(int(c.tickets.counts["D"]), 2)
	assert_almost(c.attributes.total("muscle"), 130.0)
	assert_almost(float(c.energy["neili"]), 30.0)
	assert_eq(c.owned, ["qigong_low"] as Array[String])


## B 级的属性按基因锁发挥率打折：0 阶只发挥 50%。
func test_b_grade_attributes_use_gene_lock() -> void:
	var c := _rich()
	Exchange.buy(c, "spider_gene", Rng.new(1))
	assert_almost(c.attributes.total("nerve_reaction"), 100.0 + 50.0)
	c.gene_lock_stage = 4
	assert_almost(c.attributes.total("nerve_reaction"), 200.0)
	assert_true(c.abilities.has("spider_silk"))


func test_refusal_reasons() -> void:
	var poor := Character.new("p", "p", {})
	var r := Exchange.check(poor, "qigong_mid")
	assert_false(bool(r["ok"]))
	assert_true((r["reasons"] as Array).has("not_enough_points"))
	assert_true((r["reasons"] as Array).has("missing_ticket"))
	assert_true((r["reasons"] as Array).has("missing_prerequisite:qigong_low"))
	assert_eq(Exchange.check(poor, "nope")["reasons"], ["unknown_entry"])
	var events := Exchange.buy(poor, "qigong_mid", Rng.new(1))
	assert_eq(events[0]["type"], "exchange_refused")
	assert_eq(poor.points, 0)


## 纳戒需要内力。
func test_needs_energy() -> void:
	var c := _rich()
	assert_eq(Exchange.check(c, "na_ring")["reasons"], ["needs_energy:neili"])
	Exchange.buy(c, "qigong_low", Rng.new(1))
	assert_true(bool(Exchange.check(c, "na_ring")["ok"]))


## 素质门槛，有对应天赋的人可以绕过（詹岚的精神力天赋）。
func test_gate_and_talent_bypass() -> void:
	var c := _rich()
	assert_eq(Exchange.check(c, "mind_scan")["reasons"], ["gate:spirit"])
	c.flags["talents"] = ["spirit_talent"]
	assert_true(bool(Exchange.check(c, "mind_scan")["ok"]))


func test_no_duplicates_but_consumables_stack() -> void:
	var c := _rich()
	Exchange.buy(c, "desert_eagle", Rng.new(1))
	assert_eq(Exchange.check(c, "desert_eagle")["reasons"], ["already_owned"])
	assert_true(c.skills.has("desert_eagle"))
	Exchange.buy(c, "grenade", Rng.new(1))
	Exchange.buy(c, "grenade", Rng.new(1))
	assert_almost(float(c.items["grenade"]), 2.0)
	assert_false(c.owned.has("grenade"))


func test_double_b_ticket() -> void:
	var c := _rich()
	Exchange.buy(c, "rebirth_cross", Rng.new(1))
	assert_eq(c.points, 13000)
	assert_eq(int(c.tickets.counts["B"]), 1)
	assert_almost(float(c.battle_resources()["rebirth_cross"]), 1.0)


## 前置链：男爵 → 子爵 → 伯爵；同一系列不算双血统。
func test_bloodline_chain_no_risk() -> void:
	var c := _rich()
	Exchange.buy(c, "vampire_baron", Rng.new(1))
	Exchange.buy(c, "vampire_viscount", Rng.new(1))
	var r := Exchange.check(c, "vampire_count")
	assert_true(bool(r["ok"]))
	assert_eq(r["warnings"], [])


## 双血统：先警告不兑换；坚持兑换时按 70% 结算变异。
func test_second_bloodline_warns_then_rolls() -> void:
	var mutated := 0
	for s in 20:
		var c := _rich()
		Exchange.buy(c, "vampire_baron", Rng.new(s))
		var warn := Exchange.buy(c, "spider_gene", Rng.new(s))
		assert_eq(warn[0]["type"], "exchange_warning")
		assert_false(c.owned.has("spider_gene"))
		var events := Exchange.buy(c, "spider_gene", Rng.new(s), {"accept_risk": true})
		assert_true(c.owned.has("spider_gene"))
		if events[1]["type"] == "bloodline_mutation":
			mutated += 1
			assert_true(bool(c.flags["mutated"]))
	assert_true(mutated >= 8 and mutated <= 19, "20 次里变异 %d 次" % mutated)


## 代兑：别人付钱；付钱的人这次已经给过别人就不行。
func test_gift() -> void:
	var giver := _rich("zhang_jie")
	var newbie := Character.new("newbie", "新人", {})
	var events := Exchange.buy(newbie, "qigong_low", Rng.new(1), {"payer": giver})
	assert_eq(events[0]["payer"], "zhang_jie")
	assert_eq(giver.points, 19500)
	assert_eq(newbie.points, 0)
	assert_true(newbie.owned.has("qigong_low"))
	assert_eq(Exchange.check(newbie, "vampire_baron", giver, true)["reasons"], ["gift_used"])
