# 计划 3：远征内核 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `game/core/expedition/` 做出一部恐怖片里"地图上的那一层"：剧本数据（地点图、通路、剧情人物、剧情事件、手表限制）、全局剧情时钟、剧情惯性与改写、手表（倒计时、百米绑定、禁言、抹杀）、分队、搜索与休息、和战斗内核的对接（发起战斗、回报击杀）、一部片结束时的结算，全部有无界面测试。

**Architecture:** 和前两个计划一样是纯逻辑层（`RefCounted` + `preload`）。剧本是静态数据（`scenario.gd`，手写剧本和以后主神 AI 出的题都产出这种结构）；进行中的状态单独放在 `expedition_state.gd`，能存读档。规则分三块：`watch.gd` 管时间流逝带来的东西（倒计时、黑暗、绑定、抹杀、禁言），`plot_runner.gd` 管剧情事件和效果，`expedition.gd` 是对外的控制器。战斗由界面用计划 2 的 `battle.gd` 去打，打完把战斗对象交回来，`battle_report.gd` 从事件记录里整理出击杀，计划 2 的代码不用改。

**Tech Stack:** Godot 4.7.2（GDScript）、bash。

**依据：** 设计规格 `docs/superpowers/specs/2026-11-05-wuxian-kongbu-game-design.md`（v0.8）第 5、8、9.3、10.2 节；核心机制分析第 1.3、2.2 节；计划 1 的 `settlement.gd`、`kill_reward.gd`、`game_state.gd`；计划 2 的 `battle.gd`、`unit_factory.gd`、`battle_data.gd`。

**本计划的全部代码都已在临时目录里实际跑通（加上前两个计划的 119 个，共 178 个测试全部通过），照抄即可。**

**执行环境注意：**
- 仓库根目录：Windows 上是 `I:\workspace\mobilegame\wuxian-kongbu\`；在 WSL 的 bash 里是 `/mnt/i/workspace/mobilegame/wuxian-kongbu`。所有命令都在仓库根目录执行。
- 只跑某个测试文件时用 `WSLENV=TEST_FILTER TEST_FILTER=<文件名> bash game/tools/run_tests.sh`。`TEST_FILTER` 按路径子串匹配，所以控制器测试写成 `test_expedition.gd`（带扩展名），免得把 `test_expedition_state.gd` 等也匹配进来。
- 所有文本文件用 **LF** 换行、UTF-8 无 BOM；GDScript 代码块用 **Tab** 缩进，照抄时保留 Tab。
- **"确认失败"那一步**：被测文件还不存在，输出里除了 `FAIL  ...（脚本无法加载）`，前面还会有几行 `SCRIPT ERROR: Parse Error: ...`，最后是 `!! 检测到脚本错误`。这都是预期的。
- 跑测试不会生成 `.gd.uid` 文件，导入工程（Task 7）才会。Task 7 把这些文件一起提交。
- **只提交，不推送。**

---

## 设计要点

- **剧本**（`scenario.gd`）：一个字典。`locations` 是地点（`dark` 表示黑暗，`search` 是能搜到的东西）；`paths` 是双向通路（`minutes` 是走一趟的时间，`closed` 表示默认关着）；`npcs` 是剧情人物（`plot: true` 的在场时禁言生效）；`watch` 是手表限制；`events` 是剧情事件。测试用的小剧本在 `game/tests/fixtures/mini_scenario.json`，M1 的真剧本在计划 7。
- **时间**：全局一个时钟（分钟）。任何分队的移动、搜索、休息都推进这个时钟；途中到点的定时事件依次发生。行动途中出现战斗，行动被打断（移动没到达、搜索没完成），剩下的时间作废。等待中的战斗没回报之前，其他行动都会被拒绝。
- **剧情事件**：`at` 是定时事件（到点就发生），`when` 是条件事件（条件一成立就发生），每个只发生一次。条件的写法见 `conditions.gd` 开头的注释。
- **剧情惯性**：原剧情默认照常发生。事件的 `alterations` 里第一条 `if` 成立的改写会替代原效果，剧情偏移量加上事件的惯性等级（`inertia`，默认 1）。偏移量能触发连锁事件（`deviation_at_least`），这就是"改变剧情的代价"。
- **效果**（`plot_runner.gd`）：`say`（台词）、`set_flag`、`npc_move`、`npc_die`、`open_path`/`close_path`、`fear`、`battle`（有人在那个地点才打，没人就躲过去）、`side_plot`（支线：点数 + 等级）、`bonus`、`penalty`、`tether_release`、`end`。收益人 `recipients` 可以是名单、`"present"`（事件地点上的人）或 `"all"`。
- **百米绑定**：地图上表现为"必须在绑定对象所在地点或相邻地点"（`max_hops`）。超出先警告，连续超出 `grace_minutes` 分钟以上被主神抹杀。绑定对象死亡后转移给 `transfer_to`，没有就解除。
- **禁言**：剧情人物在场时说出主神的信息，每句扣 10 点。
- **黑暗**：在黑暗地点每 10 分钟恐惧 +3（按精神力折算）。休息每 10 分钟恐惧 −5。
- **击杀奖励**：敌人数据里加了 `kill_base`（基础价）和 `threat`（威胁）。奖励 = 基础价 × min(1, 威胁 ÷ 队伍评价战力)，评价战力默认 120（普通人队伍）。原著：10 只丧尸 = 1 点，爬行者 100 点。击杀者是最后一次打中它的人。杀死新人扣 1000 点。
- **结算**：一部片结束（回归、全灭或剧本给的结局）后，活着的人：存活 1000 + 击杀（合计后向下取整）+ 支线 + 特殊奖励 + 扣分，交给计划 1 的 `settlement.gd`；点数为负被抹杀。原著锚点：郑吒第一部 6502 点 = 1000 + 5000（救下马修，B 级支线）+ 500（精神临界值突破）+ 2（击杀）。

**不在本计划范围**（后续计划处理）：支线等级随队伍强弱变化、评价战力的计算、主神出题（计划 5）；对话与说服的 AI 判定（计划 6，结果以 `apply_effects` 落地）；M1 的完整剧本（计划 7）；地点图界面（计划 8）。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `game/data/rules/expedition_rules.json` | 远征规则常量：黑暗恐惧、休息恢复、默认搜索时间、默认评价战力 |
| `game/data/battle/enemies.json`（修改） | 给丧尸、丧尸犬、爬行者加上击杀基础价和威胁值 |
| `game/tests/fixtures/mini_scenario.json` | 测试用的小剧本（照 M1 简化：车厢、大厅、楼梯井、激光通道、主机房、下水道） |
| `game/core/expedition/scenario.gd` | 剧本：加载、校验、地点与通路查询、两地相隔几段通路 |
| `game/core/expedition/expedition_state.gd` | 进行中的状态：时钟、分队、剧情人物、旗标、事件、偏移、绑定、击杀、结算条目；存读档 |
| `game/core/expedition/conditions.gd` | 剧情条件 |
| `game/core/expedition/watch.gd` | 时间流逝：倒计时、黑暗、百米绑定、抹杀、全灭、禁言、手表界面数据 |
| `game/core/expedition/plot_runner.gd` | 剧情事件、改写与偏移、效果 |
| `game/core/expedition/battle_report.gd` | 从战斗事件记录里整理击杀与伤亡 |
| `game/core/expedition/expedition_settlement.gd` | 一部片的结算并写回轮回者 |
| `game/core/expedition/expedition.gd` | 远征控制器：移动、搜索、休息、分队、禁言、效果落地、战斗对接、结算、存读档 |
| `game/tests/unit/expedition/test_*.gd` | 各模块的测试（8 个文件，59 个测试） |

---

### Task 1：远征数据与剧本

**Files:**
- Create: `game/data/rules/expedition_rules.json`、`game/tests/fixtures/mini_scenario.json`、`game/core/expedition/scenario.gd`
- Modify: `game/data/battle/enemies.json`
- Test: `game/tests/unit/expedition/test_scenario.gd`

- [ ] **Step 1：写测试 `game/tests/unit/expedition/test_scenario.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Scenario = preload("res://core/expedition/scenario.gd")
const BattleData = preload("res://core/battle/battle_data.gd")

const FIXTURE := "res://tests/fixtures/mini_scenario.json"


func test_fixture_loads_and_validates() -> void:
	var sc := Scenario.load_file(FIXTURE)
	assert_true(sc != null)
	assert_eq(sc.id, "mini_hive")
	var errors: Array[String] = sc.validate()
	assert_eq(errors.size(), 0, str(errors))


func test_path_and_neighbors() -> void:
	var sc := Scenario.load_file(FIXTURE)
	assert_eq(int(sc.path_between("hall", "car")["minutes"]), 10)
	assert_true(sc.path_between("car", "laser").is_empty())
	assert_eq(sc.neighbors("hall"), ["car", "stairs", "sewer"] as Array[String])
	assert_eq(Scenario.path_key("laser", "control"), "control|laser")


func test_hops() -> void:
	var sc := Scenario.load_file(FIXTURE)
	assert_eq(sc.hops("car", "car"), 0)
	assert_eq(sc.hops("car", "hall"), 1)
	assert_eq(sc.hops("car", "laser"), 3)
	assert_eq(sc.hops("sewer", "control"), 4)


func test_validate_catches_errors() -> void:
	var sc := Scenario.new({
		"id": "bad", "name": "坏剧本", "start_location": "nowhere", "duration_minutes": 10, "main_task": "",
		"locations": {"a": {"name": "A"}},
		"paths": [{"a": "a", "b": "b", "minutes": 5}],
		"npcs": {"x": {"name": "X", "location": "a"}},
		"watch": {"tether": {"npc": "ghost"}},
		"events": [
			{"id": "e1", "effects": [{"explode": true}]},
			{"id": "e1", "at": 0, "effects": [{"battle": {"location": "a", "enemies": [{"def": "dragon", "count": 1}]}}]},
		],
	})
	var errors := sc.validate()
	var text := "\n".join(errors)
	assert_true(text.contains("起点"), text)
	assert_true(text.contains("不存在的地点 b"), text)
	assert_true(text.contains("百米绑定"), text)
	assert_true(text.contains("既没有 at 也没有 when"), text)
	assert_true(text.contains("未知效果 explode"), text)
	assert_true(text.contains("重复"), text)
	assert_true(text.contains("dragon"), text)


func test_missing_keys() -> void:
	var errors := Scenario.new({"id": "x"}).validate()
	assert_true(errors.size() > 0)


## 敌人带着击杀基础价和威胁值（结算用，原著：10 只丧尸 = 1 点，爬行者 100 点）。
func test_enemies_have_kill_values() -> void:
	assert_almost(float(BattleData.enemy("zombie")["kill_base"]), 0.1)
	assert_almost(float(BattleData.enemy("licker")["kill_base"]), 100.0)
	assert_almost(float(BattleData.enemy("licker")["threat"]), 300.0)
```

- [ ] **Step 2：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_scenario bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`FAIL  res://tests/unit/expedition/test_scenario.gd（脚本无法加载）`，`!! 检测到脚本错误`，`exit=1`。

- [ ] **Step 3：创建 `game/data/rules/expedition_rules.json`**

```json
{
	"version": 1,
	"dark_fear_per_10_minutes": 3,
	"rest_fear_per_10_minutes": -5,
	"default_search_minutes": 10,
	"default_rating_power": 120
}
```

- [ ] **Step 4：改写 `game/data/battle/enemies.json`**（整个文件替换成下面的内容：每种敌人加了 `kill_base` 和 `threat` 两行，其余不变）

```json
{
	"version": 1,
	"enemies": {
		"zombie": {
			"name": "丧尸",
			"hp": 40,
			"speed": 70,
			"attack_mult": 1.0,
			"kill_base": 0.1,
			"threat": 100,
			"skills": ["zombie_bite"],
			"ai": "wounded",
			"flags": ["fearless"],
			"fear_aura": 3
		},
		"zombie_dog": {
			"name": "丧尸犬",
			"hp": 35,
			"speed": 140,
			"attack_mult": 1.0,
			"kill_base": 1,
			"threat": 150,
			"skills": ["dog_bite"],
			"ai": "weakest",
			"flags": ["fearless"],
			"fear_aura": 5
		},
		"licker": {
			"name": "爬行者",
			"hp": 200,
			"speed": 120,
			"attack_mult": 1.0,
			"kill_base": 100,
			"threat": 300,
			"skills": ["licker_claw", "licker_tongue"],
			"ai": "threat",
			"flags": ["fearless", "ignores_darkness"],
			"tag_mult": {"bullet": 0.15},
			"initiative": 0.3,
			"fear_aura": 15
		}
	}
}
```

- [ ] **Step 5：创建 `game/tests/fixtures/mini_scenario.json`**

```json
{
	"id": "mini_hive",
	"name": "测试用：小蜂巢",
	"start_location": "car",
	"duration_minutes": 120,
	"main_task": "存活 2 小时",
	"locations": {
		"car": {"name": "高速车厢", "search": [{"item": "grenade", "count": 1}]},
		"hall": {"name": "蜂巢入口大厅"},
		"stairs": {"name": "楼梯井", "dark": true},
		"laser": {"name": "激光通道"},
		"control": {"name": "火焰女皇主机房", "search": [{"item": "spray", "count": 2}], "search_minutes": 20},
		"sewer": {"name": "下水道", "dark": true}
	},
	"paths": [
		{"a": "car", "b": "hall", "minutes": 10},
		{"a": "hall", "b": "stairs", "minutes": 5},
		{"a": "stairs", "b": "laser", "minutes": 5},
		{"a": "laser", "b": "control", "minutes": 5, "closed": true},
		{"a": "hall", "b": "sewer", "minutes": 15}
	],
	"npcs": {
		"matthew": {"name": "马修", "location": "car", "plot": true},
		"kaplan": {"name": "卡普兰", "location": "hall", "plot": true}
	},
	"watch": {
		"tether": {"npc": "matthew", "max_hops": 1, "grace_minutes": 10, "transfer_to": "kaplan"},
		"gag_penalty": -10
	},
	"events": [
		{
			"id": "rules_talk",
			"at": 0,
			"effects": [
				{"say": {"speaker": "zhang_jie", "text": "欢迎来到恐怖片的世界。"}},
				{"bonus": {"points": 100, "label": "讲解规则", "recipients": ["zhang_jie"]}}
			]
		},
		{
			"id": "mercs_arrive",
			"at": 10,
			"effects": [
				{"npc_move": {"npc": "matthew", "to": "hall"}},
				{"fear": {"amount": 10}}
			]
		},
		{
			"id": "laser_trap",
			"when": {"party_at": "laser"},
			"location": "laser",
			"inertia": 2,
			"effects": [
				{"fear": {"amount": 30, "location": "laser"}},
				{"battle": {"location": "laser", "enemies": [{"def": "zombie", "count": 2, "row": 0}]}}
			],
			"alterations": [
				{
					"if": {"flag": "warned_laser"},
					"label": "提前提醒，陷阱被识破",
					"effects": [
						{"open_path": ["laser", "control"]},
						{"side_plot": {"id": "save_matthew", "grade": "B", "points": 5000, "label": "救下马修", "recipients": "present"}},
						{"bonus": {"points": 500, "label": "精神临界值突破", "recipients": "present", "attributes": {"spirit": 20, "nerve_reaction": 30}}},
						{"tether_release": true}
					]
				}
			]
		},
		{
			"id": "queen_shutdown",
			"at": 60,
			"inertia": 1,
			"effects": [
				{"set_flag": "lights_out"},
				{"npc_die": "matthew"}
			],
			"alterations": [
				{"if": {"flag": "threatened_queen"}, "label": "威胁火焰女皇，断电被推迟", "effects": []}
			]
		},
		{
			"id": "lickers_early",
			"when": {"deviation_at_least": 2},
			"effects": [
				{"say": {"speaker": "narrator", "text": "剧情被改变，远处传来爬行者的嘶叫。"}},
				{"set_flag": "lickers_early"}
			]
		}
	]
}
```

- [ ] **Step 6：创建 `game/core/expedition/scenario.gd`**

```gdscript
extends RefCounted
## 一部恐怖片的剧本数据（设计规格 5.1~5.3、8"剧本来源抽象"）：地点图、通路、剧情人物、剧情事件、手表限制。
## 手写剧本和以后主神 AI 出的题都产出这种结构。剧本是静态数据，进行中的状态在 expedition_state.gd。

const DataLoader = preload("res://core/util/data_loader.gd")
const BattleData = preload("res://core/battle/battle_data.gd")

const REQUIRED: Array[String] = ["id", "name", "start_location", "duration_minutes", "main_task", "locations", "paths", "npcs", "watch", "events"]
const EFFECT_KEYS: Array[String] = ["say", "set_flag", "npc_move", "npc_die", "open_path", "close_path", "fear", "battle", "side_plot", "bonus", "penalty", "tether_release", "end"]

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
		var lists: Array = [ev.get("effects", [])]
		for alt: Dictionary in ev.get("alterations", []):
			lists.append(alt.get("effects", []))
		for effects: Array in lists:
			for e: Dictionary in effects:
				_check_effect(ev_id, e, errors)
	return errors


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
```

- [ ] **Step 7：运行，确认通过**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_scenario bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`共 6 个测试，失败 0 个`，`exit=0`。再跑一次战斗数据的测试，确认改了敌人数据没有影响：`WSLENV=TEST_FILTER TEST_FILTER=test_battle_data bash game/tools/run_tests.sh; echo "exit=$?"`，预期 `共 5 个测试，失败 0 个`。

- [ ] **Step 8：提交**

```bash
git add game/data/rules/expedition_rules.json game/data/battle/enemies.json game/tests/fixtures/mini_scenario.json game/core/expedition/scenario.gd game/tests/unit/expedition/test_scenario.gd
git commit -m "feat(expedition): 剧本数据与地点图，敌人加上击杀价值" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

### Task 2：远征状态与剧情条件

**Files:**
- Create: `game/core/expedition/expedition_state.gd`、`game/core/expedition/conditions.gd`
- Test: `game/tests/unit/expedition/test_expedition_state.gd`、`game/tests/unit/expedition/test_conditions.gd`

- [ ] **Step 1：写测试 `game/tests/unit/expedition/test_expedition_state.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const ExpeditionState = preload("res://core/expedition/expedition_state.gd")

const FIXTURE := "res://tests/fixtures/mini_scenario.json"


func _state() -> RefCounted:
	var chars := {}
	for id in ["zheng_zha", "zhang_jie", "newbie"]:
		chars[id] = Character.new(id, id, {})
	var st := ExpeditionState.new()
	var members: Array[String] = ["zheng_zha", "zhang_jie", "newbie"]
	st.setup(Scenario.load_file(FIXTURE), chars, members)
	return st


func test_setup() -> void:
	var st := _state()
	assert_eq(st.clock, 0)
	assert_eq(st.location_of("zheng_zha"), "car")
	assert_eq(st.members_at("car").size(), 3)
	assert_true(st.party_at("car"))
	assert_eq(st.npcs["matthew"]["location"], "car")
	assert_eq(st.tether["npc"], "matthew")
	assert_true(st.is_path_open("car", "hall"))
	assert_false(st.is_path_open("control", "laser"))


func test_split_and_merge() -> void:
	var st := _state()
	var group: Array[String] = ["newbie"]
	var sid: String = st.split("s1", group)
	assert_eq(sid, "s2")
	assert_eq(st.squad_of("newbie"), "s2")
	assert_eq(st.living_members("s1"), ["zheng_zha", "zhang_jie"] as Array[String])
	st.squads["s2"]["items"]["grenade"] = 1.0
	st.squads["s2"]["location"] = "hall"
	assert_false(st.merge("s1", "s2"))
	st.squads["s2"]["location"] = "car"
	assert_true(st.merge("s1", "s2"))
	assert_false(st.squads.has("s2"))
	assert_eq(st.living_members("s1").size(), 3)
	assert_almost(float(st.squads["s1"]["items"]["grenade"]), 1.0)


func test_split_rejects_bad_input() -> void:
	var st := _state()
	var everyone: Array[String] = ["zheng_zha", "zhang_jie", "newbie"]
	var stranger: Array[String] = ["alice"]
	var none: Array[String] = []
	assert_eq(st.split("s1", everyone), "")
	assert_eq(st.split("s1", stranger), "")
	assert_eq(st.split("s1", none), "")
	assert_eq(st.split("s9", stranger), "")


func test_dead_members_filtered() -> void:
	var st := _state()
	st.characters["newbie"].alive = false
	assert_eq(st.all_living().size(), 2)
	assert_false(st.is_alive("newbie"))
	assert_eq(st.roster.size(), 3)


func test_save_round_trip() -> void:
	var st := _state()
	var group: Array[String] = ["newbie"]
	st.split("s1", group)
	st.clock = 42
	st.flags["warned_laser"] = true
	st.tether_out["newbie"] = 5
	st.kill_counts["zheng_zha"] = 3
	st.add_ledger("zheng_zha", "bonus", 500.0, "精神临界值突破")
	var text := JSON.stringify(st.to_dict())
	var parsed: Dictionary = JSON.parse_string(text)
	var copy := ExpeditionState.new()
	copy.load_dict(parsed, Scenario.load_file(FIXTURE), st.characters)
	assert_eq(copy.to_dict(), st.to_dict())
	assert_eq(copy.squad_of("newbie"), "s2")
	assert_eq(copy.tether_out["newbie"], 5)
```

- [ ] **Step 2：写测试 `game/tests/unit/expedition/test_conditions.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const ExpeditionState = preload("res://core/expedition/expedition_state.gd")
const Conditions = preload("res://core/expedition/conditions.gd")


func _state() -> RefCounted:
	var st := ExpeditionState.new()
	var members: Array[String] = ["zheng_zha"]
	st.setup(Scenario.load_file("res://tests/fixtures/mini_scenario.json"), {"zheng_zha": Character.new("zheng_zha", "郑吒", {})}, members)
	return st


func test_empty_condition_holds() -> void:
	assert_true(Conditions.check({}, _state()))


func test_flags() -> void:
	var st := _state()
	assert_false(Conditions.check({"flag": "warned_laser"}, st))
	assert_true(Conditions.check({"not_flag": "warned_laser"}, st))
	st.flags["warned_laser"] = true
	assert_true(Conditions.check({"flag": "warned_laser"}, st))


func test_time() -> void:
	var st := _state()
	st.clock = 30
	assert_true(Conditions.check({"time_at_least": 30}, st))
	assert_false(Conditions.check({"time_at_least": 31}, st))
	assert_true(Conditions.check({"time_before": 31}, st))
	assert_false(Conditions.check({"time_before": 30}, st))


func test_party_and_npcs() -> void:
	var st := _state()
	assert_true(Conditions.check({"party_at": "car"}, st))
	assert_false(Conditions.check({"party_at": "hall"}, st))
	assert_true(Conditions.check({"npc_at": {"npc": "matthew", "location": "car"}}, st))
	assert_true(Conditions.check({"npc_alive": "matthew"}, st))
	st.npcs["matthew"]["alive"] = false
	assert_true(Conditions.check({"npc_dead": "matthew"}, st))
	assert_false(Conditions.check({"npc_alive": "nobody"}, st))


## 所有项都要成立。
func test_multiple_keys_are_and() -> void:
	var st := _state()
	st.flags["a"] = true
	assert_true(Conditions.check({"flag": "a", "party_at": "car"}, st))
	assert_false(Conditions.check({"flag": "a", "party_at": "hall"}, st))


func test_combinators() -> void:
	var st := _state()
	st.deviation = 2
	assert_true(Conditions.check({"deviation_at_least": 2}, st))
	assert_true(Conditions.check({"any": [{"flag": "x"}, {"party_at": "car"}]}, st))
	assert_false(Conditions.check({"all": [{"flag": "x"}, {"party_at": "car"}]}, st))
	assert_true(Conditions.check({"not": {"flag": "x"}}, st))


func test_unknown_key_fails() -> void:
	assert_false(Conditions.check({"moon_is_full": true}, _state()))
```

- [ ] **Step 3：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_expedition_state bash game/tools/run_tests.sh; echo "exit=$?"`，再运行 `WSLENV=TEST_FILTER TEST_FILTER=test_conditions bash game/tools/run_tests.sh; echo "exit=$?"`

预期：两次都是对应文件 `FAIL ...（脚本无法加载）`，`!! 检测到脚本错误`，`exit=1`。

- [ ] **Step 4：创建 `game/core/expedition/expedition_state.gd`**

```gdscript
extends RefCounted
## 一次远征（一部恐怖片）进行中的全部状态：时钟、分队、剧情人物、剧情旗标、已触发的事件、剧情偏移、手表限制、击杀与结算条目。
## 规则由 watch.gd、plot_runner.gd、expedition.gd 实现；这里只存数据、做查询、存读档。

const Scenario = preload("res://core/expedition/scenario.gd")

var scenario: RefCounted
## 角色 id → character.gd，和 GameState 共用同一批对象。
var characters: Dictionary = {}
## 进入这部片的全部轮回者 id（结算时逐个处理，死了的也在）。
var roster: Array = []
## 全局时间（分钟）。所有分队共用一条时间线。
var clock: int = 0
## 分队 id → {"members": [角色 id], "location": 地点, "items": {道具: 数量}}
var squads: Dictionary = {}
var next_squad_no: int = 2
## 剧情人物 id → {"location": 地点, "alive": bool}
var npcs: Dictionary = {}
var flags: Dictionary = {}
## 通路是否开着，键是 Scenario.path_key。剧本里写了 closed 的通路默认关。
var path_open: Dictionary = {}
## 已触发的事件 id → "original"（按原剧情）或 "altered"（被改写）。
var fired: Dictionary = {}
## 剧情偏移量：每改写一个事件，加上它的惯性等级（设计规格 5.2）。
var deviation: int = 0
## 当前的百米绑定 {"npc", "max_hops", "grace_minutes", "transfer_to"}；空字典表示没有绑定。
var tether: Dictionary = {}
## 角色 id → 已经离开绑定范围多少分钟。
var tether_out: Dictionary = {}
var searched: Dictionary = {}
## 角色 id → 击杀点数（小数，结算时合计后向下取整）。
var kill_points: Dictionary = {}
var kill_counts: Dictionary = {}
## 结算条目：{"char", "kind", "points", "label", "grade"}，kind 同 settlement.gd。
var ledger: Array = []
## 等待界面去打的战斗；不为空时其他行动都会被拒绝。
var pending_battle: Dictionary = {}
## ongoing（进行中）、returned（倒计时结束，回归）、wiped（全员死亡）或剧本 end 效果给的结果。
var outcome: String = "ongoing"
var settled: bool = false


func setup(sc: RefCounted, chars: Dictionary, member_ids: Array[String]) -> void:
	scenario = sc
	characters = chars
	roster = member_ids.duplicate()
	squads = {"s1": {"members": member_ids.duplicate(), "location": String(sc.data["start_location"]), "items": {}}}
	for npc_id: String in sc.data["npcs"]:
		npcs[npc_id] = {"location": String(sc.data["npcs"][npc_id]["location"]), "alive": true}
	for p: Dictionary in sc.data["paths"]:
		path_open[Scenario.path_key(String(p["a"]), String(p["b"]))] = not bool(p.get("closed", false))
	tether = (sc.data["watch"].get("tether", {}) as Dictionary).duplicate()


func is_path_open(a: String, b: String) -> bool:
	return bool(path_open.get(Scenario.path_key(a, b), false))


func is_alive(char_id: String) -> bool:
	return characters.has(char_id) and characters[char_id].alive


func squad_of(char_id: String) -> String:
	for sid: String in squads:
		if (squads[sid]["members"] as Array).has(char_id):
			return sid
	return ""


func location_of(char_id: String) -> String:
	var sid := squad_of(char_id)
	return String(squads[sid]["location"]) if sid != "" else ""


func living_members(squad_id: String) -> Array[String]:
	var out: Array[String] = []
	for c: String in squads[squad_id]["members"]:
		if is_alive(c):
			out.append(c)
	return out


func all_living() -> Array[String]:
	var out: Array[String] = []
	for sid: String in squads:
		out.append_array(living_members(sid))
	return out


func squads_at(loc: String) -> Array[String]:
	var out: Array[String] = []
	for sid: String in squads:
		if squads[sid]["location"] == loc and not living_members(sid).is_empty():
			out.append(sid)
	return out


func members_at(loc: String) -> Array[String]:
	var out: Array[String] = []
	for sid in squads_at(loc):
		out.append_array(living_members(sid))
	return out


func party_at(loc: String) -> bool:
	return not squads_at(loc).is_empty()


## 分队（设计规格 5.4）：把 member_ids 从 squad_id 拆出去，成为一支新分队，返回新 id。
## 拆不出（有人不在这支队里，或者会把原队拆空）时返回空字符串。
func split(squad_id: String, member_ids: Array[String]) -> String:
	if not squads.has(squad_id) or member_ids.is_empty():
		return ""
	var members: Array = squads[squad_id]["members"]
	for c in member_ids:
		if not members.has(c):
			return ""
	if member_ids.size() >= members.size():
		return ""
	var new_id := "s%d" % next_squad_no
	next_squad_no += 1
	for c in member_ids:
		members.erase(c)
	squads[new_id] = {"members": member_ids.duplicate(), "location": squads[squad_id]["location"], "items": {}}
	return new_id


## 合队：两支分队在同一地点时，b 并入 a（成员和道具）。
func merge(a: String, b: String) -> bool:
	if a == b or not squads.has(a) or not squads.has(b) or squads[a]["location"] != squads[b]["location"]:
		return false
	(squads[a]["members"] as Array).append_array(squads[b]["members"])
	var items: Dictionary = squads[a]["items"]
	for k: String in squads[b]["items"]:
		items[k] = float(items.get(k, 0.0)) + float(squads[b]["items"][k])
	squads.erase(b)
	return true


func add_ledger(char_id: String, kind: String, points: float, label: String, grade: String = "") -> void:
	ledger.append({"char": char_id, "kind": kind, "points": points, "label": label, "grade": grade})


## 存档：不含剧本本身（按 id 另行加载）和角色（在 GameState 里）。
func to_dict() -> Dictionary:
	return {
		"scenario": scenario.id,
		"roster": roster.duplicate(),
		"clock": clock,
		"squads": squads.duplicate(true),
		"next_squad_no": next_squad_no,
		"npcs": npcs.duplicate(true),
		"flags": flags.duplicate(true),
		"path_open": path_open.duplicate(),
		"fired": fired.duplicate(),
		"deviation": deviation,
		"tether": tether.duplicate(),
		"tether_out": tether_out.duplicate(),
		"searched": searched.duplicate(),
		"kill_points": kill_points.duplicate(),
		"kill_counts": kill_counts.duplicate(),
		"ledger": ledger.duplicate(true),
		"pending_battle": pending_battle.duplicate(true),
		"outcome": outcome,
		"settled": settled,
	}


func load_dict(d: Dictionary, sc: RefCounted, chars: Dictionary) -> void:
	assert(String(d["scenario"]) == sc.id, "存档里的剧本和传入的剧本不一致")
	scenario = sc
	characters = chars
	roster = (d["roster"] as Array).duplicate()
	clock = int(d["clock"])
	squads = (d["squads"] as Dictionary).duplicate(true)
	next_squad_no = int(d["next_squad_no"])
	npcs = (d["npcs"] as Dictionary).duplicate(true)
	flags = (d["flags"] as Dictionary).duplicate(true)
	path_open = (d["path_open"] as Dictionary).duplicate()
	fired = (d["fired"] as Dictionary).duplicate()
	deviation = int(d["deviation"])
	tether = (d["tether"] as Dictionary).duplicate()
	tether_out = {}
	for c: String in d["tether_out"]:
		tether_out[c] = int(d["tether_out"][c])
	searched = (d["searched"] as Dictionary).duplicate()
	kill_points = (d["kill_points"] as Dictionary).duplicate()
	kill_counts = {}
	for c: String in d["kill_counts"]:
		kill_counts[c] = int(d["kill_counts"][c])
	ledger = (d["ledger"] as Array).duplicate(true)
	pending_battle = (d["pending_battle"] as Dictionary).duplicate(true)
	outcome = String(d["outcome"])
	settled = bool(d["settled"])
```

- [ ] **Step 5：创建 `game/core/expedition/conditions.gd`**

```gdscript
extends RefCounted
## 剧情条件（事件的 when、改写的 if）。条件是一个字典，里面每一项都成立才算成立；空字典恒成立。
##   {"flag": 名}、{"not_flag": 名}                 剧情旗标
##   {"time_at_least": 分钟}、{"time_before": 分钟}  时钟
##   {"party_at": 地点}                             有活着的轮回者在那里
##   {"npc_alive": id}、{"npc_dead": id}            剧情人物生死
##   {"npc_at": {"npc": id, "location": 地点}}
##   {"deviation_at_least": n}                      剧情偏移量（连锁事件用）
##   {"all": [条件...]}、{"any": [条件...]}、{"not": 条件}
## 不认识的键一律视为不成立，免得写错的剧本悄悄触发。


static func check(cond: Dictionary, st: RefCounted) -> bool:
	for k: String in cond:
		if not _check_one(k, cond[k], st):
			return false
	return true


static func _check_one(key: String, v: Variant, st: RefCounted) -> bool:
	match key:
		"flag":
			return bool(st.flags.get(String(v), false))
		"not_flag":
			return not bool(st.flags.get(String(v), false))
		"time_at_least":
			return st.clock >= int(v)
		"time_before":
			return st.clock < int(v)
		"party_at":
			return st.party_at(String(v))
		"npc_alive":
			return st.npcs.has(String(v)) and bool(st.npcs[String(v)]["alive"])
		"npc_dead":
			return st.npcs.has(String(v)) and not bool(st.npcs[String(v)]["alive"])
		"npc_at":
			var npc: Dictionary = st.npcs.get(String(v["npc"]), {})
			return not npc.is_empty() and npc["location"] == v["location"]
		"deviation_at_least":
			return st.deviation >= int(v)
		"all":
			for c: Dictionary in v:
				if not check(c, st):
					return false
			return true
		"any":
			for c: Dictionary in v:
				if check(c, st):
					return true
			return false
		"not":
			return not check(v, st)
	return false
```

- [ ] **Step 6：运行，确认通过**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_expedition_state bash game/tools/run_tests.sh; echo "exit=$?"`，再运行 `WSLENV=TEST_FILTER TEST_FILTER=test_conditions bash game/tools/run_tests.sh; echo "exit=$?"`

预期：第一次 `共 5 个测试，失败 0 个`，第二次 `共 7 个测试，失败 0 个`，都是 `exit=0`。

- [ ] **Step 7：提交**

```bash
git add game/core/expedition/expedition_state.gd game/core/expedition/conditions.gd game/tests/unit/expedition/test_expedition_state.gd game/tests/unit/expedition/test_conditions.gd
git commit -m "feat(expedition): 远征状态、分队与剧情条件" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

### Task 3：手表与时间流逝

**Files:**
- Create: `game/core/expedition/watch.gd`
- Test: `game/tests/unit/expedition/test_watch.gd`

- [ ] **Step 1：写测试 `game/tests/unit/expedition/test_watch.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const ExpeditionState = preload("res://core/expedition/expedition_state.gd")
const Watch = preload("res://core/expedition/watch.gd")


func _state() -> RefCounted:
	var chars := {}
	for id in ["zheng_zha", "newbie"]:
		chars[id] = Character.new(id, id, {})
	var st := ExpeditionState.new()
	var members: Array[String] = ["zheng_zha", "newbie"]
	st.setup(Scenario.load_file("res://tests/fixtures/mini_scenario.json"), chars, members)
	return st


func _types(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for e in events:
		out.append(String(e["type"]))
	return out


func test_fear_scaled_by_spirit() -> void:
	var ch := Character.new("c", "c", {"spirit": 200})
	assert_almost(Watch.add_fear(ch, 20.0), 10.0)
	assert_almost(Watch.add_fear(ch, -50.0), -10.0)
	ch.fear = 95.0
	assert_almost(Watch.add_fear(ch, 20.0), 5.0)


## 黑暗中每 10 分钟恐惧 +3。
func test_darkness_raises_fear() -> void:
	var st := _state()
	st.squads["s1"]["location"] = "stairs"
	st.npcs["matthew"]["location"] = "stairs"
	var events: Array[Dictionary] = []
	Watch.pass_time(st, 20, events)
	assert_eq(st.clock, 20)
	assert_almost(st.characters["zheng_zha"].fear, 6.0)
	assert_true(_types(events).has("fear_changed"))


## 百米绑定：在绑定对象所在地点或相邻地点都可以。
func test_tether_in_range() -> void:
	var st := _state()
	st.squads["s1"]["location"] = "hall"
	var events: Array[Dictionary] = []
	Watch.pass_time(st, 30, events)
	assert_false(_types(events).has("tether_warning"))
	assert_true(st.tether_out.is_empty())


## 超出范围：先警告，连续超出 10 分钟以上被抹杀。
func test_tether_warning_then_erase() -> void:
	var st := _state()
	var group: Array[String] = ["newbie"]
	var sid: String = st.split("s1", group)
	st.squads[sid]["location"] = "stairs"
	var events: Array[Dictionary] = []
	Watch.check_tether(st, 0, events)
	assert_eq(_types(events), ["tether_warning"] as Array[String])
	events.clear()
	Watch.pass_time(st, 10, events)
	assert_true(st.is_alive("newbie"))
	Watch.pass_time(st, 1, events)
	assert_false(st.is_alive("newbie"))
	assert_eq(st.characters["newbie"].flags["erased"], "tether")
	assert_true(_types(events).has("erased"))
	assert_true(st.is_alive("zheng_zha"))


## 回到范围内，超出计时清零。
func test_tether_reset_when_back() -> void:
	var st := _state()
	st.squads["s1"]["location"] = "stairs"
	var events: Array[Dictionary] = []
	Watch.pass_time(st, 8, events)
	st.squads["s1"]["location"] = "car"
	Watch.pass_time(st, 1, events)
	assert_true(st.tether_out.is_empty())
	st.squads["s1"]["location"] = "stairs"
	Watch.pass_time(st, 8, events)
	assert_true(st.is_alive("zheng_zha"))


## 绑定对象死亡：转移给卡普兰；卡普兰也死了就解除。
func test_tether_transfer_and_release() -> void:
	var st := _state()
	var events: Array[Dictionary] = []
	st.npcs["matthew"]["alive"] = false
	Watch.on_tether_npc_died(st, events)
	assert_eq(st.tether["npc"], "kaplan")
	st.npcs["kaplan"]["alive"] = false
	Watch.on_tether_npc_died(st, events)
	assert_true(st.tether.is_empty())
	assert_eq(_types(events), ["tether_transferred", "tether_released"] as Array[String])


## 禁言：剧情人物在场时泄露主神信息，每句扣 10 点；不在场不扣。
func test_gag_penalty() -> void:
	var st := _state()
	var events: Array[Dictionary] = []
	assert_true(Watch.leak(st, "zheng_zha", events))
	assert_eq(st.ledger[0], {"char": "zheng_zha", "kind": "penalty", "points": -10.0, "label": "泄露主神信息", "grade": ""})
	st.squads["s1"]["location"] = "sewer"
	assert_false(Watch.leak(st, "zheng_zha", events))
	assert_eq(st.ledger.size(), 1)


## 倒计时结束：回归，时间不会超过时限。
func test_countdown_returns() -> void:
	var st := _state()
	var events: Array[Dictionary] = []
	Watch.pass_time(st, 115, events)
	assert_eq(st.outcome, "ongoing")
	Watch.pass_time(st, 30, events)
	assert_eq(st.clock, 120)
	assert_eq(st.outcome, "returned")
	Watch.pass_time(st, 30, events)
	assert_eq(st.clock, 120)


func test_wipe() -> void:
	var st := _state()
	var events: Array[Dictionary] = []
	Watch.erase(st, "zheng_zha", "tether", events)
	assert_eq(st.outcome, "ongoing")
	Watch.erase(st, "newbie", "tether", events)
	assert_eq(st.outcome, "wiped")


func test_view() -> void:
	var st := _state()
	st.clock = 30
	st.kill_counts["zheng_zha"] = 4
	st.kill_points["zheng_zha"] = 0.4
	var v := Watch.view(st, "zheng_zha")
	assert_eq(v["main_task"], "存活 2 小时")
	assert_eq(v["remaining_minutes"], 90)
	assert_eq(v["kills"], 4)
	assert_eq(v["constraints"][0], {"kind": "tether", "npc": "matthew", "max_hops": 1, "out_minutes": -1})
	assert_eq(v["constraints"][1], {"kind": "gag", "penalty": -10})
```

- [ ] **Step 2：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_watch bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`FAIL  res://tests/unit/expedition/test_watch.gd（脚本无法加载）`，`!! 检测到脚本错误`，`exit=1`。

- [ ] **Step 3：创建 `game/core/expedition/watch.gd`**

```gdscript
extends RefCounted
## 手表（设计规格 5.3）与时间流逝：倒计时、黑暗里的恐惧、百米绑定、禁言、抹杀。
## 百米绑定在地点图上的表现：必须在绑定对象所在地点或相邻地点（max_hops）；
## 超出时先警告，连续超出 grace_minutes 分钟以上就被主神抹杀。绑定对象死亡后转移给 transfer_to，没有就解除。

const DataLoader = preload("res://core/util/data_loader.gd")
const Rules = preload("res://core/util/rules.gd")

const RULES_PATH := "res://data/rules/expedition_rules.json"

static var _rules: Dictionary = {}


static func rules() -> Dictionary:
	if _rules.is_empty():
		var res := DataLoader.load_json(RULES_PATH)
		assert(res.ok, res.error)
		_rules = res.data
	return _rules


## 远征里的恐惧变化（轮回者身上的 0~100），增加量按精神力折算，和战斗里一致。返回实际变化量。
static func add_fear(ch: RefCounted, amount: float) -> float:
	var delta := amount
	if amount > 0.0:
		delta = amount * 100.0 / maxf(ch.attributes.total("spirit"), 1.0)
	var before: float = ch.fear
	ch.fear = clampf(ch.fear + delta, 0.0, 100.0)
	return ch.fear - before


## 时间流逝 minutes 分钟。到倒计时为止，超过的部分不算；时间到了就回归。
static func pass_time(st: RefCounted, minutes: int, events: Array[Dictionary]) -> void:
	if minutes <= 0 or st.outcome != "ongoing":
		return
	var duration := int(st.scenario.data["duration_minutes"])
	var m := mini(minutes, duration - st.clock)
	st.clock += m
	_darkness(st, m, events)
	check_tether(st, m, events)
	if st.clock >= duration and st.outcome == "ongoing":
		st.outcome = "returned"
		events.append({"type": "returned", "clock": st.clock})


static func _darkness(st: RefCounted, minutes: int, events: Array[Dictionary]) -> void:
	var rate := float(rules()["dark_fear_per_10_minutes"])
	for sid: String in st.squads:
		var loc := String(st.squads[sid]["location"])
		if not bool(st.scenario.location(loc).get("dark", false)):
			continue
		for c in st.living_members(sid):
			var d := add_fear(st.characters[c], rate * float(minutes) / 10.0)
			if d != 0.0:
				events.append({"type": "fear_changed", "char": c, "amount": d, "fear": st.characters[c].fear, "reason": "darkness"})


## 检查百米绑定。minutes = 这次流逝的时间；刚到达新地点时用 0 检查一次，超出就立刻警告。
static func check_tether(st: RefCounted, minutes: int, events: Array[Dictionary]) -> void:
	if st.tether.is_empty():
		return
	var npc_id := String(st.tether["npc"])
	if not bool(st.npcs[npc_id]["alive"]):
		return
	var npc_loc := String(st.npcs[npc_id]["location"])
	var max_hops := int(st.tether["max_hops"])
	var grace := int(st.tether["grace_minutes"])
	for c in st.all_living():
		var dist: int = st.scenario.hops(st.location_of(c), npc_loc)
		if dist >= 0 and dist <= max_hops:
			st.tether_out.erase(c)
			continue
		if not st.tether_out.has(c):
			st.tether_out[c] = 0
			events.append({"type": "tether_warning", "char": c, "npc": npc_id, "grace_minutes": grace})
		st.tether_out[c] = int(st.tether_out[c]) + minutes
		if int(st.tether_out[c]) > grace:
			erase(st, c, "tether", events)


## 绑定对象死亡：转移给 transfer_to（还活着的话），否则解除。
static func on_tether_npc_died(st: RefCounted, events: Array[Dictionary]) -> void:
	var to := String(st.tether.get("transfer_to", ""))
	st.tether_out.clear()
	if to != "" and st.npcs.has(to) and bool(st.npcs[to]["alive"]):
		st.tether["npc"] = to
		st.tether["transfer_to"] = ""
		events.append({"type": "tether_transferred", "npc": to})
	else:
		release_tether(st, events)


static func release_tether(st: RefCounted, events: Array[Dictionary]) -> void:
	st.tether = {}
	st.tether_out.clear()
	events.append({"type": "tether_released"})


## 被主神抹杀。
static func erase(st: RefCounted, char_id: String, reason: String, events: Array[Dictionary]) -> void:
	var ch: RefCounted = st.characters[char_id]
	ch.alive = false
	ch.flags["erased"] = reason
	st.tether_out.erase(char_id)
	events.append({"type": "erased", "char": char_id, "reason": reason})
	check_wipe(st, events)


static func check_wipe(st: RefCounted, events: Array[Dictionary]) -> void:
	if st.outcome == "ongoing" and st.all_living().is_empty():
		st.outcome = "wiped"
		events.append({"type": "wiped"})


## 禁言：剧情人物在场时说出主神的信息，每句扣分（原著：泄密每句 −10）。返回是否被扣分。
static func leak(st: RefCounted, char_id: String, events: Array[Dictionary]) -> bool:
	var loc: String = st.location_of(char_id)
	for npc_id: String in st.npcs:
		var npc: Dictionary = st.npcs[npc_id]
		if bool(npc["alive"]) and npc["location"] == loc and bool(st.scenario.data["npcs"][npc_id].get("plot", false)):
			var penalty := float(st.scenario.data["watch"].get("gag_penalty", Rules.get_value("settlement", "leak_per_sentence")))
			st.add_ledger(char_id, "penalty", penalty, "泄露主神信息")
			events.append({"type": "gag_penalty", "char": char_id, "points": penalty, "witness": npc_id})
			return true
	events.append({"type": "leak_unwitnessed", "char": char_id})
	return false


## 手表界面：主线任务、剩余时间、击杀、限制条件。
static func view(st: RefCounted, char_id: String) -> Dictionary:
	var constraints: Array = []
	if not st.tether.is_empty():
		constraints.append({
			"kind": "tether",
			"npc": String(st.tether["npc"]),
			"max_hops": int(st.tether["max_hops"]),
			"out_minutes": int(st.tether_out.get(char_id, -1)),
		})
	if st.scenario.data["watch"].has("gag_penalty"):
		constraints.append({"kind": "gag", "penalty": int(st.scenario.data["watch"]["gag_penalty"])})
	return {
		"main_task": String(st.scenario.data["main_task"]),
		"remaining_minutes": int(st.scenario.data["duration_minutes"]) - st.clock,
		"kills": int(st.kill_counts.get(char_id, 0)),
		"kill_points": float(st.kill_points.get(char_id, 0.0)),
		"constraints": constraints,
	}
```

- [ ] **Step 4：运行，确认通过**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_watch bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`共 10 个测试，失败 0 个`，`exit=0`。

- [ ] **Step 5：提交**

```bash
git add game/core/expedition/watch.gd game/tests/unit/expedition/test_watch.gd
git commit -m "feat(expedition): 手表：倒计时、黑暗、百米绑定、抹杀、禁言" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

### Task 4：剧情事件与剧情惯性

**Files:**
- Create: `game/core/expedition/plot_runner.gd`
- Test: `game/tests/unit/expedition/test_plot_runner.gd`

- [ ] **Step 1：写测试 `game/tests/unit/expedition/test_plot_runner.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const ExpeditionState = preload("res://core/expedition/expedition_state.gd")
const PlotRunner = preload("res://core/expedition/plot_runner.gd")


func _state() -> RefCounted:
	var chars := {}
	for id in ["zheng_zha", "zhang_jie"]:
		chars[id] = Character.new(id, id, {})
	var st := ExpeditionState.new()
	var members: Array[String] = ["zheng_zha", "zhang_jie"]
	st.setup(Scenario.load_file("res://tests/fixtures/mini_scenario.json"), chars, members)
	return st


func _event(st: RefCounted, id: String) -> Dictionary:
	for ev: Dictionary in st.scenario.events():
		if ev["id"] == id:
			return ev
	return {}


func _types(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for e in events:
		out.append(String(e["type"]))
	return out


func test_next_timed_in_order() -> void:
	var st := _state()
	assert_eq(PlotRunner.next_timed(st)["id"], "rules_talk")
	st.fired["rules_talk"] = "original"
	assert_eq(PlotRunner.next_timed(st)["id"], "mercs_arrive")
	st.fired["mercs_arrive"] = "original"
	st.fired["queen_shutdown"] = "original"
	assert_true(PlotRunner.next_timed(st).is_empty())


func test_original_event() -> void:
	var st := _state()
	var events: Array[Dictionary] = []
	PlotRunner.fire(st, _event(st, "rules_talk"), events)
	assert_eq(st.fired["rules_talk"], "original")
	assert_eq(_types(events), ["plot_event", "dialogue", "bonus"] as Array[String])
	assert_eq(st.ledger[0]["char"], "zhang_jie")
	assert_almost(float(st.ledger[0]["points"]), 100.0)


## 剧情惯性：改写条件成立时，原效果被替代，剧情偏移量加上惯性等级。
func test_alteration_adds_deviation() -> void:
	var st := _state()
	st.flags["threatened_queen"] = true
	var events: Array[Dictionary] = []
	PlotRunner.fire(st, _event(st, "queen_shutdown"), events)
	assert_eq(st.fired["queen_shutdown"], "altered")
	assert_eq(st.deviation, 1)
	assert_true(bool(st.npcs["matthew"]["alive"]))
	assert_false(st.flags.has("lights_out"))
	assert_eq(events[0]["label"], "威胁火焰女皇，断电被推迟")


func test_original_queen_shutdown_kills_matthew() -> void:
	var st := _state()
	var events: Array[Dictionary] = []
	PlotRunner.fire(st, _event(st, "queen_shutdown"), events)
	assert_true(bool(st.flags["lights_out"]))
	assert_false(bool(st.npcs["matthew"]["alive"]))
	assert_eq(st.tether["npc"], "kaplan")
	assert_true(_types(events).has("tether_transferred"))


## 条件事件：到激光通道触发陷阱 → 发起战斗；有人提醒过 → 改写为救下马修、开门、解除绑定，并连锁出偏移事件。
func test_conditional_battle() -> void:
	var st := _state()
	var events: Array[Dictionary] = []
	PlotRunner.run_conditional(st, events)
	assert_eq(events.size(), 0)
	st.squads["s1"]["location"] = "laser"
	PlotRunner.run_conditional(st, events)
	assert_eq(st.fired["laser_trap"], "original")
	assert_eq(st.pending_battle["location"], "laser")
	assert_eq(st.pending_battle["squad"], "s1")
	assert_almost(st.characters["zheng_zha"].fear, 30.0)
	assert_true(_types(events).has("battle_request"))


func test_conditional_alteration_chain() -> void:
	var st := _state()
	st.flags["warned_laser"] = true
	st.squads["s1"]["location"] = "laser"
	var events: Array[Dictionary] = []
	PlotRunner.run_conditional(st, events)
	assert_eq(st.fired["laser_trap"], "altered")
	assert_eq(st.deviation, 2)
	assert_true(st.pending_battle.is_empty())
	assert_true(st.is_path_open("laser", "control"))
	assert_true(st.tether.is_empty())
	assert_true(bool(st.flags["side:save_matthew"]))
	assert_eq(st.fired["lickers_early"], "original")
	assert_true(bool(st.flags["lickers_early"]))
	var kinds: Array = []
	for l: Dictionary in st.ledger:
		if l["char"] == "zheng_zha":
			kinds.append([l["kind"], l["points"], l["grade"]])
	assert_eq(kinds, [["side_plot", 5000.0, "B"], ["bonus", 500.0, ""]])
	assert_almost(st.characters["zheng_zha"].attributes.total("spirit"), 120.0)
	assert_almost(st.characters["zheng_zha"].attributes.total("nerve_reaction"), 130.0)


func test_battle_avoided_when_nobody_there() -> void:
	var st := _state()
	var events: Array[Dictionary] = []
	PlotRunner.apply_effect(st, {"battle": {"location": "sewer", "enemies": [{"def": "zombie", "count": 1}]}}, "", events)
	assert_eq(_types(events), ["battle_avoided"] as Array[String])
	assert_true(st.pending_battle.is_empty())


func test_recipients() -> void:
	var st := _state()
	st.characters["zhang_jie"].alive = false
	assert_eq(PlotRunner.recipients(st, ["zheng_zha", "zhang_jie"], ""), ["zheng_zha"] as Array[String])
	assert_eq(PlotRunner.recipients(st, "present", "car"), ["zheng_zha"] as Array[String])
	assert_eq(PlotRunner.recipients(st, "present", "hall").size(), 0)
	assert_eq(PlotRunner.recipients(st, "all", ""), ["zheng_zha"] as Array[String])


func test_misc_effects() -> void:
	var st := _state()
	var events: Array[Dictionary] = []
	var effects: Array = [
		{"npc_move": {"npc": "matthew", "to": "hall"}},
		{"close_path": ["car", "hall"]},
		{"penalty": {"points": -1000, "label": "杀死新人", "recipients": ["zheng_zha"]}},
		{"end": "escaped"},
	]
	PlotRunner.apply_effects(st, effects, "", events)
	assert_eq(st.npcs["matthew"]["location"], "hall")
	assert_false(st.is_path_open("car", "hall"))
	assert_almost(float(st.ledger[0]["points"]), -1000.0)
	assert_eq(st.outcome, "escaped")
```

- [ ] **Step 2：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_plot_runner bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`FAIL  res://tests/unit/expedition/test_plot_runner.gd（脚本无法加载）`，`!! 检测到脚本错误`，`exit=1`。

- [ ] **Step 3：创建 `game/core/expedition/plot_runner.gd`**

```gdscript
extends RefCounted
## 剧情事件（设计规格 5.2）：定时事件（at，到点发生）和条件事件（when，条件一成立就发生），每个只发生一次。
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
	while changed and st.outcome == "ongoing" and st.pending_battle.is_empty():
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
		var where := String(e["fear"].get("location", ""))
		var targets: Array[String] = st.members_at(where) if where != "" else st.all_living()
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
	if e.has("end"):
		st.outcome = String(e["end"])
		events.append({"type": "expedition_end", "outcome": st.outcome})


## 战斗效果：有轮回者在那个地点就发起战斗（等界面打完再回报），没人在就躲过去了。
static func _battle(st: RefCounted, spec: Dictionary, events: Array[Dictionary]) -> void:
	var loc := String(spec["location"])
	var here: Array[String] = st.squads_at(loc)
	if here.is_empty():
		events.append({"type": "battle_avoided", "location": loc})
		return
	var dark := bool(st.scenario.location(loc).get("dark", false)) or bool(st.flags.get("lights_out", false))
	st.pending_battle = {
		"location": loc,
		"squad": here[0],
		"enemies": (spec["enemies"] as Array).duplicate(true),
		"dark": dark,
	}
	events.append({"type": "battle_request", "location": loc, "squad": here[0], "dark": dark})
```

- [ ] **Step 4：运行，确认通过**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_plot_runner bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`共 9 个测试，失败 0 个`，`exit=0`。

- [ ] **Step 5：提交**

```bash
git add game/core/expedition/plot_runner.gd game/tests/unit/expedition/test_plot_runner.gd
git commit -m "feat(expedition): 剧情事件、剧情惯性与改写、效果" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

### Task 5：战斗回报与一部片的结算

**Files:**
- Create: `game/core/expedition/battle_report.gd`、`game/core/expedition/expedition_settlement.gd`
- Test: `game/tests/unit/expedition/test_battle_report.gd`、`game/tests/unit/expedition/test_expedition_settlement.gd`

- [ ] **Step 1：写测试 `game/tests/unit/expedition/test_battle_report.gd`**

```gdscript
extends "res://tests/test_case.gd"

const UnitFactory = preload("res://core/battle/unit_factory.gd")
const BattleReport = preload("res://core/expedition/battle_report.gd")


func _units() -> Array[RefCounted]:
	var z1 := UnitFactory.from_enemy("zombie", "z1", 0)
	var z2 := UnitFactory.from_enemy("licker", "l1", 0)
	var a := UnitFactory.from_enemy("zombie", "zheng_zha", 0)
	a.side = "ally"
	var b := UnitFactory.from_enemy("zombie", "newbie", 0)
	b.side = "ally"
	var units: Array[RefCounted] = [z1, z2, a, b]
	return units


func test_last_hit_gets_the_kill() -> void:
	var history: Array[Dictionary] = [
		{"type": "damage", "source": "newbie", "target": "z1", "amount": 30.0, "hp": 10.0},
		{"type": "damage", "source": "zheng_zha", "target": "z1", "amount": 16.0, "hp": -6.0},
		{"type": "death", "target": "z1", "turned": false},
		{"type": "damage", "source": "zheng_zha", "target": "l1", "amount": 200.0, "hp": 0.0},
		{"type": "death", "target": "l1", "turned": false},
	]
	var r := BattleReport.summarize(history, _units())
	assert_eq(r["kills"], [
		{"killer": "zheng_zha", "victim": "z1", "def_id": "zombie"},
		{"killer": "zheng_zha", "victim": "l1", "def_id": "licker"},
	])
	assert_eq(r["deaths"], [])


func test_ally_deaths_and_fled() -> void:
	var history: Array[Dictionary] = [
		{"type": "damage", "source": "zheng_zha", "target": "newbie", "amount": 200.0, "hp": -60.0},
		{"type": "death", "target": "newbie", "turned": false},
		{"type": "damage", "source": "z1", "target": "zheng_zha", "amount": 10.0, "hp": 130.0},
		{"type": "death", "target": "zheng_zha", "turned": true},
		{"type": "fled", "unit": "z1"},
	]
	var r := BattleReport.summarize(history, _units())
	assert_eq(r["deaths"], [
		{"id": "newbie", "killer": "zheng_zha", "turned": false},
		{"id": "zheng_zha", "killer": "", "turned": true},
	])
	assert_eq(r["fled"], ["z1"])


func test_no_killer_without_damage() -> void:
	var history: Array[Dictionary] = [{"type": "death", "target": "z1", "turned": false}]
	assert_eq(BattleReport.summarize(history, _units())["kills"][0]["killer"], "")
```

- [ ] **Step 2：写测试 `game/tests/unit/expedition/test_expedition_settlement.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const ExpeditionState = preload("res://core/expedition/expedition_state.gd")
const ExpeditionSettlement = preload("res://core/expedition/expedition_settlement.gd")


func _state() -> RefCounted:
	var chars := {}
	for id in ["zheng_zha", "zhang_jie", "newbie"]:
		chars[id] = Character.new(id, id, {})
	var st := ExpeditionState.new()
	var members: Array[String] = ["zheng_zha", "zhang_jie", "newbie"]
	st.setup(Scenario.load_file("res://tests/fixtures/mini_scenario.json"), chars, members)
	return st


## 原著：郑吒第一部 6502 点 = 存活 1000 + 救下马修（B 级支线）5000 + 精神临界值突破 500 + 击杀 2。
func test_zheng_zha_6502() -> void:
	var st := _state()
	st.kill_points["zheng_zha"] = 2.4
	st.add_ledger("zheng_zha", "side_plot", 5000.0, "救下马修", "B")
	st.add_ledger("zheng_zha", "bonus", 500.0, "精神临界值突破")
	var results := ExpeditionSettlement.settle_all(st)
	assert_eq(int(results["zheng_zha"]["final_points"]), 6502)
	var zz: RefCounted = st.characters["zheng_zha"]
	assert_eq(zz.points, 6502)
	assert_true(zz.tickets.has_at_least("B"))
	assert_eq(zz.films_completed, 1)
	assert_true(st.settled)


func test_entries() -> void:
	var st := _state()
	st.add_ledger("zhang_jie", "bonus", 100.0, "讲解规则")
	var entries := ExpeditionSettlement.entries_for(st, "zhang_jie")
	assert_eq(entries.size(), 2)
	assert_eq(entries[0]["kind"], "survival")
	assert_eq(entries[1]["label"], "讲解规则")
	st.characters["newbie"].alive = false
	assert_eq(ExpeditionSettlement.entries_for(st, "newbie").size(), 0)


func test_dead_are_not_settled() -> void:
	var st := _state()
	st.characters["newbie"].alive = false
	st.characters["newbie"].flags["erased"] = "tether"
	var results := ExpeditionSettlement.settle_all(st)
	assert_eq(results["newbie"], {"dead": true, "reason": "tether"})
	assert_eq(st.characters["newbie"].films_completed, 0)


## 点数为负：被主神抹杀（原著）。
func test_negative_points_erased() -> void:
	var st := _state()
	st.add_ledger("newbie", "penalty", -1000.0, "杀死新人")
	st.add_ledger("newbie", "penalty", -10.0, "泄露主神信息")
	var results := ExpeditionSettlement.settle_all(st)
	assert_true(bool(results["newbie"]["erased"]))
	assert_false(st.characters["newbie"].alive)
	assert_eq(st.characters["newbie"].flags["erased"], "negative_points")
```

- [ ] **Step 3：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_battle_report bash game/tools/run_tests.sh; echo "exit=$?"`，再运行 `WSLENV=TEST_FILTER TEST_FILTER=test_expedition_settlement bash game/tools/run_tests.sh; echo "exit=$?"`

预期：两次都是对应文件 `FAIL ...（脚本无法加载）`，`!! 检测到脚本错误`，`exit=1`。

- [ ] **Step 4：创建 `game/core/expedition/battle_report.gd`**

```gdscript
extends RefCounted
## 从一场战斗的事件记录里整理出击杀和伤亡，供远征记账（击杀奖励、杀死新人扣分）。
## 击杀者 = 最后一次对它造成伤害的单位；没被直接打过（例如流血死、感染变丧尸）就没有击杀者。

## 返回 {"kills": [{"killer", "victim", "def_id"}], "deaths": [{"id", "killer", "turned"}], "fled": [单位 id]}
static func summarize(history: Array[Dictionary], units: Array[RefCounted]) -> Dictionary:
	var by_id := {}
	for u in units:
		by_id[u.id] = u
	var last_hit := {}
	var kills: Array = []
	var deaths: Array = []
	var fled: Array = []
	for e in history:
		match String(e["type"]):
			"damage":
				last_hit[e["target"]] = e["source"]
			"death":
				var v: RefCounted = by_id[e["target"]]
				var killer := "" if bool(e["turned"]) else String(last_hit.get(v.id, ""))
				if v.side == "enemy":
					kills.append({"killer": killer, "victim": v.id, "def_id": v.def_id})
				else:
					deaths.append({"id": v.id, "killer": killer, "turned": bool(e["turned"])})
			"fled":
				fled.append(String(e["unit"]))
	return {"kills": kills, "deaths": deaths, "fled": fled}
```

- [ ] **Step 5：创建 `game/core/expedition/expedition_settlement.gd`**

```gdscript
extends RefCounted
## 一部片结束时，把远征里记下的账（存活、击杀、支线、特殊奖励、扣分）交给 settlement.gd 结算，并写回轮回者（设计规格 5.6）。
## 原著锚点：郑吒第一部 6502 点 = 存活 1000 + 救下马修 5000 + 精神临界值突破 500 + 击杀 2。

const Rules = preload("res://core/util/rules.gd")
const Settlement = preload("res://core/economy/settlement.gd")


## 一个人的结算条目。死了的人没有条目（不结算）。
static func entries_for(st: RefCounted, char_id: String) -> Array:
	var out: Array = []
	if not st.is_alive(char_id):
		return out
	out.append({"kind": "survival", "points": float(Rules.get_value("settlement", "survival")), "label": "存活"})
	var k := float(st.kill_points.get(char_id, 0.0))
	if k > 0.0:
		out.append({"kind": "kill", "points": k, "label": "击杀"})
	for l: Dictionary in st.ledger:
		if l["char"] == char_id:
			out.append({"kind": String(l["kind"]), "points": float(l["points"]), "label": String(l["label"]), "grade": String(l["grade"])})
	return out


## 全员结算并写回：点数、支线、完成的片数；点数为负被抹杀。返回 角色 id → 结算结果（死了的是 {"dead": true, "reason": ...}）。
static func settle_all(st: RefCounted) -> Dictionary:
	var results := {}
	for c: String in st.roster:
		var ch: RefCounted = st.characters[c]
		if not ch.alive:
			results[c] = {"dead": true, "reason": String(ch.flags.get("erased", "killed"))}
			continue
		var r := Settlement.settle(entries_for(st, c), ch.points)
		ch.points = int(r["final_points"])
		for g: String in r["tickets"]:
			ch.tickets.add(g)
		if bool(r["erased"]):
			ch.alive = false
			ch.flags["erased"] = "negative_points"
		else:
			ch.films_completed += 1
		results[c] = r
	st.settled = true
	return results
```

- [ ] **Step 6：运行，确认通过**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_battle_report bash game/tools/run_tests.sh; echo "exit=$?"`，再运行 `WSLENV=TEST_FILTER TEST_FILTER=test_expedition_settlement bash game/tools/run_tests.sh; echo "exit=$?"`

预期：第一次 `共 3 个测试，失败 0 个`，第二次 `共 4 个测试，失败 0 个`，都是 `exit=0`。

- [ ] **Step 7：提交**

```bash
git add game/core/expedition/battle_report.gd game/core/expedition/expedition_settlement.gd game/tests/unit/expedition/test_battle_report.gd game/tests/unit/expedition/test_expedition_settlement.gd
git commit -m "feat(expedition): 战斗回报与一部片的结算（原著 6502 点锚点）" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

### Task 6：远征控制器

**Files:**
- Create: `game/core/expedition/expedition.gd`
- Test: `game/tests/unit/expedition/test_expedition.gd`

- [ ] **Step 1：写测试 `game/tests/unit/expedition/test_expedition.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const GameState = preload("res://core/model/game_state.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const Expedition = preload("res://core/expedition/expedition.gd")
const Battle = preload("res://core/battle/battle.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
const Rng = preload("res://core/util/rng.gd")

const FIXTURE := "res://tests/fixtures/mini_scenario.json"


## 测试用的假战斗：只需要 history、field.units、outcome 三样。
class FakeField extends RefCounted:
	var units: Array[RefCounted] = []


class FakeBattle extends RefCounted:
	var history: Array[Dictionary] = []
	var field := FakeField.new()
	var outcome := "victory"


func _game() -> RefCounted:
	var g := GameState.new(1)
	for id in ["zheng_zha", "zhang_jie", "newbie"]:
		g.add_character(Character.new(id, id, {}))
	g.characters["zhang_jie"].films_completed = 3
	return g


func _start(g: RefCounted) -> RefCounted:
	var ex := Expedition.new()
	var members: Array[String] = ["zheng_zha", "zhang_jie", "newbie"]
	ex.start(g, Scenario.load_file(FIXTURE), members)
	return ex


func _types(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for e in events:
		out.append(String(e["type"]))
	return out


## 一条直线 a—b—c 的小剧本，剧情人物在 a，绑定 1 格、宽限 10 分钟，没有事件。
func _line_scenario() -> RefCounted:
	return Scenario.new({
		"id": "line", "name": "直线", "start_location": "a", "duration_minutes": 60, "main_task": "存活",
		"locations": {"a": {"name": "A"}, "b": {"name": "B"}, "c": {"name": "C"}},
		"paths": [{"a": "a", "b": "b", "minutes": 5}, {"a": "b", "b": "c", "minutes": 5}],
		"npcs": {"vip": {"name": "VIP", "location": "a", "plot": true}},
		"watch": {"tether": {"npc": "vip", "max_hops": 1, "grace_minutes": 10}},
		"events": [],
	})


func test_start_fires_opening() -> void:
	var g := _game()
	var ex := Expedition.new()
	var members: Array[String] = ["zheng_zha", "zhang_jie", "newbie"]
	var events: Array[Dictionary] = ex.start(g, Scenario.load_file(FIXTURE), members)
	assert_eq(_types(events), ["expedition_start", "plot_event", "dialogue", "bonus"] as Array[String])
	assert_eq(ex.st.clock, 0)
	assert_eq(ex.st.ledger[0]["char"], "zhang_jie")


## 走到大厅要 10 分钟，途中第 10 分钟雇佣兵登场：马修移到大厅，全员恐惧 +10。
func test_move_runs_timed_events() -> void:
	var ex := _start(_game())
	var events: Array[Dictionary] = ex.move("s1", "hall")
	var types := _types(events)
	assert_true(types.find("plot_event") < types.find("arrived"), str(types))
	assert_eq(ex.st.clock, 10)
	assert_eq(ex.st.location_of("zheng_zha"), "hall")
	assert_eq(ex.st.npcs["matthew"]["location"], "hall")
	assert_almost(ex.st.characters["zheng_zha"].fear, 10.0)


func test_invalid_moves() -> void:
	var ex := _start(_game())
	assert_eq(ex.move("s1", "laser")[0]["reason"], "no_path")
	assert_eq(ex.move("s9", "hall")[0]["reason"], "no_squad")
	assert_eq(ex.st.clock, 0)


## 激光通道的门默认关着。
func test_closed_path() -> void:
	var ex := _start(_game())
	ex.st.squads["s1"]["location"] = "laser"
	ex.st.fired["laser_trap"] = "original"
	assert_eq(ex.move("s1", "control")[0]["reason"], "no_path")


func test_search_once() -> void:
	var ex := _start(_game())
	var events: Array[Dictionary] = ex.search("s1")
	assert_eq(events[events.size() - 1]["found"], [{"item": "grenade", "count": 1}])
	assert_almost(float(ex.st.squads["s1"]["items"]["grenade"]), 1.0)
	assert_eq(ex.st.clock, 10)
	assert_eq(ex.search("s1")[0]["type"], "already_searched")
	assert_eq(ex.st.clock, 10)


func test_rest_lowers_fear() -> void:
	var ex := _start(_game())
	ex.st.characters["newbie"].fear = 50.0
	ex.rest("s1", 20)
	assert_eq(ex.st.clock, 20)
	assert_almost(ex.st.characters["newbie"].fear, 50.0 + 10.0 - 10.0)


## 原剧情：走进激光通道 → 陷阱 → 战斗。战斗没打完之前不能做别的事；打完记击杀。
func test_laser_trap_battle() -> void:
	var g := _game()
	var ex := _start(g)
	ex.move("s1", "hall")
	ex.move("s1", "stairs")
	var events: Array[Dictionary] = ex.move("s1", "laser")
	assert_true(_types(events).has("battle_request"), str(_types(events)))
	assert_eq(ex.st.pending_battle["location"], "laser")
	assert_eq(ex.move("s1", "stairs")[0]["reason"], "battle_pending")
	var pistol: Array[String] = ["pistol_shot"]
	var units: Array[RefCounted] = ex.battle_units({"zheng_zha": pistol, "zhang_jie": pistol, "newbie": pistol}, "ai")
	assert_eq(units.size(), 5)
	var b := Battle.new()
	b.setup(units, ex.battle_options(), Rng.new(4))
	assert_eq(b.outcome, "victory")
	var report: Array[Dictionary] = ex.report_battle(b)
	assert_true(_types(report).has("battle_resolved"))
	assert_true(ex.st.pending_battle.is_empty())
	var total_kills := 0
	for c in ["zheng_zha", "zhang_jie", "newbie"]:
		total_kills += int(ex.st.kill_counts.get(c, 0))
	assert_eq(total_kills, 2)


## 击杀奖励按相对威胁算：丧尸基础价 0.1，威胁 100，新人队评价战力 120 → 每只 0.0833。
## 杀死新人扣 1000 点。战后写回生命和剩余道具。
func test_report_records_kills_and_penalties() -> void:
	var g := _game()
	var ex := _start(g)
	ex.st.squads["s1"]["items"] = {"grenade": 2.0}
	ex.st.squads["s1"]["location"] = "laser"
	ex.st.pending_battle = {"location": "laser", "squad": "s1", "enemies": [{"def": "zombie", "count": 1}], "dark": false}
	var units: Array[RefCounted] = ex.battle_units({})
	var b := FakeBattle.new()
	b.field.units = units
	units[0].hp = 50.0
	units[0].resources["grenade"] = 1.0
	b.history = [
		{"type": "damage", "source": "zheng_zha", "target": "zombie_1", "amount": 40.0, "hp": 0.0},
		{"type": "death", "target": "zombie_1", "turned": false},
		{"type": "damage", "source": "zhang_jie", "target": "newbie", "amount": 200.0, "hp": -60.0},
		{"type": "death", "target": "newbie", "turned": false},
	]
	units[2].alive = false
	ex.report_battle(b)
	assert_almost(float(ex.st.kill_points["zheng_zha"]), 0.1 * 100.0 / 120.0)
	assert_eq(ex.st.ledger[ex.st.ledger.size() - 1], {"char": "zhang_jie", "kind": "penalty", "points": -1000.0, "label": "杀死新人", "grade": ""})
	assert_almost(g.characters["zheng_zha"].hp, 50.0)
	assert_false(g.characters["newbie"].alive)
	assert_eq(ex.st.squads["s1"]["items"], {"grenade": 1.0})


## 改变剧情：有人提前提醒激光陷阱 → 改写为救下马修（B 级支线 + 5000）、精神临界值突破（+500）、开门、解除绑定，
## 剧情偏移 2 → 连锁事件。之后撑到倒计时结束回归、结算。
func test_altered_plot_and_settlement() -> void:
	var g := _game()
	var ex := _start(g)
	ex.apply_effects([{"set_flag": "warned_laser"}])
	ex.move("s1", "hall")
	ex.move("s1", "stairs")
	var events: Array[Dictionary] = ex.move("s1", "laser")
	var types := _types(events)
	assert_true(types.has("plot_altered"), str(types))
	assert_true(types.has("side_plot_done"))
	assert_true(types.has("tether_released"))
	assert_true(bool(ex.st.flags["lickers_early"]))
	assert_eq(ex.move("s1", "control")[1]["type"], "arrived")
	ex.rest("s1", 200)
	assert_eq(ex.st.outcome, "returned")
	assert_eq(ex.st.clock, 120)
	var results: Dictionary = ex.finish()
	assert_eq(int(results["zheng_zha"]["final_points"]), 1000 + 5000 + 500)
	assert_eq(int(results["zhang_jie"]["final_points"]), 1000 + 5000 + 500 + 100)
	assert_true(g.characters["zheng_zha"].tickets.has_at_least("B"))
	assert_eq(g.films_record, ["mini_hive"])
	assert_eq(ex.finish(), {})


func test_finish_only_after_end() -> void:
	var ex := _start(_game())
	assert_eq(ex.finish(), {})


## 百米绑定：走到离剧情人物两格的地方先警告，超过宽限时间被抹杀；全员被抹杀即全灭。
func test_tether_erases() -> void:
	var g := _game()
	var ex := Expedition.new()
	var members: Array[String] = ["newbie"]
	ex.start(g, _line_scenario(), members)
	ex.move("s1", "b")
	var events: Array[Dictionary] = ex.move("s1", "c")
	assert_true(_types(events).has("tether_warning"))
	ex.rest("s1", 10)
	assert_true(g.characters["newbie"].alive)
	events = ex.rest("s1", 1)
	assert_false(g.characters["newbie"].alive)
	assert_eq(ex.st.outcome, "wiped")
	assert_eq(ex.finish()["newbie"], {"dead": true, "reason": "tether"})


func test_gag_through_controller() -> void:
	var ex := _start(_game())
	var events: Array[Dictionary] = ex.leak("newbie")
	assert_eq(events[0]["type"], "gag_penalty")
	assert_eq(events[0]["witness"], "matthew")


func test_split_and_merge() -> void:
	var ex := _start(_game())
	var group: Array[String] = ["newbie"]
	var events: Array[Dictionary] = ex.split("s1", group)
	assert_eq(events[0]["squad"], "s2")
	ex.move("s2", "hall")
	assert_eq(ex.merge("s1", "s2")[0]["reason"], "bad_merge")
	ex.move("s1", "hall")
	assert_eq(ex.merge("s1", "s2")[0]["type"], "squads_merged")


func test_watch_view() -> void:
	var ex := _start(_game())
	ex.move("s1", "hall")
	var v: Dictionary = ex.watch_view("zheng_zha")
	assert_eq(v["remaining_minutes"], 110)
	assert_eq(v["constraints"][0]["npc"], "matthew")


## 存档后读档，继续行动的结果和不存档完全一样。
func test_save_and_resume() -> void:
	var g1 := _game()
	var a := _start(g1)
	a.move("s1", "hall")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(a.to_dict()))
	var b := Expedition.new()
	b.load_dict(saved, g1, Scenario.load_file(FIXTURE))
	assert_eq(b.to_dict(), a.to_dict())
	var g2 := _game()
	var c := _start(g2)
	c.move("s1", "hall")
	assert_eq(b.move("s1", "sewer"), c.move("s1", "sewer"))
	assert_eq(b.st.clock, 25)
```

- [ ] **Step 2：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_expedition.gd bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`FAIL  res://tests/unit/expedition/test_expedition.gd（脚本无法加载）`，`!! 检测到脚本错误`，`exit=1`。

- [ ] **Step 3：创建 `game/core/expedition/expedition.gd`**

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

const ExpeditionState = preload("res://core/expedition/expedition_state.gd")
const Watch = preload("res://core/expedition/watch.gd")
const PlotRunner = preload("res://core/expedition/plot_runner.gd")
const BattleReport = preload("res://core/expedition/battle_report.gd")
const ExpeditionSettlement = preload("res://core/expedition/expedition_settlement.gd")
const BattleData = preload("res://core/battle/battle_data.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
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


## 为待打的战斗生成单位。loadouts：角色 id → 技能 id 数组（没给的只会拳脚）。
## 分队的道具交给第一个人携带；每排最多 4 人，多出来的往后排。
func battle_units(loadouts: Dictionary, controller: String = "player") -> Array[RefCounted]:
	var units: Array[RefCounted] = []
	if st.pending_battle.is_empty():
		return units
	var sid := String(st.pending_battle["squad"])
	var members: Array[String] = st.living_members(sid)
	for i in members.size():
		var c := members[i]
		var skills: Array[String] = []
		for s in loadouts.get(c, ["punch"]):
			skills.append(String(s))
		var res: Dictionary = st.squads[sid]["items"] if i == 0 else {}
		units.append(UnitFactory.from_character(st.characters[c], "ally", mini(floori(i / 4.0), 2), skills, controller, res))
	st.pending_battle["carrier"] = members[0] if not members.is_empty() else ""
	var n := 0
	for g: Dictionary in st.pending_battle["enemies"]:
		for k in int(g.get("count", 1)):
			n += 1
			var row := mini(int(g.get("row", 0)) + floori(k / 4.0), 2)
			units.append(UnitFactory.from_enemy(String(g["def"]), "%s_%d" % [g["def"], n], row))
	return units


func battle_options() -> Dictionary:
	return {"dark": bool(st.pending_battle.get("dark", false))}


## 战斗打完后回报：写回轮回者的生命、恐惧、基因锁、生死和剩余道具；记击杀奖励；杀死新人扣 1000 点。
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
		UnitFactory.write_back(u, st.characters[u.character_id])
		if u.character_id == carrier:
			var items := {}
			for k: String in u.resources:
				if k != "rebirth_cross" and float(u.resources[k]) > 0.0:
					items[k] = float(u.resources[k])
			st.squads[sid]["items"] = items
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
	st.pending_battle = {}
	events.append({"type": "battle_resolved", "outcome": String(b.outcome)})
	Watch.check_wipe(st, events)
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
	elif not st.pending_battle.is_empty():
		reason = "battle_pending"
	elif not st.squads.has(squad_id) or st.living_members(squad_id).is_empty():
		reason = "no_squad"
	if reason != "":
		events.append({"type": "invalid_action", "reason": reason})
		return false
	return true


## 推进 minutes 分钟：途中到点的定时事件依次发生，每次之后检查条件事件。
## 返回 true 表示时间完整走完；被战斗打断或远征结束返回 false。
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
		if not st.pending_battle.is_empty():
			return false
	Watch.pass_time(st, target - st.clock, events)
	PlotRunner.run_conditional(st, events)
	return st.outcome == "ongoing" and st.pending_battle.is_empty()
```

- [ ] **Step 4：运行，确认通过**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_expedition.gd bash game/tools/run_tests.sh; echo "exit=$?"`

预期：15 个 `ok`，`共 15 个测试，失败 0 个`，`exit=0`。

- [ ] **Step 5：提交**

```bash
git add game/core/expedition/expedition.gd game/tests/unit/expedition/test_expedition.gd
git commit -m "feat(expedition): 远征控制器：移动、搜索、休息、分队、战斗对接、结算、存读档" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

### Task 7：全量验证与 uid 文件

- [ ] **Step 1：跑全部测试**

Run: `bash game/tools/run_tests.sh; echo "exit=$?"`

预期：结尾为 `共 178 个测试，失败 0 个`，`exit=0`，输出里没有 `SCRIPT ERROR`。

- [ ] **Step 2：导入工程**

Run: `godot --headless --path game --import; echo "exit=$?"`

预期：`exit=0`。

- [ ] **Step 3：查看新生成的 uid 文件**

Run: `git status --short`

预期：除了 `?? _work/`，正好是下面 16 行（顺序可能不同）：

```text
?? game/core/expedition/battle_report.gd.uid
?? game/core/expedition/conditions.gd.uid
?? game/core/expedition/expedition.gd.uid
?? game/core/expedition/expedition_settlement.gd.uid
?? game/core/expedition/expedition_state.gd.uid
?? game/core/expedition/plot_runner.gd.uid
?? game/core/expedition/scenario.gd.uid
?? game/core/expedition/watch.gd.uid
?? game/tests/unit/expedition/test_battle_report.gd.uid
?? game/tests/unit/expedition/test_conditions.gd.uid
?? game/tests/unit/expedition/test_expedition.gd.uid
?? game/tests/unit/expedition/test_expedition_settlement.gd.uid
?? game/tests/unit/expedition/test_expedition_state.gd.uid
?? game/tests/unit/expedition/test_plot_runner.gd.uid
?? game/tests/unit/expedition/test_scenario.gd.uid
?? game/tests/unit/expedition/test_watch.gd.uid
```

- [ ] **Step 4：提交 uid 文件**

```bash
git add game/core/expedition/*.gd.uid game/tests/unit/expedition/*.gd.uid
git commit -m "chore: 纳入计划 3 新脚本的 uid 文件" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
git log --oneline -8
```

预期：`git status --short` 只剩 `?? _work/`；`git log --oneline -8` 最上面 7 个是本计划的提交（Task 1~6 各一个，加上 uid 一个），第 8 个是提交本计划的 `docs: 计划 3 远征内核`。**不要推送。**
