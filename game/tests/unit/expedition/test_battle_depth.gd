extends "res://tests/test_case.gd"

const Session = preload("res://core/session/session.gd")
const Battle = preload("res://core/battle/battle.gd")
const Rng = preload("res://core/util/rng.gd")


func _at_control() -> RefCounted:
	var s := Session.new()
	s.start_m1(1)
	var ex = s.expedition
	ex.choose("listen")
	ex.move("s1", "hall")
	ex.move("s1", "stairs")
	ex.choose("help")
	ex.move("s1", "laser")
	ex.choose("save_matthew")
	ex.move("s1", "control")
	return s


## 爬行者是精英：只点第一个按钮（拳脚/手枪乱打）会死人；这是"无脑点"的代价。
func test_mindless_clicking_costs_lives() -> void:
	var s := _at_control()
	var ex = s.expedition
	ex.st.pending_battle = {"location": "control", "squad": "s1",
		"enemies": [{"def": "licker", "count": 2, "row": 0}], "dark": false,
		"survive_until": -1.0, "after_victory": [], "after_defeat": []}
	var b := Battle.new()
	b.setup(ex.battle_units({}), ex.battle_options(), Rng.new(1))
	var guard := 0
	while b.outcome == "ongoing" and guard < 400:
		var acts: Array[Dictionary] = b.legal_actions()
		if acts.is_empty():
			break
		b.act(acts[0])
		guard += 1
	var dead := 0
	for u: RefCounted in b.field.units:
		if u.side == "ally" and not u.alive:
			dead += 1
	assert_eq(b.outcome, "victory")
	assert_true(dead >= 1, "无脑点至少死一个人，实际 %d" % dead)


## 判断力来自队伍里最聪明的人：M1 有詹岚（130），能看到敌人的技能名。
func test_intel_comes_from_smartest_member() -> void:
	var s := _at_control()
	var ex = s.expedition
	ex.st.pending_battle = {"location": "control", "squad": "s1",
		"enemies": [{"def": "zombie", "count": 1, "row": 0}], "dark": false,
		"survive_until": -1.0, "after_victory": [], "after_defeat": []}
	assert_eq(int(ex.battle_options()["intel"]), 1)
	ex.st.characters["zhan_lan"].attributes.base["intelligence"] = 80.0
	ex.st.characters["zheng_zha"].attributes.base["intelligence"] = 80.0
	ex.st.characters["zhang_jie"].attributes.base["intelligence"] = 80.0
	assert_eq(int(ex.battle_options()["intel"]), 0)
