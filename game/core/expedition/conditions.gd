extends RefCounted
## 剧情条件（事件的 when、改写的 if）。条件是一个字典，里面每一项都成立才算成立；空字典恒成立。
##   {"flag": 名}、{"not_flag": 名}                 剧情旗标
##   {"time_at_least": 分钟}、{"time_before": 分钟}  时钟
##   {"party_at": 地点}                             有活着的轮回者在那里
##   {"npc_alive": id}、{"npc_dead": id}            剧情人物生死
##   {"npc_at": {"npc": id, "location": 地点}}
##   {"deviation_at_least": n}                      剧情偏移量（连锁事件用）
##   {"all": [条件...]}、{"any": [条件...]}、{"not": 条件}
## 不认识的键一律视为不成立，免得写错的剧本悄悄触发。


static func check(cond: Dictionary, st: RefCounted) -> bool:
	for k: String in cond:
		if not _check_one(k, cond[k], st):
			return false
	return true


static func _check_one(key: String, v: Variant, st: RefCounted) -> bool:
	match key:
		"flag":
			return bool(st.flags.get(String(v), false))
		"not_flag":
			return not bool(st.flags.get(String(v), false))
		"time_at_least":
			return st.clock >= int(v)
		"time_before":
			return st.clock < int(v)
		"party_at":
			return st.party_at(String(v))
		"npc_alive":
			return st.npcs.has(String(v)) and bool(st.npcs[String(v)]["alive"])
		"npc_dead":
			return st.npcs.has(String(v)) and not bool(st.npcs[String(v)]["alive"])
		"npc_at":
			var npc: Dictionary = st.npcs.get(String(v["npc"]), {})
			return not npc.is_empty() and npc["location"] == v["location"]
		"deviation_at_least":
			return st.deviation >= int(v)
		"all":
			for c: Dictionary in v:
				if not check(c, st):
					return false
			return true
		"any":
			for c: Dictionary in v:
				if check(c, st):
					return true
			return false
		"not":
			return not check(v, st)
	return false
