extends SceneTree
## M1 可玩切片的无头验收：加载主场景，按真实界面路径走一遍
## 标题 → 新游戏 → 听规则 → 大厅 → 楼梯井（扶人）→ 激光通道（救马修）
## → 主机房（跟詹岚搭话）→ 推理 → 丧尸战 → 留守 → 自由说辞逼火焰女皇 → 断电
## → 撑到回归 → 结算 → 主神空间（问主神）→ 暂停菜单存槽 → 回标题 → 从槽读回来。
## 用法：godot --headless --path game -s res://tools/verify_m1_slice.gd
## 加 --capture（不带 --headless）可以截一张结算后的图到 art_src/qa/。
## 它要用存档槽和自动档，所以开始时把已有的存档挪到 user://verify_backup_<槽>.json，结束时原样放回；
## 上次中途崩了留下的备份，开头会先放回去再备份，不会被覆盖。

const Slots = preload("res://core/save/slots.gd")
const PortraitSource = preload("res://ui/art/portrait_source.gd")

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


const BACKUP := "user://verify_backup_%d.json"


func _run() -> void:
	# 先把玩家的存档挪开，截图和断言才干净；_finish 再放回去。
	_restore_slots()
	_stash_slots()
	root.size = Vector2i(1920, 1080)
	var packed := load("res://ui/main.tscn") as PackedScene
	_expect(packed != null, "主场景可以加载")
	if packed == null:
		_finish()
		return
	var main: Control = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var title: Control = main.content.get_child(0)
	_expect(title.has_method("press_new"), "启动进标题画面")
	_expect((title.slot_rows() as Array).size() == 3, "标题画面列出三个存档槽")
	await _shot("m1_title.png")
	title.press_new()
	_expect(title.mode_panel.visible, "新游戏先选存档方式")
	title.press_mode(false)
	await process_frame
	_expect(not main.session.iron_man, "选了宽松模式")
	var screen: Control = main.content.get_child(0)
	_expect(screen.has_method("press_choice"), "新游戏进入地点图")
	_expect(String(main.session.phase) == "expedition", "开局在远征阶段")
	_expect(int(main.session.game.characters.size()) == 7, "七名轮回者")

	_expect(screen.press_choice("listen"), "开场选择：听规则")
	_expect(screen.press_move("hall"), "走到大厅")
	await process_frame
	await process_frame
	_expect(bool(Slots.summary(Slots.AUTO)["exists"]), "换地点后自动存档落盘")
	_expect(String(Slots.summary(Slots.AUTO)["label"]).contains("生化危机一"), "自动档摘要写着片名")

	# 禁言：当着剧情人物（马修）提"主神"，当场扣 10 点。
	_expect(screen.press_talk("matthew"), "在大厅跟马修搭话")
	var gag_panel: Control = main.panel
	if gag_panel != null:
		var before := _penalty_count(main)
		gag_panel.press_send("主神到底想让我们干什么")
		_expect(_penalty_count(main) == before + 1, "当着马修提主神被记一次泄密")
		_expect(gag_panel.log_label.text.contains("说漏了嘴"), "对话框里当场提示")
		gag_panel.press_close()
		await process_frame

	_expect(screen.press_move("stairs"), "走到楼梯井")
	_expect(screen.press_choice("help"), "扶掉队的新人")
	_expect(screen.press_move("laser"), "走进激光通道")
	await process_frame
	await process_frame
	var cs: Control = main.get_node_or_null("Cutscene")
	_expect(cs != null, "走进激光通道弹出剧情 CG")
	if cs != null:
		_expect(cs.art.texture != null, "CG 图已加载")
		_expect(String(cs.caption.text).contains("激光网"), "CG 带字幕")
		await create_timer(0.45).timeout
		await _shot("m1_cutscene.png")
		cs.press_continue()
		await process_frame
	_expect(main.session.expedition.st.pending_cutscene.is_empty(), "插图播完自动继续")

	# 说服马修：先过检定，才轮到救人选择。
	var pend: Dictionary = screen.view.pending()
	_expect(String(pend.get("kind", "")) == "check", "插图之后先等说服马修")
	_expect(String(pend.get("id", "")) == "convince_matthew", "检定是说服马修")
	_expect(screen.press_choice("save_matthew") == false or not main.session.expedition.st.pending_check.is_empty(), "没过说服不能直接选")
	screen.select_keywords(["最后", "盯着", "激光"])
	await _shot("m1_persuade_matthew.png")
	_expect(screen.press_persuade_keywords(), "用关键词说服马修")
	await process_frame
	_expect(main.session.expedition.st.pending_check.is_empty(), "说服结算后清空")
	_expect(screen.press_choice("save_matthew"), "拖着马修贴门")
	_expect(screen.press_move("control"), "进入主机房")
	_expect(int(main.session.expedition.st.clock) == 45, "第 45 分钟到达主机房")
	_expect(main.session.expedition.st.tether.is_empty(), "救下马修后绑定解除")

	_expect(screen.has_method("press_talk"), "界面支持搭话")
	_expect(screen.press_talk("zhan_lan"), "跟同队的詹岚搭话")
	var dlg: Control = main.panel
	_expect(dlg != null, "对话框打开")
	if dlg != null:
		_expect(dlg.log_label.text.contains("詹岚"), "开场有台词")
		if PortraitSource.has_portrait("zhan_lan"):
			_expect(dlg.portrait.texture.get_height() == 768, "对话框用的是正式立绘")
		else:
			_expect(dlg.portrait.texture.get_height() == 24, "没有正式立绘时回退像素头像")
		dlg.press_send("你怎么看张杰")
		_expect(main.session.dialogues.has("zhan_lan"), "对话记进存档数据")
		dlg.press_send("他讲规则讲得太顺了")
		_expect(int(main.dialogue.trust_of("zhan_lan")) >= 2, "两次对话涨到 2 点信任")
		_expect(bool(main.session.expedition.st.intel.clues_found.has("rules_too_smooth")), "信任换来线索")
		await _shot("m1_slice_dialogue.png")
		dlg.press_close()
		await process_frame

	screen.press_deduce()
	_expect(int(main.session.expedition.st.clock) == 55, "推理花了 10 分钟")
	await _shot("m1_slice_expedition.png")

	screen.press_rest(15)
	await process_frame
	await process_frame
	var battle: Control = main.content.get_child(0)
	_expect(battle.has_method("press_action"), "第 70 分钟进入战斗界面")
	_expect(battle.view.has_method("objective"), "战斗界面显示目标")
	if battle.view.has_method("objective"):
		_expect(String(battle.view.objective()).contains("消灭"), "丧尸战目标是清场")
	_expect(battle.view.has_method("intents"), "战斗界面显示敌人意图")
	if battle.view.has_method("intents"):
		_expect(battle.view.intents().size() > 0, "能看到敌人意图")
		_expect(int(battle.view.b.intel) == 1, "詹岚的判断力让意图显示到技能")
	await _shot("m1_slice_battle.png")
	var guard := 0
	while battle.has_method("press_action") and not bool(battle.view.finished()) and guard < 400:
		battle.press_action(0)
		guard += 1
	_expect(guard < 400, "战斗在 400 个行动内结束")
	await process_frame
	await process_frame
	screen = main.content.get_child(0)
	_expect(screen.has_method("press_choice"), "战斗结束回到地点图")
	_expect(int(main.session.expedition.st.clock) == 70, "战斗结束停在第 70 分钟")
	_expect(main.session.expedition.st.pending_battle.is_empty(), "战斗已回报")

	screen.press_rest(20)
	await process_frame
	_expect(screen.press_choice("stay"), "第 90 分钟选择留守主机房")
	screen.press_rest(35)
	await process_frame
	await _shot("m1_slice_persuade.png")
	_expect(screen.has_method("press_persuade_free"), "界面支持自由说辞")
	var opened := false
	if screen.has_method("press_persuade_free"):
		opened = screen.press_persuade_free()
	_expect(opened, "第 125 分钟打开说服对话")
	var side: Control = main.panel
	_expect(side != null, "说服对话框打开")
	if side != null:
		side.press_send("我知道激光是你控的。不关闭，我就断电拆板——这是威胁。")
		await process_frame
		_expect(bool(main.session.expedition.st.flags.get("queen_helps", false)), "自由说辞说服成功")
		await _shot("m1_slice_persuade_panel.png")
		side.press_close()
		await process_frame
	screen.press_rest(40)
	_expect(int(main.session.expedition.st.clock) == 165, "断电事件在第 160 分钟发生")
	screen.press_rest(5)
	screen.press_rest(17)
	await process_frame
	await process_frame
	_expect(String(main.session.phase) == "settlement", "撑到 3:07 后进入结算")
	# 原著 6500 = 存活 1000 + 救马修 5000 + 精神突破 500；这一趟当着马修说漏嘴一次，扣 10。
	_expect(_found_text(main.content, "6490"), "郑吒结算 6490 点（6500 − 禁言 10）")
	_expect(_found_text(main.content, "B 级支线"), "B 级支线入账")

	var hub_btn := _find_button(main.content, "进入主神空间")
	_expect(hub_btn != null, "结算界面有进入主神空间的按钮")
	if hub_btn != null:
		hub_btn.emit_signal("pressed")
		await process_frame
	_expect(String(main.session.phase) == "hub", "进入主神空间")
	var hub: Control = main.content.get_child(0)
	_expect(hub.has_method("press_entry"), "主神空间界面加载")
	if not hub.has_method("press_entry"):
		_finish()
		return
	_expect(_found_text(main.content, "回归当晚"), "回归当晚")

	hub.press_entry("qigong_low")
	_expect(not main.session.game.characters["zheng_zha"].owned.has("qigong_low"), "当晚不能兑换")
	hub.press_rest()
	_expect(int(main.session.hub.day) == 1, "休息到第 1 天")
	_expect(not hub.view.morning().is_empty(), "第 1 天早上有晨会")
	hub.press_morning("accept")
	_expect(hub.view.morning().is_empty(), "晨会回答完就收起")
	_expect(_found_text(main.content, "第 1 天"), "界面显示第 1 天")

	main.session.hub.split_ticket("zheng_zha", "B")
	main.session.hub.split_ticket("zheng_zha", "C")
	hub.press_entry("qigong_low")
	var zz: RefCounted = main.session.game.characters["zheng_zha"]
	_expect(zz.owned.has("qigong_low"), "兑换到低级气功")
	_expect(zz.energy.has("neili"), "获得内力池")
	hub.press_attr("muscle")
	_expect(int(zz.points) == 5890, "买属性扣 100 点，剩 5890")
	hub.press_create("萝丽")
	_expect(main.session.game.companions.size() == 1, "造出萝丽")

	# 对练：兑换完气功，拿它跟训练傀儡打一场，看得见伤害数字。
	var day_before: int = main.session.hub.day
	var hp_before: float = zz.hp
	hub.open_tab("spar")
	await process_frame
	await _shot("m1_spar.png")
	hub.press_spar("qigong_low" if zz.skills.has("qigong_low") else "punch")
	_expect(int(main.session.hub.day) == day_before + 1, "对练耗 1 天")
	_expect(_found_text(hub.status_label, "打出"), "状态行给出对练伤害")
	_expect(absf(zz.hp - hp_before) < 0.01, "对练不伤角色")
	await _shot("m1_slice_hub.png")

	main._open_pause()
	await process_frame
	_expect(main.pause != null, "Esc 打开暂停菜单")
	await _shot("m1_pause.png")
	if main.pause != null:
		main.pause.press_save(1)
		_expect(bool(Slots.summary(1)["exists"]), "存到槽 1")
		_expect(String(Slots.summary(1)["label"]).contains("主神空间"), "槽 1 摘要写着主神空间")
		main._close_pause()
	main._on_load_slot(1)
	await process_frame
	var loaded: Control = main.content.get_child(0)
	_expect(String(main.session.phase) == "hub", "读档回到主神空间")
	_expect(int(main.session.hub.day) == 2, "读档保留天数（休息 1 天 + 对练 1 天）")
	_expect(main.session.game.characters["zheng_zha"].owned.has("qigong_low"), "读档保留兑换")
	_expect(main.session.game.companions.size() == 1, "读档保留造物")
	_expect(main.session.dialogues.has("zhan_lan"), "读档保留对话记忆")

	_expect(loaded.has_method("press_ask_zhushen"), "主神空间能提问")
	loaded.press_ask_zhushen()
	var zs: Control = main.panel
	_expect(zs != null, "主神对话框打开")
	if zs != null:
		zs.press_send("支线怎么拆分")
		_expect(zs.log_label.text.contains("三个 C"), "主神回答支线规则")
		zs.press_send("下一部是什么")
		_expect(zs.log_label.text.contains("权限"), "越界的问题被拒绝")
		await _shot("m1_slice_zhushen.png")
		zs.press_close()
		await process_frame

	var hurt: Array[Dictionary] = loaded.view.repairs()
	if not hurt.is_empty():
		var before_hp: float = main.session.game.characters[String(hurt[0]["id"])].hp
		loaded.press_repair(String(hurt[0]["id"]))
		_expect(main.session.game.characters[String(hurt[0]["id"])].hp > before_hp, "修复回血")

	for i in 8:
		loaded.press_rest()
	_expect(int(main.session.hub.day) == 9, "休息到第 9 天")
	_expect(bool(loaded.view.can_depart()), "第 9 天可以出发")
	loaded.press_depart()
	await process_frame
	_expect(String(main.session.phase) == "done", "走光柱后阶段结束")
	_expect(_found_text(main.content, "二十道光柱"), "结尾画面")
	_expect(_found_text(main.content, "萝丽："), "走光柱时萝丽说了一句话")

	main._show_title()
	await process_frame
	var back: Control = main.content.get_child(0)
	_expect(back.has_method("press_new"), "回到标题画面")
	back.press_slot(1)
	await process_frame
	_expect(String(main.session.phase) == "hub", "从标题读槽 1 回到主神空间")

	_finish()


## 加 --capture 时把当前画面存到 art_src/qa/（只在非 headless 下有意义）。
func _shot(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://").path_join("../art_src/qa")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name))


## 自动档和三个手动槽。
func _slots() -> Array[int]:
	var out: Array[int] = [Slots.AUTO]
	for i in range(1, Slots.COUNT + 1):
		out.append(i)
	return out


## 把现有的存档复制进备份，再清空槽位。
func _stash_slots() -> void:
	for i in _slots():
		if FileAccess.file_exists(Slots.path(i)):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(Slots.path(i)), ProjectSettings.globalize_path(BACKUP % i))
		Slots.erase(i)


## 有备份的槽：清掉槽里的档，把备份放回原位，删掉备份。开头调一次是为了接住上次中途崩掉留下的备份。
func _restore_slots() -> void:
	for i in _slots():
		var backup := BACKUP % i
		if not FileAccess.file_exists(backup):
			continue
		Slots.erase(i)
		DirAccess.copy_absolute(ProjectSettings.globalize_path(backup), ProjectSettings.globalize_path(Slots.path(i)))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))


func _expect(cond: bool, message: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL " + message)


## 结算账本里的罚分条数（禁言每中一句加一条）。
func _penalty_count(main: Node) -> int:
	var st: RefCounted = main.session.expedition.st
	var n := 0
	for row: Dictionary in st.ledger:
		if String(row["kind"]) == "penalty":
			n += 1
	return n


func _found_text(node: Node, needle: String) -> bool:
	if node is Label and String(node.text).contains(needle):
		return true
	if node is Button and String(node.text).contains(needle):
		return true
	for c in node.get_children():
		if _found_text(c, needle):
			return true
	return false


func _find_button(node: Node, text: String) -> Button:
	if node is Button and String(node.text) == text:
		return node
	for c in node.get_children():
		var b := _find_button(c, text)
		if b != null:
			return b
	return null


func _finish() -> void:
	for i in _slots():
		Slots.erase(i)
	_restore_slots()
	print("M1 切片验证：失败 %d 项" % failures)
	quit(0 if failures == 0 else 1)
