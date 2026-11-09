extends "res://tests/test_case.gd"

const Companion = preload("res://core/hub/companion.gd")
const Character = preload("res://core/model/character.gd")
const Session = preload("res://core/session/session.gd")


func _lori() -> Dictionary:
	var c := {"id": "zheng_zha_human_1", "name": "萝丽", "creator": "zheng_zha", "attributes": {}}
	Companion.init_fields(c, "luo_li", 0)
	return c


## 刚造出来：心情 60、亲密 50、依赖 40、安心 40，人设 luo_li。
func test_init_fields() -> void:
	var c := _lori()
	assert_almost(float(c["mood"]), 60.0)
	assert_almost(float(c["intimacy"]), 50.0)
	assert_eq(String(c["persona"]), "luo_li")
	assert_eq(Companion.wish(c), "想知道你每天在练什么")


## 陪她一天、一起训练、说话：各自改哪些数，制造者恐惧怎么降；说话每天只算一次。
func test_actions() -> void:
	var c := _lori()
	var zz := Character.new("zheng_zha", "郑吒", {})
	zz.fear = 30.0
	Companion.visit(c, zz, 1)
	assert_almost(float(c["intimacy"]), 60.0)
	assert_almost(float(c["mood"]), 75.0)
	assert_almost(zz.fear, 20.0)
	Companion.train_together(c, zz, 2)
	assert_almost(float(c["dependence"]), 35.0)
	assert_almost(zz.fear, 15.0)
	assert_eq(Companion.talked(c, 2).size(), 1)
	assert_eq(Companion.talked(c, 2).size(), 0, "同一天只算一次")
	assert_almost(float(c["intimacy"]), 68.0)


## 好几天没人陪，心情往下掉；亲密够高时，制造者每天恐惧多降 5。
func test_day_passed() -> void:
	var c := _lori()
	var zz := Character.new("zheng_zha", "郑吒", {})
	zz.fear = 20.0
	Companion.day_passed(c, zz, 2)
	assert_almost(float(c["mood"]), 60.0, 0.0001, "两天内不算孤单")
	Companion.day_passed(c, zz, 3)
	assert_almost(float(c["mood"]), 56.0)
	assert_almost(zz.fear, 20.0, 0.0001, "亲密 50 还不够当锚")
	c["intimacy"] = 65.0
	Companion.day_passed(c, zz, 4)
	assert_almost(zz.fear, 15.0)


## 出征时的反应随亲密和心情变；亲密又开心时，她是锚，制造者恐惧 −10。
func test_farewell() -> void:
	var c := _lori()
	assert_eq(String(Companion.farewell(c)["line"]), "路上小心。回来给我讲讲。")
	c["intimacy"] = 80.0
	var f := Companion.farewell(c)
	assert_eq(String(f["line"]), "早点回来。我会一直等你。")
	assert_almost(float(f["fear"]), -10.0)
	c["mood"] = 30.0
	assert_eq(String(Companion.farewell(c)["line"]), "你又要走了……这次也不带我。")
	assert_eq(Companion.wish(c), "想你多陪陪她")


func _hub_session() -> RefCounted:
	var s := Session.new()
	s.start_m1(1)
	s.expedition.st.outcome = "returned"
	s.settle()
	s.enter_hub()
	return s


## 休整里：造萝丽带上陪伴字段；陪她、一起训练各耗 1 天，最后一天不行；说话不耗天。
func test_hub_actions() -> void:
	var s := _hub_session()
	s.hub.create_human("zheng_zha", "萝丽", {"spirit": 120}, "luo_li")
	var id := String(s.game.companions[0]["id"])
	assert_eq(String(s.game.companions[0]["persona"]), "luo_li")
	var events: Array[Dictionary] = s.hub.visit_companion(id)
	assert_eq(String(events[0]["type"]), "companion_visited")
	assert_eq(s.hub.day, 1)
	s.hub.train_with_companion(id)
	assert_eq(s.hub.day, 2)
	assert_eq(s.hub.companion_talked(id).size(), 1)
	assert_eq(s.hub.day, 2)
	s.hub.day = 8
	assert_eq(String(s.hub.visit_companion(id)[0]["reason"]), "no_days")
	assert_eq(String(s.hub.visit_companion("nope")[0]["reason"]), "no_companion")


## 走光柱：萝丽说一句话，亲密高时郑吒更安心；九天没人陪她会难过；造物随存档走。
func test_depart_farewell() -> void:
	var s := _hub_session()
	s.hub.create_human("zheng_zha", "萝丽", {}, "luo_li")
	s.game.companions[0]["intimacy"] = 90.0
	s.game.characters["zheng_zha"].fear = 30.0
	s.hub.rest(9)
	assert_almost(float(s.game.companions[0]["mood"]), 60.0 - 7 * 4.0 - 5.0, 0.0001, "第 3~9 天没人陪每天 −4；晨会没人理，按默认让她回房间又 −5")
	s.game.companions[0]["mood"] = 80.0
	assert_true(s.depart())
	assert_eq(s.farewells.size(), 1)
	assert_eq(String(s.farewells[0]["line"]), "早点回来。我会一直等你。")
	assert_almost(s.game.characters["zheng_zha"].fear, 0.0, 0.0001, "休整九天恐惧早就降到 0，锚只是让它别往上走")
	var t := Session.new()
	assert_true(t.load_dict(s.to_dict()))
	assert_eq(t.farewells, s.farewells)


## 制造者死在片里，造物和房间一起消失（下一次结算时）。
func test_companion_follows_creator() -> void:
	var s := Session.new()
	s.start_m1(1)
	s.game.companions.append({"id": "zheng_zha_human_1", "name": "萝丽", "creator": "zheng_zha", "attributes": {}})
	s.game.characters["zheng_zha"].alive = false
	s.expedition.st.outcome = "returned"
	s.settle()
	assert_eq(s.game.companions, [])
	assert_eq(s.film_report["companions_lost"], ["萝丽"])
