extends "res://tests/test_case.gd"
## 对话框控件：追加台词、候选回复、说话/说服两种提交、关闭。

const DialoguePanel = preload("res://ui/dialogue/dialogue_panel.gd")


func _panel() -> Control:
	var p := DialoguePanel.new()
	p.build()
	p.open_for("卡普兰", "第 40 分钟 · 蜂巢入口大厅", "talk")
	return p


## 控件不进树也不会自动释放，测完自己收。
func _drop(p: Control) -> void:
	p.free()


func test_push_shows_speaker_and_text() -> void:
	var p := _panel()
	p.push("卡普兰", "别碰那扇门。[警告]")
	assert_true(p.log_label.text.contains("卡普兰"))
	assert_true(p.log_label.text.contains("别碰那扇门"))
	assert_true(p.log_label.text.contains("［警告］"), "方括号被转义，不会当成 BBCode")
	p.push("我", "为什么")
	assert_true(p.log_label.text.contains("为什么"))
	assert_eq(p._lines.size(), 2)
	_drop(p)


func test_replies_become_buttons() -> void:
	var p := _panel()
	p.set_replies(["为什么", "我偏要碰", "……"])
	assert_eq(p.reply_box.get_child_count(), 3)
	var picked: Array = []
	var sent: Array = []
	p.reply_picked.connect(func(t: String) -> void: picked.append(t))
	p.submitted.connect(func(t: String) -> void: sent.append(t))
	p.press_reply(1)
	assert_eq(picked.size(), 1)
	assert_eq(String(picked[0]), "我偏要碰")
	assert_eq(sent.size(), 1, "点了候选就等于说出口")
	p.set_replies(["a"])
	assert_eq(p.reply_box.get_child_count(), 1, "换一批会清掉旧的")
	_drop(p)


func test_send_emits_submitted() -> void:
	var p := _panel()
	var sent: Array = []
	p.submitted.connect(func(t: String) -> void: sent.append(t))
	p.input.text = "你们到底是什么人"
	p.press_send()
	assert_eq(sent.size(), 1)
	assert_eq(String(sent[0]), "你们到底是什么人")
	assert_eq(String(p.input.text), "", "发出后清空输入框")
	_drop(p)


func test_empty_input_does_nothing() -> void:
	var p := _panel()
	var sent: Array = []
	p.submitted.connect(func(t: String) -> void: sent.append(t))
	p.press_send("   ")
	assert_eq(sent.size(), 0)
	_drop(p)


func test_persuade_mode_uses_other_signal() -> void:
	var p := _panel()
	var talked: Array = []
	var argued: Array = []
	p.submitted.connect(func(t: String) -> void: talked.append(t))
	p.persuading.connect(func(t: String) -> void: argued.append(t))
	p.set_mode("persuade")
	assert_eq(String(p.send_button.text), "说服")
	p.press_send("断电，否则激光")
	assert_eq(talked.size(), 0)
	assert_eq(argued.size(), 1)
	_drop(p)


func test_close_hides_and_signals() -> void:
	var p := _panel()
	var closed: Array = []
	p.closed.connect(func() -> void: closed.append(true))
	p.press_close()
	assert_eq(closed.size(), 1)
	assert_false(p.visible)
	_drop(p)
