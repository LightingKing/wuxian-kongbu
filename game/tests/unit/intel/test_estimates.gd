extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const Estimates = preload("res://core/intel/estimates.gd")


## 没有智者：看不到成功率。
func test_hidden_without_thinker() -> void:
	assert_eq(Estimates.estimate(0.3, 120.0, 0.5), {"shown": false})


## 楚轩口吻："约在三成左右"。
func test_tenths_for_moderate_intelligence() -> void:
	var e := Estimates.estimate(0.3, 180.0, 0.5)
	assert_eq(e["text"], "约三成")
	assert_almost(float(e["estimate"]), 0.3)


func test_noise_shrinks_with_intelligence() -> void:
	var low := Estimates.estimate(0.5, 150.0, 1.0)
	var high := Estimates.estimate(0.5, 260.0, 1.0)
	assert_almost(float(low["estimate"]), 0.7)
	assert_almost(float(high["estimate"]), 0.52)
	assert_eq(high["text"], "约 52%")
	assert_eq(Estimates.estimate(0.5, 220.0, 0.5)["text"], "约 50%")


func test_clamped() -> void:
	assert_almost(float(Estimates.estimate(0.98, 150.0, 1.0)["estimate"]), 1.0)
	assert_eq(Estimates.estimate(0.98, 150.0, 1.0)["text"], "约十成")


func test_best_thinker() -> void:
	var a := Character.new("a", "a", {"intelligence": 120})
	var b := Character.new("b", "b", {"intelligence": 220})
	var c := Character.new("c", "c", {"intelligence": 300})
	c.alive = false
	assert_eq(Estimates.best_thinker([a, b, c]), b)
	assert_eq(Estimates.best_thinker([]), null)
