extends SceneTree
## 无界面测试入口：godot --headless --path game -s res://tests/run_tests.gd
## 环境变量 TEST_FILTER 可只跑路径里包含该字符串的测试文件。
## 先等一帧再跑（计划 22）：这时场景树已经建好，测试可以把场景放进 root、等帧、等信号
## （测试方法里可以 await；runner 会等它跑完）。失败判定：统计失败数决定退出码；
## 运行时错误会让一个测试半途中止，所以 run_tests.sh 还会检查输出里的 SCRIPT ERROR。

const ROOT := "res://tests/unit"


func _initialize() -> void:
	await process_frame
	var code: int = await _run_all()
	quit(code)


func _run_all() -> int:
	var files := _collect(ROOT)
	files.sort()
	var filter := OS.get_environment("TEST_FILTER")
	var total := 0
	var failed := 0
	for path in files:
		if filter != "" and not path.contains(filter):
			continue
		var script: Variant = load(path)
		if script == null or not script.can_instantiate():
			total += 1
			failed += 1
			print("FAIL  %s（脚本无法加载）" % path)
			continue
		var inst: Variant = script.new()
		for m in inst.get_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			total += 1
			if inst.has_method("before_each"):
				inst.call("before_each")
			await inst.call(name)
			var fails: Array[String] = inst.take_failures()
			var asserts: int = inst.take_assert_count()
			if asserts == 0:
				fails.append("没有任何断言")
			if fails.is_empty():
				print("ok    %s::%s" % [path.get_file(), name])
			else:
				failed += 1
				print("FAIL  %s::%s" % [path.get_file(), name])
				for f in fails:
					print("        " + f)
	print("\n共 %d 个测试，失败 %d 个" % [total, failed])
	return 1 if failed > 0 else 0


func _collect(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	for f in d.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for sub in d.get_directories():
		out.append_array(_collect(dir_path.path_join(sub)))
	return out
