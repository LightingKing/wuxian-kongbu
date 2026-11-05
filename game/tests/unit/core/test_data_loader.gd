extends "res://tests/test_case.gd"

const DataLoader = preload("res://core/util/data_loader.gd")
const Rules = preload("res://core/util/rules.gd")


func test_missing_file_reports_error() -> void:
	var res := DataLoader.load_json("res://data/nope.json")
	assert_false(res.ok)
	assert_true(res.error.contains("不存在"))


func test_core_rules_load() -> void:
	var res := DataLoader.load_json(Rules.PATH)
	assert_true(res.ok, res.error)
	var errs := DataLoader.missing_keys(res.data, ["attributes", "settlement", "plot_tickets", "kill_reward"], "core_rules")
	assert_eq(errs.size(), 0, str(errs))


func test_rules_values() -> void:
	assert_eq(int(Rules.get_value("settlement", "survival")), 1000)
	assert_eq(int(Rules.get_value("plot_tickets", "ratio")), 3)
