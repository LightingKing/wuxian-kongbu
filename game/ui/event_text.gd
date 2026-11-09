extends RefCounted
## 把 core 发出的事件翻译成一行中文，给界面的事件流和战斗日志用。
## 只负责"能看懂"，不做规则判断；认不出的事件返回空字符串（界面跳过）。

const BattleData = preload("res://core/battle/battle_data.gd")


static func describe(e: Dictionary, names: Dictionary = {}) -> String:
	var t := String(e.get("type", ""))
	match t:
		"expedition_start":
			return "进入恐怖片。"
		"move_start":
			return "出发，前往 %s（%d 分钟）。" % [_name(e.get("to", ""), names), int(e.get("minutes", 0))]
		"arrived":
			return "到达 %s。" % _name(e.get("location", ""), names)
		"move_interrupted":
			return "半路被打断。"
		"plot_event":
			return "剧情发生：%s。" % _name(e.get("event", ""), names)
		"plot_altered":
			return "剧情被改写：%s。" % String(e.get("label", ""))
		"dialogue":
			return "%s：%s" % [_name(e.get("speaker", ""), names), String(e.get("text", ""))]
		"tether_set":
			return "手表绑定：不得离开 %s 100 米。" % _name(e.get("npc", ""), names)
		"tether_warning":
			return "%s 超出绑定范围，%d 分钟内不回来会被抹杀。" % [_name(e.get("char", ""), names), int(e.get("grace_minutes", 0))]
		"tether_released":
			return "绑定解除。"
		"tether_transferred":
			return "绑定转移到 %s。" % _name(e.get("npc", ""), names)
		"erased":
			return "%s 被主神抹杀（%s）。" % [_name(e.get("char", ""), names), String(e.get("reason", ""))]
		"char_died":
			return "%s 死了（%s）。" % [_name(e.get("char", ""), names), String(e.get("reason", ""))]
		"infection_turned":
			return "%s 变成了丧尸。" % _name(e.get("char", ""), names)
		"battle_request":
			return "战斗！%s 出现了敌人。" % _name(e.get("location", ""), names)
		"battle_resolved":
			return "战斗结束：%s。" % String(e.get("outcome", ""))
		"kill_recorded":
			return "%s 击杀 %s（+%.1f 点）。" % [_name(e.get("char", ""), names), _enemy(e.get("enemy", "")), float(e.get("points", 0.0))]
		"side_plot_done":
			return "支线完成：%s（%s 级，+%d 点）。" % [String(e.get("label", "")), String(e.get("grade", "")), int(e.get("points", 0))]
		"bonus":
			return "%s：+%d 点。" % [String(e.get("label", "")), int(e.get("points", 0))]
		"penalty":
			return "%s：%d 点。" % [String(e.get("label", "")), int(e.get("points", 0))]
		"fear_changed":
			return "%s 恐惧 %+.1f（%s）。" % [_name(e.get("char", ""), names), float(e.get("amount", 0.0)), _reason(String(e.get("reason", "")))]
		"clue_found":
			return "发现线索：%s。" % _name(e.get("clue", ""), names)
		"inference":
			return "推论：%s（可信度 %.0f%%）。" % [_name(e.get("fact", ""), names), float(e.get("confidence", 0.0)) * 100.0]
		"returned":
			return "倒计时结束，回归主神空间。"
		"wiped":
			return "全员死亡，任务失败。"
		"choice_request":
			return "需要做出选择。"
		"choice_made":
			return "已选择。"
		"persuade_request":
			return "需要说服 %s。" % _name(e.get("npc", ""), names)
		"persuade_result":
			return "说服%s。" % ("成功" if bool(e.get("success", false)) else "失败")
		"item_used":
			return "%s 使用了道具。" % _name(e.get("char", ""), names)
		"searched":
			return "搜索完毕。"
		"search_encounter":
			return String(e.get("text", "搜索的声音引来了敌人。"))
		"persuade_blocked":
			return "你还没有把握开口——先想清楚%s。" % _name(e.get("fact", ""), names)
		"already_searched":
			return "这里已经搜过了。"
		# ---- 战斗 ----
		"battle_start":
			return "战斗开始。"
		"turn_start":
			return "轮到 %s。" % _name(e.get("unit", ""), names)
		"action":
			return "%s 行动。" % _name(e.get("unit", ""), names)
		"damage":
			return "%s 受到 %.0f 伤害（剩 %.0f）。" % [_name(e.get("target", ""), names), float(e.get("amount", 0.0)), float(e.get("hp", 0.0))]
		"heal":
			return "%s 回复 %.0f 生命。" % [_name(e.get("target", ""), names), float(e.get("amount", 0.0))]
		"miss":
			return "%s 躲开了 %s 的攻击。" % [_name(e.get("target", ""), names), _name(e.get("source", ""), names)]
		"death":
			return "%s 倒下了。" % _name(e.get("target", ""), names)
		"fled":
			return "%s 逃离了战场。" % _name(e.get("unit", ""), names)
		"status_applied":
			return "%s 陷入 %s。" % [_name(e.get("target", ""), names), _status(e.get("status", ""))]
		"status_expired":
			return "%s 的 %s 结束了。" % [_name(e.get("target", ""), names), _status(e.get("status", ""))]
		"status_damage":
			return "%s 因 %s 受到 %.0f 伤害。" % [_name(e.get("target", ""), names), _status(e.get("status", "")), float(e.get("amount", 0.0))]
		"moved":
			return "%s 换到第 %d 排。" % [_name(e.get("unit", ""), names), int(e.get("row", 0)) + 1]
		"battle_end":
			return "战斗结束。"
		"gene_lock_awaken":
			return "%s 解开了基因锁第 %d 阶！" % [_name(e.get("target", ""), names), int(e.get("stage", 0))]
		"awaken_failed":
			return "%s 在濒死边缘没能突破。" % _name(e.get("target", ""), names)
		"fear_collapse":
			return "%s 恐惧崩溃了。" % _name(e.get("target", ""), names)
		"fear_endured":
			return "%s 硬撑住了恐惧。" % _name(e.get("target", ""), names)
		"infection_turned":
			return "%s 在战斗中变成了丧尸。" % _name(e.get("target", ""), names)
		"gag_penalty":
			return "说漏了嘴——%s 就在旁边，扣 %.0f 点。" % [_name(e.get("witness", ""), names), float(e.get("points", 0.0))]
		"leak_unwitnessed":
			return "差点说漏嘴。旁边没有剧情人物，没人听见。"
		"invalid_action":
			return ""
	return ""


static func _name(id: Variant, names: Dictionary) -> String:
	var key := String(id)
	return String(names.get(key, key))


static func _reason(r: String) -> String:
	var table := {
		"enemy_appear": "敌人登场", "darkness": "黑暗", "plot": "剧情", "rest": "休息",
		"tether": "绑定", "turned": "感染", "fight": "战斗", "low_hp": "濒死", "aura": "敌人威压",
	}
	return String(table.get(r, r))


static func _status(id: Variant) -> String:
	var s := String(id)
	var all := BattleData.statuses()
	return String((all[s] as Dictionary).get("name", s)) if all.has(s) else s


static func _enemy(id: Variant) -> String:
	var d := String(id)
	var all := BattleData.enemies()
	return String((all[d] as Dictionary).get("name", d)) if all.has(d) else d
