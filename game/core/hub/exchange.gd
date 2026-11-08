extends RefCounted
## 在主神处兑换（设计规格 6.2~6.3）。先核对门槛，不满足时主神说明原因；满足就扣点数和支线、把积木落到角色身上。
## 门槛：点数、支线、前置（高一级要先有同系低一级）、能量类型（纳戒要内力）、素质门槛（天赋可绕过）、不能重复兑换。
## 代兑：可以用别人的点数和支线给自己兑换，每人每次休整只能给别人一次（由 hub.gd 记录，这里只看传进来的 gift_used）。
## 双血统：已有别的系列的血统再兑换血统，主神先警告；坚持兑换时 70% 变成非人（flags.mutated）。

const Catalog = preload("res://core/hub/catalog.gd")
const Pricing = preload("res://core/hub/pricing.gd")


## 返回 {"ok": bool, "reasons": [原因], "warnings": [警告]}。payer 为 null 表示自己付。
static func check(ch: RefCounted, entry_id: String, payer: RefCounted = null, gift_used: bool = false) -> Dictionary:
	var reasons: Array[String] = []
	var warnings: Array[String] = []
	if not Catalog.has(entry_id):
		reasons.append("unknown_entry")
		return {"ok": false, "reasons": reasons, "warnings": warnings}
	var e := Catalog.entry(entry_id)
	var who: RefCounted = payer if payer != null else ch
	var t := Pricing.parse_tier(String(e["price"]["tier"]))
	if who.points < int(e["price"]["points"]):
		reasons.append("not_enough_points")
	if int(t["count"]) > 0 and not who.tickets.has_at_least(String(t["grade"]), int(t["count"])):
		reasons.append("missing_ticket")
	for r: String in e.get("requires", []):
		if not ch.owned.has(r):
			reasons.append("missing_prerequisite:" + r)
	var need_energy := String(e.get("requires_energy", ""))
	if need_energy != "" and not ch.energy.has(need_energy):
		reasons.append("needs_energy:" + need_energy)
	var gates: Dictionary = e.get("gates", {})
	var bypass := String(gates.get("talent_bypass", ""))
	var talented := bypass != "" and (ch.flags.get("talents", []) as Array).has(bypass)
	for k: String in gates.get("attr_min", {}):
		if not talented and ch.attributes.total(k) < float(gates["attr_min"][k]):
			reasons.append("gate:" + k)
	if not bool(e.get("consumable", false)) and ch.owned.has(entry_id):
		reasons.append("already_owned")
	if who != ch and gift_used:
		reasons.append("gift_used")
	if bool(e.get("bloodline", false)) and _other_bloodline(ch, String(e["series"])):
		warnings.append("bloodline_risk")
	return {"ok": reasons.is_empty(), "reasons": reasons, "warnings": warnings}


static func _other_bloodline(ch: RefCounted, series: String) -> bool:
	for id in ch.owned:
		var o := Catalog.entry(id)
		if bool(o.get("bloodline", false)) and String(o["series"]) != series:
			return true
	return false


## 兑换。opts：payer（付钱的人，默认自己）、accept_risk（坚持兑换有变异风险的血统）、gift_used（付钱的人这次休整已经给过别人）。
## 返回事件：exchange_refused / exchange_warning（被警告，没有兑换）/ exchange_done，以及 bloodline_mutation 或 bloodline_safe。
static func buy(ch: RefCounted, entry_id: String, rng: RefCounted, opts: Dictionary = {}) -> Array[Dictionary]:
	var payer: RefCounted = opts.get("payer", null)
	var who: RefCounted = payer if payer != null else ch
	var result := check(ch, entry_id, payer, bool(opts.get("gift_used", false)))
	if not result["ok"]:
		return [{"type": "exchange_refused", "char": ch.id, "entry": entry_id, "reasons": result["reasons"]}]
	var risky := (result["warnings"] as Array).has("bloodline_risk")
	if risky and not bool(opts.get("accept_risk", false)):
		return [{"type": "exchange_warning", "char": ch.id, "entry": entry_id, "warnings": result["warnings"]}]
	var e := Catalog.entry(entry_id)
	var t := Pricing.parse_tier(String(e["price"]["tier"]))
	who.points -= int(e["price"]["points"])
	if int(t["count"]) > 0:
		who.tickets.spend(String(t["grade"]), int(t["count"]))
	_apply(ch, e)
	if not bool(e.get("consumable", false)):
		ch.owned.append(entry_id)
	var events: Array[Dictionary] = [{"type": "exchange_done", "char": ch.id, "entry": entry_id, "payer": who.id, "price": (e["price"] as Dictionary).duplicate()}]
	if risky:
		if rng.chance(float(Pricing.rules()["mutation_chance"])):
			ch.flags["mutated"] = true
			events.append({"type": "bloodline_mutation", "char": ch.id})
		else:
			events.append({"type": "bloodline_safe", "char": ch.id})
	return events


## 把积木落到角色身上。B 级及以上的属性记在 enhanced_high（受基因锁发挥率影响）；A 级以上的新技能熟练度从低开始。
static func _apply(ch: RefCounted, e: Dictionary) -> void:
	var r := Pricing.rules()
	var tier := String(e["price"]["tier"])
	var high := Pricing.tier_rank(tier) >= Pricing.tier_rank(String(r["high_grade_from"]))
	var start_prof := float(r["new_high_skill_proficiency"]) if Pricing.tier_rank(tier) >= Pricing.tier_rank(String(r["low_proficiency_from"])) else 1.0
	for b: Dictionary in e["blocks"]:
		if b.has("attr"):
			for k: String in b["attr"]:
				if high:
					ch.attributes.add_enhanced_high(k, float(b["attr"][k]))
				else:
					ch.attributes.add_enhanced(k, float(b["attr"][k]))
		elif b.has("energy"):
			var pool := String(b["energy"])
			ch.energy[pool] = float(ch.energy.get(pool, 0.0)) + float(b["amount"])
		elif b.has("item"):
			var item := String(b["item"])
			ch.items[item] = float(ch.items.get(item, 0.0)) + float(b["count"])
		elif b.has("skill"):
			var s := String(b["skill"])
			if not ch.skills.has(s):
				ch.skills.append(s)
				ch.proficiency[s] = start_prof
		else:
			var a := String(b.get("ability", b.get("passive", b.get("side_effect", ""))))
			if a != "" and not ch.abilities.has(a):
				ch.abilities.append(a)
				ch.proficiency[a] = start_prof
	ch.hp = minf(ch.hp, ch.hp_max())
