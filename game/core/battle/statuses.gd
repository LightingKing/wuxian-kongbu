extends RefCounted
## 状态效果（设计规格 4.5），全部由 data/battle/statuses.json 定义。
## 状态记在单位的 statuses 里：{"id": 状态, "remaining": 剩余次数}。
## 时间规则：每次轮到持有者行动时，先结算持续伤害，再把 remaining 减 1，减到 0 就结束。
## 所以 duration = N 表示"到持有者第 N 次轮到自己时结束"：防御（1）挡到下次轮到自己为止，流血（3）跳 3 次伤害。

const BattleData = preload("res://core/battle/battle_data.gd")


static func has(unit: RefCounted, status_id: String) -> bool:
	for s: Dictionary in unit.statuses:
		if s["id"] == status_id:
			return true
	return false


## 施加状态。已有同名状态时：stack = "refresh" 重置剩余次数，"keep" 保持不变（感染倒计时不会被再咬一口重置）。
static func apply(unit: RefCounted, status_id: String) -> Dictionary:
	var def := BattleData.status(status_id)
	for s: Dictionary in unit.statuses:
		if s["id"] == status_id:
			if def["stack"] == "refresh":
				s["remaining"] = int(def["duration"])
			return {"type": "status_applied", "target": unit.id, "status": status_id, "renewed": true}
	unit.statuses.append({"id": status_id, "remaining": int(def["duration"])})
	return {"type": "status_applied", "target": unit.id, "status": status_id, "renewed": false}


static func remove(unit: RefCounted, status_id: String) -> bool:
	for i in unit.statuses.size():
		if unit.statuses[i]["id"] == status_id:
			unit.statuses.remove_at(i)
			return true
	return false


## 乘法修正（speed_mult、attack_mult、damage_taken_mult）：所有状态连乘，没有就是 1。
static func mult(unit: RefCounted, key: String) -> float:
	var m := 1.0
	for s: Dictionary in unit.statuses:
		var mods: Dictionary = BattleData.status(s["id"]).get("modifiers", {})
		m *= float(mods.get(key, 1.0))
	return m


## 加法修正（hit_mod）：所有状态相加，没有就是 0。
static func sum(unit: RefCounted, key: String) -> float:
	var total := 0.0
	for s: Dictionary in unit.statuses:
		var mods: Dictionary = BattleData.status(s["id"]).get("modifiers", {})
		total += float(mods.get(key, 0.0))
	return total


static func has_flag(unit: RefCounted, flag: String) -> bool:
	for s: Dictionary in unit.statuses:
		if (BattleData.status(s["id"]).get("flags", []) as Array).has(flag):
			return true
	return false


## 轮到持有者行动时调用。返回事件列表；持续伤害直接扣血，死亡由战斗控制器判断。
static func start_of_turn(unit: RefCounted) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var expired: Array[String] = []
	for s: Dictionary in unit.statuses:
		var def := BattleData.status(s["id"])
		var tick := float(def.get("tick_damage", 0.0))
		if tick > 0.0:
			unit.hp -= tick
			events.append({"type": "status_damage", "target": unit.id, "status": s["id"], "amount": tick, "hp": unit.hp})
		s["remaining"] = int(s["remaining"]) - 1
		if int(s["remaining"]) <= 0:
			expired.append(String(s["id"]))
	for id in expired:
		remove(unit, id)
		events.append({"type": "status_expired", "target": unit.id, "status": id})
		if BattleData.status(id).get("on_expire", "") == "turn_zombie":
			unit.turned = true
			unit.alive = false
			events.append({"type": "infection_turned", "target": unit.id})
	return events
