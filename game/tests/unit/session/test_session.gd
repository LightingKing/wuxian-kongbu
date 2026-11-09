extends "res://tests/test_case.gd"

const Session = preload("res://core/session/session.gd")

const SAVE_PATH := "user://test_session.json"


func _clean() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


## 新游戏：七个人、远征阶段、开场就要表态。
func test_start_m1() -> void:
	var s := Session.new()
	assert_true(s.start_m1(1))
	assert_eq(s.phase, "expedition")
	assert_eq(s.game.characters.size(), 7)
	assert_true(s.expedition != null)
	assert_eq(s.blocked_reason(), "choice")
	assert_eq(s.day, 0)


## 远征中途存档，读档后继续走，事件和状态完全一样。
func test_save_and_resume() -> void:
	_clean()
	var a := Session.new()
	a.start_m1(1)
	a.expedition.choose("listen")
	a.expedition.move("s1", "hall")
	assert_eq(a.save_to(SAVE_PATH), OK)
	var b := Session.load_from(SAVE_PATH)
	assert_true(b != null)
	assert_eq(b.phase, "expedition")
	assert_eq(b.game.to_dict(), a.game.to_dict())
	assert_eq(b.expedition.to_dict(), a.expedition.to_dict())
	var ea: Array[Dictionary] = a.expedition.move("s1", "stairs")
	var eb: Array[Dictionary] = b.expedition.move("s1", "stairs")
	assert_eq(eb, ea)
	assert_eq(b.expedition.st.clock, a.expedition.st.clock)
	assert_eq(b.expedition.st.pending_choice, a.expedition.st.pending_choice)
	_clean()


## 结算只能做一次；然后进主神空间，休整 9 天后才能出发。
func test_settle_and_rest_days() -> void:
	var s := Session.new()
	s.start_m1(1)
	s.expedition.st.outcome = "returned"
	var results: Dictionary = s.settle()
	assert_eq(s.phase, "settlement")
	assert_eq(s.day, 0)
	assert_eq(int(results["zheng_zha"]["final_points"]), 1000)
	assert_eq(s.settle(), {})
	assert_true(s.enter_hub())
	for i in 9:
		assert_true(s.advance_day())
	assert_eq(s.day, 9)
	assert_true(s.can_depart())
	assert_true(s.depart())
	assert_eq(s.phase, "done")
	assert_false(s.advance_day())


## 结算后存档，读档保留阶段、天数、结算结果和点数。
func test_save_after_settlement() -> void:
	_clean()
	var a := Session.new()
	a.start_m1(2)
	a.expedition.st.outcome = "returned"
	a.settle()
	a.enter_hub()
	a.advance_day()
	assert_eq(a.save_to(SAVE_PATH), OK)
	var b := Session.load_from(SAVE_PATH)
	assert_true(b != null)
	assert_eq(b.phase, "hub")
	assert_eq(b.day, 1)
	assert_eq(int(b.game.characters["zheng_zha"].points), 1000)
	assert_eq(int(b.settlement["zheng_zha"]["final_points"]), 1000)
	assert_eq(b.to_dict()["expedition"], a.to_dict()["expedition"])
	_clean()


func test_reject_bad_save() -> void:
	assert_false(Session.new().load_dict({"version": 99}))
	assert_false(Session.new().load_dict({"version": 1, "chapter": "res://nope.json", "game": {}}))
	assert_true(Session.load_from("user://nope.json") == null)
