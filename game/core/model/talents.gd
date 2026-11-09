extends RefCounted
## 天赋（设计规格 3.6、3.7）：每个人带一个隐藏天赋和它的发挥条件；条件满足就觉醒，落一次效果，之后一直有效。
## 人物表写 flags.talent（一个 id）；旧数据和以后的新人生成器可能写 flags.talents（数组），两种都认。
## 契合：天赋本身（不论觉醒与否）就能绕过兑换项写明的素质门槛（目录 gates.talent_bypass）。
## 觉醒条件（data/characters/talents.json 的 triggers，满足任意一个即可）：
##   near_death：战斗结束时活着、生命不到上限的 near_death_ratio；
##   ally_died：同一地点的同伴死了或被抹杀；
##   team_peril：这部片活着的轮回者只剩一半或更少；
##   bought_series:<系列> / bought_attr:<属性>：兑换到契合的强化；
##   trained：在主神空间训练或对练过；
##   flag:<旗标>：剧情旗标被设上（例如队伍停下来扶掉队的人）。
## 效果（effect）：attr（锻炼属性，主神看不见）、fear_relief（自己的恐惧下降）、
##   team_fear_relief（同地点其他人的恐惧下降，由远征层处理）、train_mult（训练熟练度倍率）。
## 觉醒记在 flags.talents_awake（数组），随角色存档。

const DataLoader = preload("res://core/util/data_loader.gd")

const PATH := "res://data/characters/talents.json"

static var _cache: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		var res := DataLoader.load_json(PATH)
		assert(res.ok, res.error)
		_cache = res.data
	return _cache


static func def(talent_id: String) -> Dictionary:
	return (data()["talents"] as Dictionary).get(talent_id, {})


## 这个人身上的天赋 id（可能为空）。
static func ids(ch: RefCounted) -> Array[String]:
	var out: Array[String] = []
	var one := String(ch.flags.get("talent", ""))
	if one != "":
		out.append(one)
	for t in ch.flags.get("talents", []):
		if not out.has(String(t)):
			out.append(String(t))
	return out


static func has(ch: RefCounted, talent_id: String) -> bool:
	return talent_id != "" and ids(ch).has(talent_id)


static func is_awake(ch: RefCounted, talent_id: String) -> bool:
	return (ch.flags.get("talents_awake", []) as Array).has(talent_id)


## 已觉醒天赋的显示名（界面用）；没有返回空数组。
static func awake_names(ch: RefCounted) -> Array[String]:
	var out: Array[String] = []
	for t in ids(ch):
		if is_awake(ch, t):
			out.append(String(def(t).get("name", t)))
	return out


## 训练倍率：觉醒了带 train_mult 的天赋才有，否则 1。
static func train_mult(ch: RefCounted) -> float:
	var m := 1.0
	for t in ids(ch):
		if is_awake(ch, t):
			m = maxf(m, float((def(t).get("effect", {}) as Dictionary).get("train_mult", 1.0)))
	return m


## 某个触发发生在 ch 身上。返回这次觉醒的天赋 id（通常 0 或 1 个），事件追加到 events。
static func trigger(ch: RefCounted, trigger_id: String, events: Array[Dictionary]) -> Array[String]:
	var woke: Array[String] = []
	if not ch.alive:
		return woke
	for t in ids(ch):
		var d := def(t)
		if d.is_empty() or is_awake(ch, t) or not (d.get("triggers", []) as Array).has(trigger_id):
			continue
		_awaken(ch, t, d, trigger_id, events)
		woke.append(t)
	return woke


## 觉醒算一次潜力突升，主神看在眼里，记进议程（agenda 为 null 时跳过）。
static func record(agenda: RefCounted, char_id: String, talent_id: String, film: String) -> void:
	if agenda == null:
		return
	agenda.potential_spike(char_id, float(data()["awaken_spike"]), film, "天赋觉醒：%s" % String(def(talent_id).get("name", talent_id)))


static func _awaken(ch: RefCounted, t: String, d: Dictionary, trigger_id: String, events: Array[Dictionary]) -> void:
	var awake: Array = ch.flags.get("talents_awake", [])
	awake.append(t)
	ch.flags["talents_awake"] = awake
	var eff: Dictionary = d.get("effect", {})
	var attrs: Dictionary = eff.get("attr", {})
	for k: String in attrs:
		ch.attributes.add_trained(k, float(attrs[k]))
	if eff.has("fear_relief"):
		ch.fear = maxf(0.0, ch.fear - float(eff["fear_relief"]))
	events.append({
		"type": "talent_awakened", "char": ch.id, "talent": t, "name": String(d.get("name", t)),
		"trigger": trigger_id, "text": String(d.get("text", "")),
	})
