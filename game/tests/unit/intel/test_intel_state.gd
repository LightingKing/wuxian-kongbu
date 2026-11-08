extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const IntelState = preload("res://core/intel/intel_state.gd")

## 异形一（原著）：楚轩推出存在皇后。
const FACTS := {
	"queen_exists": {"statement": "存在异形皇后", "domain": "biology", "truth": true, "difficulty": 0.5, "clues": {"egg_count": 0.5, "hive_structure": 0.5}},
	"red_queen_bluffing": {"statement": "火焰女皇在虚张声势", "domain": "computers", "truth": false, "difficulty": 0.2, "clues": {"red_queen_talk": 0.6}},
}


func _intel() -> RefCounted:
	var s := IntelState.new()
	s.load_facts(FACTS)
	return s


func _thinker(id: String, intelligence: float) -> RefCounted:
	return Character.new(id, id, {"intelligence": intelligence})


func test_status_progression() -> void:
	var s := _intel()
	assert_eq(s.status("queen_exists"), "unknown")
	var events: Array[Dictionary] = s.add_clue("egg_count")
	assert_eq(events, [{"type": "clue_found", "clue": "egg_count"}, {"type": "fact_hinted", "fact": "queen_exists"}])
	assert_eq(s.status("queen_exists"), "hinted")
	assert_almost(s.clue_weight("queen_exists"), 0.5)
	s.deduce("queen_exists", _thinker("chu_xuan", 220.0), 0.0)
	assert_eq(s.status("queen_exists"), "inferred")
	s.confirm("queen_exists")
	assert_eq(s.status("queen_exists"), "confirmed")


func test_no_clue_no_deduction() -> void:
	var s := _intel()
	assert_eq(s.deduce("queen_exists", _thinker("c", 220.0), 0.0)["reason"], "no_clues")


## 准确度随智力、线索、领域熟悉度、天赋提高，随难度降低。
func test_accuracy_formula() -> void:
	var fact: Dictionary = FACTS["queen_exists"]
	var normal := _thinker("n", 100.0)
	assert_almost(IntelState.accuracy(normal, fact, 0.5), 0.3 + 0.2 - 0.15)
	var chu := _thinker("chu_xuan", 220.0)
	chu.flags["domains"] = {"biology": 1.0}
	chu.flags["talents"] = ["genius"]
	assert_almost(IntelState.accuracy(chu, fact, 0.25), 0.3 + 0.3 + 0.1 + 0.2 + 0.1 - 0.15)
	assert_almost(IntelState.accuracy(_thinker("x", 1000.0), fact, 1.0), 0.97)


## 推论可能出错：roll 落在准确度之外时得出相反的结论。
func test_wrong_conclusion() -> void:
	var s := _intel()
	s.add_clue("red_queen_talk")
	var ev: Dictionary = s.deduce("red_queen_bluffing", _thinker("zheng_zha", 100.0), 0.99)
	assert_true(bool(ev["conclusion"]))
	var confirm: Dictionary = s.confirm("red_queen_bluffing")
	assert_false(bool(confirm["truth"]))
	assert_false(bool(confirm["inference_was_right"]))


## 两个智者结论一致：可信度叠加；不一致：有争议，留可信度高的那个。
func test_cross_check() -> void:
	var s := _intel()
	s.add_clue("egg_count")
	s.add_clue("hive_structure")
	var a: Dictionary = s.deduce("queen_exists", _thinker("chu_xuan", 200.0), 0.0)
	var c1: float = a["confidence"]
	var b: Dictionary = s.deduce("queen_exists", _thinker("xiao_honglv", 200.0), 0.0)
	assert_almost(float(b["confidence"]), 1.0 - (1.0 - c1) * (1.0 - c1))
	assert_false(bool(b["contested"]))
	var t := _intel()
	t.add_clue("egg_count")
	t.deduce("queen_exists", _thinker("weak", 100.0), 0.99)
	var strong: Dictionary = t.deduce("queen_exists", _thinker("strong", 250.0), 0.0)
	assert_true(bool(strong["contested"]))
	assert_true(bool(strong["conclusion"]))


func test_round_trip() -> void:
	var s := _intel()
	s.add_clue("egg_count")
	s.deduce("queen_exists", _thinker("c", 200.0), 0.1)
	var copy := IntelState.new()
	copy.load_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	assert_eq(copy.to_dict(), s.to_dict())
