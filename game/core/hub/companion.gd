extends RefCounted
## 人造人陪伴（设计规格 6.6；M1：郑吒造萝丽、心情与亲密度、她对出征的反应、房间里的 AI 对话）。
## 造物记在 GameState.companions，每条是字典：
##   {"id", "name", "creator", "attributes", "persona",
##    "mood" 心情, "intimacy" 亲密, "dependence" 依赖, "security" 安心（都是 0~100）,
##    "last_visit_day" 最近一次陪她是第几天, "talked_day" 最近一次说话是第几天}
## 这里只有纯函数：改字典、改制造者的恐惧、返回事件。耗不耗天由 hub.gd 决定。

const DEFAULTS := {"mood": 60.0, "intimacy": 50.0, "dependence": 40.0, "security": 40.0}
## 亲密到这里，制造者休整时恐惧多降一些（她是"锚"）。
const ANCHOR_INTIMACY := 60.0
const ANCHOR_RELIEF := 5.0
## 连着几天没人陪，心情开始往下掉。
const LONELY_AFTER_DAYS := 2
const LONELY_MOOD := 4.0


## 新造出来的人：补上陪伴字段。persona 是对话层的人设 id（萝丽是 luo_li）。
static func init_fields(c: Dictionary, persona: String, day: int) -> void:
	for k: String in DEFAULTS:
		c[k] = DEFAULTS[k]
	c["persona"] = persona
	c["last_visit_day"] = day
	c["talked_day"] = -1


static func find(game: RefCounted, companion_id: String) -> Dictionary:
	for c: Dictionary in game.companions:
		if String(c["id"]) == companion_id:
			return c
	return {}


static func _bump(c: Dictionary, deltas: Dictionary) -> void:
	for k: String in deltas:
		c[k] = clampf(float(c.get(k, DEFAULTS.get(k, 50.0))) + float(deltas[k]), 0.0, 100.0)


## 陪她待一天：亲密 +10、心情 +15、安心 +10；制造者恐惧 −10。
static func visit(c: Dictionary, creator: RefCounted, day: int) -> Array[Dictionary]:
	_bump(c, {"intimacy": 10.0, "mood": 15.0, "security": 10.0})
	c["last_visit_day"] = day
	creator.fear = maxf(0.0, creator.fear - 10.0)
	return [{"type": "companion_visited", "companion": String(c["id"]), "name": String(c["name"]), "mood": c["mood"], "intimacy": c["intimacy"]}]


## 一起训练：她觉得自己帮得上忙（依赖 −5、安心 +5、亲密 +5、心情 +5）；制造者恐惧 −5。
static func train_together(c: Dictionary, creator: RefCounted, day: int) -> Array[Dictionary]:
	_bump(c, {"intimacy": 5.0, "mood": 5.0, "dependence": -5.0, "security": 5.0})
	c["last_visit_day"] = day
	creator.fear = maxf(0.0, creator.fear - 5.0)
	return [{"type": "companion_trained", "companion": String(c["id"]), "name": String(c["name"]), "dependence": c["dependence"], "intimacy": c["intimacy"]}]


## 说了一次话（AI 对话或离线台词）：每天只算一次，亲密 +3、心情 +5。
static func talked(c: Dictionary, day: int) -> Array[Dictionary]:
	if int(c.get("talked_day", -1)) == day:
		return []
	c["talked_day"] = day
	_bump(c, {"intimacy": 3.0, "mood": 5.0})
	return [{"type": "companion_talked", "companion": String(c["id"]), "name": String(c["name"]), "intimacy": c["intimacy"]}]


## 过了一天：连着两天以上没人陪，心情 −4；亲密够高时制造者恐惧多降 5。
static func day_passed(c: Dictionary, creator: RefCounted, day: int) -> void:
	if day - int(c.get("last_visit_day", day)) > LONELY_AFTER_DAYS:
		_bump(c, {"mood": -LONELY_MOOD})
	if float(c["intimacy"]) >= ANCHOR_INTIMACY and creator != null and creator.alive:
		creator.fear = maxf(0.0, creator.fear - ANCHOR_RELIEF)


## 她现在想要什么（界面显示一句）。
static func wish(c: Dictionary) -> String:
	if float(c["mood"]) < 40.0:
		return "想你多陪陪她"
	if float(c["dependence"]) >= 60.0:
		return "想跟你一起进下一部片"
	if float(c["security"]) < 40.0:
		return "担心你回不来"
	if float(c["intimacy"]) >= 70.0:
		return "想看看现实世界是什么样子"
	return "想知道你每天在练什么"


## 出征时她的反应：亲密和心情决定说什么；亲密够高的话，她是制造者的锚，出发前恐惧 −10。
## 返回 {"companion", "name", "line", "fear"}，fear 是制造者恐惧的变化量。
static func farewell(c: Dictionary) -> Dictionary:
	var line := ""
	var fear := 0.0
	if float(c["intimacy"]) >= 70.0 and float(c["mood"]) >= 50.0:
		line = "早点回来。我会一直等你。"
		fear = -10.0
	elif float(c["mood"]) < 40.0:
		line = "你又要走了……这次也不带我。"
	elif float(c["security"]) < 40.0:
		line = "你一定要回来，答应我。"
	else:
		line = "路上小心。回来给我讲讲。"
	return {"companion": String(c["id"]), "name": String(c["name"]), "line": line, "fear": fear}
