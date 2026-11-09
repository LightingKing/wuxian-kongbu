extends "res://tests/test_case.gd"

const Catalog = preload("res://core/hub/catalog.gd")
const Exchange = preload("res://core/hub/exchange.gd")
const BattleData = preload("res://core/battle/battle_data.gd")
const Battle = preload("res://core/battle/battle.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
const Character = preload("res://core/model/character.gd")
const GameState = preload("res://core/model/game_state.gd")
const Campaign = preload("res://core/campaign/campaign.gd")
const Rng = preload("res://core/util/rng.gd")

const CHAPTER := "res://data/scenarios/biohazard1/chapter.json"


## 规格 7.2：M1 约 200 条，覆盖 D~B 的各个系列。
func test_m1_scale() -> void:
	assert_eq(Catalog.entries().size(), 200)
	var series := {}
	var tiers := {}
	for id: String in Catalog.entries():
		var e: Dictionary = Catalog.entry(id)
		series[String(e["series"])] = true
		tiers[String(e["price"]["tier"])] = true
	assert_true(series.size() >= 50, "系列数 %d" % series.size())
	for t in ["", "D", "C", "B", "2B"]:
		assert_true(tiers.has(t), "缺 %s 档" % t)
	for c in ["enhance", "tech", "magic", "item"]:
		assert_true(Catalog.by_category(c).size() >= 20, c)


## 带着消耗品就有对应的技能；带得不够（火箭弹 0 发）就没有。
func test_item_skills() -> void:
	var got := BattleData.item_skills({"grenade": 2, "spray": 1, "rocket": 0})
	assert_true(got.has("grenade"))
	assert_true(got.has("first_aid_spray"))
	assert_false(got.has("antidote"))
	assert_false(got.has("rocket_shot"))
	assert_eq(BattleData.item_skills({}), [] as Array[String])


## 原著锚点条目现在真能上场：低级气功给气功掌，价格还是 500 + D。
func test_anchor_items_grant_battle_skills() -> void:
	var c := Character.new("a", "a", {})
	c.points = 99999
	c.tickets.add("D", 3)
	assert_eq(int(Catalog.entry("qigong_low")["price"]["points"]), 500)
	assert_eq(String(Catalog.entry("qigong_low")["price"]["tier"]), "D")
	Exchange.buy(c, "qigong_low", Rng.new(1))
	assert_true(c.skills.has("qigong_palm"))
	assert_almost(float(c.energy["neili"]), 30.0)


## 远征里：郑吒带着手榴弹和医疗包，战斗单位自动多出这两个技能；分队共用的道具给第一个人。
func test_carried_items_in_battle() -> void:
	var g := GameState.new(1)
	var ex := Campaign.start(g, CHAPTER)
	ex.choose("listen")
	g.characters["zheng_zha"].items["grenade"] = 2.0
	g.characters["zheng_zha"].items["medkit"] = 1.0
	ex.st.squads["s1"]["items"]["flashbang"] = 1.0
	ex.st.pending_battle = {"location": "car", "squad": "s1", "enemies": [{"def": "zombie", "count": 1}], "dark": false, "survive_until": -1.0, "after_victory": [], "after_defeat": []}
	for u: RefCounted in ex.battle_units({}):
		if u.side != "ally":
			continue
		if u.character_id == "zheng_zha":
			assert_true(u.skills.has("grenade"))
			assert_true(u.skills.has("medkit"))
			assert_true(u.skills.has("flashbang"), "第一个人背着分队共用的闪光弹")
		elif u.character_id == "zhang_jie":
			assert_false(u.skills.has("grenade"))


## 目录里给的每一个技能都能在真实战斗里放出来：选得出合法目标、执行不出错。
func test_every_catalog_skill_usable() -> void:
	var skills := {}
	for id: String in Catalog.entries():
		for b: Dictionary in Catalog.entry(id)["blocks"]:
			if b.has("skill"):
				skills[String(b["skill"])] = true
	assert_true(skills.size() >= 80, "技能数 %d" % skills.size())
	for s: String in skills:
		_try_skill(s)


func _try_skill(skill_id: String) -> void:
	var def := BattleData.skill(skill_id)
	var res := {"neili": 300.0, "blood": 300.0, "mana": 300.0, "ammo": 50.0}
	for k: String in def.get("cost", {}):
		res[k] = maxf(float(res.get(k, 0.0)), 5.0)
	var hero := Character.new("hero", "英雄", {})
	hero.hp = 999.0
	var row := int((def["user_rows"] as Array)[0])
	var units: Array[RefCounted] = [
		UnitFactory.from_character(hero, "ally", row, [skill_id], "player", res),
		UnitFactory.from_enemy("zombie", "zombie_1", 0),
		UnitFactory.from_enemy("zombie", "zombie_2", 0),
	]
	var b := Battle.new()
	b.setup(units, {}, Rng.new(7))
	var picked: Dictionary = {}
	for a: Dictionary in b.legal_actions():
		if String(a.get("skill", "")) == skill_id:
			picked = a
			break
	assert_false(picked.is_empty(), "%s 选不出合法目标" % skill_id)
	if picked.is_empty():
		return
	var before := b.history.size()
	b.act(picked)
	assert_true(b.history.size() > before, "%s 放出去没有任何事件" % skill_id)
