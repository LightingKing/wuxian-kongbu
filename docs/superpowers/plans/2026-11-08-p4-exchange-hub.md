# 计划 4：兑换与主神空间 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `game/core/hub/` 做出主神空间的规则：兑换目录（效果积木）、定价公式（原著价格作为验收锚点）、兑换门槛与结算（前置、能量、素质、天赋、代兑、双血统风险）、B 级以上兑换受基因锁发挥率影响，以及一次休整的行动：天数、训练、修复、造人、直接强化属性、支线拆分与合成。

**Architecture:** 纯逻辑层（`RefCounted` + `preload`）。兑换项是数据（`data/hub/exchange_catalog.json`），每项由效果积木组成；`pricing.gd` 把积木换算成价格，`catalog.gd` 加载时校验"目录里写的价格 = 公式算出的价格"。`exchange.gd` 做门槛核对和兑换，`hub.gd` 管一次休整的天数和各种行动。为此给计划 1 的属性、角色、游戏状态加了几个字段（旧存档照样能读）。

**Tech Stack:** Godot 4.7.2（GDScript）、bash。

**依据：** 设计规格 `docs/superpowers/specs/2026-11-05-wuxian-kongbu-game-design.md`（v0.8）第 3.4、6.2~6.6、7.1~7.2、9.6 节；核心机制分析第四节；`_work/mechanics.md` 第 2.5、3.3、4 节的原著价格。

**本计划的全部代码都已在临时目录里实际跑通（加上前三个计划的 178 个，共 214 个测试全部通过），照抄即可。**

**执行环境注意：**
- 仓库根目录：Windows 上是 `I:\workspace\mobilegame\wuxian-kongbu\`；在 WSL 的 bash 里是 `/mnt/i/workspace/mobilegame/wuxian-kongbu`。所有命令都在仓库根目录执行。
- 只跑某个测试文件时用 `WSLENV=TEST_FILTER TEST_FILTER=<文件名> bash game/tools/run_tests.sh`。休整测试写成 `test_hub.gd`（带扩展名），免得把 `test_hub_model.gd` 也匹配进来。
- 所有文本文件用 **LF** 换行、UTF-8 无 BOM；GDScript 代码块用 **Tab** 缩进，照抄时保留 Tab。
- **"确认失败"那一步**：被测文件还不存在时，输出里除了 `FAIL  ...（脚本无法加载）`，前面还会有几行 `SCRIPT ERROR: Parse Error: ...`，最后是 `!! 检测到脚本错误`。这都是预期的。
- 跑测试不会生成 `.gd.uid` 文件，导入工程（Task 5）才会。Task 5 把这些文件一起提交。
- **只提交，不推送。**

---

## 设计要点

- **效果积木**：每块积木只有一种类型——`attr`（属性加成）、`energy`（能量池：内力、血族能量）、`skill`（战斗技能，必须在 `battle/skills.json` 里）、`ability`（还不能在战斗里直接用的能力，例如红炎、轻功，以后的计划接入）、`passive`（被动）、`item`（道具数量）、`side_effect`（副作用，带折扣）。积木可以带 `tier`（档次）。
- **定价公式**（`pricing.gd`）：
  - 价值 = 各积木价值之和 × 副作用折扣；属性积木 10 点 = 1 点属性；无限弹药 × 20；魔法传说类的非属性积木 × 2（原著规律）。
  - 等级 = 积木里最高的档次；点数 = 价值 − 所需支线的折算值。折算值 D 500、C 1400、B 2400，由原著三件纯属性的兑换项标定（低级气功 500+D、T 病毒 1500+C、蜘蛛侠基因 2000+B）；A、S 暂无原著锚点，先占位。
  - 为什么等级不按总价值分档：原著里精神力扫描是 4000+C（折合约 5400），蜘蛛侠基因却是 2000+B（折合约 4400），等级反映的是效果的档次，不是总量。
  - 目录里写的价格必须等于公式算出的价格；23 件原著价格在测试里逐项核对。
- **兑换门槛**（`exchange.gd`）：点数、支线（"2B" 表示两个 B）、前置（高一级要先有同系低一级）、能量类型（纳戒要内力）、素质门槛（有对应天赋可绕过）、不能重复兑换（消耗品除外）、代兑次数。不满足时返回全部原因。
- **双血统**：已有别的系列的血统，再兑换血统时主神先警告（不兑换）；坚持兑换时 70% 变成非人（`flags.mutated`）。同一系列的升级（男爵 → 子爵 → 伯爵）不算。
- **基因锁发挥率**：B 级及以上兑换项的属性记在 `attributes.enhanced_high`，按发挥率打折（0 阶 50%、一阶 70%……四阶 100%）。角色的基因锁阶数一变，发挥率自动更新。A 级以上的新技能熟练度从 0.3 开始，要训练。
- **休整**（`hub.gd`）：第 0 天是回归当晚，只能造人和结算，不能兑换；每过一天恐惧 −15；训练每天熟练度 +0.25，最后一天强制休息不能训练；修复：生命一半以上 400（修补），更重按伤势涨到 2000（修复），可以由别人付；造人：每人第一个免费，之后 500，素质最多 200；直接强化属性 10 点 = 1 点；每人每次休整只能给别人代兑一次。

**不在本计划范围**：约 200 条的 M1 完整目录（计划 7，按同一套积木和公式扩充）；红炎、轻功等能力在战斗里的效果、熟练度对战斗的影响（计划 7）；造物的陪伴与 AI 对话（计划 6、8）；复活、时间兑换、工坊（后续里程碑）。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `game/core/model/attributes.gd`（改写） | 加上 `enhanced_high` 和发挥率 `high_mult` |
| `game/core/model/character.gd`（改写） | 基因锁阶数变化时同步发挥率；加上已兑换项、战斗技能、能力、熟练度、能量池、道具 |
| `game/core/model/game_state.gd`（改写） | 加上造物列表 |
| `game/data/hub/hub_rules.json` | 支线折算值、大类倍率、无限弹药倍率、变异概率、造人、修复、休整、训练 |
| `game/data/hub/exchange_catalog.json` | 兑换目录：原著首批 26 项 |
| `game/core/hub/pricing.gd` | 定价公式 |
| `game/core/hub/catalog.gd` | 加载、查询、校验兑换目录 |
| `game/core/hub/exchange.gd` | 兑换门槛与兑换 |
| `game/core/hub/hub.gd` | 一次休整：天数、兑换、属性强化、支线拆合、修复、造人、训练、休息 |
| `game/tests/unit/hub/test_*.gd` | 各模块的测试（5 个文件，36 个测试） |

---

### Task 1：属性、角色、游戏状态的新字段

**Files:**
- Modify: `game/core/model/attributes.gd`、`game/core/model/character.gd`、`game/core/model/game_state.gd`
- Test: `game/tests/unit/hub/test_hub_model.gd`

- [ ] **Step 1：写测试 `game/tests/unit/hub/test_hub_model.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Attributes = preload("res://core/model/attributes.gd")
const Character = preload("res://core/model/character.gd")
const GameState = preload("res://core/model/game_state.gd")


## B 级及以上兑换来的属性按基因锁发挥率打折：0 阶 50%，四阶 100%（设计规格 3.4）。
func test_high_grade_attributes_scaled_by_gene_lock() -> void:
	var c := Character.new("zz", "郑吒", {})
	c.attributes.add_enhanced_high("muscle", 100.0)
	c.attributes.add_enhanced("muscle", 10.0)
	assert_almost(c.attributes.total("muscle"), 100.0 + 10.0 + 50.0)
	c.gene_lock_stage = 1
	assert_almost(c.attributes.total("muscle"), 100.0 + 10.0 + 70.0)
	c.gene_lock_stage = 4
	assert_almost(c.attributes.total("muscle"), 210.0)


func test_attributes_round_trip_with_high() -> void:
	var a := Attributes.new()
	a.add_enhanced_high("nerve_reaction", 100.0)
	var b := Attributes.new()
	b.load_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	assert_almost(float(b.enhanced_high["nerve_reaction"]), 100.0)


## 计划 1 的旧存档没有 enhanced_high，读取时按 0 处理。
func test_old_attribute_save_loads() -> void:
	var a := Attributes.new()
	a.load_dict({"base": a.base.duplicate(), "enhanced": a.enhanced.duplicate()})
	assert_almost(a.total("spirit"), 100.0)


func test_character_new_fields_round_trip() -> void:
	var c := Character.new("zz", "郑吒", {})
	c.owned.append("qigong_low")
	c.skills.append("desert_eagle")
	c.abilities.append("red_flame")
	c.proficiency["desert_eagle"] = 0.5
	c.energy["neili"] = 30.0
	c.items["grenade"] = 2.0
	c.gene_lock_stage = 2
	var d := Character.new()
	d.load_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(d.owned, ["qigong_low"] as Array[String])
	assert_eq(d.skills, ["desert_eagle"] as Array[String])
	assert_eq(d.abilities, ["red_flame"] as Array[String])
	assert_almost(float(d.proficiency["desert_eagle"]), 0.5)
	assert_almost(float(d.energy["neili"]), 30.0)
	assert_almost(float(d.items["grenade"]), 2.0)
	assert_almost(d.attributes.high_mult, 0.85)


func test_battle_resources() -> void:
	var c := Character.new("zz", "郑吒", {})
	c.energy["neili"] = 30.0
	c.items["grenade"] = 2.0
	assert_eq(c.battle_resources(), {"neili": 30.0, "grenade": 2.0})


func test_companions_saved() -> void:
	var g := GameState.new(1)
	g.companions.append({"id": "loli", "name": "萝丽", "creator": "zheng_zha", "attributes": {}})
	var h := GameState.new(2)
	h.load_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	assert_eq(h.companions[0]["name"], "萝丽")
```

- [ ] **Step 2：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_hub_model bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`共 6 个测试，失败 5 个`（只有 `test_old_attribute_save_loads` 是 `ok`），`!! 检测到脚本错误`，`exit=1`。

- [ ] **Step 3：改写 `game/core/model/attributes.gd`**（整个文件替换成下面的内容）

```gdscript
extends RefCounted
## 六项基础属性（原著）：智力、精神力、细胞活力、神经反应速度、肌肉组织强度、免疫力强度。常人各约 100。
## base = 自身（天生 + 锻炼，主神评价看不见锻炼部分）；enhanced = 在主神处兑换来的强化量（10 点奖励点数 = 1 点）。
## enhanced_high = B 级及以上兑换项带来的属性，按基因锁发挥率 high_mult 打折（设计规格 3.4），由角色按基因锁阶数设置。

const KEYS: Array[String] = ["intelligence", "spirit", "cell_vitality", "nerve_reaction", "muscle", "immunity"]

var base: Dictionary = {}
var enhanced: Dictionary = {}
var enhanced_high: Dictionary = {}
var high_mult: float = 1.0


func _init(values: Dictionary = {}) -> void:
	for k in KEYS:
		base[k] = float(values.get(k, 100.0))
		enhanced[k] = 0.0
		enhanced_high[k] = 0.0


func total(key: String) -> float:
	return float(base[key]) + float(enhanced[key]) + float(enhanced_high[key]) * high_mult


func add_enhanced(key: String, amount: float) -> void:
	enhanced[key] = float(enhanced[key]) + amount


func add_enhanced_high(key: String, amount: float) -> void:
	enhanced_high[key] = float(enhanced_high[key]) + amount


func add_trained(key: String, amount: float) -> void:
	base[key] = float(base[key]) + amount


func to_dict() -> Dictionary:
	return {"base": base.duplicate(), "enhanced": enhanced.duplicate(), "enhanced_high": enhanced_high.duplicate()}


func load_dict(d: Dictionary) -> void:
	var high: Dictionary = d.get("enhanced_high", {})
	for k in KEYS:
		base[k] = float(d["base"][k])
		enhanced[k] = float(d["enhanced"][k])
		enhanced_high[k] = float(high.get(k, 0.0))
```

- [ ] **Step 4：改写 `game/core/model/character.gd`**（整个文件替换成下面的内容）

```gdscript
extends RefCounted
## 一个轮回者。点数和支线是个人的（原著里每人各自结算、各自兑换）。

const Attributes = preload("res://core/model/attributes.gd")
const PlotTickets = preload("res://core/economy/plot_tickets.gd")
const DerivedStats = preload("res://core/model/derived_stats.gd")
const GeneLock = preload("res://core/model/gene_lock.gd")

var id: String = ""
var display_name: String = ""
var attributes: RefCounted = Attributes.new()
var tickets: RefCounted = PlotTickets.new()
var points: int = 0
## 改阶数时同步 B 级及以上兑换属性的发挥率（设计规格 3.4）。
var gene_lock_stage: int = 0:
	set(value):
		gene_lock_stage = value
		if attributes != null:
			attributes.high_mult = GeneLock.effectiveness(value)
var fear: float = 0.0
var hp: float = 0.0
var alive: bool = true
var films_completed: int = 0
var revived_once: bool = false
var flags: Dictionary = {}
## 已兑换的兑换项 id（不含消耗品）。
var owned: Array[String] = []
## 战斗技能 id（battle/skills.json）。
var skills: Array[String] = []
## 还不能在战斗里直接用的能力（以后的计划逐步接入），例如红炎、轻功。
var abilities: Array[String] = []
## 技能熟练度 0~1：A 级以上兑换来的"只是心法"，要训练才能发挥（设计规格 6.2）。
var proficiency: Dictionary = {}
## 能量池上限，例如 {"neili": 30, "blood": 30}。
var energy: Dictionary = {}
## 道具数量，例如 {"grenade": 2}。
var items: Dictionary = {}


func _init(char_id: String = "", name: String = "", attr_values: Dictionary = {}) -> void:
	id = char_id
	display_name = name
	attributes = Attributes.new(attr_values)
	gene_lock_stage = 0
	hp = hp_max()


func hp_max() -> float:
	return float(DerivedStats.compute(attributes)["hp_max"])


## 原著：未完成过任何一部片的人算新人（复活免费）。
func is_newbie() -> bool:
	return films_completed == 0


## 带进战斗的资源：能量池加道具。
func battle_resources() -> Dictionary:
	var out := energy.duplicate()
	for k: String in items:
		out[k] = float(out.get(k, 0.0)) + float(items[k])
	return out


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"attributes": attributes.to_dict(),
		"tickets": tickets.to_dict(),
		"points": points,
		"gene_lock_stage": gene_lock_stage,
		"fear": fear,
		"hp": hp,
		"alive": alive,
		"films_completed": films_completed,
		"revived_once": revived_once,
		"flags": flags.duplicate(true),
		"owned": owned.duplicate(),
		"skills": skills.duplicate(),
		"abilities": abilities.duplicate(),
		"proficiency": proficiency.duplicate(),
		"energy": energy.duplicate(),
		"items": items.duplicate(),
	}


func load_dict(d: Dictionary) -> void:
	id = String(d["id"])
	display_name = String(d["display_name"])
	attributes.load_dict(d["attributes"])
	tickets.load_dict(d["tickets"])
	points = int(d["points"])
	gene_lock_stage = int(d["gene_lock_stage"])
	fear = float(d["fear"])
	hp = float(d["hp"])
	alive = bool(d["alive"])
	films_completed = int(d["films_completed"])
	revived_once = bool(d["revived_once"])
	flags = (d["flags"] as Dictionary).duplicate(true)
	owned.assign(d.get("owned", []))
	skills.assign(d.get("skills", []))
	abilities.assign(d.get("abilities", []))
	proficiency = (d.get("proficiency", {}) as Dictionary).duplicate()
	energy = (d.get("energy", {}) as Dictionary).duplicate()
	items = (d.get("items", {}) as Dictionary).duplicate()
```

- [ ] **Step 5：改写 `game/core/model/game_state.gd`**（整个文件替换成下面的内容：加了 `companions` 和它的存读档）

```gdscript
extends RefCounted
## 整局游戏状态。存档就是它的 to_dict()。

const Rng = preload("res://core/util/rng.gd")
const Character = preload("res://core/model/character.gd")

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
```

- [ ] **Step 6：运行，确认通过**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_hub_model bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`共 6 个测试，失败 0 个`，`exit=0`。再跑全部测试，确认前三个计划的测试没受影响：`bash game/tools/run_tests.sh; echo "exit=$?"`，预期 `共 184 个测试，失败 0 个`，`exit=0`。

- [ ] **Step 7：提交**

```bash
git add game/core/model/attributes.gd game/core/model/character.gd game/core/model/game_state.gd game/tests/unit/hub/test_hub_model.gd
git commit -m "feat(model): B 级以上属性受基因锁发挥率影响；角色加上兑换项、技能、能量、道具；造物列表" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

### Task 2：定价公式与兑换目录

**Files:**
- Create: `game/data/hub/hub_rules.json`、`game/data/hub/exchange_catalog.json`、`game/core/hub/pricing.gd`、`game/core/hub/catalog.gd`
- Test: `game/tests/unit/hub/test_pricing.gd`、`game/tests/unit/hub/test_catalog.gd`

- [ ] **Step 1：写测试 `game/tests/unit/hub/test_pricing.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Pricing = preload("res://core/hub/pricing.gd")
const Catalog = preload("res://core/hub/catalog.gd")

## 原著出现过的价格（mechanics.md 第 3.3、4 节）。公式必须从积木把它们算对。
const NOVEL_PRICES := {
	"qigong_low": [500, "D"],
	"qigong_mid": [1200, "C"],
	"qigong_high": [2500, "B"],
	"vampire_baron": [800, "D"],
	"vampire_viscount": [1500, "C"],
	"vampire_count": [3000, "B"],
	"spider_gene": [2000, "B"],
	"t_virus": [1500, "C"],
	"werewolf_high": [2700, "B"],
	"eagle_eye": [1000, "C"],
	"elf_wind_archer": [2000, "C"],
	"red_flame": [2000, "C"],
	"light_kungfu": [2000, "C"],
	"mind_scan": [4000, "C"],
	"mind_focus": [2500, "B"],
	"desert_eagle": [100, ""],
	"gauss_pistol": [1500, "D"],
	"gauss_sniper": [5000, "D"],
	"shield_plate": [1500, "D"],
	"na_ring": [1500, "D"],
	"purifying_sword": [1000, ""],
	"bingning_dan": [1000, "D"],
	"rebirth_cross": [7000, "2B"],
}


func test_novel_prices() -> void:
	for id: String in NOVEL_PRICES:
		var p := Pricing.price(Catalog.entry(id))
		assert_eq(p, {"points": int(NOVEL_PRICES[id][0]), "tier": String(NOVEL_PRICES[id][1])}, id)


## 10 点 = 1 点属性。
func test_attribute_rate() -> void:
	var e := {"category": "enhance", "blocks": [{"attr": {"muscle": 30, "spirit": 20}}]}
	assert_almost(Pricing.value(e), 500.0)
	assert_eq(Pricing.price(e), {"points": 500, "tier": ""})


## 魔法传说类约为科技类的 2 倍；属性积木不翻倍。
func test_magic_doubles() -> void:
	var tech := {"category": "tech", "blocks": [{"passive": "x", "value": 600}]}
	var magic := {"category": "magic", "blocks": [{"passive": "x", "value": 600}, {"attr": {"spirit": 10}}]}
	assert_almost(Pricing.value(tech), 600.0)
	assert_almost(Pricing.value(magic), 1300.0)


## 无限弹药是有限版的 20 倍。
func test_unlimited_ammo() -> void:
	var limited := {"category": "tech", "blocks": [{"ability": "missile", "value": 50}]}
	var unlimited := {"category": "tech", "blocks": [{"ability": "missile", "value": 50, "unlimited": true}]}
	assert_almost(Pricing.value(unlimited), Pricing.value(limited) * 20.0)


func test_side_effect_discount() -> void:
	var e := {"category": "enhance", "blocks": [{"passive": "rage", "value": 3000}, {"side_effect": "berserk", "discount": 0.8}]}
	assert_almost(Pricing.value(e), 2400.0)


func test_tier_parsing() -> void:
	assert_eq(Pricing.parse_tier("2B"), {"grade": "B", "count": 2})
	assert_eq(Pricing.parse_tier("D"), {"grade": "D", "count": 1})
	assert_eq(Pricing.parse_tier(""), {"grade": "", "count": 0})
	assert_eq(Pricing.parse_tier("Z")["grade"], "?")
	assert_true(Pricing.tier_rank("2B") > Pricing.tier_rank("B"))
	assert_true(Pricing.tier_rank("A") > Pricing.tier_rank("2B"))
	assert_almost(Pricing.ticket_worth("2B"), 4800.0)


## 等级取积木里最高的档次。
func test_tier_is_highest_block() -> void:
	var e := {"category": "enhance", "blocks": [{"passive": "a", "value": 1000, "tier": "D"}, {"passive": "b", "value": 2000, "tier": "C"}]}
	assert_eq(Pricing.tier_of(e), "C")
	assert_eq(Pricing.price(e), {"points": 1600, "tier": "C"})
```

- [ ] **Step 2：写测试 `game/tests/unit/hub/test_catalog.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Catalog = preload("res://core/hub/catalog.gd")


func test_catalog_valid() -> void:
	var errors := Catalog.validate()
	assert_eq(errors.size(), 0, "\n".join(errors))


## 设计规格 9.6 的 M1 首批清单都在目录里。
func test_m1_first_batch_present() -> void:
	for id in ["qigong_low", "vampire_baron", "qigong_mid", "vampire_viscount", "t_virus", "spider_gene", "qigong_high", "werewolf_high", "vampire_count", "na_ring", "desert_eagle", "grenade", "first_aid_spray", "antidote"]:
		assert_true(Catalog.has(id), id)


## 原著：高级需要同系低级作前置。
func test_prerequisite_chains() -> void:
	assert_eq(Catalog.entry("qigong_high")["requires"], ["qigong_mid"])
	assert_eq(Catalog.entry("vampire_count")["requires"], ["vampire_viscount"])
	assert_eq(Catalog.entry("na_ring")["requires_energy"], "neili")


func test_by_category() -> void:
	var items := Catalog.by_category("item")
	assert_true(items.has("rebirth_cross"))
	assert_false(items.has("spider_gene"))
	assert_true(Catalog.by_category("magic").has("na_ring"))
```

- [ ] **Step 3：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_pricing bash game/tools/run_tests.sh; echo "exit=$?"`，再运行 `WSLENV=TEST_FILTER TEST_FILTER=test_catalog bash game/tools/run_tests.sh; echo "exit=$?"`

预期：两次都是对应文件 `FAIL ...（脚本无法加载）`，`!! 检测到脚本错误`，`exit=1`。

- [ ] **Step 4：创建 `game/data/hub/hub_rules.json`**

```json
{
	"version": 1,
	"ticket_value": {"D": 500, "C": 1400, "B": 2400, "A": 7000, "S": 20000},
	"category_mult": {"tech": 1.0, "magic": 2.0, "enhance": 1.0, "item": 1.0},
	"unlimited_mult": 20,
	"high_grade_from": "B",
	"low_proficiency_from": "A",
	"new_high_skill_proficiency": 0.3,
	"mutation_chance": 0.7,
	"human": {"cost": 500, "attr_max": 200},
	"repair": {"patch_cost": 400, "full_cost": 2000, "patch_hp_ratio": 0.5},
	"rest": {"days_default": 10, "fear_relief_per_day": 15},
	"train": {"proficiency_per_day": 0.25}
}
```

- [ ] **Step 5：创建 `game/data/hub/exchange_catalog.json`**

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
			"gates": {"attr_min": {"spirit": 300}, "talent_bypass": "spirit_talent"},
			"price": {"points": 4000, "tier": "C"}, "source": "L4740",
			"note": "门槛数值是占位，计划 7 按原著核对",
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

- [ ] **Step 6：创建 `game/core/hub/pricing.gd`**

```gdscript
extends RefCounted
## 兑换定价公式（设计规格 7.2，核心机制分析 4.4）。兑换项由效果积木组成，公式把积木换算成"价值"，再拆成支线等级和点数。
## 原著规律：
##   - 属性积木：10 点 = 1 点属性；
##   - 无限弹药（unlimited）× 20；
##   - 魔法传说类（magic）× 2（只乘非属性积木）；
##   - 有副作用的打折（side_effect 积木的 discount）；
## 等级 = 积木里最高的 tier（这件东西的"档次"），点数 = 价值 − 所需支线的折算值（D 500、C 1400、B 2400）。
## 折算值用原著三件纯属性的兑换项标定：低级气功 500+D、T 病毒 1500+C、蜘蛛侠基因 2000+B。A、S 的折算值还没有原著锚点，先占位。
## tier 写法："" 不要支线；"D"、"C"、"B"、"A"、"S"；"2B" 表示两个 B（原著的双 B）。

const DataLoader = preload("res://core/util/data_loader.gd")
const Rules = preload("res://core/util/rules.gd")

const RULES_PATH := "res://data/hub/hub_rules.json"
const GRADES: Array[String] = ["D", "C", "B", "A", "S"]

static var _rules: Dictionary = {}


static func rules() -> Dictionary:
	if _rules.is_empty():
		var res := DataLoader.load_json(RULES_PATH)
		assert(res.ok, res.error)
		_rules = res.data
	return _rules


## "2B" → {"grade": "B", "count": 2}；"" → {"grade": "", "count": 0}。写错时 grade 为 "?"。
static func parse_tier(tier: String) -> Dictionary:
	if tier == "":
		return {"grade": "", "count": 0}
	var count := 1
	var grade := tier
	if tier.length() == 2 and tier[0].is_valid_int():
		count = tier[0].to_int()
		grade = tier[1]
	if not GRADES.has(grade) or count < 1:
		return {"grade": "?", "count": 0}
	return {"grade": grade, "count": count}


## 用于比较高低：先比等级，再比个数。
static func tier_rank(tier: String) -> int:
	var t := parse_tier(tier)
	if t["count"] == 0:
		return 0
	return (GRADES.find(String(t["grade"])) + 1) * 10 + int(t["count"])


static func ticket_worth(tier: String) -> float:
	var t := parse_tier(tier)
	if int(t["count"]) == 0:
		return 0.0
	return float(rules()["ticket_value"][t["grade"]]) * int(t["count"])


static func block_value(block: Dictionary, category: String) -> float:
	if block.has("attr"):
		var sum := 0.0
		for k: String in block["attr"]:
			sum += float(block["attr"][k])
		return sum * float(Rules.get_rules()["points_per_attribute"])
	var mult := float(rules()["category_mult"].get(category, 1.0))
	if block.has("item"):
		return float(block["count"]) * float(block["unit_value"]) * mult
	var v := float(block.get("value", 0.0))
	if bool(block.get("unlimited", false)):
		v *= float(rules()["unlimited_mult"])
	return v * mult


static func value(entry: Dictionary) -> float:
	var total := 0.0
	var discount := 1.0
	for b: Dictionary in entry["blocks"]:
		if b.has("side_effect"):
			discount *= float(b["discount"])
		else:
			total += block_value(b, String(entry["category"]))
	return total * discount


## 积木里最高的 tier。
static func tier_of(entry: Dictionary) -> String:
	var best := ""
	for b: Dictionary in entry["blocks"]:
		var t := String(b.get("tier", ""))
		if tier_rank(t) > tier_rank(best):
			best = t
	return best


## 公式算出的价格 {"points": int, "tier": String}。
static func price(entry: Dictionary) -> Dictionary:
	var tier := tier_of(entry)
	return {"points": roundi(value(entry) - ticket_worth(tier)), "tier": tier}
```

- [ ] **Step 7：创建 `game/core/hub/catalog.gd`**

```gdscript
extends RefCounted
## 兑换目录（data/hub/exchange_catalog.json）。每一项：名字、大类、系列、价格、效果积木，以及前置、能量要求、素质门槛、是否血统、是否消耗品。
## 大类：tech（科技）、magic（魔法传说）、enhance（强化：血统、内功、技能）、item（道具与消耗品）。
## 目录里写的价格必须和定价公式算出来的一致（原著价格就是这样被锁住的）。

const DataLoader = preload("res://core/util/data_loader.gd")
const BattleData = preload("res://core/battle/battle_data.gd")
const Pricing = preload("res://core/hub/pricing.gd")

const PATH := "res://data/hub/exchange_catalog.json"
const REQUIRED: Array[String] = ["name", "category", "series", "price", "blocks"]
const CATEGORIES: Array[String] = ["tech", "magic", "enhance", "item"]
const BLOCK_KINDS: Array[String] = ["attr", "energy", "skill", "ability", "passive", "item", "side_effect"]

static var _cache: Dictionary = {}


static func entries() -> Dictionary:
	if _cache.is_empty():
		var res := DataLoader.load_json(PATH)
		assert(res.ok, res.error)
		_cache = res.data["entries"]
	return _cache


static func has(id: String) -> bool:
	return entries().has(id)


static func entry(id: String) -> Dictionary:
	return entries()[id]


static func by_category(category: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in entries():
		if entries()[id]["category"] == category:
			out.append(id)
	return out


static func validate() -> Array[String]:
	var errors: Array[String] = []
	for id: String in entries():
		var e: Dictionary = entries()[id]
		var missing := DataLoader.missing_keys(e, REQUIRED, "兑换项 " + id)
		if not missing.is_empty():
			errors.append_array(missing)
			continue
		if not CATEGORIES.has(String(e["category"])):
			errors.append("兑换项 %s 的大类无效" % id)
		for r: String in e.get("requires", []):
			if not has(r):
				errors.append("兑换项 %s 的前置 %s 不存在" % [id, r])
		for b: Dictionary in e["blocks"]:
			var kinds := 0
			for k in BLOCK_KINDS:
				if b.has(k):
					kinds += 1
			if kinds != 1:
				errors.append("兑换项 %s 有一块积木的类型不明确" % id)
			if b.has("skill") and not BattleData.skills().has(String(b["skill"])):
				errors.append("兑换项 %s 的技能 %s 不在战斗技能里" % [id, b["skill"]])
			if Pricing.parse_tier(String(b.get("tier", "")))["grade"] == "?":
				errors.append("兑换项 %s 的 tier 写法无效" % id)
		var expected := Pricing.price(e)
		var listed: Dictionary = e["price"]
		if int(listed["points"]) != int(expected["points"]) or String(listed["tier"]) != String(expected["tier"]):
			errors.append("兑换项 %s 的价格 %s 和公式 %s 不一致" % [id, listed, expected])
		if int(expected["points"]) < 0:
			errors.append("兑换项 %s 的点数为负" % id)
	return errors
```

- [ ] **Step 8：运行，确认通过**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_pricing bash game/tools/run_tests.sh; echo "exit=$?"`，再运行 `WSLENV=TEST_FILTER TEST_FILTER=test_catalog bash game/tools/run_tests.sh; echo "exit=$?"`

预期：第一次 `共 7 个测试，失败 0 个`，第二次 `共 4 个测试，失败 0 个`，都是 `exit=0`。

- [ ] **Step 9：提交**

```bash
git add game/data/hub/hub_rules.json game/data/hub/exchange_catalog.json game/core/hub/pricing.gd game/core/hub/catalog.gd game/tests/unit/hub/test_pricing.gd game/tests/unit/hub/test_catalog.gd
git commit -m "feat(hub): 效果积木定价公式与兑换目录（23 件原著价格锚点）" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

### Task 3：兑换

**Files:**
- Create: `game/core/hub/exchange.gd`
- Test: `game/tests/unit/hub/test_exchange.gd`

- [ ] **Step 1：写测试 `game/tests/unit/hub/test_exchange.gd`**

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
	c.flags["talents"] = ["spirit_talent"]
	assert_true(bool(Exchange.check(c, "mind_scan")["ok"]))


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

预期：`FAIL  res://tests/unit/hub/test_exchange.gd（脚本无法加载）`，`!! 检测到脚本错误`，`exit=1`。

- [ ] **Step 3：创建 `game/core/hub/exchange.gd`**

```gdscript
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
```

- [ ] **Step 4：运行，确认通过**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_exchange bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`共 10 个测试，失败 0 个`，`exit=0`。

- [ ] **Step 5：提交**

```bash
git add game/core/hub/exchange.gd game/tests/unit/hub/test_exchange.gd
git commit -m "feat(hub): 兑换门槛、代兑与双血统风险" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

### Task 4：休整

**Files:**
- Create: `game/core/hub/hub.gd`
- Test: `game/tests/unit/hub/test_hub.gd`

- [ ] **Step 1：写测试 `game/tests/unit/hub/test_hub.gd`**

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
```

- [ ] **Step 2：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_hub.gd bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`FAIL  res://tests/unit/hub/test_hub.gd（脚本无法加载）`，`!! 检测到脚本错误`，`exit=1`。

- [ ] **Step 3：创建 `game/core/hub/hub.gd`**

```gdscript
extends RefCounted
## 主神空间的一次休整（设计规格 6.2~6.4）。休整天数是行动点：兑换、结算、造人、修复不耗天；训练、休息耗天。
## 原著惯例：回归当晚（第 0 天）不兑换，只结算和造人；最后一天强制休息，不能训练；每天恐惧自然下降。
## 代兑：每人每次休整只能用自己的点数或支线给别人兑换一次（设计规格 6.3）。

const Exchange = preload("res://core/hub/exchange.gd")
const Pricing = preload("res://core/hub/pricing.gd")
const Rules = preload("res://core/util/rules.gd")

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
	if gift and events[0]["type"] == "exchange_done":
		gifts[payer_id] = true
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
	return _emit([{"type": "attribute_bought", "char": char_id, "attr": attr, "amount": amount, "cost": cost}])


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
	return _emit([{"type": "human_created", "creator": creator_id, "companion": companion, "cost": cost}])


## 训练：花天数提升已有技能或能力的熟练度。最后一天强制休息，不能占用。
func train(char_id: String, skill_id: String, days: int) -> Array[Dictionary]:
	var ch := _char(char_id)
	if not ch.skills.has(skill_id) and not ch.abilities.has(skill_id):
		return _refuse("unknown_skill")
	if days <= 0 or day + days > days_total - 1:
		return _refuse("no_days")
	var gain := float(Pricing.rules()["train"]["proficiency_per_day"]) * days
	ch.proficiency[skill_id] = minf(1.0, float(ch.proficiency.get(skill_id, 1.0)) + gain)
	var events: Array[Dictionary] = [{"type": "trained", "char": char_id, "skill": skill_id, "days": days, "proficiency": ch.proficiency[skill_id]}]
	_pass_days(days, events)
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


func to_dict() -> Dictionary:
	return {"days_total": days_total, "day": day, "gifts": gifts.duplicate()}


func load_dict(d: Dictionary, game_state: RefCounted) -> void:
	game = game_state
	days_total = int(d["days_total"])
	day = int(d["day"])
	gifts = (d["gifts"] as Dictionary).duplicate()
```

- [ ] **Step 4：运行，确认通过**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_hub.gd bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`共 9 个测试，失败 0 个`，`exit=0`。

- [ ] **Step 5：提交**

```bash
git add game/core/hub/hub.gd game/tests/unit/hub/test_hub.gd
git commit -m "feat(hub): 休整：天数、训练、修复、造人、属性强化、支线拆合" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

### Task 5：全量验证与 uid 文件

- [ ] **Step 1：跑全部测试**

Run: `bash game/tools/run_tests.sh; echo "exit=$?"`

预期：结尾为 `共 214 个测试，失败 0 个`，`exit=0`，输出里没有 `SCRIPT ERROR`。

- [ ] **Step 2：导入工程**

Run: `godot --headless --path game --import; echo "exit=$?"`

预期：`exit=0`。

- [ ] **Step 3：查看新生成的 uid 文件**

Run: `git status --short`

预期：除了 `?? _work/`，正好是下面 9 行（顺序可能不同）：

```text
?? game/core/hub/catalog.gd.uid
?? game/core/hub/exchange.gd.uid
?? game/core/hub/hub.gd.uid
?? game/core/hub/pricing.gd.uid
?? game/tests/unit/hub/test_catalog.gd.uid
?? game/tests/unit/hub/test_exchange.gd.uid
?? game/tests/unit/hub/test_hub.gd.uid
?? game/tests/unit/hub/test_hub_model.gd.uid
?? game/tests/unit/hub/test_pricing.gd.uid
```

- [ ] **Step 4：提交 uid 文件**

```bash
git add game/core/hub/*.gd.uid game/tests/unit/hub/*.gd.uid
git commit -m "chore: 纳入计划 4 新脚本的 uid 文件" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
git log --oneline -6
```

预期：`git status --short` 只剩 `?? _work/`；`git log --oneline -6` 最上面 5 个是本计划的提交（Task 1~4 各一个，加上 uid 一个），第 6 个是提交本计划的 `docs: 计划 4 兑换与主神空间`。**不要推送。**
