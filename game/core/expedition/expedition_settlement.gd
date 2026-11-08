extends RefCounted
## 一部片结束时，把远征里记下的账（存活、击杀、支线、特殊奖励、扣分）交给 settlement.gd 结算，并写回轮回者（设计规格 5.6）。
## 原著锚点：郑吒第一部 6502 点 = 存活 1000 + 救下马修 5000 + 精神临界值突破 500 + 击杀 2。

const Rules = preload("res://core/util/rules.gd")
const Settlement = preload("res://core/economy/settlement.gd")


## 一个人的结算条目。死了的人没有条目（不结算）。
static func entries_for(st: RefCounted, char_id: String) -> Array:
	var out: Array = []
	if not st.is_alive(char_id):
		return out
	out.append({"kind": "survival", "points": float(Rules.get_value("settlement", "survival")), "label": "存活"})
	var k := float(st.kill_points.get(char_id, 0.0))
	if k > 0.0:
		out.append({"kind": "kill", "points": k, "label": "击杀"})
	for l: Dictionary in st.ledger:
		if l["char"] == char_id:
			out.append({"kind": String(l["kind"]), "points": float(l["points"]), "label": String(l["label"]), "grade": String(l["grade"])})
	return out


## 全员结算并写回：点数、支线、完成的片数；点数为负被抹杀。返回 角色 id → 结算结果（死了的是 {"dead": true, "reason": ...}）。
static func settle_all(st: RefCounted) -> Dictionary:
	var results := {}
	for c: String in st.roster:
		var ch: RefCounted = st.characters[c]
		if not ch.alive:
			results[c] = {"dead": true, "reason": String(ch.flags.get("erased", "killed"))}
			continue
		var r := Settlement.settle(entries_for(st, c), ch.points)
		ch.points = int(r["final_points"])
		for g: String in r["tickets"]:
			ch.tickets.add(g)
		if bool(r["erased"]):
			ch.alive = false
			ch.flags["erased"] = "negative_points"
		else:
			ch.films_completed += 1
		results[c] = r
	st.settled = true
	return results
