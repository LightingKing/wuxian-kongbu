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


## 固定话题变成按钮：没聊过的带"•"，聊过的打"✓"；点一下发 topic_picked；没有话题时标题藏起来；重新打开会清空。
func test_topics_become_buttons() -> void:
	var p := _panel()
	assert_false(p.topic_title.visible, "没有话题时不显示")
	p.set_topics([{"id": "kaplan_door", "label": "你在忙什么？", "seen": true}, {"id": "kaplan_queen", "label": "主电脑是什么？", "seen": false}])
	assert_true(p.topic_title.visible)
	assert_eq(p.topic_count(), 2)
	assert_eq(String((p.topic_box.get_child(0) as Button).text), "✓ 你在忙什么？")
	assert_eq(String((p.topic_box.get_child(1) as Button).text), "• 主电脑是什么？")
	var picked: Array = []
	p.topic_picked.connect(func(t: String) -> void: picked.append(t))
	p.press_topic(1)
	p.press_topic(5)
	assert_eq(picked, ["kaplan_queen"])
	assert_eq(String(p.topic_title.text), "可以问的：")
	p.open_for("马修", "列车", "talk")
	assert_eq(p.topic_count(), 0, "换个人说话，旧话题清掉")
	p.set_topics([{"id": "matthew_look", "label": "看看他", "observe": true, "seen": false}])
	assert_eq(String(p.topic_title.text), "可以做的：", "只能看看的时候不叫'问'")
	_drop(p)


## 对方听不见（列车上的剧情人物）：输入框和"说"按钮关掉，硬发也发不出去；重新打开恢复。
func test_free_text_can_be_disabled() -> void:
	var p := _panel()
	var sent: Array = []
	p.submitted.connect(func(t: String) -> void: sent.append(t))
	p.set_free_text(false)
	assert_false(p.input.editable)
	assert_true(p.send_button.disabled)
	p.press_send("你听得见吗")
	assert_eq(sent.size(), 0)
	p.set_free_text(true)
	assert_true(p.input.editable)
	assert_eq(String(p.input.placeholder_text), "说点什么……")
	p.press_send("现在呢")
	assert_eq(sent.size(), 1)
	_drop(p)


func test_close_hides_and_signals() -> void:
	var p := _panel()
	var closed: Array = []
	p.closed.connect(func() -> void: closed.append(true))
	p.press_close()
	assert_eq(closed.size(), 1)
	assert_false(p.visible)
	_drop(p)
