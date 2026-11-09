extends "res://tests/test_case.gd"
## 插图覆盖层：字幕、关闭信号、缺图时不崩。

const Cutscene = preload("res://ui/cutscene.gd")


func test_open_shows_caption_and_finishes() -> void:
	var c := Cutscene.new()
	c.build()
	var done: Array = []
	c.finished.connect(func() -> void: done.append(true))
	c.open_for("cg_laser", "激光网正在合拢")
	assert_eq(String(c.caption.text), "激光网正在合拢")
	assert_true(c.art.texture != null, "本机有激光通道 CG 时应加载")
	c.press_continue()
	assert_eq(done.size(), 1)
	c.free()


func test_missing_cg_is_tolerated() -> void:
	var c := Cutscene.new()
	c.build()
	c.open_for("no_such_cg", "")
	assert_true(c.art.texture == null)
	assert_eq(String(c.caption.text), "")
	c.free()
