extends "res://tests/test_case.gd"

const Talents = preload("res://core/model/talents.gd")
const Character = preload("res://core/model/character.gd")
const GameState = preload("res://core/model/game_state.gd")
const Campaign = preload("res://core/campaign/campaign.gd")
const Hub = preload("res://core/hub/hub.gd")

const CHAPTER := "res://data/scenarios/biohazard1/chapter.json"


## 测试用的假战斗：只需要 history、field.units、outcome 三样。
class FakeField extends RefCounted:
	var units: Array[RefCounted] = []


class FakeBattle extends RefCounted:
	var history: Array[Dictionary] = []
	var field := FakeField.new()
	var outcome := "victory"


func _types(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for e in events:
		out.append(String(e["type"]))
	return out


## 人物表写单个 flags.talent，旧数据写 flags.talents 数组，两种都认。
func test_ids_read_both_forms() -> void:
	var c := Character.new("a", "a", {})
	assert_eq(Talents.ids(c), [] as Array[String])
	c.flags["talent"] = "psychic"
	c.flags["talents"] = ["genius", "psychic"]
	assert_eq(Talents.ids(c), ["psychic", "genius"] as Array[String])
	assert_true(Talents.has(c, "genius"))
	assert_false(Talents.has(c, ""))


## 觉醒只发生一次：锻炼属性加上去（主神看不见）、恐惧下降；死人不觉醒。
func test_trigger_awakens_once() -> void:
	var c := Character.new("zheng_zha", "郑吒", {})
	c.flags["talent"] = "iron_will"
	c.fear = 50.0
	var events: Array[Dictionary] = []
	assert_eq(Talents.trigger(c, "flag:whatever", events), [] as Array[String])
	assert_eq(Talents.trigger(c, "ally_died", events), ["iron_will"] as Array[String])
	assert_eq(_types(events), ["talent_awakened"] as Array[String])
	assert_eq(String(events[0]["name"]), "不屈")
	assert_almost(c.attributes.total("spirit"), 115.0)
	assert_almost(float(c.attributes.enhanced["spirit"]), 0.0, 0.0001, "锻炼不进兑换属性，主神看不见")
	assert_almost(c.fear, 20.0)
	assert_true(Talents.is_awake(c, "iron_will"))
	assert_eq(Talents.awake_names(c), ["不屈"] as Array[String])
	assert_eq(Talents.trigger(c, "near_death", events), [] as Array[String])
	assert_eq(events.size(), 1)
	var dead := Character.new("x", "x", {})
	dead.flags["talent"] = "iron_will"
	dead.alive = false
	assert_eq(Talents.trigger(dead, "ally_died", events), [] as Array[String])


## 学得快：觉醒前训练倍率 1，觉醒后 2。
func test_train_mult() -> void:
	var c := Character.new("li_xiao_yi", "李萧毅", {})
	c.flags["talent"] = "quick_learner"
	assert_almost(Talents.train_mult(c), 1.0)
	var events: Array[Dictionary] = []
	Talents.trigger(c, "trained", events)
	assert_almost(Talents.train_mult(c), 2.0)


## 远征：四个人当场死掉 → 郑吒看着同伴倒下（不屈）；活着的只剩三个（≤ 七人的一半）→ 张杰、詹岚觉醒。
## 觉醒都记进主神议程（潜力突升，不够复制进恶魔小队）。
func test_deaths_awaken_in_expedition() -> void:
	var g := GameState.new(1)
	var ex := Campaign.start(g, CHAPTER)
	ex.choose("listen")
	var events: Array[Dictionary] = ex.apply_effects([{"damage": {"amount": 999, "recipients": ["li_xiao_yi", "mu_gang", "xiao_pang_zi", "zhong_nian_fu_nv"], "reason": "test"}}], "car")
	var woke := {}
	for e in events:
		if e["type"] == "talent_awakened":
			woke[String(e["char"])] = String(e["talent"])
	assert_eq(woke, {"zheng_zha": "iron_will", "zhang_jie": "half_guide", "zhan_lan": "psychic"})
	assert_almost(g.characters["zhan_lan"].attributes.total("spirit"), 190.0)
	assert_almost(float(g.agenda.potentials["zhan_lan"]), 0.1)
	assert_eq(g.agenda.demon_copies, [])


## 战后濒死：活着但生命不到四分之一的人触发 near_death（郑吒的不屈）。
func test_near_death_after_battle() -> void:
	var g := GameState.new(1)
	var ex := Campaign.start(g, CHAPTER)
	ex.st.pending_battle = {"location": "car", "squad": "s1", "enemies": [{"def": "zombie", "count": 1}], "dark": false, "survive_until": -1.0, "after_victory": [], "after_defeat": []}
	var units: Array[RefCounted] = ex.battle_units({})
	for u in units:
		if u.side == "ally" and u.character_id == "zheng_zha":
			u.hp = 5.0
	var b := FakeBattle.new()
	b.field.units = units
	var events: Array[Dictionary] = ex.report_battle(b)
	assert_true(_types(events).has("talent_awakened"))
	assert_true(Talents.is_awake(g.characters["zheng_zha"], "iron_will"))
	assert_false(Talents.is_awake(g.characters["zhang_jie"], "half_guide"))


## 休整：詹岚兑换精神力 → 精神力天赋觉醒（+40）；李萧毅训练一次觉醒"学得快"，之后训练熟练度翻倍。
func test_hub_triggers() -> void:
	var g := GameState.new(1)
	Campaign.start(g, CHAPTER)
	var zl: RefCounted = g.characters["zhan_lan"]
	zl.points = 1000
	var hub := Hub.new()
	hub.start(g, 9)
	hub.day = 1
	var events: Array[Dictionary] = hub.buy_attribute("zhan_lan", "spirit", 10)
	assert_eq(_types(events), ["attribute_bought", "talent_awakened"] as Array[String])
	assert_almost(zl.attributes.total("spirit"), 200.0)
	var li: RefCounted = g.characters["li_xiao_yi"]
	li.proficiency["punch"] = 0.2
	events = hub.train("li_xiao_yi", "punch", 1)
	assert_eq(_types(events), ["trained", "talent_awakened", "day_passed"] as Array[String])
	var after_first := float(li.proficiency["punch"])
	hub.train("li_xiao_yi", "punch", 1)
	var per_day := after_first - 0.2
	assert_almost(float(li.proficiency["punch"]) - after_first, minf(per_day * 2.0, 1.0 - after_first))
