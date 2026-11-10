extends RefCounted
## 所有单元测试的基类。测试方法以 test_ 开头；断言失败只记录，不中断。

var _failures: Array[String] = []
var _assert_count := 0


func assert_true(cond: bool, msg: String = "") -> void:
	_assert_count += 1
	if not cond:
		_failures.append("assert_true 失败 %s" % msg)


func assert_false(cond: bool, msg: String = "") -> void:
	assert_true(not cond, msg)


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	_assert_count += 1
	var both_numbers := _is_number(actual) and _is_number(expected)
	if typeof(actual) != typeof(expected) and not both_numbers:
		_failures.append("assert_eq 类型不同：期望 %s，实际 %s %s" % [var_to_str(expected), var_to_str(actual), msg])
		return
	if actual != expected:
		_failures.append("assert_eq：期望 %s，实际 %s %s" % [var_to_str(expected), var_to_str(actual), msg])


func assert_almost(actual: float, expected: float, eps: float = 0.0001, msg: String = "") -> void:
	_assert_count += 1
	if absf(actual - expected) > eps:
		_failures.append("assert_almost：期望 %f，实际 %f %s" % [expected, actual, msg])


func take_failures() -> Array[String]:
	var out := _failures.duplicate()
	_failures.clear()
	return out


## 场景树（runner 已经等过一帧，root 在树里）：要测镜头、打字这类需要节点在树里的东西时用。
func tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


func take_assert_count() -> int:
	var n := _assert_count
	_assert_count = 0
	return n


func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT
