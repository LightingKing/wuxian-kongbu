extends RefCounted
## 一部恐怖片结束时的个人结算。
## entries 每条：{"kind": String, "points": float, "grade": String（可选，支线等级）, "label": String}
##   kind = "survival"（存活固定奖励）| "kill"（击杀，可为小数，结算时合计后向下取整）
##        | "side_plot"（支线完成：点数 + 一个支线等级）| "bonus"（特殊奖励）| "penalty"（扣分，points 为负）
## 返回 {"delta": int, "final_points": int, "tickets": Array[String], "erased": bool, "lines": Array[String]}
## erased = 结算后点数为负 → 被主神抹杀（原著 L1872）。


static func settle(entries: Array, current_points: int) -> Dictionary:
	var kill_sum := 0.0
	var other := 0
	var tickets: Array[String] = []
	var lines: Array[String] = []
	for e in entries:
		var kind: String = e["kind"]
		var pts: float = float(e.get("points", 0.0))
		var label: String = e.get("label", kind)
		match kind:
			"kill":
				kill_sum += pts
			"side_plot":
				other += int(pts)
				var grade: String = e.get("grade", "")
				if grade != "":
					tickets.append(grade)
				lines.append("%s：%+d 点，%s 级支线一个" % [label, int(pts), grade])
			"survival", "bonus", "penalty":
				other += int(pts)
				lines.append("%s：%+d 点" % [label, int(pts)])
			_:
				assert(false, "未知结算类型：" + kind)
	var kill_points := int(floor(kill_sum))
	if kill_sum > 0.0:
		lines.append("击杀：%+d 点" % kill_points)
	var delta := other + kill_points
	var final_points := current_points + delta
	return {
		"delta": delta,
		"final_points": final_points,
		"tickets": tickets,
		"erased": final_points < 0,
		"lines": lines,
	}
