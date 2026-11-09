extends RefCounted
## 一次远征（一部恐怖片）的控制器（设计规格第 5 节）。界面调用这里的行动，拿回一串事件来播放。
## 用法：
##   var ex := Expedition.new()
##   ex.start(game_state, Scenario.load_file(...), ["zheng_zha", ...])
##   ex.move("s1", "hall")；ex.search("s1")；ex.rest("s1", 30)；ex.split("s1", [...])；ex.leak("zheng_zha")
##   出现 battle_request 时：units = ex.battle_units(配装)，用 battle.gd 打完，再 ex.report_battle(battle)
##   outcome 不再是 ongoing 时：ex.finish() 结算
## 时间是全局的：任何分队的行动都推进同一个时钟，期间到点的剧情事件依次发生。
## 行动途中发生战斗时，行动被打断（移动没到达、搜索没完成），剩下的时间作废。

const ExpeditionState = preload("res://core/expedition/expedition_state.gd")
const Watch = preload("res://core/expedition/watch.gd")
const Persuasion = preload("res://core/expedition/persuasion.gd")
const PlotRunner = preload("res://core/expedition/plot_runner.gd")
const BattleReport = preload("res://core/expedition/battle_report.gd")
const ExpeditionSettlement = preload("res://core/expedition/expedition_settlement.gd")
const BattleData = preload("res://core/battle/battle_data.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
const Statuses = preload("res://core/battle/statuses.gd")
const KillReward = preload("res://core/economy/kill_reward.gd")
const Rules = preload("res://core/util/rules.gd")

var game: RefCounted
var st: RefCounted
## 主神眼中这支队伍的评价战力，用来算相对击杀奖励（以后由主神议程层给出）。
var rating_power: float = 120.0
var history: Array[Dictionary] = []


## options：rating_power（评价战力）。
func start(game_state: RefCounted, sc: RefCounted, member_ids: Array[String], options: Dictionary = {}) -> Array[Dictionary]:
	game = game_state
	st = ExpeditionState.new()
	st.setup(sc, game_state.characters, member_ids)
	rating_power = float(options.get("rating_power", Watch.rules()["default_rating_power"]))
	var events: Array[Dictionary] = [{"type": "expedition_start", "scenario": sc.id, "location": String(sc.data["start_location"])}]
	_run_time(0, events)
	return _emit(events)


func move(squad_id: String, to: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not _can_act(squad_id, events):
		return _emit(events)
	var from := String(st.squads[squad_id]["location"])
	var path: Dictionary = st.scenario.path_between(from, to)
	if path.is_empty() or not st.is_path_open(from, to):
		events.append({"type": "invalid_action", "reason": "no_path", "from": from, "to": to})
		return _emit(events)
	events.append({"type": "move_start", "squad": squad_id, "from": from, "to": to, "minutes": int(path["minutes"])})
	if _run_time(int(path["minutes"]), events):
		st.squads[squad_id]["location"] = to
		events.append({"type": "arrived", "squad": squad_id, "location": to, "clock": st.clock})
		Watch.check_tether(st, 0, events)
		PlotRunner.run_conditional(st, events)
	else:
		events.append({"type": "move_interrupted", "squad": squad_id})
	return _emit(events)


## 搜索当前地点。每个地点只能搜一次，找到的东西放进分队的道具里。
func search(squad_id: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not _can_act(squad_id, events):
		return _emit(events)
	var loc := String(st.squads[squad_id]["location"])
	if st.searched.has(loc):
		events.append({"type": "already_searched", "location": loc})
		return _emit(events)
	var info: Dictionary = st.scenario.location(loc)
	var minutes := int(info.get("search_minutes", Watch.rules()["default_search_minutes"]))
	if _run_time(minutes, events):
		st.searched[loc] = true
		var items: Dictionary = st.squads[squad_id]["items"]
		var found: Array = []
		for f: Dictionary in info.get("search", []):
			var item := String(f["item"])
			items[item] = float(items.get(item, 0.0)) + float(f["count"])
			found.append({"item": item, "count": int(f["count"])})
		events.append({"type": "searched", "squad": squad_id, "location": loc, "found": found})
		var enc: Dictionary = info.get("search_encounter", {})
		if st.pending_battle.is_empty() and not enc.is_empty() and game.rng.chance(float(enc.get("chance", 0.0))):
			st.pending_battle = {
				"location": loc,
				"squad": squad_id,
				"enemies": (enc["enemies"] as Array).duplicate(true),
				"dark": Watch.is_dark(st, loc),
				"survive_until": -1.0,
				"after_victory": [],
				"after_defeat": [],
			}
			events.append({"type": "search_encounter", "location": loc, "text": String(enc.get("intro", ""))})
			events.append({"type": "battle_request", "location": loc, "squad": squad_id, "dark": bool(st.pending_battle["dark"])})
	return _emit(events)


## 原地休息 minutes 分钟，恐惧下降。
func rest(squad_id: String, minutes: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not _can_act(squad_id, events):
		return _emit(events)
	if _run_time(minutes, events):
		var rate := float(Watch.rules()["rest_fear_per_10_minutes"])
		for c in st.living_members(squad_id):
			var d := Watch.add_fear(st.characters[c], rate * float(minutes) / 10.0)
			if d != 0.0:
				events.append({"type": "fear_changed", "char": c, "amount": d, "fear": st.characters[c].fear, "reason": "rest"})
	return _emit(events)


func split(squad_id: String, member_ids: Array[String]) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not _can_act(squad_id, events):
		return _emit(events)
	var new_id: String = st.split(squad_id, member_ids)
	if new_id == "":
		events.append({"type": "invalid_action", "reason": "bad_split"})
	else:
		events.append({"type": "squad_split", "from": squad_id, "squad": new_id, "members": member_ids.duplicate()})
	return _emit(events)


func merge(a: String, b: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not _can_act(a, events):
		return _emit(events)
	if st.merge(a, b):
		events.append({"type": "squads_merged", "squad": a, "merged": b})
	else:
		events.append({"type": "invalid_action", "reason": "bad_merge"})
	return _emit(events)


## 某人说出了主神的信息（对话层判定后调用）。
func leak(char_id: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if st.outcome == "ongoing" and st.is_alive(char_id):
		Watch.leak(st, char_id, events)
	return _emit(events)


## 对话、说服、AI 判定之类的结果以效果的形式落地（例如提醒大家有陷阱 → set_flag）。
func apply_effects(effects: Array, location: String = "") -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if st.outcome != "ongoing":
		events.append({"type": "invalid_action", "reason": "ended"})
		return _emit(events)
	PlotRunner.apply_effects(st, effects, location, events)
	PlotRunner.run_conditional(st, events)
	return _emit(events)


## 为待打的战斗生成单位。loadouts：角色 id → 技能 id 数组（没给的用角色自己的技能，什么都没有就只会拳脚）。
## 每个人带着自己的能量和道具；分队共用的道具交给第一个人携带；每排最多 4 人，多出来的往后排。
func battle_units(loadouts: Dictionary, controller: String = "player") -> Array[RefCounted]:
	var units: Array[RefCounted] = []
	if st.pending_battle.is_empty():
		return units
	var sid := String(st.pending_battle["squad"])
	var members: Array[String] = st.living_members(sid)
	for i in members.size():
		var c := members[i]
		var ch: RefCounted = st.characters[c]
		var skills: Array[String] = []
		var own_skills: Array = ch.skills if not ch.skills.is_empty() else ["punch"]
		for s in loadouts.get(c, own_skills):
			skills.append(String(s))
		var res: Dictionary = ch.battle_resources()
		if i == 0:
			for k: String in st.squads[sid]["items"]:
				res[k] = float(res.get(k, 0.0)) + float(st.squads[sid]["items"][k])
		units.append(UnitFactory.from_character(ch, "ally", mini(floori(i / 4.0), 2), skills, controller, res))
	st.pending_battle["carrier"] = members[0] if not members.is_empty() else ""
	var n := 0
	for g: Dictionary in st.pending_battle["enemies"]:
		for k in int(g.get("count", 1)):
			n += 1
			var row := mini(int(g.get("row", 0)) + floori(k / 4.0), 2)
			units.append(UnitFactory.from_enemy(String(g["def"]), "%s_%d" % [g["def"], n], row))
	return units


func battle_options() -> Dictionary:
	var out := {"dark": bool(st.pending_battle.get("dark", false)), "intel": _intel_level()}
	if st.pending_battle.has("survive_until"):
		out["survive_until"] = float(st.pending_battle["survive_until"])
	return out


## 队伍里最聪明的人能看穿多少敌人意图（0~2）。
func _intel_level() -> int:
	var best := 0.0
	for c: String in st.all_living():
		best = maxf(best, float(st.characters[c].attributes.total("intelligence")))
	if best >= 160.0:
		return 2
	if best >= 110.0:
		return 1
	return 0


## 战斗打完后回报：写回轮回者的生命、恐惧、基因锁、生死和剩余道具（用掉的先扣分队共用的）；记击杀奖励；杀死新人扣 1000 点；
## 带着感染下场的人开始感染倒计时；逃离战场的人往离绑定对象最远的相邻地点跑；最后发生战斗后效果（after_victory / after_defeat）。
func report_battle(b: RefCounted) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if st.pending_battle.is_empty():
		events.append({"type": "invalid_action", "reason": "no_battle"})
		return _emit(events)
	var sid := String(st.pending_battle["squad"])
	var carrier := String(st.pending_battle.get("carrier", ""))
	for u: RefCounted in b.field.units:
		if u.side != "ally" or not st.characters.has(u.character_id):
			continue
		var ch: RefCounted = st.characters[u.character_id]
		UnitFactory.write_back(u, ch)
		_settle_items(u, ch, sid if u.character_id == carrier else "")
		if u.alive and Statuses.has(u, "infection") and not st.infected.has(ch.id):
			st.infected[ch.id] = 0
			events.append({"type": "infected", "char": ch.id})
	var summary := BattleReport.summarize(b.history, b.field.units)
	for k: Dictionary in summary["kills"]:
		var killer := String(k["killer"])
		if not st.characters.has(killer):
			continue
		var def := BattleData.enemy(String(k["def_id"]))
		var pts := KillReward.points_for_kill(float(def.get("kill_base", 0.0)), float(def.get("threat", 0.0)), rating_power)
		st.kill_points[killer] = float(st.kill_points.get(killer, 0.0)) + pts
		st.kill_counts[killer] = int(st.kill_counts.get(killer, 0)) + 1
		events.append({"type": "kill_recorded", "char": killer, "enemy": String(k["def_id"]), "points": pts})
	for d: Dictionary in summary["deaths"]:
		var victim := String(d["id"])
		var killer := String(d["killer"])
		if st.characters.has(victim) and st.characters.has(killer) and killer != victim and st.characters[victim].is_newbie():
			st.add_ledger(killer, "penalty", float(Rules.get_value("settlement", "kill_newbie")), "杀死新人")
			events.append({"type": "kill_newbie_penalty", "char": killer, "victim": victim})
	for f: String in summary["fled"]:
		if st.is_alive(f):
			_flee(f, events)
	var loc := String(st.pending_battle["location"])
	var won := ["victory", "survived"].has(String(b.outcome))
	var after: Array = st.pending_battle.get("after_victory" if won else "after_defeat", [])
	st.pending_battle = {}
	events.append({"type": "battle_resolved", "outcome": String(b.outcome)})
	Watch.check_wipe(st, events)
	PlotRunner.apply_effects(st, after, loc, events)
	PlotRunner.run_conditional(st, events)
	return _emit(events)


## 道具结算：战斗里用掉的数量先从分队共用的扣，再从自己的扣。
func _settle_items(u: RefCounted, ch: RefCounted, squad_id: String) -> void:
	var shared: Dictionary = st.squads[squad_id]["items"] if squad_id != "" else {}
	var keys: Array = ch.items.keys()
	for k: String in shared:
		if not keys.has(k):
			keys.append(k)
	for k: String in keys:
		var own := float(ch.items.get(k, 0.0))
		var common := float(shared.get(k, 0.0))
		var used := maxf(0.0, own + common - float(u.resources.get(k, own + common)))
		var from_common := minf(used, common)
		if squad_id != "":
			if common - from_common > 0.0:
				shared[k] = common - from_common
			else:
				shared.erase(k)
		var own_left := own - (used - from_common)
		if own_left > 0.0:
			ch.items[k] = own_left
		else:
			ch.items.erase(k)


## 逃离战场：往相邻地点里离绑定对象最远的那个跑（没有绑定就跑第一个相邻地点），可能因此被抹杀。
func _flee(char_id: String, events: Array[Dictionary]) -> void:
	var options: Array[String] = st.scenario.neighbors(st.location_of(char_id))
	if options.is_empty():
		return
	var best := options[0]
	if not st.tether.is_empty():
		var npc_loc := String(st.npcs[String(st.tether["npc"])]["location"])
		var best_d := -1
		for n in options:
			var d: int = st.scenario.hops(n, npc_loc)
			if d > best_d:
				best_d = d
				best = n
	st.move_members([char_id], best)
	events.append({"type": "fled_away", "char": char_id, "to": best})
	Watch.check_tether(st, 0, events)


## 回答等待中的选择。
func choose(option_id: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if st.outcome != "ongoing" or st.pending_choice.is_empty():
		events.append({"type": "invalid_action", "reason": "no_choice"})
		return _emit(events)
	if not st.pending_check.is_empty():
		events.append({"type": "invalid_action", "reason": "check_pending"})
		return _emit(events)
	var pending: Dictionary = st.pending_choice
	var picked: Dictionary = {}
	for o: Dictionary in pending["options"]:
		if o["id"] == option_id:
			picked = o
	if picked.is_empty():
		events.append({"type": "invalid_action", "reason": "bad_option"})
		return _emit(events)
	st.pending_choice = {}
	events.append({"type": "choice_made", "id": String(pending["id"]), "option": option_id})
	PlotRunner.apply_effects(st, picked.get("effects", []), String(pending["location"]), events)
	PlotRunner.run_conditional(st, events)
	return _emit(events)


## 现在能不能开口：有等待中的说服、说的人活着、要的证据（requires_fact）已经有了。
## 返回 {"ok", "check"} 或 {"ok": false, "reason", "fact"}。
func can_persuade(thinker_id: String) -> Dictionary:
	if st.outcome != "ongoing" or st.pending_check.is_empty():
		return {"ok": false, "reason": "no_check"}
	if not st.is_alive(thinker_id):
		return {"ok": false, "reason": "no_thinker"}
	var check: Dictionary = st.pending_check
	var fact := String(check.get("requires_fact", ""))
	if fact != "":
		var s: String = st.intel.status(fact)
		if s != "inferred" and s != "confirmed":
			return {"ok": false, "reason": "no_fact", "fact": fact}
	return {"ok": true, "check": check}


## 用关键词说服：把"说了什么"交给 persuasion.gd 折算成 0~3 级，再走 resolve_persuasion。
## 需要先推理出 requires_fact 指定的事实；没有推论时按失败处理，并报告 persuade_blocked。
func persuade_with(keywords: Array, thinker_id: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if st.outcome != "ongoing" or st.pending_check.is_empty():
		events.append({"type": "invalid_action", "reason": "no_check"})
		return _emit(events)
	if not st.is_alive(thinker_id):
		events.append({"type": "invalid_action", "reason": "no_thinker"})
		return _emit(events)
	var check: Dictionary = st.pending_check
	var level := Persuasion.level(check, keywords, st.characters[thinker_id], st.intel)
	if level >= 0:
		return resolve_persuasion(level)
	st.pending_check = {}
	events.append({"type": "persuade_blocked", "id": String(check["id"]), "npc": String(check["npc"]), "fact": String(check.get("requires_fact", ""))})
	PlotRunner.apply_effects(st, check.get("failure", []), String(check.get("location", "")), events)
	PlotRunner.run_conditional(st, events)
	return _emit(events)


## 说服检定：level 是对话层（AI 或离线兜底）给的说服力等级 0~3。高于难度必成，等于难度一半机会，低于难度失败。
func resolve_persuasion(level: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if st.outcome != "ongoing" or st.pending_check.is_empty():
		events.append({"type": "invalid_action", "reason": "no_check"})
		return _emit(events)
	var check: Dictionary = st.pending_check
	var difficulty := int(check["difficulty"])
	var success: bool = level > difficulty or (level == difficulty and game.rng.chance(float(Watch.rules()["persuade_even_chance"])))
	st.pending_check = {}
	events.append({"type": "persuade_result", "id": String(check["id"]), "npc": String(check["npc"]), "level": level, "difficulty": difficulty, "success": success})
	PlotRunner.apply_effects(st, check.get("success" if success else "failure", []), String(check["location"]), events)
	PlotRunner.run_conditional(st, events)
	return _emit(events)


## 使用道具（解毒剂解除感染、止血喷雾回血）。先用自己的，没有再用分队共用的。
func use_item(char_id: String, item: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var def: Dictionary = (Watch.rules()["items"] as Dictionary).get(item, {})
	if st.outcome != "ongoing" or not st.is_alive(char_id) or def.is_empty():
		events.append({"type": "invalid_action", "reason": "cannot_use"})
		return _emit(events)
	var ch: RefCounted = st.characters[char_id]
	var shared: Dictionary = st.squads[st.squad_of(char_id)]["items"]
	var pool: Dictionary = ch.items if float(ch.items.get(item, 0.0)) >= 1.0 else shared
	if float(pool.get(item, 0.0)) < 1.0:
		events.append({"type": "invalid_action", "reason": "no_item"})
		return _emit(events)
	pool[item] = float(pool[item]) - 1.0
	if float(pool[item]) <= 0.0:
		pool.erase(item)
	if bool(def.get("cure_infection", false)):
		st.infected.erase(char_id)
	if def.has("heal"):
		ch.hp = minf(ch.hp + float(def["heal"]), ch.hp_max())
	events.append({"type": "item_used", "char": char_id, "item": item, "hp": ch.hp, "infected": st.infected.has(char_id)})
	return _emit(events)


## 推理一条隐藏事实：花 deduce_minutes 分钟，结论和可信度见 intel_state.gd。
func deduce(fact_id: String, thinker_id: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not st.is_alive(thinker_id):
		events.append({"type": "invalid_action", "reason": "no_thinker"})
		return _emit(events)
	if not _can_act(st.squad_of(thinker_id), events):
		return _emit(events)
	if _run_time(int(Watch.rules()["deduce_minutes"]), events):
		events.append(st.intel.deduce(fact_id, st.characters[thinker_id], game.rng.randf()))
	return _emit(events)


## 插图播完：清掉等待，继续条件事件。界面在没有这张图时也应调它，避免卡住。
func dismiss_cutscene() -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if st.pending_cutscene.is_empty():
		return _emit(events)
	var name := String(st.pending_cutscene.get("name", ""))
	st.pending_cutscene = {}
	events.append({"type": "cutscene_dismissed", "name": name})
	PlotRunner.run_conditional(st, events)
	return _emit(events)


## 远征结束（回归、全灭或剧本给的结局）后结算，只能结算一次。返回 角色 id → 结算结果。
func finish() -> Dictionary:
	if st.outcome == "ongoing" or st.settled:
		return {}
	var results := ExpeditionSettlement.settle_all(st)
	game.films_record.append(st.scenario.id)
	_emit([{"type": "settled", "outcome": st.outcome}])
	return results


func watch_view(char_id: String) -> Dictionary:
	return Watch.view(st, char_id)


func to_dict() -> Dictionary:
	return {"state": st.to_dict(), "rating_power": rating_power}


func load_dict(d: Dictionary, game_state: RefCounted, sc: RefCounted) -> void:
	game = game_state
	st = ExpeditionState.new()
	st.load_dict(d["state"], sc, game_state.characters)
	rating_power = float(d["rating_power"])


func _emit(events: Array[Dictionary]) -> Array[Dictionary]:
	history.append_array(events)
	return events


func _can_act(squad_id: String, events: Array[Dictionary]) -> bool:
	var reason := ""
	if st.outcome != "ongoing":
		reason = "ended"
	elif not st.pending_cutscene.is_empty():
		reason = "cutscene_pending"
	elif not st.pending_battle.is_empty():
		reason = "battle_pending"
	elif not st.pending_check.is_empty():
		reason = "check_pending"
	elif not st.pending_choice.is_empty():
		reason = "choice_pending"
	elif not st.squads.has(squad_id) or st.living_members(squad_id).is_empty():
		reason = "no_squad"
	if reason != "":
		events.append({"type": "invalid_action", "reason": reason})
		return false
	return true


## 推进 minutes 分钟：途中到点的定时事件依次发生，每次之后检查条件事件。
## 返回 true 表示时间完整走完；被战斗、选择、说服打断或远征结束返回 false。
func _run_time(minutes: int, events: Array[Dictionary]) -> bool:
	var target: int = st.clock + minutes
	while st.outcome == "ongoing":
		var ev := PlotRunner.next_timed(st)
		if ev.is_empty() or int(ev["at"]) > target:
			break
		Watch.pass_time(st, int(ev["at"]) - st.clock, events)
		if st.outcome != "ongoing":
			return false
		PlotRunner.fire(st, ev, events)
		PlotRunner.run_conditional(st, events)
		if st.is_blocked():
			return false
	Watch.pass_time(st, target - st.clock, events)
	PlotRunner.run_conditional(st, events)
	return st.outcome == "ongoing" and not st.is_blocked()
