# 计划 14：天赋觉醒与主神议程接线 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补上 M1 核查发现的两块规则缺口：天赋字段对不上、天赋没有任何机制作用；主神议程从来没被创建过（没有张杰的半引导者异常、片后不调评价、郑吒造萝丽不会潜力突升、恶魔小队复制体缺失）。

**Architecture:** 新增 `core/model/talents.gd` + `data/characters/talents.json`，统一回答"这个人有没有某天赋、什么时候觉醒、觉醒后有什么效果"；兑换门槛、推理、规则发现改用它。主神议程挂到 `GameState.agenda`，随存档走；章节 JSON 新增可选的 `agenda` 块，开局由 `Campaign.apply_agenda` 写入；`Session.settle()` 调 `Agenda.update_rating` 并把总评存进 `film_report`；`Hub.create_human` 记潜力突升、够大就复制进恶魔小队。天赋的触发点集中在两处：`Expedition._emit`（剧情旗标、同伴死亡、只剩一半人）+ `report_battle`（战后濒死、战斗里的死亡），`Hub`（兑换、强化属性、训练、对练）。界面只显示觉醒结果和评价变化。

**Tech Stack:** Godot 4.7.2（GDScript）、JSON 数据、现有 `Agenda`/`Expedition`/`Hub` 规则层。

**依据：** 设计规格 1.2（M1：主神议程状态、郑吒造萝丽 → 潜力突升 → 复制进恶魔小队）、3.6（天赋与发挥条件、天赋契合可绕过门槛）、3.7（天赋觉醒不计入主神评价）、5.5（议程层、主神理由）、7.3（评价的变化）。

**本计划已在临时目录跑通：414 个无界面测试全过、`SCRIPT ERROR 0`、M1 切片验收 0 失败、40 局随机乱玩无卡死。**

**执行环境注意：**
- 仓库根目录：`I:\workspace\mobilegame\wuxian-kongbu\`；命令都在仓库根目录执行（Git Bash）。
- 只跑某个测试：`WSLENV=TEST_FILTER TEST_FILTER=<文件名> bash game/tools/run_tests.sh`。
- 文本文件 **LF**、UTF-8 无 BOM；GDScript 用 **Tab**。
- 跑测试不生成 `.gd.uid`，导入工程（Task 3）才会。
- **只提交，不推送。**
- 临时验证目录是 `_work/plan_check_p14/game`。
- **切片验收会清空 `user://` 下的三个存档槽**，所以只在改了工程名的副本里跑（Task 3 Step 5），不在仓库工程里跑。

---

## 设计要点

- **字段统一**：人物表写的是 `flags.talent`（一个 id），代码一直读 `flags.talents`（数组），所以天赋从来没生效过；目录里精神力扫描的绕过天赋又写成 `spirit_talent`，而詹岚的天赋 id 是 `psychic`。`Talents.ids()` 两种写法都认，目录改成 `psychic`。
- **契合不等于觉醒**：天赋本身就能绕过兑换项写明的素质门槛（规格 3.6 "天赋契合"）；觉醒是另一回事，要满足发挥条件，觉醒后一次性加锻炼属性（主神看不见，规格 3.7）、降恐惧，或者给"学得快"这种长期倍率。
- **触发条件都能在规则层判定**：`near_death`（战后活着、生命 ≤ 25%）、`ally_died`（同地点的同伴死了或被抹杀）、`team_peril`（活着的只剩一半或更少）、`bought_series:<系列>` / `bought_attr:<属性>`、`trained`、`flag:<旗标>`。七个人的条件按人物表的描述落到这几种上：郑吒"不屈"= 濒死或同伴死在面前；张杰"半引导者"= 队伍面临团灭；詹岚"精神力天赋"= 兑换精神类强化或绝境；李萧毅"学得快"= 训练过；牟钢"老司机"= 被逼到绝路（M1 没有方向盘，人物表描述同步补上）；小胖子、中年妇女 = 队伍停下来扶他们。
- **主神议程的位置**：议程和评价一样是跨片的整局状态，所以放进 `GameState`；旧存档没有 `agenda` 字段时新建一份，不改存档版本号。
- **评价规则不变，只是终于被调用**：按章节 `agenda.expected_wipe`（M1 = 按团灭安排）和存活人数调用已有的 `Agenda.update_rating`。原著三人活下来（3/7 < 0.7）评价不变；七人全活 +1，下一部的评价战力随之上升。
- **恶魔小队复制是隐藏的**：造人只给玩家发 `human_created`；潜力突升和复制只写进议程的决定记录（带主神理由），M7 才揭晓。每个制造者只有第一个造物算突升。
- **觉醒也是潜力突升**（每次 0.1，低于复制门槛 0.2），主神看得见"这个人在长"。

**不在本计划范围**：关系网与服从、规则百科与规则发现的接线（计划 15）；兑换目录扩到约 200 条（计划 16）；萝丽陪伴、晨会、铁人模式（计划 17）；像素战斗画面（计划 18）；文档对齐、平衡、`tr()`（计划 19）。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `game/data/characters/talents.json` | 七种天赋的名字、觉醒条件、效果、旁白 |
| `game/core/model/talents.gd` | 有没有某天赋、是否觉醒、触发觉醒、训练倍率、记进议程 |
| `game/core/hub/exchange.gd` | 素质门槛的天赋绕过改用 `Talents.has` |
| `game/core/intel/intel_state.gd` | 推理里的"天才"改用 `Talents.has` |
| `game/core/intel/rule_discovery.gd` | 规则发现的天赋要求改用 `Talents.has` |
| `game/data/hub/exchange_catalog.json` | 精神力扫描的绕过天赋改成 `psychic` |
| `game/data/characters/m1_roster.json` | 牟钢的发挥条件补"被逼到绝路" |
| `game/core/director/agenda.gd` | 异常记在谁身上；按种类和人查开着的异常 |
| `game/data/director/director_rules.json` | 造人的潜力突升量 0.25 |
| `game/core/model/game_state.gd` | `agenda` 字段，随存档走 |
| `game/core/campaign/campaign.gd` | `apply_agenda`：章节议程块写进议程 |
| `game/data/scenarios/biohazard1/chapter.json` | M1 议程：按团灭安排、张杰的半引导者异常、按张杰定难度 |
| `game/core/session/session.gd` | 结算时调评价、记"继续加压"、`film_report` 存档 |
| `game/core/hub/hub.gd` | 兑换/强化/训练/对练触发天赋；造人突升与恶魔小队复制 |
| `game/core/expedition/expedition.gd` | 远征里的天赋触发点 |
| `game/ui/hub/hub_view.gd`、`game/ui/hub/hub_screen.gd` | 人物卡显示已觉醒的天赋；操作结果里带觉醒提示 |
| `game/ui/event_text.gd` | 觉醒的中文文案 |
| `game/ui/main.gd` | 结算界面显示幸存人数和评价变化 |

---

## Task 1：天赋判定与契合门槛

**Files:**
- Create: `game/data/characters/talents.json`、`game/core/model/talents.gd`
- Modify: `game/core/hub/exchange.gd`、`game/core/intel/intel_state.gd`、`game/core/intel/rule_discovery.gd`、`game/data/hub/exchange_catalog.json`、`game/data/characters/m1_roster.json`
- Test: `game/tests/unit/hub/test_exchange.gd`

- [ ] **Step 1：改写 `game/tests/unit/hub/test_exchange.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const Exchange = preload("res://core/hub/exchange.gd")
const Rng = preload("res://core/util/rng.gd")


func _rich(id: String = "zheng_zha") -> RefCounted:
	var c := Character.new(id, id, {})
	c.points = 20000
	c.tickets.add("D", 3)
	c.tickets.add("C", 3)
	c.tickets.add("B", 3)
	return c


## 郑吒的第一次兑换（原著）：低级气功 500+D、血族男爵 800+D。
func test_buy_qigong_low() -> void:
	var c := _rich()
	var events := Exchange.buy(c, "qigong_low", Rng.new(1))
	assert_eq(events[0]["type"], "exchange_done")
	assert_eq(c.points, 19500)
	assert_eq(int(c.tickets.counts["D"]), 2)
	assert_almost(c.attributes.total("muscle"), 130.0)
	assert_almost(float(c.energy["neili"]), 30.0)
	assert_eq(c.owned, ["qigong_low"] as Array[String])


## B 级的属性按基因锁发挥率打折：0 阶只发挥 50%。
func test_b_grade_attributes_use_gene_lock() -> void:
	var c := _rich()
	Exchange.buy(c, "spider_gene", Rng.new(1))
	assert_almost(c.attributes.total("nerve_reaction"), 100.0 + 50.0)
	c.gene_lock_stage = 4
	assert_almost(c.attributes.total("nerve_reaction"), 200.0)
	assert_true(c.abilities.has("spider_silk"))


func test_refusal_reasons() -> void:
	var poor := Character.new("p", "p", {})
	var r := Exchange.check(poor, "qigong_mid")
	assert_false(bool(r["ok"]))
	assert_true((r["reasons"] as Array).has("not_enough_points"))
	assert_true((r["reasons"] as Array).has("missing_ticket"))
	assert_true((r["reasons"] as Array).has("missing_prerequisite:qigong_low"))
	assert_eq(Exchange.check(poor, "nope")["reasons"], ["unknown_entry"])
	var events := Exchange.buy(poor, "qigong_mid", Rng.new(1))
	assert_eq(events[0]["type"], "exchange_refused")
	assert_eq(poor.points, 0)


## 纳戒需要内力。
func test_needs_energy() -> void:
	var c := _rich()
	assert_eq(Exchange.check(c, "na_ring")["reasons"], ["needs_energy:neili"])
	Exchange.buy(c, "qigong_low", Rng.new(1))
	assert_true(bool(Exchange.check(c, "na_ring")["ok"]))


## 素质门槛，有对应天赋的人可以绕过（詹岚的精神力天赋）。
func test_gate_and_talent_bypass() -> void:
	var c := _rich()
	assert_eq(Exchange.check(c, "mind_scan")["reasons"], ["gate:spirit"])
	c.flags["talent"] = "psychic"
	assert_true(bool(Exchange.check(c, "mind_scan")["ok"]), "人物表写法：詹岚的精神力天赋绕过精神力门槛")
	var d := _rich()
	d.flags["talents"] = ["psychic"]
	assert_true(bool(Exchange.check(d, "mind_scan")["ok"]), "数组写法也认")


func test_no_duplicates_but_consumables_stack() -> void:
	var c := _rich()
	Exchange.buy(c, "desert_eagle", Rng.new(1))
	assert_eq(Exchange.check(c, "desert_eagle")["reasons"], ["already_owned"])
	assert_true(c.skills.has("desert_eagle"))
	Exchange.buy(c, "grenade", Rng.new(1))
	Exchange.buy(c, "grenade", Rng.new(1))
	assert_almost(float(c.items["grenade"]), 2.0)
	assert_false(c.owned.has("grenade"))


func test_double_b_ticket() -> void:
	var c := _rich()
	Exchange.buy(c, "rebirth_cross", Rng.new(1))
	assert_eq(c.points, 13000)
	assert_eq(int(c.tickets.counts["B"]), 1)
	assert_almost(float(c.battle_resources()["rebirth_cross"]), 1.0)


## 前置链：男爵 → 子爵 → 伯爵；同一系列不算双血统。
func test_bloodline_chain_no_risk() -> void:
	var c := _rich()
	Exchange.buy(c, "vampire_baron", Rng.new(1))
	Exchange.buy(c, "vampire_viscount", Rng.new(1))
	var r := Exchange.check(c, "vampire_count")
	assert_true(bool(r["ok"]))
	assert_eq(r["warnings"], [])


## 双血统：先警告不兑换；坚持兑换时按 70% 结算变异。
func test_second_bloodline_warns_then_rolls() -> void:
	var mutated := 0
	for s in 20:
		var c := _rich()
		Exchange.buy(c, "vampire_baron", Rng.new(s))
		var warn := Exchange.buy(c, "spider_gene", Rng.new(s))
		assert_eq(warn[0]["type"], "exchange_warning")
		assert_false(c.owned.has("spider_gene"))
		var events := Exchange.buy(c, "spider_gene", Rng.new(s), {"accept_risk": true})
		assert_true(c.owned.has("spider_gene"))
		if events[1]["type"] == "bloodline_mutation":
			mutated += 1
			assert_true(bool(c.flags["mutated"]))
	assert_true(mutated >= 8 and mutated <= 19, "20 次里变异 %d 次" % mutated)


## 代兑：别人付钱；付钱的人这次已经给过别人就不行。
func test_gift() -> void:
	var giver := _rich("zhang_jie")
	var newbie := Character.new("newbie", "新人", {})
	var events := Exchange.buy(newbie, "qigong_low", Rng.new(1), {"payer": giver})
	assert_eq(events[0]["payer"], "zhang_jie")
	assert_eq(giver.points, 19500)
	assert_eq(newbie.points, 0)
	assert_true(newbie.owned.has("qigong_low"))
	assert_eq(Exchange.check(newbie, "vampire_baron", giver, true)["reasons"], ["gift_used"])
```

- [ ] **Step 2：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_exchange bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`FAIL  test_exchange.gd::test_gate_and_talent_bypass`（目录还写着 `spirit_talent`，人物表写法也不认）。

- [ ] **Step 3：创建 `game/data/characters/talents.json`**

```json
{
	"version": 1,
	"near_death_ratio": 0.25,
	"awaken_spike": 0.1,
	"talents": {
		"iron_will": {
			"name": "不屈",
			"triggers": ["near_death", "ally_died"],
			"text": "眼看着同伴倒下，他反而稳住了。",
			"effect": {"attr": {"spirit": 15, "nerve_reaction": 10}, "fear_relief": 30}
		},
		"half_guide": {
			"name": "半引导者",
			"triggers": ["team_peril"],
			"text": "队伍快撑不住了，他终于不再藏着。",
			"effect": {"attr": {"nerve_reaction": 15, "muscle": 15}, "fear_relief": 20}
		},
		"psychic": {
			"name": "精神力天赋",
			"triggers": ["bought_attr:spirit", "bought_series:psionic", "team_peril"],
			"text": "精神力像被点着了，四周的动静一下子清楚起来。",
			"effect": {"attr": {"spirit": 40}}
		},
		"quick_learner": {
			"name": "学得快",
			"triggers": ["trained"],
			"text": "有人带着练过一遍，他就上手了。",
			"effect": {"train_mult": 2.0}
		},
		"wheelman": {
			"name": "老司机",
			"triggers": ["near_death"],
			"text": "被逼到绝路，他握拳的手反而稳了。",
			"effect": {"attr": {"nerve_reaction": 15}, "fear_relief": 25}
		},
		"lucky": {
			"name": "傻人有傻福",
			"triggers": ["flag:helped_lagging"],
			"text": "被人扶着走，他忽然觉得没那么怕了。",
			"effect": {"attr": {"immunity": 15, "cell_vitality": 10}, "fear_relief": 15}
		},
		"calm_voice": {
			"name": "稳住人心",
			"triggers": ["flag:helped_lagging"],
			"text": "队伍肯停下来等她，她开口把大家安抚住了。",
			"effect": {"attr": {"spirit": 10}, "fear_relief": 15, "team_fear_relief": 10}
		}
	}
}
```

- [ ] **Step 4：创建 `game/core/model/talents.gd`**

```gdscript
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
```

- [ ] **Step 5：改写 `game/core/hub/exchange.gd`**

```gdscript
extends RefCounted
## 在主神处兑换（设计规格 6.2~6.3）。先核对门槛，不满足时主神说明原因；满足就扣点数和支线、把积木落到角色身上。
## 门槛：点数、支线、前置（高一级要先有同系低一级）、能量类型（纳戒要内力）、素质门槛（契合的天赋可绕过，见 talents.gd）、不能重复兑换。
## 代兑：可以用别人的点数和支线给自己兑换，每人每次休整只能给别人一次（由 hub.gd 记录，这里只看传进来的 gift_used）。
## 双血统：已有别的系列的血统再兑换血统，主神先警告；坚持兑换时 70% 变成非人（flags.mutated）。

const Catalog = preload("res://core/hub/catalog.gd")
const Pricing = preload("res://core/hub/pricing.gd")
const Talents = preload("res://core/model/talents.gd")


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
	var talented := Talents.has(ch, bypass)
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
```

- [ ] **Step 6：改写 `game/core/intel/intel_state.gd`**

```gdscript
extends RefCounted
## 信息模型（设计规格 3.8，核心机制分析 9.3A、9.4）：每条隐藏事实对队伍有四种状态——
##   unknown（未知）→ hinted（有线索）→ inferred（有推论，带可信度）→ confirmed（已确认）。
## 智者用线索做推理，得出推论和可信度；推论可能是错的。两个智者结论一致时可信度叠加，不一致时标成"有争议"。
## 事实的定义来自剧本：{"statement", "domain", "truth", "difficulty", "clues": {线索 id: 权重}}。
## 随机数由调用方传入（roll 在 0~1 之间）。

const Talents = preload("res://core/model/talents.gd")

var facts: Dictionary = {}
var clues_found: Dictionary = {}
## 事实 id → {"conclusion": bool, "confidence": float, "by": [角色 id], "contested": bool}
var inferences: Dictionary = {}
## 事实 id → 真相
var confirmed: Dictionary = {}


func load_facts(defs: Dictionary) -> void:
	facts = defs.duplicate(true)


func status(fact_id: String) -> String:
	if confirmed.has(fact_id):
		return "confirmed"
	if inferences.has(fact_id):
		return "inferred"
	if clue_weight(fact_id) > 0.0:
		return "hinted"
	return "unknown"


## 已找到的线索权重之和，最多算 1。
func clue_weight(fact_id: String) -> float:
	var w := 0.0
	var clues: Dictionary = facts[fact_id].get("clues", {})
	for c: String in clues:
		if clues_found.has(c):
			w += float(clues[c])
	return minf(w, 1.0)


func add_clue(clue_id: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if clues_found.has(clue_id):
		return events
	clues_found[clue_id] = true
	events.append({"type": "clue_found", "clue": clue_id})
	for f: String in facts:
		if (facts[f].get("clues", {}) as Dictionary).has(clue_id):
			events.append({"type": "fact_hinted", "fact": f})
	return events


## 推理准确度：0.3 + (智力 − 100) / 400 + 线索 × 0.4 + 领域熟悉度 × 0.2 + 天才 0.1 − 难度 × 0.3，限制在 0.05~0.97。
## 领域熟悉度在 flags.domains 里（0~1），天才是天赋 "genius"（见 talents.gd）。
static func accuracy(thinker: RefCounted, fact: Dictionary, clue_w: float) -> float:
	var a := 0.3
	a += (thinker.attributes.total("intelligence") - 100.0) / 400.0
	a += clue_w * 0.4
	a += float((thinker.flags.get("domains", {}) as Dictionary).get(String(fact.get("domain", "")), 0.0)) * 0.2
	if Talents.has(thinker, "genius"):
		a += 0.1
	a -= float(fact.get("difficulty", 0.0)) * 0.3
	return clampf(a, 0.05, 0.97)


## 推理一条事实。roll < 准确度时得出正确结论，否则得出相反的结论；智者自己报的可信度就是准确度。
func deduce(fact_id: String, thinker: RefCounted, roll: float) -> Dictionary:
	if confirmed.has(fact_id):
		return {"type": "deduce_skipped", "fact": fact_id, "reason": "confirmed"}
	var w := clue_weight(fact_id)
	if w <= 0.0:
		return {"type": "deduce_skipped", "fact": fact_id, "reason": "no_clues"}
	var fact: Dictionary = facts[fact_id]
	var acc := accuracy(thinker, fact, w)
	var conclusion: bool = bool(fact["truth"]) if roll < acc else not bool(fact["truth"])
	var inf: Dictionary = inferences.get(fact_id, {})
	if inf.is_empty():
		inf = {"conclusion": conclusion, "confidence": acc, "by": [thinker.id], "contested": false}
	elif bool(inf["conclusion"]) == conclusion:
		inf["confidence"] = 1.0 - (1.0 - float(inf["confidence"])) * (1.0 - acc)
		(inf["by"] as Array).append(thinker.id)
	else:
		inf["contested"] = true
		(inf["by"] as Array).append(thinker.id)
		if acc > float(inf["confidence"]):
			inf["conclusion"] = conclusion
			inf["confidence"] = acc
	inferences[fact_id] = inf
	return {"type": "inference", "fact": fact_id, "conclusion": inf["conclusion"], "confidence": inf["confidence"], "by": thinker.id, "contested": inf["contested"]}


## 真相揭晓（剧情证实、亲眼看到）。返回事件里带着之前的推论对不对。
func confirm(fact_id: String) -> Dictionary:
	var truth: bool = bool(facts[fact_id]["truth"])
	confirmed[fact_id] = truth
	var was: Variant = null
	if inferences.has(fact_id):
		was = bool(inferences[fact_id]["conclusion"]) == truth
	return {"type": "fact_confirmed", "fact": fact_id, "truth": truth, "inference_was_right": was}


func to_dict() -> Dictionary:
	return {
		"facts": facts.duplicate(true),
		"clues_found": clues_found.duplicate(),
		"inferences": inferences.duplicate(true),
		"confirmed": confirmed.duplicate(),
	}


func load_dict(d: Dictionary) -> void:
	facts = (d["facts"] as Dictionary).duplicate(true)
	clues_found = (d["clues_found"] as Dictionary).duplicate()
	inferences = (d["inferences"] as Dictionary).duplicate(true)
	confirmed = (d["confirmed"] as Dictionary).duplicate()
```

- [ ] **Step 7：改写 `game/core/intel/rule_discovery.gd`**

```gdscript
extends RefCounted
## 规则发现（设计规格 3.8，核心机制分析 9.3B）：引擎里有一层隐藏规则和漏洞，被智者发现之前在机制上是锁住的。
## 发现后写进规则百科，并解锁对应的东西（unlocks，例如 "catalog:parts_blueprints" 开放零件图纸页）。
## 规则定义在 data/intel/hidden_rules.json；requires 的各项都满足才能发现：
##   intelligence_min（发现者的智力）、talents（发现者的天赋）、flags（GameState.flags 里为真的旗标）、films_completed_min（发现者经历过的片数）。

const DataLoader = preload("res://core/util/data_loader.gd")
const Talents = preload("res://core/model/talents.gd")

const PATH := "res://data/intel/hidden_rules.json"

static var _cache: Dictionary = {}

## 规则 id → {"by": 发现者 id}
var discovered: Dictionary = {}


static func rules() -> Dictionary:
	if _cache.is_empty():
		var res := DataLoader.load_json(PATH)
		assert(res.ok, res.error)
		_cache = res.data["rules"]
	return _cache


## 发现者满足不了的条件列表（空表示可以发现）。
static func unmet(rule_id: String, thinker: RefCounted, game_state: RefCounted) -> Array[String]:
	var req: Dictionary = rules()[rule_id]["requires"]
	var out: Array[String] = []
	if thinker.attributes.total("intelligence") < float(req.get("intelligence_min", 0.0)):
		out.append("intelligence")
	for t: String in req.get("talents", []):
		if not Talents.has(thinker, t):
			out.append("talent:" + t)
	for f: String in req.get("flags", []):
		if not bool(game_state.flags.get(f, false)):
			out.append("flag:" + f)
	if thinker.films_completed < int(req.get("films_completed_min", 0)):
		out.append("experience")
	return out


func try_discover(rule_id: String, thinker: RefCounted, game_state: RefCounted) -> Dictionary:
	if discovered.has(rule_id):
		return {"type": "rule_known", "rule": rule_id}
	var missing := unmet(rule_id, thinker, game_state)
	if not missing.is_empty():
		return {"type": "rule_not_found", "rule": rule_id, "missing": missing}
	discovered[rule_id] = {"by": thinker.id}
	var r: Dictionary = rules()[rule_id]
	return {"type": "rule_discovered", "rule": rule_id, "name": String(r["name"]), "unlocks": String(r["unlocks"]), "by": thinker.id}


## 让每个智者把能发现的都试一遍（休整期、远征中的思考时间）。
func discover_all(thinkers: Array, game_state: RefCounted) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for rule_id: String in rules():
		if discovered.has(rule_id):
			continue
		for t: RefCounted in thinkers:
			if t.alive and unmet(rule_id, t, game_state).is_empty():
				events.append(try_discover(rule_id, t, game_state))
				break
	return events


func is_unlocked(key: String) -> bool:
	for rule_id: String in discovered:
		if rules()[rule_id]["unlocks"] == key:
			return true
	return false


## 规则百科：已发现的规则，按发现顺序。
func encyclopedia() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rule_id: String in discovered:
		out.append({"rule": rule_id, "name": String(rules()[rule_id]["name"]), "by": String(discovered[rule_id]["by"])})
	return out


func to_dict() -> Dictionary:
	return {"discovered": discovered.duplicate(true)}


func load_dict(d: Dictionary) -> void:
	discovered = (d["discovered"] as Dictionary).duplicate(true)
```

- [ ] **Step 8：改写 `game/data/hub/exchange_catalog.json`**

```json
{
	"version": 1,
	"entries": {
		"qigong_low": {
			"name": "低级气功", "category": "enhance", "series": "qigong",
			"price": {"points": 500, "tier": "D"}, "source": "L403、L597",
			"blocks": [
				{"attr": {"spirit": 10, "cell_vitality": 20, "nerve_reaction": 20, "muscle": 30, "immunity": 20}, "tier": "D"},
				{"energy": "neili", "amount": 30, "value": 0}
			]
		},
		"qigong_mid": {
			"name": "中级气功", "category": "enhance", "series": "qigong", "requires": ["qigong_low"],
			"price": {"points": 1200, "tier": "C"}, "source": "L597",
			"blocks": [{"energy": "neili", "amount": 60, "value": 2600, "tier": "C"}]
		},
		"qigong_high": {
			"name": "高级气功", "category": "enhance", "series": "qigong", "requires": ["qigong_mid"],
			"price": {"points": 2500, "tier": "B"}, "source": "L588、L6251",
			"blocks": [
				{"energy": "neili", "amount": 120, "value": 4400, "tier": "B"},
				{"passive": "qi_burst", "value": 500}
			]
		},
		"vampire_baron": {
			"name": "血族男爵", "category": "enhance", "series": "vampire", "bloodline": true,
			"price": {"points": 800, "tier": "D"}, "source": "L597",
			"blocks": [{"energy": "blood", "amount": 30, "value": 1300, "tier": "D"}]
		},
		"vampire_viscount": {
			"name": "血族子爵", "category": "enhance", "series": "vampire", "bloodline": true, "requires": ["vampire_baron"],
			"price": {"points": 1500, "tier": "C"}, "source": "L597、L4789",
			"blocks": [{"energy": "blood", "amount": 60, "value": 2900, "tier": "C"}]
		},
		"vampire_count": {
			"name": "血族伯爵", "category": "enhance", "series": "vampire", "bloodline": true, "requires": ["vampire_viscount"],
			"price": {"points": 3000, "tier": "B"}, "source": "L590、L4748",
			"blocks": [
				{"energy": "blood", "amount": 120, "value": 3900, "tier": "B"},
				{"passive": "undying_unless_heart_or_brain", "value": 1500}
			]
		},
		"spider_gene": {
			"name": "蜘蛛侠基因变异血统", "category": "enhance", "series": "spider", "bloodline": true,
			"price": {"points": 2000, "tier": "B"}, "source": "L399、L587",
			"blocks": [
				{"attr": {"intelligence": 20, "spirit": 20, "cell_vitality": 50, "nerve_reaction": 100, "muscle": 100, "immunity": 150}, "tier": "B"},
				{"ability": "spider_silk", "value": 0}
			]
		},
		"t_virus": {
			"name": "T 病毒进化模式", "category": "enhance", "series": "t_virus",
			"price": {"points": 1500, "tier": "C"}, "source": "L404",
			"blocks": [{"attr": {"intelligence": 20, "spirit": 20, "cell_vitality": 50, "nerve_reaction": 50, "muscle": 50, "immunity": 100}, "tier": "C"}]
		},
		"werewolf_high": {
			"name": "高级狼人血统", "category": "enhance", "series": "werewolf", "bloodline": true,
			"price": {"points": 2700, "tier": "B"}, "source": "L589",
			"blocks": [{"passive": "werewolf_form", "value": 5100, "tier": "B"}]
		},
		"eagle_eye": {
			"name": "德鲁依苍鹰眼固化", "category": "enhance", "series": "druid",
			"price": {"points": 1000, "tier": "C"}, "source": "L2782",
			"blocks": [{"passive": "eagle_eye", "value": 2400, "tier": "C"}]
		},
		"elf_wind_archer": {
			"name": "精灵族风系射手", "category": "enhance", "series": "elf", "bloodline": true,
			"price": {"points": 2000, "tier": "C"}, "source": "L4765",
			"blocks": [{"ability": "wind_arrow", "value": 3400, "tier": "C"}]
		},
		"red_flame": {
			"name": "红炎", "category": "enhance", "series": "vampire_skill", "requires_energy": "blood",
			"price": {"points": 2000, "tier": "C"}, "source": "L2787、L3406",
			"blocks": [{"ability": "red_flame", "value": 3400, "tier": "C"}]
		},
		"light_kungfu": {
			"name": "轻功", "category": "enhance", "series": "kungfu", "requires_energy": "neili",
			"price": {"points": 2000, "tier": "C"}, "source": "L4816、L4839",
			"blocks": [{"ability": "light_kungfu", "value": 3400, "tier": "C"}]
		},
		"mind_scan": {
			"name": "精神力扫描", "category": "enhance", "series": "psionic",
			"gates": {"attr_min": {"spirit": 300}, "talent_bypass": "psychic"},
			"price": {"points": 4000, "tier": "C"}, "source": "L4740",
			"note": "门槛数值是占位；詹岚的精神力天赋可绕过（原著 L4740 附近）",
			"blocks": [{"ability": "mind_scan", "value": 5400, "tier": "C"}]
		},
		"mind_focus": {
			"name": "心神凝聚", "category": "enhance", "series": "psionic",
			"price": {"points": 2500, "tier": "B"}, "source": "L6206",
			"blocks": [{"passive": "mind_focus", "value": 4900, "tier": "B"}]
		},
		"desert_eagle": {
			"name": "沙漠之鹰（无限子弹）", "category": "tech", "series": "pistol",
			"price": {"points": 100, "tier": ""}, "source": "L44",
			"blocks": [{"skill": "desert_eagle", "value": 5, "unlimited": true}]
		},
		"gauss_pistol": {
			"name": "无限弹药高斯手枪", "category": "tech", "series": "gauss",
			"price": {"points": 1500, "tier": "D"}, "source": "L8334",
			"blocks": [{"ability": "gauss_pistol", "value": 100, "unlimited": true, "tier": "D"}]
		},
		"gauss_sniper": {
			"name": "无限弹药高斯离子狙击步枪", "category": "tech", "series": "gauss",
			"price": {"points": 5000, "tier": "D"}, "source": "L1583",
			"blocks": [{"ability": "gauss_sniper", "value": 275, "unlimited": true, "tier": "D"}]
		},
		"shield_plate": {
			"name": "防护盾", "category": "tech", "series": "shield",
			"price": {"points": 1500, "tier": "D"}, "source": "L5689",
			"blocks": [{"passive": "shield_plate", "value": 2000, "tier": "D"}]
		},
		"na_ring": {
			"name": "纳戒", "category": "magic", "series": "storage", "requires_energy": "neili",
			"price": {"points": 1500, "tier": "D"}, "source": "L626~630",
			"blocks": [{"ability": "na_ring", "value": 1000, "tier": "D"}]
		},
		"purifying_sword": {
			"name": "净化之光（长剑）", "category": "magic", "series": "holy_blade",
			"price": {"points": 1000, "tier": ""}, "source": "L623",
			"blocks": [{"ability": "purifying_light_sword", "value": 500}]
		},
		"grenade": {
			"name": "手榴弹", "category": "item", "series": "explosive", "consumable": true,
			"price": {"points": 50, "tier": ""}, "source": "原著未载价格",
			"blocks": [{"item": "grenade", "count": 1, "unit_value": 50}]
		},
		"first_aid_spray": {
			"name": "止血喷雾", "category": "item", "series": "medical", "consumable": true,
			"price": {"points": 50, "tier": ""}, "source": "原著未载价格",
			"blocks": [{"item": "spray", "count": 1, "unit_value": 50}]
		},
		"antidote": {
			"name": "解毒剂", "category": "item", "series": "medical", "consumable": true,
			"price": {"points": 100, "tier": ""}, "source": "原著未载价格",
			"blocks": [{"item": "antidote", "count": 1, "unit_value": 100}]
		},
		"bingning_dan": {
			"name": "冰凝丹", "category": "item", "series": "elixir", "consumable": true,
			"price": {"points": 1000, "tier": "D"}, "source": "L13123",
			"blocks": [{"item": "bingning_dan", "count": 1, "unit_value": 1500, "tier": "D"}]
		},
		"rebirth_cross": {
			"name": "重生十字章", "category": "item", "series": "revival", "consumable": true,
			"price": {"points": 7000, "tier": "2B"}, "source": "L6153、L12207",
			"blocks": [{"item": "rebirth_cross", "count": 1, "unit_value": 11800, "tier": "2B"}]
		}
	}
}
```

- [ ] **Step 9：改写 `game/data/characters/m1_roster.json`**

```json
{
	"version": 1,
	"characters": {
		"zheng_zha": {
			"name": "郑吒",
			"attributes": {"intelligence": 100, "spirit": 110, "cell_vitality": 105, "nerve_reaction": 105, "muscle": 110, "immunity": 100},
			"skills": ["punch"],
			"items": {"ammo": 12},
			"films_completed": 0,
			"flags": {
				"background": "普通公司职员，看过这部电影，记得激光通道和火焰女皇。",
				"talent": "iron_will",
				"talent_name": "不屈",
				"talent_condition": "濒死或同伴死在面前",
				"demon": "怕失去重要的人",
				"potential": 0.8,
				"personality": "重情义、护短，关键时候反而冷静。",
				"role": "主角"
			}
		},
		"zhang_jie": {
			"name": "张杰",
			"attributes": {"intelligence": 110, "spirit": 130, "cell_vitality": 130, "nerve_reaction": 140, "muscle": 140, "immunity": 120},
			"skills": ["desert_eagle", "punch"],
			"items": {},
			"films_completed": 3,
			"flags": {
				"background": "经历过三部片的老手，对主神的规则了如指掌。",
				"talent": "half_guide",
				"talent_name": "半引导者",
				"talent_condition": "队伍面临团灭",
				"demon": "知道自己迟早要死",
				"potential": 0.7,
				"personality": "懒散、爱抽烟，用玩笑藏事。",
				"role": "资深者"
			}
		},
		"zhan_lan": {
			"name": "詹岚",
			"attributes": {"intelligence": 130, "spirit": 150, "cell_vitality": 95, "nerve_reaction": 100, "muscle": 90, "immunity": 95},
			"skills": ["punch"],
			"items": {},
			"films_completed": 0,
			"flags": {
				"background": "作家，擅长从局势里推出别人没说的东西。",
				"talent": "psychic",
				"talent_name": "精神力天赋",
				"talent_condition": "兑换精神类强化，或队伍陷入绝境",
				"demon": "总觉得自己不够强，只会拖累别人",
				"potential": 0.75,
				"personality": "冷静、话少，提出计划时会先算最坏情况。",
				"role": "智者苗子"
			}
		},
		"li_xiao_yi": {
			"name": "李萧毅",
			"attributes": {"intelligence": 105, "spirit": 100, "cell_vitality": 100, "nerve_reaction": 105, "muscle": 100, "immunity": 100},
			"skills": ["punch"],
			"items": {},
			"films_completed": 0,
			"flags": {
				"background": "大学生，跑得快，嘴也快。",
				"talent": "quick_learner",
				"talent_name": "学得快",
				"talent_condition": "有人教，或者拿到说明书",
				"demon": "怕被队伍丢下",
				"potential": 0.55,
				"personality": "话多、爱表现，真出事时会跟着最靠得住的人。",
				"role": "新人"
			}
		},
		"mu_gang": {
			"name": "牟钢",
			"attributes": {"intelligence": 90, "spirit": 90, "cell_vitality": 110, "nerve_reaction": 95, "muscle": 120, "immunity": 105},
			"skills": ["punch"],
			"items": {},
			"films_completed": 0,
			"flags": {
				"background": "货运司机，开过长途，力气大、耐力好。",
				"talent": "wheelman",
				"talent_name": "老司机",
				"talent_condition": "摸到方向盘，或者被逼到绝路",
				"demon": "怕死，越怕越慌",
				"potential": 0.45,
				"personality": "嗓门大、爱吹牛，真遇到事容易崩。",
				"role": "新人"
			}
		},
		"xiao_pang_zi": {
			"name": "小胖子",
			"attributes": {"intelligence": 95, "spirit": 85, "cell_vitality": 90, "nerve_reaction": 90, "muscle": 85, "immunity": 90},
			"skills": ["punch"],
			"items": {},
			"films_completed": 0,
			"flags": {
				"background": "刚毕业，体能差，怕黑。",
				"talent": "lucky",
				"talent_name": "傻人有傻福",
				"talent_condition": "被人护着的时候",
				"demon": "觉得自己只会拖后腿",
				"potential": 0.5,
				"personality": "胆小、听话，被救过就死心塌地。",
				"role": "新人"
			}
		},
		"zhong_nian_fu_nv": {
			"name": "中年妇女",
			"attributes": {"intelligence": 95, "spirit": 105, "cell_vitality": 95, "nerve_reaction": 90, "muscle": 85, "immunity": 95},
			"skills": ["punch"],
			"items": {},
			"films_completed": 0,
			"flags": {
				"background": "中学老师，见过些世面，但体力跟不上。",
				"talent": "calm_voice",
				"talent_name": "稳住人心",
				"talent_condition": "有人听她说话",
				"demon": "怕自己和孩子一样被丢下",
				"potential": 0.4,
				"personality": "嘴上硬，心里软，会照顾比她更怕的人。",
				"role": "新人"
			}
		}
	}
}
```

- [ ] **Step 10：运行，确认通过**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_exchange bash game/tools/run_tests.sh; echo "exit=$?"`，再运行 `bash game/tools/run_tests.sh | tail -2`

预期：`test_exchange.gd` 全部 `ok`；全量 `共 403 个测试，失败 0 个`。

- [ ] **Step 11：提交**

```bash
git add game/data/characters/talents.json game/core/model/talents.gd game/core/hub/exchange.gd game/core/intel/intel_state.gd game/core/intel/rule_discovery.gd game/data/hub/exchange_catalog.json game/data/characters/m1_roster.json game/tests/unit/hub/test_exchange.gd
git commit -m "feat(talents): 统一天赋字段，詹岚的精神力天赋能绕过精神力门槛" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

## Task 2：主神议程接线与天赋觉醒的触发点

**Files:**
- Modify: `game/core/director/agenda.gd`、`game/data/director/director_rules.json`、`game/core/model/game_state.gd`、`game/core/campaign/campaign.gd`、`game/data/scenarios/biohazard1/chapter.json`、`game/core/session/session.gd`、`game/core/hub/hub.gd`、`game/core/expedition/expedition.gd`
- Test: `game/tests/unit/core/test_talents.gd`（新）、`game/tests/unit/director/test_agenda.gd`、`game/tests/unit/campaign/test_m1_content.gd`、`game/tests/unit/session/test_session.gd`

- [ ] **Step 1：写测试 `game/tests/unit/core/test_talents.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Talents = preload("res://core/model/talents.gd")
const Character = preload("res://core/model/character.gd")
const GameState = preload("res://core/model/game_state.gd")
const Campaign = preload("res://core/campaign/campaign.gd")
const Hub = preload("res://core/hub/hub.gd")

const CHAPTER := "res://data/scenarios/biohazard1/chapter.json"


## 测试用的假战斗：只需要 history、field.units、outcome 三样。
class FakeField extends RefCounted:
	var units: Array[RefCounted] = []


class FakeBattle extends RefCounted:
	var history: Array[Dictionary] = []
	var field := FakeField.new()
	var outcome := "victory"


func _types(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for e in events:
		out.append(String(e["type"]))
	return out


## 人物表写单个 flags.talent，旧数据写 flags.talents 数组，两种都认。
func test_ids_read_both_forms() -> void:
	var c := Character.new("a", "a", {})
	assert_eq(Talents.ids(c), [] as Array[String])
	c.flags["talent"] = "psychic"
	c.flags["talents"] = ["genius", "psychic"]
	assert_eq(Talents.ids(c), ["psychic", "genius"] as Array[String])
	assert_true(Talents.has(c, "genius"))
	assert_false(Talents.has(c, ""))


## 觉醒只发生一次：锻炼属性加上去（主神看不见）、恐惧下降；死人不觉醒。
func test_trigger_awakens_once() -> void:
	var c := Character.new("zheng_zha", "郑吒", {})
	c.flags["talent"] = "iron_will"
	c.fear = 50.0
	var events: Array[Dictionary] = []
	assert_eq(Talents.trigger(c, "flag:whatever", events), [] as Array[String])
	assert_eq(Talents.trigger(c, "ally_died", events), ["iron_will"] as Array[String])
	assert_eq(_types(events), ["talent_awakened"] as Array[String])
	assert_eq(String(events[0]["name"]), "不屈")
	assert_almost(c.attributes.total("spirit"), 115.0)
	assert_almost(float(c.attributes.enhanced["spirit"]), 0.0, 0.0001, "锻炼不进兑换属性，主神看不见")
	assert_almost(c.fear, 20.0)
	assert_true(Talents.is_awake(c, "iron_will"))
	assert_eq(Talents.awake_names(c), ["不屈"] as Array[String])
	assert_eq(Talents.trigger(c, "near_death", events), [] as Array[String])
	assert_eq(events.size(), 1)
	var dead := Character.new("x", "x", {})
	dead.flags["talent"] = "iron_will"
	dead.alive = false
	assert_eq(Talents.trigger(dead, "ally_died", events), [] as Array[String])


## 学得快：觉醒前训练倍率 1，觉醒后 2。
func test_train_mult() -> void:
	var c := Character.new("li_xiao_yi", "李萧毅", {})
	c.flags["talent"] = "quick_learner"
	assert_almost(Talents.train_mult(c), 1.0)
	var events: Array[Dictionary] = []
	Talents.trigger(c, "trained", events)
	assert_almost(Talents.train_mult(c), 2.0)


## 远征：四个人当场死掉 → 郑吒看着同伴倒下（不屈）；活着的只剩三个（≤ 七人的一半）→ 张杰、詹岚觉醒。
## 觉醒都记进主神议程（潜力突升，不够复制进恶魔小队）。
func test_deaths_awaken_in_expedition() -> void:
	var g := GameState.new(1)
	var ex := Campaign.start(g, CHAPTER)
	ex.choose("listen")
	var events: Array[Dictionary] = ex.apply_effects([{"damage": {"amount": 999, "recipients": ["li_xiao_yi", "mu_gang", "xiao_pang_zi", "zhong_nian_fu_nv"], "reason": "test"}}], "car")
	var woke := {}
	for e in events:
		if e["type"] == "talent_awakened":
			woke[String(e["char"])] = String(e["talent"])
	assert_eq(woke, {"zheng_zha": "iron_will", "zhang_jie": "half_guide", "zhan_lan": "psychic"})
	assert_almost(g.characters["zhan_lan"].attributes.total("spirit"), 190.0)
	assert_almost(float(g.agenda.potentials["zhan_lan"]), 0.1)
	assert_eq(g.agenda.demon_copies, [])


## 战后濒死：活着但生命不到四分之一的人触发 near_death（郑吒的不屈）。
func test_near_death_after_battle() -> void:
	var g := GameState.new(1)
	var ex := Campaign.start(g, CHAPTER)
	ex.st.pending_battle = {"location": "car", "squad": "s1", "enemies": [{"def": "zombie", "count": 1}], "dark": false, "survive_until": -1.0, "after_victory": [], "after_defeat": []}
	var units: Array[RefCounted] = ex.battle_units({})
	for u in units:
		if u.side == "ally" and u.character_id == "zheng_zha":
			u.hp = 5.0
	var b := FakeBattle.new()
	b.field.units = units
	var events: Array[Dictionary] = ex.report_battle(b)
	assert_true(_types(events).has("talent_awakened"))
	assert_true(Talents.is_awake(g.characters["zheng_zha"], "iron_will"))
	assert_false(Talents.is_awake(g.characters["zhang_jie"], "half_guide"))


## 休整：詹岚兑换精神力 → 精神力天赋觉醒（+40）；李萧毅训练一次觉醒"学得快"，之后训练熟练度翻倍。
func test_hub_triggers() -> void:
	var g := GameState.new(1)
	Campaign.start(g, CHAPTER)
	var zl: RefCounted = g.characters["zhan_lan"]
	zl.points = 1000
	var hub := Hub.new()
	hub.start(g, 9)
	hub.day = 1
	var events: Array[Dictionary] = hub.buy_attribute("zhan_lan", "spirit", 10)
	assert_eq(_types(events), ["attribute_bought", "talent_awakened"] as Array[String])
	assert_almost(zl.attributes.total("spirit"), 200.0)
	var li: RefCounted = g.characters["li_xiao_yi"]
	li.proficiency["punch"] = 0.2
	events = hub.train("li_xiao_yi", "punch", 1)
	assert_eq(_types(events), ["trained", "talent_awakened", "day_passed"] as Array[String])
	var after_first := float(li.proficiency["punch"])
	hub.train("li_xiao_yi", "punch", 1)
	var per_day := after_first - 0.2
	assert_almost(float(li.proficiency["punch"]) - after_first, minf(per_day * 2.0, 1.0 - after_first))
```

- [ ] **Step 2：改写 `game/tests/unit/director/test_agenda.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const GameState = preload("res://core/model/game_state.gd")
const Agenda = preload("res://core/director/agenda.gd")


func _game() -> RefCounted:
	var g := GameState.new(1)
	for id in ["zheng_zha", "zhang_jie", "zhan_lan"]:
		g.add_character(Character.new(id, id, {}))
	return g


func test_stages_advance_with_reasons() -> void:
	var a := Agenda.new()
	assert_eq(a.stage, "guide")
	assert_true(a.advance_stage("biohazard1", "引导者带新人入门"))
	assert_eq(a.stage, "captain")
	assert_eq(a.decisions[0], {"film": "biohazard1", "kind": "advance_stage", "payload": {"stage": "captain"}, "reason": "引导者带新人入门"})
	for i in 10:
		a.advance_stage("x", "")
	assert_eq(a.stage, "finale")
	assert_false(a.advance_stage("x", ""))


## 原著：张杰的"半引导者"异常让主神刻意加难（L5595）；考验完成后异常解除。
func test_anomaly_lifecycle() -> void:
	var a := Agenda.new()
	var id: String = a.add_anomaly("half_guide", "biohazard1", "张杰既像引导者又不肯考验", "异常：加难逼它表态")
	assert_eq(id, "anomaly_1")
	assert_eq(a.open_anomalies().size(), 1)
	a.set_ultimatum("captain_trial", "final_destination2", "只留一个出口", "the_grudge", "最后通牒")
	assert_eq(a.ultimatum["kind"], "captain_trial")
	assert_true(a.resolve_anomaly(id, "final_destination2", "考验完成"))
	assert_false(a.resolve_anomaly(id, "x", ""))
	assert_eq(a.open_anomalies().size(), 0)


## 异常记在谁身上：同种异常按人区分，解除后查不到。
func test_open_anomaly_by_char() -> void:
	var a := Agenda.new()
	var id: String = a.add_anomaly("half_guide", "biohazard1", "半引导者", "加难", "zhang_jie")
	assert_eq(String(a.anomalies[0]["char"]), "zhang_jie")
	assert_eq(a.decisions[0]["payload"], {"id": id, "kind": "half_guide", "char": "zhang_jie"})
	assert_eq(a.open_anomaly("half_guide", "zhang_jie"), id)
	assert_eq(a.open_anomaly("half_guide", "zheng_zha"), "")
	a.resolve_anomaly(id, "final_destination2", "考验完成")
	assert_eq(a.open_anomaly("half_guide", "zhang_jie"), "")


## 潜力突升够大，主神考虑复制进恶魔小队。
func test_potential_spike() -> void:
	var a := Agenda.new()
	assert_false(a.potential_spike("zheng_zha", 0.1, "alien1", "首次觉醒"))
	assert_true(a.potential_spike("zheng_zha", 0.3, "alien1", "造人"))
	a.copy_to_demon_team("zheng_zha", "alien1", "对照实验")
	assert_false(a.potential_spike("zheng_zha", 0.5, "x", ""))
	assert_almost(float(a.potentials["zheng_zha"]), 0.9)
	assert_eq(a.demon_copies, ["zheng_zha"])


## 评价：活过一部本该团灭的片、损失小 → +1；队长死 → −1；所有人都死过 → 清零、记录消失。
func test_update_rating() -> void:
	var g := _game()
	g.films_record = ["biohazard1", "alien1"]
	var r := Agenda.update_rating(g, {"expected_wipe": true, "members": 10, "survivors": 8})
	assert_eq(r, {"before": 0, "after": 1, "reasons": ["survived_wipe"] as Array[String]})
	r = Agenda.update_rating(g, {"expected_wipe": true, "members": 10, "survivors": 5})
	assert_eq(int(r["after"]), 1)
	r = Agenda.update_rating(g, {"captain_died": true, "members": 10, "survivors": 9})
	assert_eq(int(r["after"]), 0)
	r = Agenda.update_rating(g, {"captain_died": true, "members": 10, "survivors": 9})
	assert_eq(int(r["after"]), 0)
	g.team_rating = 3
	r = Agenda.update_rating(g, {"all_died": true, "members": 10, "survivors": 1})
	assert_eq(g.team_rating, 0)
	assert_eq(g.films_record, [])


## 评价战力：新人队伍 120；兑换让它上升；锻炼和基因锁主神看不见。
func test_rating_power() -> void:
	var g := _game()
	var team := ["zheng_zha", "zhang_jie", "zhan_lan"]
	assert_almost(Agenda.rating_power(g, team), 120.0)
	g.characters["zheng_zha"].attributes.add_trained("muscle", 300.0)
	g.characters["zheng_zha"].gene_lock_stage = 2
	assert_almost(Agenda.rating_power(g, team), 120.0)
	g.characters["zheng_zha"].attributes.add_enhanced_high("muscle", 180.0)
	assert_almost(Agenda.rating_power(g, team), 120.0 * (100.0 + 10.0) / 100.0)
	g.team_rating = 2
	assert_almost(Agenda.rating_power(g, team), 240.0 * 1.1)
	g.characters["zheng_zha"].alive = false
	assert_almost(Agenda.rating_power(g, team), 240.0)


func test_round_trip() -> void:
	var a := Agenda.new()
	a.advance_stage("biohazard1", "r")
	a.add_anomaly("half_guide", "biohazard1", "n", "r")
	a.potential_spike("zheng_zha", 0.3, "alien1", "r")
	var copy := Agenda.new()
	copy.load_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	assert_eq(copy.to_dict(), a.to_dict())
```

- [ ] **Step 3：改写 `game/tests/unit/campaign/test_m1_content.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Campaign = preload("res://core/campaign/campaign.gd")
const GameState = preload("res://core/model/game_state.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const BattleData = preload("res://core/battle/battle_data.gd")
const Persona = preload("res://ai/persona.gd")
const Talents = preload("res://core/model/talents.gd")

const CHAPTER := "res://data/scenarios/biohazard1/chapter.json"
const ROSTER := "res://data/characters/m1_roster.json"
const SCENARIO := "res://data/scenarios/biohazard1/scenario.json"

const M1_MEMBERS := ["zheng_zha", "zhang_jie", "zhan_lan", "li_xiao_yi", "mu_gang", "xiao_pang_zi", "zhong_nian_fu_nv"]


## 测试用的假战斗：只需要 history、field.units、outcome 三样。
class FakeField extends RefCounted:
	var units: Array[RefCounted] = []


class FakeBattle extends RefCounted:
	var history: Array[Dictionary] = []
	var field := FakeField.new()
	var outcome := "victory"


func _start() -> RefCounted:
	return Campaign.start(GameState.new(1), CHAPTER)


## 用假战斗把待打的战斗按胜利了结（不产生击杀记录）。
func _win(ex: RefCounted) -> Array[Dictionary]:
	var units: Array[RefCounted] = ex.battle_units({})
	var b := FakeBattle.new()
	b.field.units = units
	return ex.report_battle(b)


func _types(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for e in events:
		out.append(String(e["type"]))
	return out


## 章节的议程块：开局就记下张杰的半引导者异常和"按张杰定难度"的决定，各带主神理由。
func test_chapter_agenda() -> void:
	var g := GameState.new(1)
	Campaign.start(g, CHAPTER)
	var id: String = g.agenda.open_anomaly("half_guide", "zhang_jie")
	assert_eq(id, "anomaly_1")
	var kinds: Array = []
	for d: Dictionary in g.agenda.decisions:
		kinds.append(String(d["kind"]))
		assert_true(String(d["reason"]) != "", "每个决定都要有主神理由")
	assert_eq(kinds, ["add_anomaly", "difficulty_anchor"])
	Campaign.apply_agenda(g, Campaign.load_chapter(CHAPTER), "biohazard1")
	assert_eq(g.agenda.open_anomalies().size(), 1, "同一异常不重复记")


## 走到激光通道门口：听规则 → 大厅 → 楼梯井（扶掉队的人）→ 激光通道。
func _to_laser() -> RefCounted:
	var ex := _start()
	ex.choose("listen")
	ex.move("s1", "hall")
	ex.move("s1", "stairs")
	ex.choose("help")
	ex.move("s1", "laser")
	ex.dismiss_cutscene()
	# 激光通道里先说通马修（难度 1，等级 2 必成），才轮到救人选择。
	assert_eq(String(ex.st.pending_check.get("id", "")), "convince_matthew", "激光通道要先过说服马修")
	ex.resolve_persuasion(2)
	return ex


func test_chapter_validates() -> void:
	var ch := Campaign.load_chapter(CHAPTER)
	var errors := Campaign.validate_chapter(ch)
	assert_eq(errors.size(), 0, str(errors))
	assert_eq(String(ch["id"]), "m1")


func test_roster() -> void:
	var roster := Campaign.build_roster(ROSTER)
	assert_eq(roster.size(), 7)
	assert_eq(roster["zhang_jie"].display_name, "张杰")
	assert_eq(int(roster["zhang_jie"].films_completed), 3)
	assert_eq(int(roster["zheng_zha"].films_completed), 0)
	assert_true(roster["zhang_jie"].skills.has("desert_eagle"))
	assert_eq(String(roster["mu_gang"].flags["talent"]), "wheelman")
	assert_true(float(roster["zheng_zha"].flags["potential"]) > 0.5)


## 剧本里的剧情人物和名单上的轮回者都要有 AI 人设，M1 才算能全 AI 驱动对话。
func test_personas_cover_cast() -> void:
	var personas := Persona.load_all()
	var sc := Scenario.load_file(SCENARIO)
	for id: String in sc.data["npcs"]:
		assert_true(personas.has(id), id)
	for id: String in Campaign.build_roster(ROSTER):
		assert_true(personas.has(id), id)
	assert_true(personas.has("zhushen"))
	assert_eq((personas["red_queen"]["fallback_lines"] as Array).size(), 3)


func test_scenario_metadata() -> void:
	var sc := Scenario.load_file(SCENARIO)
	assert_eq(sc.validate().size(), 0, str(sc.validate()))
	assert_eq(String(sc.id), "biohazard1")
	assert_eq(int(sc.data["duration_minutes"]), 187)
	assert_eq((sc.data["locations"] as Dictionary).size(), 8)
	assert_eq((sc.data["npcs"] as Dictionary).size(), 8)
	var choices := 0
	for ev: Dictionary in sc.events():
		for e: Dictionary in ev.get("effects", []):
			if e.has("choice"):
				choices += 1
	assert_true(choices >= 3, str(choices))


## 开局：七个人都在，评价战力 120；开场事件要玩家表态；张杰讲规则拿 100 点。
func test_start_and_opening() -> void:
	var g := GameState.new(1)
	var ex := Campaign.start(g, CHAPTER)
	assert_true(ex != null)
	assert_eq(g.characters.size(), 7)
	assert_almost(ex.rating_power, 120.0)
	assert_eq(ex.st.pending_choice["id"], "opening_attitude")
	assert_eq(ex.move("s1", "hall")[0]["reason"], "choice_pending")
	ex.choose("listen")
	assert_true(bool(ex.st.flags["listened_rules"]))
	assert_eq(ex.st.ledger[0], {"char": "zhang_jie", "kind": "bonus", "points": 100.0, "label": "讲解规则", "grade": ""})


## 扶不扶掉队的新人：扶 = 多花 15 分钟、加恐惧、两人活下来。
func test_lagging_help() -> void:
	var ex := _start()
	ex.choose("listen")
	ex.move("s1", "hall")
	ex.move("s1", "stairs")
	assert_eq(ex.st.clock, 18)
	assert_eq(ex.st.pending_choice["id"], "lag_behind")
	ex.choose("help")
	assert_eq(ex.st.clock, 33)
	assert_true(ex.st.characters["xiao_pang_zi"].alive)
	assert_true(ex.st.characters["zhong_nian_fu_nv"].alive)
	assert_true(bool(ex.st.flags["helped_lagging"]))
	# 队伍肯停下来等：小胖子"傻人有傻福"、中年妇女"稳住人心"觉醒，后者让同地点其他人恐惧 −10。
	assert_true(Talents.is_awake(ex.st.characters["xiao_pang_zi"], "lucky"))
	assert_true(Talents.is_awake(ex.st.characters["zhong_nian_fu_nv"], "calm_voice"))
	assert_almost(ex.st.characters["zheng_zha"].fear, 14.5 * 100.0 / 110.0 - 10.0)


## 不扶：两个人超出百米被抹杀，队伍不停。
func test_lagging_leave() -> void:
	var ex := _start()
	ex.choose("listen")
	ex.move("s1", "hall")
	ex.move("s1", "stairs")
	ex.choose("leave")
	assert_eq(ex.st.clock, 18)
	assert_false(ex.st.characters["xiao_pang_zi"].alive)
	assert_false(ex.st.characters["zhong_nian_fu_nv"].alive)
	assert_eq(ex.st.characters["xiao_pang_zi"].flags["erased"], "tether")
	assert_false(bool(ex.st.flags.get("helped_lagging", false)))
	# 同伴在面前被抹杀：郑吒的"不屈"觉醒。
	assert_true(Talents.is_awake(ex.st.characters["zheng_zha"], "iron_will"))


## 激光通道：按记忆拖着马修贴门 → B 级支线 + 5000、精神临界值突破 +500、绑定解除、门开了。
func test_laser_saves_matthew() -> void:
	var ex := _to_laser()
	assert_eq(ex.st.clock, 40)
	assert_eq(ex.st.pending_choice["id"], "laser_choice")
	assert_true(ex.st.characters["zheng_zha"].skills.has("pistol_shot_limited"))
	var events: Array[Dictionary] = ex.choose("save_matthew")
	assert_true(_types(events).has("side_plot_done"))
	assert_true(_types(events).has("tether_released"))
	assert_true(ex.st.tether.is_empty())
	assert_true(ex.st.is_path_open("laser", "control"))
	assert_true(ex.st.npcs["matthew"]["alive"])
	assert_true(ex.st.characters["mu_gang"].alive)
	assert_almost(ex.st.characters["zheng_zha"].attributes.total("spirit"), 130.0)
	assert_almost(ex.st.characters["zheng_zha"].attributes.total("nerve_reaction"), 135.0)
	assert_true(ex.move("s1", "control")[1]["type"] == "arrived")


## 只顾自己：马修死，绑定转给卡普兰；牟钢在激光里被击毙。
func test_laser_selfish() -> void:
	var ex := _to_laser()
	var events: Array[Dictionary] = ex.choose("self_only")
	assert_false(ex.st.npcs["matthew"]["alive"])
	assert_eq(ex.st.tether["npc"], "kaplan")
	assert_false(ex.st.characters["mu_gang"].alive)
	assert_true(_types(events).has("tether_transferred"))
	assert_false(bool(ex.st.flags.get("side:save_matthew", false)))


## 从线索推理火焰女皇：主机房的对话给线索，詹岚花 10 分钟推出结论（带可信度）。
func test_deduce_from_clues() -> void:
	var ex := _to_laser()
	ex.choose("save_matthew")
	ex.move("s1", "control")
	assert_almost(ex.st.intel.clue_weight("queen_controls_lasers"), 1.0)
	var events: Array[Dictionary] = ex.deduce("queen_controls_lasers", "zhan_lan")
	assert_eq(events[0]["type"], "inference")
	assert_almost(float(events[0]["confidence"]), 0.655)
	assert_eq(ex.st.clock, 55)


## 原剧情路线走到底：丧尸、留守、威胁火焰女皇、断电、内门，撑到 3:07 回归；
## 郑吒 6500 点（存活 1000 + 救马修 5000 + 精神突破 500）和一个 B 级支线。
func test_canon_route_to_return() -> void:
	var g := GameState.new(1)
	var ex := Campaign.start(g, CHAPTER)
	ex.choose("listen")
	ex.move("s1", "hall")
	assert_eq(ex.st.clock, 10)
	assert_eq(ex.st.tether["npc"], "matthew")
	ex.move("s1", "stairs")
	ex.choose("help")
	ex.move("s1", "laser")
	ex.dismiss_cutscene()
	assert_eq(String(ex.st.pending_check.get("id", "")), "convince_matthew")
	ex.resolve_persuasion(2)
	ex.choose("save_matthew")
	ex.move("s1", "control")
	assert_eq(ex.st.clock, 45)
	ex.deduce("queen_controls_lasers", "zhan_lan")
	ex.rest("s1", 15)
	assert_eq(ex.st.clock, 70)
	assert_eq(ex.st.pending_battle["location"], "control")
	_win(ex)
	ex.rest("s1", 20)
	assert_eq(ex.st.clock, 90)
	assert_eq(ex.st.pending_choice["id"], "stay_or_follow")
	ex.choose("stay")
	assert_true(bool(ex.st.flags["stay_control"]))
	ex.rest("s1", 35)
	assert_eq(ex.st.clock, 125)
	assert_eq(ex.st.pending_check["id"], "threaten_queen")
	var talk: Array[Dictionary] = ex.persuade_with(["威胁", "断电", "激光"], "zhan_lan")
	assert_true(bool(talk[0]["success"]))
	assert_true(bool(ex.st.flags["queen_helps"]))
	ex.rest("s1", 40)
	assert_eq(ex.st.clock, 165)
	assert_true(bool(ex.st.flags["power_out"]))
	ex.rest("s1", 5)
	assert_eq(ex.st.clock, 170)
	assert_eq(ex.st.fired["lickers_inner"], "altered")
	assert_true(ex.st.pending_battle.is_empty())
	ex.rest("s1", 17)
	assert_eq(ex.st.clock, 187)
	assert_eq(ex.st.outcome, "returned")
	var results: Dictionary = ex.finish()
	assert_eq(int(results["zheng_zha"]["final_points"]), 6500)
	assert_eq(int(results["zhang_jie"]["final_points"]), 1100, "张杰只拿存活 1000 和自己的讲解奖励 100")
	assert_eq(int(results["mu_gang"]["final_points"]), 1000, "个人支线不发给别人")
	assert_true(g.characters["zheng_zha"].tickets.has_at_least("B"))
	assert_eq(g.films_record, ["biohazard1"])


## 下水道路线：分兵后全队在下水道，有丧尸犬和爬行者，撑到最后拿 D 级支线。
func test_sewer_route() -> void:
	var ex := _to_laser()
	ex.choose("save_matthew")
	ex.move("s1", "control")
	ex.rest("s1", 25)
	assert_eq(ex.st.clock, 70)
	_win(ex)
	ex.rest("s1", 20)
	assert_eq(ex.st.clock, 90)
	ex.choose("follow")
	assert_eq(ex.st.location_of("zheng_zha"), "sewer")
	assert_eq(ex.st.npcs["matthew"]["location"], "sewer")
	var sid: String = ex.st.squad_of("zheng_zha")
	ex.rest(sid, 10)
	assert_eq(ex.st.clock, 100)
	assert_eq(ex.st.pending_battle["location"], "sewer")
	_win(ex)
	ex.rest(sid, 50)
	assert_eq(ex.st.clock, 150)
	assert_eq(ex.st.pending_battle["location"], "sewer")
	_win(ex)
	ex.rest(sid, 30)
	assert_eq(ex.st.clock, 180)
	assert_true(bool(ex.st.flags["sewer_out"]))
	ex.rest(sid, 7)
	assert_eq(ex.st.outcome, "returned")
	assert_true(bool(ex.st.flags.get("side:sewer_escape", false)))
```

- [ ] **Step 4：改写 `game/tests/unit/session/test_session.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Session = preload("res://core/session/session.gd")

const SAVE_PATH := "user://test_session.json"


func _clean() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


## 新游戏：七个人、远征阶段、开场就要表态。
func test_start_m1() -> void:
	var s := Session.new()
	assert_true(s.start_m1(1))
	assert_eq(s.phase, "expedition")
	assert_eq(s.game.characters.size(), 7)
	assert_true(s.expedition != null)
	assert_eq(s.blocked_reason(), "choice")
	assert_eq(s.day, 0)


## 远征中途存档，读档后继续走，事件和状态完全一样。
func test_save_and_resume() -> void:
	_clean()
	var a := Session.new()
	a.start_m1(1)
	a.expedition.choose("listen")
	a.expedition.move("s1", "hall")
	assert_eq(a.save_to(SAVE_PATH), OK)
	var b := Session.load_from(SAVE_PATH)
	assert_true(b != null)
	assert_eq(b.phase, "expedition")
	assert_eq(b.game.to_dict(), a.game.to_dict())
	assert_eq(b.expedition.to_dict(), a.expedition.to_dict())
	var ea: Array[Dictionary] = a.expedition.move("s1", "stairs")
	var eb: Array[Dictionary] = b.expedition.move("s1", "stairs")
	assert_eq(eb, ea)
	assert_eq(b.expedition.st.clock, a.expedition.st.clock)
	assert_eq(b.expedition.st.pending_choice, a.expedition.st.pending_choice)
	_clean()


## 结算只能做一次；然后进主神空间，休整 9 天后才能出发。
func test_settle_and_rest_days() -> void:
	var s := Session.new()
	s.start_m1(1)
	s.expedition.st.outcome = "returned"
	var results: Dictionary = s.settle()
	assert_eq(s.phase, "settlement")
	assert_eq(s.day, 0)
	assert_eq(int(results["zheng_zha"]["final_points"]), 1000)
	assert_eq(s.settle(), {})
	assert_true(s.enter_hub())
	for i in 9:
		assert_true(s.advance_day())
	assert_eq(s.day, 9)
	assert_true(s.can_depart())
	assert_true(s.depart())
	assert_eq(s.phase, "done")
	assert_false(s.advance_day())


## 结算后存档，读档保留阶段、天数、结算结果和点数。
func test_save_after_settlement() -> void:
	_clean()
	var a := Session.new()
	a.start_m1(2)
	a.expedition.st.outcome = "returned"
	a.settle()
	a.enter_hub()
	a.advance_day()
	assert_eq(a.save_to(SAVE_PATH), OK)
	var b := Session.load_from(SAVE_PATH)
	assert_true(b != null)
	assert_eq(b.phase, "hub")
	assert_eq(b.day, 1)
	assert_eq(int(b.game.characters["zheng_zha"].points), 1000)
	assert_eq(int(b.settlement["zheng_zha"]["final_points"]), 1000)
	assert_eq(b.to_dict()["expedition"], a.to_dict()["expedition"])
	_clean()


## 主神议程随存档走：开局的半引导者异常读档后还在。
func test_agenda_saved() -> void:
	_clean()
	var a := Session.new()
	a.start_m1(3)
	assert_true(a.game.agenda.open_anomaly("half_guide", "zhang_jie") != "")
	assert_eq(a.save_to(SAVE_PATH), OK)
	var b := Session.load_from(SAVE_PATH)
	assert_eq(b.game.agenda.to_dict(), a.game.agenda.to_dict())
	_clean()


## 结算时主神调整评价：七人全活（本该团灭）→ +1；只活三人（原著）→ 不变。总评随存档走。
func test_film_report_rating() -> void:
	var s := Session.new()
	s.start_m1(1)
	s.expedition.st.outcome = "returned"
	s.settle()
	assert_eq(s.film_report["survivors"], 7)
	assert_eq(s.film_report["rating_before"], 0)
	assert_eq(s.film_report["rating_after"], 1)
	assert_eq(s.game.team_rating, 1)
	var t := Session.new()
	t.start_m1(1)
	for c in ["li_xiao_yi", "mu_gang", "xiao_pang_zi", "zhong_nian_fu_nv"]:
		t.game.characters[c].alive = false
	t.expedition.st.outcome = "returned"
	t.settle()
	assert_eq(t.film_report["survivors"], 3)
	assert_eq(t.film_report["rating_after"], 0)
	var kinds: Array = []
	for d: Dictionary in t.game.agenda.decisions:
		kinds.append(String(d["kind"]))
	assert_true(kinds.has("rating"))
	assert_true(kinds.has("keep_pressure"), "半引导者异常没解除，主神记一条继续加压")
	assert_eq(Session.new().load_dict(t.to_dict()), true)
	var u := Session.new()
	u.load_dict(t.to_dict())
	assert_eq(u.film_report, t.film_report)


## 郑吒造萝丽：潜力突升 → 主神悄悄把他复制进恶魔小队；第二个造物不再突升。
func test_human_creation_demon_copy() -> void:
	var s := Session.new()
	s.start_m1(1)
	s.expedition.st.outcome = "returned"
	s.settle()
	var events: Array[Dictionary] = s.hub.create_human("zheng_zha", "萝丽", {"spirit": 120})
	assert_eq(String(events[0]["type"]), "human_created")
	assert_eq(events.size(), 1, "复制进恶魔小队是隐藏的，不给玩家发事件")
	assert_eq(s.game.agenda.demon_copies, ["zheng_zha"])
	assert_true(bool(s.game.flags["seen_human_creation"]))
	s.game.characters["zheng_zha"].points = 600
	s.hub.create_human("zheng_zha", "二号", {})
	assert_almost(float(s.game.agenda.potentials["zheng_zha"]), 0.25)


func test_reject_bad_save() -> void:
	assert_false(Session.new().load_dict({"version": 99}))
	assert_false(Session.new().load_dict({"version": 1, "chapter": "res://nope.json", "game": {}}))
	assert_true(Session.load_from("user://nope.json") == null)
```

- [ ] **Step 5：运行，确认失败**

Run: `bash game/tools/run_tests.sh | tail -3`

预期：有失败，或者因为 `open_anomaly` / `agenda` / `film_report` 还不存在而出现 `SCRIPT ERROR`；这一步只要不是全部通过就对。

- [ ] **Step 6：改写 `game/core/director/agenda.gd`**

```gdscript
extends RefCounted
## 主神议程骨架（设计规格 5.5，核心机制分析 1.0~1.4、2.2）：主神是有目的的行动者，为每支队伍维护隐藏议程——
##   标准课程走到哪一步（引导者 → 队长 → 成长窗口 → 团战 → 加难 → 瓶颈试炼 → 终局）；
##   异常（例：张杰这种"半引导者"）与最后通牒；每个人的潜力与潜力突升；被复制进恶魔小队的人；拖后腿的因素；瓶颈。
## 每个决定都附一段隐藏的"主神理由"，写进存档（调试用，也是智者推理的对象）。
## 这里还有两个能算的东西：一部片之后评价怎么变；主神眼中的"评价战力"（用来算相对击杀奖励）。

const DataLoader = preload("res://core/util/data_loader.gd")
const Attributes = preload("res://core/model/attributes.gd")

const PATH := "res://data/director/director_rules.json"

static var _cache: Dictionary = {}

var stage: String = "guide"
## {"id", "kind", "char", "since_film", "note", "resolved_film"}；char 是异常落在谁身上（可为空）。
var anomalies: Array = []
var next_anomaly_no: int = 1
## {"kind", "deadline_film", "note"}；空字典表示没有
var ultimatum: Dictionary = {}
var potentials: Dictionary = {}
var demon_copies: Array = []
var drag_factors: Array = []
var bottlenecks: Dictionary = {}
## 主神的决定和理由：{"film", "kind", "payload", "reason"}
var decisions: Array = []


static func rules() -> Dictionary:
	if _cache.is_empty():
		var res := DataLoader.load_json(PATH)
		assert(res.ok, res.error)
		_cache = res.data
	return _cache


func record(film: String, kind: String, payload: Dictionary, reason: String) -> void:
	decisions.append({"film": film, "kind": kind, "payload": payload.duplicate(true), "reason": reason})


## 课程推进一步；已经到终局时返回 false。
func advance_stage(film: String, reason: String) -> bool:
	var stages: Array = rules()["stages"]
	var i := stages.find(stage)
	if i >= stages.size() - 1:
		return false
	stage = String(stages[i + 1])
	record(film, "advance_stage", {"stage": stage}, reason)
	return true


func add_anomaly(kind: String, film: String, note: String, reason: String, char_id: String = "") -> String:
	var id := "anomaly_%d" % next_anomaly_no
	next_anomaly_no += 1
	anomalies.append({"id": id, "kind": kind, "char": char_id, "since_film": film, "note": note, "resolved_film": ""})
	record(film, "add_anomaly", {"id": id, "kind": kind, "char": char_id}, reason)
	return id


## 同一种异常（落在同一个人身上）还开着吗？返回它的 id，没有返回空字符串。
func open_anomaly(kind: String, char_id: String = "") -> String:
	for a: Dictionary in open_anomalies():
		if a["kind"] == kind and String(a.get("char", "")) == char_id:
			return String(a["id"])
	return ""


func resolve_anomaly(id: String, film: String, reason: String) -> bool:
	for a: Dictionary in anomalies:
		if a["id"] == id and a["resolved_film"] == "":
			a["resolved_film"] = film
			record(film, "resolve_anomaly", {"id": id}, reason)
			return true
	return false


func open_anomalies() -> Array:
	return anomalies.filter(func(a: Dictionary) -> bool: return a["resolved_film"] == "")


func set_ultimatum(kind: String, deadline_film: String, note: String, film: String, reason: String) -> void:
	ultimatum = {"kind": kind, "deadline_film": deadline_film, "note": note}
	record(film, "ultimatum", ultimatum, reason)


## 潜力突升（造人、凭自身属性开锁、心魔突破、顿悟……）。突升够大时，主神会考虑复制进恶魔小队（返回 true）。
func potential_spike(char_id: String, amount: float, film: String, reason: String) -> bool:
	potentials[char_id] = float(potentials.get(char_id, 0.0)) + amount
	record(film, "potential_spike", {"char": char_id, "amount": amount}, reason)
	var consider := amount >= float(rules()["demon_copy_spike"]) and not demon_copies.has(char_id)
	if consider:
		record(film, "consider_demon_copy", {"char": char_id}, "潜力突升够大，值得做对照实验")
	return consider


func copy_to_demon_team(char_id: String, film: String, reason: String) -> void:
	if not demon_copies.has(char_id):
		demon_copies.append(char_id)
	record(film, "demon_copy", {"char": char_id}, reason)


## 一部片之后评价怎么变（核心机制分析 2.2）：
##   result = {"expected_wipe": 主神本来按团灭安排, "members": 人数, "survivors": 活着回来的人数（中途死过又复活的不算活着）,
##             "captain_died": 队长死了, "all_died": 所有人都死过}
##   所有人都死过 → 评价清零，经历过的片的记录消失；
##   活过一部本该团灭的片、损失又小（幸存比例 ≥ 0.7）→ +1；队长死亡 → −1（不低于 0）。
static func update_rating(game_state: RefCounted, result: Dictionary) -> Dictionary:
	var r: Dictionary = rules()["rating"]
	var before: int = game_state.team_rating
	var reasons: Array[String] = []
	if bool(result.get("all_died", false)):
		game_state.team_rating = 0
		game_state.films_record.clear()
		reasons.append("wiped")
		return {"before": before, "after": 0, "reasons": reasons}
	var rating := before
	var members := maxi(1, int(result.get("members", 1)))
	if bool(result.get("expected_wipe", false)) and float(result.get("survivors", 0)) / members >= float(r["low_loss_survivor_ratio"]):
		rating += int(r["survive_wipe_bonus"])
		reasons.append("survived_wipe")
	if bool(result.get("captain_died", false)):
		rating += int(r["captain_death"])
		reasons.append("captain_died")
	game_state.team_rating = maxi(0, rating)
	return {"before": before, "after": game_state.team_rating, "reasons": reasons}


## 评价战力：主神只看得见兑换来的东西，看不见锻炼（base）和基因锁。
## = 基准 × (1 + 评价 × 系数) × 队伍平均"可见属性" / 100，可见属性 = 100 + 兑换属性（enhanced + enhanced_high 全额）÷ 6。
## 新人队伍（评价 0、没兑换）正好是 120，和计划 3 的默认值一致。
static func rating_power(game_state: RefCounted, member_ids: Array) -> float:
	var rp: Dictionary = rules()["rating_power"]
	var total := 0.0
	var n := 0
	for id: String in member_ids:
		var ch: RefCounted = game_state.characters[id]
		if not ch.alive:
			continue
		var visible := 0.0
		for k in Attributes.KEYS:
			visible += float(ch.attributes.enhanced[k]) + float(ch.attributes.enhanced_high[k])
		total += 100.0 + visible / 6.0
		n += 1
	var avg := total / n if n > 0 else 100.0
	return float(rp["base"]) * (1.0 + game_state.team_rating * float(rp["per_rating"])) * avg / 100.0


func to_dict() -> Dictionary:
	return {
		"stage": stage,
		"anomalies": anomalies.duplicate(true),
		"next_anomaly_no": next_anomaly_no,
		"ultimatum": ultimatum.duplicate(true),
		"potentials": potentials.duplicate(),
		"demon_copies": demon_copies.duplicate(),
		"drag_factors": drag_factors.duplicate(true),
		"bottlenecks": bottlenecks.duplicate(true),
		"decisions": decisions.duplicate(true),
	}


func load_dict(d: Dictionary) -> void:
	stage = String(d["stage"])
	anomalies = (d["anomalies"] as Array).duplicate(true)
	next_anomaly_no = int(d["next_anomaly_no"])
	ultimatum = (d["ultimatum"] as Dictionary).duplicate(true)
	potentials = (d["potentials"] as Dictionary).duplicate()
	demon_copies = (d["demon_copies"] as Array).duplicate()
	drag_factors = (d["drag_factors"] as Array).duplicate(true)
	bottlenecks = (d["bottlenecks"] as Dictionary).duplicate(true)
	decisions = (d["decisions"] as Array).duplicate(true)
```

- [ ] **Step 7：改写 `game/data/director/director_rules.json`**

```json
{
	"version": 1,
	"stages": ["guide", "captain", "growth", "team_battle", "escalation", "bottleneck", "finale"],
	"rating": {
		"survive_wipe_bonus": 1,
		"low_loss_survivor_ratio": 0.7,
		"captain_death": -1
	},
	"rating_power": {
		"base": 120,
		"per_rating": 0.5
	},
	"demon_copy_spike": 0.2,
	"human_creation_spike": 0.25
}
```

- [ ] **Step 8：改写 `game/core/model/game_state.gd`**

```gdscript
extends RefCounted
## 整局游戏状态。存档就是它的 to_dict()。

const Rng = preload("res://core/util/rng.gd")
const Character = preload("res://core/model/character.gd")
const Agenda = preload("res://core/director/agenda.gd")

const SAVE_VERSION := 1

var rng: RefCounted = Rng.new(0)
var characters: Dictionary = {}  # id -> Character
var team_rating: int = 0  # 主神评价分（核心机制分析 2.2）
var films_record: Array = []  # 经历过的片的 id；团灭时清空
var mode: Dictionary = {"content": "canon", "control": "team"}
var iron_man: bool = true
## 造物（人造人）：{"id", "name", "creator", "attributes"}。制造者死亡，造物随之消失（设计规格 6.6）。
var companions: Array = []
var flags: Dictionary = {}
## 主神议程（设计规格 5.5）：课程阶段、异常、潜力突升、恶魔小队复制体和每个决定的理由。玩家看不见，随存档走。
var agenda: RefCounted = Agenda.new()


func _init(seed_value: int = 0) -> void:
	rng = Rng.new(seed_value)


func add_character(c: RefCounted) -> void:
	characters[c.id] = c


func living_characters() -> Array:
	return characters.values().filter(func(c): return c.alive)


func to_dict() -> Dictionary:
	var chars := {}
	for id in characters:
		chars[id] = characters[id].to_dict()
	return {
		"version": SAVE_VERSION,
		"rng": rng.to_dict(),
		"characters": chars,
		"team_rating": team_rating,
		"films_record": films_record.duplicate(),
		"mode": mode.duplicate(),
		"iron_man": iron_man,
		"companions": companions.duplicate(true),
		"flags": flags.duplicate(true),
		"agenda": agenda.to_dict(),
	}


func load_dict(d: Dictionary) -> void:
	assert(int(d["version"]) == SAVE_VERSION, "存档版本不匹配")
	rng.load_dict(d["rng"])
	characters.clear()
	for id in d["characters"]:
		var c := Character.new()
		c.load_dict(d["characters"][id])
		characters[id] = c
	team_rating = int(d["team_rating"])
	films_record = (d["films_record"] as Array).duplicate()
	mode = (d["mode"] as Dictionary).duplicate()
	iron_man = bool(d["iron_man"])
	companions = (d.get("companions", []) as Array).duplicate(true)
	flags = (d["flags"] as Dictionary).duplicate(true)
	agenda = Agenda.new()
	if d.has("agenda"):
		agenda.load_dict(d["agenda"])
```

- [ ] **Step 9：改写 `game/core/campaign/campaign.gd`**

```gdscript
extends RefCounted
## 章节装配（设计规格 9、10.1）：一份章节 JSON 把剧本、人物表和开局名单拼成一次远征。
## 章节 JSON：{"id", "name", "scenario", "roster", "members"}，两个路径都是 res:// 下的 JSON。
## 可选的 "agenda"：这部片开场时主神议程的状态——{"expected_wipe": 按团灭安排, "anomalies": [{"kind", "char", "note", "reason"}],
##   "decisions": [{"kind", "payload", "reason"}]}。开局时写进 GameState.agenda（同一异常不重复记）。
## 人物表 JSON：{"version", "characters": {id: {"name", "attributes", "skills", "items", "films_completed", "flags"}}}。
## 这里只做装配和校验；远征本身的规则在 expedition/ 里。

const Character = preload("res://core/model/character.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const Expedition = preload("res://core/expedition/expedition.gd")
const Agenda = preload("res://core/director/agenda.gd")
const Attributes = preload("res://core/model/attributes.gd")
const DataLoader = preload("res://core/util/data_loader.gd")
const BattleData = preload("res://core/battle/battle_data.gd")

const REQUIRED: Array[String] = ["id", "name", "scenario", "roster", "members"]


## 读章节文件；读不到时返回空字典，错误由 validate_chapter 报告。
static func load_chapter(path: String) -> Dictionary:
	var res := DataLoader.load_json(path)
	if not res.ok:
		push_error(res.error)
		return {}
	return res.data


## 人物表 → 角色 id → Character。读不到时返回空字典。
static func build_roster(path: String) -> Dictionary:
	var res := DataLoader.load_json(path)
	if not res.ok:
		push_error(res.error)
		return {}
	var out := {}
	for id: String in res.data.get("characters", {}):
		var d: Dictionary = res.data["characters"][id]
		var ch := Character.new(id, String(d.get("name", id)), d.get("attributes", {}))
		ch.skills.assign(d.get("skills", []))
		ch.items = (d.get("items", {}) as Dictionary).duplicate()
		ch.points = int(d.get("points", 0))
		ch.films_completed = int(d.get("films_completed", 0))
		ch.flags = (d.get("flags", {}) as Dictionary).duplicate(true)
		ch.hp = ch.hp_max()
		out[id] = ch
	return out


## 检查章节能不能开局：路径存在、剧本合法、名单上的人都在、技能都有定义、属性齐全。
static func validate_chapter(ch: Dictionary) -> Array[String]:
	var errors: Array[String] = DataLoader.missing_keys(ch, REQUIRED, "章节")
	if not errors.is_empty():
		return errors
	var sc_res := DataLoader.load_json(String(ch["scenario"]))
	if not sc_res.ok:
		errors.append("剧本：%s" % sc_res.error)
	else:
		for e: String in Scenario.new(sc_res.data).validate():
			errors.append("剧本：%s" % e)
	var roster_res := DataLoader.load_json(String(ch["roster"]))
	if not roster_res.ok:
		errors.append("人物表：%s" % roster_res.error)
		return errors
	var roster: Dictionary = roster_res.data.get("characters", {})
	var members: Array = ch["members"]
	if members.is_empty():
		errors.append("章节没有开局名单")
	var seen := {}
	for id: String in members:
		if seen.has(id):
			errors.append("开局名单重复：%s" % id)
		seen[id] = true
		if not roster.has(id):
			errors.append("人物表里没有 %s" % id)
			continue
		var d: Dictionary = roster[id]
		for k in Attributes.KEYS:
			if not (d.get("attributes", {}) as Dictionary).has(k):
				errors.append("%s 缺少属性 %s" % [id, k])
		for s: String in d.get("skills", []):
			if not BattleData.skills().has(s):
				errors.append("%s 的技能 %s 不存在" % [id, s])
	return errors


## 把章节的议程块写进主神议程：异常（已经开着的不重复记）和开场决定，每条都带主神理由。
static func apply_agenda(game_state: RefCounted, ch: Dictionary, film: String) -> void:
	var ag: Dictionary = ch.get("agenda", {})
	var agenda: RefCounted = game_state.agenda
	for a: Dictionary in ag.get("anomalies", []):
		var who := String(a.get("char", ""))
		if agenda.open_anomaly(String(a["kind"]), who) == "":
			agenda.add_anomaly(String(a["kind"]), film, String(a.get("note", "")), String(a.get("reason", "")), who)
	for d: Dictionary in ag.get("decisions", []):
		agenda.record(film, String(d["kind"]), d.get("payload", {}), String(d.get("reason", "")))


## 开局：把名单上的人加进 GameState（已有同名角色则覆盖），按主神评价战力开一部片。
## 返回 Expedition；章节数据有误时返回 null（错误已经 push_error）。
static func start(game_state: RefCounted, path: String) -> RefCounted:
	var ch := load_chapter(path)
	var errors := validate_chapter(ch)
	if not errors.is_empty():
		push_error("章节数据有误：" + "；".join(errors))
		return null
	var roster := build_roster(String(ch["roster"]))
	var members: Array[String] = []
	for id: String in ch["members"]:
		members.append(String(id))
	for id: String in members:
		game_state.add_character(roster[id])
	var sc := Scenario.load_file(String(ch["scenario"]))
	apply_agenda(game_state, ch, sc.id)
	var ex := Expedition.new()
	ex.start(game_state, sc, members, {"rating_power": Agenda.rating_power(game_state, members)})
	return ex
```

- [ ] **Step 10：改写 `game/data/scenarios/biohazard1/chapter.json`**

```json
{
	"id": "m1",
	"name": "生化危机一",
	"scenario": "res://data/scenarios/biohazard1/scenario.json",
	"roster": "res://data/characters/m1_roster.json",
	"members": ["zheng_zha", "zhang_jie", "zhan_lan", "li_xiao_yi", "mu_gang", "xiao_pang_zi", "zhong_nian_fu_nv"],
	"agenda": {
		"expected_wipe": true,
		"anomalies": [
			{
				"kind": "half_guide",
				"char": "zhang_jie",
				"note": "张杰活过三部片、实力够当引导者，却一直不肯接受引导者考验（半引导者）。",
				"reason": "异常不纠正，整支队伍的课程推不动：刻意加难，难度按队里最强的张杰来定，逼他表态（原著 L5595）。"
			}
		],
		"decisions": [
			{
				"kind": "difficulty_anchor",
				"payload": {"anchor": "zhang_jie"},
				"reason": "生化危机一的安排按张杰的实力定，新人只是陪跑；按差一点团灭来设计（设计规格 5.5）。"
			}
		]
	}
}
```

- [ ] **Step 11：改写 `game/core/session/session.gd`**

```gdscript
extends RefCounted
## 一局游戏（设计规格 2、10.2）：把 GameState、当前远征、阶段和休整天数装在一起。
## 阶段：expedition（在片子里）→ settlement（刚回归，结算完）→ hub（主神空间休整 9 天）→ done（下一次出发，M2 未做）。
## 界面只读这里的 game / expedition，并调用这里的方法推进；存档就是 to_dict()。

const GameState = preload("res://core/model/game_state.gd")
const Campaign = preload("res://core/campaign/campaign.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const Expedition = preload("res://core/expedition/expedition.gd")
const SaveService = preload("res://core/save/save_service.gd")
const Hub = preload("res://core/hub/hub.gd")
const Agenda = preload("res://core/director/agenda.gd")

const VERSION := 1
const M1_CHAPTER := "res://data/scenarios/biohazard1/chapter.json"
const PHASES: Array[String] = ["expedition", "settlement", "hub", "done"]
const REST_DAYS := 9

var game: RefCounted
var expedition: RefCounted
## 休整期的主神空间（settlement / hub 阶段才有）。
var hub: RefCounted
var phase: String = "expedition"
var chapter_path: String = ""
## 休整第几天（settlement 时为 1）。
var day: int = 0
## 上一次结算的结果（角色 id → 结算条目），给结算界面用。
var settlement: Dictionary = {}
## 对话记忆与信任：npc_id → {"memories": [...], "trust": 0~5}。core/dialogue 直接读写这个字典。
var dialogues: Dictionary = {}
## 上一部片的总评（结算界面用）：{"film", "members", "survivors", "rating_before", "rating_after", "reasons"}。
var film_report: Dictionary = {}


## 开一局：建 GameState、按章节装配七名轮回者、开始第一部片。
func start(chapter: String, seed_value: int = 0) -> bool:
	chapter_path = chapter
	game = GameState.new(seed_value)
	expedition = Campaign.start(game, chapter)
	if expedition == null:
		return false
	phase = "expedition"
	hub = null
	day = 0
	settlement = {}
	dialogues = {}
	film_report = {}
	return true


func start_m1(seed_value: int = 0) -> bool:
	return start(M1_CHAPTER, seed_value)


func in_expedition() -> bool:
	return phase == "expedition" and expedition != null


func expedition_over() -> bool:
	return expedition != null and String(expedition.st.outcome) != "ongoing"


## 现在为什么不能行动："" 表示可以，否则是 battle / choice / check / ended。
func blocked_reason() -> String:
	if not in_expedition():
		return "ended"
	if expedition.st.outcome != "ongoing":
		return "ended"
	if not expedition.st.pending_cutscene.is_empty():
		return "cutscene"
	if not expedition.st.pending_battle.is_empty():
		return "battle"
	if not expedition.st.pending_check.is_empty():
		return "check"
	if not expedition.st.pending_choice.is_empty():
		return "choice"
	return ""


## 片子结束（回归、全灭或剧本结局）后结算一次，进入 settlement 阶段。
func settle() -> Dictionary:
	if phase != "expedition" or not expedition_over():
		return {}
	settlement = expedition.finish()
	film_report = _rate_film()
	hub = Hub.new()
	hub.start(game, REST_DAYS)
	phase = "settlement"
	day = hub.day
	return settlement


## 主神按这部片的结果调整评价（设计规格 7.3）：本该团灭的片活下来七成以上 +1、所有人都死过清零。
## 半引导者这类异常没解除时，主神记一条"继续加压"的决定。
func _rate_film() -> Dictionary:
	var st: RefCounted = expedition.st
	var film: String = st.scenario.id
	var ag: Dictionary = Campaign.load_chapter(chapter_path).get("agenda", {})
	var survivors := 0
	for c: String in st.roster:
		if st.is_alive(c):
			survivors += 1
	var result := {
		"expected_wipe": bool(ag.get("expected_wipe", false)),
		"members": st.roster.size(),
		"survivors": survivors,
		"captain_died": false,
		"all_died": survivors == 0,
	}
	var r := Agenda.update_rating(game, result)
	game.agenda.record(film, "rating", r, "幸存 %d/%d：%s" % [survivors, st.roster.size(), "、".join(r["reasons"]) if not (r["reasons"] as Array).is_empty() else "评价不变"])
	for a: Dictionary in game.agenda.open_anomalies():
		game.agenda.record(film, "keep_pressure", {"anomaly": a["id"]}, "异常（%s）还没解除，下一部继续按最强者定难度。" % String(a["kind"]))
	return {
		"film": film, "members": st.roster.size(), "survivors": survivors,
		"rating_before": int(r["before"]), "rating_after": int(r["after"]), "reasons": (r["reasons"] as Array).duplicate(),
	}


func enter_hub() -> bool:
	if phase != "settlement":
		return false
	phase = "hub"
	return true


func advance_day() -> bool:
	if phase != "hub" or hub == null or hub.can_depart():
		return false
	hub.rest(1)
	day = hub.day
	return true


func can_depart() -> bool:
	return phase == "hub" and hub != null and hub.can_depart()


## 走光柱出发；M2 的内容还没做，先把阶段停在 done。
func depart() -> bool:
	if not can_depart():
		return false
	phase = "done"
	return true


func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"phase": phase,
		"chapter": chapter_path,
		"day": day,
		"game": game.to_dict() if game != null else {},
		"expedition": expedition.to_dict() if expedition != null else {},
		"hub": hub.to_dict() if hub != null else {},
		"settlement": settlement.duplicate(true),
		"dialogues": dialogues.duplicate(true),
		"film_report": film_report.duplicate(true),
	}


## 读档失败返回 false（版本不对、字段缺失、剧本读不到）。
func load_dict(d: Dictionary) -> bool:
	if int(d.get("version", 0)) != VERSION or not d.has("game") or not d.has("chapter"):
		return false
	chapter_path = String(d["chapter"])
	var chapter := Campaign.load_chapter(chapter_path)
	if chapter.is_empty():
		return false
	game = GameState.new()
	game.load_dict(d["game"])
	phase = String(d.get("phase", "expedition"))
	if not PHASES.has(phase):
		return false
	day = int(d.get("day", 0))
	settlement = (d.get("settlement", {}) as Dictionary).duplicate(true)
	dialogues = (d.get("dialogues", {}) as Dictionary).duplicate(true)
	film_report = (d.get("film_report", {}) as Dictionary).duplicate(true)
	var h: Dictionary = d.get("hub", {})
	if not h.is_empty():
		hub = Hub.new()
		hub.load_dict(h, game)
		day = hub.day
	var e: Dictionary = d.get("expedition", {})
	if e.is_empty():
		expedition = null
		return phase != "expedition"
	var sc := Scenario.load_file(String(chapter["scenario"]))
	if sc == null:
		return false
	expedition = Expedition.new()
	expedition.load_dict(e, game, sc)
	return true


func save_to(path: String) -> Error:
	return SaveService.write_dict(path, to_dict())


static func load_from(path: String) -> RefCounted:
	var d := SaveService.read_dict(path)
	if d.is_empty():
		return null
	var s := new()
	if not s.load_dict(d):
		return null
	return s
```

- [ ] **Step 12：改写 `game/core/hub/hub.gd`**

```gdscript
extends RefCounted
## 主神空间的一次休整（设计规格 6.2~6.4）。休整天数是行动点：兑换、结算、造人、修复不耗天；训练、休息耗天。
## 原著惯例：回归当晚（第 0 天）不兑换，只结算和造人；最后一天强制休息，不能训练；每天恐惧自然下降。
## 代兑：每人每次休整只能用自己的点数或支线给别人兑换一次（设计规格 6.3）。
## 天赋：兑换契合的强化、训练或对练会触发觉醒（talents.gd）；觉醒的"学得快"让训练熟练度翻倍。
## 造人：每个制造者的第一个造物让他的潜力突升；突升够大，主神悄悄把他复制进恶魔小队（议程里记着，玩家不知道）。

const Exchange = preload("res://core/hub/exchange.gd")
const Pricing = preload("res://core/hub/pricing.gd")
const Rules = preload("res://core/util/rules.gd")
const Battle = preload("res://core/battle/battle.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
const Rng = preload("res://core/util/rng.gd")
const Catalog = preload("res://core/hub/catalog.gd")
const Talents = preload("res://core/model/talents.gd")
const Agenda = preload("res://core/director/agenda.gd")

## 对练用的傀儡血量，用来换算"打掉了多少"。
const DUMMY_HP := 240.0

var game: RefCounted
var days_total: int = 10
## 0 = 回归当晚；每过一天加 1，到 days_total 就该出发了。
var day: int = 0
## 这次休整里已经给别人付过钱的人。
var gifts: Dictionary = {}
var history: Array[Dictionary] = []


func start(game_state: RefCounted, days: int = -1) -> Array[Dictionary]:
	game = game_state
	days_total = days if days > 0 else int(Pricing.rules()["rest"]["days_default"])
	day = 0
	gifts = {}
	return _emit([{"type": "hub_start", "days": days_total}])


func days_left() -> int:
	return days_total - day


func can_depart() -> bool:
	return day >= days_total


func _char(id: String) -> RefCounted:
	return game.characters[id]


func _emit(events: Array[Dictionary]) -> Array[Dictionary]:
	history.append_array(events)
	return events


func _refuse(reason: String) -> Array[Dictionary]:
	return _emit([{"type": "hub_refused", "reason": reason}])


## 兑换。opts：payer（付钱的人的 id）、accept_risk（坚持兑换有变异风险的血统）。
func exchange(char_id: String, entry_id: String, opts: Dictionary = {}) -> Array[Dictionary]:
	if day == 0:
		return _refuse("return_night")
	var payer_id := String(opts.get("payer", char_id))
	var gift := payer_id != char_id
	var events := Exchange.buy(_char(char_id), entry_id, game.rng, {
		"payer": _char(payer_id) if gift else null,
		"accept_risk": bool(opts.get("accept_risk", false)),
		"gift_used": gift and gifts.has(payer_id),
	})
	if events[0]["type"] == "exchange_done":
		if gift:
			gifts[payer_id] = true
		var e := Catalog.entry(entry_id)
		_talent(char_id, "bought_series:" + String(e["series"]), events)
		for b: Dictionary in e["blocks"]:
			for k: String in b.get("attr", {}):
				_talent(char_id, "bought_attr:" + k, events)
	return _emit(events)


## 直接强化属性：10 点 = 1 点（原著）。
func buy_attribute(char_id: String, attr: String, amount: int) -> Array[Dictionary]:
	if day == 0:
		return _refuse("return_night")
	var ch := _char(char_id)
	var cost := amount * int(Rules.get_rules()["points_per_attribute"])
	if amount <= 0 or ch.points < cost:
		return _refuse("not_enough_points")
	ch.points -= cost
	ch.attributes.add_enhanced(attr, float(amount))
	var events: Array[Dictionary] = [{"type": "attribute_bought", "char": char_id, "attr": attr, "amount": amount, "cost": cost}]
	_talent(char_id, "bought_attr:" + attr, events)
	return _emit(events)


## 支线拆分（1 个高一级 → 3 个低一级）与合成（3 个 → 1 个高一级）。
func split_ticket(char_id: String, grade: String) -> Array[Dictionary]:
	if not _char(char_id).tickets.split(grade):
		return _refuse("cannot_split")
	return _emit([{"type": "ticket_split", "char": char_id, "grade": grade}])


func merge_tickets(char_id: String, grade: String) -> Array[Dictionary]:
	if not _char(char_id).tickets.merge(grade):
		return _refuse("cannot_merge")
	return _emit([{"type": "tickets_merged", "char": char_id, "grade": grade}])


## 修复费用：生命还有一半以上算"修补"（400）；更重按伤势线性涨到"修复"上限（2000）。满血不要钱。
func repair_cost(char_id: String) -> int:
	var ch := _char(char_id)
	var ratio: float = ch.hp / ch.hp_max()
	if ratio >= 1.0:
		return 0
	var r: Dictionary = Pricing.rules()["repair"]
	var patch := float(r["patch_cost"])
	var threshold := float(r["patch_hp_ratio"])
	if ratio >= threshold:
		return int(patch)
	return roundi(patch + (threshold - maxf(ratio, 0.0)) / threshold * (float(r["full_cost"]) - patch))


## 修复：生命回满，基因锁后遗症消除。可以由别人付钱（修复不算代兑次数）。
func repair(char_id: String, payer_id: String = "") -> Array[Dictionary]:
	var ch := _char(char_id)
	var payer := _char(payer_id if payer_id != "" else char_id)
	var cost := repair_cost(char_id)
	if cost == 0:
		return _refuse("not_injured")
	if payer.points < cost:
		return _refuse("not_enough_points")
	payer.points -= cost
	ch.hp = ch.hp_max()
	ch.flags.erase("gene_lock_aftereffect")
	return _emit([{"type": "repaired", "char": char_id, "payer": payer.id, "cost": cost}])


## 造人（娱乐类）：每个制造者第一个免费，之后 500 点；各项素质最多约两倍常人（设计规格 6.3）。回归当晚就可以造。
func create_human(creator_id: String, name: String, attrs: Dictionary) -> Array[Dictionary]:
	var ch := _char(creator_id)
	var h: Dictionary = Pricing.rules()["human"]
	var made := 0
	for c: Dictionary in game.companions:
		if c["creator"] == creator_id:
			made += 1
	var cost := 0 if made == 0 else int(h["cost"])
	if ch.points < cost:
		return _refuse("not_enough_points")
	ch.points -= cost
	var clamped := {}
	for k: String in attrs:
		clamped[k] = minf(float(attrs[k]), float(h["attr_max"]))
	var companion := {"id": "%s_human_%d" % [creator_id, made + 1], "name": name, "creator": creator_id, "attributes": clamped}
	game.companions.append(companion)
	game.flags["seen_human_creation"] = true
	if made == 0:
		var film := _film()
		if game.agenda.potential_spike(creator_id, float(Agenda.rules()["human_creation_spike"]), film, "造人：%s 按自己的记忆造出了 %s" % [ch.display_name, name]):
			game.agenda.copy_to_demon_team(creator_id, film, "潜力突升够大：复制一份放进恶魔小队，做对照实验（M7 才揭晓）。")
	return _emit([{"type": "human_created", "creator": creator_id, "companion": companion, "cost": cost}])


## 训练：花天数提升已有技能或能力的熟练度。最后一天强制休息，不能占用。
func train(char_id: String, skill_id: String, days: int) -> Array[Dictionary]:
	var ch := _char(char_id)
	if not ch.skills.has(skill_id) and not ch.abilities.has(skill_id):
		return _refuse("unknown_skill")
	if days <= 0 or day + days > days_total - 1:
		return _refuse("no_days")
	var gain := float(Pricing.rules()["train"]["proficiency_per_day"]) * days * Talents.train_mult(ch)
	ch.proficiency[skill_id] = minf(1.0, float(ch.proficiency.get(skill_id, 1.0)) + gain)
	var events: Array[Dictionary] = [{"type": "trained", "char": char_id, "skill": skill_id, "days": days, "proficiency": ch.proficiency[skill_id]}]
	_talent(char_id, "trained", events)
	_pass_days(days, events)
	return _emit(events)


## 训练场对练：拿指定技能跟训练傀儡打一场，耗 1 天。
## 目的是让玩家看见兑换前后的伤害差别；单位是副本，不写回，角色不会受伤、不会耗道具。
func spar(char_id: String, skill_id: String) -> Array[Dictionary]:
	var ch := _char(char_id)
	if ch == null or not ch.alive:
		return _refuse("bad_char")
	if not ch.skills.has(skill_id):
		return _refuse("unknown_skill")
	if day + 1 > days_total - 1:
		return _refuse("no_days")
	var units: Array[RefCounted] = []
	units.append(UnitFactory.from_character(ch, "ally", 0, [skill_id], "player", ch.battle_resources()))
	units.append(UnitFactory.from_enemy("training_dummy", "dummy_1", 0))
	var b := Battle.new()
	b.setup(units, {"allow_retreat": false}, Rng.new(day * 37 + 11))
	var rounds := 0
	while b.outcome == "ongoing" and rounds < 40:
		var acts: Array[Dictionary] = b.legal_actions()
		if acts.is_empty():
			break
		var picked: Dictionary = acts[0]
		for a: Dictionary in acts:
			if String(a.get("type", "")) == "skill":
				picked = a
				break
		b.act(picked)
		rounds += 1
	var dummy: RefCounted = b.field.get_unit("dummy_1")
	var left := maxf(float(dummy.hp), 0.0) if dummy != null else 0.0
	var dealt := clampf(DUMMY_HP - left, 0.0, DUMMY_HP)
	var gain := float(Pricing.rules()["train"]["proficiency_per_day"]) * 0.5 * Talents.train_mult(ch)
	ch.proficiency[skill_id] = minf(1.0, float(ch.proficiency.get(skill_id, 1.0)) + gain)
	var events: Array[Dictionary] = [{
		"type": "spar_done", "char": char_id, "skill": skill_id,
		"damage": dealt, "rounds": rounds, "outcome": b.outcome,
		"proficiency": ch.proficiency[skill_id],
	}]
	_talent(char_id, "trained", events)
	_pass_days(1, events)
	return _emit(events)


func rest(days: int) -> Array[Dictionary]:
	if days <= 0 or day + days > days_total:
		return _refuse("no_days")
	var events: Array[Dictionary] = []
	_pass_days(days, events)
	return _emit(events)


func _pass_days(days: int, events: Array[Dictionary]) -> void:
	var relief := float(Pricing.rules()["rest"]["fear_relief_per_day"])
	for i in days:
		day += 1
		for ch: RefCounted in game.characters.values():
			if ch.alive:
				ch.fear = maxf(0.0, ch.fear - relief)
		events.append({"type": "day_passed", "day": day, "days_left": days_left()})


## 天赋触发：觉醒的事件追加进 events，同时记进主神议程。
func _talent(char_id: String, trigger_id: String, events: Array[Dictionary]) -> void:
	for t in Talents.trigger(_char(char_id), trigger_id, events):
		Talents.record(game.agenda, char_id, t, _film())


## 这次休整接在哪部片后面（议程记录用）。
func _film() -> String:
	return String(game.films_record.back()) if not game.films_record.is_empty() else ""


func to_dict() -> Dictionary:
	return {"days_total": days_total, "day": day, "gifts": gifts.duplicate()}


func load_dict(d: Dictionary, game_state: RefCounted) -> void:
	game = game_state
	days_total = int(d["days_total"])
	day = int(d["day"])
	gifts = (d["gifts"] as Dictionary).duplicate()
```

- [ ] **Step 13：改写 `game/core/expedition/expedition.gd`**

```gdscript
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
## 天赋觉醒（talents.gd）在这里判：剧情旗标、同伴死在面前、只剩一半人、战后濒死。觉醒事件追加在同一批事件后面。

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
const Talents = preload("res://core/model/talents.gd")

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
	var loc := String(st.pending_battle["location"])
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
	var near := float(Talents.data()["near_death_ratio"])
	for u: RefCounted in b.field.units:
		if u.side == "ally" and st.is_alive(u.character_id):
			var ch: RefCounted = st.characters[u.character_id]
			if ch.hp <= ch.hp_max() * near:
				_trigger(ch.id, "near_death", events)
	for d: Dictionary in summary["deaths"]:
		if st.characters.has(String(d["id"])):
			_on_death(loc, events)
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
	_talent_hooks(events)
	history.append_array(events)
	return events


## 天赋觉醒的触发：剧情旗标被设上、同伴死了或被抹杀（同地点的人看在眼里）、活着的只剩一半。
## 只看这批原有的事件；追加进来的觉醒事件不再触发别的。战斗里的死亡在 report_battle 里单独处理。
func _talent_hooks(events: Array[Dictionary]) -> void:
	if st == null:
		return
	var n := events.size()
	for i in n:
		var ev: Dictionary = events[i]
		match String(ev.get("type", "")):
			"flag_set":
				for c in st.all_living():
					_trigger(c, "flag:" + String(ev["flag"]), events)
			"char_died", "erased":
				_on_death(st.location_of(String(ev["char"])), events)


## 有人死在 where：同地点活着的人触发 ally_died；活着的轮回者只剩一半或更少时，所有人触发 team_peril。
func _on_death(where: String, events: Array[Dictionary]) -> void:
	for c in st.members_at(where):
		_trigger(c, "ally_died", events)
	var living: Array[String] = st.all_living()
	if living.size() * 2 <= st.roster.size():
		for c in living:
			_trigger(c, "team_peril", events)


## 让 char_id 身上的天赋按 trigger_id 判一次觉醒；觉醒了记进主神议程，带 team_fear_relief 的安抚同地点的其他人。
func _trigger(char_id: String, trigger_id: String, events: Array[Dictionary]) -> void:
	for t in Talents.trigger(st.characters[char_id], trigger_id, events):
		Talents.record(game.agenda, char_id, t, st.scenario.id)
		var relief := float((Talents.def(t).get("effect", {}) as Dictionary).get("team_fear_relief", 0.0))
		if relief <= 0.0:
			continue
		for m in st.members_at(st.location_of(char_id)):
			if m == char_id:
				continue
			var d := Watch.add_fear(st.characters[m], -relief)
			if d != 0.0:
				events.append({"type": "fear_changed", "char": m, "amount": d, "fear": st.characters[m].fear, "reason": "talent"})


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
```

- [ ] **Step 14：运行，确认通过**

Run: `bash game/tools/run_tests.sh > _work/p14_task2.txt 2>&1; echo "exit=$?"; tail -1 _work/p14_task2.txt; echo "SCRIPT ERROR: $(grep -c 'SCRIPT ERROR' _work/p14_task2.txt)"`

预期：`共 414 个测试，失败 0 个`、`SCRIPT ERROR: 0`。

- [ ] **Step 15：提交**

```bash
git add game/core/director/agenda.gd game/data/director/director_rules.json game/core/model/game_state.gd game/core/campaign/campaign.gd game/data/scenarios/biohazard1/chapter.json game/core/session/session.gd game/core/hub/hub.gd game/core/expedition/expedition.gd game/tests/unit/core/test_talents.gd game/tests/unit/director/test_agenda.gd game/tests/unit/campaign/test_m1_content.gd game/tests/unit/session/test_session.gd
git commit -m "feat(agenda): 主神议程进存档，片后调评价，造萝丽复制进恶魔小队；天赋按条件觉醒" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

## Task 3：界面呈现与验收

**Files:**
- Modify: `game/ui/hub/hub_view.gd`、`game/ui/hub/hub_screen.gd`、`game/ui/event_text.gd`、`game/ui/main.gd`

- [ ] **Step 1：改写 `game/ui/hub/hub_view.gd`**

```gdscript
extends RefCounted
## 主神空间界面的取数层：兑换、属性、修复、造人、训练、休息。
## 规则在 core/hub；这里只把状态整理成界面能画的东西，并把点击交回去。

const Exchange = preload("res://core/hub/exchange.gd")
const Catalog = preload("res://core/hub/catalog.gd")
const BattleData = preload("res://core/battle/battle_data.gd")
const Talents = preload("res://core/model/talents.gd")

## 造人预设：萝丽（郑吒的青梅竹马），素质在常人的上限附近。
const LORI_ATTRS := {"intelligence": 110, "spirit": 120, "cell_vitality": 120, "nerve_reaction": 120, "muscle": 100, "immunity": 110}

var session: RefCounted
var hub: RefCounted
var game: RefCounted


func _init(s: RefCounted) -> void:
	session = s
	hub = s.hub
	game = s.game
	if hub != null:
		session.day = hub.day


func day_text() -> String:
	if hub == null:
		return ""
	return "回归当晚" if hub.day == 0 else "第 %d 天 / %d 天" % [hub.day, hub.days_total]


func days_left() -> int:
	return hub.days_left() if hub != null else 0


func can_depart() -> bool:
	return session.can_depart()


func characters() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in game.characters:
		var ch: RefCounted = game.characters[id]
		out.append({
			"id": id, "name": ch.display_name, "points": ch.points,
			"hp": ch.hp, "hp_max": ch.hp_max(), "fear": ch.fear,
			"tickets": ch.tickets.counts.duplicate(), "alive": ch.alive,
			"talents": Talents.awake_names(ch),
		})
	return out


## 兑换目录；category 为空时给全部。ok 表示现在能买，reasons 是买不了的原因。
func entries(char_id: String, category: String = "") -> Array[Dictionary]:
	var ch: RefCounted = game.characters[char_id]
	var out: Array[Dictionary] = []
	for id: String in Catalog.entries():
		var e: Dictionary = Catalog.entry(id)
		if category != "" and String(e["category"]) != category:
			continue
		var check: Dictionary = Exchange.check(ch, id)
		var reasons: Array[String] = []
		for r: String in check["reasons"]:
			reasons.append(reason_text(r))
		out.append({
			"id": id, "name": String(e["name"]), "category": String(e["category"]),
			"series": String(e["series"]), "points": int(e["price"]["points"]),
			"tier": String(e["price"].get("tier", "")), "owned": ch.owned.has(id),
			"ok": bool(check["ok"]), "reasons": reasons,
			"warnings": (check["warnings"] as Array).duplicate(),
		})
	return out


func buy(char_id: String, entry_id: String, accept_risk: bool = false) -> Array[Dictionary]:
	return hub.exchange(char_id, entry_id, {"accept_risk": accept_risk})


func buy_attribute(char_id: String, attr: String, amount: int) -> Array[Dictionary]:
	return hub.buy_attribute(char_id, attr, amount)


func split_ticket(char_id: String, grade: String) -> Array[Dictionary]:
	return hub.split_ticket(char_id, grade)


func repairs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in game.characters:
		var ch: RefCounted = game.characters[id]
		if not ch.alive or ch.hp >= ch.hp_max():
			continue
		out.append({"id": id, "name": ch.display_name, "hp": ch.hp, "hp_max": ch.hp_max(), "cost": hub.repair_cost(id)})
	return out


func repair(char_id: String) -> Array[Dictionary]:
	return hub.repair(char_id)


func companions() -> Array:
	return game.companions.duplicate(true)


## 造人：M1 固定郑吒造萝丽，素质取预设（不超过常人两倍）。
func create_human(creator_id: String, name: String) -> Array[Dictionary]:
	return hub.create_human(creator_id, name, LORI_ATTRS)


## 还有熟练度可练的技能/能力（低于 1.0 的）。
func trainable(char_id: String) -> Array[Dictionary]:
	var ch: RefCounted = game.characters[char_id]
	var out: Array[Dictionary] = []
	for s: String in ch.skills:
		if float(ch.proficiency.get(s, 1.0)) < 1.0:
			var info: Dictionary = BattleData.skills().get(s, {})
			out.append({"id": s, "name": String(info.get("name", s)), "proficiency": float(ch.proficiency.get(s, 0.0))})
	for a: String in ch.abilities:
		if float(ch.proficiency.get(a, 1.0)) < 1.0:
			out.append({"id": a, "name": a, "proficiency": float(ch.proficiency.get(a, 0.0))})
	return out


## 对练能用的招式：只列战斗技能（被动能力不上场）。
func sparrable(char_id: String) -> Array[Dictionary]:
	var ch: RefCounted = game.characters[char_id]
	var out: Array[Dictionary] = []
	for s: String in ch.skills:
		var info: Dictionary = BattleData.skills().get(s, {})
		out.append({"id": s, "name": String(info.get("name", s)), "proficiency": float(ch.proficiency.get(s, 1.0))})
	return out


func spar(char_id: String, skill_id: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = hub.spar(char_id, skill_id)
	session.day = hub.day
	return events


func train(char_id: String, skill_id: String, days: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = hub.train(char_id, skill_id, days)
	session.day = hub.day
	return events


func rest(days: int = 1) -> Array[Dictionary]:
	var events: Array[Dictionary] = hub.rest(days)
	session.day = hub.day
	return events


## 提示文字：把 core 的原因码翻成中文。
static func reason_text(code: String) -> String:
	if code.begins_with("missing_prerequisite:"):
		return "缺前置：" + code.get_slice(":", 1)
	if code.begins_with("gate:"):
		return "属性不够：" + code.get_slice(":", 1)
	if code.begins_with("needs_energy:"):
		return "需要能量：" + code.get_slice(":", 1)
	var table := {
		"not_enough_points": "点数不够", "missing_ticket": "支线不够",
		"already_owned": "已经拥有", "gift_used": "这次休整已经代兑过",
		"unknown_entry": "目录里没有这一项", "return_night": "回归当晚不兑换",
		"not_injured": "没有受伤", "cannot_split": "拆不了", "cannot_merge": "合不了",
		"no_days": "天数不够", "unknown_skill": "没有这个技能",
	}
	return String(table.get(code, code))
```

- [ ] **Step 2：改写 `game/ui/hub/hub_screen.gd`**

```gdscript
extends Control
## 主神空间（M1 休整）：兑换、属性、修复、造人、训练、休息与出发。
## 只调用 HubView；规则在 core/hub。

signal departed
## 想向主神提问。
signal zhushen_requested

const HubView = preload("res://ui/hub/hub_view.gd")
const UiTheme = preload("res://ui/ui_theme.gd")
const Sfx = preload("res://core/audio/sfx.gd")

const ATTRS := {
	"intelligence": "智力", "spirit": "精神力", "cell_vitality": "细胞活力",
	"nerve_reaction": "神经反应", "muscle": "肌肉强度", "immunity": "免疫力",
}

var view: RefCounted
var selected: String = "zheng_zha"
var tab: String = "exchange"
var category: String = ""
var confirm_entry: String = ""
var status_label: Label
var day_label: Label
var char_box: VBoxContainer
var tab_box: HBoxContainer
var content_box: VBoxContainer
var rest_button: Button
var depart_button: Button
var name_edit: LineEdit


func setup(session: RefCounted) -> void:
	view = HubView.new(session)
	_build()
	refresh()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiTheme.paint_bg(self)
	day_label = UiTheme.label("", 30, UiTheme.ACCENT2)
	day_label.position = Vector2(30, 20)
	day_label.size = Vector2(380, 40)
	add_child(day_label)
	var sub := UiTheme.label("兑换、修复、造人不耗天；训练和休息耗天。第 9 天黄昏走光柱。", 16, UiTheme.MUTED)
	sub.position = Vector2(30, 62)
	sub.size = Vector2(380, 44)
	add_child(sub)

	char_box = VBoxContainer.new()
	char_box.position = Vector2(30, 120)
	char_box.size = Vector2(380, 560)
	char_box.add_theme_constant_override("separation", 6)
	add_child(char_box)

	rest_button = UiTheme.button("休息一天", 20)
	rest_button.position = Vector2(30, 720)
	rest_button.size = Vector2(180, 52)
	rest_button.pressed.connect(press_rest)
	add_child(rest_button)
	depart_button = UiTheme.button("走光柱", 20)
	depart_button.position = Vector2(230, 720)
	depart_button.size = Vector2(180, 52)
	depart_button.pressed.connect(press_depart)
	add_child(depart_button)

	var ask := UiTheme.button("问主神", 20)
	ask.position = Vector2(30, 792)
	ask.size = Vector2(380, 52)
	ask.pressed.connect(press_ask_zhushen)
	add_child(ask)

	tab_box = HBoxContainer.new()
	tab_box.position = Vector2(450, 24)
	tab_box.size = Vector2(1420, 52)
	tab_box.add_theme_constant_override("separation", 10)
	add_child(tab_box)
	for t in [["兑换", "exchange"], ["属性", "attr"], ["修复", "repair"], ["造人", "human"], ["训练", "train"], ["对练", "spar"]]:
		var b := UiTheme.button(String(t[0]), 20)
		b.pressed.connect(open_tab.bind(String(t[1])))
		tab_box.add_child(b)

	var panel := PanelContainer.new()
	panel.position = Vector2(450, 90)
	panel.size = Vector2(1420, 760)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	content_box = VBoxContainer.new()
	content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_box.add_theme_constant_override("separation", 8)
	scroll.add_child(content_box)

	status_label = UiTheme.label("", 19, UiTheme.ACCENT2)
	status_label.position = Vector2(450, 866)
	status_label.size = Vector2(1420, 60)
	add_child(status_label)


func refresh() -> void:
	day_label.text = "主神空间 · " + view.day_text()
	rest_button.text = "休息一天（剩 %d 天）" % view.days_left()
	rest_button.disabled = view.can_depart()
	depart_button.visible = view.can_depart()

	for c in char_box.get_children():
		char_box.remove_child(c)
		c.queue_free()
	for ch: Dictionary in view.characters():
		var t := "%s\n%d 点 · 生命 %d/%d · 恐惧 %d" % [String(ch["name"]), int(ch["points"]), int(ch["hp"]), int(ch["hp_max"]), int(ch["fear"])]
		var tickets := ""
		for g: String in ["D", "C", "B", "A", "S"]:
			if int((ch["tickets"] as Dictionary).get(g, 0)) > 0:
				tickets += "%s×%d " % [g, int(ch["tickets"][g])]
		if tickets != "":
			t += "\n" + tickets
		var woke: Array = ch["talents"]
		t += "\n天赋：" + ("、".join(woke) if not woke.is_empty() else "未显露")
		var b := UiTheme.button(t, 17)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(select_char.bind(String(ch["id"])))
		if not bool(ch["alive"]):
			t += "\n（死亡）"
			b.text = t
			b.modulate = Color(0.6, 0.62, 0.68, 1.0)
		elif String(ch["id"]) == selected:
			b.modulate = Color(1.0, 0.82, 0.55, 1.0)
		char_box.add_child(b)

	for c in tab_box.get_children():
		var b := c as Button
		b.modulate = Color(1.0, 0.82, 0.55, 1.0) if _tab_of(b.text) == tab else Color.WHITE

	for c in content_box.get_children():
		content_box.remove_child(c)
		c.queue_free()
	match tab:
		"exchange": _build_exchange()
		"attr": _build_attr()
		"repair": _build_repair()
		"human": _build_human()
		"train": _build_train()
		"spar": _build_spar()


func _tab_of(text: String) -> String:
	var table := {"兑换": "exchange", "属性": "attr", "修复": "repair", "造人": "human", "训练": "train", "对练": "spar"}
	return String(table.get(text, ""))


func _char() -> RefCounted:
	return view.game.characters[selected]


func _build_exchange() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for c in [["全部", ""], ["强化", "enhance"], ["科技", "tech"], ["魔法", "magic"], ["道具", "item"]]:
		var b := UiTheme.button(String(c[0]), 18)
		b.pressed.connect(_set_category.bind(String(c[1])))
		if category == String(c[1]):
			b.modulate = Color(1.0, 0.82, 0.55, 1.0)
		row.add_child(b)
	content_box.add_child(row)
	if view.hub.day == 0:
		content_box.add_child(UiTheme.label("回归当晚不兑换。先造人，或者直接休息到第 2 天。", 20, UiTheme.MUTED))

	if confirm_entry != "":
		var warn := HBoxContainer.new()
		warn.add_theme_constant_override("separation", 10)
		warn.add_child(UiTheme.label("双血统冲突：坚持兑换有 70% 几率变成非人。", 20, UiTheme.ACCENT))
		var yes := UiTheme.button("仍然兑换", 18)
		yes.pressed.connect(_do_buy.bind(confirm_entry, true))
		warn.add_child(yes)
		var no := UiTheme.button("取消", 18)
		no.pressed.connect(func() -> void:
			confirm_entry = ""
			refresh())
		warn.add_child(no)
		content_box.add_child(warn)

	for e: Dictionary in view.entries(selected, category):
		var label := "%s   %d 点" % [String(e["name"]), int(e["points"])]
		if String(e["tier"]) != "":
			label += " · " + String(e["tier"]) + " 级"
		if bool(e["owned"]):
			label += "  [已拥有]"
		elif not bool(e["ok"]):
			label += "  (" + "、".join(e["reasons"]) + ")"
		var b := UiTheme.button(label, 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not bool(e["ok"])
		b.pressed.connect(press_entry.bind(String(e["id"])))
		content_box.add_child(b)


func _build_attr() -> void:
	var ch := _char()
	for k: String in ATTRS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var v := UiTheme.label("%s：%d" % [String(ATTRS[k]), int(ch.attributes.total(k))], 20)
		v.custom_minimum_size = Vector2(320, 40)
		row.add_child(v)
		var b := UiTheme.button("+10（100 点）", 18)
		b.custom_minimum_size = Vector2(200, 40)
		b.disabled = view.hub.day == 0 or ch.points < 100
		b.pressed.connect(press_attr.bind(k))
		row.add_child(b)
		content_box.add_child(row)
	content_box.add_child(UiTheme.label("10 点奖励点数 = 1 点属性（原著）。", 18, UiTheme.MUTED))


func _build_repair() -> void:
	var list: Array[Dictionary] = view.repairs()
	if list.is_empty():
		content_box.add_child(UiTheme.label("没有人受伤。", 20, UiTheme.MUTED))
		return
	for r: Dictionary in list:
		var b := UiTheme.button("%s  生命 %d/%d   修复 %d 点" % [String(r["name"]), int(r["hp"]), int(r["hp_max"]), int(r["cost"])], 18)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = _char().points < int(r["cost"])
		b.pressed.connect(press_repair.bind(String(r["id"])))
		content_box.add_child(b)


func _build_human() -> void:
	var made: Array = view.companions()
	content_box.add_child(UiTheme.label("造人：第一个免费，之后 500 点；素质最多约常人两倍，回归当晚就能造。", 19, UiTheme.MUTED))
	for c: Dictionary in made:
		content_box.add_child(UiTheme.label("已有造物：%s（制造者 %s）" % [String(c["name"]), String(c["creator"])], 20))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	name_edit = LineEdit.new()
	name_edit.text = "萝丽"
	name_edit.custom_minimum_size = Vector2(260, 48)
	name_edit.add_theme_font_size_override("font_size", 20)
	row.add_child(name_edit)
	var b := UiTheme.button("造人", 20)
	b.custom_minimum_size = Vector2(160, 48)
	b.disabled = made.size() > 0 and _char().points < 500
	b.pressed.connect(func() -> void:
		press_create(name_edit.text))
	row.add_child(b)
	content_box.add_child(row)


func _build_train() -> void:
	var list: Array[Dictionary] = view.trainable(selected)
	if list.is_empty():
		content_box.add_child(UiTheme.label("没有需要练的技能：低级别的兑换一上手就是熟练的，A 级以上才要练。", 19, UiTheme.MUTED))
		return
	for t: Dictionary in list:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var l := UiTheme.label("%s  熟练度 %.0f%%" % [String(t["name"]), float(t["proficiency"]) * 100.0], 20)
		l.custom_minimum_size = Vector2(420, 44)
		row.add_child(l)
		for days in [1, 2, 3]:
			var b := UiTheme.button("练 %d 天" % days, 18)
			b.custom_minimum_size = Vector2(120, 44)
			b.disabled = view.hub.day + days > view.hub.days_total - 1
			b.pressed.connect(press_train.bind(String(t["id"]), days))
			row.add_child(b)
		content_box.add_child(row)


## 对练：拿招式跟训练傀儡打一场，看伤害数字。耗 1 天，不伤人不耗道具。
func _build_spar() -> void:
	content_box.add_child(UiTheme.label("跟训练傀儡打一场（耗 1 天，不掉血、不耗弹药），用来看兑换前后的差别。", 18, UiTheme.MUTED))
	var list: Array[Dictionary] = view.sparrable(selected)
	if list.is_empty():
		content_box.add_child(UiTheme.label("这个人还没有能上场的招式。", 19, UiTheme.MUTED))
		return
	for t: Dictionary in list:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var l := UiTheme.label(String(t["name"]), 20)
		l.custom_minimum_size = Vector2(420, 44)
		row.add_child(l)
		var b := UiTheme.button("打一场（1 天）", 18)
		b.custom_minimum_size = Vector2(160, 44)
		b.disabled = view.hub.day + 1 > view.hub.days_total - 1
		b.pressed.connect(press_spar.bind(String(t["id"])))
		row.add_child(b)
		content_box.add_child(row)


func press_spar(skill_id: String) -> void:
	var events: Array[Dictionary] = view.spar(selected, skill_id)
	Sfx.play_for_events(events)
	status_label.text = _describe(events)
	refresh()


func _set_category(c: String) -> void:
	category = c
	refresh()


func select_char(id: String) -> void:
	selected = id
	refresh()


func open_tab(t: String) -> void:
	tab = t
	confirm_entry = ""
	refresh()


func press_entry(entry_id: String) -> void:
	var e: Dictionary = {}
	for item: Dictionary in view.entries(selected):
		if String(item["id"]) == entry_id:
			e = item
	if e.is_empty():
		return
	if (e["warnings"] as Array).has("bloodline_risk"):
		confirm_entry = entry_id
		refresh()
		return
	_do_buy(entry_id, false)


func _do_buy(entry_id: String, accept_risk: bool) -> void:
	confirm_entry = ""
	var events: Array[Dictionary] = view.buy(selected, entry_id, accept_risk)
	Sfx.play_for_events(events)
	status_label.text = _describe(events)
	refresh()


func press_attr(attr: String) -> void:
	var events: Array[Dictionary] = view.buy_attribute(selected, attr, 10)
	Sfx.play_for_events(events)
	status_label.text = _describe(events)
	refresh()


func press_repair(char_id: String) -> void:
	var events: Array[Dictionary] = view.repair(char_id)
	Sfx.play_for_events(events)
	status_label.text = _describe(events)
	refresh()


func press_create(name: String) -> void:
	var events: Array[Dictionary] = view.create_human(selected, name)
	Sfx.play_for_events(events)
	status_label.text = _describe(events)
	refresh()


func press_train(skill_id: String, days: int) -> void:
	var events: Array[Dictionary] = view.train(selected, skill_id, days)
	Sfx.play_for_events(events)
	status_label.text = _describe(events)
	refresh()


func press_rest() -> void:
	status_label.text = _describe(view.rest(1))
	refresh()


func press_ask_zhushen() -> void:
	zhushen_requested.emit()


func press_depart() -> bool:
	if not view.can_depart():
		return false
	session_depart()
	return true


func session_depart() -> void:
	if view.session.depart():
		departed.emit()


func _describe(events: Array[Dictionary]) -> String:
	if events.is_empty():
		return ""
	var text := _describe_first(events[0])
	for ev: Dictionary in events:
		if String(ev["type"]) == "talent_awakened":
			text += "；%s 的天赋觉醒：%s" % [view.game.characters[String(ev["char"])].display_name, String(ev["name"])]
	return text


func _describe_first(e: Dictionary) -> String:
	match String(e["type"]):
		"exchange_done":
			return "兑换完成：" + String(e["entry"])
		"exchange_refused":
			return "主神拒绝了：" + "、".join(e["reasons"])
		"exchange_warning":
			return "需要确认血统风险"
		"attribute_bought":
			return "属性 +%d，花掉 %d 点" % [int(e["amount"]), int(e["cost"])]
		"repaired":
			return "修复完成，花掉 %d 点" % int(e["cost"])
		"human_created":
			return "造人完成：%s" % String((e["companion"] as Dictionary)["name"])
		"trained":
			return "训练完成：%s 熟练度 %.0f%%" % [String(e["skill"]), float(e["proficiency"]) * 100.0]
		"spar_done":
			return "对练：%s 打出 %d 伤害（%d 回合，%s），熟练度 %.0f%%" % [
				String(e["skill"]), int(float(e["damage"])), int(e["rounds"]),
				"打赢" if String(e["outcome"]) == "victory" else "没打完",
				float(e["proficiency"]) * 100.0]
		"day_passed":
			return "第 %d 天" % int(e["day"])
		"hub_refused":
			return HubView.reason_text(String(e["reason"]))
		"bloodline_mutation":
			return "血统冲突爆发：变成了非人"
		"bloodline_safe":
			return "运气不错，血统没有冲突"
	return String(e["type"])
```

- [ ] **Step 3：改写 `game/ui/event_text.gd`**

```gdscript
extends RefCounted
## 把 core 发出的事件翻译成一行中文，给界面的事件流和战斗日志用。
## 只负责"能看懂"，不做规则判断；认不出的事件返回空字符串（界面跳过）。

const BattleData = preload("res://core/battle/battle_data.gd")


static func describe(e: Dictionary, names: Dictionary = {}) -> String:
	var t := String(e.get("type", ""))
	match t:
		"expedition_start":
			return "进入恐怖片。"
		"move_start":
			return "出发，前往 %s（%d 分钟）。" % [_name(e.get("to", ""), names), int(e.get("minutes", 0))]
		"arrived":
			return "到达 %s。" % _name(e.get("location", ""), names)
		"move_interrupted":
			return "半路被打断。"
		"plot_event":
			return "剧情发生：%s。" % _name(e.get("event", ""), names)
		"plot_altered":
			return "剧情被改写：%s。" % String(e.get("label", ""))
		"dialogue":
			return "%s：%s" % [_name(e.get("speaker", ""), names), String(e.get("text", ""))]
		"tether_set":
			return "手表绑定：不得离开 %s 100 米。" % _name(e.get("npc", ""), names)
		"tether_warning":
			return "%s 超出绑定范围，%d 分钟内不回来会被抹杀。" % [_name(e.get("char", ""), names), int(e.get("grace_minutes", 0))]
		"tether_released":
			return "绑定解除。"
		"tether_transferred":
			return "绑定转移到 %s。" % _name(e.get("npc", ""), names)
		"erased":
			return "%s 被主神抹杀（%s）。" % [_name(e.get("char", ""), names), String(e.get("reason", ""))]
		"char_died":
			return "%s 死了（%s）。" % [_name(e.get("char", ""), names), String(e.get("reason", ""))]
		"infection_turned":
			return "%s 变成了丧尸。" % _name(e.get("char", ""), names)
		"battle_request":
			return "战斗！%s 出现了敌人。" % _name(e.get("location", ""), names)
		"battle_resolved":
			return "战斗结束：%s。" % String(e.get("outcome", ""))
		"kill_recorded":
			return "%s 击杀 %s（+%.1f 点）。" % [_name(e.get("char", ""), names), _enemy(e.get("enemy", "")), float(e.get("points", 0.0))]
		"side_plot_done":
			return "支线完成：%s（%s 级，+%d 点）。" % [String(e.get("label", "")), String(e.get("grade", "")), int(e.get("points", 0))]
		"bonus":
			return "%s：+%d 点。" % [String(e.get("label", "")), int(e.get("points", 0))]
		"penalty":
			return "%s：%d 点。" % [String(e.get("label", "")), int(e.get("points", 0))]
		"fear_changed":
			return "%s 恐惧 %+.1f（%s）。" % [_name(e.get("char", ""), names), float(e.get("amount", 0.0)), _reason(String(e.get("reason", "")))]
		"clue_found":
			return "发现线索：%s。" % _name(e.get("clue", ""), names)
		"inference":
			return "推论：%s（可信度 %.0f%%）。" % [_name(e.get("fact", ""), names), float(e.get("confidence", 0.0)) * 100.0]
		"returned":
			return "倒计时结束，回归主神空间。"
		"wiped":
			return "全员死亡，任务失败。"
		"choice_request":
			return "需要做出选择。"
		"choice_made":
			return "已选择。"
		"persuade_request":
			return "需要说服 %s。" % _name(e.get("npc", ""), names)
		"persuade_result":
			return "说服%s。" % ("成功" if bool(e.get("success", false)) else "失败")
		"item_used":
			return "%s 使用了道具。" % _name(e.get("char", ""), names)
		"talent_awakened":
			return "%s 的天赋觉醒了：%s。%s" % [_name(e.get("char", ""), names), String(e.get("name", "")), String(e.get("text", ""))]
		"searched":
			return "搜索完毕。"
		"search_encounter":
			return String(e.get("text", "搜索的声音引来了敌人。"))
		"persuade_blocked":
			return "你还没有把握开口——先想清楚%s。" % _name(e.get("fact", ""), names)
		"already_searched":
			return "这里已经搜过了。"
		# ---- 战斗 ----
		"battle_start":
			return "战斗开始。"
		"turn_start":
			return "轮到 %s。" % _name(e.get("unit", ""), names)
		"action":
			return "%s 行动。" % _name(e.get("unit", ""), names)
		"damage":
			return "%s 受到 %.0f 伤害（剩 %.0f）。" % [_name(e.get("target", ""), names), float(e.get("amount", 0.0)), float(e.get("hp", 0.0))]
		"heal":
			return "%s 回复 %.0f 生命。" % [_name(e.get("target", ""), names), float(e.get("amount", 0.0))]
		"miss":
			return "%s 躲开了 %s 的攻击。" % [_name(e.get("target", ""), names), _name(e.get("source", ""), names)]
		"death":
			return "%s 倒下了。" % _name(e.get("target", ""), names)
		"fled":
			return "%s 逃离了战场。" % _name(e.get("unit", ""), names)
		"status_applied":
			return "%s 陷入 %s。" % [_name(e.get("target", ""), names), _status(e.get("status", ""))]
		"status_expired":
			return "%s 的 %s 结束了。" % [_name(e.get("target", ""), names), _status(e.get("status", ""))]
		"status_damage":
			return "%s 因 %s 受到 %.0f 伤害。" % [_name(e.get("target", ""), names), _status(e.get("status", "")), float(e.get("amount", 0.0))]
		"moved":
			return "%s 换到第 %d 排。" % [_name(e.get("unit", ""), names), int(e.get("row", 0)) + 1]
		"battle_end":
			return "战斗结束。"
		"gene_lock_awaken":
			return "%s 解开了基因锁第 %d 阶！" % [_name(e.get("target", ""), names), int(e.get("stage", 0))]
		"awaken_failed":
			return "%s 在濒死边缘没能突破。" % _name(e.get("target", ""), names)
		"fear_collapse":
			return "%s 恐惧崩溃了。" % _name(e.get("target", ""), names)
		"fear_endured":
			return "%s 硬撑住了恐惧。" % _name(e.get("target", ""), names)
		"infection_turned":
			return "%s 在战斗中变成了丧尸。" % _name(e.get("target", ""), names)
		"gag_penalty":
			return "说漏了嘴——%s 就在旁边，扣 %.0f 点。" % [_name(e.get("witness", ""), names), float(e.get("points", 0.0))]
		"leak_unwitnessed":
			return "差点说漏嘴。旁边没有剧情人物，没人听见。"
		"invalid_action":
			return ""
	return ""


static func _name(id: Variant, names: Dictionary) -> String:
	var key := String(id)
	return String(names.get(key, key))


static func _reason(r: String) -> String:
	var table := {
		"enemy_appear": "敌人登场", "darkness": "黑暗", "plot": "剧情", "rest": "休息",
		"tether": "绑定", "turned": "感染", "fight": "战斗", "low_hp": "濒死", "aura": "敌人威压",
	}
	return String(table.get(r, r))


static func _status(id: Variant) -> String:
	var s := String(id)
	var all := BattleData.statuses()
	return String((all[s] as Dictionary).get("name", s)) if all.has(s) else s


static func _enemy(id: Variant) -> String:
	var d := String(id)
	var all := BattleData.enemies()
	return String((all[d] as Dictionary).get("name", d)) if all.has(d) else d
```

- [ ] **Step 4：改写 `game/ui/main.gd`**

```gdscript
extends Control
## 游戏入口：标题画面 → 新游戏/读档 → 远征 → 战斗 → 结算 → 主神空间休整。
## 只做流程和换屏；远征与战斗的状态都在 Session / Expedition / Battle 里。
## 对话也在这里接线：AiService → Dialogue → 对话框，没配密钥就自动走离线兜底。
## PC 版外壳：标题画面、三个存档槽、设置、Esc 暂停菜单都在这里挂。

const Session = preload("res://core/session/session.gd")
const ExpeditionScreen = preload("res://ui/expedition/expedition_screen.gd")
const BattleScreen = preload("res://ui/battle/battle_screen.gd")
const HubScreen = preload("res://ui/hub/hub_screen.gd")
const UiTheme = preload("res://ui/ui_theme.gd")
const Battle = preload("res://core/battle/battle.gd")
const AiService = preload("res://ai/ai_service.gd")
const AiSettings = preload("res://ai/ai_settings.gd")
const HttpTransport = preload("res://ai/http_transport.gd")
const Persona = preload("res://ai/persona.gd")
const Dialogue = preload("res://core/dialogue/dialogue.gd")
const Gag = preload("res://core/dialogue/gag.gd")
const DialoguePanel = preload("res://ui/dialogue/dialogue_panel.gd")
const EventText = preload("res://ui/event_text.gd")
const DataLoader = preload("res://core/util/data_loader.gd")
const Slots = preload("res://core/save/slots.gd")
const Settings = preload("res://core/settings/settings.gd")
const TitleScreen = preload("res://ui/title_screen.gd")
const PauseMenu = preload("res://ui/pause_menu.gd")
const Sfx = preload("res://core/audio/sfx.gd")
const Cutscene = preload("res://ui/cutscene.gd")
const PortraitSource = preload("res://core/art/portrait_source.gd")

const ZHSHEN_FAQ := "res://data/ai/zhushen_faq.json"
## 主神不许说出口的词（校验层会拦，泄露就换离线回答）。
const ZHSHEN_FORBIDDEN: Array[String] = ["下一部", "剧情", "原著", "郑吒会"]

var session: RefCounted
var content: Control
var bar: ColorRect
var header: Label
var menu_button: Button
var battle_screen: Control = null
var title_screen: Control = null
var pause: Control = null
## 窗口模式与主音量，存 user://settings.json。
var settings: Dictionary = Settings.defaults()
## 自动存档：阶段/地点/天数一变就落盘，退出后"继续游戏"能接着玩。
var _auto_key := ""
## AI 接入层与对话层；离线时 ai.online() 为 false，全部走脚本兜底。
var ai: RefCounted
var dialogue: RefCounted
var panel: Control = null


func _ready() -> void:
	theme = UiTheme.build()
	_build_frame()
	add_child(Sfx.new())
	settings = Settings.load_settings()
	Settings.apply(settings)
	_show_title()


func _build_frame() -> void:
	UiTheme.paint_bg(self)
	bar = ColorRect.new()
	bar.color = UiTheme.PANEL
	bar.position = Vector2(0, 0)
	bar.size = Vector2(1920, 56)
	add_child(bar)
	header = UiTheme.label("无限恐怖", 24, UiTheme.ACCENT2)
	header.position = Vector2(30, 12)
	header.size = Vector2(1200, 34)
	add_child(header)

	menu_button = UiTheme.button("菜单（Esc）", 18)
	menu_button.position = Vector2(1700, 6)
	menu_button.size = Vector2(190, 44)
	menu_button.pressed.connect(_open_pause)
	add_child(menu_button)

	content = Control.new()
	content.position = Vector2(0, 56)
	content.size = Vector2(1920, 1024)
	add_child(content)

	_show_frame(false)


## 标题画面要整屏，游戏里让出顶部 56px 的状态栏。
func _show_frame(playing: bool) -> void:
	bar.visible = playing
	header.visible = playing
	menu_button.visible = playing
	content.position = Vector2(0, 56) if playing else Vector2(0, 0)
	content.size = Vector2(1920, 1024) if playing else Vector2(1920, 1080)


func _clear() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	battle_screen = null
	if panel != null:
		panel.queue_free()
		panel = null


func _names() -> Dictionary:
	var out := {}
	for id: String in session.game.characters:
		out[id] = session.game.characters[id].display_name
	return out


func _set_status(text: String) -> void:
	header.text = "无限恐怖 · M1 · " + text


func _show_expedition() -> void:
	_clear()
	var screen := ExpeditionScreen.new()
	screen.setup(session.expedition, _names())
	screen.battle_needed.connect(_on_battle_needed)
	screen.ended.connect(_on_expedition_ended)
	screen.talk_requested.connect(_on_talk)
	screen.persuade_requested.connect(_on_persuade_free)
	screen.cutscene_requested.connect(_on_cutscene)
	content.add_child(screen)
	_set_status("生化危机一")


func _on_battle_needed() -> void:
	if battle_screen != null or session.blocked_reason() != "battle":
		return
	var units: Array[RefCounted] = session.expedition.battle_units({})
	if units.is_empty():
		return
	var b := Battle.new()
	b.setup(units, session.expedition.battle_options(), session.game.rng)
	var screen := BattleScreen.new()
	screen.setup(b)
	screen.finished.connect(_on_battle_finished.bind(b))
	_clear()
	content.add_child(screen)
	battle_screen = screen
	var loc := String(session.expedition.st.pending_battle.get("location", ""))
	_set_status("战斗中 · " + String(session.expedition.st.scenario.location(loc).get("name", loc)))


func _on_battle_finished(b: RefCounted) -> void:
	if battle_screen == null:
		return
	session.expedition.report_battle(b)
	battle_screen = null
	if session.phase == "expedition" and session.expedition_over():
		_on_expedition_ended()
	else:
		_show_expedition()


func _on_expedition_ended() -> void:
	if session.phase != "expedition":
		return
	var results: Dictionary = session.settle()
	Sfx.play("coin")
	_show_result(results)


func _show_result(results: Dictionary) -> void:
	_clear()
	var box := VBoxContainer.new()
	box.position = Vector2(300, 90)
	box.size = Vector2(1320, 860)
	box.add_theme_constant_override("separation", 14)
	content.add_child(box)

	var title := UiTheme.label("任务结束：%s" % String(session.expedition.st.outcome), 34, UiTheme.ACCENT2)
	box.add_child(title)
	box.add_child(UiTheme.label("倒计时 %d 分钟 · 存活结算" % int(session.expedition.st.clock), 20, UiTheme.MUTED))
	var fr: Dictionary = session.film_report
	if not fr.is_empty():
		box.add_child(UiTheme.label("幸存 %d/%d · 主神评价 %d → %d" % [int(fr["survivors"]), int(fr["members"]), int(fr["rating_before"]), int(fr["rating_after"])], 20, UiTheme.MUTED))
	for id: String in results:
		var r: Dictionary = results[id]
		var name: String = session.game.characters[id].display_name if session.game.characters.has(id) else id
		if bool(r.get("dead", false)):
			box.add_child(UiTheme.label("%s：死亡（%s）" % [name, String(r.get("reason", ""))], 22, UiTheme.MUTED))
			continue
		var line := "%s：%d 点" % [name, int(r["final_points"])]
		var tickets: Array = r.get("tickets", [])
		if not tickets.is_empty():
			line += " · " + "、".join(tickets) + " 级支线"
		box.add_child(UiTheme.label(line, 24, UiTheme.TEXT))
	var go := UiTheme.button("进入主神空间", 24)
	go.custom_minimum_size = Vector2(320, 60)
	go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	go.pressed.connect(_on_enter_hub)
	box.add_child(go)
	_set_status("结算完成")


func _on_enter_hub() -> void:
	if session.enter_hub():
		_show_hub()


func _show_hub() -> void:
	if session.hub == null:
		return
	_clear()
	var screen := HubScreen.new()
	screen.setup(session)
	screen.departed.connect(_show_done)
	screen.zhushen_requested.connect(_on_ask_zhushen)
	content.add_child(screen)
	_set_status("主神空间")


func _show_done() -> void:
	_clear()
	var box := VBoxContainer.new()
	box.position = Vector2(300, 160)
	box.size = Vector2(1320, 600)
	box.add_theme_constant_override("separation", 16)
	content.add_child(box)
	box.add_child(UiTheme.label("二十道光柱降下。", 36, UiTheme.ACCENT2))
	box.add_child(UiTheme.label("下一部：异形一（内容与界面在后续计划里做）。", 22, UiTheme.TEXT))
	_set_status("M1 结束")


## ---- 标题与存档槽 ----

func _show_title() -> void:
	session = null
	battle_screen = null
	_close_pause()
	_clear()
	_show_frame(false)
	var t := TitleScreen.new()
	t.set_settings(settings)
	t.new_game.connect(_new_game)
	t.load_slot.connect(_load_slot)
	t.quit_game.connect(_quit_game)
	t.settings_changed.connect(_on_settings_changed)
	content.add_child(t)
	title_screen = t


func _new_game() -> void:
	title_screen = null
	session = Session.new()
	session.start_m1(1)
	_setup_ai()
	_show_frame(true)
	_show_expedition()


func _load_slot(slot: int) -> void:
	var s := Slots.read(slot)
	if s == null:
		_set_status("存档位 %d 读不出来" % slot)
		return
	title_screen = null
	session = s
	battle_screen = null
	_setup_ai()
	_show_frame(true)
	if session.phase == "expedition":
		_show_expedition()
	elif session.phase == "done":
		_show_done()
	else:
		_show_hub()


func _on_settings_changed(next: Dictionary) -> void:
	settings = next
	Settings.save_settings(settings)


## ---- 暂停菜单 ----

func _open_pause() -> void:
	if session == null or pause != null:
		return
	pause = PauseMenu.new()
	pause.resume.connect(_close_pause)
	pause.save_slot.connect(_on_save_slot)
	pause.load_slot.connect(_on_load_slot)
	pause.to_title.connect(_show_title)
	pause.quit_game.connect(_quit_game)
	add_child(pause)
	pause.open_for("")


func _close_pause() -> void:
	if pause == null:
		return
	pause.queue_free()
	pause = null


func _on_save_slot(slot: int) -> void:
	if session == null:
		return
	var err: int = Slots.write(slot, session)
	if pause != null:
		pause.set_status("已保存到槽 %d" % slot if err == OK else "保存失败（%d）" % err)


func _on_load_slot(slot: int) -> void:
	_close_pause()
	_load_slot(slot)


func _quit_game() -> void:
	get_tree().quit()


## 自动存档：阶段、所在地点、休整天数任何一项变了就落一次盘。
## 只在远征/结算/休整里存，第一部结束（done）不覆盖旧档。
func _process(_delta: float) -> void:
	_autosave_tick()


func _autosave_tick() -> void:
	if session == null or String(session.phase) == "done":
		return
	var key := auto_key()
	if key == _auto_key:
		return
	_auto_key = key
	Slots.write(Slots.AUTO, session)


## 当前应该落在自动档上的状态指纹（验收脚本与测试也用它）。
func auto_key() -> String:
	if session == null:
		return ""
	var loc := ""
	if String(session.phase) == "expedition":
		loc = _location_id()
	return "%s|%s|%d" % [String(session.phase), loc, int(session.day)]


## Esc：标题画面先关覆盖层；游戏里先关对话框，再关暂停菜单，最后打开暂停菜单。
func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or k.keycode != KEY_ESCAPE:
		return
	if title_screen != null and is_instance_valid(title_screen):
		if title_screen.handle_escape():
			accept_event()
		return
	if panel != null and is_instance_valid(panel):
		panel.press_close()
		accept_event()
		return
	if pause != null:
		_close_pause()
	else:
		_open_pause()
	accept_event()


## 建 AI 接入层（HTTP 节点挂在自己身上才能联网）和对话层；读档后重调一次即可换掉 store。
func _setup_ai() -> void:
	if ai == null:
		var transport := HttpTransport.new()
		transport.name = "AiTransport"
		add_child(transport)
		ai = AiService.new(AiSettings.load_settings(), transport)
	dialogue = Dialogue.new(ai, _personas(), session.dialogues)


func _personas() -> Dictionary:
	var out := {}
	for id: String in Persona.load_all():
		out[id] = Persona.from_data(id)
	return out


func _location_id() -> String:
	if session.expedition == null:
		return ""
	var st: RefCounted = session.expedition.st
	for sid: String in st.squads:
		if (st.squads[sid]["members"] as Array).has("zheng_zha"):
			return String(st.squads[sid]["location"])
	return String(st.scenario.data["start_location"])


func _location_name() -> String:
	var id := _location_id()
	if id == "":
		return ""
	return String(session.expedition.st.scenario.location(id).get("name", id))


func _situation() -> String:
	return dialogue.situation_text(_location_name(), int(session.expedition.st.clock))


## 当前屏如果是远征界面就返回它（说服要问它谁最适合开口）。
func _expedition_screen() -> Control:
	if content.get_child_count() == 0:
		return null
	var c: Control = content.get_child(content.get_child_count() - 1)
	return c if c.has_method("press_talk") else null


func _open_panel(title: String, subtitle: String, mode: String) -> void:
	if panel != null:
		panel.queue_free()
		panel = null
	var p := DialoguePanel.new()
	add_child(p)
	p.open_for(title, subtitle, mode)
	p.closed.connect(func() -> void:
		if panel == p:
			panel = null
		p.queue_free()
	)
	panel = p


func _source_text(source: String) -> String:
	match source:
		"ai":
			return "在线 · " + _model_name()
		"replay":
			return "回放（这句话说过）"
		"none":
			return "（没有这个人设）"
	return "离线 · 脚本台词"


func _model_name() -> String:
	if ai == null:
		return ""
	return String((ai.settings["tiers"]["fast"] as Dictionary).get("model", ""))


## 有图就播，没图直接跳过——不能因为缺一张 CG 把流程卡死。
func _on_cutscene(cg_name: String, text: String) -> void:
	var screen := _expedition_screen()
	if not PortraitSource.has_cg(cg_name):
		if screen != null:
			screen.press_cutscene_done()
		return
	var c := Cutscene.new()
	c.name = "Cutscene"
	add_child(c)
	c.open_for(cg_name, text)
	c.finished.connect(func() -> void:
		c.queue_free()
		if screen != null and is_instance_valid(screen):
			screen.press_cutscene_done()
	)


func _on_talk(npc_id: String) -> void:
	var title: String = dialogue.display_name(npc_id)
	_open_panel(title, "%s · 第 %d 分钟" % [_location_name(), int(session.expedition.st.clock)], "talk")
	var p: Control = panel
	p.set_portrait(npc_id)
	p.set_status("……")
	dialogue.say(npc_id, "", _situation(), func(res: Dictionary) -> void:
		if panel != p:
			return
		p.push(title, String(res["say"]))
		p.set_status(_source_text(String(res["source"])))
	)
	p.submitted.connect(_on_said.bind(npc_id))


func _on_said(text: String, npc_id: String) -> void:
	var p: Control = panel
	if p == null:
		return
	p.push("我", text)
	# 禁言：说漏了就在这句话下面当场结算，玩家立刻知道哪句中招。
	if Gag.is_leak(text):
		_push_events(session.expedition.leak("zheng_zha"), p)
	p.set_status("……")
	p.set_replies([])
	dialogue.say(npc_id, text, _situation(), func(res: Dictionary) -> void:
		if panel != p:
			return
		p.push(dialogue.display_name(npc_id), String(res["say"]))
		p.set_status(_source_text(String(res["source"])))
		_after_said(npc_id, p)
	)


## 说过话就涨信任；到剧本给的门槛，对方会说一句实话，可能给线索。
func _after_said(npc_id: String, p: Control) -> void:
	var screen := _expedition_screen()
	if screen == null:
		return
	var def: Dictionary = screen.view.trust_def(npc_id)
	if def.is_empty():
		return
	for ev: Dictionary in dialogue.add_trust(npc_id, 1, def):
		if String(ev.get("line", "")) != "":
			p.push(dialogue.display_name(npc_id), String(ev["line"]))
		_push_events(session.expedition.apply_effects(ev["effects"], _location_id()), p)
	screen.refresh()


func _push_events(events: Array, p: Control) -> void:
	var names := _event_names()
	for e: Dictionary in events:
		var text := EventText.describe(e, names)
		if text != "":
			p.push("（结果）", text)


## 事件文本要的不只是人名：地点、剧情事件、线索都得有中文名，不然日志里全是 id。
func _event_names() -> Dictionary:
	var out := _names()
	if session.expedition == null:
		return out
	var sc: RefCounted = session.expedition.st.scenario
	for loc_id: String in sc.data.get("locations", {}):
		out[loc_id] = String(sc.location(loc_id).get("name", loc_id))
	for ev: Dictionary in sc.events():
		out[String(ev["id"])] = String(ev.get("label", ev["id"]))
	for npc_id: String in sc.data.get("npcs", {}):
		out[npc_id] = String(sc.data["npcs"][npc_id].get("name", npc_id))
	for fact_id: String in sc.data.get("facts", {}):
		var f: Dictionary = sc.data["facts"][fact_id]
		var statement := String(f.get("statement", fact_id))
		out[fact_id] = statement
		for clue_id: String in f.get("clues", {}):
			out[clue_id] = statement
	return out


func _on_persuade_free() -> void:
	var screen := _expedition_screen()
	if screen == null:
		return
	var check: Dictionary = session.expedition.st.pending_check
	if check.is_empty():
		return
	if not bool(session.expedition.can_persuade(String(screen.view.best_thinker_id()))["ok"]):
		return
	var npc := String(check["npc"])
	_open_panel("%s · 说服" % dialogue.display_name(npc), String(check["goal"]), "persuade")
	panel.set_portrait(npc)
	panel.push("（局面）", "要让对方点头：%s" % String(check["goal"]))
	panel.persuading.connect(_on_persuade_text)


func _on_persuade_text(text: String) -> void:
	var p: Control = panel
	var screen := _expedition_screen()
	if p == null or screen == null:
		return
	var check: Dictionary = session.expedition.st.pending_check
	if check.is_empty():
		p.push("（提示）", "现在没有要说服的人。")
		return
	var npc := String(check["npc"])
	p.push("我", text)
	p.set_status("……")
	dialogue.rate(npc, text, String(check["goal"]), check.get("keywords", []), _situation(), func(res: Dictionary) -> void:
		if panel != p:
			return
		p.push("（判定）", "说服力 %d/3。%s" % [int(res["level"]), String(res["reason"])])
		_push_events(session.expedition.resolve_persuasion(int(res["level"])), p)
		p.set_status(_source_text(String(res["source"])))
		screen.refresh()
	)


func _on_ask_zhushen() -> void:
	_open_panel("主神", "巨大的光球悬在头顶，没有表情。", "talk")
	panel.set_portrait("zhushen")
	panel.push("主神", "问。")
	panel.submitted.connect(_on_zhushen_question)


func _on_zhushen_question(text: String) -> void:
	var p: Control = panel
	if p == null:
		return
	p.push("我", text)
	p.set_status("……")
	dialogue.ask_zhushen(text, _zhushen_faq(), ZHSHEN_FORBIDDEN, func(res: Dictionary) -> void:
		if panel != p:
			return
		p.push("主神", String(res["answer"]))
		p.set_status(_source_text(String(res["source"])))
	)


func _zhushen_faq() -> Array:
	var res := DataLoader.load_json(ZHSHEN_FAQ)
	if not res.ok:
		return []
	return (res.data as Dictionary).get("faq", [])
```

- [ ] **Step 5：在改名的副本里跑切片验收**

切片验收会清空 `user://` 的存档槽，`user://` 跟着工程名走，所以复制一份、改工程名再跑：

```bash
rm -rf _work/p14_verify && mkdir -p _work/p14_verify && cp -r game _work/p14_verify/game
sed -i 's/^config\/name=.*/config\/name="无限恐怖_验收p14"/' _work/p14_verify/game/project.godot
timeout 300 godot --headless --path _work/p14_verify/game -s res://tools/verify_m1_slice.gd 2>&1 | tail -3; echo "exit=${PIPESTATUS[0]}"
```

预期：`M1 切片验证：失败 0 项`，`exit=0`。

- [ ] **Step 6：跑全量与导入**

```bash
bash game/tools/run_tests.sh > _work/p14_run.txt 2>&1; echo "tests exit=$?"; tail -1 _work/p14_run.txt; echo "SCRIPT ERROR: $(grep -c 'SCRIPT ERROR' _work/p14_run.txt)"
godot --headless --path game --import > _work/p14_imp.txt 2>&1; echo "import exit=$?"
git status --short | sort
```

预期：`共 414 个测试，失败 0 个`、`SCRIPT ERROR: 0`、`import exit=0`；`git status` 除了四个界面文件，多出 `game/core/model/talents.gd.uid` 和 `game/tests/unit/core/test_talents.gd.uid`。

- [ ] **Step 7：提交界面与 uid**

```bash
git add game/ui/hub/hub_view.gd game/ui/hub/hub_screen.gd game/ui/event_text.gd game/ui/main.gd game/core/model/talents.gd.uid game/tests/unit/core/test_talents.gd.uid
git commit -m "feat(ui): 人物卡显示觉醒的天赋，结算显示幸存与主神评价变化" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log --oneline -1
```

- [ ] **Step 8：更新 README 进度并提交**

```bash
python -I -X utf8 - <<'EOF'
p = "README.md"
s = open(p, encoding="utf-8").read()
o = "- 计划 13（M1 收尾：说服马修、禁言可触发、训练场对练、自动存档）已完成，累计 403 个无界面测试；规格 9.7 的 7 条完成标准里，PC 侧 6 条已满足，只剩安卓导出。\n"
n = o + "- 计划 14（天赋觉醒与主神议程接线：七种天赋按条件觉醒、詹岚可绕过精神力门槛；张杰的半引导者异常、片后调评价、郑吒造萝丽后被复制进恶魔小队）已完成，累计 414 个无界面测试。\n"
assert s.count(o) == 1
open(p, "w", encoding="utf-8", newline="\n").write(s.replace(o, n))
print("ok")
EOF
git add README.md
git commit -m "docs: 计划 14 完成，更新进度" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log --oneline -1
git status --short
```

- [ ] **Step 9：验收检查**

```bash
git log --oneline -6
grep -c $'\r' game/core/model/talents.gd game/core/expedition/expedition.gd game/ui/main.gd
for f in data/characters/talents.json core/model/talents.gd core/hub/exchange.gd core/intel/intel_state.gd core/intel/rule_discovery.gd data/hub/exchange_catalog.json data/characters/m1_roster.json core/director/agenda.gd data/director/director_rules.json core/model/game_state.gd core/campaign/campaign.gd data/scenarios/biohazard1/chapter.json core/session/session.gd core/hub/hub.gd core/expedition/expedition.gd ui/hub/hub_view.gd ui/hub/hub_screen.gd ui/event_text.gd ui/main.gd tests/unit/hub/test_exchange.gd tests/unit/core/test_talents.gd tests/unit/director/test_agenda.gd tests/unit/campaign/test_m1_content.gd tests/unit/session/test_session.gd; do cmp -s "game/$f" "_work/plan_check_p14/game/$f" || echo "DIFF $f"; done
echo "compare done"
test -z "$(git diff --name-only origin/main..HEAD | grep -iE '\.(png|jpe?g|webp|gif|wav|ogg)$')" && echo "no media"
```

预期：三个 `grep -c` 都是 `0`；`compare done` 前没有 `DIFF`；`no media`。
