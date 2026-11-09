# 计划 15：关系网、服从与规则百科 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补上 M1 核查发现的另外两块缺口：关系网和凝聚力写好了却没人用（剧情选择不影响信任，信任也不影响任何事）；规则百科、规则发现、"张杰讲规则解锁首批条目"都没有。

**Architecture:** 关系网（`core/social/relations.gd`）、新的规则百科（`core/intel/codex.gd`，内含已有的 `rule_discovery.gd`）和"拍板的人"（`leader`）都挂到 `GameState`，随存档走。剧本只发请求：`relation` 效果早就会发 `relation_request`，新增的 `codex` 效果发 `codex_request`；`Expedition._emit` 把这两种请求落到整局状态上。打完仗活下来的人互相"并肩作战"。队友对 `leader` 的服从度（已有的 `Cohesion.obedience`）不到 40 时，`battle_units()` 把他交给 AI。`Session.settle()` 让章节指定的老手带新人认识主神空间（老手死了就没人带）；`Hub` 每过一段天数让智者试着推出隐藏规则。界面加"队伍""百科"两页、战斗卡标"不听指挥"、问主神时按关键词解锁条目。

**Tech Stack:** Godot 4.7.2（GDScript）、JSON 数据、已有的 `Relations`/`Cohesion`/`RuleDiscovery`。

**依据：** 设计规格 7.4（关系网；凝聚力决定服从，信任低的人转为 AI 控制；M1：新人的信任与服从、扶不扶掉队者和留守还是跟走对信任的影响）、9.3（嘲讽的新人信任会变）、3.8（规则发现）、9.5.1（张杰讲规则解锁规则百科首批条目）、9.6（回归当晚张杰带新人认识光球和房间；主神问答解锁百科条目）。

**本计划已在临时目录跑通：430 个无界面测试全过、`SCRIPT ERROR 0`、M1 切片验收 0 失败、40 局随机乱玩无卡死。**

**执行环境注意：**
- 仓库根目录：`I:\workspace\mobilegame\wuxian-kongbu\`；命令都在仓库根目录执行（Git Bash）。
- 只跑某个测试：`WSLENV=TEST_FILTER TEST_FILTER=<文件名> bash game/tools/run_tests.sh`。
- 文本文件 **LF**、UTF-8 无 BOM；GDScript 用 **Tab**。
- 跑测试不生成 `.gd.uid`，导入工程（Task 3）才会。
- **只提交，不推送。**
- 临时验证目录是 `_work/plan_check_p15/game`。
- **切片验收会清空 `user://` 下的三个存档槽**，只在改了工程名的副本里跑（Task 3 Step 8）。

---

## 设计要点

- **谁是"拍板的人"**：扮演整队时，玩家的每个选择都以主角郑吒的名义做出，所以章节写 `"leader": "zheng_zha"`，队友对他的看法决定听不听指挥。他死了以后没人可服从，全员回到玩家手里。
- **服从阈值不改公式**：`Cohesion.obedience = 信任×0.5 + 敬畏×0.4 + 忠诚×0.2 − 怨恨×0.5`，默认关系下是 43，刚好听指挥；只要信任掉 10 就跌破 40。人物表没写忠诚的按 50。
- **选择落到数字上**（关系事件写在 `relation_events.json`，新增四种）：
  - 听讲：张杰对郑吒信任 +5；质疑 −5；嘲讽信任 −10、怨恨 +15（张杰服从 30.5，不听指挥，要并肩打三仗才回来）。
  - 扶掉队的人：两人对郑吒信任 +25（救命）、在场的人 +5；扔下他们：在场的人 −10（跌到 40，不听指挥）。
  - 救马修：在场的人 +5、敬畏 +5；只顾自己让牟钢死在激光里：在场的人 −10。
  - 采纳詹岚的提议留守：詹岚信任 +8；驳回她跟雇佣兵走：信任 −5、怨恨 +3（她跌破 40）。
- **一件事几个当事人，旁观者只算一次**：扔下两个人不该让旁观者扣两次分，`plot_runner` 只把旁观者交给第一个当事人。当事人也可以是剧情人物（救下马修）。
- **信任能修复**：每打完一仗，活下来的队友两两"并肩作战"（信任 +5、好感 +3）；跟队友聊天每次 +2，但只聊到 60，再往上要靠行动。
- **规则百科分两部分**：公开规则 18 条（`data/intel/codex.json`），开场三条、认真听讲再加五条、回归当晚老手带着认识六条、其余问主神；隐藏规则沿用 `hidden_rules.json`，智者在休整里推出来。张杰死了没人带导览，那六条只能问主神——这也是一个可感知的分歧。
- **问主神按关键词解锁**：主神只答规则，所以判"问到了哪条"看问题里的关键词，不看 AI 怎么措辞，离线在线结果一样。

**不在本计划范围**：投票、诱饵、决裂（M2）；团队章程（M4）；恐惧传染倍率接入战斗；兑换目录扩充（计划 16）；萝丽陪伴、晨会、铁人模式（计划 17）；像素战斗画面（计划 18）；文档对齐、平衡、`tr()`（计划 19）。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `game/data/intel/codex.json` | 18 条公开规则：标题、正文、来源组、问主神的关键词 |
| `game/core/intel/codex.gd` | 规则百科：解锁、按组解锁、按问题解锁、显示列表、存读档（内含规则发现） |
| `game/core/social/relations.gd` | `bond()`：一群人两两经历同一件事 |
| `game/data/social/relation_events.json` | 新增听讲、质疑、嘲讽、意见被驳回 |
| `game/core/model/game_state.gd` | `relations`、`codex`、`leader` 三个字段，随存档走 |
| `game/data/scenarios/biohazard1/scenario.json` | 四个选择都带关系事件；开场和听讲带百科条目 |
| `game/core/expedition/scenario.gd` | 剧本校验认识 `codex` 效果 |
| `game/core/expedition/plot_runner.gd` | `codex` 效果；关系事件支持剧情人物当事人、旁观者只算一次 |
| `game/data/scenarios/biohazard1/chapter.json` | `leader`、`hub_tour_guide` |
| `game/core/campaign/campaign.gd` | 开局写 `leader` |
| `game/core/expedition/expedition.gd` | 请求落地、并肩作战、服从与 AI 接管 |
| `game/core/session/session.gd` | 回归当晚的导览、聊天涨信任 |
| `game/core/hub/hub.gd` | 过天时的规则发现 |
| `game/ui/hub/hub_view.gd`、`game/ui/hub/hub_screen.gd` | "队伍""百科"两页；规则发现的提示 |
| `game/ui/battle/battle_view.gd` | AI 接管的队友标"不听指挥" |
| `game/ui/event_text.gd` | 关系、百科、规则发现的中文文案 |
| `game/ui/main.gd` | 结算显示导览；聊天涨信任；问主神解锁百科 |

---

## Task 1：整局状态里的关系网、规则百科和拍板的人

**Files:**
- Create: `game/data/intel/codex.json`、`game/core/intel/codex.gd`
- Modify: `game/core/social/relations.gd`、`game/data/social/relation_events.json`、`game/core/model/game_state.gd`
- Test: `game/tests/unit/intel/test_codex.gd`（新）、`game/tests/unit/social/test_relations.gd`

- [ ] **Step 1：写测试 `game/tests/unit/intel/test_codex.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Codex = preload("res://core/intel/codex.gd")
const Character = preload("res://core/model/character.gd")
const GameState = preload("res://core/model/game_state.gd")


## 同一条只解锁一次；不认识的 id 跳过；全都知道了返回空数组。
func test_unlock_once() -> void:
	var c := Codex.new()
	var events: Array[Dictionary] = c.unlock(["survive_points", "nope", "go_home"], "zhang_jie")
	assert_eq(events, [{"type": "codex_unlocked", "entries": ["survive_points", "go_home"] as Array[String], "source": "zhang_jie"}] as Array[Dictionary])
	assert_eq(c.unlock(["go_home"], "zhushen"), [] as Array[Dictionary])
	assert_eq(String(c.known["go_home"]["source"]), "zhang_jie", "第一次告诉你的人不变")
	assert_true(c.is_known("survive_points"))
	assert_false(c.is_known("tether"))


## 回归当晚的导览：hub_tour 组整组解锁。
func test_unlock_group() -> void:
	var c := Codex.new()
	var events: Array[Dictionary] = c.unlock_group("hub_tour", "zhang_jie")
	var ids: Array = events[0]["entries"]
	assert_true(ids.has("exchange"))
	assert_true(ids.has("human_creation"))
	assert_false(ids.has("tether"))
	for id: String in ids:
		assert_eq(String(Codex.entry(id)["group"]), "hub_tour")


## 问主神：问题里带关键词就解锁对应条目；问剧情、问不相干的不解锁。
func test_unlock_by_question() -> void:
	var c := Codex.new()
	var events: Array[Dictionary] = c.unlock_by_question("支线能拆分吗？")
	var ids: Array = events[0]["entries"]
	assert_true(ids.has("ticket_split"))
	assert_true(ids.has("side_plots"))
	assert_eq(String(c.known["ticket_split"]["source"]), "zhushen")
	assert_eq(c.unlock_by_question("下一部是什么片？"), [] as Array[Dictionary])


## 百科：公开规则按解锁顺序，后面接智者发现的隐藏规则；还有多少条没听说过。
func test_entries_and_hidden_rules() -> void:
	var g := GameState.new(1)
	var zl := Character.new("zhan_lan", "詹岚", {"intelligence": 190})
	g.add_character(zl)
	g.flags["seen_human_creation"] = true
	var c: RefCounted = g.codex
	c.unlock(["watch_tasks", "survive_points"], "zhang_jie")
	var found: Array[Dictionary] = c.discovery.discover_all([zl], g)
	assert_eq(String(found[0]["rule"]), "bodyguard_human")
	var list: Array[Dictionary] = c.entries()
	assert_eq(list.size(), 3)
	assert_eq(String(list[0]["id"]), "watch_tasks")
	assert_false(bool(list[0]["hidden"]))
	assert_eq(String(list[2]["id"]), "bodyguard_human")
	assert_true(bool(list[2]["hidden"]))
	assert_eq(String(list[2]["source"]), "zhan_lan")
	assert_eq(c.locked_count(), Codex.data().size() - 2)


## 存读档：已知条目、顺序、发现的隐藏规则都保留；旧存档没有 codex 字段时是空百科。
func test_round_trip() -> void:
	var g := GameState.new(1)
	g.codex.unlock(["gag", "tether"], "zhang_jie")
	g.codex.discovery.discovered["always_a_way"] = {"by": "zhan_lan"}
	var d: Dictionary = g.to_dict()
	var h := GameState.new()
	h.load_dict(d)
	assert_eq(h.codex.to_dict(), g.codex.to_dict())
	assert_eq(h.codex.order, ["gag", "tether"])
	d.erase("codex")
	var old := GameState.new()
	old.load_dict(d)
	assert_eq(old.codex.entries(), [] as Array[Dictionary])
```

- [ ] **Step 2：改写 `game/tests/unit/social/test_relations.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Relations = preload("res://core/social/relations.gd")


func test_defaults() -> void:
	var r := Relations.new()
	assert_almost(r.value("a", "b", "trust"), 50.0)
	assert_almost(r.value("a", "b", "awe"), 20.0)
	assert_almost(r.value("a", "b", "resentment"), 0.0)
	assert_true(r.pairs.is_empty())


## 关系是单向的，并且限制在 0~100。
func test_directional_and_clamped() -> void:
	var r := Relations.new()
	r.change("a", "b", {"trust": 70})
	assert_almost(r.value("a", "b", "trust"), 100.0)
	assert_almost(r.value("b", "a", "trust"), 50.0)
	r.change("a", "b", {"resentment": -10})
	assert_almost(r.value("a", "b", "resentment"), 0.0)


## 救命：被救的人信任和好感上升，旁观者也会多一点信任和敬畏。
func test_saved_life() -> void:
	var r := Relations.new()
	var ev: Dictionary = r.apply_event("saved_life", "zheng_zha", "zhan_lan", ["zhang_jie"])
	assert_eq(ev["name"], "救命")
	assert_almost(r.value("zhan_lan", "zheng_zha", "trust"), 75.0)
	assert_almost(r.value("zhan_lan", "zheng_zha", "affection"), 65.0)
	assert_almost(r.value("zhang_jie", "zheng_zha", "trust"), 55.0)
	assert_almost(r.value("zhang_jie", "zheng_zha", "awe"), 25.0)


## 异形一：楚轩拿李帅西当诱饵（设计规格 9.8）。
func test_used_as_bait() -> void:
	var r := Relations.new()
	r.apply_event("used_as_bait", "chu_xuan", "li_shuaixi", ["zheng_zha", "chu_xuan"])
	assert_almost(r.value("li_shuaixi", "chu_xuan", "trust"), 20.0)
	assert_almost(r.value("li_shuaixi", "chu_xuan", "resentment"), 25.0)
	assert_almost(r.value("zheng_zha", "chu_xuan", "trust"), 40.0)
	assert_almost(r.value("chu_xuan", "chu_xuan", "trust"), 50.0)


func test_mutual_event() -> void:
	var r := Relations.new()
	r.apply_event("fought_together", "a", "b")
	assert_almost(r.value("a", "b", "trust"), 55.0)
	assert_almost(r.value("b", "a", "trust"), 55.0)


func test_tags_and_round_trip() -> void:
	var r := Relations.new()
	r.add_tag("zheng_zha", "luo_li", "creator")
	r.add_tag("zheng_zha", "luo_li", "creator")
	r.apply_event("lied_to", "chu_xuan", "zheng_zha")
	assert_true(r.has_tag("zheng_zha", "luo_li", "creator"))
	assert_eq((r.get_rel("zheng_zha", "luo_li")["tags"] as Array).size(), 1)
	var copy := Relations.new()
	copy.load_dict(JSON.parse_string(JSON.stringify(r.to_dict())))
	assert_eq(copy.to_dict(), r.to_dict())


## 一群人并肩作战：每两人之间互相 +5 信任、+3 好感；返回一条汇总事件。
func test_bond() -> void:
	var r := Relations.new()
	var ev: Dictionary = r.bond("fought_together", ["a", "b", "c"])
	assert_eq(ev, {"type": "bonded", "kind": "fought_together", "name": "并肩作战", "chars": ["a", "b", "c"]})
	for pair in [["a", "b"], ["b", "a"], ["a", "c"], ["c", "b"]]:
		assert_almost(r.value(pair[0], pair[1], "trust"), 55.0)
		assert_almost(r.value(pair[0], pair[1], "affection"), 53.0)
```

- [ ] **Step 3：运行，确认失败**

Run: `bash game/tools/run_tests.sh | tail -3`

预期：`test_codex.gd` 加载失败（`codex.gd` 还不存在）、`test_relations.gd::test_bond` 失败；这一步只要不是全部通过就对。

- [ ] **Step 4：创建 `game/data/intel/codex.json`**

```json
{
	"version": 1,
	"entries": {
		"survive_points": {
			"title": "活过一部片，一千点",
			"text": "每个活着回到主神空间的人，至少拿到一千点奖励点数。",
			"group": "opening",
			"keywords": ["点数", "奖励", "一千"]
		},
		"go_home": {
			"title": "攒够点数能回现实",
			"text": "张杰说攒够五万点可以回到现实世界。具体条件只有主神知道。",
			"group": "opening",
			"keywords": ["回家", "回现实", "现实"]
		},
		"watch_tasks": {
			"title": "手表发布任务",
			"text": "进片后手表会显示主线任务和剩余时间。主线完成、倒计时结束，才会被传送回来。",
			"group": "opening",
			"keywords": ["手表", "任务", "倒计时"]
		},
		"tether": {
			"title": "绑定与抹杀",
			"text": "手表可能把你和某个剧情人物绑在一起：离开规定范围太久，主神直接抹杀。",
			"group": "opening_listen",
			"keywords": ["绑定", "百米", "抹杀", "范围"]
		},
		"gag": {
			"title": "不许泄露主神",
			"text": "当着剧情人物说出主神、轮回、点数这类东西，要被扣分。",
			"group": "opening_listen",
			"keywords": ["泄露", "禁言", "扣分", "说出"]
		},
		"kill_points": {
			"title": "杀怪有点数",
			"text": "杀死片里的怪物能拿点数，怪物越强给得越多。主神按队伍的实力折算，越强的队伍拿得越少。",
			"group": "opening_listen",
			"keywords": ["杀怪", "击杀", "怪物"]
		},
		"side_plots": {
			"title": "支线剧情",
			"text": "主线之外还有支线：完成了给支线等级（D、C、B……）和额外点数。好东西都要支线才能换。",
			"group": "opening_listen",
			"keywords": ["支线"]
		},
		"death_is_real": {
			"title": "死了就是真死",
			"text": "死在恐怖片里不会自动复活。新人第一次死，主神也不会管。",
			"group": "opening_listen",
			"keywords": ["死亡", "复活", "死了"]
		},
		"return_night": {
			"title": "回归当晚只结算",
			"text": "回来的第一晚只结算点数、造人；兑换要等到第二天。",
			"group": "hub_tour",
			"keywords": ["回归", "当晚", "第一晚"]
		},
		"exchange": {
			"title": "兑换",
			"text": "在光球前兑换强化、道具和血统：要点数，档次高的还要支线。十点奖励点换一点属性。",
			"group": "hub_tour",
			"keywords": ["兑换", "强化", "属性"]
		},
		"repair": {
			"title": "修复",
			"text": "受了伤可以花点数修复，伤得越重越贵。已经死了的人修不回来。",
			"group": "hub_tour",
			"keywords": ["修复", "治疗", "受伤"]
		},
		"human_creation": {
			"title": "造人",
			"text": "可以让主神造人，每人第一个免费，素质不超过常人两倍。造的人住在你的房间里。",
			"group": "hub_tour",
			"keywords": ["造人", "造物", "伴侣"]
		},
		"rest_days": {
			"title": "休整与光柱",
			"text": "每次回来有固定的休整天数。训练、休息耗天；最后一天黄昏光柱降下，必须走进去。",
			"group": "hub_tour",
			"keywords": ["休整", "光柱", "天数", "训练"]
		},
		"kill_teammate": {
			"title": "杀队友扣分",
			"text": "杀死同队的轮回者，主神扣一千点。",
			"group": "hub_tour",
			"keywords": ["杀队友", "内斗", "自相残杀"]
		},
		"ticket_split": {
			"title": "支线拆分",
			"text": "一个高一级的支线可以拆成三个低一级的：B 拆三个 C，C 拆三个 D。",
			"group": "zhushen",
			"keywords": ["拆分", "拆"]
		},
		"gift_once": {
			"title": "代兑一次",
			"text": "每次休整，每人只能用自己的点数或支线给别人兑换一次。",
			"group": "zhushen",
			"keywords": ["代兑", "给别人", "送"]
		},
		"bloodline_risk": {
			"title": "双血统风险",
			"text": "身上已经有一种血统再兑换另一种，七成会变成非人。",
			"group": "zhushen",
			"keywords": ["血统", "变异"]
		},
		"team_rating": {
			"title": "队伍评价",
			"text": "主神按队伍完成过的片和兑换的强弱评价队伍；评价越高，片越难、奖励折算越低。全队都死过，评价清零。",
			"group": "zhushen",
			"keywords": ["评价", "难度", "团灭"]
		}
	}
}
```

- [ ] **Step 5：创建 `game/core/intel/codex.gd`**

```gdscript
extends RefCounted
## 规则百科（设计规格 3.8、9.5.1、9.6）：玩家已经知道的主神规则，分两部分——
##   公开规则（data/intel/codex.json）：张杰讲规则（剧本 codex 效果）、回归当晚带新人认识主神空间（hub_tour 组）、问主神时按关键词解锁；
##   隐藏规则（rule_discovery.gd）：智者自己推出来的漏洞，发现之前在机制上锁着。
## 同一条只解锁一次；解锁顺序就是百科里的显示顺序。整局有效，随 GameState 存档。

const DataLoader = preload("res://core/util/data_loader.gd")
const RuleDiscovery = preload("res://core/intel/rule_discovery.gd")

const PATH := "res://data/intel/codex.json"

static var _cache: Dictionary = {}

## 条目 id → {"source": 从谁那里知道的（角色 id、"zhushen" ……）}
var known: Dictionary = {}
var order: Array = []
var discovery: RefCounted = RuleDiscovery.new()


static func data() -> Dictionary:
	if _cache.is_empty():
		var res := DataLoader.load_json(PATH)
		assert(res.ok, res.error)
		_cache = res.data["entries"]
	return _cache


static func entry(id: String) -> Dictionary:
	return data().get(id, {})


func is_known(id: String) -> bool:
	return known.has(id)


## 解锁一批条目。返回 [{"type": "codex_unlocked", "entries": [新解锁的 id], "source"}]；全都知道了返回空数组。
func unlock(ids: Array, source: String) -> Array[Dictionary]:
	var fresh: Array[String] = []
	for id in ids:
		var k := String(id)
		if not data().has(k) or known.has(k):
			continue
		known[k] = {"source": source}
		order.append(k)
		fresh.append(k)
	if fresh.is_empty():
		return []
	return [{"type": "codex_unlocked", "entries": fresh, "source": source}]


## 按条目的 group 批量解锁（hub_tour：回归当晚有老手带新人认识光球和房间）。
func unlock_group(group: String, source: String) -> Array[Dictionary]:
	var ids: Array = []
	for id: String in data():
		if String(data()[id].get("group", "")) == group:
			ids.append(id)
	return unlock(ids, source)


## 问主神：问题里提到某条目的关键词就解锁它（主神只答规则，不答剧情）。
func unlock_by_question(text: String) -> Array[Dictionary]:
	var ids: Array = []
	for id: String in data():
		for kw: String in data()[id].get("keywords", []):
			if text.contains(kw):
				ids.append(id)
				break
	return unlock(ids, "zhushen")


## 百科内容：已知的公开规则（按解锁顺序），后面接智者发现的隐藏规则。
func entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: String in order:
		var e := entry(id)
		out.append({"id": id, "title": String(e["title"]), "text": String(e["text"]), "source": String(known[id]["source"]), "hidden": false})
	for r: Dictionary in discovery.encyclopedia():
		out.append({"id": String(r["rule"]), "title": String(r["name"]), "text": "", "source": String(r["by"]), "hidden": true})
	return out


## 还没听说过的公开规则条数（提示玩家去问主神）。
func locked_count() -> int:
	return data().size() - known.size()


func to_dict() -> Dictionary:
	return {"known": known.duplicate(true), "order": order.duplicate(), "discovered": discovery.discovered.duplicate(true)}


func load_dict(d: Dictionary) -> void:
	known = (d.get("known", {}) as Dictionary).duplicate(true)
	order = (d.get("order", []) as Array).duplicate()
	discovery = RuleDiscovery.new()
	discovery.discovered = (d.get("discovered", {}) as Dictionary).duplicate(true)
```

- [ ] **Step 6：改写 `game/core/social/relations.gd`**

```gdscript
extends RefCounted
## 关系网（设计规格 7.4，核心机制分析 8.2）：每两个人之间、单向的四个数值（0~100）——
##   trust（信任）、affection（好感）、awe（敬畏）、resentment（怨恨），外加标记（恋慕、仇敌、师徒、战友……）。
## get_rel(a, b) 是 a 怎么看 b。没记录过的关系取默认值（data/social/relation_events.json 的 defaults）。
## 事件（救命、被当诱饵、见死不救……）按数据改变当事人和旁观者对行动者的看法。

const DataLoader = preload("res://core/util/data_loader.gd")

const PATH := "res://data/social/relation_events.json"
const KEYS: Array[String] = ["trust", "affection", "awe", "resentment"]

static var _cache: Dictionary = {}

## "a>b" → {"trust", "affection", "awe", "resentment", "tags": [...]}
var pairs: Dictionary = {}


static func data() -> Dictionary:
	if _cache.is_empty():
		var res := DataLoader.load_json(PATH)
		assert(res.ok, res.error)
		_cache = res.data
	return _cache


static func _key(a: String, b: String) -> String:
	return a + ">" + b


func get_rel(a: String, b: String) -> Dictionary:
	if pairs.has(_key(a, b)):
		return pairs[_key(a, b)]
	var d: Dictionary = (data()["defaults"] as Dictionary).duplicate()
	for k in KEYS:
		d[k] = float(d[k])
	d["tags"] = []
	return d


func value(a: String, b: String, key: String) -> float:
	return float(get_rel(a, b)[key])


func change(a: String, b: String, deltas: Dictionary) -> void:
	var r := get_rel(a, b)
	for k: String in deltas:
		r[k] = clampf(float(r[k]) + float(deltas[k]), 0.0, 100.0)
	pairs[_key(a, b)] = r


func add_tag(a: String, b: String, tag: String) -> void:
	var r := get_rel(a, b)
	if not (r["tags"] as Array).has(tag):
		(r["tags"] as Array).append(tag)
	pairs[_key(a, b)] = r


func has_tag(a: String, b: String, tag: String) -> bool:
	return (get_rel(a, b)["tags"] as Array).has(tag)


## 关系事件：actor 对 target 做了某事，witnesses 看到了。返回一条事件记录。
func apply_event(kind: String, actor: String, target: String, witnesses: Array = []) -> Dictionary:
	var ev: Dictionary = data()["events"][kind]
	if ev.has("target_to_actor"):
		change(target, actor, ev["target_to_actor"])
	if ev.has("actor_to_target"):
		change(actor, target, ev["actor_to_target"])
	if ev.has("witness_to_actor"):
		for w: String in witnesses:
			if w != actor and w != target:
				change(w, actor, ev["witness_to_actor"])
	return {"type": "relation_event", "kind": kind, "name": String(ev["name"]), "actor": actor, "target": target, "witnesses": witnesses.duplicate()}


## 一群人一起经历了某事（例如并肩作战）：每两人之间按事件各算一次，返回一条汇总事件。
func bond(kind: String, members: Array) -> Dictionary:
	for i in members.size():
		for j in range(i + 1, members.size()):
			apply_event(kind, String(members[i]), String(members[j]))
	return {"type": "bonded", "kind": kind, "name": String(data()["events"][kind]["name"]), "chars": members.duplicate()}


func to_dict() -> Dictionary:
	return {"pairs": pairs.duplicate(true)}


func load_dict(d: Dictionary) -> void:
	pairs = (d["pairs"] as Dictionary).duplicate(true)
```

- [ ] **Step 7：改写 `game/data/social/relation_events.json`**

```json
{
	"version": 1,
	"defaults": {"trust": 50, "affection": 50, "awe": 20, "resentment": 0},
	"events": {
		"saved_life": {"name": "救命", "target_to_actor": {"trust": 25, "affection": 15}, "witness_to_actor": {"trust": 5, "awe": 5}},
		"fought_together": {"name": "并肩作战", "target_to_actor": {"trust": 5, "affection": 3}, "actor_to_target": {"trust": 5, "affection": 3}},
		"advice_taken": {"name": "意见被采纳", "target_to_actor": {"trust": 8, "awe": 3}},
		"shown_strength": {"name": "展现实力", "witness_to_actor": {"awe": 10}, "target_to_actor": {"awe": 10}},
		"used_as_bait": {"name": "被当成诱饵", "target_to_actor": {"trust": -30, "resentment": 25}, "witness_to_actor": {"trust": -10, "resentment": 5}},
		"unfair_share": {"name": "分配不公", "target_to_actor": {"trust": -10, "resentment": 10}},
		"left_to_die": {"name": "见死不救", "target_to_actor": {"trust": -35, "resentment": 30}, "witness_to_actor": {"trust": -10}},
		"promise_broken": {"name": "违背承诺", "target_to_actor": {"trust": -20, "resentment": 10}},
		"lied_to": {"name": "“我骗你的”", "target_to_actor": {"trust": -15, "awe": 5, "resentment": 5}},
		"killed_innocent": {"name": "杀害无辜", "witness_to_actor": {"trust": -10, "affection": -5, "awe": 5}},
		"heeded_rules": {"name": "认真听讲", "target_to_actor": {"trust": 5}, "actor_to_target": {"awe": 10}},
		"questioned": {"name": "当面质疑", "target_to_actor": {"trust": -5}},
		"mocked": {"name": "当众嘲讽", "target_to_actor": {"trust": -10, "resentment": 15}},
		"advice_ignored": {"name": "意见被驳回", "target_to_actor": {"trust": -5, "resentment": 3}}
	}
}
```

- [ ] **Step 8：改写 `game/core/model/game_state.gd`**

```gdscript
extends RefCounted
## 整局游戏状态。存档就是它的 to_dict()。

const Rng = preload("res://core/util/rng.gd")
const Character = preload("res://core/model/character.gd")
const Agenda = preload("res://core/director/agenda.gd")
const Relations = preload("res://core/social/relations.gd")
const Codex = preload("res://core/intel/codex.gd")

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
## 队友关系网（设计规格 7.4）：信任、好感、敬畏、怨恨。
var relations: RefCounted = Relations.new()
## 规则百科（设计规格 3.8）：已知的公开规则和智者发现的隐藏规则。
var codex: RefCounted = Codex.new()
## 拍板的人（扮演整队时就是主角）；队友对他的服从度决定战斗里听不听指挥。空字符串表示没有。
var leader: String = ""


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
		"relations": relations.to_dict(),
		"codex": codex.to_dict(),
		"leader": leader,
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
	relations = Relations.new()
	if d.has("relations"):
		relations.load_dict(d["relations"])
	codex = Codex.new()
	if d.has("codex"):
		codex.load_dict(d["codex"])
	leader = String(d.get("leader", ""))
```

- [ ] **Step 9：运行，确认通过**

Run: `bash game/tools/run_tests.sh > _work/p15_task1.txt 2>&1; echo "exit=$?"; tail -1 _work/p15_task1.txt; echo "SCRIPT ERROR: $(grep -c 'SCRIPT ERROR' _work/p15_task1.txt)"`

预期：`共 420 个测试，失败 0 个`、`SCRIPT ERROR: 0`。

- [ ] **Step 10：提交**

```bash
git add game/data/intel/codex.json game/core/intel/codex.gd game/core/social/relations.gd game/data/social/relation_events.json game/core/model/game_state.gd game/tests/unit/intel/test_codex.gd game/tests/unit/social/test_relations.gd
git commit -m "feat(state): 关系网、规则百科和拍板的人进整局存档" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

## Task 2：剧情选择改信任、信任改服从、规则百科逐步解锁

**Files:**
- Modify: `game/data/scenarios/biohazard1/scenario.json`、`game/core/expedition/scenario.gd`、`game/core/expedition/plot_runner.gd`、`game/data/scenarios/biohazard1/chapter.json`、`game/core/campaign/campaign.gd`、`game/core/expedition/expedition.gd`、`game/core/session/session.gd`、`game/core/hub/hub.gd`
- Test: `game/tests/unit/campaign/test_m1_content.gd`、`game/tests/unit/session/test_session.gd`、`game/tests/unit/hub/test_hub.gd`

- [ ] **Step 1：改写 `game/tests/unit/campaign/test_m1_content.gd`**

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


## 张杰讲规则：开场就进三条百科；认真听再加五条，质疑的只有开场那三条。
func test_opening_codex() -> void:
	var g := GameState.new(1)
	var ex := Campaign.start(g, CHAPTER)
	assert_eq(g.codex.order, ["survive_points", "go_home", "watch_tasks"])
	ex.choose("listen")
	assert_eq(g.codex.order.size(), 8)
	assert_true(g.codex.is_known("tether"))
	var g2 := GameState.new(1)
	var ex2 := Campaign.start(g2, CHAPTER)
	ex2.choose("doubt")
	assert_eq(g2.codex.order.size(), 3)
	assert_almost(g2.relations.value("zhang_jie", "zheng_zha", "trust"), 45.0)


## 嘲讽张杰：他对郑吒信任 40、怨恨 15，服从度不到 40，下一场战斗由 AI 接管。
func test_mock_makes_zhang_jie_disobey() -> void:
	var g := GameState.new(1)
	var ex := Campaign.start(g, CHAPTER)
	var events: Array[Dictionary] = ex.choose("mock")
	assert_true(_types(events).has("relation_event"))
	assert_almost(g.relations.value("zhang_jie", "zheng_zha", "trust"), 40.0)
	assert_almost(g.relations.value("zhang_jie", "zheng_zha", "resentment"), 15.0)
	assert_false(ex.obeys("zhang_jie"))
	assert_true(ex.obeys("zhan_lan"))
	assert_true(ex.obeys("zheng_zha"), "拍板的人自己永远听自己的")
	ex.st.pending_battle = {"location": "car", "squad": "s1", "enemies": [{"def": "zombie", "count": 1}], "dark": false, "survive_until": -1.0, "after_victory": [], "after_defeat": []}
	assert_eq(ex.disobedient(), ["zhang_jie"] as Array[String])
	for u: RefCounted in ex.battle_units({}):
		if u.side == "ally":
			assert_eq(u.controller, "ai" if u.character_id == "zhang_jie" else "player", u.character_id)


## 扔下掉队的人：在场的人对郑吒信任 −10（两个当事人也只算一次），掉到 40，不听指挥；
## 一起打过一仗（并肩作战 +5）又回到听指挥。
func test_leave_costs_trust_until_fought_together() -> void:
	var g := GameState.new(1)
	var ex := Campaign.start(g, CHAPTER)
	ex.choose("doubt")
	ex.move("s1", "hall")
	ex.move("s1", "stairs")
	ex.choose("leave")
	assert_almost(g.relations.value("zhan_lan", "zheng_zha", "trust"), 40.0)
	assert_false(ex.obeys("zhan_lan"))
	assert_false(ex.obeys("li_xiao_yi"))
	ex.st.pending_battle = {"location": "stairs", "squad": "s1", "enemies": [{"def": "zombie", "count": 1}], "dark": false, "survive_until": -1.0, "after_victory": [], "after_defeat": []}
	var events := _win(ex)
	assert_true(_types(events).has("bonded"))
	assert_almost(g.relations.value("zhan_lan", "zheng_zha", "trust"), 45.0)
	assert_true(ex.obeys("zhan_lan"))


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
	# 救命之恩：被扶的人对郑吒信任 +25；旁观的人 +5（两个当事人只算一次）。
	assert_almost(ex.game.relations.value("xiao_pang_zi", "zheng_zha", "trust"), 75.0)
	assert_almost(ex.game.relations.value("zhan_lan", "zheng_zha", "trust"), 55.0)
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
	# 救下马修，在场的人看在眼里：扶人 +5、救马修 +5。
	assert_almost(ex.game.relations.value("zhan_lan", "zheng_zha", "trust"), 60.0)
	assert_almost(ex.game.relations.value("zhan_lan", "zheng_zha", "awe"), 30.0)
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
	# 眼看牟钢死在激光里：在场的人对郑吒信任 −10（扶人时 +5，现在 45）。
	assert_almost(ex.game.relations.value("zhan_lan", "zheng_zha", "trust"), 45.0)


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
	var zl_trust: float = g.relations.value("zhan_lan", "zheng_zha", "trust")
	ex.choose("stay")
	assert_true(bool(ex.st.flags["stay_control"]))
	assert_almost(g.relations.value("zhan_lan", "zheng_zha", "trust"), zl_trust + 8.0, 0.0001, "詹岚的提议被采纳")
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
	var zl_trust: float = ex.game.relations.value("zhan_lan", "zheng_zha", "trust")
	ex.choose("follow")
	assert_almost(ex.game.relations.value("zhan_lan", "zheng_zha", "trust"), zl_trust - 5.0, 0.0001, "詹岚的提议被驳回")
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

- [ ] **Step 2：改写 `game/tests/unit/session/test_session.gd`**

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


## 关系网、规则百科、拍板的人都随存档走。
func test_social_state_saved() -> void:
	_clean()
	var a := Session.new()
	a.start_m1(4)
	a.expedition.choose("mock")
	assert_eq(a.game.leader, "zheng_zha")
	assert_eq(a.save_to(SAVE_PATH), OK)
	var b := Session.load_from(SAVE_PATH)
	assert_eq(b.game.leader, "zheng_zha")
	assert_eq(b.game.relations.to_dict(), a.game.relations.to_dict())
	assert_eq(b.game.codex.to_dict(), a.game.codex.to_dict())
	assert_false(b.expedition.obeys("zhang_jie"))
	_clean()


## 回归当晚：张杰活着就带新人认识主神空间（hub_tour 六条进百科）；他死了就没人带。
func test_hub_tour_needs_guide() -> void:
	var s := Session.new()
	s.start_m1(1)
	s.expedition.st.outcome = "returned"
	s.settle()
	assert_eq(s.film_report["tour_guide"], "zhang_jie")
	assert_eq((s.film_report["tour_entries"] as Array).size(), 6)
	assert_true(s.game.codex.is_known("return_night"))
	var t := Session.new()
	t.start_m1(1)
	t.game.characters["zhang_jie"].alive = false
	t.expedition.st.outcome = "returned"
	t.settle()
	assert_eq(t.film_report["tour_guide"], "")
	assert_false(t.game.codex.is_known("return_night"))


## 跟队友聊天：每次对郑吒信任 +2，聊到 60 封顶；跟剧情人物、郑吒自己聊不算。
func test_talk_trust_capped() -> void:
	var s := Session.new()
	s.start_m1(1)
	var ev: Array[Dictionary] = s.talked("li_xiao_yi")
	assert_eq(String(ev[0]["type"]), "relation_talk")
	assert_almost(s.game.relations.value("li_xiao_yi", "zheng_zha", "trust"), 52.0)
	for i in 10:
		s.talked("li_xiao_yi")
	assert_almost(s.game.relations.value("li_xiao_yi", "zheng_zha", "trust"), 60.0)
	assert_eq(s.talked("li_xiao_yi"), [] as Array[Dictionary])
	assert_eq(s.talked("kaplan"), [] as Array[Dictionary])
	assert_eq(s.talked("zheng_zha"), [] as Array[Dictionary])


func test_reject_bad_save() -> void:
	assert_false(Session.new().load_dict({"version": 99}))
	assert_false(Session.new().load_dict({"version": 1, "chapter": "res://nope.json", "game": {}}))
	assert_true(Session.load_from("user://nope.json") == null)
```

- [ ] **Step 3：改写 `game/tests/unit/hub/test_hub.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const GameState = preload("res://core/model/game_state.gd")
const Hub = preload("res://core/hub/hub.gd")


func _game() -> RefCounted:
	var g := GameState.new(1)
	for id in ["zheng_zha", "zhang_jie", "newbie"]:
		var c := Character.new(id, id, {})
		c.points = 6502
		c.tickets.add("B", 1)
		g.add_character(c)
	return g


func _hub(g: RefCounted, days: int = 9) -> RefCounted:
	var h := Hub.new()
	h.start(g, days)
	return h


## 原著惯例：回归当晚不兑换，只结算和造人。
func test_return_night() -> void:
	var g := _game()
	var h := _hub(g)
	var events: Array[Dictionary] = h.exchange("zheng_zha", "desert_eagle")
	assert_eq(events[0], {"type": "hub_refused", "reason": "return_night"})
	events = h.create_human("zheng_zha", "萝丽", {"spirit": 150})
	assert_eq(events[0]["type"], "human_created")
	h.rest(1)
	events = h.exchange("zheng_zha", "desert_eagle")
	assert_eq(events[0]["type"], "exchange_done")


func test_days_and_fear() -> void:
	var g := _game()
	var h := _hub(g)
	g.characters["newbie"].fear = 40.0
	var events: Array[Dictionary] = h.rest(2)
	assert_eq(h.day, 2)
	assert_eq(h.days_left(), 7)
	assert_almost(g.characters["newbie"].fear, 10.0)
	assert_eq(events[1], {"type": "day_passed", "day": 2, "days_left": 7})
	assert_eq(h.rest(8)[0]["reason"], "no_days")
	h.rest(7)
	assert_true(h.can_depart())


## 训练提升熟练度；最后一天强制休息，不能占用。
func test_train() -> void:
	var g := _game()
	var h := _hub(g)
	var zz: RefCounted = g.characters["zheng_zha"]
	zz.abilities.append("red_flame")
	zz.proficiency["red_flame"] = 0.3
	h.train("zheng_zha", "red_flame", 2)
	assert_almost(float(zz.proficiency["red_flame"]), 0.8)
	assert_eq(h.day, 2)
	assert_eq(h.train("zheng_zha", "red_flame", 7)[0]["reason"], "no_days")
	assert_eq(h.train("zheng_zha", "flying", 1)[0]["reason"], "unknown_skill")
	h.train("zheng_zha", "red_flame", 6)
	assert_almost(float(zz.proficiency["red_flame"]), 1.0)


## 修复：轻伤"修补" 400，重伤按伤势涨到 2000；可以由别人付；满血不要钱。
func test_repair() -> void:
	var g := _game()
	var h := _hub(g)
	var zz: RefCounted = g.characters["zheng_zha"]
	assert_eq(h.repair_cost("zheng_zha"), 0)
	zz.hp = zz.hp_max() * 0.6
	assert_eq(h.repair_cost("zheng_zha"), 400)
	zz.hp = zz.hp_max() * 0.25
	assert_eq(h.repair_cost("zheng_zha"), 1200)
	zz.hp = 0.0
	assert_eq(h.repair_cost("zheng_zha"), 2000)
	zz.flags["gene_lock_aftereffect"] = true
	h.repair("zheng_zha", "zhang_jie")
	assert_almost(zz.hp, zz.hp_max())
	assert_eq(zz.points, 6502)
	assert_eq(g.characters["zhang_jie"].points, 4502)
	assert_false(zz.flags.has("gene_lock_aftereffect"))
	assert_eq(h.repair("zheng_zha")[0]["reason"], "not_injured")


## 造人：第一个免费，之后 500 点；素质最多两倍常人。
func test_create_human() -> void:
	var g := _game()
	var h := _hub(g)
	var first: Array[Dictionary] = h.create_human("zheng_zha", "萝丽", {"spirit": 150, "muscle": 300})
	assert_eq(int(first[0]["cost"]), 0)
	assert_almost(float(first[0]["companion"]["attributes"]["muscle"]), 200.0)
	var second: Array[Dictionary] = h.create_human("zheng_zha", "保镖", {})
	assert_eq(int(second[0]["cost"]), 500)
	assert_eq(g.characters["zheng_zha"].points, 6002)
	assert_eq(g.companions.size(), 2)
	assert_eq(g.companions[1]["id"], "zheng_zha_human_2")


func test_buy_attribute() -> void:
	var g := _game()
	var h := _hub(g)
	h.rest(1)
	h.buy_attribute("newbie", "nerve_reaction", 100)
	assert_eq(g.characters["newbie"].points, 5502)
	assert_almost(g.characters["newbie"].attributes.total("nerve_reaction"), 200.0)
	assert_eq(h.buy_attribute("newbie", "muscle", 1000)[0]["reason"], "not_enough_points")


func test_tickets() -> void:
	var g := _game()
	var h := _hub(g)
	h.split_ticket("zheng_zha", "B")
	assert_eq(int(g.characters["zheng_zha"].tickets.counts["C"]), 3)
	h.merge_tickets("zheng_zha", "C")
	assert_eq(int(g.characters["zheng_zha"].tickets.counts["B"]), 1)
	assert_eq(h.split_ticket("zheng_zha", "D")[0]["reason"], "cannot_split")


## 每人每次休整只能给别人代兑一次。
func test_gift_once_per_rest() -> void:
	var g := _game()
	var h := _hub(g)
	h.rest(1)
	var first: Array[Dictionary] = h.exchange("newbie", "desert_eagle", {"payer": "zhang_jie"})
	assert_eq(first[0]["type"], "exchange_done")
	var second: Array[Dictionary] = h.exchange("zheng_zha", "desert_eagle", {"payer": "zhang_jie"})
	assert_eq(second[0]["reasons"], ["gift_used"])
	var own: Array[Dictionary] = h.exchange("zhang_jie", "desert_eagle")
	assert_eq(own[0]["type"], "exchange_done")


func test_save_round_trip() -> void:
	var g := _game()
	var h := _hub(g)
	h.rest(3)
	h.exchange("newbie", "desert_eagle", {"payer": "zhang_jie"})
	var copy := Hub.new()
	copy.load_dict(JSON.parse_string(JSON.stringify(h.to_dict())), g)
	assert_eq(copy.to_dict(), h.to_dict())
	assert_eq(copy.days_left(), 6)


## 规则发现：智力够 180、见过造人的人，休整一天就推出"第一个造人名额应该造保镖"，写进规则百科。
func test_rule_discovery_on_day_pass() -> void:
	var g := _game()
	var h := _hub(g)
	var events: Array[Dictionary] = h.rest(1)
	assert_eq(events.size(), 1, "没人够格时什么也发现不了")
	g.characters["zhang_jie"].attributes.add_enhanced("intelligence", 80.0)
	g.flags["seen_human_creation"] = true
	events = h.rest(1)
	assert_eq(String(events[1]["type"]), "rule_discovered")
	assert_eq(String(events[1]["rule"]), "bodyguard_human")
	assert_eq(String(events[1]["by"]), "zhang_jie")
	assert_eq(String(g.codex.entries()[0]["id"]), "bodyguard_human")
	assert_eq(h.rest(1).size(), 1, "发现过的不再报")
```

- [ ] **Step 4：运行，确认失败**

Run: `bash game/tools/run_tests.sh | tail -3`

预期：有失败，或者因为 `obeys` / `disobedient` / `talked` 还不存在而出现 `SCRIPT ERROR`；只要不是全部通过就对。

- [ ] **Step 5：改写 `game/data/scenarios/biohazard1/scenario.json`**

```json
{
	"id": "biohazard1",
	"name": "生化危机一",
	"start_location": "car",
	"duration_minutes": 187,
	"main_task": "存活 3 小时 07 分；不得离开马修 100 米",
	"locations": {
		"car": {"name": "高速车厢", "pos": [60, 700], "search": [{"item": "grenade", "count": 1}, {"item": "ammo", "count": 6}]},
		"hall": {"name": "蜂巢入口大厅", "pos": [220, 600]},
		"stairs": {"name": "楼梯井", "pos": [380, 500], "dark": true},
		"laser": {"name": "激光通道", "pos": [540, 400], "search": [{"item": "ammo", "count": 4}]},
		"control": {"name": "火焰女皇主机房", "pos": [700, 280], "search": [{"item": "spray", "count": 2}, {"item": "antidote", "count": 1}], "search_minutes": 20, "search_encounter": {"chance": 0.35, "intro": "翻柜子的声音引来了两只丧尸。", "enemies": [{"def": "zombie", "count": 3, "row": 0}]}},
		"corridor": {"name": "实验区走廊", "pos": [700, 520], "search": [{"item": "ammo", "count": 6}], "search_encounter": {"chance": 0.5, "intro": "柜门倒下的声音在走廊里回荡。", "enemies": [{"def": "zombie", "count": 3, "row": 0}]}},
		"freezer": {"name": "冷冻仓库", "pos": [700, 740], "dark": true, "search": [{"item": "antidote", "count": 2}], "search_encounter": {"chance": 0.4, "intro": "冷气里窜出一条丧尸犬。", "enemies": [{"def": "zombie_dog", "count": 2, "row": 0}]}},
		"sewer": {"name": "下水道", "pos": [380, 820], "dark": true, "search": [{"item": "ammo", "count": 4}], "search_encounter": {"chance": 0.5, "intro": "水声盖不住爪子刮管壁的声音。", "enemies": [{"def": "zombie_dog", "count": 2, "row": 0}]}}
	},
	"paths": [
		{"a": "car", "b": "hall", "minutes": 10},
		{"a": "hall", "b": "stairs", "minutes": 8},
		{"a": "stairs", "b": "laser", "minutes": 7},
		{"a": "laser", "b": "control", "minutes": 5, "closed": true},
		{"a": "control", "b": "corridor", "minutes": 4},
		{"a": "corridor", "b": "freezer", "minutes": 5},
		{"a": "corridor", "b": "sewer", "minutes": 6},
		{"a": "hall", "b": "sewer", "minutes": 15}
	],
	"npcs": {
		"matthew": {"name": "马修·艾迪森", "location": "hall", "plot": true},
		"alice": {"name": "艾丽丝", "location": "hall", "plot": true},
		"ryan": {"name": "瑞恩", "location": "hall", "plot": true},
		"matt": {"name": "马特", "location": "hall", "plot": true},
		"kaplan": {"name": "卡普兰", "location": "hall", "plot": true},
		"jd": {"name": "J·D", "location": "hall", "plot": true},
		"rain": {"name": "雷恩", "location": "hall", "plot": true},
		"red_queen": {"name": "火焰女皇", "location": "control", "plot": false}
	},
	"trust": {
		"kaplan": {"at": 2, "line": "主机房的线路我摸过。激光是女皇自己控的，不是墙上的开关。", "effects": [{"clue": "queen_console"}]},
		"alice": {"at": 2, "line": "激光通道……跑错一步就没了。别信地上的标记。", "effects": [{"clue": "laser_survived"}]},
		"zhan_lan": {"at": 2, "line": "张杰讲规则讲得太顺了，像是背过。", "effects": [{"clue": "rules_too_smooth"}]},
		"zhang_jie": {"at": 3, "line": "枪这东西，看谁拿。我这把可不是道具。", "effects": [{"clue": "desert_eagle"}]}
	},
	"watch": {
		"gag_penalty": -10,
		"dark_flag": "power_out"
	},
	"facts": {
		"queen_controls_lasers": {
			"statement": "火焰女皇控制着蜂巢里的激光防御",
			"domain": "biohazard",
			"truth": true,
			"difficulty": 0.4,
			"clues": {"zheng_zha_memory": 0.5, "queen_console": 0.5}
		},
		"matthew_doomed": {
			"statement": "原剧情里马修会死在激光通道",
			"domain": "biohazard",
			"truth": true,
			"difficulty": 0.5,
			"clues": {"zheng_zha_memory": 0.3, "matthew_dies": 1.0, "laser_survived": 0.4}
		},
		"zhang_jie_hiding": {
			"statement": "张杰的实力远不止他表现出来的样子",
			"domain": "zhushen",
			"truth": true,
			"difficulty": 0.6,
			"clues": {"desert_eagle": 0.5, "rules_too_smooth": 0.5}
		}
	},
	"events": [
		{
			"id": "opening",
			"label": "张杰讲规则",
			"at": 0,
			"location": "car",
			"effects": [
				{"say": {"speaker": "zhang_jie", "text": "菜鸟们，欢迎来到恐怖片的世界。活过一部片，一千点；攒够五万点，可以回现实。"}},
				{"bonus": {"points": 100, "label": "讲解规则", "recipients": ["zhang_jie"]}},
				{"clue": "rules_too_smooth"},
				{"clue": "zheng_zha_memory"},
				{"codex": {"ids": ["survive_points", "go_home", "watch_tasks"], "source": "zhang_jie"}},
				{"choice": {"id": "opening_attitude", "prompt": "张杰讲完规则，看着你们几个新人。", "options": [
					{"id": "listen", "text": "认真听完，记住每一条", "effects": [
						{"set_flag": "listened_rules"},
						{"relation": {"kind": "heeded_rules", "actor": "zheng_zha", "target": "zhang_jie"}},
						{"codex": {"ids": ["tether", "gag", "kill_points", "side_plots", "death_is_real"], "source": "zhang_jie"}}
					]},
					{"id": "doubt", "text": "质疑：凭什么信你", "effects": [
						{"fear": {"amount": 5}},
						{"set_flag": "doubted_rules"},
						{"relation": {"kind": "questioned", "actor": "zheng_zha", "target": "zhang_jie"}},
						{"say": {"speaker": "zhang_jie", "text": "信不信由你，反正死的是你。"}}
					]},
					{"id": "mock", "text": "嘲讽他装神弄鬼", "effects": [
						{"fear": {"amount": 10}},
						{"set_flag": "mocked_rules"},
						{"relation": {"kind": "mocked", "actor": "zheng_zha", "target": "zhang_jie"}},
						{"say": {"speaker": "zhang_jie", "text": "有意思。等会儿别哭。"}}
					]}
				]}}
			]
		},
		{
			"id": "mercs_board",
			"label": "雇佣兵登场",
			"at": 10,
			"location": "hall",
			"effects": [
				{"npc_move": {"npc": "matthew", "to": "hall"}},
				{"npc_move": {"npc": "alice", "to": "hall"}},
				{"npc_move": {"npc": "kaplan", "to": "hall"}},
				{"npc_move": {"npc": "ryan", "to": "hall"}},
				{"npc_move": {"npc": "rain", "to": "hall"}},
				{"npc_move": {"npc": "jd", "to": "hall"}},
				{"npc_move": {"npc": "matt", "to": "hall"}},
				{"say": {"speaker": "matthew", "text": "你们六个，从现在起是保安。跟紧我，别离开一百米。"}},
				{"set_tether": {"npc": "matthew", "max_hops": 1, "grace_minutes": 10, "transfer_to": "kaplan"}},
				{"clue": "desert_eagle"},
				{"say": {"speaker": "zhang_jie", "text": "看什么看，老子的枪。"}}
			]
		},
		{
			"id": "control_console",
			"label": "卡普兰介绍火焰女皇",
			"when": {"party_at": "control"},
			"location": "control",
			"effects": [
				{"say": {"speaker": "kaplan", "text": "火焰女皇控制着整栋楼的防御，包括那些激光。"}},
				{"clue": "queen_console"}
			]
		},
		{
			"id": "stairs_lag",
			"label": "新人掉队",
			"when": {"party_at": "stairs"},
			"location": "stairs",
			"effects": [
				{"say": {"speaker": "zhang_jie", "text": "小胖子和阿姨掉队了。等不等？"}},
				{"choice": {"id": "lag_behind", "prompt": "两个人的体力撑不住了，等他们会拖慢队伍。", "options": [
					{"id": "help", "text": "扶着他们一起走", "effects": [
						{"relation": {"kind": "saved_life", "actor": "zheng_zha", "targets": ["xiao_pang_zi", "zhong_nian_fu_nv"]}},
						{"delay": {"minutes": 15}},
						{"fear": {"amount": 10}},
						{"set_flag": "helped_lagging"},
						{"say": {"speaker": "xiao_pang_zi", "text": "谢谢……谢谢郑哥。"}}
					]},
					{"id": "leave", "text": "不管他们，跟上雇佣兵", "effects": [
						{"relation": {"kind": "left_to_die", "actor": "zheng_zha", "targets": ["xiao_pang_zi", "zhong_nian_fu_nv"]}},
						{"erase": {"targets": ["xiao_pang_zi", "zhong_nian_fu_nv"], "reason": "tether"}},
						{"fear": {"amount": 15}},
						{"say": {"speaker": "zhang_jie", "text": "超出范围了。别看。"}}
					]}
				]}}
			]
		},
		{
			"id": "laser_corridor",
			"label": "激光通道",
			"when": {"party_at": "laser"},
			"location": "laser",
			"inertia": 2,
			"effects": [
				{"cg": {"name": "cg_laser", "text": "激光网正在合拢，只有贴着大门的一小块地方是安全的。"}},
				{"say": {"speaker": "matthew", "text": "郑吒、牟钢，你们两个跟我进来。"}},
				{"give": {"recipients": ["zheng_zha"], "skill": "pistol_shot_limited"}},
				{"persuade": {
					"id": "convince_matthew", "npc": "matthew",
					"goal": "让马修同意你走在最后，好盯着激光的动势",
					"difficulty": 1,
					"keywords": ["最后", "盯着", "激光", "反应"],
					"success": [
						{"fear": {"amount": -10, "recipients": ["zheng_zha"]}},
						{"say": {"speaker": "matthew", "text": "行，你走最后。看清楚了再动。"}}
					],
					"failure": [
						{"fear": {"amount": 5}},
						{"say": {"speaker": "matthew", "text": "少废话，跟紧我走。"}}
					]
				}},
				{"choice": {"id": "laser_choice", "prompt": "激光网正在合拢，只有贴着大门的一小块地方是安全的。", "options": [
					{"id": "save_matthew", "text": "扑倒，拖着马修贴到门上", "effects": [
						{"open_path": ["laser", "control"]},
						{"relation": {"kind": "saved_life", "actor": "zheng_zha", "target": "matthew"}},
						{"side_plot": {"id": "save_matthew", "grade": "B", "points": 5000, "label": "救下马修", "recipients": ["zheng_zha"]}},
						{"bonus": {"points": 500, "label": "精神临界值突破", "recipients": ["zheng_zha"], "attributes": {"spirit": 20, "nerve_reaction": 30}}},
						{"tether_release": true},
						{"clue": "laser_survived"},
						{"say": {"speaker": "matthew", "text": "你救了我。为什么？"}}
					]},
					{"id": "self_only", "text": "只顾自己贴门，喊一声让他躲", "effects": [
						{"open_path": ["laser", "control"]},
						{"npc_die": "matthew"},
						{"fear": {"amount": 20}},
						{"relation": {"kind": "left_to_die", "actor": "zheng_zha", "target": "mu_gang"}},
						{"damage": {"amount": 999, "recipients": ["mu_gang"], "reason": "laser"}},
						{"clue": "matthew_dies"}
					]},
					{"id": "panic", "text": "慌乱后退", "effects": [
						{"open_path": ["laser", "control"]},
						{"damage": {"amount": 60, "recipients": "present", "reason": "laser"}},
						{"npc_die": "matthew"},
						{"damage": {"amount": 999, "recipients": ["mu_gang"], "reason": "laser"}}
					]}
				]}}
			]
		},
		{
			"id": "queen_shutdown",
			"label": "火焰女皇被关闭",
			"at": 70,
			"location": "control",
			"effects": [
				{"npc_move": {"npc": "kaplan", "to": "control"}},
				{"say": {"speaker": "kaplan", "text": "火焰女皇已关闭。我们得快点。"}},
				{"set_flag": "queen_off"},
				{"battle": {"location": "control", "enemies": [{"def": "zombie", "count": 8, "row": 0}]}}
			]
		},
		{
			"id": "divergence",
			"label": "詹岚的提议",
			"when": {"all": [{"time_at_least": 90}, {"party_at": "control"}]},
			"location": "control",
			"effects": [
				{"say": {"speaker": "zhan_lan", "text": "雇佣兵被困住了。与其跟他们走，不如赖在主机房——这里只有一道门。"}},
				{"choice": {"id": "stay_or_follow", "prompt": "留守主机房，还是跟雇佣兵走下水道？", "options": [
					{"id": "stay", "text": "留守主机房", "effects": [
						{"set_flag": "stay_control"},
						{"relation": {"kind": "advice_taken", "actor": "zheng_zha", "target": "zhan_lan"}},
						{"say": {"speaker": "matthew", "text": "你们留下。卡普兰，把门锁死。"}}
					]},
					{"id": "follow", "text": "跟雇佣兵走下水道", "effects": [
						{"set_flag": "went_sewer"},
						{"relation": {"kind": "advice_ignored", "actor": "zheng_zha", "target": "zhan_lan"}},
						{"fear": {"amount": 10}},
						{"npc_move": {"npc": "matthew", "to": "sewer"}},
						{"npc_move": {"npc": "kaplan", "to": "sewer"}},
						{"npc_move": {"npc": "ryan", "to": "sewer"}},
						{"npc_move": {"npc": "rain", "to": "sewer"}},
						{"npc_move": {"npc": "jd", "to": "sewer"}},
						{"npc_move": {"npc": "alice", "to": "sewer"}},
						{"npc_move": {"npc": "matt", "to": "sewer"}},
						{"move_members": {"members": ["zheng_zha", "zhang_jie", "zhan_lan", "li_xiao_yi", "mu_gang", "xiao_pang_zi", "zhong_nian_fu_nv"], "to": "sewer"}}
					]}
				]}}
			]
		},
		{
			"id": "sewer_dogs",
			"label": "下水道遇袭",
			"when": {"all": [{"time_at_least": 100}, {"party_at": "sewer"}]},
			"location": "sewer",
			"effects": [
				{"say": {"speaker": "rain", "text": "有东西在下面！"}},
				{"battle": {"location": "sewer", "enemies": [{"def": "zombie_dog", "count": 2, "row": 0}]}}
			]
		},
		{
			"id": "lickers_outer",
			"label": "爬行者破外门",
			"when": {"all": [{"time_at_least": 120}, {"party_at": "control"}]},
			"location": "control",
			"effects": [
				{"say": {"speaker": "kaplan", "text": "外门被撕开了！两只爬行者！"}},
				{"persuade": {"id": "threaten_queen", "npc": "red_queen", "goal": "逼火焰女皇用激光杀掉爬行者", "difficulty": 2, "requires_fact": "queen_controls_lasers", "keywords": ["威胁", "断电", "激光", "关闭"],
					"success": [
						{"set_flag": "queen_helps"},
						{"say": {"speaker": "red_queen", "text": "……执行。"}}
					],
					"failure": [
						{"battle": {"location": "control", "enemies": [{"def": "licker", "count": 2, "row": 0}]}}
					]}}
			]
		},
		{
			"id": "sewer_licker",
			"label": "爬行者堵路",
			"when": {"all": [{"time_at_least": 150}, {"party_at": "sewer"}]},
			"location": "sewer",
			"effects": [
				{"say": {"speaker": "matthew", "text": "前面有东西。准备战斗！"}},
				{"battle": {"location": "sewer", "enemies": [{"def": "licker", "count": 1, "row": 0}]}}
			]
		},
		{
			"id": "power_out",
			"label": "断电",
			"at": 160,
			"effects": [
				{"set_flag": "power_out"},
				{"say": {"speaker": "kaplan", "text": "防御系统断电了。全黑。"}},
				{"fear": {"amount": 10}}
			]
		},
		{
			"id": "lickers_inner",
			"label": "爬行者破内门",
			"when": {"all": [{"time_at_least": 170}, {"party_at": "control"}]},
			"location": "control",
			"inertia": 1,
			"effects": [
				{"battle": {"location": "control", "enemies": [{"def": "licker", "count": 2, "row": 0}]}}
			],
			"alterations": [
				{"if": {"flag": "queen_helps"}, "label": "火焰女皇的激光守住内门", "effects": [
					{"say": {"speaker": "narrator", "text": "激光闪过，两只爬行者被切成两段。"}}
				]}
			]
		},
		{
			"id": "sewer_escape",
			"label": "下水道出口",
			"when": {"all": [{"time_at_least": 175}, {"party_at": "sewer"}]},
			"location": "sewer",
			"effects": [
				{"side_plot": {"id": "sewer_escape", "grade": "D", "points": 500, "label": "从下水道生还"}},
				{"set_flag": "sewer_out"},
				{"say": {"speaker": "matthew", "text": "出口就在前面。快！"}}
			]
		}
	]
}
```

- [ ] **Step 6：改写 `game/core/expedition/scenario.gd`**

```gdscript
extends RefCounted
## 一部恐怖片的剧本数据（设计规格 5.1~5.3、8"剧本来源抽象"）：地点图、通路、剧情人物、剧情事件、手表限制。
## 手写剧本和以后主神 AI 出的题都产出这种结构。剧本是静态数据，进行中的状态在 expedition_state.gd。

const DataLoader = preload("res://core/util/data_loader.gd")
const BattleData = preload("res://core/battle/battle_data.gd")

const REQUIRED: Array[String] = ["id", "name", "start_location", "duration_minutes", "main_task", "locations", "paths", "npcs", "watch", "events"]
const EFFECT_KEYS: Array[String] = ["say", "set_flag", "npc_move", "npc_die", "open_path", "close_path", "fear", "battle", "side_plot", "bonus", "penalty", "tether_release", "end", "choice", "persuade", "give", "move_members", "damage", "set_tether", "clue", "relation", "erase", "delay", "cg", "codex"]

var data: Dictionary = {}
var id: String = ""


func _init(d: Dictionary = {}) -> void:
	data = d
	id = String(d.get("id", ""))


## 从 JSON 文件读取剧本；读不到时返回 null。
static func load_file(path: String) -> RefCounted:
	var res := DataLoader.load_json(path)
	if not res.ok:
		push_error(res.error)
		return null
	return new(res.data)


func location(loc_id: String) -> Dictionary:
	return data["locations"].get(loc_id, {})


func has_location(loc_id: String) -> bool:
	return data["locations"].has(loc_id)


static func path_key(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a


## 两地之间的通路，没有直接通路时返回空字典。
func path_between(a: String, b: String) -> Dictionary:
	for p: Dictionary in data["paths"]:
		if path_key(String(p["a"]), String(p["b"])) == path_key(a, b):
			return p
	return {}


func neighbors(loc_id: String) -> Array[String]:
	var out: Array[String] = []
	for p: Dictionary in data["paths"]:
		if p["a"] == loc_id:
			out.append(String(p["b"]))
		elif p["b"] == loc_id:
			out.append(String(p["a"]))
	return out


## 两地之间隔几段通路（不管通路开没开：百米绑定量的是实际距离）。走不到返回 -1。
func hops(a: String, b: String) -> int:
	if a == b:
		return 0
	var dist := {a: 0}
	var queue: Array[String] = [a]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for n in neighbors(cur):
			if not dist.has(n):
				dist[n] = int(dist[cur]) + 1
				if n == b:
					return int(dist[n])
				queue.append(n)
	return -1


func events() -> Array:
	return data["events"]


func validate() -> Array[String]:
	var errors: Array[String] = DataLoader.missing_keys(data, REQUIRED, "剧本")
	if not errors.is_empty():
		return errors
	if not has_location(String(data["start_location"])):
		errors.append("起点 %s 不存在" % data["start_location"])
	for p: Dictionary in data["paths"]:
		for end in [p.get("a", ""), p.get("b", "")]:
			if not has_location(String(end)):
				errors.append("通路引用了不存在的地点 %s" % end)
	for npc_id: String in data["npcs"]:
		if not has_location(String(data["npcs"][npc_id].get("location", ""))):
			errors.append("剧情人物 %s 的位置不存在" % npc_id)
	var tether: Dictionary = data["watch"].get("tether", {})
	if not tether.is_empty() and not data["npcs"].has(String(tether.get("npc", ""))):
		errors.append("百米绑定的对象不存在")
	var seen := {}
	for ev: Dictionary in data["events"]:
		var ev_id := String(ev.get("id", ""))
		if ev_id == "" or seen.has(ev_id):
			errors.append("事件 id 为空或重复：%s" % ev_id)
		seen[ev_id] = true
		if not ev.has("at") and not ev.has("when"):
			errors.append("事件 %s 既没有 at 也没有 when" % ev_id)
		_check_effects(ev_id, ev.get("effects", []), errors)
		for alt: Dictionary in ev.get("alterations", []):
			_check_effects(ev_id, alt.get("effects", []), errors)
	return errors


## 检查一组效果，连同选项、说服结果、战斗后效果里套着的效果。
func _check_effects(ev_id: String, effects: Array, errors: Array[String]) -> void:
	for e: Dictionary in effects:
		_check_effect(ev_id, e, errors)
		if e.has("choice"):
			for o: Dictionary in e["choice"].get("options", []):
				_check_effects(ev_id, o.get("effects", []), errors)
		if e.has("persuade"):
			_check_effects(ev_id, e["persuade"].get("success", []), errors)
			_check_effects(ev_id, e["persuade"].get("failure", []), errors)
		if e.has("battle"):
			_check_effects(ev_id, e["battle"].get("after_victory", []), errors)
			_check_effects(ev_id, e["battle"].get("after_defeat", []), errors)


func _check_effect(ev_id: String, e: Dictionary, errors: Array[String]) -> void:
	for k: String in e:
		if not EFFECT_KEYS.has(k):
			errors.append("事件 %s 有未知效果 %s" % [ev_id, k])
	if e.has("battle"):
		for group: Dictionary in e["battle"].get("enemies", []):
			if not BattleData.enemies().has(String(group.get("def", ""))):
				errors.append("事件 %s 引用了不存在的敌人 %s" % [ev_id, group.get("def", "")])
	if e.has("npc_move") and not has_location(String(e["npc_move"].get("to", ""))):
		errors.append("事件 %s 把人移到不存在的地点" % ev_id)
	if e.has("move_members") and not has_location(String(e["move_members"].get("to", ""))):
		errors.append("事件 %s 把队员移到不存在的地点" % ev_id)
	if e.has("choice") and (e["choice"].get("options", []) as Array).is_empty():
		errors.append("事件 %s 的选择没有选项" % ev_id)
	if e.has("clue"):
		var known := false
		for f: String in data.get("facts", {}):
			if (data["facts"][f].get("clues", {}) as Dictionary).has(String(e["clue"])):
				known = true
		if not known:
			errors.append("事件 %s 的线索 %s 不属于任何事实" % [ev_id, e["clue"]])
```

- [ ] **Step 7：改写 `game/core/expedition/plot_runner.gd`**

```gdscript
extends RefCounted
## 剧情事件（设计规格 5.2）：定时事件（at，到点发生）和条件事件（when，条件一成立就发生），每个只发生一次。
## 效果见 apply_effect。choice（等玩家选）、persuade（等说服检定）、battle（等打完）会让远征停下来等待，之后才继续。
## erase 是主神抹杀（超出百米绑定、剧本直接判定），delay 只推进时钟（地点内的耽搁，不触发定时事件）。
## relation（关系事件）和 codex（规则百科条目）只发请求事件，由 expedition.gd 落到整局状态（GameState）上。
## 剧情惯性：原剧情默认照常发生；事件的 alterations 里第一条 if 成立的改写会替代原效果，
## 剧情偏移量加上事件的惯性等级（inertia，默认 1）。偏移量可以触发连锁事件（deviation_at_least）。

const Conditions = preload("res://core/expedition/conditions.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const Watch = preload("res://core/expedition/watch.gd")


## 下一个还没发生的定时事件（时间最早的；同一时间按剧本顺序）。没有返回空字典。
static func next_timed(st: RefCounted) -> Dictionary:
	var best: Dictionary = {}
	for ev: Dictionary in st.scenario.events():
		if not ev.has("at") or st.fired.has(String(ev["id"])):
			continue
		if best.is_empty() or int(ev["at"]) < int(best["at"]):
			best = ev
	return best


static func fire(st: RefCounted, ev: Dictionary, events: Array[Dictionary]) -> void:
	var ev_id := String(ev["id"])
	var effects: Array = ev.get("effects", [])
	var mode := "original"
	for alt: Dictionary in ev.get("alterations", []):
		if Conditions.check(alt.get("if", {}), st):
			effects = alt.get("effects", [])
			mode = "altered"
			st.deviation += int(ev.get("inertia", 1))
			events.append({"type": "plot_altered", "event": ev_id, "label": String(alt.get("label", "")), "deviation": st.deviation})
			break
	st.fired[ev_id] = mode
	events.append({"type": "plot_event", "event": ev_id, "mode": mode, "clock": st.clock})
	apply_effects(st, effects, String(ev.get("location", "")), events)


## 让所有条件已经成立的条件事件发生（一个事件的效果可能让另一个的条件成立，所以反复检查）。
## 出现待打的战斗或远征结束时停下。
static func run_conditional(st: RefCounted, events: Array[Dictionary]) -> void:
	var changed := true
	while changed and st.outcome == "ongoing" and not st.is_blocked():
		changed = false
		for ev: Dictionary in st.scenario.events():
			if ev.has("when") and not st.fired.has(String(ev["id"])) and Conditions.check(ev["when"], st):
				fire(st, ev, events)
				changed = true
				break


static func apply_effects(st: RefCounted, effects: Array, location: String, events: Array[Dictionary]) -> void:
	for e: Dictionary in effects:
		apply_effect(st, e, location, events)


## 效果的收益人：数组 = 指定的人；"present" = 事件地点上的轮回者；"all" = 所有活着的轮回者。只算活着的。
static func recipients(st: RefCounted, spec: Variant, location: String) -> Array[String]:
	var out: Array[String] = []
	if spec is Array:
		for c: String in spec:
			if st.is_alive(c):
				out.append(c)
	elif String(spec) == "present":
		out = st.members_at(location)
	else:
		out = st.all_living()
	return out


static func apply_effect(st: RefCounted, e: Dictionary, location: String, events: Array[Dictionary]) -> void:
	if e.has("cg"):
		var cg: Dictionary = e["cg"]
		var cg_name := String(cg.get("name", ""))
		var cg_text := String(cg.get("text", ""))
		st.pending_cutscene = {"name": cg_name, "text": cg_text}
		events.append({"type": "cutscene", "name": cg_name, "text": cg_text})
	if e.has("say"):
		events.append({"type": "dialogue", "speaker": String(e["say"]["speaker"]), "text": String(e["say"]["text"])})
	if e.has("set_flag"):
		st.flags[String(e["set_flag"])] = e.get("value", true)
		events.append({"type": "flag_set", "flag": String(e["set_flag"])})
	if e.has("npc_move"):
		var npc_id := String(e["npc_move"]["npc"])
		st.npcs[npc_id]["location"] = String(e["npc_move"]["to"])
		events.append({"type": "npc_moved", "npc": npc_id, "to": st.npcs[npc_id]["location"]})
	if e.has("npc_die"):
		var dead := String(e["npc_die"])
		st.npcs[dead]["alive"] = false
		events.append({"type": "npc_died", "npc": dead})
		if not st.tether.is_empty() and st.tether["npc"] == dead:
			Watch.on_tether_npc_died(st, events)
	if e.has("open_path") or e.has("close_path"):
		var open := e.has("open_path")
		var ends: Array = e["open_path"] if open else e["close_path"]
		st.path_open[Scenario.path_key(String(ends[0]), String(ends[1]))] = open
		events.append({"type": "path_changed", "a": String(ends[0]), "b": String(ends[1]), "open": open})
	if e.has("fear"):
		var spec: Dictionary = e["fear"]
		var targets: Array[String] = []
		if spec.has("recipients"):
			targets = recipients(st, spec["recipients"], location)
		else:
			var where := String(spec.get("location", ""))
			targets = st.members_at(where) if where != "" else st.all_living()
		for c in targets:
			var d := Watch.add_fear(st.characters[c], float(e["fear"]["amount"]))
			events.append({"type": "fear_changed", "char": c, "amount": d, "fear": st.characters[c].fear, "reason": "plot"})
	if e.has("battle"):
		_battle(st, e["battle"], events)
	if e.has("side_plot"):
		var sp: Dictionary = e["side_plot"]
		var who := recipients(st, sp.get("recipients", "present"), location)
		for c in who:
			st.add_ledger(c, "side_plot", float(sp["points"]), String(sp["label"]), String(sp["grade"]))
		st.flags["side:" + String(sp["id"])] = true
		events.append({"type": "side_plot_done", "id": String(sp["id"]), "grade": String(sp["grade"]), "points": float(sp["points"]), "chars": who})
	if e.has("bonus"):
		var b: Dictionary = e["bonus"]
		var who := recipients(st, b.get("recipients", "present"), location)
		for c in who:
			st.add_ledger(c, "bonus", float(b["points"]), String(b["label"]))
			var attrs: Dictionary = b.get("attributes", {})
			for k: String in attrs:
				st.characters[c].attributes.add_trained(k, float(attrs[k]))
		events.append({"type": "bonus", "label": String(b["label"]), "points": float(b["points"]), "chars": who})
	if e.has("penalty"):
		var p: Dictionary = e["penalty"]
		var who := recipients(st, p.get("recipients", "present"), location)
		for c in who:
			st.add_ledger(c, "penalty", float(p["points"]), String(p["label"]))
		events.append({"type": "penalty", "label": String(p["label"]), "points": float(p["points"]), "chars": who})
	if e.has("tether_release") and not st.tether.is_empty():
		Watch.release_tether(st, events)
	if e.has("choice"):
		_choice(st, e["choice"], location, events)
	if e.has("persuade"):
		_persuade(st, e["persuade"], location, events)
	if e.has("give"):
		var g: Dictionary = e["give"]
		var who := recipients(st, g.get("recipients", "present"), location)
		for c in who:
			var ch: RefCounted = st.characters[c]
			if g.has("skill") and not ch.skills.has(String(g["skill"])):
				ch.skills.append(String(g["skill"]))
			if g.has("item"):
				ch.items[String(g["item"])] = float(ch.items.get(String(g["item"]), 0.0)) + float(g.get("count", 1))
		events.append({"type": "given", "chars": who, "skill": String(g.get("skill", "")), "item": String(g.get("item", ""))})
	if e.has("move_members"):
		var mv: Dictionary = e["move_members"]
		var sid: String = st.move_members(mv["members"], String(mv["to"]))
		if sid != "":
			events.append({"type": "members_moved", "squad": sid, "members": st.living_members(sid), "to": String(mv["to"])})
	if e.has("damage"):
		var dmg: Dictionary = e["damage"]
		for c in recipients(st, dmg.get("recipients", "present"), location):
			var ch: RefCounted = st.characters[c]
			ch.hp -= float(dmg["amount"])
			events.append({"type": "plot_damage", "char": c, "amount": float(dmg["amount"]), "hp": ch.hp})
			if ch.hp <= 0.0:
				Watch.kill(st, c, String(dmg.get("reason", "plot")), events)
	if e.has("set_tether"):
		st.tether = (e["set_tether"] as Dictionary).duplicate()
		st.tether_out.clear()
		events.append({"type": "tether_set", "npc": String(st.tether["npc"])})
		Watch.check_tether(st, 0, events)
	if e.has("clue"):
		events.append_array(st.intel.add_clue(String(e["clue"])))
	if e.has("erase"):
		var er: Dictionary = e["erase"]
		for c in recipients(st, er.get("targets", []), location):
			Watch.erase(st, c, String(er.get("reason", "plot")), events)
	if e.has("delay"):
		Watch.pass_time(st, int(e["delay"]["minutes"]), events)
	if e.has("relation"):
		# 当事人可以是轮回者，也可以是剧情人物（救下马修）。一件事有几个当事人时，旁观者只算一次。
		var rel: Dictionary = e["relation"]
		var targets: Array = rel["targets"] if rel.has("targets") else [rel["target"]]
		var witnesses: Array[String] = recipients(st, rel.get("witnesses", "present"), location)
		for t: String in targets:
			var alive: bool = st.is_alive(t) or (st.npcs.has(t) and bool(st.npcs[t]["alive"]))
			if alive:
				events.append({"type": "relation_request", "kind": String(rel["kind"]), "actor": String(rel["actor"]), "target": t, "witnesses": witnesses.duplicate()})
				witnesses.clear()
	if e.has("codex"):
		var cx: Dictionary = e["codex"]
		events.append({"type": "codex_request", "entries": (cx["ids"] as Array).duplicate(), "source": String(cx.get("source", ""))})
	if e.has("end"):
		st.outcome = String(e["end"])
		events.append({"type": "expedition_end", "outcome": st.outcome})


## 选择：记下等玩家选（expedition.choose），选项的效果在选了之后才发生；选项里还可以再套一个选择（连续的激光）。
static func _choice(st: RefCounted, spec: Dictionary, location: String, events: Array[Dictionary]) -> void:
	st.pending_choice = {"id": String(spec["id"]), "prompt": String(spec["prompt"]), "options": (spec["options"] as Array).duplicate(true), "location": String(spec.get("location", location))}
	var shown: Array = []
	for o: Dictionary in spec["options"]:
		shown.append({"id": String(o["id"]), "text": String(o["text"])})
	events.append({"type": "choice_request", "id": String(spec["id"]), "prompt": String(spec["prompt"]), "options": shown})


## 说服：记下等对话层（AI 或离线兜底）给出说服力等级，再由 expedition.resolve_persuasion 检定。
static func _persuade(st: RefCounted, spec: Dictionary, location: String, events: Array[Dictionary]) -> void:
	st.pending_check = (spec as Dictionary).duplicate(true)
	st.pending_check["location"] = String(spec.get("location", location))
	events.append({"type": "persuade_request", "id": String(spec["id"]), "npc": String(spec["npc"]), "goal": String(spec["goal"]), "difficulty": int(spec["difficulty"]), "keywords": (spec.get("keywords", []) as Array).duplicate()})


## 战斗效果：有轮回者在那个地点就发起战斗（等界面打完再回报），没人在就躲过去了。
## location 写成 "@马修的 id" 表示在那个剧情人物所在的地方打。after_victory / after_defeat 是战斗结束后才发生的效果。
static func _battle(st: RefCounted, spec: Dictionary, events: Array[Dictionary]) -> void:
	var loc := String(spec["location"])
	if loc.begins_with("@"):
		loc = String(st.npcs[loc.substr(1)]["location"])
	var here: Array[String] = st.squads_at(loc)
	if here.is_empty():
		events.append({"type": "battle_avoided", "location": loc})
		return
	var dark := Watch.is_dark(st, loc)
	st.pending_battle = {
		"location": loc,
		"squad": here[0],
		"enemies": (spec["enemies"] as Array).duplicate(true),
		"dark": dark,
		"survive_until": float(spec.get("survive_until", -1.0)),
		"after_victory": (spec.get("after_victory", []) as Array).duplicate(true),
		"after_defeat": (spec.get("after_defeat", []) as Array).duplicate(true),
	}
	events.append({"type": "battle_request", "location": loc, "squad": here[0], "dark": dark})
```

- [ ] **Step 8：改写 `game/data/scenarios/biohazard1/chapter.json`**

```json
{
	"id": "m1",
	"name": "生化危机一",
	"scenario": "res://data/scenarios/biohazard1/scenario.json",
	"roster": "res://data/characters/m1_roster.json",
	"members": ["zheng_zha", "zhang_jie", "zhan_lan", "li_xiao_yi", "mu_gang", "xiao_pang_zi", "zhong_nian_fu_nv"],
	"leader": "zheng_zha",
	"hub_tour_guide": "zhang_jie",
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

- [ ] **Step 9：改写 `game/core/campaign/campaign.gd`**

```gdscript
extends RefCounted
## 章节装配（设计规格 9、10.1）：一份章节 JSON 把剧本、人物表和开局名单拼成一次远征。
## 章节 JSON：{"id", "name", "scenario", "roster", "members"}，两个路径都是 res:// 下的 JSON。
## 可选的 "agenda"：这部片开场时主神议程的状态——{"expected_wipe": 按团灭安排, "anomalies": [{"kind", "char", "note", "reason"}],
##   "decisions": [{"kind", "payload", "reason"}]}。开局时写进 GameState.agenda（同一异常不重复记）。
## 可选的 "leader"：拍板的人（队友服从谁）；"hub_tour_guide"：回归当晚带新人认识主神空间的老手（由 Session 用）。
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
	game_state.leader = String(ch.get("leader", ""))
	var sc := Scenario.load_file(String(ch["scenario"]))
	apply_agenda(game_state, ch, sc.id)
	var ex := Expedition.new()
	ex.start(game_state, sc, members, {"rating_power": Agenda.rating_power(game_state, members)})
	return ex
```

- [ ] **Step 10：改写 `game/core/expedition/expedition.gd`**

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
## 关系网与规则百科是整局状态：剧本发出的 relation_request / codex_request 在这里落到 GameState 上；
## 打完仗活下来的人互相"并肩作战"；队友对拍板的人（GameState.leader）服从度不到 40 时，战斗里由 AI 接管。

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
const Cohesion = preload("res://core/social/cohesion.gd")

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
		units.append(UnitFactory.from_character(ch, "ally", mini(floori(i / 4.0), 2), skills, controller if obeys(c) else "ai", res))
	st.pending_battle["carrier"] = members[0] if not members.is_empty() else ""
	var n := 0
	for g: Dictionary in st.pending_battle["enemies"]:
		for k in int(g.get("count", 1)):
			n += 1
			var row := mini(int(g.get("row", 0)) + floori(k / 4.0), 2)
			units.append(UnitFactory.from_enemy(String(g["def"]), "%s_%d" % [g["def"], n], row))
	return units


## 这个人听不听拍板的人指挥。没有拍板的人、他自己就是、或者拍板的人已经死了，都算听。
func obeys(char_id: String) -> bool:
	var leader: String = game.leader
	if leader == "" or char_id == leader or not st.is_alive(leader):
		return true
	return Cohesion.obeys(game.relations, char_id, leader, _traits())


## 待打的战斗里不听指挥的人（界面提示用）。
func disobedient() -> Array[String]:
	var out: Array[String] = []
	if st.pending_battle.is_empty():
		return out
	for c: String in st.living_members(String(st.pending_battle["squad"])):
		if not obeys(c):
			out.append(c)
	return out


## 个人倾向：人物表 flags.loyalty（0~100），没写的按 50。
func _traits() -> Dictionary:
	var out := {}
	for c: String in st.roster:
		var ch: RefCounted = st.characters[c]
		if ch.flags.has("loyalty"):
			out[c] = {"loyalty": float(ch.flags["loyalty"])}
	return out


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
	var fought: Array = []
	for u: RefCounted in b.field.units:
		if u.side == "ally" and st.is_alive(u.character_id) and not fought.has(u.character_id):
			fought.append(u.character_id)
	if fought.size() >= 2:
		events.append(game.relations.bond("fought_together", fought))
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
	_state_hooks(events)
	_talent_hooks(events)
	history.append_array(events)
	return events


## 剧本对整局状态的请求：关系事件落到关系网，规则百科条目解锁。结果事件追加在后面。
func _state_hooks(events: Array[Dictionary]) -> void:
	if st == null:
		return
	var n := events.size()
	for i in n:
		var ev: Dictionary = events[i]
		match String(ev.get("type", "")):
			"relation_request":
				events.append(game.relations.apply_event(String(ev["kind"]), String(ev["actor"]), String(ev["target"]), ev["witnesses"]))
			"codex_request":
				events.append_array(game.codex.unlock(ev["entries"], String(ev["source"])))


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
## 上一部片的总评（结算界面用）：{"film", "members", "survivors", "rating_before", "rating_after", "reasons",
##   "tour_guide": 回归当晚带新人认识主神空间的人（没人带就是空）, "tour_entries": 因此解锁的规则百科条目}。
var film_report: Dictionary = {}

## 聊天能拉近关系，但只到这里；再往上要靠行动（救人、并肩作战）。
const TALK_TRUST_STEP := 2.0
const TALK_TRUST_CAP := 60.0


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
	var chapter := Campaign.load_chapter(chapter_path)
	film_report = _rate_film(chapter)
	hub = Hub.new()
	hub.start(game, REST_DAYS)
	_hub_tour(chapter)
	phase = "settlement"
	day = hub.day
	return settlement


## 主神按这部片的结果调整评价（设计规格 7.3）：本该团灭的片活下来七成以上 +1、所有人都死过清零。
## 半引导者这类异常没解除时，主神记一条"继续加压"的决定。
func _rate_film(chapter: Dictionary) -> Dictionary:
	var st: RefCounted = expedition.st
	var film: String = st.scenario.id
	var ag: Dictionary = chapter.get("agenda", {})
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


## 回归当晚：老手（章节的 hub_tour_guide）还活着，就带新人认识光球和房间，规则百科的 hub_tour 组解锁；
## 他死了就没人带，这些条目只能自己去问主神。
func _hub_tour(chapter: Dictionary) -> void:
	var guide := String(chapter.get("hub_tour_guide", ""))
	film_report["tour_guide"] = ""
	film_report["tour_entries"] = []
	if guide == "" or not game.characters.has(guide) or not game.characters[guide].alive:
		return
	var events: Array[Dictionary] = game.codex.unlock_group("hub_tour", guide)
	film_report["tour_guide"] = guide
	if not events.is_empty():
		film_report["tour_entries"] = (events[0]["entries"] as Array).duplicate()


## 跟队友聊了一次：他对拍板的人的信任 +2，最多聊到 60。对剧情人物、拍板的人自己不起作用。
## 返回 [{"type": "relation_talk", "char", "trust"}] 或空数组。
func talked(npc_id: String) -> Array[Dictionary]:
	if game == null or game.leader == "" or npc_id == game.leader or not game.characters.has(npc_id):
		return []
	var before: float = game.relations.value(npc_id, game.leader, "trust")
	if before >= TALK_TRUST_CAP:
		return []
	game.relations.change(npc_id, game.leader, {"trust": minf(TALK_TRUST_STEP, TALK_TRUST_CAP - before)})
	return [{"type": "relation_talk", "char": npc_id, "trust": game.relations.value(npc_id, game.leader, "trust")}]


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
## 规则发现：每过一段天数，活着的人里够格的智者会推出隐藏规则（rule_discovery.gd），写进规则百科。

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
	events.append_array(game.codex.discovery.discover_all(game.living_characters(), game))


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

- [ ] **Step 13：运行，确认通过**

Run: `bash game/tools/run_tests.sh > _work/p15_task2.txt 2>&1; echo "exit=$?"; tail -1 _work/p15_task2.txt; echo "SCRIPT ERROR: $(grep -c 'SCRIPT ERROR' _work/p15_task2.txt)"`

预期：`共 427 个测试，失败 0 个`、`SCRIPT ERROR: 0`。

- [ ] **Step 14：提交**

```bash
git add game/data/scenarios/biohazard1/scenario.json game/core/expedition/scenario.gd game/core/expedition/plot_runner.gd game/data/scenarios/biohazard1/chapter.json game/core/campaign/campaign.gd game/core/expedition/expedition.gd game/core/session/session.gd game/core/hub/hub.gd game/tests/unit/campaign/test_m1_content.gd game/tests/unit/session/test_session.gd game/tests/unit/hub/test_hub.gd
git commit -m "feat(social): 剧情选择改信任，信任低的队友不听指挥；规则百科随剧情、导览和规则发现解锁" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

## Task 3：队伍页、百科页与验收

**Files:**
- Modify: `game/ui/hub/hub_view.gd`、`game/ui/hub/hub_screen.gd`、`game/ui/battle/battle_view.gd`、`game/ui/event_text.gd`、`game/ui/main.gd`
- Test: `game/tests/unit/hub/test_hub_view.gd`、`game/tests/unit/ui/test_views.gd`

- [ ] **Step 1：改写 `game/tests/unit/hub/test_hub_view.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Session = preload("res://core/session/session.gd")
const HubView = preload("res://ui/hub/hub_view.gd")


func _view() -> RefCounted:
	var s := Session.new()
	s.start_m1(1)
	s.expedition.st.outcome = "returned"
	s.settle()
	s.enter_hub()
	s.hub.rest(1)
	var zz: RefCounted = s.game.characters["zheng_zha"]
	zz.points = 5000
	zz.tickets.add("D")
	return HubView.new(s)


func test_day_and_catalog() -> void:
	var v := _view()
	assert_eq(v.day_text(), "第 1 天 / 9 天")
	assert_eq(v.days_left(), 8)
	assert_eq(v.characters().size(), 7)
	var all: Array[Dictionary] = v.entries("zheng_zha")
	assert_eq(all.size(), 26)
	var qigong := {}
	for e: Dictionary in all:
		if e["id"] == "qigong_low":
			qigong = e
	assert_eq(qigong["points"], 500)
	assert_true(bool(qigong["ok"]))
	assert_eq((v.entries("zheng_zha", "item") as Array).size(), 5)


## 兑换扣点数和支线、记到 owned；再买一次会被拒。
func test_buy_exchange() -> void:
	var v := _view()
	var events: Array[Dictionary] = v.buy("zheng_zha", "qigong_low")
	assert_eq(events[0]["type"], "exchange_done")
	var zz: RefCounted = v.game.characters["zheng_zha"]
	assert_eq(zz.points, 4500)
	assert_true(zz.owned.has("qigong_low"))
	assert_true(zz.energy.has("neili"))
	var again: Array[Dictionary] = v.buy("zheng_zha", "qigong_low")
	assert_eq(again[0]["type"], "exchange_refused")
	assert_true((again[0]["reasons"] as Array).has("already_owned"))


func test_attribute_and_ticket_split() -> void:
	var v := _view()
	var zz: RefCounted = v.game.characters["zheng_zha"]
	var before: float = zz.attributes.total("muscle")
	v.buy_attribute("zheng_zha", "muscle", 10)
	assert_almost(zz.attributes.total("muscle"), before + 10.0)
	assert_eq(zz.points, 4900)
	assert_eq(zz.tickets.counts["D"], 1)
	zz.tickets.add("C")
	v.split_ticket("zheng_zha", "C")
	assert_eq(zz.tickets.counts["C"], 0)
	assert_eq(zz.tickets.counts["D"], 4)


## 修复：按伤势报价，修完回满；没伤的不在列表里。
func test_repair() -> void:
	var v := _view()
	var zz: RefCounted = v.game.characters["zheng_zha"]
	zz.hp = 30.0
	var list: Array[Dictionary] = v.repairs()
	assert_eq(list.size(), 1)
	var cost := int(list[0]["cost"])
	assert_true(cost >= 400 and cost <= 2000, str(cost))
	v.repair("zheng_zha")
	assert_almost(zz.hp, zz.hp_max())
	assert_eq(zz.points, 5000 - cost)
	assert_eq(v.repairs().size(), 0)


## 造人：第一次免费，之后 500；造物记在 game.companions。
func test_create_human() -> void:
	var v := _view()
	var events: Array[Dictionary] = v.create_human("zheng_zha", "萝丽")
	assert_eq(events[0]["type"], "human_created")
	assert_eq(events[0]["cost"], 0)
	assert_eq(v.companions().size(), 1)
	assert_eq(String(v.companions()[0]["name"]), "萝丽")
	var second: Array[Dictionary] = v.create_human("zheng_zha", "萝丽二号")
	assert_eq(second[0]["cost"], 500)


## 对练：列全部战斗技能（不挑熟练度），打一场花 1 天，会话里的天数跟着走。
func test_spar() -> void:
	var v := _view()
	var list: Array[Dictionary] = v.sparrable("zheng_zha")
	assert_true(list.size() >= 1, "至少有拳脚")
	var has_punch := false
	for t: Dictionary in list:
		if String(t["id"]) == "punch":
			has_punch = true
	assert_true(has_punch)
	var events: Array[Dictionary] = v.spar("zheng_zha", "punch")
	assert_eq(String(events[0]["type"]), "spar_done")
	assert_eq(v.session.day, 2, "对练花 1 天，session 同步")
	assert_true(float(events[0]["damage"]) > 0.0)


## 训练：熟练度低于 1 的能力才列出来；练一天涨 0.25，天数一起走。
func test_train() -> void:
	var v := _view()
	var zz: RefCounted = v.game.characters["zheng_zha"]
	zz.abilities.append("red_flame")
	zz.proficiency["red_flame"] = 0.3
	var list: Array[Dictionary] = v.trainable("zheng_zha")
	assert_eq(list.size(), 1)
	assert_eq(list[0]["id"], "red_flame")
	v.train("zheng_zha", "red_flame", 1)
	assert_almost(float(zz.proficiency["red_flame"]), 0.55)
	assert_eq(v.session.day, 2)


## 队伍页：六个队友怎么看郑吒；默认关系下都听指挥（服从 43）。
func test_team() -> void:
	var v := _view()
	var t: Dictionary = v.team()
	assert_eq(t["leader"], "郑吒")
	var rows: Array = t["rows"]
	assert_eq(rows.size(), 6)
	for r: Dictionary in rows:
		assert_almost(float(r["obedience"]), 43.0)
		assert_true(bool(r["obeys"]))
		assert_eq(String(r["stage"]), "none")


## 百科页：开场三条 + 回归当晚张杰带着认识的六条；来源显示成中文名。
func test_codex() -> void:
	var v := _view()
	var c: Dictionary = v.codex()
	var entries: Array = c["entries"]
	assert_eq(entries.size(), 9)
	assert_eq(String(entries[0]["source_name"]), "张杰")
	assert_eq(int(c["locked"]), 18 - 9)
```

- [ ] **Step 2：改写 `game/tests/unit/ui/test_views.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Session = preload("res://core/session/session.gd")
const ExpeditionView = preload("res://ui/expedition/expedition_view.gd")
const BattleView = preload("res://ui/battle/battle_view.gd")
const Character = preload("res://core/model/character.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
const Battle = preload("res://core/battle/battle.gd")
const Rng = preload("res://core/util/rng.gd")


func _view() -> RefCounted:
	var s := Session.new()
	s.start_m1(1)
	var names := {}
	for id: String in s.game.characters:
		names[id] = s.game.characters[id].display_name
	return ExpeditionView.new(s.expedition, names)


func _names(v: RefCounted) -> Dictionary:
	var out := {}
	for m: Dictionary in v.members():
		out[m["id"]] = m["name"]
	return out


## 地图：8 个地点都有坐标；起点在车厢，大厅相邻，激光通道不直接相邻。
func test_map() -> void:
	var v := _view()
	var m: Array[Dictionary] = v.map()
	assert_eq(m.size(), 8)
	var by_id := {}
	for item: Dictionary in m:
		by_id[item["id"]] = item
	assert_true(by_id["car"]["here"])
	assert_true(by_id["hall"]["adjacent"])
	assert_false(by_id["laser"]["adjacent"])
	assert_eq(by_id["control"]["pos"], Vector2(700, 280))
	assert_false(by_id["stairs"]["searched"])
	assert_true(by_id["stairs"]["dark"])


func test_watch_and_members() -> void:
	var v := _view()
	var w: Dictionary = v.watch()
	assert_eq(w["remaining_minutes"], 187)
	assert_true(String(w["main_task"]).contains("3 小时"))
	assert_eq(w["tether"], "")
	assert_eq(v.members().size(), 7)
	assert_eq(v.pending()["kind"], "choice")
	assert_eq(v.pending()["options"].size(), 3)


## 走到大厅：雇佣兵登场、绑定生效，事件流里有对话。
func test_move_and_tether() -> void:
	var v := _view()
	v.choose("listen")
	var events: Array[Dictionary] = v.move("hall")
	assert_eq(v.location(), "hall")
	assert_true(v.watch()["tether"].contains("马修"))
	var log: Array[String] = v.log_tail(12)
	assert_true("\n".join(log).contains("马修·艾迪森"))
	assert_true(events.size() > 0)
	assert_false(v.can_move("laser"))


## 战斗视图：单位卡、时间轴、行动列表、打完有结果。
func test_battle_view() -> void:
	var hero := Character.new("hero", "英雄", {})
	var units: Array[RefCounted] = [
		UnitFactory.from_character(hero, "ally", 0, ["punch"], "player"),
		UnitFactory.from_enemy("zombie", "zombie_1", 0),
	]
	var b := Battle.new()
	b.setup(units, {}, Rng.new(3))
	var bv := BattleView.new(b)
	assert_eq(bv.units().size(), 2)
	assert_eq(bv.timeline().size(), 8)
	assert_true(bv.current().has("name"))
	var acts: Array[Dictionary] = bv.actions()
	assert_true(acts.size() > 0)
	assert_true(String(acts[0]["label"]).contains("拳脚"))
	var guard := 0
	while not bv.finished() and guard < 50:
		var list: Array[Dictionary] = bv.actions()
		if list.is_empty():
			break
		bv.act(0)
		guard += 1
	assert_true(bv.finished())
	assert_true(bv.log_tail(10).size() > 0)


## 不听指挥的队友（AI 接管）在单位卡的状态里第一个标出来。
func test_battle_view_marks_disobedient() -> void:
	var hero := Character.new("hero", "英雄", {})
	var mate := Character.new("mate", "队友", {})
	var units: Array[RefCounted] = [
		UnitFactory.from_character(hero, "ally", 0, ["punch"], "player"),
		UnitFactory.from_character(mate, "ally", 0, ["punch"], "ai"),
		UnitFactory.from_enemy("zombie", "zombie_1", 0),
	]
	var b := Battle.new()
	b.setup(units, {}, Rng.new(3))
	var bv := BattleView.new(b)
	for u: Dictionary in bv.units():
		if String(u["id"]) == "mate":
			assert_eq(String((u["statuses"] as Array)[0]), "不听指挥")
		elif String(u["id"]) == "hero":
			assert_false((u["statuses"] as Array).has("不听指挥"))
```

- [ ] **Step 3：运行，确认失败**

Run: `bash game/tools/run_tests.sh | tail -3`

预期：`test_hub_view.gd` 的 `test_team` / `test_codex` 和 `test_views.gd::test_battle_view_marks_disobedient` 失败（或报 `SCRIPT ERROR`）。

- [ ] **Step 4：改写 `game/ui/hub/hub_view.gd`**

```gdscript
extends RefCounted
## 主神空间界面的取数层：兑换、属性、修复、造人、训练、休息、队伍关系、规则百科。
## 规则在 core/hub；这里只把状态整理成界面能画的东西，并把点击交回去。

const Exchange = preload("res://core/hub/exchange.gd")
const Catalog = preload("res://core/hub/catalog.gd")
const BattleData = preload("res://core/battle/battle_data.gd")
const Talents = preload("res://core/model/talents.gd")
const Cohesion = preload("res://core/social/cohesion.gd")

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


## 队伍：每个活着的队友怎么看拍板的人（信任、好感、敬畏、怨恨）、服从度、听不听指挥、冲突到了哪一级。
## 返回 {"leader": 名字, "cohesion": 全队凝聚力, "rows": [...]}；没有拍板的人时 rows 为空。
func team() -> Dictionary:
	var leader: String = game.leader
	var living: Array = []
	for id: String in game.characters:
		if game.characters[id].alive:
			living.append(id)
	var out := {"leader": "", "cohesion": Cohesion.cohesion(game.relations, living), "rows": []}
	if leader == "" or not game.characters.has(leader):
		return out
	out["leader"] = game.characters[leader].display_name
	for id: String in living:
		if id == leader:
			continue
		var rel: Dictionary = game.relations.get_rel(id, leader)
		var ob: float = Cohesion.obedience(game.relations, id, leader)
		(out["rows"] as Array).append({
			"id": id, "name": game.characters[id].display_name,
			"trust": float(rel["trust"]), "affection": float(rel["affection"]),
			"awe": float(rel["awe"]), "resentment": float(rel["resentment"]),
			"obedience": ob, "obeys": ob >= 40.0,
			"stage": Cohesion.conflict_stage(game.relations, id, leader),
		})
	return out


## 规则百科：已知条目（公开规则在前，智者发现的隐藏规则在后）和还没听说过的条数。
func codex() -> Dictionary:
	var entries: Array[Dictionary] = game.codex.entries()
	for e: Dictionary in entries:
		var src := String(e["source"])
		e["source_name"] = "主神" if src == "zhushen" else (game.characters[src].display_name if game.characters.has(src) else src)
	return {"entries": entries, "locked": game.codex.locked_count()}


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

- [ ] **Step 5：改写 `game/ui/hub/hub_screen.gd`**

```gdscript
extends Control
## 主神空间（M1 休整）：兑换、属性、修复、造人、训练、对练、队伍关系、规则百科、休息与出发。
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
	for t in [["兑换", "exchange"], ["属性", "attr"], ["修复", "repair"], ["造人", "human"], ["训练", "train"], ["对练", "spar"], ["队伍", "team"], ["百科", "codex"]]:
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
		"team": _build_team()
		"codex": _build_codex()


func _tab_of(text: String) -> String:
	var table := {"兑换": "exchange", "属性": "attr", "修复": "repair", "造人": "human", "训练": "train", "对练": "spar", "队伍": "team", "百科": "codex"}
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


## 队伍：队友怎么看拍板的人。服从度不到 40 的人，下一场战斗里不听指挥（AI 接管）。
const STAGE_NAMES := {
	"none": "相安无事", "discontent": "不满", "talk_back": "顶撞", "disobey": "抗命",
	"act_alone": "擅自行动", "hoard": "私藏", "defect": "想叛逃", "betray": "起了杀心",
}


func _build_team() -> void:
	var t: Dictionary = view.team()
	if String(t["leader"]) == "":
		content_box.add_child(UiTheme.label("这支队伍还没有拍板的人。", 19, UiTheme.MUTED))
		return
	content_box.add_child(UiTheme.label("全队凝聚力 %.0f。下面是每个人怎么看%s：服从度 = 信任×0.5 + 敬畏×0.4 + 忠诚×0.2 − 怨恨×0.5，不到 40 的人战斗里不听指挥。" % [float(t["cohesion"]), String(t["leader"])], 18, UiTheme.MUTED))
	for r: Dictionary in t["rows"]:
		var line := "%s　信任 %.0f · 好感 %.0f · 敬畏 %.0f · 怨恨 %.0f　服从 %.0f（%s）　%s" % [
			String(r["name"]), float(r["trust"]), float(r["affection"]), float(r["awe"]), float(r["resentment"]),
			float(r["obedience"]), "听指挥" if bool(r["obeys"]) else "不听指挥", String(STAGE_NAMES.get(String(r["stage"]), r["stage"]))]
		content_box.add_child(UiTheme.label(line, 19, UiTheme.TEXT if bool(r["obeys"]) else UiTheme.ACCENT2))


## 规则百科：张杰讲的、回归当晚带着认识的、问主神问出来的，加上智者自己推出来的隐藏规则。
func _build_codex() -> void:
	var c: Dictionary = view.codex()
	var entries: Array = c["entries"]
	if entries.is_empty():
		content_box.add_child(UiTheme.label("你们对主神的规则一无所知。", 19, UiTheme.MUTED))
	for e: Dictionary in entries:
		if bool(e["hidden"]):
			content_box.add_child(UiTheme.label("【隐藏规则】%s（%s 推出来的）" % [String(e["title"]), String(e["source_name"])], 20, UiTheme.ACCENT2))
		else:
			content_box.add_child(UiTheme.label("%s（%s）：%s" % [String(e["title"]), String(e["source_name"]), String(e["text"])], 19))
	if int(c["locked"]) > 0:
		content_box.add_child(UiTheme.label("还有 %d 条规则没人告诉过你们，可以去问主神。" % int(c["locked"]), 18, UiTheme.MUTED))


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
		elif String(ev["type"]) == "rule_discovered":
			text += "；%s 推出了一条隐藏规则：%s" % [view.game.characters[String(ev["by"])].display_name, String(ev["name"])]
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

- [ ] **Step 6：改写 `game/ui/battle/battle_view.gd`**

```gdscript
extends RefCounted
## 战斗界面的取数层：把 Battle 的状态整理成单位卡、时间轴和可点的行动列表。
## 界面只调用 act(index)，拿回事件；规则全在 core/battle。

const BattleData = preload("res://core/battle/battle_data.gd")
const EventText = preload("res://ui/event_text.gd")

var b: RefCounted
var names: Dictionary = {}


func _init(battle: RefCounted) -> void:
	b = battle
	for u: RefCounted in b.field.units:
		names[u.id] = u.display_name


func current() -> Dictionary:
	if b.current == null:
		return {}
	return {"id": b.current.id, "name": b.current.display_name}


func finished() -> bool:
	return b.outcome != "ongoing"


func outcome() -> String:
	return b.outcome


## 战斗目标：守门/撑时间，还是清场。
func objective() -> String:
	if b.survive_until >= 0.0:
		return "守住这里：撑到时间轴 %d（现在 %d）" % [int(b.survive_until), int(b.ctb.now)]
	return "消灭所有敌人"


## 敌人下一步想干什么；判断力越高，看到得越多（0 只知道要动，1 知道技能，2 知道目标）。
func intents() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u: RefCounted in b.field.units:
		if u.side != "enemy" or not u.in_play():
			continue
		var v: Dictionary = b.intent_view(u.id, b.intel)
		var text := "准备行动"
		if bool(v.get("known", false)):
			var kind := String(v.get("kind", ""))
			if kind == "attack" or kind == "support":
				text = String(v.get("skill_name", "攻击"))
				if v.has("targets"):
					var who: Array[String] = []
					for t in v["targets"]:
						who.append(_target_label(String(t)))
					text += " → " + "、".join(who)
			else:
				text = "换位或防御"
		out.append({"id": u.id, "name": _short_name(u.id), "text": text})
		if out.size() >= 4:
			break
	return out


func timeline() -> Array[String]:
	var out: Array[String] = []
	for id: String in b.timeline(8):
		out.append(String(names.get(id, id)))
	return out


## 战场上的单位，己方在前、敌方在后；同一边按排、再按 id 排。
func units() -> Array[Dictionary]:
	var list: Array = b.field.units.duplicate()
	list.sort_custom(func(a: RefCounted, c: RefCounted) -> bool:
		if a.side != c.side:
			return a.side == "ally"
		if a.row != c.row:
			return a.row < c.row
		return a.id < c.id)
	var out: Array[Dictionary] = []
	for u: RefCounted in list:
		var statuses := _status_names(u)
		if u.side == "ally" and u.controller == "ai":
			statuses.insert(0, "不听指挥")
		out.append({
			"id": u.id,
			"name": _short_name(u.id),
			"side": u.side,
			"row": u.row,
			"hp": u.hp,
			"hp_max": u.hp_max,
			"fear": u.fear,
			"alive": u.alive,
			"fled": u.fled,
			"current": b.current != null and b.current.id == u.id,
			"statuses": statuses,
			"ammo": int(u.resources.get("ammo", -1)),
		})
	return out


func _status_names(u: RefCounted) -> Array[String]:
	var out: Array[String] = []
	var all := BattleData.statuses()
	for s: Dictionary in u.statuses:
		var id := String(s["id"])
		out.append(String((all[id] as Dictionary).get("name", id)) if all.has(id) else id)
	return out


## 可点的行动，每项带序号；act(index) 用同一个序号。
func actions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var legal: Array[Dictionary] = b.legal_actions()
	for i in legal.size():
		out.append({"index": i, "label": _label(legal[i])})
	return out


## 同一技能对多个目标时合成一组，界面先选技能再选目标，免得二十个一样的按钮。
func groups() -> Array[Dictionary]:
	var legal: Array[Dictionary] = b.legal_actions()
	var order: Array[String] = []
	var by_key := {}
	for i in legal.size():
		var key := _group_key(legal[i])
		if not by_key.has(key):
			by_key[key] = {"key": key, "label": "", "indices": []}
			order.append(key)
		(by_key[key]["indices"] as Array).append(i)
	var out: Array[Dictionary] = []
	for key in order:
		var g: Dictionary = by_key[key]
		var idx: Array = g["indices"]
		g["label"] = _label(legal[int(idx[0])]) if idx.size() == 1 else "%s（%d 个目标）" % [_skill_name(legal[int(idx[0])]), idx.size()]
		out.append(g)
	return out


func _group_key(a: Dictionary) -> String:
	var t := String(a["type"])
	if t == "skill":
		return "skill:" + String(a["skill"])
	if t == "move":
		return "move:%d" % int(a["row"])
	return t


func _skill_name(a: Dictionary) -> String:
	var skill := String(a.get("skill", ""))
	return String(BattleData.skill(skill).get("name", skill))


func _label(a: Dictionary) -> String:
	var t := String(a["type"])
	match t:
		"skill":
			var title := _skill_name(a)
			var who: Array[String] = []
			for id: String in a.get("targets", []):
				who.append(_target_label(id))
			return "%s → %s" % [title, "、".join(who)] if not who.is_empty() else title
		"move":
			return "换到第 %d 排" % (int(a["row"]) + 1)
		"defend":
			return "防御"
		"gene_lock":
			return "开启基因锁"
		"retreat":
			return "撤退"
	return t


## 只带编号的名字，给意图面板用。
func _short_name(id: String) -> String:
	var name := String(names.get(id, id))
	var tail := id.get_slice("_", id.get_slice_count("_") - 1)
	if tail.is_valid_int():
		name += "#" + tail
	return name


## 目标标签：名字后面加编号和剩余生命，十个丧尸才分得清。
func _target_label(id: String) -> String:
	var name := _short_name(id)
	var tail := id.get_slice("_", id.get_slice_count("_") - 1)
	if tail.is_valid_int():
		name += "#" + tail
	var u: RefCounted = b.field.get_unit(id)
	if u != null:
		name += "（%d）" % int(u.hp)
	return name


func act(index: int) -> Array[Dictionary]:
	var legal: Array[Dictionary] = b.legal_actions()
	if index < 0 or index >= legal.size():
		return []
	return b.act(legal[index])


func log_tail(n: int = 6) -> Array[String]:
	var out: Array[String] = []
	var start := maxi(0, b.history.size() - n)
	for i in range(start, b.history.size()):
		var line := EventText.describe(b.history[i], names)
		if line != "":
			out.append(line)
	return out
```

- [ ] **Step 7：改写 `game/ui/event_text.gd`**

```gdscript
extends RefCounted
## 把 core 发出的事件翻译成一行中文，给界面的事件流和战斗日志用。
## 只负责"能看懂"，不做规则判断；认不出的事件返回空字符串（界面跳过）。

const BattleData = preload("res://core/battle/battle_data.gd")
const Codex = preload("res://core/intel/codex.gd")


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
		"relation_event":
			return "关系变化：%s（%s → %s）。" % [String(e.get("name", "")), _name(e.get("actor", ""), names), _name(e.get("target", ""), names)]
		"bonded":
			return "%s：活下来的人之间信任加深了。" % String(e.get("name", ""))
		"relation_talk":
			return "%s 对你更信任了一点（%.0f）。" % [_name(e.get("char", ""), names), float(e.get("trust", 0.0))]
		"codex_unlocked":
			var titles: Array[String] = []
			for id in e.get("entries", []):
				titles.append(String(Codex.entry(String(id)).get("title", id)))
			return "规则百科新增：%s。" % "、".join(titles)
		"rule_discovered":
			return "%s 推出了一条隐藏规则：%s。" % [_name(e.get("by", ""), names), String(e.get("name", ""))]
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

- [ ] **Step 8：改写 `game/ui/main.gd`**

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
		var guide := String(fr.get("tour_guide", ""))
		if guide != "":
			box.add_child(UiTheme.label("%s 带新人认识了光球和房间：规则百科新增 %d 条。" % [session.game.characters[guide].display_name, (fr.get("tour_entries", []) as Array).size()], 20, UiTheme.MUTED))
		else:
			box.add_child(UiTheme.label("没有老手带你们认识主神空间，规矩只能自己去问主神。", 20, UiTheme.MUTED))
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


## 说过话就涨信任；到剧本给的门槛，对方会说一句实话，可能给线索。队友还会对拍板的人多一点信任（关系网，有上限）。
func _after_said(npc_id: String, p: Control) -> void:
	var screen := _expedition_screen()
	if screen == null:
		return
	_push_events(session.talked(npc_id), p)
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
		# 问到哪条规则，规则百科就记下哪条（主神只答规则，所以按关键词判，不看 AI 怎么措辞）。
		_push_events(session.game.codex.unlock_by_question(text), p)
	)


func _zhushen_faq() -> Array:
	var res := DataLoader.load_json(ZHSHEN_FAQ)
	if not res.ok:
		return []
	return (res.data as Dictionary).get("faq", [])
```

- [ ] **Step 9：在改名的副本里跑切片验收**

```bash
rm -rf _work/p15_verify && mkdir -p _work/p15_verify && cp -r game _work/p15_verify/game
sed -i 's/^config\/name=.*/config\/name="无限恐怖_验收p15"/' _work/p15_verify/game/project.godot
timeout 300 godot --headless --path _work/p15_verify/game -s res://tools/verify_m1_slice.gd 2>&1 | tail -3; echo "exit=${PIPESTATUS[0]}"
```

预期：`M1 切片验证：失败 0 项`，`exit=0`。

- [ ] **Step 10：跑全量与导入**

```bash
bash game/tools/run_tests.sh > _work/p15_run.txt 2>&1; echo "tests exit=$?"; tail -1 _work/p15_run.txt; echo "SCRIPT ERROR: $(grep -c 'SCRIPT ERROR' _work/p15_run.txt)"
godot --headless --path game --import > _work/p15_imp.txt 2>&1; echo "import exit=$?"
git status --short | sort
```

预期：`共 430 个测试，失败 0 个`、`SCRIPT ERROR: 0`、`import exit=0`；`git status` 除了界面文件和两份测试，多出 `game/core/intel/codex.gd.uid` 和 `game/tests/unit/intel/test_codex.gd.uid`。

- [ ] **Step 11：提交界面与 uid**

```bash
git add game/ui/hub/hub_view.gd game/ui/hub/hub_screen.gd game/ui/battle/battle_view.gd game/ui/event_text.gd game/ui/main.gd game/tests/unit/hub/test_hub_view.gd game/tests/unit/ui/test_views.gd game/core/intel/codex.gd.uid game/tests/unit/intel/test_codex.gd.uid
git commit -m "feat(ui): 主神空间加队伍页和百科页，战斗卡标不听指挥，问主神解锁百科" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log --oneline -1
```

- [ ] **Step 12：更新 README 进度并提交**

```bash
python -I -X utf8 - <<'EOF'
p = "README.md"
s = open(p, encoding="utf-8").read()
o = "- 计划 14（天赋觉醒与主神议程接线：七种天赋按条件觉醒、詹岚可绕过精神力门槛；张杰的半引导者异常、片后调评价、郑吒造萝丽后被复制进恶魔小队）已完成，累计 414 个无界面测试。\n"
n = o + "- 计划 15（关系网、服从与规则百科：四个剧情选择改变队友对郑吒的信任，服从度不到 40 的队友战斗里不听指挥；张杰讲规则、回归当晚导览、问主神逐步解锁 18 条规则，智者能推出隐藏规则）已完成，累计 430 个无界面测试。\n"
assert s.count(o) == 1
open(p, "w", encoding="utf-8", newline="\n").write(s.replace(o, n))
print("ok")
EOF
git add README.md
git commit -m "docs: 计划 15 完成，更新进度" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log --oneline -1
git status --short
```

- [ ] **Step 13：验收检查**

```bash
git log --oneline -6
grep -c $'\r' game/core/intel/codex.gd game/core/expedition/expedition.gd game/ui/hub/hub_screen.gd
for f in data/intel/codex.json core/intel/codex.gd core/social/relations.gd data/social/relation_events.json core/model/game_state.gd data/scenarios/biohazard1/scenario.json core/expedition/scenario.gd core/expedition/plot_runner.gd data/scenarios/biohazard1/chapter.json core/campaign/campaign.gd core/expedition/expedition.gd core/session/session.gd core/hub/hub.gd ui/hub/hub_view.gd ui/hub/hub_screen.gd ui/battle/battle_view.gd ui/event_text.gd ui/main.gd tests/unit/intel/test_codex.gd tests/unit/social/test_relations.gd tests/unit/campaign/test_m1_content.gd tests/unit/session/test_session.gd tests/unit/hub/test_hub.gd tests/unit/hub/test_hub_view.gd tests/unit/ui/test_views.gd; do cmp -s "game/$f" "_work/plan_check_p15/game/$f" || echo "DIFF $f"; done
echo "compare done"
test -z "$(git diff --name-only origin/main..HEAD | grep -iE '\.(png|jpe?g|webp|gif|wav|ogg)$')" && echo "no media"
```

预期：三个 `grep -c` 都是 `0`；`compare done` 前没有 `DIFF`；`no media`。
