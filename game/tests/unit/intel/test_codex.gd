extends "res://tests/test_case.gd"

const Codex = preload("res://core/intel/codex.gd")
const Character = preload("res://core/model/character.gd")
const GameState = preload("res://core/model/game_state.gd")


## 同一条只解锁一次；不认识的 id 跳过；全都知道了返回空数组。
func test_unlock_once() -> void:
	var c := Codex.new()
	var events: Array[Dictionary] = c.unlock(["survive_points", "nope", "go_home"], "zhang_jie")
	assert_eq(events, [{"type": "codex_unlocked", "entries": ["survive_points", "go_home"] as Array[String], "source": "zhang_jie"}] as Array[Dictionary])
	assert_eq(c.unlock(["go_home"], "zhushen"), [] as Array[Dictionary])
	assert_eq(String(c.known["go_home"]["source"]), "zhang_jie", "第一次告诉你的人不变")
	assert_true(c.is_known("survive_points"))
	assert_false(c.is_known("tether"))


## 回归当晚的导览：hub_tour 组整组解锁。
func test_unlock_group() -> void:
	var c := Codex.new()
	var events: Array[Dictionary] = c.unlock_group("hub_tour", "zhang_jie")
	var ids: Array = events[0]["entries"]
	assert_true(ids.has("exchange"))
	assert_true(ids.has("human_creation"))
	assert_false(ids.has("tether"))
	for id: String in ids:
		assert_eq(String(Codex.entry(id)["group"]), "hub_tour")


## 问主神：问题里带关键词就解锁对应条目；问剧情、问不相干的不解锁。
func test_unlock_by_question() -> void:
	var c := Codex.new()
	var events: Array[Dictionary] = c.unlock_by_question("支线能拆分吗？")
	var ids: Array = events[0]["entries"]
	assert_true(ids.has("ticket_split"))
	assert_true(ids.has("side_plots"))
	assert_eq(String(c.known["ticket_split"]["source"]), "zhushen")
	assert_eq(c.unlock_by_question("下一部是什么片？"), [] as Array[Dictionary])


## 百科：公开规则按解锁顺序，后面接智者发现的隐藏规则；还有多少条没听说过。
func test_entries_and_hidden_rules() -> void:
	var g := GameState.new(1)
	var zl := Character.new("zhan_lan", "詹岚", {"intelligence": 190})
	g.add_character(zl)
	g.flags["seen_human_creation"] = true
	var c: RefCounted = g.codex
	c.unlock(["watch_tasks", "survive_points"], "zhang_jie")
	var found: Array[Dictionary] = c.discovery.discover_all([zl], g)
	assert_eq(String(found[0]["rule"]), "bodyguard_human")
	var list: Array[Dictionary] = c.entries()
	assert_eq(list.size(), 3)
	assert_eq(String(list[0]["id"]), "watch_tasks")
	assert_false(bool(list[0]["hidden"]))
	assert_eq(String(list[2]["id"]), "bodyguard_human")
	assert_true(bool(list[2]["hidden"]))
	assert_eq(String(list[2]["source"]), "zhan_lan")
	assert_eq(c.locked_count(), Codex.data().size() - 2)


## 存读档：已知条目、顺序、发现的隐藏规则都保留；旧存档没有 codex 字段时是空百科。
func test_round_trip() -> void:
	var g := GameState.new(1)
	g.codex.unlock(["gag", "tether"], "zhang_jie")
	g.codex.discovery.discovered["always_a_way"] = {"by": "zhan_lan"}
	var d: Dictionary = g.to_dict()
	var h := GameState.new()
	h.load_dict(d)
	assert_eq(h.codex.to_dict(), g.codex.to_dict())
	assert_eq(h.codex.order, ["gag", "tether"])
	d.erase("codex")
	var old := GameState.new()
	old.load_dict(d)
	assert_eq(old.codex.entries(), [] as Array[Dictionary])
