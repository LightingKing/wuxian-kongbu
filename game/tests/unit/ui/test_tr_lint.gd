extends "res://tests/test_case.gd"
## 规则（AGENTS.md）：界面文字用中文，通过 tr() 包装，为以后的翻译留口。
## 这里只查最常见的写法：UiTheme.label / UiTheme.button 的第一个参数不能直接写字面字符串。


func test_ui_literals_wrapped_in_tr() -> void:
	var bad: Array[String] = []
	var re := RegEx.create_from_string("UiTheme\\.(label|button)\\(\"")
	for path in _scripts("res://ui"):
		var text := FileAccess.get_file_as_string(path)
		var line_no := 0
		for line in text.split("\n"):
			line_no += 1
			if re.search(line) != null:
				bad.append("%s:%d" % [path, line_no])
	assert_eq(bad.size(), 0, "没包 tr() 的界面文字：" + "、".join(bad))


func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(d)))
	return out
