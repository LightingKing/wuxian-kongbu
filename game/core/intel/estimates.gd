extends RefCounted
## 成功率的显示（设计规格 3.8"概率"）：只有队里有智者（智力 ≥ 150）时才显示，精度随智力提高。
##   150~199：误差约 ±0.2 以内，按"成"报（"约三成"，楚轩口吻）；
##   200~249：误差更小，按 5% 报；
##   250 以上：误差 ±0.02，按 1% 报。
## 随机数由调用方传入（roll 在 0~1 之间）。

const MIN_INTELLIGENCE := 150.0
const TENTHS: Array[String] = ["零", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]


## 队里智力最高的人；没有人时返回 null。
static func best_thinker(members: Array) -> RefCounted:
	var best: RefCounted = null
	for m: RefCounted in members:
		if m.alive and (best == null or m.attributes.total("intelligence") > best.attributes.total("intelligence")):
			best = m
	return best


static func estimate(true_p: float, intelligence: float, roll: float) -> Dictionary:
	if intelligence < MIN_INTELLIGENCE:
		return {"shown": false}
	var noise := maxf(0.02, (250.0 - intelligence) / 500.0)
	var est := clampf(true_p + noise * (2.0 * roll - 1.0), 0.0, 1.0)
	var step := 0.1 if intelligence < 200.0 else (0.05 if intelligence < 250.0 else 0.01)
	var shown := roundf(est / step) * step
	var text := ""
	if step == 0.1:
		text = "约%s成" % TENTHS[roundi(shown * 10.0)]
	else:
		text = "约 %d%%" % roundi(shown * 100.0)
	return {"shown": true, "estimate": shown, "text": text}
