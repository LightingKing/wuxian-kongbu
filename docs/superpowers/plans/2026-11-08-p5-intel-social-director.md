# 计划 5：智谋、关系与主神议程 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 做出"看不见的战力"和"人"的规则骨架：信息模型（隐藏事实、线索、带可信度的推论）、成功率显示、规则发现、关系网与凝聚力（服从、冲突升级、投票、恐惧传染、救援意愿）、计策积木与规划器、主神议程与评价变化。每一块都是能运行、能测试的机制，参数可调。

**Architecture:** 纯逻辑层（`RefCounted` + `preload`），按子系统分目录：`core/intel/`、`core/social/`、`core/strategy/`、`core/director/`，数据在 `data/` 下同名目录。所有随机都由调用方传入（roll 在 0~1 之间），方便测试。每个有状态的模块都有 `to_dict`/`load_dict`；接进总存档和界面是后续计划的事。

**Tech Stack:** Godot 4.7.2（GDScript）、bash。

**依据：** 设计规格 `docs/superpowers/specs/2026-11-05-wuxian-kongbu-game-design.md`（v0.9）第 3.8、5.5、7.3、7.4 节；核心机制分析第 1.3~1.4、2.2、8.2、9.3~9.4 节。

**本计划的全部代码都已在临时目录里实际跑通（加上前四个计划的 214 个，共 257 个测试全部通过），照抄即可。**

**执行环境注意：**
- 仓库根目录：Windows 上是 `I:\workspace\mobilegame\wuxian-kongbu\`；在 WSL 的 bash 里是 `/mnt/i/workspace/mobilegame/wuxian-kongbu`。所有命令都在仓库根目录执行。
- 只跑某个测试文件时用 `WSLENV=TEST_FILTER TEST_FILTER=<文件名> bash game/tools/run_tests.sh`。
- 所有文本文件用 **LF** 换行、UTF-8 无 BOM；GDScript 代码块用 **Tab** 缩进，照抄时保留 Tab。
- **"确认失败"那一步**：被测文件还不存在，输出里除了 `FAIL  ...（脚本无法加载）`，前面还会有几行 `SCRIPT ERROR: Parse Error: ...`，最后是 `!! 检测到脚本错误`。这都是预期的。
- 跑测试不会生成 `.gd.uid` 文件，导入工程（Task 6）才会。Task 6 把这些文件一起提交。
- **只提交，不推送。**

---

## 设计要点

- **信息模型**（`intel_state.gd`）：每条隐藏事实有四种状态：未知 → 有线索 → 有推论（带可信度）→ 已确认。推理准确度 = 0.3 + (智力 − 100)/400 + 线索 × 0.4 + 领域熟悉度 × 0.2 + 天才 0.1 − 难度 × 0.3（限制在 0.05~0.97）。roll 落在准确度之外就得出相反的结论——推论可能是错的。两个智者结论一致，可信度叠加 1 − (1 − c1)(1 − c2)；不一致，标成"有争议"，留可信度高的那个。
- **成功率显示**（`estimates.gd`）：只有队里智力 ≥ 150 时才显示；150~199 按"成"报（"约三成"），200~249 按 5% 报，250 以上按 1% 报；误差随智力缩小。
- **规则发现**（`rule_discovery.gd`）：8 条隐藏规则（造人当保镖、零件图纸绕开支线、"记录"回旧片、冷藏尸体、新人复活免费、自创技能不计评价、牺牲新人降评价、主神不给必死任务），各有发现条件（智力、天赋、剧情旗标、经历）。发现前锁着，发现后 `is_unlocked("catalog:parts_blueprints")` 之类为真，写进规则百科。
- **关系网**（`relations.gd`）：每两人之间单向的信任、好感、敬畏、怨恨（0~100，默认 50/50/20/0）和标记。10 种关系事件（救命、并肩作战、意见被采纳、展现实力、被当诱饵、分配不公、见死不救、违背承诺、"我骗你的"、杀害无辜）改变当事人和旁观者对行动者的看法。
- **凝聚力**（`cohesion.gd`）：成员两两之间"好"的平均（默认关系下 44）；服从度不到 40 的人不听指挥；冲突升级阶梯（不满 → 顶撞 → 抗命 → 擅自行动 → 私藏 → 叛逃 → 背刺）；投票过半数通过；凝聚力越低恐惧越容易传染；信任 + 好感 − 怨恨 ≥ 100 才愿意冒险救人。
- **规划器**（`planner.gd`）：12 块计策积木。智力决定能组合几块（100 → 1 块，150 → 2，200 → 3，250 → 4）；规划器穷举不超过人手和时间的组合，按"胜率 × 100 − 预计伤亡 × 15 − 道德代价 × 0.3"排序。胜率按平方律。每块积木带着对敌人的假设；敌人看穿时，依赖它的积木只剩代价、没有效果。实测：以弱打强（100 对 180）时不布局胜率 24%，普通人最多想到 39%，楚轩级别能找到 72% 的方案。
- **主神议程**（`agenda.gd`）：课程阶段、异常与最后通牒、潜力突升（够大就考虑复制进恶魔小队）、每个决定附带隐藏理由。评价变化：所有人都死过 → 清零、记录消失；活过本该团灭的片且幸存 ≥ 七成 → +1；队长死亡 → −1。评价战力只看兑换来的属性，看不见锻炼和基因锁；新人队伍正好 120，和计划 3 的默认值一致。

**不在本计划范围**：剧本里的隐藏事实和线索（计划 7 填 M1 的数据）；推理、规则发现在远征和休整里花时间、出现在界面（计划 7、8）；规则发现真正开放兑换页（计划 7 接进 `exchange.gd`）；AI 用人物口吻讲出计划、决定瞒不瞒（计划 6）；计划结果改写战斗初始条件（计划 7）；把这些状态接进总存档（计划 7）；团队章程、派系、卧底（M2 以后）。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `game/core/intel/intel_state.gd` | 信息模型：事实、线索、推论、确认 |
| `game/core/intel/estimates.gd` | 成功率显示的精度与口吻 |
| `game/data/intel/hidden_rules.json` | 8 条隐藏规则与发现条件 |
| `game/core/intel/rule_discovery.gd` | 规则发现与规则百科 |
| `game/data/social/relation_events.json` | 关系默认值与 10 种关系事件 |
| `game/core/social/relations.gd` | 关系网 |
| `game/core/social/cohesion.gd` | 凝聚力、服从、冲突升级、投票、恐惧传染、救援意愿 |
| `game/data/strategy/stratagems.json` | 12 块计策积木 |
| `game/core/strategy/planner.gd` | 计划评估、规划器、对弈 |
| `game/data/director/director_rules.json` | 课程阶段、评价变化、评价战力、恶魔复制阈值 |
| `game/core/director/agenda.gd` | 主神议程、评价变化、评价战力 |
| `game/tests/unit/{intel,social,strategy,director}/test_*.gd` | 各模块的测试（7 个文件，43 个测试） |

---

### Task 1：信息模型与成功率显示

**Files:**
- Create: `game/core/intel/intel_state.gd`、`game/core/intel/estimates.gd`
- Test: `game/tests/unit/intel/test_intel_state.gd`、`game/tests/unit/intel/test_estimates.gd`

- [ ] **Step 1：写测试 `game/tests/unit/intel/test_intel_state.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const IntelState = preload("res://core/intel/intel_state.gd")

## 异形一（原著）：楚轩推出存在皇后。
const FACTS := {
	"queen_exists": {"statement": "存在异形皇后", "domain": "biology", "truth": true, "difficulty": 0.5, "clues": {"egg_count": 0.5, "hive_structure": 0.5}},
	"red_queen_bluffing": {"statement": "火焰女皇在虚张声势", "domain": "computers", "truth": false, "difficulty": 0.2, "clues": {"red_queen_talk": 0.6}},
}


func _intel() -> RefCounted:
	var s := IntelState.new()
	s.load_facts(FACTS)
	return s


func _thinker(id: String, intelligence: float) -> RefCounted:
	return Character.new(id, id, {"intelligence": intelligence})


func test_status_progression() -> void:
	var s := _intel()
	assert_eq(s.status("queen_exists"), "unknown")
	var events: Array[Dictionary] = s.add_clue("egg_count")
	assert_eq(events, [{"type": "clue_found", "clue": "egg_count"}, {"type": "fact_hinted", "fact": "queen_exists"}])
	assert_eq(s.status("queen_exists"), "hinted")
	assert_almost(s.clue_weight("queen_exists"), 0.5)
	s.deduce("queen_exists", _thinker("chu_xuan", 220.0), 0.0)
	assert_eq(s.status("queen_exists"), "inferred")
	s.confirm("queen_exists")
	assert_eq(s.status("queen_exists"), "confirmed")


func test_no_clue_no_deduction() -> void:
	var s := _intel()
	assert_eq(s.deduce("queen_exists", _thinker("c", 220.0), 0.0)["reason"], "no_clues")


## 准确度随智力、线索、领域熟悉度、天赋提高，随难度降低。
func test_accuracy_formula() -> void:
	var fact: Dictionary = FACTS["queen_exists"]
	var normal := _thinker("n", 100.0)
	assert_almost(IntelState.accuracy(normal, fact, 0.5), 0.3 + 0.2 - 0.15)
	var chu := _thinker("chu_xuan", 220.0)
	chu.flags["domains"] = {"biology": 1.0}
	chu.flags["talents"] = ["genius"]
	assert_almost(IntelState.accuracy(chu, fact, 0.25), 0.3 + 0.3 + 0.1 + 0.2 + 0.1 - 0.15)
	assert_almost(IntelState.accuracy(_thinker("x", 1000.0), fact, 1.0), 0.97)


## 推论可能出错：roll 落在准确度之外时得出相反的结论。
func test_wrong_conclusion() -> void:
	var s := _intel()
	s.add_clue("red_queen_talk")
	var ev: Dictionary = s.deduce("red_queen_bluffing", _thinker("zheng_zha", 100.0), 0.99)
	assert_true(bool(ev["conclusion"]))
	var confirm: Dictionary = s.confirm("red_queen_bluffing")
	assert_false(bool(confirm["truth"]))
	assert_false(bool(confirm["inference_was_right"]))


## 两个智者结论一致：可信度叠加；不一致：有争议，留可信度高的那个。
func test_cross_check() -> void:
	var s := _intel()
	s.add_clue("egg_count")
	s.add_clue("hive_structure")
	var a: Dictionary = s.deduce("queen_exists", _thinker("chu_xuan", 200.0), 0.0)
	var c1: float = a["confidence"]
	var b: Dictionary = s.deduce("queen_exists", _thinker("xiao_honglv", 200.0), 0.0)
	assert_almost(float(b["confidence"]), 1.0 - (1.0 - c1) * (1.0 - c1))
	assert_false(bool(b["contested"]))
	var t := _intel()
	t.add_clue("egg_count")
	t.deduce("queen_exists", _thinker("weak", 100.0), 0.99)
	var strong: Dictionary = t.deduce("queen_exists", _thinker("strong", 250.0), 0.0)
	assert_true(bool(strong["contested"]))
	assert_true(bool(strong["conclusion"]))


func test_round_trip() -> void:
	var s := _intel()
	s.add_clue("egg_count")
	s.deduce("queen_exists", _thinker("c", 200.0), 0.1)
	var copy := IntelState.new()
	copy.load_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	assert_eq(copy.to_dict(), s.to_dict())
```

- [ ] **Step 2：写测试 `game/tests/unit/intel/test_estimates.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const Estimates = preload("res://core/intel/estimates.gd")


## 没有智者：看不到成功率。
func test_hidden_without_thinker() -> void:
	assert_eq(Estimates.estimate(0.3, 120.0, 0.5), {"shown": false})


## 楚轩口吻："约在三成左右"。
func test_tenths_for_moderate_intelligence() -> void:
	var e := Estimates.estimate(0.3, 180.0, 0.5)
	assert_eq(e["text"], "约三成")
	assert_almost(float(e["estimate"]), 0.3)


func test_noise_shrinks_with_intelligence() -> void:
	var low := Estimates.estimate(0.5, 150.0, 1.0)
	var high := Estimates.estimate(0.5, 260.0, 1.0)
	assert_almost(float(low["estimate"]), 0.7)
	assert_almost(float(high["estimate"]), 0.52)
	assert_eq(high["text"], "约 52%")
	assert_eq(Estimates.estimate(0.5, 220.0, 0.5)["text"], "约 50%")


func test_clamped() -> void:
	assert_almost(float(Estimates.estimate(0.98, 150.0, 1.0)["estimate"]), 1.0)
	assert_eq(Estimates.estimate(0.98, 150.0, 1.0)["text"], "约十成")


func test_best_thinker() -> void:
	var a := Character.new("a", "a", {"intelligence": 120})
	var b := Character.new("b", "b", {"intelligence": 220})
	var c := Character.new("c", "c", {"intelligence": 300})
	c.alive = false
	assert_eq(Estimates.best_thinker([a, b, c]), b)
	assert_eq(Estimates.best_thinker([]), null)
```

- [ ] **Step 3：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_intel_state bash game/tools/run_tests.sh; echo "exit=$?"`，再运行 `WSLENV=TEST_FILTER TEST_FILTER=test_estimates bash game/tools/run_tests.sh; echo "exit=$?"`

预期：两次都是对应文件 `FAIL ...（脚本无法加载）`，`!! 检测到脚本错误`，`exit=1`。

- [ ] **Step 4：创建 `game/core/intel/intel_state.gd`**

```gdscript
extends RefCounted
## 信息模型（设计规格 3.8，核心机制分析 9.3A、9.4）：每条隐藏事实对队伍有四种状态——
##   unknown（未知）→ hinted（有线索）→ inferred（有推论，带可信度）→ confirmed（已确认）。
## 智者用线索做推理，得出推论和可信度；推论可能是错的。两个智者结论一致时可信度叠加，不一致时标成"有争议"。
## 事实的定义来自剧本：{"statement", "domain", "truth", "difficulty", "clues": {线索 id: 权重}}。
## 随机数由调用方传入（roll 在 0~1 之间）。

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
## 领域熟悉度在 flags.domains 里（0~1），天才是 flags.talents 里的 "genius"。
static func accuracy(thinker: RefCounted, fact: Dictionary, clue_w: float) -> float:
	var a := 0.3
	a += (thinker.attributes.total("intelligence") - 100.0) / 400.0
	a += clue_w * 0.4
	a += float((thinker.flags.get("domains", {}) as Dictionary).get(String(fact.get("domain", "")), 0.0)) * 0.2
	if (thinker.flags.get("talents", []) as Array).has("genius"):
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

- [ ] **Step 5：创建 `game/core/intel/estimates.gd`**

```gdscript
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
```

- [ ] **Step 6：运行，确认通过**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_intel_state bash game/tools/run_tests.sh; echo "exit=$?"`，再运行 `WSLENV=TEST_FILTER TEST_FILTER=test_estimates bash game/tools/run_tests.sh; echo "exit=$?"`

预期：第一次 `共 6 个测试，失败 0 个`，第二次 `共 5 个测试，失败 0 个`，都是 `exit=0`。

- [ ] **Step 7：提交**

```bash
git add game/core/intel/intel_state.gd game/core/intel/estimates.gd game/tests/unit/intel/test_intel_state.gd game/tests/unit/intel/test_estimates.gd
git commit -m "feat(intel): 信息模型（事实、线索、推论与可信度）与成功率显示" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

### Task 2：规则发现

**Files:**
- Create: `game/data/intel/hidden_rules.json`、`game/core/intel/rule_discovery.gd`
- Test: `game/tests/unit/intel/test_rule_discovery.gd`

- [ ] **Step 1：写测试 `game/tests/unit/intel/test_rule_discovery.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const GameState = preload("res://core/model/game_state.gd")
const RuleDiscovery = preload("res://core/intel/rule_discovery.gd")


func _chu_xuan() -> RefCounted:
	var c := Character.new("chu_xuan", "楚轩", {"intelligence": 220})
	c.flags["talents"] = ["genius", "tech_talent"]
	c.films_completed = 1
	return c


func test_rules_load() -> void:
	assert_eq(RuleDiscovery.rules().size(), 8)
	assert_eq(RuleDiscovery.rules()["parts_blueprints"]["unlocks"], "catalog:parts_blueprints")


## 楚轩在异形一之后的三项规则发现（设计规格 9.8）。
func test_chu_xuan_discoveries() -> void:
	var g := GameState.new(1)
	g.flags["seen_human_creation"] = true
	var d := RuleDiscovery.new()
	var events: Array[Dictionary] = d.discover_all([_chu_xuan()], g)
	var found: Array = []
	for e in events:
		found.append(e["rule"])
	assert_true(found.has("bodyguard_human"))
	assert_true(found.has("parts_blueprints"))
	assert_true(found.has("record_travel"))
	assert_false(found.has("cold_storage"))
	assert_true(d.is_unlocked("catalog:parts_blueprints"))
	assert_false(d.is_unlocked("hub:cold_storage"))


## 普通人发现不了；缺什么都列出来。
func test_unmet_conditions() -> void:
	var g := GameState.new(1)
	var zz := Character.new("zheng_zha", "郑吒", {})
	assert_eq(RuleDiscovery.unmet("bodyguard_human", zz, g), ["intelligence", "flag:seen_human_creation"] as Array[String])
	assert_eq(RuleDiscovery.unmet("parts_blueprints", zz, g), ["intelligence", "talent:tech_talent"] as Array[String])
	var d := RuleDiscovery.new()
	assert_eq(d.try_discover("record_travel", zz, g)["type"], "rule_not_found")
	assert_eq(d.discover_all([zz], g).size(), 0)


func test_discover_once_and_encyclopedia() -> void:
	var g := GameState.new(1)
	var d := RuleDiscovery.new()
	var chu := _chu_xuan()
	assert_eq(d.try_discover("record_travel", chu, g)["type"], "rule_discovered")
	assert_eq(d.try_discover("record_travel", chu, g)["type"], "rule_known")
	assert_eq(d.encyclopedia(), [{"rule": "record_travel", "name": "“记录”可以回旧片和现实", "by": "chu_xuan"}] as Array[Dictionary])


func test_dead_thinkers_discover_nothing() -> void:
	var g := GameState.new(1)
	var chu := _chu_xuan()
	chu.alive = false
	assert_eq(RuleDiscovery.new().discover_all([chu], g).size(), 0)


func test_round_trip() -> void:
	var g := GameState.new(1)
	var d := RuleDiscovery.new()
	d.try_discover("record_travel", _chu_xuan(), g)
	var copy := RuleDiscovery.new()
	copy.load_dict(JSON.parse_string(JSON.stringify(d.to_dict())))
	assert_true(copy.is_unlocked("hub:record_travel"))
```

- [ ] **Step 2：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_rule_discovery bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`FAIL  res://tests/unit/intel/test_rule_discovery.gd（脚本无法加载）`，`!! 检测到脚本错误`，`exit=1`。

- [ ] **Step 3：创建 `game/data/intel/hidden_rules.json`**

```json
{
	"version": 1,
	"rules": {
		"bodyguard_human": {
			"name": "第一个造人名额应该造保镖",
			"unlocks": "hub:bodyguard_human",
			"requires": {"intelligence_min": 180, "flags": ["seen_human_creation"]},
			"source": "L1556~1597"
		},
		"parts_blueprints": {
			"name": "零件与图纸能绕开支线门槛",
			"unlocks": "catalog:parts_blueprints",
			"requires": {"intelligence_min": 200, "talents": ["tech_talent"]},
			"source": "L1556~1597"
		},
		"record_travel": {
			"name": "“记录”可以回旧片和现实",
			"unlocks": "hub:record_travel",
			"requires": {"intelligence_min": 200, "films_completed_min": 1},
			"source": "L1556~1597"
		},
		"cold_storage": {
			"name": "冷藏尸体能省下复活费",
			"unlocks": "hub:cold_storage",
			"requires": {"intelligence_min": 180, "flags": ["knows_revival"]},
			"source": "核心机制分析 9.2"
		},
		"newbie_free_revival": {
			"name": "新人复活免费",
			"unlocks": "hub:newbie_free_revival",
			"requires": {"intelligence_min": 150, "flags": ["knows_revival"]},
			"source": "L8284、L9091"
		},
		"self_skills_unrated": {
			"name": "自创技能不计入主神评价",
			"unlocks": "info:self_skills_unrated",
			"requires": {"intelligence_min": 200, "flags": ["has_self_skill"]},
			"source": "L7866、L21838"
		},
		"sacrifice_lowers_rating": {
			"name": "牺牲新人能让评价略降",
			"unlocks": "info:sacrifice_lowers_rating",
			"requires": {"intelligence_min": 220, "films_completed_min": 3},
			"source": "核心机制分析 2.2"
		},
		"always_a_way": {
			"name": "主神不给必死的任务，一定有解",
			"unlocks": "info:always_a_way",
			"requires": {"intelligence_min": 150, "films_completed_min": 2},
			"source": "L361、L8543、L13656"
		}
	}
}
```

- [ ] **Step 4：创建 `game/core/intel/rule_discovery.gd`**

```gdscript
extends RefCounted
## 规则发现（设计规格 3.8，核心机制分析 9.3B）：引擎里有一层隐藏规则和漏洞，被智者发现之前在机制上是锁住的。
## 发现后写进规则百科，并解锁对应的东西（unlocks，例如 "catalog:parts_blueprints" 开放零件图纸页）。
## 规则定义在 data/intel/hidden_rules.json；requires 的各项都满足才能发现：
##   intelligence_min（发现者的智力）、talents（发现者的天赋）、flags（GameState.flags 里为真的旗标）、films_completed_min（发现者经历过的片数）。

const DataLoader = preload("res://core/util/data_loader.gd")

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
	var talents: Array = thinker.flags.get("talents", [])
	for t: String in req.get("talents", []):
		if not talents.has(t):
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

- [ ] **Step 5：运行，确认通过**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_rule_discovery bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`共 6 个测试，失败 0 个`，`exit=0`。

- [ ] **Step 6：提交**

```bash
git add game/data/intel/hidden_rules.json game/core/intel/rule_discovery.gd game/tests/unit/intel/test_rule_discovery.gd
git commit -m "feat(intel): 规则发现与规则百科（8 条隐藏规则）" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

### Task 3：关系网与凝聚力

**Files:**
- Create: `game/data/social/relation_events.json`、`game/core/social/relations.gd`、`game/core/social/cohesion.gd`
- Test: `game/tests/unit/social/test_relations.gd`、`game/tests/unit/social/test_cohesion.gd`

- [ ] **Step 1：写测试 `game/tests/unit/social/test_relations.gd`**

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
```

- [ ] **Step 2：写测试 `game/tests/unit/social/test_cohesion.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Relations = preload("res://core/social/relations.gd")
const Cohesion = preload("res://core/social/cohesion.gd")

const TEAM := ["zheng_zha", "zhang_jie", "zhan_lan", "newbie"]


func test_default_cohesion() -> void:
	var r := Relations.new()
	assert_almost(Cohesion.cohesion(r, TEAM), 44.0)
	assert_almost(Cohesion.cohesion(r, ["solo"]), 100.0)


func test_events_move_cohesion() -> void:
	var r := Relations.new()
	r.apply_event("saved_life", "zheng_zha", "zhan_lan", TEAM)
	var up := Cohesion.cohesion(r, TEAM)
	assert_true(up > 44.0)
	r.apply_event("left_to_die", "zhang_jie", "newbie", TEAM)
	assert_true(Cohesion.cohesion(r, TEAM) < up)


## 信任低、怨恨高的人不听指挥；忠诚能拉回一点。
func test_obedience() -> void:
	var r := Relations.new()
	assert_almost(Cohesion.obedience(r, "newbie", "zheng_zha"), 25.0 + 8.0 + 10.0)
	assert_true(Cohesion.obeys(r, "newbie", "zheng_zha"))
	r.apply_event("used_as_bait", "zheng_zha", "newbie")
	assert_false(Cohesion.obeys(r, "newbie", "zheng_zha"))
	assert_true(Cohesion.obeys(r, "newbie", "zheng_zha", {"newbie": {"loyalty": 200.0}}))


## 冲突升级阶梯：怨恨积累，从"不满"一路升到"背刺"。
func test_conflict_ladder() -> void:
	var r := Relations.new()
	assert_eq(Cohesion.conflict_stage(r, "newbie", "leader"), "none")
	r.change("newbie", "leader", {"resentment": 45, "trust": -30})
	assert_eq(Cohesion.conflict_stage(r, "newbie", "leader"), "talk_back")
	r.change("newbie", "leader", {"resentment": 60, "trust": -20})
	assert_eq(Cohesion.conflict_stage(r, "newbie", "leader"), "betray")
	assert_eq(Cohesion.conflict_stage(r, "newbie", "leader", {"newbie": {"loyalty": 150.0}}), "defect")


## 投票：信任提议人的人赞成；立场能压过信任。过半数通过。
func test_vote() -> void:
	var r := Relations.new()
	r.change("zhan_lan", "zheng_zha", {"trust": 20})
	r.change("newbie", "zheng_zha", {"trust": -20})
	var result := Cohesion.vote(r, "zheng_zha", TEAM)
	assert_eq(result["yes"], ["zheng_zha", "zhan_lan"])
	assert_eq(result["no"], ["zhang_jie", "newbie"])
	assert_false(bool(result["passed"]))
	result = Cohesion.vote(r, "zheng_zha", TEAM, {"zhang_jie": 0.5})
	assert_true(bool(result["passed"]))


func test_fear_contagion_and_rescue() -> void:
	assert_almost(Cohesion.fear_contagion(50.0), 1.0)
	assert_almost(Cohesion.fear_contagion(10.0), 1.4)
	assert_almost(Cohesion.fear_contagion(100.0), 0.5)
	var r := Relations.new()
	assert_true(Cohesion.willing_to_rescue(r, "a", "b"))
	r.change("a", "b", {"resentment": 10})
	assert_false(Cohesion.willing_to_rescue(r, "a", "b"))
```

- [ ] **Step 3：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_relations bash game/tools/run_tests.sh; echo "exit=$?"`，再运行 `WSLENV=TEST_FILTER TEST_FILTER=test_cohesion bash game/tools/run_tests.sh; echo "exit=$?"`

预期：两次都是对应文件 `FAIL ...（脚本无法加载）`，`!! 检测到脚本错误`，`exit=1`。

- [ ] **Step 4：创建 `game/data/social/relation_events.json`**

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
		"killed_innocent": {"name": "杀害无辜", "witness_to_actor": {"trust": -10, "affection": -5, "awe": 5}}
	}
}
```

- [ ] **Step 5：创建 `game/core/social/relations.gd`**

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


func to_dict() -> Dictionary:
	return {"pairs": pairs.duplicate(true)}


func load_dict(d: Dictionary) -> void:
	pairs = (d["pairs"] as Dictionary).duplicate(true)
```

- [ ] **Step 6：创建 `game/core/social/cohesion.gd`**

```gdscript
extends RefCounted
## 凝聚力及其作用（设计规格 7.4，核心机制分析 8.2）：服从、冲突升级、投票、恐惧传染、救援意愿。
## 全部从关系网（relations.gd）算出来；个人倾向（忠诚等，0~100）放在 traits：角色 id → {"loyalty": ...}，没有就按 50。

## 冲突升级阶梯：不满 → 顶撞 → 抗命 → 擅自行动 → 私藏或偷窃 → 叛逃或转队 → 背刺谋杀。
const STAGES: Array[String] = ["none", "discontent", "talk_back", "disobey", "act_alone", "hoard", "defect", "betray"]
const STAGE_THRESHOLDS: Array[float] = [20.0, 35.0, 50.0, 60.0, 70.0, 80.0, 90.0]


## 一个人对另一个人的"好"：信任 × 0.5 + 好感 × 0.3 + 敬畏 × 0.2 − 怨恨 × 0.5。
static func regard(rel: RefCounted, a: String, b: String) -> float:
	return rel.value(a, b, "trust") * 0.5 + rel.value(a, b, "affection") * 0.3 + rel.value(a, b, "awe") * 0.2 - rel.value(a, b, "resentment") * 0.5


## 团队凝聚力（0~100）：所有有序成员对的"好"的平均。默认关系下是 44。
static func cohesion(rel: RefCounted, members: Array) -> float:
	var total := 0.0
	var n := 0
	for a: String in members:
		for b: String in members:
			if a != b:
				total += regard(rel, a, b)
				n += 1
	return clampf(total / float(n), 0.0, 100.0) if n > 0 else 100.0


## 服从度：信任 × 0.5 + 敬畏 × 0.4 + 忠诚 × 0.2 − 怨恨 × 0.5。不到 40 的人不听指挥（扮演整队时转为 AI 控制，可能抗命）。
static func obedience(rel: RefCounted, member: String, leader: String, traits: Dictionary = {}) -> float:
	var loyalty := float((traits.get(member, {}) as Dictionary).get("loyalty", 50.0))
	return rel.value(member, leader, "trust") * 0.5 + rel.value(member, leader, "awe") * 0.4 + loyalty * 0.2 - rel.value(member, leader, "resentment") * 0.5


static func obeys(rel: RefCounted, member: String, leader: String, traits: Dictionary = {}) -> bool:
	return obedience(rel, member, leader, traits) >= 40.0


## 冲突升级到第几级：不满值 = 怨恨 − 信任 × 0.3 + (50 − 忠诚) × 0.2，按阈值落在阶梯上。
static func conflict_stage(rel: RefCounted, member: String, leader: String, traits: Dictionary = {}) -> String:
	var loyalty := float((traits.get(member, {}) as Dictionary).get("loyalty", 50.0))
	var grievance: float = rel.value(member, leader, "resentment") - rel.value(member, leader, "trust") * 0.3 + (50.0 - loyalty) * 0.2
	var stage := 0
	for i in STAGE_THRESHOLDS.size():
		if grievance >= STAGE_THRESHOLDS[i]:
			stage = i + 1
	return STAGES[stage]


## 投票（中洲队传统）：提议人投赞成；其他人的支持度 = (对提议人的信任 − 50) / 50 + 自己的立场（−1~1），大于 0 投赞成。过半数通过。
static func vote(rel: RefCounted, proposer: String, members: Array, stance: Dictionary = {}) -> Dictionary:
	var yes: Array = [proposer]
	var no: Array = []
	for m: String in members:
		if m == proposer:
			continue
		var support: float = (rel.value(m, proposer, "trust") - 50.0) / 50.0 + float(stance.get(m, 0.0))
		if support > 0.0:
			yes.append(m)
		else:
			no.append(m)
	return {"yes": yes, "no": no, "passed": yes.size() * 2 > members.size()}


## 恐惧传染倍率：凝聚力越低，一个人崩溃越容易带垮一片（0.5~1.5）。
static func fear_contagion(cohesion_value: float) -> float:
	return clampf(1.0 + (50.0 - cohesion_value) / 100.0, 0.5, 1.5)


## AI 队友愿不愿意冒险救人：信任 + 好感 − 怨恨 ≥ 100。
static func willing_to_rescue(rel: RefCounted, rescuer: String, victim: String) -> bool:
	return rel.value(rescuer, victim, "trust") + rel.value(rescuer, victim, "affection") - rel.value(rescuer, victim, "resentment") >= 100.0
```

- [ ] **Step 7：运行，确认通过**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_relations bash game/tools/run_tests.sh; echo "exit=$?"`，再运行 `WSLENV=TEST_FILTER TEST_FILTER=test_cohesion bash game/tools/run_tests.sh; echo "exit=$?"`

预期：两次都是 `共 6 个测试，失败 0 个`，`exit=0`。

- [ ] **Step 8：提交**

```bash
git add game/data/social/relation_events.json game/core/social/relations.gd game/core/social/cohesion.gd game/tests/unit/social/test_relations.gd game/tests/unit/social/test_cohesion.gd
git commit -m "feat(social): 关系网与凝聚力（服从、冲突升级、投票、恐惧传染、救援）" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

### Task 4：计策积木与规划器

**Files:**
- Create: `game/data/strategy/stratagems.json`、`game/core/strategy/planner.gd`
- Test: `game/tests/unit/strategy/test_planner.gd`

- [ ] **Step 1：写测试 `game/tests/unit/strategy/test_planner.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Planner = preload("res://core/strategy/planner.gd")

const EVEN := {"our": 100.0, "enemy": 100.0, "people": 4, "minutes": 60, "team_size": 4}
const OUTMATCHED := {"our": 100.0, "enemy": 180.0, "people": 4, "minutes": 90, "team_size": 4}


func test_stratagems_load() -> void:
	assert_eq(Planner.stratagems().size(), 12)
	assert_eq(Planner.stratagems()["bait"]["name"], "诱饵")


func test_depth_by_intelligence() -> void:
	assert_eq(Planner.depth_for(100.0), 1)
	assert_eq(Planner.depth_for(150.0), 2)
	assert_eq(Planner.depth_for(220.0), 3)
	assert_eq(Planner.depth_for(400.0), 4)


func test_baseline_even_fight() -> void:
	var p := Planner.evaluate([], EVEN)
	assert_almost(float(p["success"]), 0.5)
	assert_almost(float(p["casualties"]), 1.0)


## 伏击：先手 + 加成；诱饵：先手，但担任诱饵的人风险高，还扣信任。
func test_block_effects() -> void:
	var ambush := Planner.evaluate(["ambush"], EVEN)
	var our := 100.0 * 1.2 * 1.15
	assert_almost(float(ambush["success"]), our * our / (our * our + 10000.0))
	var bait := Planner.evaluate(["bait"], EVEN)
	assert_almost(float(bait["trust_cost"]), 25.0)
	assert_true(float(bait["casualties"]) > 0.4)
	assert_eq(bait["assumes"], ["enemy_takes_bait"])


## 计划不超过可分派的人手和时间。
func test_limits() -> void:
	var nobody := {"our": 100.0, "enemy": 100.0, "people": 0, "minutes": 60, "team_size": 1}
	for p in Planner.plan(nobody, 300.0, 50):
		assert_eq(int(p["roles"]), 0, str(p["blocks"]))
	var hurry := {"our": 100.0, "enemy": 100.0, "people": 4, "minutes": 10, "team_size": 4}
	for p in Planner.plan(hurry, 300.0, 50):
		assert_true(int(p["minutes"]) <= 10, str(p["blocks"]))


## 越聪明想得越深：更好的计划，且结果确定。
func test_smarter_finds_better_plan() -> void:
	var dull := Planner.plan(OUTMATCHED, 100.0)
	var genius := Planner.plan(OUTMATCHED, 220.0)
	assert_eq((dull[0]["blocks"] as Array).size(), 1)
	assert_true(float(genius[0]["score"]) > float(dull[0]["score"]))
	assert_true(float(genius[0]["success"]) > float(dull[0]["success"]))
	assert_eq(Planner.plan(OUTMATCHED, 220.0), genius)


## 情报欺骗要智力 180 才想得到。
func test_requires_intel() -> void:
	for p in Planner.plan(EVEN, 170.0, 200):
		assert_false((p["blocks"] as Array).has("deceive"))


## 对弈：敌人看穿"知道它的行进路线"，伏击和陷阱就只剩代价。
func test_seen_through() -> void:
	var chosen := Planner.evaluate(["ambush", "trap"], OUTMATCHED)
	var real := Planner.against(chosen, OUTMATCHED, ["enemy_path_known"])
	assert_true(float(real["success"]) < float(chosen["success"]))
	assert_almost(float(real["success"]), float(Planner.evaluate([], OUTMATCHED)["success"]))
	assert_almost(float(real["trust_cost"]), float(chosen["trust_cost"]))
	assert_eq(real["minutes"], chosen["minutes"])
```

- [ ] **Step 2：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_planner bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`FAIL  res://tests/unit/strategy/test_planner.gd（脚本无法加载）`，`!! 检测到脚本错误`，`exit=1`。

- [ ] **Step 3：创建 `game/data/strategy/stratagems.json`**

```json
{
	"version": 1,
	"stratagems": {
		"bait": {"name": "诱饵", "roles": 1, "minutes": 10, "role_risk": 0.4, "first_strike": true, "trust_cost": 25, "assumes": ["enemy_takes_bait"]},
		"ambush": {"name": "伏击", "roles": 2, "minutes": 20, "role_risk": 0.05, "first_strike": true, "power_bonus": 0.2, "assumes": ["enemy_path_known"]},
		"split_forces": {"name": "分兵", "roles": 2, "minutes": 10, "role_risk": 0.1, "split": 0.3, "assumes": ["enemy_pursues"]},
		"feint": {"name": "佯攻", "roles": 1, "minutes": 10, "role_risk": 0.15, "split": 0.2, "assumes": ["enemy_reacts"]},
		"show_weakness": {"name": "示弱", "roles": 1, "minutes": 30, "role_risk": 0.1, "power_bonus": 0.15, "assumes": ["enemy_underestimates"]},
		"deceive": {"name": "情报欺骗", "roles": 0, "minutes": 30, "power_bonus": 0.1, "requires_intel": 180, "assumes": ["enemy_trusts_intel"]},
		"borrow_knife": {"name": "借刀杀人", "roles": 1, "minutes": 40, "role_risk": 0.1, "reduction": 0.3, "assumes": ["third_party_hostile"]},
		"chaos": {"name": "制造混乱", "roles": 1, "minutes": 15, "role_risk": 0.15, "enemy_morale": -0.2},
		"decapitate": {"name": "斩首", "roles": 2, "minutes": 10, "role_risk": 0.3, "reduction": 0.25, "assumes": ["leader_exposed"]},
		"retreat_route": {"name": "预设撤退路线", "roles": 0, "minutes": 15, "casualty_mult": 0.6},
		"trap": {"name": "布置陷阱", "roles": 1, "minutes": 30, "role_risk": 0.05, "reduction": 0.2, "assumes": ["enemy_path_known"]},
		"momentum": {"name": "造势", "roles": 0, "minutes": 30, "power_bonus": 0.1, "requires_intel": 160}
	}
}
```

- [ ] **Step 4：创建 `game/core/strategy/planner.gd`**

```gdscript
extends RefCounted
## 计策与规划器骨架（设计规格 3.8"布局""对弈"，核心机制分析 9.3C~D）。
## 计划由计策积木组成（data/strategy/stratagems.json）。规划器真正去搜索积木组合：智力决定能组合几块（搜索深度）。
## 局面是一个抽象模型：situation = {"our": 我方战力, "enemy": 敌方战力, "people": 能分派的人数, "minutes": 可用时间, "team_size": 队伍人数}。
## 每块积木的作用：power_bonus（我方加成）、first_strike（先手）、split（分割敌人）、reduction（削减敌人）、enemy_morale（敌方士气）、
## casualty_mult（伤亡倍率）；代价：roles（占用人数）、minutes、role_risk（担任者的死亡风险）、trust_cost（道德代价，扣信任）。
## 胜率按平方律：p = 我方有效战力² ÷ (我方² + 敌方²)。
## 每块积木带着对敌人的假设（assumes）；敌人看穿某个假设时，依赖它的积木只剩代价、没有效果。

const DataLoader = preload("res://core/util/data_loader.gd")

const PATH := "res://data/strategy/stratagems.json"

static var _cache: Dictionary = {}


static func stratagems() -> Dictionary:
	if _cache.is_empty():
		var res := DataLoader.load_json(PATH)
		assert(res.ok, res.error)
		_cache = res.data["stratagems"]
	return _cache


## 搜索深度：智力 100 只能想到一块，150 两块，200 三块，250 以上四块。
static func depth_for(intelligence: float) -> int:
	return clampi(1 + floori((intelligence - 100.0) / 50.0), 1, 4)


## 评估一组积木。broken = 被敌人看穿的假设。
static func evaluate(blocks: Array, situation: Dictionary, broken: Array = []) -> Dictionary:
	var bonus := 0.0
	var first := false
	var split := 0.0
	var reduction := 1.0
	var morale := 0.0
	var casualty_mult := 1.0
	var role_risk := 0.0
	var trust := 0.0
	var minutes := 0
	var roles := 0
	var assumes: Array = []
	for id: String in blocks:
		var s: Dictionary = stratagems()[id]
		roles += int(s.get("roles", 0))
		minutes += int(s.get("minutes", 0))
		role_risk += float(s.get("role_risk", 0.0)) * int(s.get("roles", 0))
		trust += float(s.get("trust_cost", 0.0))
		var works := true
		for a: String in s.get("assumes", []):
			if not assumes.has(a):
				assumes.append(a)
			if broken.has(a):
				works = false
		if not works:
			continue
		bonus += float(s.get("power_bonus", 0.0))
		first = first or bool(s.get("first_strike", false))
		split += float(s.get("split", 0.0))
		reduction *= 1.0 - float(s.get("reduction", 0.0))
		morale += float(s.get("enemy_morale", 0.0))
		casualty_mult *= float(s.get("casualty_mult", 1.0))
	var our := float(situation["our"]) * (1.0 + bonus) * (1.15 if first else 1.0)
	var enemy := float(situation["enemy"]) * reduction * (1.0 - minf(split, 0.5)) * maxf(0.1, 1.0 + morale)
	var p := our * our / (our * our + enemy * enemy)
	var casualties := role_risk + (1.0 - p) * float(situation.get("team_size", 1)) * 0.5 * casualty_mult
	return {
		"blocks": blocks.duplicate(),
		"success": p,
		"casualties": casualties,
		"trust_cost": trust,
		"minutes": minutes,
		"roles": roles,
		"assumes": assumes,
	}


## 计划得分：胜率 × 100 − 预计伤亡 × 15 − 道德代价 × 0.3。
static func score(plan: Dictionary) -> float:
	return float(plan["success"]) * 100.0 - float(plan["casualties"]) * 15.0 - float(plan["trust_cost"]) * 0.3


## 搜索所有不超过深度、人手和时间限制的积木组合，返回得分最高的 top 个（得分相同按积木顺序）。
static func plan(situation: Dictionary, intelligence: float, top: int = 3) -> Array[Dictionary]:
	var ids: Array[String] = []
	for id: String in stratagems():
		if float(stratagems()[id].get("requires_intel", 0.0)) <= intelligence:
			ids.append(id)
	ids.sort()
	var combos: Array[Array] = []
	_combine(ids, 0, [], depth_for(intelligence), combos)
	var plans: Array[Dictionary] = []
	for c in combos:
		var p := evaluate(c, situation)
		if int(p["roles"]) <= int(situation["people"]) and int(p["minutes"]) <= int(situation["minutes"]):
			p["score"] = score(p)
			plans.append(p)
	plans.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["score"]) > float(b["score"]))
	return plans.slice(0, top)


static func _combine(ids: Array[String], start: int, current: Array, depth: int, out: Array[Array]) -> void:
	if not current.is_empty():
		out.append(current.duplicate())
	if current.size() >= depth:
		return
	for i in range(start, ids.size()):
		current.append(ids[i])
		_combine(ids, i + 1, current, depth, out)
		current.pop_back()


## 对弈：敌人看穿了哪些假设，计划的实际胜率是多少。
static func against(chosen: Dictionary, situation: Dictionary, enemy_sees_through: Array) -> Dictionary:
	return evaluate(chosen["blocks"], situation, enemy_sees_through)
```

- [ ] **Step 5：运行，确认通过**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_planner bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`共 8 个测试，失败 0 个`，`exit=0`。

- [ ] **Step 6：提交**

```bash
git add game/data/strategy/stratagems.json game/core/strategy/planner.gd game/tests/unit/strategy/test_planner.gd
git commit -m "feat(strategy): 计策积木与规划器（智力决定搜索深度、对弈假设）" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

### Task 5：主神议程与评价

**Files:**
- Create: `game/data/director/director_rules.json`、`game/core/director/agenda.gd`
- Test: `game/tests/unit/director/test_agenda.gd`

- [ ] **Step 1：写测试 `game/tests/unit/director/test_agenda.gd`**

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

- [ ] **Step 2：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_agenda bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`FAIL  res://tests/unit/director/test_agenda.gd（脚本无法加载）`，`!! 检测到脚本错误`，`exit=1`。

- [ ] **Step 3：创建 `game/data/director/director_rules.json`**

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
	"demon_copy_spike": 0.2
}
```

- [ ] **Step 4：创建 `game/core/director/agenda.gd`**

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
## {"id", "kind", "since_film", "note", "resolved_film"}
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


func add_anomaly(kind: String, film: String, note: String, reason: String) -> String:
	var id := "anomaly_%d" % next_anomaly_no
	next_anomaly_no += 1
	anomalies.append({"id": id, "kind": kind, "since_film": film, "note": note, "resolved_film": ""})
	record(film, "add_anomaly", {"id": id, "kind": kind}, reason)
	return id


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

- [ ] **Step 5：运行，确认通过**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_agenda bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`共 6 个测试，失败 0 个`，`exit=0`。

- [ ] **Step 6：提交**

```bash
git add game/data/director/director_rules.json game/core/director/agenda.gd game/tests/unit/director/test_agenda.gd
git commit -m "feat(director): 主神议程骨架、评价变化与评价战力" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

### Task 6：全量验证与 uid 文件

- [ ] **Step 1：跑全部测试**

Run: `bash game/tools/run_tests.sh; echo "exit=$?"`

预期：结尾为 `共 257 个测试，失败 0 个`，`exit=0`，输出里没有 `SCRIPT ERROR`。

- [ ] **Step 2：导入工程**

Run: `godot --headless --path game --import; echo "exit=$?"`

预期：`exit=0`。

- [ ] **Step 3：查看新生成的 uid 文件**

Run: `git status --short`

预期：除了 `?? _work/`，正好是下面 14 行（顺序可能不同）：

```text
?? game/core/director/agenda.gd.uid
?? game/core/intel/estimates.gd.uid
?? game/core/intel/intel_state.gd.uid
?? game/core/intel/rule_discovery.gd.uid
?? game/core/social/cohesion.gd.uid
?? game/core/social/relations.gd.uid
?? game/core/strategy/planner.gd.uid
?? game/tests/unit/director/test_agenda.gd.uid
?? game/tests/unit/intel/test_estimates.gd.uid
?? game/tests/unit/intel/test_intel_state.gd.uid
?? game/tests/unit/intel/test_rule_discovery.gd.uid
?? game/tests/unit/social/test_cohesion.gd.uid
?? game/tests/unit/social/test_relations.gd.uid
?? game/tests/unit/strategy/test_planner.gd.uid
```

- [ ] **Step 4：提交 uid 文件**

```bash
git add game/core/intel/*.gd.uid game/core/social/*.gd.uid game/core/strategy/*.gd.uid game/core/director/*.gd.uid game/tests/unit/intel/*.gd.uid game/tests/unit/social/*.gd.uid game/tests/unit/strategy/*.gd.uid game/tests/unit/director/*.gd.uid
git commit -m "chore: 纳入计划 5 新脚本的 uid 文件" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
git log --oneline -7
```

预期：`git status --short` 只剩 `?? _work/`；`git log --oneline -7` 最上面 6 个是本计划的提交（Task 1~5 各一个，加上 uid 一个），第 7 个是提交本计划的 `docs: 计划 5 智谋、关系与主神议程`。**不要推送。**
