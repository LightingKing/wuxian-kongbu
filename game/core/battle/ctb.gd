extends RefCounted
## 行动时间轴（CTB，设计规格 4.2）：下次行动时间 = 当前时间 + 基础延迟 × 倍率 ÷ 速度。
## 速度 200 的单位每行动两次，速度 100 的单位行动一次。时间相同时，先加入战场的先动。

const BattleData = preload("res://core/battle/battle_data.gd")

var base_delay: float = 10000.0
var now: float = 0.0


func _init() -> void:
	base_delay = float(BattleData.rules()["ctb_base_delay"])


func delay(speed: float, mult: float) -> float:
	return base_delay * mult / maxf(speed, 1.0)


## 开场：第一次行动的时间按先手倍率（initiative）算。
func init_unit(u: RefCounted) -> void:
	u.next_time = now + delay(u.speed(), u.initiative)


## units 里最早行动的在场单位；没有人在场时返回 null。
func next_actor(units: Array[RefCounted]) -> RefCounted:
	var best: RefCounted = null
	for u in units:
		if u.in_play() and (best == null or u.next_time < best.next_time):
			best = u
	return best


## u 刚行动完：时间推进到它的行动时刻，再排它的下一次行动。
func advance(u: RefCounted, mult: float) -> void:
	now = maxf(now, u.next_time)
	u.next_time = now + delay(u.speed(), mult)


## 预览接下来 count 次行动的单位 id（假设每次都是普通行动），不改变任何单位。
func preview(units: Array[RefCounted], count: int) -> Array[String]:
	var times: Array[float] = []
	var live: Array[RefCounted] = []
	for u in units:
		if u.in_play():
			live.append(u)
			times.append(u.next_time)
	var out: Array[String] = []
	if live.is_empty():
		return out
	for i in count:
		var best := 0
		for j in live.size():
			if times[j] < times[best]:
				best = j
		out.append(live[best].id)
		times[best] += delay(live[best].speed(), 1.0)
	return out
