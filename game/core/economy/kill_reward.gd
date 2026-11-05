extends RefCounted
## 击杀奖励与相对难度挂钩（核心机制分析 第二节）：
##   奖励 = 基础价 × min(1, 怪物威胁 / 击杀者的评价战力)
## 比值低于阈值（默认 0.05）时为 0——"像玩一样"的杀戮不给分。
## 标定（原著）：爬行者 100（生化危机一）→ 50（生化危机二，L6524）→ 25（偷袭生化，L13099）。
## 评价战力只算主神"看得见"的部分（兑换），不含自创技能和基因锁，由调用方传入。

const Rules = preload("res://core/util/rules.gd")


static func points_for_kill(base_value: float, enemy_threat: float, killer_rating_power: float) -> float:
	if killer_rating_power <= 0.0:
		return base_value
	var ratio := enemy_threat / killer_rating_power
	var zero_below := float(Rules.get_value("kill_reward", "zero_below_ratio"))
	if ratio < zero_below:
		return 0.0
	return base_value * minf(1.0, ratio)
