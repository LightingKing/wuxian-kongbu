# 计划 2：战斗内核 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `game/core/battle/` 做出完整的战斗规则内核：三排战场、行动时间轴（CTB）、数据驱动的技能和状态、命中与伤害、恐惧与基因锁觉醒、恐慌、死亡与复活道具、确定性效用 AI 与敌人意图、战斗控制器和战斗模拟，全部有无界面测试。

**Architecture:** 和计划 1 一样，core 层是纯逻辑（`RefCounted` + `preload`，不用 `class_name`）。技能、状态、敌人、规则常量都在 JSON 里。战斗控制器 `battle.gd` 接收单位和玩家行动，输出一串事件（字典），界面以后只按事件播放表现。所有随机都走带种子的 `rng.gd`；公式函数把随机数当参数传入，测试时可以直接给定。

**Tech Stack:** Godot 4.7.2（GDScript）、bash。

**依据：** 设计规格 `docs/superpowers/specs/2026-11-05-wuxian-kongbu-game-design.md`（v0.8）第 3.2、3.4、3.5、4、8、10.2、10.4 节；计划 1 的 `character.gd`、`derived_stats.gd`、`rng.gd`、测试体系。

**本计划的全部代码都已在临时目录里实际跑通（加上计划 1 的 32 个，共 119 个测试全部通过），照抄即可。**

**执行环境注意：**
- 仓库根目录：Windows 上是 `I:\workspace\mobilegame\wuxian-kongbu\`；在 WSL 的 bash 里是 `/mnt/i/workspace/mobilegame/wuxian-kongbu`。所有命令都在仓库根目录执行。
- 只跑某个测试文件时用 `WSLENV=TEST_FILTER TEST_FILTER=<文件名> bash game/tools/run_tests.sh`。`WSLENV` 让 WSL 把 `TEST_FILTER` 传给 Windows 版 Godot；在 Git Bash 里多写它也没有影响。`TEST_FILTER` 按路径子串匹配，所以控制器测试写成 `test_battle.gd`（带扩展名），免得把 `test_battle_data.gd` 等也匹配进来。
- 所有文本文件用 **LF** 换行、UTF-8 无 BOM；GDScript 代码块用 **Tab** 缩进，照抄时保留 Tab。字符串里的 `\t` 是反斜杠加 t 两个字符，不要写成真正的 Tab。
- **"确认失败"那一步**：被测文件还不存在，输出里除了 `FAIL  ...（脚本无法加载）`，前面还会有几行 `SCRIPT ERROR: Parse Error: ...`，最后是 `!! 检测到脚本错误`。这都是预期的。
- 跑测试不会生成 `.gd.uid` 文件，导入工程（Task 8）才会。Task 8 把这些文件一起提交。
- **只提交，不推送。** 推送由 Claude 验收后做。

---

## 设计要点

- **单位**（`battle_unit.gd`）：轮回者、剧情人物、敌人都是同一种单位。`side` 是 `"ally"` 或 `"enemy"`；`row` 是 0 前排、1 中排、2 后排；`controller` 是 `"player"`（玩家下令）或 `"ai"`。轮回者从 `character.gd` 转来（`unit_factory.gd`），战后把生命、恐惧、基因锁、生死写回去。
- **行动**统一写成字典，玩家和 AI 用同一种格式：
  - `{"type": "skill", "skill": 技能 id, "targets": [单位 id, ...]}`
  - `{"type": "move", "row": 目标排}`、`{"type": "defend"}`、`{"type": "gene_lock"}`、`{"type": "retreat"}`
- **前排**：最前面还有人的那一排。近战只能打对方前排；前排打空了，中排就顶上来。
- **行动时间轴**：下次行动时间 = 当前时间 + 10000 × 倍率 ÷ 速度。速度 200 的单位每行动两次，速度 100 的行动一次。换位倍率 0.6，防御 0.8。第一次行动按先手倍率算（爬行者 0.3）。
- **状态的时间规则**：每次轮到持有者行动时，先结算持续伤害，再把剩余次数减 1，减到 0 就结束。所以 duration = N 表示"到持有者第 N 次轮到自己时结束"：防御（1）挡到下次轮到自己为止；流血（3）跳 3 次伤害；感染（5）到第 5 次轮到自己时变丧尸。
- **冷却**：用完技能后，接下来 N 次轮到自己都不能用。
- **恐惧**：敌人登场（每只的 `fear_aura`）、队友死亡（+20）、一次掉血超过生命上限 25%（+10）、黑暗中每次轮到自己（+4）。增加量按精神力折算（精神力 200 只涨一半）。恐惧满时检定一次：先看觉醒，再看崩溃（恐慌），都没中就硬撑过去；恐惧降下来以后再满会再检定。
- **基因锁觉醒**：只有轮回者有。生命第一次低于 25% 时检定一次；恐惧满时也检定。概率 = 0.02 + 潜力 × 0.4 + (精神力 − 100) × 0.001 + 恐惧 × 0.001，资深者再加 0.05，上限 0.9。觉醒后基因锁升一阶（战斗里最多到三阶），进入基因锁状态（速度、攻击 ×1.5，屏蔽痛觉），恐惧回落到 30，战后有后遗症（`aftereffect`，由远征层处理）。二阶起可以主动开启。
- **恐慌**：不听指挥。发呆 40%，往后逃 30%（已经在后排就逃离战场），其余对随便一个人出手（可能误伤队友）。
- **死亡**：生命归零即死亡。带着重生十字章（资源 `rebirth_cross`）的，消耗一次，以 30% 生命复活。感染变丧尸不能复活。
- **效用 AI**：给每个合法行动打分取最高分，同分取先出现的，所以同一局面总是同一个选择。敌人行动完就定好下一步（`intent`）；轮到它时，如果意图还合法就照做，否则重新选。界面按情报等级显示意图：0 只知道大类，1 知道技能，2 还知道目标。
- **随机数顺序**：命中判定、伤害浮动、附加状态的概率、觉醒和崩溃检定、恐慌行为都从同一个 `rng` 依次取数，所以同一个种子总是同一场战斗。

**不在本计划范围**（后续计划处理）：剧情战斗的特殊行动（激光通道的"卧倒""贴门"）、后遗症的具体效果、击杀奖励接入结算（计划 3）；三阶"模拟"技能、按智力加噪声的意图准确度（计划 5）；M1 完整的技能和敌人数值（计划 7）；战斗界面（计划 8）。

---

## 文件结构（本计划创建）

| 文件 | 职责 |
|---|---|
| `game/data/rules/battle_rules.json` | 战斗规则常量：排数、容量、时间轴、命中、伤害浮动、恐惧、基因锁、崩溃、恐慌、复活、行动上限 |
| `game/data/battle/skills.json` | 技能：拳脚、手枪、沙漠之鹰、手榴弹、气功掌、止血喷雾、解毒剂、鼓舞，以及丧尸、丧尸犬、爬行者的技能 |
| `game/data/battle/statuses.json` | 状态：流血、感染、防御、恐慌、眩晕、基因锁、失明、酸蚀 |
| `game/data/battle/enemies.json` | M1 敌人：丧尸、丧尸犬、爬行者 |
| `game/core/battle/battle_data.gd` | 加载并缓存上面四个文件，检查引用是否有效 |
| `game/core/battle/statuses.gd` | 状态的施加、移除、修正值、每回合结算 |
| `game/core/battle/battle_unit.gd` | 战斗单位 |
| `game/core/battle/unit_factory.gd` | 从轮回者或敌人数据创建单位，战后写回 |
| `game/core/battle/battlefield.gd` | 三排战场：放置、容量、前排、换位 |
| `game/core/battle/ctb.gd` | 行动时间轴与预览 |
| `game/core/battle/combat_math.gd` | 命中率与伤害公式 |
| `game/core/battle/fear.gd` | 恐惧增减、觉醒与崩溃检定 |
| `game/core/battle/targeting.gd` | 技能可用性、可选目标、合法行动列表 |
| `game/core/battle/utility_ai.gd` | 效用 AI 与意图显示 |
| `game/core/battle/battle.gd` | 战斗控制器：回合推进、行动结算、事件、胜负 |
| `game/core/battle/battle_sim.gd` | AI 对 AI 的批量战斗模拟 |
| `game/tests/unit/battle/test_*.gd` | 各模块的测试（11 个文件，87 个测试） |

---

### Task 1：战斗数据

**Files:**
- Create: `game/data/rules/battle_rules.json`、`game/data/battle/skills.json`、`game/data/battle/statuses.json`、`game/data/battle/enemies.json`、`game/core/battle/battle_data.gd`
- Test: `game/tests/unit/battle/test_battle_data.gd`

- [ ] **Step 1：写测试 `game/tests/unit/battle/test_battle_data.gd`**

```gdscript
extends "res://tests/test_case.gd"

const BattleData = preload("res://core/battle/battle_data.gd")


func test_all_data_valid() -> void:
	var errors := BattleData.validate()
	assert_eq(errors.size(), 0, str(errors))


func test_m1_enemies_present() -> void:
	for id in ["zombie", "zombie_dog", "licker"]:
		assert_true(BattleData.enemies().has(id), id)


## 原著：爬行者是精英，手枪几乎无效。
func test_licker_resists_bullets() -> void:
	var licker := BattleData.enemy("licker")
	assert_almost(float(licker["tag_mult"]["bullet"]), 0.15)
	assert_true((licker["flags"] as Array).has("ignores_darkness"))


## 原著：被丧尸咬到会感染。
func test_zombie_bite_infects() -> void:
	var applies: Array = BattleData.skill("zombie_bite")["applies"]
	assert_eq(String(applies[0]["status"]), "infection")


func test_rules_values() -> void:
	var r := BattleData.rules()
	assert_eq(int(r["rows"]), 3)
	assert_eq(int(r["row_capacity_default"]), 4)
	assert_eq(int(r["ctb_base_delay"]), 10000)
```

- [ ] **Step 2：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_battle_data bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`FAIL  res://tests/unit/battle/test_battle_data.gd（脚本无法加载）`，`!! 检测到脚本错误`，`exit=1`。

- [ ] **Step 3：创建 `game/data/rules/battle_rules.json`**

```json
{
	"version": 1,
	"rows": 3,
	"row_capacity_default": 4,
	"ctb_base_delay": 10000,
	"hit": {
		"min": 0.05,
		"max": 0.95,
		"per_speed_point": 0.002,
		"darkness_penalty": 0.25
	},
	"damage_variance": 0.1,
	"delay_mult": {
		"move": 0.6,
		"defend": 0.8,
		"gene_lock": 1.0,
		"panic": 1.0
	},
	"fear": {
		"max": 100,
		"resist_baseline": 100,
		"ally_death": 20,
		"heavy_wound_ratio": 0.25,
		"heavy_wound": 10,
		"darkness_per_turn": 4,
		"after_awaken": 30
	},
	"gene_lock": {
		"low_hp_ratio": 0.25,
		"awaken_base": 0.02,
		"awaken_per_potential": 0.4,
		"awaken_per_spirit_over_baseline": 0.001,
		"awaken_per_fear": 0.001,
		"awaken_veteran_bonus": 0.05,
		"awaken_max": 0.9,
		"max_stage_in_battle": 3,
		"active_min_stage": 2
	},
	"collapse": {
		"base": 0.35,
		"newbie_bonus": 0.35,
		"per_spirit_over_baseline": -0.002,
		"min": 0.05,
		"max": 0.95
	},
	"panic": {
		"freeze": 0.4,
		"flee": 0.3
	},
	"revive_hp_ratio": 0.3,
	"max_actions": 2000
}
```

- [ ] **Step 4：创建 `game/data/battle/skills.json`**

```json
{
	"version": 1,
	"skills": {
		"punch": {
			"name": "拳脚",
			"user_rows": [0, 1],
			"target_side": "enemy",
			"reach": "melee",
			"target_rows": [0, 1, 2],
			"target_type": "single",
			"accuracy": 0.9,
			"power": 8,
			"scaling": "muscle",
			"tags": ["physical", "melee"]
		},
		"pistol_shot": {
			"name": "手枪射击",
			"user_rows": [0, 1, 2],
			"target_side": "enemy",
			"reach": "ranged",
			"target_rows": [0, 1, 2],
			"target_type": "single",
			"accuracy": 0.8,
			"power": 16,
			"scaling": "fixed",
			"tags": ["physical", "bullet"]
		},
		"desert_eagle": {
			"name": "沙漠之鹰",
			"user_rows": [0, 1, 2],
			"target_side": "enemy",
			"reach": "ranged",
			"target_rows": [0, 1, 2],
			"target_type": "single",
			"accuracy": 0.75,
			"power": 30,
			"scaling": "fixed",
			"tags": ["physical", "bullet"]
		},
		"grenade": {
			"name": "手榴弹",
			"user_rows": [0, 1, 2],
			"target_side": "enemy",
			"reach": "ranged",
			"target_rows": [0, 1, 2],
			"target_type": "row",
			"accuracy": 0.85,
			"power": 45,
			"scaling": "fixed",
			"tags": ["physical", "explosive"],
			"cost": {"grenade": 1}
		},
		"qigong_palm": {
			"name": "气功掌",
			"user_rows": [0, 1],
			"target_side": "enemy",
			"reach": "melee",
			"target_rows": [0, 1, 2],
			"target_type": "single",
			"accuracy": 0.9,
			"power": 20,
			"scaling": "muscle",
			"tags": ["physical", "melee", "qi"],
			"cost": {"neili": 10}
		},
		"first_aid_spray": {
			"name": "止血喷雾",
			"user_rows": [0, 1, 2],
			"target_side": "ally",
			"reach": "ranged",
			"target_rows": [0, 1, 2],
			"target_type": "single",
			"heal": 40,
			"cleanse": ["bleed"],
			"cost": {"spray": 1}
		},
		"antidote": {
			"name": "解毒剂",
			"user_rows": [0, 1, 2],
			"target_side": "ally",
			"reach": "ranged",
			"target_rows": [0, 1, 2],
			"target_type": "single",
			"cleanse": ["infection"],
			"cost": {"antidote": 1}
		},
		"encourage": {
			"name": "鼓舞",
			"user_rows": [0, 1, 2],
			"target_side": "ally",
			"reach": "ranged",
			"target_rows": [0, 1, 2],
			"target_type": "all",
			"fear": -15,
			"cooldown": 3
		},
		"zombie_bite": {
			"name": "撕咬",
			"user_rows": [0, 1],
			"target_side": "enemy",
			"reach": "melee",
			"target_rows": [0, 1, 2],
			"target_type": "single",
			"accuracy": 0.75,
			"power": 18,
			"scaling": "muscle",
			"tags": ["physical", "melee"],
			"applies": [{"status": "infection", "chance": 0.5}]
		},
		"dog_bite": {
			"name": "扑咬",
			"user_rows": [0, 1],
			"target_side": "enemy",
			"reach": "melee",
			"target_rows": [0, 1, 2],
			"target_type": "single",
			"accuracy": 0.85,
			"power": 14,
			"scaling": "muscle",
			"tags": ["physical", "melee"],
			"applies": [{"status": "bleed", "chance": 0.5}]
		},
		"licker_tongue": {
			"name": "舌击",
			"user_rows": [0, 1, 2],
			"target_side": "enemy",
			"reach": "ranged",
			"target_rows": [0, 1, 2],
			"target_type": "single",
			"accuracy": 0.9,
			"power": 20,
			"scaling": "muscle",
			"tags": ["physical"],
			"applies": [{"status": "stun", "chance": 0.3}]
		},
		"licker_claw": {
			"name": "爪击",
			"user_rows": [0, 1],
			"target_side": "enemy",
			"reach": "melee",
			"target_rows": [0, 1, 2],
			"target_type": "single",
			"accuracy": 0.8,
			"power": 55,
			"scaling": "muscle",
			"tags": ["physical", "melee"],
			"applies": [{"status": "bleed", "chance": 0.7}],
			"cooldown": 1
		}
	}
}
```

- [ ] **Step 5：创建 `game/data/battle/statuses.json`**

```json
{
	"version": 1,
	"statuses": {
		"bleed": {
			"name": "流血",
			"duration": 3,
			"stack": "refresh",
			"tick_damage": 5
		},
		"infection": {
			"name": "感染",
			"duration": 5,
			"stack": "keep",
			"on_expire": "turn_zombie"
		},
		"defending": {
			"name": "防御",
			"duration": 1,
			"stack": "refresh",
			"modifiers": {"damage_taken_mult": 0.5}
		},
		"panic": {
			"name": "恐慌",
			"duration": 3,
			"stack": "refresh",
			"flags": ["panic"]
		},
		"stun": {
			"name": "眩晕",
			"duration": 2,
			"stack": "keep",
			"flags": ["skip_turn"]
		},
		"gene_lock": {
			"name": "基因锁",
			"duration": 4,
			"stack": "refresh",
			"modifiers": {"speed_mult": 1.5, "attack_mult": 1.5},
			"flags": ["no_pain"]
		},
		"blind": {
			"name": "失明",
			"duration": 3,
			"stack": "refresh",
			"modifiers": {"hit_mod": -0.4}
		},
		"acid": {
			"name": "酸蚀",
			"duration": 3,
			"stack": "refresh",
			"tick_damage": 4,
			"modifiers": {"damage_taken_mult": 1.2}
		}
	}
}
```

- [ ] **Step 6：创建 `game/data/battle/enemies.json`**

```json
{
	"version": 1,
	"enemies": {
		"zombie": {
			"name": "丧尸",
			"hp": 40,
			"speed": 70,
			"attack_mult": 1.0,
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

- [ ] **Step 7：创建 `game/core/battle/battle_data.gd`**

```gdscript
extends RefCounted
## 战斗数据：规则常量、技能、状态、敌人（设计规格第 4 节）。第一次访问时加载并缓存。

const DataLoader = preload("res://core/util/data_loader.gd")

const RULES_PATH := "res://data/rules/battle_rules.json"
const SKILLS_PATH := "res://data/battle/skills.json"
const STATUSES_PATH := "res://data/battle/statuses.json"
const ENEMIES_PATH := "res://data/battle/enemies.json"

const SKILL_REQUIRED: Array[String] = ["name", "user_rows", "target_side", "reach", "target_rows", "target_type"]
const STATUS_REQUIRED: Array[String] = ["name", "duration", "stack"]
const ENEMY_REQUIRED: Array[String] = ["name", "hp", "speed", "attack_mult", "skills", "ai"]
const TARGET_SIDES: Array[String] = ["enemy", "ally", "self"]
const TARGET_TYPES: Array[String] = ["single", "row", "all"]
const REACHES: Array[String] = ["melee", "ranged"]
const AI_PROFILES: Array[String] = ["nearest", "weakest", "wounded", "threat"]

static var _cache: Dictionary = {}


static func _load(path: String, section: String) -> Dictionary:
	var key := path + "#" + section
	if not _cache.has(key):
		var res := DataLoader.load_json(path)
		assert(res.ok, res.error)
		_cache[key] = res.data if section == "" else res.data[section]
	return _cache[key]


static func rules() -> Dictionary:
	return _load(RULES_PATH, "")


static func skills() -> Dictionary:
	return _load(SKILLS_PATH, "skills")


static func statuses() -> Dictionary:
	return _load(STATUSES_PATH, "statuses")


static func enemies() -> Dictionary:
	return _load(ENEMIES_PATH, "enemies")


static func skill(id: String) -> Dictionary:
	return skills()[id]


static func status(id: String) -> Dictionary:
	return statuses()[id]


static func enemy(id: String) -> Dictionary:
	return enemies()[id]


## 检查数据之间的引用和取值范围，返回错误列表（空表示没有问题）。
static func validate() -> Array[String]:
	var errors: Array[String] = []
	var sk := skills()
	var st := statuses()
	for id: String in sk:
		var s: Dictionary = sk[id]
		errors.append_array(DataLoader.missing_keys(s, SKILL_REQUIRED, "技能 " + id))
		if not TARGET_SIDES.has(String(s.get("target_side", ""))):
			errors.append("技能 %s 的 target_side 无效" % id)
		if not TARGET_TYPES.has(String(s.get("target_type", ""))):
			errors.append("技能 %s 的 target_type 无效" % id)
		if not REACHES.has(String(s.get("reach", ""))):
			errors.append("技能 %s 的 reach 无效" % id)
		for a: Dictionary in s.get("applies", []):
			if not st.has(String(a["status"])):
				errors.append("技能 %s 引用了不存在的状态 %s" % [id, a["status"]])
		for c: String in s.get("cleanse", []):
			if not st.has(c):
				errors.append("技能 %s 引用了不存在的状态 %s" % [id, c])
	for id: String in st:
		errors.append_array(DataLoader.missing_keys(st[id], STATUS_REQUIRED, "状态 " + id))
	var en := enemies()
	for id: String in en:
		var e: Dictionary = en[id]
		errors.append_array(DataLoader.missing_keys(e, ENEMY_REQUIRED, "敌人 " + id))
		for s_id: String in e.get("skills", []):
			if not sk.has(s_id):
				errors.append("敌人 %s 引用了不存在的技能 %s" % [id, s_id])
		if not AI_PROFILES.has(String(e.get("ai", ""))):
			errors.append("敌人 %s 的 ai 无效" % id)
	return errors
```

- [ ] **Step 8：运行，确认通过**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_battle_data bash game/tools/run_tests.sh; echo "exit=$?"`

预期：5 个 `ok`，`共 5 个测试，失败 0 个`，`exit=0`。

- [ ] **Step 9：提交**

```bash
git add game/data/rules/battle_rules.json game/data/battle/skills.json game/data/battle/statuses.json game/data/battle/enemies.json game/core/battle/battle_data.gd game/tests/unit/battle/test_battle_data.gd
git commit -m "feat(battle): 战斗数据：规则常量、技能、状态、敌人" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

### Task 2：战斗单位与状态效果

**Files:**
- Create: `game/core/battle/statuses.gd`、`game/core/battle/battle_unit.gd`、`game/core/battle/unit_factory.gd`
- Test: `game/tests/unit/battle/test_statuses.gd`、`game/tests/unit/battle/test_battle_unit.gd`

- [ ] **Step 1：写测试 `game/tests/unit/battle/test_statuses.gd`**

```gdscript
extends "res://tests/test_case.gd"

const UnitFactory = preload("res://core/battle/unit_factory.gd")
const Statuses = preload("res://core/battle/statuses.gd")


func _unit() -> RefCounted:
	return UnitFactory.from_enemy("zombie", "z1", 0)


func test_apply_and_has() -> void:
	var u := _unit()
	var ev := Statuses.apply(u, "bleed")
	assert_eq(ev["type"], "status_applied")
	assert_false(bool(ev["renewed"]))
	assert_true(Statuses.has(u, "bleed"))
	assert_eq(u.statuses.size(), 1)


func test_refresh_resets_duration() -> void:
	var u := _unit()
	Statuses.apply(u, "bleed")
	Statuses.start_of_turn(u)
	assert_eq(int(u.statuses[0]["remaining"]), 2)
	var ev := Statuses.apply(u, "bleed")
	assert_true(bool(ev["renewed"]))
	assert_eq(int(u.statuses[0]["remaining"]), 3)
	assert_eq(u.statuses.size(), 1)


## 感染倒计时不会被再咬一口重置。
func test_keep_does_not_reset() -> void:
	var u := _unit()
	Statuses.apply(u, "infection")
	Statuses.start_of_turn(u)
	Statuses.apply(u, "infection")
	assert_eq(int(u.statuses[0]["remaining"]), 4)


func test_bleed_ticks_three_times() -> void:
	var u := _unit()
	Statuses.apply(u, "bleed")
	for i in 3:
		Statuses.start_of_turn(u)
	assert_almost(u.hp, 40.0 - 15.0)
	assert_false(Statuses.has(u, "bleed"))
	Statuses.start_of_turn(u)
	assert_almost(u.hp, 25.0)


func test_defending_lasts_until_next_turn() -> void:
	var u := _unit()
	Statuses.apply(u, "defending")
	assert_almost(Statuses.mult(u, "damage_taken_mult"), 0.5)
	var events := Statuses.start_of_turn(u)
	assert_false(Statuses.has(u, "defending"))
	assert_eq(events[0]["type"], "status_expired")
	assert_almost(Statuses.mult(u, "damage_taken_mult"), 1.0)


func test_infection_turns_on_fifth_turn() -> void:
	var u := _unit()
	Statuses.apply(u, "infection")
	for i in 4:
		Statuses.start_of_turn(u)
	assert_true(u.alive)
	var events := Statuses.start_of_turn(u)
	assert_false(u.alive)
	assert_true(u.turned)
	assert_eq(events[events.size() - 1]["type"], "infection_turned")


func test_modifiers_and_flags() -> void:
	var u := _unit()
	Statuses.apply(u, "blind")
	Statuses.apply(u, "acid")
	assert_almost(Statuses.sum(u, "hit_mod"), -0.4)
	assert_almost(Statuses.mult(u, "damage_taken_mult"), 1.2)
	Statuses.apply(u, "stun")
	assert_true(Statuses.has_flag(u, "skip_turn"))
	assert_false(Statuses.has_flag(u, "panic"))


func test_remove() -> void:
	var u := _unit()
	Statuses.apply(u, "infection")
	assert_true(Statuses.remove(u, "infection"))
	assert_false(Statuses.remove(u, "infection"))
	assert_false(Statuses.has(u, "infection"))
```

- [ ] **Step 2：写测试 `game/tests/unit/battle/test_battle_unit.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
const Statuses = preload("res://core/battle/statuses.gd")


func _zheng_zha() -> RefCounted:
	var ch := Character.new("zheng_zha", "郑吒", {"muscle": 120, "nerve_reaction": 110})
	ch.flags["potential"] = 0.8
	return ch


func test_from_character_uses_derived_stats() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var u := UnitFactory.from_character(_zheng_zha(), "ally", 0, skills, "player", {"grenade": 2})
	assert_almost(u.hp_max, 40.0 + 0.6 * 100.0 + 0.4 * 120.0)
	assert_almost(u.hp, u.hp_max)
	assert_almost(u.speed(), 110.0)
	assert_almost(u.attack_mult(), 1.2)
	assert_true(u.reincarnator)
	assert_true(u.newbie)
	assert_almost(u.potential, 0.8)
	assert_eq(int(u.resources["grenade"]), 2)
	assert_eq(u.controller, "player")


func test_from_enemy_reads_data() -> void:
	var u := UnitFactory.from_enemy("licker", "licker_1", 1)
	assert_eq(u.display_name, "爬行者")
	assert_eq(u.side, "enemy")
	assert_eq(u.row, 1)
	assert_almost(u.hp, 200.0)
	assert_almost(u.initiative, 0.3)
	assert_true(u.has_flag("ignores_darkness"))
	assert_false(u.reincarnator)


func test_gene_lock_status_speeds_up() -> void:
	var skills: Array[String] = []
	var u := UnitFactory.from_character(_zheng_zha(), "ally", 0, skills)
	Statuses.apply(u, "gene_lock")
	assert_almost(u.speed(), 165.0)
	assert_almost(u.attack_mult(), 1.8)


func test_write_back() -> void:
	var ch := _zheng_zha()
	var skills: Array[String] = []
	var u := UnitFactory.from_character(ch, "ally", 0, skills)
	u.hp = 12.0
	u.fear = 55.0
	u.gene_lock_stage = 1
	u.aftereffect = true
	UnitFactory.write_back(u, ch)
	assert_almost(ch.hp, 12.0)
	assert_almost(ch.fear, 55.0)
	assert_eq(ch.gene_lock_stage, 1)
	assert_true(ch.alive)
	assert_true(bool(ch.flags["gene_lock_aftereffect"]))


func test_write_back_turned() -> void:
	var ch := _zheng_zha()
	var skills: Array[String] = []
	var u := UnitFactory.from_character(ch, "ally", 0, skills)
	u.alive = false
	u.turned = true
	u.hp = -3.0
	UnitFactory.write_back(u, ch)
	assert_false(ch.alive)
	assert_almost(ch.hp, 0.0)
	assert_true(bool(ch.flags["turned"]))
```

- [ ] **Step 3：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_statuses bash game/tools/run_tests.sh; echo "exit=$?"`，再运行 `WSLENV=TEST_FILTER TEST_FILTER=test_battle_unit bash game/tools/run_tests.sh; echo "exit=$?"`

预期：两次都是对应文件 `FAIL ...（脚本无法加载）`，`!! 检测到脚本错误`，`exit=1`。

- [ ] **Step 4：创建 `game/core/battle/statuses.gd`**

```gdscript
extends RefCounted
## 状态效果（设计规格 4.5），全部由 data/battle/statuses.json 定义。
## 状态记在单位的 statuses 里：{"id": 状态, "remaining": 剩余次数}。
## 时间规则：每次轮到持有者行动时，先结算持续伤害，再把 remaining 减 1，减到 0 就结束。
## 所以 duration = N 表示"到持有者第 N 次轮到自己时结束"：防御（1）挡到下次轮到自己为止，流血（3）跳 3 次伤害。

const BattleData = preload("res://core/battle/battle_data.gd")


static func has(unit: RefCounted, status_id: String) -> bool:
	for s: Dictionary in unit.statuses:
		if s["id"] == status_id:
			return true
	return false


## 施加状态。已有同名状态时：stack = "refresh" 重置剩余次数，"keep" 保持不变（感染倒计时不会被再咬一口重置）。
static func apply(unit: RefCounted, status_id: String) -> Dictionary:
	var def := BattleData.status(status_id)
	for s: Dictionary in unit.statuses:
		if s["id"] == status_id:
			if def["stack"] == "refresh":
				s["remaining"] = int(def["duration"])
			return {"type": "status_applied", "target": unit.id, "status": status_id, "renewed": true}
	unit.statuses.append({"id": status_id, "remaining": int(def["duration"])})
	return {"type": "status_applied", "target": unit.id, "status": status_id, "renewed": false}


static func remove(unit: RefCounted, status_id: String) -> bool:
	for i in unit.statuses.size():
		if unit.statuses[i]["id"] == status_id:
			unit.statuses.remove_at(i)
			return true
	return false


## 乘法修正（speed_mult、attack_mult、damage_taken_mult）：所有状态连乘，没有就是 1。
static func mult(unit: RefCounted, key: String) -> float:
	var m := 1.0
	for s: Dictionary in unit.statuses:
		var mods: Dictionary = BattleData.status(s["id"]).get("modifiers", {})
		m *= float(mods.get(key, 1.0))
	return m


## 加法修正（hit_mod）：所有状态相加，没有就是 0。
static func sum(unit: RefCounted, key: String) -> float:
	var total := 0.0
	for s: Dictionary in unit.statuses:
		var mods: Dictionary = BattleData.status(s["id"]).get("modifiers", {})
		total += float(mods.get(key, 0.0))
	return total


static func has_flag(unit: RefCounted, flag: String) -> bool:
	for s: Dictionary in unit.statuses:
		if (BattleData.status(s["id"]).get("flags", []) as Array).has(flag):
			return true
	return false


## 轮到持有者行动时调用。返回事件列表；持续伤害直接扣血，死亡由战斗控制器判断。
static func start_of_turn(unit: RefCounted) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var expired: Array[String] = []
	for s: Dictionary in unit.statuses:
		var def := BattleData.status(s["id"])
		var tick := float(def.get("tick_damage", 0.0))
		if tick > 0.0:
			unit.hp -= tick
			events.append({"type": "status_damage", "target": unit.id, "status": s["id"], "amount": tick, "hp": unit.hp})
		s["remaining"] = int(s["remaining"]) - 1
		if int(s["remaining"]) <= 0:
			expired.append(String(s["id"]))
	for id in expired:
		remove(unit, id)
		events.append({"type": "status_expired", "target": unit.id, "status": id})
		if BattleData.status(id).get("on_expire", "") == "turn_zombie":
			unit.turned = true
			unit.alive = false
			events.append({"type": "infection_turned", "target": unit.id})
	return events
```

- [ ] **Step 5：创建 `game/core/battle/battle_unit.gd`**

```gdscript
extends RefCounted
## 战斗里的一个单位（轮回者、剧情人物或敌人）。由 unit_factory.gd 创建。
## side：我方 "ally"，敌方 "enemy"。row：0 前排、1 中排、2 后排。

const Statuses = preload("res://core/battle/statuses.gd")

var id: String = ""
var display_name: String = ""
var def_id: String = ""
var character_id: String = ""
var side: String = "ally"
var row: int = 0
var size: int = 1
## "player" 由玩家下令，"ai" 由效用 AI 决定。
var controller: String = "ai"
var ai_profile: String = "nearest"

var hp: float = 1.0
var hp_max: float = 1.0
var base_speed: float = 100.0
var base_attack_mult: float = 1.0
var spirit: float = 100.0
## 只有轮回者有基因锁，能觉醒。
var reincarnator: bool = false
var newbie: bool = false
## 隐藏潜力 0~1，影响觉醒概率（设计规格 3.6）。
var potential: float = 0.0
var gene_lock_stage: int = 0
var fear: float = 0.0

var skills: Array[String] = []
## 能量池与道具数量，例如 {"neili": 30, "grenade": 2}。
var resources: Dictionary = {}
## 技能 → 还要等几次自己的回合。
var cooldowns: Dictionary = {}
var statuses: Array[Dictionary] = []
## 按伤害标签的承伤倍率，例如爬行者 {"bullet": 0.15}。
var tag_mult: Dictionary = {}
## fearless（不会恐惧）、ignores_darkness（黑暗中命中不降）等。
var flags: Array[String] = []
## 第一次行动的延迟倍率，小于 1 表示先手。
var initiative: float = 1.0
## 登场时让对方每人增加的恐惧值。
var fear_aura: float = 0.0
## 重生十字章之类的道具：死亡时消耗一次，以部分生命复活。
var revive_charges: int = 0

var alive: bool = true
var fled: bool = false
## 感染倒计时走完，变成丧尸。
var turned: bool = false
var next_time: float = 0.0
## 本场战斗里已经做过"低血觉醒检定"。
var low_hp_checked: bool = false
## 恐惧满后已经检定过；恐惧降下来以后才会再检定。
var fear_checked: bool = false
## 本场战斗开过基因锁，战后有后遗症（由远征层处理）。
var aftereffect: bool = false
## 敌人提前定好的下一步行动（设计规格 4.6）。
var intent: Dictionary = {}


func in_play() -> bool:
	return alive and not fled


func has_flag(flag: String) -> bool:
	return flags.has(flag)


func hp_ratio() -> float:
	return hp / hp_max


func speed() -> float:
	return base_speed * Statuses.mult(self, "speed_mult")


func attack_mult() -> float:
	return base_attack_mult * Statuses.mult(self, "attack_mult")
```

- [ ] **Step 6：创建 `game/core/battle/unit_factory.gd`**

```gdscript
extends RefCounted
## 从轮回者（character.gd）或敌人数据创建战斗单位，战后把结果写回轮回者。

const BattleUnit = preload("res://core/battle/battle_unit.gd")
const BattleData = preload("res://core/battle/battle_data.gd")
const DerivedStats = preload("res://core/model/derived_stats.gd")


## 轮回者进战斗。skill_ids 是本场可用的技能；resources 是带进来的能量和道具。
static func from_character(ch: RefCounted, side: String, row: int, skill_ids: Array[String], controller: String = "player", resources: Dictionary = {}) -> RefCounted:
	var d := DerivedStats.compute(ch.attributes)
	var u := BattleUnit.new()
	u.id = ch.id
	u.character_id = ch.id
	u.display_name = ch.display_name
	u.side = side
	u.row = row
	u.controller = controller
	u.hp_max = float(d["hp_max"])
	u.hp = minf(ch.hp, u.hp_max)
	u.base_speed = float(d["speed"])
	u.base_attack_mult = float(d["attack_mult"])
	u.spirit = float(d["mental_resist"])
	u.reincarnator = true
	u.newbie = ch.is_newbie()
	u.potential = float(ch.flags.get("potential", 0.0))
	u.gene_lock_stage = ch.gene_lock_stage
	u.fear = ch.fear
	u.skills = skill_ids.duplicate()
	u.resources = resources.duplicate()
	u.revive_charges = int(resources.get("rebirth_cross", 0))
	return u


## 按 enemies.json 创建敌人。unit_id 在一场战斗里要唯一，例如 "zombie_1"。
static func from_enemy(def_id: String, unit_id: String, row: int) -> RefCounted:
	var e := BattleData.enemy(def_id)
	var u := BattleUnit.new()
	u.id = unit_id
	u.def_id = def_id
	u.display_name = String(e["name"])
	u.side = "enemy"
	u.row = row
	u.controller = "ai"
	u.ai_profile = String(e["ai"])
	u.hp_max = float(e["hp"])
	u.hp = u.hp_max
	u.base_speed = float(e["speed"])
	u.base_attack_mult = float(e["attack_mult"])
	u.size = int(e.get("size", 1))
	for s: String in e["skills"]:
		u.skills.append(s)
	for f: String in e.get("flags", []):
		u.flags.append(f)
	u.tag_mult = (e.get("tag_mult", {}) as Dictionary).duplicate()
	u.initiative = float(e.get("initiative", 1.0))
	u.fear_aura = float(e.get("fear_aura", 0.0))
	return u


## 战斗结束后把生命、恐惧、基因锁、生死写回轮回者。
static func write_back(u: RefCounted, ch: RefCounted) -> void:
	ch.hp = maxf(u.hp, 0.0)
	ch.fear = u.fear
	ch.gene_lock_stage = u.gene_lock_stage
	ch.alive = u.alive
	if u.turned:
		ch.flags["turned"] = true
	if u.aftereffect:
		ch.flags["gene_lock_aftereffect"] = true
```

- [ ] **Step 7：运行，确认通过**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_statuses bash game/tools/run_tests.sh; echo "exit=$?"`，再运行 `WSLENV=TEST_FILTER TEST_FILTER=test_battle_unit bash game/tools/run_tests.sh; echo "exit=$?"`

预期：第一次 `共 8 个测试，失败 0 个`，第二次 `共 5 个测试，失败 0 个`，都是 `exit=0`。

- [ ] **Step 8：提交**

```bash
git add game/core/battle/statuses.gd game/core/battle/battle_unit.gd game/core/battle/unit_factory.gd game/tests/unit/battle/test_statuses.gd game/tests/unit/battle/test_battle_unit.gd
git commit -m "feat(battle): 战斗单位与状态效果" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

### Task 3：三排战场与行动时间轴

**Files:**
- Create: `game/core/battle/battlefield.gd`、`game/core/battle/ctb.gd`
- Test: `game/tests/unit/battle/test_battlefield.gd`、`game/tests/unit/battle/test_ctb.gd`

- [ ] **Step 1：写测试 `game/tests/unit/battle/test_battlefield.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Battlefield = preload("res://core/battle/battlefield.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")


func _zombie(id: String, row: int) -> RefCounted:
	return UnitFactory.from_enemy("zombie", id, row)


func test_default_capacity() -> void:
	var f := Battlefield.new()
	assert_eq(f.capacity, 4)
	assert_eq(f.rows, 3)


func test_row_capacity_enforced() -> void:
	var f := Battlefield.new(2)
	assert_true(f.add(_zombie("z1", 0)))
	assert_true(f.add(_zombie("z2", 0)))
	assert_false(f.add(_zombie("z3", 0)))
	assert_true(f.add(_zombie("z3", 1)))
	assert_eq(f.used("enemy", 0), 2)


func test_large_unit_takes_more_slots() -> void:
	var f := Battlefield.new(2)
	var big := _zombie("big", 0)
	big.size = 2
	assert_true(f.add(big))
	assert_false(f.add(_zombie("z1", 0)))


func test_front_row_moves_up_when_emptied() -> void:
	var f := Battlefield.new()
	var front := _zombie("z1", 0)
	f.add(front)
	f.add(_zombie("z2", 1))
	assert_eq(f.front_row("enemy"), 0)
	front.alive = false
	assert_eq(f.front_row("enemy"), 1)
	assert_eq(f.front_row("ally"), -1)


func test_move_adjacent_only() -> void:
	var f := Battlefield.new(1)
	var a := _zombie("z1", 0)
	var b := _zombie("z2", 2)
	f.add(a)
	f.add(b)
	assert_false(f.move(a, 2))
	assert_true(f.move(a, 1))
	assert_eq(a.row, 1)
	assert_false(f.move(b, 1))


func test_dead_units_free_their_slot() -> void:
	var f := Battlefield.new(1)
	var a := _zombie("z1", 0)
	f.add(a)
	a.alive = false
	assert_true(f.can_place("enemy", 0, 1))
	assert_eq(f.side_units("enemy").size(), 0)
	assert_eq(f.get_unit("z1"), a)


func test_opponent() -> void:
	assert_eq(Battlefield.opponent("ally"), "enemy")
	assert_eq(Battlefield.opponent("enemy"), "ally")
```

- [ ] **Step 2：写测试 `game/tests/unit/battle/test_ctb.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Ctb = preload("res://core/battle/ctb.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")


func _unit(id: String, speed: float) -> RefCounted:
	var u := UnitFactory.from_enemy("zombie", id, 0)
	u.base_speed = speed
	return u


func _run(ctb: RefCounted, units: Array[RefCounted], n: int) -> Array[String]:
	var order: Array[String] = []
	for i in n:
		var u: RefCounted = ctb.next_actor(units)
		order.append(u.id)
		ctb.advance(u, 1.0)
	return order


func test_delay_formula() -> void:
	var ctb := Ctb.new()
	assert_almost(ctb.delay(100.0, 1.0), 100.0)
	assert_almost(ctb.delay(200.0, 1.0), 50.0)
	assert_almost(ctb.delay(100.0, 0.6), 60.0)


## 速度 200 的单位每行动两次，速度 100 的行动一次。
func test_double_speed_acts_twice() -> void:
	var ctb := Ctb.new()
	var fast := _unit("fast", 200.0)
	var slow := _unit("slow", 100.0)
	var units: Array[RefCounted] = [slow, fast]
	for u in units:
		ctb.init_unit(u)
	var order := _run(ctb, units, 6)
	assert_eq(order.count("fast"), 4, str(order))
	assert_eq(order.count("slow"), 2, str(order))
	assert_eq(order[0], "fast")


## 时间相同时，先加入战场的先动。
func test_tie_keeps_insertion_order() -> void:
	var ctb := Ctb.new()
	var a := _unit("a", 100.0)
	var b := _unit("b", 100.0)
	var units: Array[RefCounted] = [a, b]
	for u in units:
		ctb.init_unit(u)
	assert_eq(_run(ctb, units, 4), ["a", "b", "a", "b"] as Array[String])


## 爬行者的舌头先手：initiative 0.3。
func test_initiative_acts_first() -> void:
	var ctb := Ctb.new()
	var human := _unit("human", 100.0)
	var licker := UnitFactory.from_enemy("licker", "licker", 0)
	var units: Array[RefCounted] = [human, licker]
	for u in units:
		ctb.init_unit(u)
	assert_eq(ctb.next_actor(units).id, "licker")


func test_preview_does_not_change_units() -> void:
	var ctb := Ctb.new()
	var fast := _unit("fast", 200.0)
	var slow := _unit("slow", 100.0)
	var units: Array[RefCounted] = [slow, fast]
	for u in units:
		ctb.init_unit(u)
	var before: float = fast.next_time
	var p := ctb.preview(units, 10)
	assert_eq(p.size(), 10)
	assert_almost(fast.next_time, before)
	assert_eq(p.slice(0, 6), _run(ctb, units, 6))


func test_dead_units_skipped() -> void:
	var ctb := Ctb.new()
	var a := _unit("a", 300.0)
	var b := _unit("b", 100.0)
	var units: Array[RefCounted] = [a, b]
	for u in units:
		ctb.init_unit(u)
	a.alive = false
	assert_eq(ctb.next_actor(units).id, "b")
	assert_eq(ctb.preview(units, 3), ["b", "b", "b"] as Array[String])
	b.fled = true
	assert_eq(ctb.next_actor(units), null)
```

- [ ] **Step 3：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_battlefield bash game/tools/run_tests.sh; echo "exit=$?"`，再运行 `WSLENV=TEST_FILTER TEST_FILTER=test_ctb bash game/tools/run_tests.sh; echo "exit=$?"`

预期：两次都是对应文件 `FAIL ...（脚本无法加载）`，`!! 检测到脚本错误`，`exit=1`。

- [ ] **Step 4：创建 `game/core/battle/battlefield.gd`**

```gdscript
extends RefCounted
## 三排战场（设计规格 4.1）：敌我各有前（0）、中（1）、后（2）三排，每排容量由战斗决定。
## 大型单位占多个格（size）。最前面还有人的那一排算"前排"：前排打空了，中排就顶上来。

const BattleData = preload("res://core/battle/battle_data.gd")

var capacity: int = 4
var rows: int = 3
## 全部单位，按加入顺序；行动顺序打平时按这个顺序。
var units: Array[RefCounted] = []


func _init(row_capacity: int = -1) -> void:
	var r := BattleData.rules()
	rows = int(r["rows"])
	capacity = row_capacity if row_capacity > 0 else int(r["row_capacity_default"])


static func opponent(side: String) -> String:
	return "enemy" if side == "ally" else "ally"


func used(side: String, row: int) -> int:
	var n := 0
	for u in units:
		if u.side == side and u.row == row and u.in_play():
			n += u.size
	return n


func can_place(side: String, row: int, size: int) -> bool:
	return row >= 0 and row < rows and used(side, row) + size <= capacity


func add(u: RefCounted) -> bool:
	if not can_place(u.side, u.row, u.size):
		return false
	units.append(u)
	return true


func get_unit(id: String) -> RefCounted:
	for u in units:
		if u.id == id:
			return u
	return null


func side_units(side: String) -> Array[RefCounted]:
	var out: Array[RefCounted] = []
	for u in units:
		if u.side == side and u.in_play():
			out.append(u)
	return out


func row_units(side: String, row: int) -> Array[RefCounted]:
	var out: Array[RefCounted] = []
	for u in units:
		if u.side == side and u.row == row and u.in_play():
			out.append(u)
	return out


## 该方最前面还有人的一排；整方都没人时返回 -1。
func front_row(side: String) -> int:
	for r in rows:
		if not row_units(side, r).is_empty():
			return r
	return -1


## 换位：只能移到相邻的一排，并且那一排放得下。
func move(u: RefCounted, to_row: int) -> bool:
	if absi(to_row - u.row) != 1 or not can_place(u.side, to_row, u.size):
		return false
	u.row = to_row
	return true
```

- [ ] **Step 5：创建 `game/core/battle/ctb.gd`**

```gdscript
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
```

- [ ] **Step 6：运行，确认通过**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_battlefield bash game/tools/run_tests.sh; echo "exit=$?"`，再运行 `WSLENV=TEST_FILTER TEST_FILTER=test_ctb bash game/tools/run_tests.sh; echo "exit=$?"`

预期：第一次 `共 7 个测试，失败 0 个`，第二次 `共 6 个测试，失败 0 个`，都是 `exit=0`。

- [ ] **Step 7：提交**

```bash
git add game/core/battle/battlefield.gd game/core/battle/ctb.gd game/tests/unit/battle/test_battlefield.gd game/tests/unit/battle/test_ctb.gd
git commit -m "feat(battle): 三排战场与行动时间轴" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

### Task 4：命中、伤害、恐惧与基因锁觉醒

**Files:**
- Create: `game/core/battle/combat_math.gd`、`game/core/battle/fear.gd`
- Test: `game/tests/unit/battle/test_combat_math.gd`、`game/tests/unit/battle/test_fear.gd`

测试锚点：手枪打丧尸 16，打爬行者只有 2（原著：手枪几乎无效），手榴弹不受影响；黑暗中人类命中下降，爬行者不受影响；新人恐惧满时崩溃概率 0.7，资深者 0.35。

- [ ] **Step 1：写测试 `game/tests/unit/battle/test_combat_math.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
const BattleData = preload("res://core/battle/battle_data.gd")
const CombatMath = preload("res://core/battle/combat_math.gd")
const Statuses = preload("res://core/battle/statuses.gd")


func _human(muscle: float = 100.0) -> RefCounted:
	var ch := Character.new("h", "新人", {"muscle": muscle})
	var skills: Array[String] = []
	return UnitFactory.from_character(ch, "ally", 0, skills)


func test_pistol_vs_zombie() -> void:
	var dmg := CombatMath.damage(_human(), UnitFactory.from_enemy("zombie", "z", 0), BattleData.skill("pistol_shot"), 0.5)
	assert_almost(dmg, 16.0)


## 原著：手枪对爬行者几乎无效。
func test_pistol_vs_licker_nearly_useless() -> void:
	var licker := UnitFactory.from_enemy("licker", "l", 0)
	assert_almost(CombatMath.damage(_human(), licker, BattleData.skill("pistol_shot"), 0.5), 2.0)
	assert_almost(CombatMath.damage(_human(), licker, BattleData.skill("grenade"), 0.5), 45.0)


func test_muscle_scales_melee_only() -> void:
	var z := UnitFactory.from_enemy("zombie", "z", 0)
	var strong := _human(150.0)
	assert_almost(CombatMath.damage(strong, z, BattleData.skill("punch"), 0.5), 12.0)
	assert_almost(CombatMath.damage(strong, z, BattleData.skill("pistol_shot"), 0.5), 16.0)


func test_variance_bounds() -> void:
	var z := UnitFactory.from_enemy("zombie", "z", 0)
	var skill := BattleData.skill("desert_eagle")
	assert_almost(CombatMath.damage(_human(), z, skill, 0.0), 27.0)
	assert_almost(CombatMath.damage(_human(), z, skill, 1.0), 33.0)


func test_defend_and_gene_lock() -> void:
	var z := UnitFactory.from_enemy("zombie", "z", 0)
	var h := _human()
	var bite := BattleData.skill("zombie_bite")
	Statuses.apply(h, "defending")
	assert_almost(CombatMath.damage(z, h, bite, 0.5), 9.0)
	Statuses.apply(h, "gene_lock")
	assert_almost(CombatMath.damage(h, z, BattleData.skill("pistol_shot"), 0.5), 24.0)


func test_non_damage_skill() -> void:
	assert_almost(CombatMath.damage(_human(), _human(), BattleData.skill("first_aid_spray"), 0.5), 0.0)


func test_hit_chance_uses_speed_difference() -> void:
	var h := _human()
	var pistol := BattleData.skill("pistol_shot")
	assert_almost(CombatMath.hit_chance(h, UnitFactory.from_enemy("zombie", "z", 0), pistol, false), 0.86)
	assert_almost(CombatMath.hit_chance(h, UnitFactory.from_enemy("licker", "l", 0), pistol, false), 0.76)


## 黑暗中人类命中下降，爬行者靠热感和嗅觉，不受影响。
func test_darkness() -> void:
	var h := _human()
	var licker := UnitFactory.from_enemy("licker", "l", 0)
	assert_almost(CombatMath.hit_chance(h, licker, BattleData.skill("pistol_shot"), true), 0.51)
	var claw := BattleData.skill("licker_claw")
	assert_almost(CombatMath.hit_chance(licker, h, claw, true), CombatMath.hit_chance(licker, h, claw, false))


func test_hit_chance_clamped_and_auto_hit() -> void:
	var h := _human()
	var z := UnitFactory.from_enemy("zombie", "z", 0)
	Statuses.apply(h, "blind")
	h.base_speed = 1.0
	assert_almost(CombatMath.hit_chance(h, z, BattleData.skill("pistol_shot"), true), 0.05)
	assert_almost(CombatMath.hit_chance(h, h, BattleData.skill("first_aid_spray"), true), 1.0)
```

- [ ] **Step 2：写测试 `game/tests/unit/battle/test_fear.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
const Fear = preload("res://core/battle/fear.gd")
const Statuses = preload("res://core/battle/statuses.gd")


func _unit(potential: float, newbie: bool, spirit: float = 100.0) -> RefCounted:
	var ch := Character.new("c", "轮回者", {"spirit": spirit})
	ch.flags["potential"] = potential
	if not newbie:
		ch.films_completed = 1
	var skills: Array[String] = []
	return UnitFactory.from_character(ch, "ally", 0, skills)


func test_gain_scaled_by_spirit() -> void:
	var normal := _unit(0.0, true)
	var strong := _unit(0.0, true, 200.0)
	assert_almost(Fear.gain(normal, 20.0), 20.0)
	assert_almost(Fear.gain(strong, 20.0), 10.0)
	assert_almost(Fear.gain(strong, -15.0), -10.0)
	assert_almost(Fear.gain(normal, 500.0), 80.0)


func test_fearless_never_afraid() -> void:
	var z := UnitFactory.from_enemy("zombie", "z", 0)
	assert_almost(Fear.gain(z, 50.0), 0.0)
	assert_almost(Fear.collapse_chance(z), 0.0)
	assert_almost(Fear.awaken_chance(z), 0.0)


func test_awaken_chance_formula() -> void:
	var u := _unit(0.8, true)
	u.fear = 100.0
	assert_almost(Fear.awaken_chance(u), 0.02 + 0.32 + 0.1)
	var vet := _unit(0.3, false)
	vet.fear = 100.0
	assert_almost(Fear.awaken_chance(vet), 0.02 + 0.12 + 0.1 + 0.05)


## 原著：资深者和高潜力者容易觉醒，新人容易崩溃。
func test_newbie_collapses_more() -> void:
	assert_almost(Fear.collapse_chance(_unit(0.0, true)), 0.7)
	assert_almost(Fear.collapse_chance(_unit(0.0, false)), 0.35)
	assert_almost(Fear.collapse_chance(_unit(0.0, false, 200.0)), 0.15)


func test_no_awaken_past_stage_three() -> void:
	var u := _unit(1.0, false)
	u.gene_lock_stage = 3
	assert_almost(Fear.awaken_chance(u), 0.0)


func test_awaken_effects() -> void:
	var u := _unit(0.5, true)
	u.fear = 100.0
	var events := Fear.awaken(u)
	assert_eq(events[0]["type"], "gene_lock_awaken")
	assert_eq(u.gene_lock_stage, 1)
	assert_almost(u.fear, 30.0)
	assert_true(u.aftereffect)
	assert_true(Statuses.has(u, "gene_lock"))


func test_low_hp_check_once() -> void:
	var u := _unit(0.8, true)
	u.hp = u.hp_max * 0.5
	assert_eq(Fear.check_low_hp(u, 0.0).size(), 0)
	u.hp = u.hp_max * 0.2
	var events := Fear.check_low_hp(u, 0.99)
	assert_eq(events[0]["type"], "awaken_failed")
	assert_true(u.low_hp_checked)
	assert_eq(Fear.check_low_hp(u, 0.0).size(), 0)
	assert_eq(u.gene_lock_stage, 0)


func test_low_hp_awaken() -> void:
	var u := _unit(0.8, true)
	u.hp = u.hp_max * 0.2
	var events := Fear.check_low_hp(u, 0.1)
	assert_eq(events[0]["type"], "gene_lock_awaken")
	assert_eq(u.gene_lock_stage, 1)


## 新人恐惧满：觉醒 0.12、崩溃 0.7，其余硬撑。
func test_full_fear_outcomes() -> void:
	var a := _unit(0.0, true)
	a.fear = 100.0
	assert_almost(Fear.awaken_chance(a), 0.12)
	assert_eq(Fear.check_full_fear(a, 0.05)[0]["type"], "gene_lock_awaken")
	var b := _unit(0.0, true)
	b.fear = 100.0
	var collapse := Fear.check_full_fear(b, 0.5)
	assert_eq(collapse[0]["type"], "fear_collapse")
	assert_true(Statuses.has(b, "panic"))
	var c := _unit(0.0, true)
	c.fear = 100.0
	assert_eq(Fear.check_full_fear(c, 0.9)[0]["type"], "fear_endured")
	assert_eq(Fear.check_full_fear(c, 0.0).size(), 0)


func test_check_again_after_fear_drops() -> void:
	var u := _unit(0.0, true)
	u.fear = 100.0
	Fear.check_full_fear(u, 0.9)
	assert_true(u.fear_checked)
	Fear.gain(u, -20.0)
	assert_false(u.fear_checked)
	Fear.gain(u, 50.0)
	assert_eq(Fear.check_full_fear(u, 0.9).size(), 1)
```

- [ ] **Step 3：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_combat_math bash game/tools/run_tests.sh; echo "exit=$?"`，再运行 `WSLENV=TEST_FILTER TEST_FILTER=test_fear bash game/tools/run_tests.sh; echo "exit=$?"`

预期：两次都是对应文件 `FAIL ...（脚本无法加载）`，`!! 检测到脚本错误`，`exit=1`。

- [ ] **Step 4：创建 `game/core/battle/combat_math.gd`**

```gdscript
extends RefCounted
## 命中与伤害公式。纯函数：随机数由调用方传入（roll 在 0~1 之间），方便测试。

const BattleData = preload("res://core/battle/battle_data.gd")
const Statuses = preload("res://core/battle/statuses.gd")


## 技能没有 accuracy（治疗、鼓舞）时必中。
## 命中 = 技能命中 + (攻方速度 − 守方速度) × 系数 + 状态修正；黑暗中再降，爬行者这类靠热感嗅觉的不受影响。
static func hit_chance(attacker: RefCounted, target: RefCounted, skill: Dictionary, dark: bool) -> float:
	if not skill.has("accuracy"):
		return 1.0
	var h: Dictionary = BattleData.rules()["hit"]
	var c := float(skill["accuracy"])
	c += (attacker.speed() - target.speed()) * float(h["per_speed_point"])
	c += Statuses.sum(attacker, "hit_mod")
	if dark and not attacker.has_flag("ignores_darkness"):
		c -= float(h["darkness_penalty"])
	return clampf(c, float(h["min"]), float(h["max"]))


## 伤害 = 威力 ×（肌肉加成，只对 scaling = muscle 的技能）× 攻方状态加成 × 浮动 × 标签承伤倍率 × 守方状态承伤倍率，四舍五入。
## roll = 0.5 时没有浮动；0 和 1 分别是下限和上限。
static func damage(attacker: RefCounted, target: RefCounted, skill: Dictionary, roll: float) -> float:
	var dmg := float(skill.get("power", 0.0))
	if dmg <= 0.0:
		return 0.0
	if skill.get("scaling", "fixed") == "muscle":
		dmg *= attacker.base_attack_mult
	dmg *= Statuses.mult(attacker, "attack_mult")
	var variance := float(BattleData.rules()["damage_variance"])
	dmg *= 1.0 + variance * (2.0 * roll - 1.0)
	for tag: String in skill.get("tags", []):
		dmg *= float(target.tag_mult.get(tag, 1.0))
	dmg *= Statuses.mult(target, "damage_taken_mult")
	return maxf(0.0, roundf(dmg))
```

- [ ] **Step 5：创建 `game/core/battle/fear.gd`**

```gdscript
extends RefCounted
## 恐惧值与基因锁觉醒（设计规格 3.4、3.5）。随机数由调用方传入（roll 在 0~1 之间）。
## 觉醒检定在两种情况下各做一次：生命第一次低于 25%；恐惧值满（降下来以后再满会再检定）。
## 恐惧满时：roll 落在觉醒概率内 → 觉醒；落在后面的崩溃概率内 → 恐慌；否则硬撑过去。

const BattleData = preload("res://core/battle/battle_data.gd")
const Statuses = preload("res://core/battle/statuses.gd")


static func _fear_rules() -> Dictionary:
	return BattleData.rules()["fear"]


static func max_fear() -> float:
	return float(_fear_rules()["max"])


## 增减恐惧，返回实际变化量。增加量按精神力折算：精神力 200 的人只涨一半；减少量不折算。
static func gain(u: RefCounted, amount: float) -> float:
	if u.has_flag("fearless"):
		return 0.0
	var delta := amount
	if amount > 0.0:
		delta = amount * float(_fear_rules()["resist_baseline"]) / maxf(u.spirit, 1.0)
	var before: float = u.fear
	u.fear = clampf(u.fear + delta, 0.0, max_fear())
	if u.fear < max_fear():
		u.fear_checked = false
	return u.fear - before


## 觉醒概率：只有轮回者有，第三阶以上要过心魔关，不能在战斗里觉醒。
static func awaken_chance(u: RefCounted) -> float:
	var g: Dictionary = BattleData.rules()["gene_lock"]
	if not u.reincarnator or u.gene_lock_stage >= int(g["max_stage_in_battle"]):
		return 0.0
	var c := float(g["awaken_base"])
	c += u.potential * float(g["awaken_per_potential"])
	c += (u.spirit - float(_fear_rules()["resist_baseline"])) * float(g["awaken_per_spirit_over_baseline"])
	c += u.fear * float(g["awaken_per_fear"])
	if not u.newbie:
		c += float(g["awaken_veteran_bonus"])
	return clampf(c, 0.0, float(g["awaken_max"]))


## 恐惧满时的崩溃概率：新人高，精神力高的人低。
static func collapse_chance(u: RefCounted) -> float:
	if u.has_flag("fearless"):
		return 0.0
	var c: Dictionary = BattleData.rules()["collapse"]
	var p := float(c["base"])
	if u.newbie:
		p += float(c["newbie_bonus"])
	p += (u.spirit - float(_fear_rules()["resist_baseline"])) * float(c["per_spirit_over_baseline"])
	return clampf(p, float(c["min"]), float(c["max"]))


## 觉醒：基因锁升一阶，进入基因锁状态，恐惧回落，战后有后遗症。
static func awaken(u: RefCounted) -> Array[Dictionary]:
	u.gene_lock_stage += 1
	u.fear = float(_fear_rules()["after_awaken"])
	u.fear_checked = false
	u.aftereffect = true
	var events: Array[Dictionary] = [{"type": "gene_lock_awaken", "target": u.id, "stage": u.gene_lock_stage}]
	events.append(Statuses.apply(u, "gene_lock"))
	return events


## 生命第一次低于 25% 时的觉醒检定。
static func check_low_hp(u: RefCounted, roll: float) -> Array[Dictionary]:
	var g: Dictionary = BattleData.rules()["gene_lock"]
	if u.low_hp_checked or not u.reincarnator or u.hp <= 0.0 or u.hp_ratio() >= float(g["low_hp_ratio"]):
		return []
	u.low_hp_checked = true
	if roll < awaken_chance(u):
		return awaken(u)
	return [{"type": "awaken_failed", "target": u.id, "trigger": "low_hp"}]


## 恐惧满时的检定：觉醒、崩溃（恐慌）或硬撑。
static func check_full_fear(u: RefCounted, roll: float) -> Array[Dictionary]:
	if u.fear < max_fear() or u.fear_checked:
		return []
	u.fear_checked = true
	var aw := awaken_chance(u)
	if roll < aw:
		return awaken(u)
	if roll < aw + collapse_chance(u):
		var events: Array[Dictionary] = [{"type": "fear_collapse", "target": u.id}]
		events.append(Statuses.apply(u, "panic"))
		return events
	return [{"type": "fear_endured", "target": u.id}]
```

- [ ] **Step 6：运行，确认通过**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_combat_math bash game/tools/run_tests.sh; echo "exit=$?"`，再运行 `WSLENV=TEST_FILTER TEST_FILTER=test_fear bash game/tools/run_tests.sh; echo "exit=$?"`

预期：第一次 `共 9 个测试，失败 0 个`，第二次 `共 10 个测试，失败 0 个`，都是 `exit=0`。

- [ ] **Step 7：提交**

```bash
git add game/core/battle/combat_math.gd game/core/battle/fear.gd game/tests/unit/battle/test_combat_math.gd game/tests/unit/battle/test_fear.gd
git commit -m "feat(battle): 命中与伤害公式、恐惧与基因锁觉醒" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

### Task 5：合法行动与效用 AI

**Files:**
- Create: `game/core/battle/targeting.gd`、`game/core/battle/utility_ai.gd`
- Test: `game/tests/unit/battle/test_targeting.gd`、`game/tests/unit/battle/test_utility_ai.gd`

- [ ] **Step 1：写测试 `game/tests/unit/battle/test_targeting.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
const Battlefield = preload("res://core/battle/battlefield.gd")
const BattleData = preload("res://core/battle/battle_data.gd")
const Targeting = preload("res://core/battle/targeting.gd")
const Statuses = preload("res://core/battle/statuses.gd")


func _human(id: String, row: int, skills: Array[String], resources: Dictionary = {}) -> RefCounted:
	return UnitFactory.from_character(Character.new(id, id, {}), "ally", row, skills, "player", resources)


func _field(units: Array[RefCounted]) -> RefCounted:
	var f := Battlefield.new()
	for u in units:
		f.add(u)
	return f


## 近战只能打对方前排；前排打空了，中排顶上来。
func test_melee_hits_front_row_only() -> void:
	var skills: Array[String] = ["punch"]
	var h := _human("h", 0, skills)
	var z1 := UnitFactory.from_enemy("zombie", "z1", 0)
	var z2 := UnitFactory.from_enemy("zombie", "z2", 1)
	var f := _field([h, z1, z2])
	var punch := BattleData.skill("punch")
	assert_eq(Targeting.target_choices(f, h, punch), [["z1"]] as Array[Array])
	z1.alive = false
	assert_eq(Targeting.target_choices(f, h, punch), [["z2"]] as Array[Array])


func test_ranged_hits_any_row() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 2, skills)
	var f := _field([h, UnitFactory.from_enemy("zombie", "z1", 0), UnitFactory.from_enemy("zombie", "z2", 2)])
	assert_eq(Targeting.target_choices(f, h, BattleData.skill("pistol_shot")).size(), 2)


func test_row_and_all_targets() -> void:
	var skills: Array[String] = ["grenade", "encourage"]
	var h := _human("h", 1, skills, {"grenade": 1})
	var h2 := _human("h2", 0, skills)
	var f := _field([h, h2, UnitFactory.from_enemy("zombie", "z1", 0), UnitFactory.from_enemy("zombie", "z2", 0), UnitFactory.from_enemy("zombie", "z3", 2)])
	assert_eq(Targeting.target_choices(f, h, BattleData.skill("grenade")), [["z1", "z2"], ["z3"]] as Array[Array])
	assert_eq(Targeting.target_choices(f, h, BattleData.skill("encourage")), [["h", "h2"]] as Array[Array])


func test_user_row_restriction() -> void:
	var skills: Array[String] = ["punch"]
	var h := _human("h", 2, skills)
	var f := _field([h, UnitFactory.from_enemy("zombie", "z1", 0)])
	assert_false(Targeting.usable(f, h, "punch"))
	h.row = 1
	assert_true(Targeting.usable(f, h, "punch"))


func test_cost_and_cooldown() -> void:
	var skills: Array[String] = ["grenade", "encourage"]
	var h := _human("h", 1, skills)
	var f := _field([h, UnitFactory.from_enemy("zombie", "z1", 0)])
	assert_false(Targeting.usable(f, h, "grenade"))
	h.resources["grenade"] = 1
	assert_true(Targeting.usable(f, h, "grenade"))
	assert_true(Targeting.usable(f, h, "encourage"))
	h.cooldowns["encourage"] = 2
	assert_false(Targeting.usable(f, h, "encourage"))


func test_legal_actions_order() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 1, skills)
	var f := _field([h, UnitFactory.from_enemy("zombie", "z1", 0)])
	var actions := Targeting.legal_actions(f, h, true)
	assert_eq(actions[0], {"type": "skill", "skill": "pistol_shot", "targets": ["z1"]})
	assert_eq(actions[1], {"type": "move", "row": 0})
	assert_eq(actions[2], {"type": "move", "row": 2})
	assert_eq(actions[3], {"type": "defend"})
	assert_eq(actions[4], {"type": "retreat"})
	assert_eq(actions.size(), 5)
	assert_false(Targeting.legal_actions(f, h, false).has({"type": "retreat"}))


## 基因锁二阶起才能主动开启，已经开着就不能再开。
func test_gene_lock_action() -> void:
	var skills: Array[String] = []
	var h := _human("h", 0, skills)
	var f := _field([h, UnitFactory.from_enemy("zombie", "z1", 0)])
	h.gene_lock_stage = 1
	assert_false(Targeting.legal_actions(f, h, false).has({"type": "gene_lock"}))
	h.gene_lock_stage = 2
	assert_true(Targeting.legal_actions(f, h, false).has({"type": "gene_lock"}))
	Statuses.apply(h, "gene_lock")
	assert_false(Targeting.legal_actions(f, h, false).has({"type": "gene_lock"}))


func test_is_legal() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 0, skills)
	var f := _field([h, UnitFactory.from_enemy("zombie", "z1", 0)])
	assert_true(Targeting.is_legal(f, h, {"type": "skill", "skill": "pistol_shot", "targets": ["z1"]}, false))
	assert_false(Targeting.is_legal(f, h, {"type": "skill", "skill": "pistol_shot", "targets": ["h"]}, false))
	assert_false(Targeting.is_legal(f, h, {"type": "skill", "skill": "punch", "targets": ["z1"]}, false))
```

- [ ] **Step 2：写测试 `game/tests/unit/battle/test_utility_ai.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
const Battlefield = preload("res://core/battle/battlefield.gd")
const UtilityAi = preload("res://core/battle/utility_ai.gd")
const Statuses = preload("res://core/battle/statuses.gd")


func _human(id: String, row: int, skills: Array[String], resources: Dictionary = {}) -> RefCounted:
	return UnitFactory.from_character(Character.new(id, id, {}), "ally", row, skills, "ai", resources)


func _field(units: Array[RefCounted]) -> RefCounted:
	var f := Battlefield.new()
	for u in units:
		f.add(u)
	return f


## 丧尸偏好咬已经受伤的人（设计规格 4.6）。
func test_zombie_bites_wounded() -> void:
	var none: Array[String] = []
	var a := _human("a", 0, none)
	var b := _human("b", 0, none)
	b.hp -= 10.0
	var z := UnitFactory.from_enemy("zombie", "z", 0)
	var f := _field([a, b, z])
	var action := UtilityAi.choose(f, z, false, false)
	assert_eq(action, {"type": "skill", "skill": "zombie_bite", "targets": ["b"]})


func test_prefers_killing_blow() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 0, skills)
	var z1 := UnitFactory.from_enemy("zombie", "z1", 0)
	var z2 := UnitFactory.from_enemy("zombie", "z2", 1)
	z2.hp = 10.0
	var f := _field([h, z1, z2])
	assert_eq(UtilityAi.choose(f, h, false, false)["targets"], ["z2"])


func test_heals_badly_hurt_ally() -> void:
	var skills: Array[String] = ["pistol_shot", "first_aid_spray"]
	var medic := _human("medic", 1, skills, {"spray": 1})
	var none: Array[String] = []
	var hurt := _human("hurt", 0, none)
	hurt.hp = 30.0
	var f := _field([medic, hurt, UnitFactory.from_enemy("zombie", "z1", 0)])
	assert_eq(UtilityAi.choose(f, medic, false, false), {"type": "skill", "skill": "first_aid_spray", "targets": ["hurt"]})


func test_cures_infection() -> void:
	var skills: Array[String] = ["pistol_shot", "antidote"]
	var medic := _human("medic", 1, skills, {"antidote": 1})
	var none: Array[String] = []
	var bitten := _human("bitten", 0, none)
	Statuses.apply(bitten, "infection")
	var f := _field([medic, bitten, UnitFactory.from_enemy("zombie", "z1", 0)])
	assert_eq(UtilityAi.choose(f, medic, false, false)["skill"], "antidote")


## 只会近战、够不着的时候往前挪。
func test_melee_unit_moves_forward() -> void:
	var none: Array[String] = []
	var f := _field([_human("a", 0, none), UnitFactory.from_enemy("zombie", "z", 2)])
	var z: RefCounted = f.get_unit("z")
	assert_eq(UtilityAi.choose(f, z, false, false), {"type": "move", "row": 1})


func test_licker_targets_threat() -> void:
	var none: Array[String] = []
	var weak := _human("weak", 0, none)
	var strong := UnitFactory.from_character(Character.new("strong", "strong", {"muscle": 200}), "ally", 0, none)
	var licker := UnitFactory.from_enemy("licker", "l", 0)
	var f := _field([weak, strong, licker])
	assert_eq(UtilityAi.choose(f, licker, false, false)["targets"], ["strong"])


func test_choice_is_deterministic() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 0, skills)
	var f := _field([h, UnitFactory.from_enemy("zombie", "z1", 0), UnitFactory.from_enemy("zombie", "z2", 0)])
	var first := UtilityAi.choose(f, h, false, false)
	for i in 5:
		assert_eq(UtilityAi.choose(f, h, false, false), first)
	assert_eq(first["targets"], ["z1"])


func test_intent_view_levels() -> void:
	var z := UnitFactory.from_enemy("zombie", "z", 0)
	assert_false(bool(UtilityAi.intent_view(z, 2)["known"]))
	z.intent = {"type": "skill", "skill": "zombie_bite", "targets": ["a"]}
	assert_eq(UtilityAi.intent_view(z, 0), {"known": true, "kind": "attack"})
	assert_eq(UtilityAi.intent_view(z, 1), {"known": true, "kind": "attack", "skill": "zombie_bite", "skill_name": "撕咬"})
	assert_eq(UtilityAi.intent_view(z, 2)["targets"], ["a"])
	z.intent = {"type": "move", "row": 1}
	assert_eq(UtilityAi.intent_view(z, 2), {"known": true, "kind": "maneuver"})
```

- [ ] **Step 3：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_targeting bash game/tools/run_tests.sh; echo "exit=$?"`，再运行 `WSLENV=TEST_FILTER TEST_FILTER=test_utility_ai bash game/tools/run_tests.sh; echo "exit=$?"`

预期：两次都是对应文件 `FAIL ...（脚本无法加载）`，`!! 检测到脚本错误`，`exit=1`。

- [ ] **Step 4：创建 `game/core/battle/targeting.gd`**

```gdscript
extends RefCounted
## 合法行动（设计规格 4.3、4.4）：技能能不能用、能打谁；换位、防御、开基因锁、撤退。
## 近战只能打对方的"前排"（最前面还有人的一排），远程按技能的 target_rows 选排。
## 行动统一写成字典，玩家和 AI 用同一种格式：
##   {"type": "skill", "skill": 技能 id, "targets": [单位 id, ...]}
##   {"type": "move", "row": 目标排}、{"type": "defend"}、{"type": "gene_lock"}、{"type": "retreat"}

const BattleData = preload("res://core/battle/battle_data.gd")
const Battlefield = preload("res://core/battle/battlefield.gd")
const Statuses = preload("res://core/battle/statuses.gd")


static func _ints(values: Array) -> Array[int]:
	var out: Array[int] = []
	for v in values:
		out.append(int(v))
	return out


static func can_pay(u: RefCounted, skill: Dictionary) -> bool:
	var cost: Dictionary = skill.get("cost", {})
	for k: String in cost:
		if float(u.resources.get(k, 0.0)) < float(cost[k]):
			return false
	return true


static func on_cooldown(u: RefCounted, skill_id: String) -> bool:
	return int(u.cooldowns.get(skill_id, 0)) > 0


## 技能所有可选的目标组合，每个组合是一组单位 id。单体：每人一组；一排：每排一组；全体：一组。
static func target_choices(field: RefCounted, u: RefCounted, skill: Dictionary) -> Array[Array]:
	var out: Array[Array] = []
	var target_side := String(skill["target_side"])
	if target_side == "self":
		out.append([u.id])
		return out
	var side: String = u.side if target_side == "ally" else Battlefield.opponent(u.side)
	var allowed := _ints(skill["target_rows"])
	var rows: Array[int] = []
	if target_side == "enemy" and skill["reach"] == "melee":
		var front: int = field.front_row(side)
		if allowed.has(front):
			rows.append(front)
	else:
		rows = allowed
	var kind := String(skill["target_type"])
	if kind == "single":
		for t: RefCounted in field.side_units(side):
			if rows.has(t.row):
				out.append([t.id])
	elif kind == "row":
		for r in field.rows:
			if not rows.has(r):
				continue
			var ids: Array = []
			for t: RefCounted in field.row_units(side, r):
				ids.append(t.id)
			if not ids.is_empty():
				out.append(ids)
	else:
		var ids: Array = []
		for t: RefCounted in field.side_units(side):
			if rows.has(t.row):
				ids.append(t.id)
		if not ids.is_empty():
			out.append(ids)
	return out


static func usable(field: RefCounted, u: RefCounted, skill_id: String) -> bool:
	var skill := BattleData.skill(skill_id)
	if not _ints(skill["user_rows"]).has(u.row):
		return false
	if on_cooldown(u, skill_id) or not can_pay(u, skill):
		return false
	return not target_choices(field, u, skill).is_empty()


## 当前单位全部合法行动，顺序固定：技能（按单位技能顺序）、换位（先前后后）、防御、基因锁、撤退。
static func legal_actions(field: RefCounted, u: RefCounted, allow_retreat: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for skill_id in u.skills:
		if not usable(field, u, skill_id):
			continue
		for choice in target_choices(field, u, BattleData.skill(skill_id)):
			out.append({"type": "skill", "skill": skill_id, "targets": choice})
	for r: int in [u.row - 1, u.row + 1]:
		if field.can_place(u.side, r, u.size):
			out.append({"type": "move", "row": r})
	out.append({"type": "defend"})
	var g: Dictionary = BattleData.rules()["gene_lock"]
	if u.reincarnator and u.gene_lock_stage >= int(g["active_min_stage"]) and not Statuses.has(u, "gene_lock"):
		out.append({"type": "gene_lock"})
	if allow_retreat and u.side == "ally":
		out.append({"type": "retreat"})
	return out


static func is_legal(field: RefCounted, u: RefCounted, action: Dictionary, allow_retreat: bool) -> bool:
	return legal_actions(field, u, allow_retreat).has(action)
```

- [ ] **Step 5：创建 `game/core/battle/utility_ai.gd`**

```gdscript
extends RefCounted
## 确定性效用 AI（设计规格 4.6、8）：给每个合法行动打分，取最高分；同分取先出现的，所以同一局面总是同一个选择。
## 敌人在轮到自己之前就定好下一步（intent），玩家能看到多少取决于情报等级（设计规格 3.8）。

const BattleData = preload("res://core/battle/battle_data.gd")
const CombatMath = preload("res://core/battle/combat_math.gd")
const Statuses = preload("res://core/battle/statuses.gd")
const Targeting = preload("res://core/battle/targeting.gd")


## 攻击偏好：nearest 打前排，weakest 打残血比例高的，wounded 专咬已经受伤的（丧尸），threat 打攻击力高的。
static func profile_bonus(profile: String, t: RefCounted) -> float:
	match profile:
		"nearest":
			return float(2 - t.row) * 8.0
		"weakest":
			return (1.0 - t.hp_ratio()) * 20.0
		"wounded":
			return 25.0 if t.hp < t.hp_max else 0.0
		"threat":
			return t.attack_mult() * 10.0
	return 0.0


static func score(field: RefCounted, u: RefCounted, action: Dictionary, dark: bool) -> float:
	match String(action["type"]):
		"skill":
			return _score_skill(field, u, action, dark)
		"move":
			return 1.0 if int(action["row"]) < u.row else 0.0
		"defend":
			return 0.5
		"gene_lock":
			return 25.0 if u.hp_ratio() < 0.5 or u.fear >= 70.0 else 0.0
	return -1.0


static func _score_skill(field: RefCounted, u: RefCounted, action: Dictionary, dark: bool) -> float:
	var skill := BattleData.skill(String(action["skill"]))
	var total := 0.0
	for tid: String in action["targets"]:
		var t: RefCounted = field.get_unit(tid)
		if float(skill.get("power", 0.0)) > 0.0:
			var dmg := CombatMath.damage(u, t, skill, 0.5)
			var expected := CombatMath.hit_chance(u, t, skill, dark) * dmg
			total += minf(expected, t.hp) / t.hp_max * 100.0
			if dmg >= t.hp:
				total += 30.0
			total += profile_bonus(u.ai_profile, t)
		if skill.has("heal") and t.hp_ratio() < 0.5:
			total += minf(float(skill["heal"]), t.hp_max - t.hp) / t.hp_max * 100.0 + 40.0
		for c: String in skill.get("cleanse", []):
			if Statuses.has(t, c):
				total += 60.0
		if float(skill.get("fear", 0.0)) < 0.0:
			total += maxf(0.0, t.fear - 30.0) * 0.5
	var cost: Dictionary = skill.get("cost", {})
	for k: String in cost:
		total -= float(cost[k]) * 0.5
	return total


## 返回得分最高的合法行动。
static func choose(field: RefCounted, u: RefCounted, allow_retreat: bool, dark: bool) -> Dictionary:
	var best: Dictionary = {}
	var best_score := -INF
	for a in Targeting.legal_actions(field, u, allow_retreat):
		var s := score(field, u, a, dark)
		if s > best_score:
			best = a
			best_score = s
	return best


## 把意图按情报等级翻译给界面：0 只知道大类（攻击 / 支援 / 调整），1 知道用什么技能，2 还知道打谁。
static func intent_view(u: RefCounted, intel: int) -> Dictionary:
	var a: Dictionary = u.intent
	if a.is_empty():
		return {"known": false}
	var view := {"known": true, "kind": "maneuver"}
	if a["type"] == "skill":
		var skill := BattleData.skill(String(a["skill"]))
		view["kind"] = "attack" if skill["target_side"] == "enemy" else "support"
		if intel >= 1:
			view["skill"] = a["skill"]
			view["skill_name"] = skill["name"]
		if intel >= 2:
			view["targets"] = (a["targets"] as Array).duplicate()
	return view
```

- [ ] **Step 6：运行，确认通过**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_targeting bash game/tools/run_tests.sh; echo "exit=$?"`，再运行 `WSLENV=TEST_FILTER TEST_FILTER=test_utility_ai bash game/tools/run_tests.sh; echo "exit=$?"`

预期：第一次 `共 8 个测试，失败 0 个`，第二次 `共 8 个测试，失败 0 个`，都是 `exit=0`。

- [ ] **Step 7：提交**

```bash
git add game/core/battle/targeting.gd game/core/battle/utility_ai.gd game/tests/unit/battle/test_targeting.gd game/tests/unit/battle/test_utility_ai.gd
git commit -m "feat(battle): 合法行动与确定性效用 AI、敌人意图" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

### Task 6：战斗控制器

**Files:**
- Create: `game/core/battle/battle.gd`
- Test: `game/tests/unit/battle/test_battle.gd`

- [ ] **Step 1：写测试 `game/tests/unit/battle/test_battle.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
const Battle = preload("res://core/battle/battle.gd")
const Statuses = preload("res://core/battle/statuses.gd")
const Rng = preload("res://core/util/rng.gd")


func _human(id: String, row: int, skills: Array[String], controller: String = "player", resources: Dictionary = {}) -> RefCounted:
	return UnitFactory.from_character(Character.new(id, id, {}), "ally", row, skills, controller, resources)


## 速度很慢的丧尸：测试里它基本不会抢在我方前面行动。
func _slow_zombie(id: String, hp: float = 40.0) -> RefCounted:
	var z := UnitFactory.from_enemy("zombie", id, 0)
	z.base_speed = 10.0
	z.hp = hp
	z.hp_max = hp
	return z


func _types(events: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for e in events:
		out.append(String(e["type"]))
	return out


func _find(events: Array[Dictionary], type: String) -> Dictionary:
	for e in events:
		if e["type"] == type:
			return e
	return {}


func test_setup_waits_for_player() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 0, skills)
	var b := Battle.new()
	var units: Array[RefCounted] = [h, _slow_zombie("z")]
	var events := b.setup(units, {}, Rng.new(1))
	assert_eq(events[0]["type"], "battle_start")
	assert_eq(b.outcome, "ongoing")
	assert_eq(b.current, h)
	assert_true(b.legal_actions().has({"type": "skill", "skill": "pistol_shot", "targets": ["z"]}))
	assert_eq(b.timeline(10).size(), 10)
	assert_eq(b.timeline(10)[0], "h")


## 爬行者登场：新人恐惧 +15；舌头先手，先于玩家行动。
func test_fear_aura_and_licker_first() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 0, skills)
	var licker := UnitFactory.from_enemy("licker", "l", 0)
	var b := Battle.new()
	var units: Array[RefCounted] = [h, licker]
	var events := b.setup(units, {}, Rng.new(3))
	var fear := _find(events, "fear_changed")
	assert_eq(fear["reason"], "enemy_appear")
	assert_almost(float(fear["amount"]), 15.0)
	var first_turn := _find(events, "turn_start")
	assert_eq(first_turn["unit"], "l")


func test_invalid_action_rejected() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 0, skills)
	var b := Battle.new()
	var units: Array[RefCounted] = [h, _slow_zombie("z")]
	b.setup(units, {}, Rng.new(1))
	var events := b.act({"type": "skill", "skill": "grenade", "targets": ["z"]})
	assert_eq(_types(events), ["invalid_action"] as Array[String])
	assert_eq(b.current, h)


func test_player_kills_zombie_and_wins() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 0, skills)
	var b := Battle.new()
	var units: Array[RefCounted] = [h, _slow_zombie("z", 1.0)]
	b.setup(units, {}, Rng.new(7))
	var guard := 0
	while b.outcome == "ongoing" and guard < 20:
		b.act({"type": "skill", "skill": "pistol_shot", "targets": ["z"]})
		guard += 1
	assert_eq(b.outcome, "victory")
	assert_eq(b.history[b.history.size() - 1], {"type": "battle_end", "outcome": "victory"})
	assert_true(_types(b.history).has("death"))


func test_enemy_intent_is_planned() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 0, skills)
	var b := Battle.new()
	var units: Array[RefCounted] = [h, _slow_zombie("z")]
	b.setup(units, {}, Rng.new(1))
	assert_eq(b.intent_view("z", 2), {"known": true, "kind": "attack", "skill": "zombie_bite", "skill_name": "撕咬", "targets": ["h"]})
	assert_eq(b.intent_view("z", 0), {"known": true, "kind": "attack"})


## 队友死亡：其他人恐惧 +20。
func test_ally_death_raises_fear() -> void:
	var none: Array[String] = []
	var dying := _human("dying", 0, none, "ai")
	dying.hp = 3.0
	Statuses.apply(dying, "bleed")
	var watcher := _human("watcher", 0, none)
	var b := Battle.new()
	var units: Array[RefCounted] = [dying, watcher, _slow_zombie("z")]
	var events := b.setup(units, {}, Rng.new(1))
	assert_false(dying.alive)
	assert_eq(_find(events, "death")["target"], "dying")
	var last_fear: Dictionary = {}
	for e in events:
		if e["type"] == "fear_changed" and e["target"] == "watcher":
			last_fear = e
	assert_eq(last_fear["reason"], "ally_death")
	assert_almost(watcher.fear, 3.0 + 20.0)
	assert_eq(b.current, watcher)


## 感染倒计时走完：变成丧尸，算死亡。
func test_infection_turns_ally() -> void:
	var none: Array[String] = []
	var bitten := _human("bitten", 0, none, "ai")
	Statuses.apply(bitten, "infection")
	bitten.statuses[0]["remaining"] = 1
	var other := _human("other", 0, none)
	var b := Battle.new()
	var units: Array[RefCounted] = [bitten, other, _slow_zombie("z")]
	var events := b.setup(units, {}, Rng.new(1))
	assert_true(bitten.turned)
	assert_eq(_find(events, "death"), {"type": "death", "target": "bitten", "turned": true})


## 持续伤害把生命打到 25% 以下，触发一次觉醒检定（成功或失败都会有事件）。
func test_low_hp_triggers_awaken_check() -> void:
	var none: Array[String] = []
	var h := _human("h", 0, none)
	h.hp = h.hp_max * 0.25 + 2.0
	Statuses.apply(h, "bleed")
	var b := Battle.new()
	var units: Array[RefCounted] = [h, _slow_zombie("z")]
	var events := b.setup(units, {}, Rng.new(1))
	var types := _types(events)
	assert_true(types.has("gene_lock_awaken") or types.has("awaken_failed"), str(types))
	assert_true(h.low_hp_checked)


## 恐慌时不听指挥：玩家的单位自动乱动，恐慌结束后才把控制权交回玩家。
func test_panic_takes_control() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 0, skills)
	Statuses.apply(h, "panic")
	var b := Battle.new()
	var units: Array[RefCounted] = [h, _slow_zombie("z", 500.0)]
	var events := b.setup(units, {}, Rng.new(5))
	var panic_count := 0
	for t in _types(events):
		if t.begins_with("panic_") or t == "fled":
			panic_count += 1
	assert_eq(panic_count, 2)
	assert_false(Statuses.has(h, "panic"))
	assert_eq(b.current, h)


func test_survive_until() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 0, skills, "ai")
	var z := UnitFactory.from_enemy("zombie", "z", 0)
	z.hp = 1000.0
	z.hp_max = 1000.0
	var b := Battle.new()
	var units: Array[RefCounted] = [h, z]
	b.setup(units, {"survive_until": 300.0}, Rng.new(2))
	assert_eq(b.outcome, "survived")
	assert_true(h.alive)


## 重生十字章：死亡时消耗一次，以 30% 生命复活。
func test_rebirth_cross_revives() -> void:
	var none: Array[String] = []
	var h := _human("h", 0, none, "player", {"rebirth_cross": 1})
	h.hp = 3.0
	Statuses.apply(h, "bleed")
	var b := Battle.new()
	var units: Array[RefCounted] = [h, _slow_zombie("z")]
	var events := b.setup(units, {}, Rng.new(1))
	assert_eq(_find(events, "revived"), {"type": "revived", "target": "h", "hp": 42.0})
	assert_true(h.alive)
	assert_eq(h.revive_charges, 0)
	assert_eq(b.current, h)


func test_retreat() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 0, skills)
	var b := Battle.new()
	var units: Array[RefCounted] = [h, _slow_zombie("z")]
	b.setup(units, {"allow_retreat": true}, Rng.new(1))
	var events := b.act({"type": "retreat"})
	assert_eq(b.outcome, "retreat")
	assert_eq(events[events.size() - 1], {"type": "battle_end", "outcome": "retreat"})
	assert_eq(b.legal_actions().size(), 0)


## 黑暗：我方每次轮到自己，恐惧 +4。
func test_darkness_adds_fear() -> void:
	var skills: Array[String] = ["pistol_shot"]
	var h := _human("h", 0, skills)
	var b := Battle.new()
	var units: Array[RefCounted] = [h, _slow_zombie("z", 500.0)]
	b.setup(units, {"dark": true}, Rng.new(1))
	assert_almost(h.fear, 3.0 + 4.0)
	b.act({"type": "defend"})
	assert_almost(h.fear, 3.0 + 8.0)


## 鼓舞冷却 3：用完之后接下来三次轮到自己都不能用。
func test_cooldown_blocks_reuse() -> void:
	var skills: Array[String] = ["encourage"]
	var h := _human("h", 0, skills)
	var b := Battle.new()
	var units: Array[RefCounted] = [h, _slow_zombie("z", 500.0)]
	b.setup(units, {}, Rng.new(1))
	var encourage := {"type": "skill", "skill": "encourage", "targets": ["h"]}
	b.act(encourage)
	for i in 3:
		assert_false(b.legal_actions().has(encourage), "第 %d 次" % i)
		b.act({"type": "defend"})
	assert_true(b.legal_actions().has(encourage))


func test_items_are_consumed() -> void:
	var skills: Array[String] = ["grenade"]
	var h := _human("h", 0, skills, "player", {"grenade": 1})
	var b := Battle.new()
	var units: Array[RefCounted] = [h, _slow_zombie("z1", 500.0), _slow_zombie("z2", 500.0)]
	b.setup(units, {}, Rng.new(1))
	b.act({"type": "skill", "skill": "grenade", "targets": ["z1", "z2"]})
	assert_almost(float(h.resources["grenade"]), 0.0)
	assert_false(b.legal_actions().has({"type": "skill", "skill": "grenade", "targets": ["z1", "z2"]}))


## 双方都打不动对方时，行动次数到上限就结束，避免死循环。
func test_timeout_guard() -> void:
	var none: Array[String] = []
	var h := _human("h", 0, none, "ai")
	var z := UnitFactory.from_enemy("zombie", "z", 0)
	z.skills.clear()
	var b := Battle.new()
	var units: Array[RefCounted] = [h, z]
	b.setup(units, {}, Rng.new(1))
	assert_eq(b.outcome, "timeout")
	assert_eq(b.action_count, 2000)
```

- [ ] **Step 2：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_battle.gd bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`FAIL  res://tests/unit/battle/test_battle.gd（脚本无法加载）`，`!! 检测到脚本错误`，`exit=1`。

- [ ] **Step 3：创建 `game/core/battle/battle.gd`**

```gdscript
extends RefCounted
## 一场战斗（设计规格第 4 节）。输入是单位和玩家的行动，输出是一串事件，界面只按事件播放表现。
## 用法：
##   var b := Battle.new()
##   var events := b.setup(units, {"dark": false}, Rng.new(seed))   # AI 单位会自动行动，直到轮到玩家或战斗结束
##   while b.outcome == "ongoing":
##       events = b.act(玩家从 b.legal_actions() 里选的一项)
## outcome：ongoing（进行中）、victory、defeat、retreat（撤退）、survived（撑到时限）、timeout（行动次数超上限）。

const BattleData = preload("res://core/battle/battle_data.gd")
const Battlefield = preload("res://core/battle/battlefield.gd")
const Ctb = preload("res://core/battle/ctb.gd")
const Statuses = preload("res://core/battle/statuses.gd")
const CombatMath = preload("res://core/battle/combat_math.gd")
const Fear = preload("res://core/battle/fear.gd")
const Targeting = preload("res://core/battle/targeting.gd")
const UtilityAi = preload("res://core/battle/utility_ai.gd")

var field: RefCounted
var ctb: RefCounted
var rng: RefCounted
var dark: bool = false
var allow_retreat: bool = false
## 坚持到这个时刻（CTB 时间）就算撑过去；小于 0 表示不限时。
var survive_until: float = -1.0
var outcome: String = "ongoing"
## 正在等待玩家下令的单位；不在玩家回合时为 null。
var current: RefCounted = null
var action_count: int = 0
var max_actions: int = 2000
## 全部事件，按发生顺序。
var history: Array[Dictionary] = []


## options：row_capacity（每排容量）、dark（黑暗）、allow_retreat（允许撤退）、survive_until（坚持到的时刻）。
func setup(units: Array[RefCounted], options: Dictionary, random: RefCounted) -> Array[Dictionary]:
	rng = random
	field = Battlefield.new(int(options.get("row_capacity", -1)))
	ctb = Ctb.new()
	dark = bool(options.get("dark", false))
	allow_retreat = bool(options.get("allow_retreat", false))
	survive_until = float(options.get("survive_until", -1.0))
	max_actions = int(BattleData.rules()["max_actions"])
	var events: Array[Dictionary] = []
	var placed: Array[String] = []
	for u in units:
		if field.add(u):
			ctb.init_unit(u)
			placed.append(u.id)
		else:
			events.append({"type": "placement_failed", "target": u.id})
	events.append({"type": "battle_start", "units": placed})
	var aura := 0.0
	for e: RefCounted in field.side_units("enemy"):
		aura += e.fear_aura
	if aura > 0.0:
		for a: RefCounted in field.side_units("ally"):
			_add_fear(a, aura, "enemy_appear", events)
	for u in field.units:
		if u.controller == "ai":
			_plan(u)
	_advance(events)
	return _emit(events)


## 玩家下令。不合法的行动会被拒绝，战斗状态不变。
func act(action: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if outcome != "ongoing" or current == null or not Targeting.is_legal(field, current, action, allow_retreat):
		events.append({"type": "invalid_action", "action": action})
		return events
	_perform(current, action, events)
	_advance(events)
	return _emit(events)


func legal_actions() -> Array[Dictionary]:
	if outcome != "ongoing" or current == null:
		return []
	return Targeting.legal_actions(field, current, allow_retreat)


## 界面上方的时间轴：接下来 count 次行动的单位 id。
func timeline(count: int = 10) -> Array[String]:
	return ctb.preview(field.units, count)


func intent_view(unit_id: String, intel: int) -> Dictionary:
	return UtilityAi.intent_view(field.get_unit(unit_id), intel)


func _emit(events: Array[Dictionary]) -> Array[Dictionary]:
	history.append_array(events)
	return events


## 推进时间轴，让 AI 和失控的单位行动，直到轮到玩家或战斗结束。
func _advance(events: Array[Dictionary]) -> void:
	while true:
		if _check_end(events):
			return
		if action_count >= max_actions:
			_finish("timeout", events)
			return
		var u: RefCounted = ctb.next_actor(field.units)
		if survive_until >= 0.0 and u.next_time >= survive_until:
			_finish("survived", events)
			return
		events.append({"type": "turn_start", "unit": u.id, "time": u.next_time})
		events.append_array(Statuses.start_of_turn(u))
		_after_hp_loss(u, events)
		if not u.in_play():
			continue
		if dark and u.side == "ally":
			_add_fear(u, float(BattleData.rules()["fear"]["darkness_per_turn"]), "darkness", events)
		if Statuses.has_flag(u, "skip_turn"):
			events.append({"type": "turn_skipped", "unit": u.id})
			_end_turn(u, 1.0, "")
			continue
		if Statuses.has_flag(u, "panic"):
			_panic_action(u, events)
			continue
		if u.controller == "player":
			current = u
			return
		var action: Dictionary = u.intent
		if action.is_empty() or not Targeting.is_legal(field, u, action, false):
			action = UtilityAi.choose(field, u, false, dark)
		_perform(u, action, events)


func _perform(u: RefCounted, action: Dictionary, events: Array[Dictionary]) -> void:
	current = null
	events.append({"type": "action", "unit": u.id, "action": action})
	var delays: Dictionary = BattleData.rules()["delay_mult"]
	var mult := 1.0
	var used := ""
	match String(action["type"]):
		"skill":
			used = String(action["skill"])
			mult = _use_skill(u, action, events)
		"move":
			field.move(u, int(action["row"]))
			events.append({"type": "moved", "unit": u.id, "row": u.row})
			mult = float(delays["move"])
		"defend":
			events.append(Statuses.apply(u, "defending"))
			mult = float(delays["defend"])
		"gene_lock":
			u.aftereffect = true
			events.append(Statuses.apply(u, "gene_lock"))
			mult = float(delays["gene_lock"])
		"retreat":
			_finish("retreat", events)
	_end_turn(u, mult, used)


## 行动结束：排下一次行动；冷却减 1（本回合刚用的技能不减）；AI 单位定好下一步意图。
func _end_turn(u: RefCounted, mult: float, used_skill: String) -> void:
	ctb.advance(u, mult)
	action_count += 1
	for k: String in u.cooldowns.keys():
		if k != used_skill:
			u.cooldowns[k] = maxi(0, int(u.cooldowns[k]) - 1)
	if u.controller == "ai" and u.in_play() and outcome == "ongoing":
		_plan(u)


func _plan(u: RefCounted) -> void:
	u.intent = UtilityAi.choose(field, u, false, dark)


func _use_skill(u: RefCounted, action: Dictionary, events: Array[Dictionary]) -> float:
	var skill_id := String(action["skill"])
	var skill := BattleData.skill(skill_id)
	var cost: Dictionary = skill.get("cost", {})
	for k: String in cost:
		u.resources[k] = float(u.resources.get(k, 0.0)) - float(cost[k])
	if skill.has("cooldown"):
		u.cooldowns[skill_id] = int(skill["cooldown"])
	for tid: String in action["targets"]:
		var t: RefCounted = field.get_unit(tid)
		if t != null and t.in_play():
			_apply_skill(u, t, skill_id, events)
	return float(skill.get("delay_mult", 1.0))


## 一个技能作用到一个目标：命中 → 伤害 → 治疗 → 净化 → 恐惧 → 附加状态。
func _apply_skill(u: RefCounted, t: RefCounted, skill_id: String, events: Array[Dictionary]) -> void:
	var skill := BattleData.skill(skill_id)
	if skill.has("accuracy") and rng.randf() >= CombatMath.hit_chance(u, t, skill, dark):
		events.append({"type": "miss", "source": u.id, "target": t.id, "skill": skill_id})
		return
	if float(skill.get("power", 0.0)) > 0.0:
		_deal_damage(u, t, CombatMath.damage(u, t, skill, rng.randf()), events)
		if not t.in_play():
			return
	if skill.has("heal"):
		var before: float = t.hp
		t.hp = minf(t.hp + float(skill["heal"]), t.hp_max)
		events.append({"type": "heal", "source": u.id, "target": t.id, "amount": t.hp - before, "hp": t.hp})
	for c: String in skill.get("cleanse", []):
		if Statuses.remove(t, c):
			events.append({"type": "status_removed", "target": t.id, "status": c})
	if skill.has("fear"):
		_add_fear(t, float(skill["fear"]), "skill", events)
	for a: Dictionary in skill.get("applies", []):
		if rng.randf() < float(a["chance"]):
			events.append(Statuses.apply(t, String(a["status"])))


func _deal_damage(src: RefCounted, t: RefCounted, amount: float, events: Array[Dictionary]) -> void:
	t.hp -= amount
	events.append({"type": "damage", "source": src.id, "target": t.id, "amount": amount, "hp": t.hp})
	if t.hp > 0.0 and amount >= float(BattleData.rules()["fear"]["heavy_wound_ratio"]) * t.hp_max and not Statuses.has_flag(t, "no_pain"):
		_add_fear(t, float(BattleData.rules()["fear"]["heavy_wound"]), "heavy_wound", events)
	_after_hp_loss(t, events)


## 掉血之后：死了就处理死亡（含复活道具），没死就看要不要做低血觉醒检定。
func _after_hp_loss(t: RefCounted, events: Array[Dictionary]) -> void:
	if t.fled:
		return
	if t.turned or t.hp <= 0.0:
		if t.alive or t.turned:
			_on_death(t, events)
		return
	if t.reincarnator and not t.low_hp_checked and t.hp_ratio() < float(BattleData.rules()["gene_lock"]["low_hp_ratio"]):
		events.append_array(Fear.check_low_hp(t, rng.randf()))


func _on_death(t: RefCounted, events: Array[Dictionary]) -> void:
	if t.revive_charges > 0 and not t.turned:
		t.revive_charges -= 1
		t.resources["rebirth_cross"] = t.revive_charges
		t.hp = roundf(t.hp_max * float(BattleData.rules()["revive_hp_ratio"]))
		events.append({"type": "revived", "target": t.id, "hp": t.hp})
		return
	t.alive = false
	events.append({"type": "death", "target": t.id, "turned": t.turned})
	for ally: RefCounted in field.side_units(t.side):
		_add_fear(ally, float(BattleData.rules()["fear"]["ally_death"]), "ally_death", events)


func _add_fear(u: RefCounted, amount: float, reason: String, events: Array[Dictionary]) -> void:
	var delta := Fear.gain(u, amount)
	if delta != 0.0:
		events.append({"type": "fear_changed", "target": u.id, "amount": delta, "fear": u.fear, "reason": reason})
	if u.fear >= Fear.max_fear() and not u.fear_checked:
		events.append_array(Fear.check_full_fear(u, rng.randf()))


## 恐慌（设计规格 3.5）：不听指挥，发呆、往后逃（已在后排就逃离战场），或者对随便一个人出手（可能误伤队友）。
func _panic_action(u: RefCounted, events: Array[Dictionary]) -> void:
	var p: Dictionary = BattleData.rules()["panic"]
	var r: float = rng.randf()
	if r < float(p["freeze"]):
		events.append({"type": "panic_freeze", "unit": u.id})
	elif r < float(p["freeze"]) + float(p["flee"]):
		if field.move(u, u.row + 1):
			events.append({"type": "panic_flee", "unit": u.id, "row": u.row})
		else:
			u.fled = true
			events.append({"type": "fled", "unit": u.id})
	else:
		var others: Array[RefCounted] = []
		for o in field.units:
			if o != u and o.in_play():
				others.append(o)
		var skill_id := "punch"
		for s in u.skills:
			if float(BattleData.skill(s).get("power", 0.0)) > 0.0:
				skill_id = s
				break
		if not others.is_empty():
			var t: RefCounted = others[rng.randi_range(0, others.size() - 1)]
			events.append({"type": "panic_misfire", "unit": u.id, "target": t.id, "skill": skill_id})
			_apply_skill(u, t, skill_id, events)
	_end_turn(u, float(BattleData.rules()["delay_mult"]["panic"]), "")


func _check_end(events: Array[Dictionary]) -> bool:
	if outcome != "ongoing":
		return true
	if field.side_units("enemy").is_empty():
		_finish("victory", events)
		return true
	if field.side_units("ally").is_empty():
		_finish("defeat", events)
		return true
	return false


func _finish(result: String, events: Array[Dictionary]) -> void:
	if outcome != "ongoing":
		return
	outcome = result
	current = null
	events.append({"type": "battle_end", "outcome": result})
```

- [ ] **Step 4：运行，确认通过**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_battle.gd bash game/tools/run_tests.sh; echo "exit=$?"`

预期：16 个 `ok`，`共 16 个测试，失败 0 个`，`exit=0`。

- [ ] **Step 5：提交**

```bash
git add game/core/battle/battle.gd game/tests/unit/battle/test_battle.gd
git commit -m "feat(battle): 战斗控制器：回合推进、行动结算、恐慌、死亡与胜负" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

### Task 7：战斗模拟

**Files:**
- Create: `game/core/battle/battle_sim.gd`
- Test: `game/tests/unit/battle/test_battle_sim.gd`

测试锚点（20 个种子，实测值）：三个拿手枪的新人打三只丧尸，胜率 1.0；打一只爬行者，胜率 0.0；换成每人两颗手榴弹，胜率 0.95；黑暗中打丧尸，平均每场死 0.25 人（白天 0）。

- [ ] **Step 1：写测试 `game/tests/unit/battle/test_battle_sim.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
const BattleSim = preload("res://core/battle/battle_sim.gd")


func _seeds(n: int) -> Array[int]:
	var out: Array[int] = []
	for i in n:
		out.append(i + 1)
	return out


## 三个拿手枪的新人。
func _squad(resources: Dictionary = {}) -> Array[RefCounted]:
	var out: Array[RefCounted] = []
	var skills: Array[String] = ["pistol_shot"]
	if resources.has("grenade"):
		skills = ["grenade", "pistol_shot"]
	for i in 3:
		var ch := Character.new("p%d" % i, "新人%d" % i, {})
		out.append(UnitFactory.from_character(ch, "ally", i % 2, skills, "ai", resources))
	return out


func _vs_zombies() -> Array[RefCounted]:
	var units := _squad()
	for i in 3:
		units.append(UnitFactory.from_enemy("zombie", "z%d" % i, 0))
	return units


func _vs_licker() -> Array[RefCounted]:
	var units := _squad()
	units.append(UnitFactory.from_enemy("licker", "licker", 0))
	return units


func _vs_licker_with_grenades() -> Array[RefCounted]:
	var units := _squad({"grenade": 2})
	units.append(UnitFactory.from_enemy("licker", "licker", 0))
	return units


func test_same_seeds_same_result() -> void:
	var a := BattleSim.run(_vs_zombies, {}, _seeds(10))
	var b := BattleSim.run(_vs_zombies, {}, _seeds(10))
	assert_eq(a, b)
	assert_eq(int(a["battles"]), 10)


## 三个拿手枪的人对付三只丧尸：大多能赢。
func test_pistols_beat_zombies() -> void:
	var r := BattleSim.run(_vs_zombies, {}, _seeds(20))
	assert_true(float(r["win_rate"]) >= 0.8, str(r))


## 原著：爬行者是精英，手枪几乎无效，三个拿手枪的新人基本打不过。
func test_pistols_lose_to_licker() -> void:
	var r := BattleSim.run(_vs_licker, {}, _seeds(20))
	assert_true(float(r["win_rate"]) <= 0.2, str(r))


## 换成手榴弹（不吃爬行者的子弹减伤）胜率明显提高。
func test_grenades_help_against_licker() -> void:
	var pistols := BattleSim.run(_vs_licker, {}, _seeds(20))
	var grenades := BattleSim.run(_vs_licker_with_grenades, {}, _seeds(20))
	assert_true(float(grenades["win_rate"]) > float(pistols["win_rate"]) + 0.2, "%s / %s" % [pistols, grenades])


## 黑暗里打丧尸更难：人类命中下降、恐惧上升。
func test_darkness_makes_it_harder() -> void:
	var light := BattleSim.run(_vs_zombies, {}, _seeds(20))
	var dark := BattleSim.run(_vs_zombies, {"dark": true}, _seeds(20))
	assert_true(float(dark["avg_ally_deaths"]) > float(light["avg_ally_deaths"]), "%s / %s" % [light, dark])
```

- [ ] **Step 2：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_battle_sim bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`FAIL  res://tests/unit/battle/test_battle_sim.gd（脚本无法加载）`，`!! 检测到脚本错误`，`exit=1`。

- [ ] **Step 3：创建 `game/core/battle/battle_sim.gd`**

```gdscript
extends RefCounted
## 战斗模拟（设计规格 10.4）：双方都交给 AI，用一组种子各打一场，统计结果，用于平衡和回归测试。
## make_units 每次调用都要返回一组全新的单位（不能复用上一场打过的）。

const Battle = preload("res://core/battle/battle.gd")
const Rng = preload("res://core/util/rng.gd")


static func run(make_units: Callable, options: Dictionary, seeds: Array[int]) -> Dictionary:
	var outcomes: Dictionary = {}
	var actions := 0
	var ally_deaths := 0
	for s in seeds:
		var units: Array[RefCounted] = make_units.call()
		for u in units:
			u.controller = "ai"
		var b := Battle.new()
		b.setup(units, options, Rng.new(s))
		outcomes[b.outcome] = int(outcomes.get(b.outcome, 0)) + 1
		actions += b.action_count
		for u in units:
			if u.side == "ally" and not u.alive:
				ally_deaths += 1
	var n := float(seeds.size())
	return {
		"battles": seeds.size(),
		"outcomes": outcomes,
		"win_rate": float(outcomes.get("victory", 0)) / n,
		"avg_actions": float(actions) / n,
		"avg_ally_deaths": float(ally_deaths) / n,
	}
```

- [ ] **Step 4：运行，确认通过**

Run: `WSLENV=TEST_FILTER TEST_FILTER=test_battle_sim bash game/tools/run_tests.sh; echo "exit=$?"`

预期：5 个 `ok`，`共 5 个测试，失败 0 个`，`exit=0`。

- [ ] **Step 5：提交**

```bash
git add game/core/battle/battle_sim.gd game/tests/unit/battle/test_battle_sim.gd
git commit -m "feat(battle): AI 对 AI 的战斗模拟" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

### Task 8：全量验证与 uid 文件

- [ ] **Step 1：跑全部测试**

Run: `bash game/tools/run_tests.sh; echo "exit=$?"`

预期：结尾为 `共 119 个测试，失败 0 个`，`exit=0`，输出里没有 `SCRIPT ERROR`。

- [ ] **Step 2：导入工程**

Run: `godot --headless --path game --import; echo "exit=$?"`

预期：`exit=0`。

- [ ] **Step 3：查看新生成的 uid 文件**

Run: `git status --short`

预期：除了 `?? _work/`，正好是下面 23 行（顺序可能不同）：

```text
?? game/core/battle/battle.gd.uid
?? game/core/battle/battle_data.gd.uid
?? game/core/battle/battle_sim.gd.uid
?? game/core/battle/battle_unit.gd.uid
?? game/core/battle/battlefield.gd.uid
?? game/core/battle/combat_math.gd.uid
?? game/core/battle/ctb.gd.uid
?? game/core/battle/fear.gd.uid
?? game/core/battle/statuses.gd.uid
?? game/core/battle/targeting.gd.uid
?? game/core/battle/unit_factory.gd.uid
?? game/core/battle/utility_ai.gd.uid
?? game/tests/unit/battle/test_battle.gd.uid
?? game/tests/unit/battle/test_battle_data.gd.uid
?? game/tests/unit/battle/test_battle_sim.gd.uid
?? game/tests/unit/battle/test_battle_unit.gd.uid
?? game/tests/unit/battle/test_battlefield.gd.uid
?? game/tests/unit/battle/test_combat_math.gd.uid
?? game/tests/unit/battle/test_ctb.gd.uid
?? game/tests/unit/battle/test_fear.gd.uid
?? game/tests/unit/battle/test_statuses.gd.uid
?? game/tests/unit/battle/test_targeting.gd.uid
?? game/tests/unit/battle/test_utility_ai.gd.uid
```

- [ ] **Step 4：提交 uid 文件**

```bash
git add game/core/battle/*.gd.uid game/tests/unit/battle/*.gd.uid
git commit -m "chore: 纳入计划 2 新脚本的 uid 文件" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
git log --oneline -9
```

预期：`git status --short` 只剩 `?? _work/`；`git log --oneline -9` 最上面 8 个是本计划的提交（Task 1~7 各一个，加上 uid 一个），第 9 个是提交本计划的 `docs: 计划 2 战斗内核与任务卡 004`。**不要推送。**
