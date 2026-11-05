extends "res://tests/test_case.gd"

const PlotTickets = preload("res://core/economy/plot_tickets.gd")


func test_split_b_into_three_c() -> void:
	var t := PlotTickets.new()
	t.add("B")
	assert_true(t.split("B"))
	assert_eq(t.counts["B"], 0)
	assert_eq(t.counts["C"], 3)


func test_zheng_zha_first_split() -> void:
	# 原著 s01：郑吒把 B 级支线拆成 2 个 C + 3 个 D
	var t := PlotTickets.new()
	t.add("B")
	t.split("B")
	t.split("C")
	assert_eq(t.counts["C"], 2)
	assert_eq(t.counts["D"], 3)


func test_merge_three_b_into_a() -> void:
	# 原著 s05：詹岚的 A 级支线由三个 B 合成
	var t := PlotTickets.new()
	t.add("B", 3)
	assert_true(t.merge("B"))
	assert_eq(t.counts["A"], 1)
	assert_eq(t.counts["B"], 0)


func test_cannot_split_d_or_merge_s() -> void:
	var t := PlotTickets.new()
	t.add("D")
	t.add("S", 3)
	assert_false(t.split("D"))
	assert_false(t.merge("S"))
	assert_eq(t.counts["D"], 1)
	assert_eq(t.counts["S"], 3)


func test_spend_insufficient_changes_nothing() -> void:
	var t := PlotTickets.new()
	t.add("C", 1)
	assert_false(t.spend("C", 2))
	assert_eq(t.counts["C"], 1)
	assert_false(t.merge("C"))
	assert_eq(t.counts["C"], 1)
