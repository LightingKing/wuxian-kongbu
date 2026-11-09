extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const GameState = preload("res://core/model/game_state.gd")
const Agenda = preload("res://core/director/agenda.gd")


func _game() -> RefCounted:
	var g := GameState.new(1)
	for id in ["zheng_zha", "zhang_jie", "zhan_lan"]:
		g.add_character(Character.new(id, id, {}))
	return g


func test_stages_advance_with_reasons() -> void:
	var a := Agenda.new()
	assert_eq(a.stage, "guide")
	assert_true(a.advance_stage("biohazard1", "引导者带新人入门"))
	assert_eq(a.stage, "captain")
	assert_eq(a.decisions[0], {"film": "biohazard1", "kind": "advance_stage", "payload": {"stage": "captain"}, "reason": "引导者带新人入门"})
	for i in 10:
		a.advance_stage("x", "")
	assert_eq(a.stage, "finale")
	assert_false(a.advance_stage("x", ""))


## 原著：张杰的"半引导者"异常让主神刻意加难（L5595）；考验完成后异常解除。
func test_anomaly_lifecycle() -> void:
	var a := Agenda.new()
	var id: String = a.add_anomaly("half_guide", "biohazard1", "张杰既像引导者又不肯考验", "异常：加难逼它表态")
	assert_eq(id, "anomaly_1")
	assert_eq(a.open_anomalies().size(), 1)
	a.set_ultimatum("captain_trial", "final_destination2", "只留一个出口", "the_grudge", "最后通牒")
	assert_eq(a.ultimatum["kind"], "captain_trial")
	assert_true(a.resolve_anomaly(id, "final_destination2", "考验完成"))
	assert_false(a.resolve_anomaly(id, "x", ""))
	assert_eq(a.open_anomalies().size(), 0)


## 异常记在谁身上：同种异常按人区分，解除后查不到。
func test_open_anomaly_by_char() -> void:
	var a := Agenda.new()
	var id: String = a.add_anomaly("half_guide", "biohazard1", "半引导者", "加难", "zhang_jie")
	assert_eq(String(a.anomalies[0]["char"]), "zhang_jie")
	assert_eq(a.decisions[0]["payload"], {"id": id, "kind": "half_guide", "char": "zhang_jie"})
	assert_eq(a.open_anomaly("half_guide", "zhang_jie"), id)
	assert_eq(a.open_anomaly("half_guide", "zheng_zha"), "")
	a.resolve_anomaly(id, "final_destination2", "考验完成")
	assert_eq(a.open_anomaly("half_guide", "zhang_jie"), "")


## 潜力突升够大，主神考虑复制进恶魔小队。
func test_potential_spike() -> void:
	var a := Agenda.new()
	assert_false(a.potential_spike("zheng_zha", 0.1, "alien1", "首次觉醒"))
	assert_true(a.potential_spike("zheng_zha", 0.3, "alien1", "造人"))
	a.copy_to_demon_team("zheng_zha", "alien1", "对照实验")
	assert_false(a.potential_spike("zheng_zha", 0.5, "x", ""))
	assert_almost(float(a.potentials["zheng_zha"]), 0.9)
	assert_eq(a.demon_copies, ["zheng_zha"])


## 评价：活过一部本该团灭的片、损失小 → +1；队长死 → −1；所有人都死过 → 清零、记录消失。
func test_update_rating() -> void:
	var g := _game()
	g.films_record = ["biohazard1", "alien1"]
	var r := Agenda.update_rating(g, {"expected_wipe": true, "members": 10, "survivors": 8})
	assert_eq(r, {"before": 0, "after": 1, "reasons": ["survived_wipe"] as Array[String]})
	r = Agenda.update_rating(g, {"expected_wipe": true, "members": 10, "survivors": 5})
	assert_eq(int(r["after"]), 1)
	r = Agenda.update_rating(g, {"captain_died": true, "members": 10, "survivors": 9})
	assert_eq(int(r["after"]), 0)
	r = Agenda.update_rating(g, {"captain_died": true, "members": 10, "survivors": 9})
	assert_eq(int(r["after"]), 0)
	g.team_rating = 3
	r = Agenda.update_rating(g, {"all_died": true, "members": 10, "survivors": 1})
	assert_eq(g.team_rating, 0)
	assert_eq(g.films_record, [])


## 评价战力：新人队伍 120；兑换让它上升；锻炼和基因锁主神看不见。
func test_rating_power() -> void:
	var g := _game()
	var team := ["zheng_zha", "zhang_jie", "zhan_lan"]
	assert_almost(Agenda.rating_power(g, team), 120.0)
	g.characters["zheng_zha"].attributes.add_trained("muscle", 300.0)
	g.characters["zheng_zha"].gene_lock_stage = 2
	assert_almost(Agenda.rating_power(g, team), 120.0)
	g.characters["zheng_zha"].attributes.add_enhanced_high("muscle", 180.0)
	assert_almost(Agenda.rating_power(g, team), 120.0 * (100.0 + 10.0) / 100.0)
	g.team_rating = 2
	assert_almost(Agenda.rating_power(g, team), 240.0 * 1.1)
	g.characters["zheng_zha"].alive = false
	assert_almost(Agenda.rating_power(g, team), 240.0)


func test_round_trip() -> void:
	var a := Agenda.new()
	a.advance_stage("biohazard1", "r")
	a.add_anomaly("half_guide", "biohazard1", "n", "r")
	a.potential_spike("zheng_zha", 0.3, "alien1", "r")
	var copy := Agenda.new()
	copy.load_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	assert_eq(copy.to_dict(), a.to_dict())
