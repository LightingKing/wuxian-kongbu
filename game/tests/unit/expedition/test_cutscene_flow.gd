extends "res://tests/test_case.gd"
## 剧情插图的流程：触发、阻塞、关闭后继续、存档保留。

const Session = preload("res://core/session/session.gd")


func _at_laser() -> RefCounted:
	var s := Session.new()
	s.start_m1(1)
	s.expedition.choose("listen")
	s.expedition.move("s1", "hall")
	s.expedition.move("s1", "stairs")
	s.expedition.choose("help")
	return s


func test_laser_triggers_cutscene() -> void:
	var s := _at_laser()
	var events: Array[Dictionary] = s.expedition.move("s1", "laser")
	assert_false(s.expedition.st.pending_cutscene.is_empty(), "走进激光通道要先播插图")
	assert_eq(String(s.expedition.st.pending_cutscene["name"]), "cg_laser")
	assert_true(String(s.expedition.st.pending_cutscene["text"]).contains("激光网"), "字幕跟着插图走")
	var types: Array[String] = []
	for e: Dictionary in events:
		types.append(String(e["type"]))
	assert_true(types.has("cutscene"), str(types))


func test_cutscene_blocks_actions() -> void:
	var s := _at_laser()
	s.expedition.move("s1", "laser")
	var ev: Array[Dictionary] = s.expedition.rest("s1", 5)
	assert_eq(String(ev[0]["type"]), "invalid_action")
	assert_eq(String(ev[0]["reason"]), "cutscene_pending")
	var moved: Array[Dictionary] = s.expedition.move("s1", "control")
	assert_eq(String(moved[0]["type"]), "invalid_action")
	assert_eq(String(s.blocked_reason()), "cutscene")


func test_dismiss_resumes_plot() -> void:
	var s := _at_laser()
	s.expedition.move("s1", "laser")
	var ev: Array[Dictionary] = s.expedition.dismiss_cutscene()
	assert_eq(String(ev[0]["type"]), "cutscene_dismissed")
	assert_true(s.expedition.st.pending_cutscene.is_empty())
	assert_eq(String(s.expedition.st.pending_choice["id"]), "laser_choice", "图播完，选择才轮到玩家")
	assert_eq(s.expedition.dismiss_cutscene().size(), 0, "重复关闭是空操作")


func test_cutscene_survives_save() -> void:
	var s := _at_laser()
	s.expedition.move("s1", "laser")
	var back := Session.new()
	assert_true(back.load_dict(s.to_dict()))
	assert_false(back.expedition.st.pending_cutscene.is_empty())
	assert_eq(String(back.expedition.st.pending_cutscene["name"]), "cg_laser")
	assert_eq(String(back.blocked_reason()), "cutscene")


func test_normal_move_has_no_cutscene() -> void:
	var s := _at_laser()
	s.expedition.move("s1", "hall")
	assert_true(s.expedition.st.pending_cutscene.is_empty())
