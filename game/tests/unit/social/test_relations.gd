extends "res://tests/test_case.gd"

const Relations = preload("res://core/social/relations.gd")


func test_defaults() -> void:
	var r := Relations.new()
	assert_almost(r.value("a", "b", "trust"), 50.0)
	assert_almost(r.value("a", "b", "awe"), 20.0)
	assert_almost(r.value("a", "b", "resentment"), 0.0)
	assert_true(r.pairs.is_empty())


## 关系是单向的，并且限制在 0~100。
func test_directional_and_clamped() -> void:
	var r := Relations.new()
	r.change("a", "b", {"trust": 70})
	assert_almost(r.value("a", "b", "trust"), 100.0)
	assert_almost(r.value("b", "a", "trust"), 50.0)
	r.change("a", "b", {"resentment": -10})
	assert_almost(r.value("a", "b", "resentment"), 0.0)


## 救命：被救的人信任和好感上升，旁观者也会多一点信任和敬畏。
func test_saved_life() -> void:
	var r := Relations.new()
	var ev: Dictionary = r.apply_event("saved_life", "zheng_zha", "zhan_lan", ["zhang_jie"])
	assert_eq(ev["name"], "救命")
	assert_almost(r.value("zhan_lan", "zheng_zha", "trust"), 75.0)
	assert_almost(r.value("zhan_lan", "zheng_zha", "affection"), 65.0)
	assert_almost(r.value("zhang_jie", "zheng_zha", "trust"), 55.0)
	assert_almost(r.value("zhang_jie", "zheng_zha", "awe"), 25.0)


## 异形一：楚轩拿李帅西当诱饵（设计规格 9.8）。
func test_used_as_bait() -> void:
	var r := Relations.new()
	r.apply_event("used_as_bait", "chu_xuan", "li_shuaixi", ["zheng_zha", "chu_xuan"])
	assert_almost(r.value("li_shuaixi", "chu_xuan", "trust"), 20.0)
	assert_almost(r.value("li_shuaixi", "chu_xuan", "resentment"), 25.0)
	assert_almost(r.value("zheng_zha", "chu_xuan", "trust"), 40.0)
	assert_almost(r.value("chu_xuan", "chu_xuan", "trust"), 50.0)


func test_mutual_event() -> void:
	var r := Relations.new()
	r.apply_event("fought_together", "a", "b")
	assert_almost(r.value("a", "b", "trust"), 55.0)
	assert_almost(r.value("b", "a", "trust"), 55.0)


func test_tags_and_round_trip() -> void:
	var r := Relations.new()
	r.add_tag("zheng_zha", "luo_li", "creator")
	r.add_tag("zheng_zha", "luo_li", "creator")
	r.apply_event("lied_to", "chu_xuan", "zheng_zha")
	assert_true(r.has_tag("zheng_zha", "luo_li", "creator"))
	assert_eq((r.get_rel("zheng_zha", "luo_li")["tags"] as Array).size(), 1)
	var copy := Relations.new()
	copy.load_dict(JSON.parse_string(JSON.stringify(r.to_dict())))
	assert_eq(copy.to_dict(), r.to_dict())


## 一群人并肩作战：每两人之间互相 +5 信任、+3 好感；返回一条汇总事件。
func test_bond() -> void:
	var r := Relations.new()
	var ev: Dictionary = r.bond("fought_together", ["a", "b", "c"])
	assert_eq(ev, {"type": "bonded", "kind": "fought_together", "name": "并肩作战", "chars": ["a", "b", "c"]})
	for pair in [["a", "b"], ["b", "a"], ["a", "c"], ["c", "b"]]:
		assert_almost(r.value(pair[0], pair[1], "trust"), 55.0)
		assert_almost(r.value(pair[0], pair[1], "affection"), 53.0)
