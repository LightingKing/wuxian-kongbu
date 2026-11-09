extends "res://tests/test_case.gd"

const Session = preload("res://core/session/session.gd")
const HubView = preload("res://ui/hub/hub_view.gd")


func _view() -> RefCounted:
	var s := Session.new()
	s.start_m1(1)
	s.expedition.st.outcome = "returned"
	s.settle()
	s.enter_hub()
	s.hub.rest(1)
	var zz: RefCounted = s.game.characters["zheng_zha"]
	zz.points = 5000
	zz.tickets.add("D")
	return HubView.new(s)


func test_day_and_catalog() -> void:
	var v := _view()
	assert_eq(v.day_text(), "第 1 天 / 9 天")
	assert_eq(v.days_left(), 8)
	assert_eq(v.characters().size(), 7)
	var all: Array[Dictionary] = v.entries("zheng_zha")
	assert_eq(all.size(), 26)
	var qigong := {}
	for e: Dictionary in all:
		if e["id"] == "qigong_low":
			qigong = e
	assert_eq(qigong["points"], 500)
	assert_true(bool(qigong["ok"]))
	assert_eq((v.entries("zheng_zha", "item") as Array).size(), 5)


## 兑换扣点数和支线、记到 owned；再买一次会被拒。
func test_buy_exchange() -> void:
	var v := _view()
	var events: Array[Dictionary] = v.buy("zheng_zha", "qigong_low")
	assert_eq(events[0]["type"], "exchange_done")
	var zz: RefCounted = v.game.characters["zheng_zha"]
	assert_eq(zz.points, 4500)
	assert_true(zz.owned.has("qigong_low"))
	assert_true(zz.energy.has("neili"))
	var again: Array[Dictionary] = v.buy("zheng_zha", "qigong_low")
	assert_eq(again[0]["type"], "exchange_refused")
	assert_true((again[0]["reasons"] as Array).has("already_owned"))


func test_attribute_and_ticket_split() -> void:
	var v := _view()
	var zz: RefCounted = v.game.characters["zheng_zha"]
	var before: float = zz.attributes.total("muscle")
	v.buy_attribute("zheng_zha", "muscle", 10)
	assert_almost(zz.attributes.total("muscle"), before + 10.0)
	assert_eq(zz.points, 4900)
	assert_eq(zz.tickets.counts["D"], 1)
	zz.tickets.add("C")
	v.split_ticket("zheng_zha", "C")
	assert_eq(zz.tickets.counts["C"], 0)
	assert_eq(zz.tickets.counts["D"], 4)


## 修复：按伤势报价，修完回满；没伤的不在列表里。
func test_repair() -> void:
	var v := _view()
	var zz: RefCounted = v.game.characters["zheng_zha"]
	zz.hp = 30.0
	var list: Array[Dictionary] = v.repairs()
	assert_eq(list.size(), 1)
	var cost := int(list[0]["cost"])
	assert_true(cost >= 400 and cost <= 2000, str(cost))
	v.repair("zheng_zha")
	assert_almost(zz.hp, zz.hp_max())
	assert_eq(zz.points, 5000 - cost)
	assert_eq(v.repairs().size(), 0)


## 造人：第一次免费，之后 500；造物记在 game.companions。
func test_create_human() -> void:
	var v := _view()
	var events: Array[Dictionary] = v.create_human("zheng_zha", "萝丽")
	assert_eq(events[0]["type"], "human_created")
	assert_eq(events[0]["cost"], 0)
	assert_eq(v.companions().size(), 1)
	assert_eq(String(v.companions()[0]["name"]), "萝丽")
	var second: Array[Dictionary] = v.create_human("zheng_zha", "萝丽二号")
	assert_eq(second[0]["cost"], 500)


## 训练：熟练度低于 1 的能力才列出来；练一天涨 0.25，天数一起走。
func test_train() -> void:
	var v := _view()
	var zz: RefCounted = v.game.characters["zheng_zha"]
	zz.abilities.append("red_flame")
	zz.proficiency["red_flame"] = 0.3
	var list: Array[Dictionary] = v.trainable("zheng_zha")
	assert_eq(list.size(), 1)
	assert_eq(list[0]["id"], "red_flame")
	v.train("zheng_zha", "red_flame", 1)
	assert_almost(float(zz.proficiency["red_flame"]), 0.55)
	assert_eq(v.session.day, 2)
