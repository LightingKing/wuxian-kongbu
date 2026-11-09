extends "res://tests/test_case.gd"
## 存档槽：三个位、摘要、读回、删除、越界。

const Slots = preload("res://core/save/slots.gd")
const Session = preload("res://core/session/session.gd")


func before_each() -> void:
	for i in range(1, Slots.COUNT + 1):
		Slots.erase(i)


func _session() -> RefCounted:
	var s := Session.new()
	s.start_m1(1)
	return s


func test_write_and_summary() -> void:
	var s := _session()
	assert_eq(Slots.write(1, s), OK)
	var row := Slots.summary(1)
	assert_true(bool(row["exists"]))
	assert_eq(int(row["slot"]), 1)
	assert_eq(String(row["phase"]), "expedition")
	assert_eq(int(row["clock"]), 0)
	assert_true(String(row["label"]).contains("生化危机一"), "摘要写影片与时钟")
	assert_true(String(row["saved_at"]) != "", "摘要带保存时间")
	assert_eq(int(row["points"]), int(s.game.characters["zheng_zha"].points))


func test_read_round_trip() -> void:
	var s := _session()
	s.expedition.choose("listen")
	s.expedition.move("s1", "hall")
	Slots.write(2, s)
	var back := Slots.read(2)
	assert_true(back != null)
	assert_eq(String(back.phase), "expedition")
	assert_eq(int(back.expedition.st.clock), int(s.expedition.st.clock))
	assert_eq(back.expedition.st.squad_of("zheng_zha"), "s1")


func test_erase_makes_slot_empty() -> void:
	Slots.write(3, _session())
	assert_true(bool(Slots.summary(3)["exists"]))
	Slots.erase(3)
	assert_false(bool(Slots.summary(3)["exists"]))
	assert_eq(String(Slots.summary(3)["label"]), "空")


func test_invalid_slot() -> void:
	assert_eq(Slots.write(0, _session()), ERR_INVALID_PARAMETER)
	assert_eq(Slots.write(4, _session()), ERR_INVALID_PARAMETER)
	assert_true(Slots.read(9) == null)
	assert_false(bool(Slots.summary(9)["exists"]))
	Slots.erase(9)


func test_hub_label_and_points() -> void:
	var s := _session()
	s.expedition.st.outcome = "returned"
	s.settle()
	s.enter_hub()
	Slots.write(1, s)
	var row := Slots.summary(1)
	assert_eq(String(row["phase"]), "hub")
	assert_true(String(row["label"]).contains("主神空间"), String(row["label"]))


func test_all_summaries_cover_every_slot() -> void:
	Slots.write(2, _session())
	var rows: Array[Dictionary] = Slots.all_summaries()
	assert_eq(rows.size(), Slots.COUNT)
	assert_false(bool(rows[0]["exists"]))
	assert_true(bool(rows[1]["exists"]))
	assert_false(bool(rows[2]["exists"]))
