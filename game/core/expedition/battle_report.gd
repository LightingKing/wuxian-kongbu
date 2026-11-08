extends RefCounted
## 从一场战斗的事件记录里整理出击杀和伤亡，供远征记账（击杀奖励、杀死新人扣分）。
## 击杀者 = 最后一次对它造成伤害的单位；没被直接打过（例如流血死、感染变丧尸）就没有击杀者。

## 返回 {"kills": [{"killer", "victim", "def_id"}], "deaths": [{"id", "killer", "turned"}], "fled": [单位 id]}
static func summarize(history: Array[Dictionary], units: Array[RefCounted]) -> Dictionary:
	var by_id := {}
	for u in units:
		by_id[u.id] = u
	var last_hit := {}
	var kills: Array = []
	var deaths: Array = []
	var fled: Array = []
	for e in history:
		match String(e["type"]):
			"damage":
				last_hit[e["target"]] = e["source"]
			"death":
				var v: RefCounted = by_id[e["target"]]
				var killer := "" if bool(e["turned"]) else String(last_hit.get(v.id, ""))
				if v.side == "enemy":
					kills.append({"killer": killer, "victim": v.id, "def_id": v.def_id})
				else:
					deaths.append({"id": v.id, "killer": killer, "turned": bool(e["turned"])})
			"fled":
				fled.append(String(e["unit"]))
	return {"kills": kills, "deaths": deaths, "fled": fled}
