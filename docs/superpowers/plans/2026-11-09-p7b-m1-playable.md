# 计划 7b：M1 可玩切片 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 M1 从"只有规则"做成"能点着玩"：一局游戏的状态与存档、地点图与手表、战斗界面、结算与休整入口。走通"新游戏 → 生化危机一 → 丧尸战 → 回归结算 → 主神空间第 1 天"，PC 上可玩，全程有无头验收。

**Architecture:** `core/session/session.gd` 管一局的阶段（expedition → settlement → hub → done）和整局存档；`ui/expedition/`、`ui/battle/` 各自有一个只读状态的 View 层（RefCounted）和一个 Control 界面，界面不写规则；`ui/main.gd` 只负责换屏。字体用系统字体（`SystemFont`），不往仓库塞字体文件；地点坐标写在剧本数据里。

**Tech Stack:** Godot 4.7.2（GDScript）、Control 程序化搭界面、JSON 存档。

**依据：** 设计规格 2、6.2、9.3、9.7、10.2；计划 7a 的 M1 内容。

**本计划的全部代码都已在临时目录里实际跑通：324 个无界面测试全过，切片验收 0 失败，三张界面截图人工看过。**

**执行环境注意：**
- 仓库根目录：Windows 上是 `I:\workspace\mobilegame\wuxian-kongbu\`；在 WSL 的 bash 里是 `/mnt/i/workspace/mobilegame/wuxian-kongbu`。所有命令都在仓库根目录执行。
- 只跑某个测试文件时用 `WSLENV=TEST_FILTER TEST_FILTER=<文件名> bash game/tools/run_tests.sh`。
- 所有文本文件用 **LF** 换行、UTF-8 无 BOM；GDScript 用 **Tab** 缩进，照抄时保留 Tab。
- **"确认失败"那一步**：测试引用了还不存在的脚本，会出现 `FAIL ...（脚本无法加载）`、`!! 检测到脚本错误` 和 `exit=1`，都是预期的。
- 跑测试不会生成 `.gd.uid`，导入工程（Task 4）才会。Task 4 把这些文件一起提交。
- 界面脚本在 `game/ui/`，按 AGENTS.md 属于 Codex 的地盘；本计划是 M1 切片临时由 Claude 落地，后续 Codex 接界面时以这里的 View 层接口为准。
- **只提交，不推送。**

---

## 设计要点

- **一局的状态**（`session.gd`）：`game`（GameState）+ `expedition`（当前远征）+ `phase` + `day`。阶段是 `expedition`（在片子里）→ `settlement`（刚回归，已结算）→ `hub`（主神空间休整 9 天）→ `done`（走光柱，M2 未做）。`settle()` 只结算一次；`advance_day()` 到第 9 天；`can_depart()` 满 9 天才让走。
- **整局存档**：`Session.to_dict()` 把 GameState、远征、阶段、天数、结算结果全写进一个 JSON；读档按章节重新加载剧本再恢复远征。远征中途、结算后、休整期都能存读档。
- **取数层**（`ExpeditionView` / `BattleView`）：把 core 的状态整理成界面能直接画的字典（地图、手表、成员、待办、单位卡、时间轴、行动分组）。界面只调用 View 的行动方法。
- **事件文本**（`event_text.gd`）：core 的事件翻译成一行中文；地点、剧情事件、线索、事实的中文名通过 `ExpeditionView` 的标签表传入，所以日志里不会出现 `control_console` 这种 id。
- **界面**：1920×1080、深色；地点图按剧本里的 `pos` 摆按钮，通路用线连；右侧是手表、成员、待办（选择/说服）和事件流；战斗界面 5 列敌人、7 列我方、时间轴、先选技能再选目标（同一技能多个目标会合组）、日志。
- **字体**：`SystemFont` 依次找 Noto Sans SC / 微软雅黑 / 苹方 / Noto Sans CJK，Windows 和安卓都能显示中文，不提交字体文件。
- **无头验收**（`tools/verify_m1_slice.gd`）：加载主场景，按真实界面路径走完原剧情路线（听规则 → 大厅 → 楼梯井扶人 → 激光通道救马修 → 主机房 → 丧尸战 → 留守 → 威胁火焰女皇 → 断电 → 回归），断言时钟、绑定、6500 点、B 支线、存档读档。加 `--capture` 可以截三张图到 `art_src/qa/`。
- **M1 完成度**：三处可感知分歧（救不救马修、扶不扶掉队新人、留守还是跟雇佣兵走）、结算数字、感染/绑定/禁言/断电都在这一层能触发；兑换、造人、训练场、AI 对话面板不在本切片（后续计划）。

**不在本计划范围**：主神空间的兑换/修复/造人/训练界面（T5）、对话与说服的 AI 面板（现在用四档按钮模拟对话层）、美术资源（全部用纯色面板和文字）、安卓导出预设、M2 内容。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `game/core/session/session.gd` | 一局的阶段、结算、休整天数、整局存读档 |
| `game/core/save/save_service.gd` | 新增整局 JSON 读写（保留原来的 GameState 读写） |
| `game/ui/event_text.gd` | 事件 → 一行中文 |
| `game/ui/ui_theme.gd` | 配色、字体、按钮/面板样式 |
| `game/ui/expedition/expedition_view.gd` | 地点图/手表/成员/待办/日志的取数 |
| `game/ui/expedition/expedition_screen.gd` | 地点图界面 |
| `game/ui/battle/battle_view.gd` | 单位卡/时间轴/行动分组的取数 |
| `game/ui/battle/battle_screen.gd` | 战斗界面 |
| `game/ui/main.gd`、`game/ui/main.tscn` | 换屏：远征 / 战斗 / 结算 / 休整 |
| `game/data/scenarios/biohazard1/scenario.json` | 地点加 `pos`，事件加 `label` |
| `game/tests/unit/session/test_session.gd` | 会话与存档（5 个） |
| `game/tests/unit/ui/test_views.gd` | 取数层（4 个） |
| `game/tools/verify_m1_slice.gd` | 切片无头验收 + 截图 |

---

### Task 1：会话与存档

**Files:**
- Create: `game/core/session/session.gd`、`game/tests/unit/session/test_session.gd`
- Modify: `game/core/save/save_service.gd`

- [ ] **Step 1：写测试 `game/tests/unit/session/test_session.gd`**

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
	assert_eq(s.day, 1)
	assert_eq(int(results["zheng_zha"]["final_points"]), 1000)
	assert_eq(s.settle(), {})
	assert_true(s.enter_hub())
	for i in 8:
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
	assert_eq(b.day, 2)
	assert_eq(int(b.game.characters["zheng_zha"].points), 1000)
	assert_eq(int(b.settlement["zheng_zha"]["final_points"]), 1000)
	assert_eq(b.to_dict()["expedition"], a.to_dict()["expedition"])
	_clean()


func test_reject_bad_save() -> void:
	assert_false(Session.new().load_dict({"version": 99}))
	assert_false(Session.new().load_dict({"version": 1, "chapter": "res://nope.json", "game": {}}))
	assert_true(Session.load_from("user://nope.json") == null)
```

- [ ] **Step 2：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=session/ bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`FAIL  res://tests/unit/session/test_session.gd（脚本无法加载）`，`!! 检测到脚本错误`，`exit=1`。

- [ ] **Step 3：创建 `game/core/session/session.gd`**

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

const VERSION := 1
const M1_CHAPTER := "res://data/scenarios/biohazard1/chapter.json"
const PHASES: Array[String] = ["expedition", "settlement", "hub", "done"]
const REST_DAYS := 9

var game: RefCounted
var expedition: RefCounted
var phase: String = "expedition"
var chapter_path: String = ""
## 休整第几天（settlement 时为 1）。
var day: int = 0
## 上一次结算的结果（角色 id → 结算条目），给结算界面用。
var settlement: Dictionary = {}


## 开一局：建 GameState、按章节装配七名轮回者、开始第一部片。
func start(chapter: String, seed_value: int = 0) -> bool:
	chapter_path = chapter
	game = GameState.new(seed_value)
	expedition = Campaign.start(game, chapter)
	if expedition == null:
		return false
	phase = "expedition"
	day = 0
	settlement = {}
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
	if not expedition.st.pending_battle.is_empty():
		return "battle"
	if not expedition.st.pending_choice.is_empty():
		return "choice"
	if not expedition.st.pending_check.is_empty():
		return "check"
	return ""


## 片子结束（回归、全灭或剧本结局）后结算一次，进入 settlement 阶段。
func settle() -> Dictionary:
	if phase != "expedition" or not expedition_over():
		return {}
	settlement = expedition.finish()
	phase = "settlement"
	day = 1
	return settlement


func enter_hub() -> bool:
	if phase != "settlement":
		return false
	phase = "hub"
	return true


func advance_day() -> bool:
	if phase != "hub" or day >= REST_DAYS:
		return false
	day += 1
	return true


func can_depart() -> bool:
	return phase == "hub" and day >= REST_DAYS


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
		"settlement": settlement.duplicate(true),
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

- [ ] **Step 4：改写 `game/core/save/save_service.gd`**

```gdscript
extends RefCounted
## 存档读写（JSON）。铁人模式只有一个存档位，由调用方传入固定路径。

const GameState = preload("res://core/model/game_state.gd")


static func save_to(path: String, state: RefCounted) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(state.to_dict(), "\t"))
	f.close()
	return OK


## 读档失败返回 null。
static func load_from(path: String) -> RefCounted:
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var state := GameState.new()
	state.load_dict(data)
	return state


## 整局存档（GameState + 远征 + 阶段）：写一个 JSON 对象，读不到返回空字典。
static func write_dict(path: String, data: Dictionary) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return OK


static func read_dict(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	return data
```

- [ ] **Step 5：运行，确认通过**

Run: `WSLENV=TEST_FILTER TEST_FILTER=session/ bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`共 5 个测试，失败 0 个`，`exit=0`。

- [ ] **Step 6：提交**

```bash
git add game/core/session/session.gd game/core/save/save_service.gd game/tests/unit/session/test_session.gd
git commit -m "feat(session): 一局的阶段、结算与整局存读档" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

### Task 2：取数层与内容标签

**Files:**
- Create: `game/ui/event_text.gd`、`game/ui/expedition/expedition_view.gd`、`game/ui/battle/battle_view.gd`、`game/tests/unit/ui/test_views.gd`
- Modify: `game/data/scenarios/biohazard1/scenario.json`

- [ ] **Step 1：写测试 `game/tests/unit/ui/test_views.gd`**

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
	assert_eq(by_id["control"]["pos"], Vector2(680, 210))
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
```

- [ ] **Step 2：运行，确认失败**

Run: `WSLENV=TEST_FILTER TEST_FILTER=unit/ui/ bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`FAIL  res://tests/unit/ui/test_views.gd（脚本无法加载）`（`ui/` 下的取数层还不存在），`!! 检测到脚本错误`，`exit=1`。

- [ ] **Step 3：创建 `game/ui/event_text.gd`**

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
		"searched":
			return "搜索完毕。"
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

- [ ] **Step 4：创建 `game/ui/expedition/expedition_view.gd`**

```gdscript
extends RefCounted
## 地点图与手表界面的取数层：把 Expedition 的状态整理成界面能直接画的东西。
## 界面只调用这里的行动方法，拿回事件；不在这里写规则。

const EventText = preload("res://ui/event_text.gd")
const Watch = preload("res://core/expedition/watch.gd")
const BattleData = preload("res://core/battle/battle_data.gd")

var ex: RefCounted
var names: Dictionary = {}

## names：角色 id → 显示名（界面从人物表传入，事件文本用）。
func _init(expedition: RefCounted, char_names: Dictionary = {}) -> void:
	ex = expedition
	names = char_names.duplicate()
	for npc_id: String in ex.st.scenario.data.get("npcs", {}):
		var def: Dictionary = ex.st.scenario.data["npcs"][npc_id]
		names[npc_id] = String(def.get("name", npc_id))
	for loc_id: String in ex.st.scenario.data.get("locations", {}):
		names[loc_id] = String(ex.st.scenario.location(loc_id).get("name", loc_id))
	for ev: Dictionary in ex.st.scenario.events():
		names[String(ev["id"])] = String(ev.get("label", ev["id"]))
	for fact_id: String in ex.st.scenario.data.get("facts", {}):
		var fact: Dictionary = ex.st.scenario.data["facts"][fact_id]
		names[fact_id] = String(fact.get("statement", fact_id))
		for clue_id: String in fact.get("clues", {}):
			names[clue_id] = String(fact.get("statement", clue_id))


func squad_id() -> String:
	for sid: String in ex.st.squads:
		if not ex.st.living_members(sid).is_empty():
			return sid
	return ""


func location() -> String:
	var sid := squad_id()
	return String(ex.st.squads[sid]["location"]) if sid != "" else ""


func blocked_reason() -> String:
	if ex.st.outcome != "ongoing":
		return "ended"
	if not ex.st.pending_battle.is_empty():
		return "battle"
	if not ex.st.pending_choice.is_empty():
		return "choice"
	if not ex.st.pending_check.is_empty():
		return "check"
	return ""


## 地图：每个地点的坐标、是否在这里、是否相邻可走、有没有搜过、黑不黑、有谁。
func map() -> Array[Dictionary]:
	var here := location()
	var around: Array[String] = ex.st.scenario.neighbors(here) if here != "" else []
	var out: Array[Dictionary] = []
	for loc_id: String in ex.st.scenario.data["locations"]:
		var info: Dictionary = ex.st.scenario.location(loc_id)
		var pos: Array = info.get("pos", [0, 0])
		var here_now := loc_id == here
		var adjacent := around.has(loc_id)
		out.append({
			"id": loc_id,
			"name": String(info.get("name", loc_id)),
			"pos": Vector2(float(pos[0]), float(pos[1])),
			"here": here_now,
			"adjacent": adjacent,
			"open": here_now or not adjacent or ex.st.is_path_open(here, loc_id),
			"searched": ex.st.searched.has(loc_id),
			"dark": Watch.is_dark(ex.st, loc_id),
			"npcs": _npcs_at(loc_id),
		})
	return out


func _npcs_at(loc_id: String) -> Array[String]:
	var out: Array[String] = []
	for npc_id: String in ex.st.npcs:
		if ex.st.npcs[npc_id]["location"] == loc_id and bool(ex.st.npcs[npc_id]["alive"]):
			var def: Dictionary = ex.st.scenario.data["npcs"].get(npc_id, {})
			out.append(String(def.get("name", npc_id)))
	return out


## 手表：主线、剩余时间、击杀、绑定、禁言。
func watch() -> Dictionary:
	var sid := squad_id()
	var who := ""
	if sid != "":
		var living: Array[String] = ex.st.living_members(sid)
		who = living[0] if not living.is_empty() else ""
	var view: Dictionary = ex.watch_view(who) if who != "" else {}
	var kills := 0
	var points := 0.0
	for c: String in ex.st.kill_counts:
		kills += int(ex.st.kill_counts[c])
	for c: String in ex.st.kill_points:
		points += float(ex.st.kill_points[c])
	var tether := ""
	if not ex.st.tether.is_empty():
		tether = "%s（%d 格内）" % [_name(String(ex.st.tether["npc"])), int(ex.st.tether["max_hops"])]
	return {
		"main_task": String(view.get("main_task", ex.st.scenario.data["main_task"])),
		"remaining_minutes": int(view.get("remaining_minutes", ex.st.scenario.data["duration_minutes"])),
		"clock": int(ex.st.clock),
		"kills": kills,
		"kill_points": points,
		"tether": tether,
		"gag": bool(ex.st.scenario.data["watch"].has("gag_penalty")),
		"dark": Watch.is_dark(ex.st, location()),
	}


## 当前分队的成员（活着的和死了的都列出来，界面上灰掉）。
func members() -> Array[Dictionary]:
	var sid := squad_id()
	var out: Array[Dictionary] = []
	if sid == "":
		return out
	for c: String in ex.st.squads[sid]["members"]:
		var ch: RefCounted = ex.st.characters[c]
		out.append({
			"id": c,
			"name": ch.display_name,
			"hp": ch.hp,
			"hp_max": ch.hp_max(),
			"fear": ch.fear,
			"alive": ch.alive,
			"infected": ex.st.infected.has(c),
		})
	return out


## 等待处理的事：选择、说服或战斗。
func pending() -> Dictionary:
	if not ex.st.pending_choice.is_empty():
		var c: Dictionary = ex.st.pending_choice
		var options: Array = []
		for o: Dictionary in c["options"]:
			options.append({"id": String(o["id"]), "text": String(o["text"])})
		return {"kind": "choice", "id": String(c["id"]), "prompt": String(c["prompt"]), "options": options}
	if not ex.st.pending_check.is_empty():
		var k: Dictionary = ex.st.pending_check
		return {"kind": "check", "id": String(k["id"]), "npc": _name(String(k["npc"])), "goal": String(k["goal"]), "difficulty": int(k["difficulty"]), "keywords": (k.get("keywords", []) as Array).duplicate()}
	if not ex.st.pending_battle.is_empty():
		var b: Dictionary = ex.st.pending_battle
		var enemies: Array = []
		for g: Dictionary in b["enemies"]:
			var def := String(g["def"])
			var info: Dictionary = BattleData.enemies().get(def, {})
			enemies.append("%s ×%d" % [String(info.get("name", def)), int(g.get("count", 1))])
		return {"kind": "battle", "location": String(b["location"]), "enemies": enemies}
	return {}


## 事件流（最近 n 条），已经翻成中文。
func log_tail(n: int = 8) -> Array[String]:
	var out: Array[String] = []
	var start := maxi(0, ex.history.size() - n)
	for i in range(start, ex.history.size()):
		var line := EventText.describe(ex.history[i], names)
		if line != "":
			out.append(line)
	return out


func can_move(to: String) -> bool:
	return blocked_reason() == "" and ex.st.scenario.neighbors(location()).has(to) and ex.st.is_path_open(location(), to)


func move(to: String) -> Array[Dictionary]:
	return ex.move(squad_id(), to)


func search() -> Array[Dictionary]:
	return ex.search(squad_id())


func rest(minutes: int = 10) -> Array[Dictionary]:
	return ex.rest(squad_id(), minutes)


func choose(option_id: String) -> Array[Dictionary]:
	return ex.choose(option_id)


func persuade(level: int) -> Array[Dictionary]:
	return ex.resolve_persuasion(level)


func use_item(char_id: String, item_id: String) -> Array[Dictionary]:
	return ex.use_item(char_id, item_id)


func deduce(fact_id: String, thinker_id: String) -> Array[Dictionary]:
	return ex.deduce(fact_id, thinker_id)


func battle_units() -> Array[RefCounted]:
	return ex.battle_units({})


func report_battle(battle: RefCounted) -> Array[Dictionary]:
	return ex.report_battle(battle)


func ended() -> bool:
	return ex.st.outcome != "ongoing"


func outcome() -> String:
	return ex.st.outcome


func _name(id: String) -> String:
	return String(names.get(id, id))
```

- [ ] **Step 5：创建 `game/ui/battle/battle_view.gd`**

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
		out.append({
			"id": u.id,
			"name": u.display_name,
			"side": u.side,
			"row": u.row,
			"hp": u.hp,
			"hp_max": u.hp_max,
			"fear": u.fear,
			"alive": u.alive,
			"fled": u.fled,
			"current": b.current != null and b.current.id == u.id,
			"statuses": _status_names(u),
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


## 目标标签：名字后面加编号和剩余生命，十个丧尸才分得清。
func _target_label(id: String) -> String:
	var name := String(names.get(id, id))
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

- [ ] **Step 6：改写 `game/data/scenarios/biohazard1/scenario.json`**

```json
{
	"id": "biohazard1",
	"name": "生化危机一",
	"start_location": "car",
	"duration_minutes": 187,
	"main_task": "存活 3 小时 07 分；不得离开马修 100 米",
	"locations": {
		"car": {"name": "高速车厢", "pos": [60, 520], "search": [{"item": "grenade", "count": 1}]},
		"hall": {"name": "蜂巢入口大厅", "pos": [220, 440]},
		"stairs": {"name": "楼梯井", "pos": [380, 350], "dark": true},
		"laser": {"name": "激光通道", "pos": [520, 290]},
		"control": {"name": "火焰女皇主机房", "pos": [680, 210], "search": [{"item": "spray", "count": 2}, {"item": "antidote", "count": 1}], "search_minutes": 20},
		"corridor": {"name": "实验区走廊", "pos": [680, 390]},
		"freezer": {"name": "冷冻仓库", "pos": [680, 550], "dark": true, "search": [{"item": "antidote", "count": 1}]},
		"sewer": {"name": "下水道", "pos": [380, 600], "dark": true}
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
				{"choice": {"id": "opening_attitude", "prompt": "张杰讲完规则，看着你们几个新人。", "options": [
					{"id": "listen", "text": "认真听完，记住每一条", "effects": [{"set_flag": "listened_rules"}]},
					{"id": "doubt", "text": "质疑：凭什么信你", "effects": [{"fear": {"amount": 5}}, {"set_flag": "doubted_rules"}, {"say": {"speaker": "zhang_jie", "text": "信不信由你，反正死的是你。"}}]},
					{"id": "mock", "text": "嘲讽他装神弄鬼", "effects": [{"fear": {"amount": 10}}, {"set_flag": "mocked_rules"}, {"say": {"speaker": "zhang_jie", "text": "有意思。等会儿别哭。"}}]}
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
						{"delay": {"minutes": 15}},
						{"fear": {"amount": 10}},
						{"set_flag": "helped_lagging"},
						{"say": {"speaker": "xiao_pang_zi", "text": "谢谢……谢谢郑哥。"}}
					]},
					{"id": "leave", "text": "不管他们，跟上雇佣兵", "effects": [
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
				{"say": {"speaker": "matthew", "text": "郑吒、牟钢，你们两个跟我进来。"}},
				{"give": {"recipients": ["zheng_zha"], "skill": "pistol_shot"}},
				{"choice": {"id": "laser_choice", "prompt": "激光网正在合拢，只有贴着大门的一小块地方是安全的。", "options": [
					{"id": "save_matthew", "text": "扑倒，拖着马修贴到门上", "effects": [
						{"open_path": ["laser", "control"]},
						{"side_plot": {"id": "save_matthew", "grade": "B", "points": 5000, "label": "救下马修"}},
						{"bonus": {"points": 500, "label": "精神临界值突破", "attributes": {"spirit": 20, "nerve_reaction": 30}}},
						{"tether_release": true},
						{"clue": "laser_survived"},
						{"say": {"speaker": "matthew", "text": "你救了我。为什么？"}}
					]},
					{"id": "self_only", "text": "只顾自己贴门，喊一声让他躲", "effects": [
						{"open_path": ["laser", "control"]},
						{"npc_die": "matthew"},
						{"fear": {"amount": 20}},
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
				{"battle": {"location": "control", "enemies": [{"def": "zombie", "count": 10, "row": 0}]}}
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
						{"say": {"speaker": "matthew", "text": "你们留下。卡普兰，把门锁死。"}}
					]},
					{"id": "follow", "text": "跟雇佣兵走下水道", "effects": [
						{"set_flag": "went_sewer"},
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
				{"persuade": {"id": "threaten_queen", "npc": "red_queen", "goal": "逼火焰女皇用激光杀掉爬行者", "difficulty": 2, "keywords": ["威胁", "断电", "激光"],
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

- [ ] **Step 7：运行，确认通过**

Run: `WSLENV=TEST_FILTER TEST_FILTER=unit/ui/ bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`共 4 个测试，失败 0 个`，`exit=0`。

- [ ] **Step 8：提交**

```bash
git add game/ui/event_text.gd game/ui/expedition/expedition_view.gd game/ui/battle/battle_view.gd game/tests/unit/ui/test_views.gd game/data/scenarios/biohazard1/scenario.json
git commit -m "feat(ui): 地点图、战斗与事件文本的取数层" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

### Task 3：界面与主场景

**Files:**
- Create: `game/ui/ui_theme.gd`、`game/ui/expedition/expedition_screen.gd`、`game/ui/battle/battle_screen.gd`、`game/ui/main.gd`、`game/ui/main.tscn`、`game/tools/verify_m1_slice.gd`
- Modify: `game/project.godot`

- [ ] **Step 1：创建 `game/tools/verify_m1_slice.gd`**（验收脚本）

```gdscript
extends SceneTree
## M1 可玩切片的无头验收：加载主场景，按真实界面路径走一遍
## 听规则 → 大厅 → 楼梯井（扶人）→ 激光通道（救马修）→ 主机房 → 丧尸战 → 留守
## → 威胁火焰女皇 → 断电 → 撑到回归 → 结算 → 主神空间 → 存档/读档。
## 用法：godot --headless --path game -s res://tools/verify_m1_slice.gd
## 加 --capture（不带 --headless）可以截一张结算后的图到 art_src/qa/。

const SAVE_PATH := "user://verify_m1_slice.json"

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var packed := load("res://ui/main.tscn") as PackedScene
	_expect(packed != null, "主场景可以加载")
	if packed == null:
		_finish()
		return
	var main: Control = packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var screen: Control = main.content.get_child(0)
	_expect(screen.has_method("press_choice"), "开局显示地点图界面")
	_expect(String(main.session.phase) == "expedition", "开局在远征阶段")
	_expect(int(main.session.game.characters.size()) == 7, "七名轮回者")

	_expect(screen.press_choice("listen"), "开场选择：听规则")
	_expect(screen.press_move("hall"), "走到大厅")
	_expect(screen.press_move("stairs"), "走到楼梯井")
	_expect(screen.press_choice("help"), "扶掉队的新人")
	_expect(screen.press_move("laser"), "走进激光通道")
	_expect(screen.press_choice("save_matthew"), "拖着马修贴门")
	_expect(screen.press_move("control"), "进入主机房")
	_expect(int(main.session.expedition.st.clock) == 45, "第 45 分钟到达主机房")
	_expect(main.session.expedition.st.tether.is_empty(), "救下马修后绑定解除")
	await _shot("m1_slice_expedition.png")

	screen.press_rest(25)
	await process_frame
	await process_frame
	var battle: Control = main.content.get_child(0)
	_expect(battle.has_method("press_action"), "第 70 分钟进入战斗界面")
	await _shot("m1_slice_battle.png")
	var guard := 0
	while battle.has_method("press_action") and not bool(battle.view.finished()) and guard < 400:
		battle.press_action(0)
		guard += 1
	_expect(guard < 400, "战斗在 400 个行动内结束")
	await process_frame
	await process_frame
	screen = main.content.get_child(0)
	_expect(screen.has_method("press_choice"), "战斗结束回到地点图")
	_expect(int(main.session.expedition.st.clock) == 70, "战斗结束停在第 70 分钟")
	_expect(main.session.expedition.st.pending_battle.is_empty(), "战斗已回报")

	screen.press_rest(20)
	await process_frame
	_expect(screen.press_choice("stay"), "第 90 分钟选择留守主机房")
	screen.press_rest(35)
	await process_frame
	_expect(screen.press_persuade(3), "第 125 分钟威胁火焰女皇")
	screen.press_rest(40)
	_expect(int(main.session.expedition.st.clock) == 165, "断电事件在第 160 分钟发生")
	screen.press_rest(5)
	screen.press_rest(17)
	await process_frame
	await process_frame
	_expect(String(main.session.phase) == "settlement", "撑到 3:07 后进入结算")
	_expect(_found_text(main.content, "6500"), "郑吒结算 6500 点")
	_expect(_found_text(main.content, "B 级支线"), "B 级支线入账")

	var hub_btn := _find_button(main.content, "进入主神空间")
	_expect(hub_btn != null, "结算界面有进入主神空间的按钮")
	if hub_btn != null:
		hub_btn.emit_signal("pressed")
		await process_frame
	_expect(String(main.session.phase) == "hub", "进入主神空间")
	_expect(_found_text(main.content, "第 1 天"), "休整第 1 天")

	main._on_save()
	main._on_load()
	await process_frame
	_expect(String(main.session.phase) == "hub", "读档回到主神空间")
	_expect(int(main.session.game.characters["zheng_zha"].points) == 6500, "读档后点数还在")

	await _shot("m1_slice_hub.png")

	_finish()


## 加 --capture 时把当前画面存到 art_src/qa/（只在非 headless 下有意义）。
func _shot(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://").path_join("../../art_src/qa")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name))


func _expect(cond: bool, message: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL " + message)


func _found_text(node: Node, needle: String) -> bool:
	if node is Label and String(node.text).contains(needle):
		return true
	if node is Button and String(node.text).contains(needle):
		return true
	for c in node.get_children():
		if _found_text(c, needle):
			return true
	return false


func _find_button(node: Node, text: String) -> Button:
	if node is Button and String(node.text) == text:
		return node
	for c in node.get_children():
		var b := _find_button(c, text)
		if b != null:
			return b
	return null


func _finish() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("M1 切片验证：失败 %d 项" % failures)
	quit(0 if failures == 0 else 1)
```

- [ ] **Step 2：运行，确认失败**

Run: `godot --headless --path game -s res://tools/verify_m1_slice.gd; echo "exit=$?"`

预期：`FAIL 主场景可以加载`，`M1 切片验证：失败 1 项`，`exit=1`（`ui/main.tscn` 还不存在）。

- [ ] **Step 3：创建 `game/ui/ui_theme.gd`**

```gdscript
extends RefCounted
## 界面配色与字体：中文字体用系统字体（Windows 的微软雅黑 / 安卓的 Noto Sans CJK），不往仓库塞字体文件。
## 界面统一从这里取颜色，别在各处写死。

const BG := Color("12141a")
const PANEL := Color("1b1f28")
const PANEL_LIGHT := Color("232936")
const LINE := Color("39414f")
const TEXT := Color("e6e9ef")
const MUTED := Color("9aa4b2")
const ACCENT := Color("d8534f")
const ACCENT2 := Color("e0a458")
const OK := Color("6fbf73")
const DARK := Color("0b0d12")


static func build() -> Theme:
	var t := Theme.new()
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Noto Sans SC", "Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", "SimHei", "sans-serif"])
	if f.font_names.size() > 0:
		t.default_font = f
	t.default_font_size = 22
	t.set_stylebox("normal", "Button", panel_style(PANEL_LIGHT, LINE, 6))
	t.set_stylebox("hover", "Button", panel_style(PANEL, ACCENT2, 6))
	t.set_stylebox("pressed", "Button", panel_style(ACCENT, ACCENT, 6))
	t.set_stylebox("disabled", "Button", panel_style(PANEL, DARK, 6))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", MUTED)
	return t


static func panel_style(bg: Color = PANEL, border: Color = LINE, radius: int = 8) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


static func button(text: String, size: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, 52)
	b.focus_mode = Control.FOCUS_NONE
	return b


## 地点图上的地点按钮：有边框、有底色，选中/不可走时颜色不同。
static func map_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_stylebox_override("normal", panel_style(PANEL_LIGHT, LINE, 6))
	b.add_theme_stylebox_override("hover", panel_style(PANEL, ACCENT2, 6))
	b.add_theme_stylebox_override("pressed", panel_style(ACCENT, ACCENT, 6))
	b.add_theme_stylebox_override("disabled", panel_style(PANEL, DARK, 6))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.focus_mode = Control.FOCUS_NONE
	return b


static func label(text: String, size: int = 22, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func rich(size: int = 20) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = false
	r.scroll_following = true
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_color_override("default_color", TEXT)
	return r


static func paint_bg(node: Control) -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(bg)
```

- [ ] **Step 4：创建 `game/ui/expedition/expedition_screen.gd`**

```gdscript
extends Control
## 地点图 + 手表 + 事件流（M1 可玩层的远征界面）。
## 只调用 ExpeditionView，规则在 core；界面负责画和把点击交回去。

signal battle_needed
signal ended

const ExpeditionView = preload("res://ui/expedition/expedition_view.gd")
const UiTheme = preload("res://ui/ui_theme.gd")
const BattleData = preload("res://core/battle/battle_data.gd")


## 画通路的小画布：地点按钮是它的子节点。
class MapCanvas extends Control:
	var ex: RefCounted

	func _draw() -> void:
		if ex == null:
			return
		for p: Dictionary in ex.st.scenario.data["paths"]:
			var a: Array = ex.st.scenario.location(String(p["a"])).get("pos", [0, 0])
			var b: Array = ex.st.scenario.location(String(p["b"])).get("pos", [0, 0])
			var open: bool = ex.st.is_path_open(String(p["a"]), String(p["b"]))
			var color := Color("39414f") if open else Color("0b0d12")
			draw_line(Vector2(float(a[0]) + 88, float(a[1]) + 30), Vector2(float(b[0]) + 88, float(b[1]) + 30), color, 5.0, true)

var view: RefCounted
var map_canvas: MapCanvas
var location_buttons: Dictionary = {}
var watch_label: RichTextLabel
var member_label: RichTextLabel
var log_label: RichTextLabel
var pending_box: VBoxContainer
var action_box: HBoxContainer
var title_label: Label
var _ended_sent := false


func setup(expedition: RefCounted, char_names: Dictionary) -> void:
	view = ExpeditionView.new(expedition, char_names)
	_build()
	refresh()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiTheme.paint_bg(self)
	var left := PanelContainer.new()
	left.position = Vector2(30, 30)
	left.size = Vector2(930, 1020)
	left.add_theme_stylebox_override("panel", UiTheme.panel_style())
	add_child(left)
	map_canvas = MapCanvas.new()
	map_canvas.ex = view.ex
	map_canvas.custom_minimum_size = Vector2(900, 980)
	left.add_child(map_canvas)

	title_label = UiTheme.label("生化危机一 · 蜂巢", 30, UiTheme.ACCENT2)
	title_label.position = Vector2(1000, 26)
	title_label.size = Vector2(880, 44)
	add_child(title_label)

	watch_label = UiTheme.rich(22)
	watch_label.position = Vector2(1000, 80)
	watch_label.size = Vector2(880, 150)
	add_child(watch_label)

	member_label = UiTheme.rich(20)
	member_label.bbcode_enabled = true
	member_label.position = Vector2(1000, 240)
	member_label.size = Vector2(880, 200)
	add_child(member_label)

	pending_box = VBoxContainer.new()
	pending_box.position = Vector2(1000, 450)
	pending_box.size = Vector2(880, 230)
	pending_box.add_theme_constant_override("separation", 8)
	add_child(pending_box)

	action_box = HBoxContainer.new()
	action_box.position = Vector2(1000, 700)
	action_box.size = Vector2(880, 60)
	action_box.add_theme_constant_override("separation", 10)
	add_child(action_box)

	log_label = UiTheme.rich(19)
	log_label.position = Vector2(1000, 780)
	log_label.size = Vector2(880, 220)
	add_child(log_label)

	var search_btn := UiTheme.button("搜索", 20)
	search_btn.pressed.connect(_on_search)
	action_box.add_child(search_btn)
	var rest10 := UiTheme.button("休息 10 分钟", 20)
	rest10.pressed.connect(_on_rest10)
	action_box.add_child(rest10)
	var rest30 := UiTheme.button("休息 30 分钟", 20)
	rest30.pressed.connect(_on_rest30)
	action_box.add_child(rest30)
	var deduce_btn := UiTheme.button("推理", 20)
	deduce_btn.pressed.connect(_on_deduce)
	action_box.add_child(deduce_btn)

	for loc_id: String in view.ex.st.scenario.data["locations"]:
		var btn := UiTheme.map_button("")
		var pos: Array = view.ex.st.scenario.location(loc_id).get("pos", [0, 0])
		btn.position = Vector2(float(pos[0]), float(pos[1]))
		btn.size = Vector2(180, 62)
		btn.pressed.connect(_on_location.bind(loc_id))
		map_canvas.add_child(btn)
		location_buttons[loc_id] = btn


func refresh() -> void:
	title_label.text = "生化危机一 · 蜂巢 · 第 %d 分钟" % int(view.ex.st.clock)
	var w: Dictionary = view.watch()
	var left := int(w["remaining_minutes"])
	watch_label.text = "%s\n剩余 %d:%02d · 击杀 %d（%.1f 点）" % [String(w["main_task"]), left / 60, left % 60, int(w["kills"]), float(w["kill_points"])]
	if String(w["tether"]) != "":
		watch_label.text += "\n绑定：" + String(w["tether"])
	if bool(w["gag"]):
		watch_label.text += "\n禁言：剧情人物在场时泄露主神信息，每句 -10"
	if bool(w["dark"]):
		watch_label.text += "\n[全黑] 恐惧持续上升"

	var lines: Array[String] = []
	for m: Dictionary in view.members():
		var color := "#e6e9ef" if bool(m["alive"]) else "#5a6270"
		var hp := "%d/%d" % [int(m["hp"]), int(m["hp_max"])]
		var tail := "  [感染]" if bool(m["infected"]) else ""
		lines.append("[color=%s]%s  %s  恐惧 %d%s[/color]" % [color, String(m["name"]), hp, int(m["fear"]), tail])
	member_label.text = "\n".join(lines)

	var items := {}
	for m: Dictionary in view.map():
		items[m["id"]] = m
	for loc_id: String in location_buttons:
		var b: Button = location_buttons[loc_id]
		var item: Dictionary = items.get(loc_id, {})
		var text: String = String(item.get("name", loc_id))
		if bool(item.get("here", false)):
			text = "● " + text
		elif not bool(item.get("adjacent", false)):
			text = "  " + text
		if (item.get("npcs", []) as Array).size() > 0:
			text += " ·人"
		b.text = text
		var reachable := bool(item.get("here", false)) or (bool(item.get("adjacent", false)) and bool(item.get("open", true)))
		b.disabled = not reachable
		b.modulate = Color(0.78, 0.84, 1.0, 1.0) if bool(item.get("dark", false)) else Color.WHITE

	_build_pending()
	log_label.text = "\n".join(view.log_tail(12))
	if view.pending().get("kind", "") == "battle":
		battle_needed.emit.call_deferred()
	if view.ended() and not _ended_sent:
		_ended_sent = true
		ended.emit.call_deferred()


func _build_pending() -> void:
	for c in pending_box.get_children():
		pending_box.remove_child(c)
		c.queue_free()
	var p: Dictionary = view.pending()
	if p.is_empty():
		return
	var kind := String(p["kind"])
	if kind == "choice":
		pending_box.add_child(UiTheme.label(String(p["prompt"]), 22, UiTheme.ACCENT2))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		for o: Dictionary in p["options"]:
			var b := UiTheme.button(String(o["text"]), 19)
			b.pressed.connect(press_choice.bind(String(o["id"])))
			row.add_child(b)
		pending_box.add_child(row)
	elif kind == "check":
		pending_box.add_child(UiTheme.label("%s：%s（难度 %d）" % [String(p["npc"]), String(p["goal"]), int(p["difficulty"])], 21, UiTheme.ACCENT2))
		pending_box.add_child(UiTheme.label("关键词：" + "、".join(p["keywords"]), 18, UiTheme.MUTED))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		for i in 4:
			var b := UiTheme.button(["很弱", "一般", "有力", "极强"][i], 19)
			b.pressed.connect(press_persuade.bind(i))
			row.add_child(b)
		pending_box.add_child(row)
	elif kind == "battle":
		pending_box.add_child(UiTheme.label("战斗：%s" % "、".join(p["enemies"]), 22, UiTheme.ACCENT))


func press_move(loc_id: String) -> bool:
	if not view.can_move(loc_id):
		return false
	view.move(loc_id)
	refresh()
	return true


func press_choice(option_id: String) -> bool:
	if view.pending().get("kind", "") != "choice":
		return false
	view.choose(option_id)
	refresh()
	return true


func press_persuade(level: int) -> bool:
	if view.pending().get("kind", "") != "check":
		return false
	view.persuade(level)
	refresh()
	return true


func press_rest(minutes: int) -> void:
	view.rest(minutes)
	refresh()


func press_search() -> void:
	view.search()
	refresh()


func press_deduce() -> void:
	var thinker := ""
	var best := -1.0
	for sid: String in view.ex.st.squads:
		for c: String in view.ex.st.living_members(sid):
			var ch: RefCounted = view.ex.st.characters[c]
			var iq := float(ch.attributes.total("intelligence"))
			if iq > best:
				best = iq
				thinker = c
	if thinker != "":
		view.deduce("queen_controls_lasers", thinker)
	refresh()


func _on_location(loc_id: String) -> void:
	press_move(loc_id)


func _on_search() -> void:
	press_search()


func _on_rest10() -> void:
	press_rest(10)


func _on_rest30() -> void:
	press_rest(30)


func _on_deduce() -> void:
	press_deduce()
```

- [ ] **Step 5：创建 `game/ui/battle/battle_screen.gd`**

```gdscript
extends Control
## 战斗界面（M1 可玩层）：按排显示战场、行动时间轴、先选技能再选目标、战斗日志。
## 只调用 BattleView；规则和 AI 在 core/battle。

signal finished

const BattleView = preload("res://ui/battle/battle_view.gd")
const UiTheme = preload("res://ui/ui_theme.gd")

var view: RefCounted
var header: Label
var timeline_label: Label
var enemy_grid: GridContainer
var ally_grid: GridContainer
var action_box: VBoxContainer
var log_label: RichTextLabel
var cards: Dictionary = {}
var open_indices: Array = []
var _done := false


func setup(battle: RefCounted) -> void:
	view = BattleView.new(battle)
	_build()
	refresh()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiTheme.paint_bg(self)
	header = UiTheme.label("战斗", 30, UiTheme.ACCENT)
	header.position = Vector2(40, 18)
	header.size = Vector2(1200, 40)
	add_child(header)
	timeline_label = UiTheme.label("", 20, UiTheme.MUTED)
	timeline_label.position = Vector2(40, 60)
	timeline_label.size = Vector2(1240, 30)
	add_child(timeline_label)

	var enemy_title := UiTheme.label("敌方", 22, UiTheme.ACCENT)
	enemy_title.position = Vector2(40, 98)
	enemy_title.size = Vector2(200, 28)
	add_child(enemy_title)
	enemy_grid = GridContainer.new()
	enemy_grid.columns = 5
	enemy_grid.position = Vector2(40, 130)
	enemy_grid.size = Vector2(1240, 210)
	enemy_grid.add_theme_constant_override("h_separation", 10)
	enemy_grid.add_theme_constant_override("v_separation", 8)
	add_child(enemy_grid)

	var ally_title := UiTheme.label("我方", 22, UiTheme.OK)
	ally_title.position = Vector2(40, 356)
	ally_title.size = Vector2(200, 28)
	add_child(ally_title)
	ally_grid = GridContainer.new()
	ally_grid.columns = 7
	ally_grid.position = Vector2(40, 388)
	ally_grid.size = Vector2(1240, 116)
	ally_grid.add_theme_constant_override("h_separation", 10)
	add_child(ally_grid)

	var action_panel := PanelContainer.new()
	action_panel.position = Vector2(1300, 90)
	action_panel.size = Vector2(580, 620)
	action_panel.add_theme_stylebox_override("panel", UiTheme.panel_style())
	add_child(action_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	action_panel.add_child(scroll)
	action_box = VBoxContainer.new()
	action_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_box.add_theme_constant_override("separation", 8)
	scroll.add_child(action_box)

	var log_title := UiTheme.label("战斗日志", 22, UiTheme.MUTED)
	log_title.position = Vector2(40, 540)
	log_title.size = Vector2(300, 28)
	add_child(log_title)
	log_label = UiTheme.rich(19)
	log_label.position = Vector2(40, 574)
	log_label.size = Vector2(1240, 420)
	add_child(log_label)


func _card(u: Dictionary) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(160, 100)
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PANEL_LIGHT))
	var l := UiTheme.label("", 17)
	p.add_child(l)
	cards[u["id"]] = l
	return p


func refresh() -> void:
	var cur: Dictionary = view.current()
	header.text = "战斗" + ((" · 轮到 " + String(cur["name"])) if not cur.is_empty() else "")
	timeline_label.text = "时间轴：" + " → ".join(view.timeline())
	for grid: GridContainer in [enemy_grid, ally_grid]:
		for c in grid.get_children():
			grid.remove_child(c)
			c.queue_free()
	var units: Array[Dictionary] = view.units()
	for u: Dictionary in units:
		var grid: GridContainer = ally_grid if String(u["side"]) == "ally" else enemy_grid
		var p := _card(u)
		var l: Label = cards[u["id"]]
		var status := "、".join(u["statuses"])
		l.text = "%s\nHP %d/%d\n恐惧 %d%s" % [
			String(u["name"]), int(u["hp"]), int(u["hp_max"]), int(u["fear"]),
			("\n" + status) if status != "" else "",
		]
		l.add_theme_color_override("font_color", UiTheme.TEXT if bool(u["alive"]) else UiTheme.MUTED)
		if bool(u["current"]):
			p.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.ACCENT, UiTheme.ACCENT, 8))
		grid.add_child(p)
		cards[u["id"]] = l

	for c in action_box.get_children():
		action_box.remove_child(c)
		c.queue_free()
	if view.finished():
		action_box.add_child(UiTheme.label("战斗结束：" + view.outcome(), 24, UiTheme.ACCENT2))
		if not _done:
			_done = true
			finished.emit.call_deferred()
		return
	var actions: Array[Dictionary] = view.actions()
	if not open_indices.is_empty():
		var back := UiTheme.button("← 返回", 18)
		back.pressed.connect(func() -> void:
			open_indices = []
			refresh())
		action_box.add_child(back)
		for i in open_indices:
			var b := UiTheme.button(String(actions[int(i)]["label"]), 18)
			b.pressed.connect(press_action.bind(int(i)))
			action_box.add_child(b)
	else:
		for g: Dictionary in view.groups():
			var b := UiTheme.button(String(g["label"]), 19)
			var indices: Array = g["indices"]
			if indices.size() == 1:
				b.pressed.connect(press_action.bind(int(indices[0])))
			else:
				b.pressed.connect(_open.bind(indices))
			action_box.add_child(b)
	log_label.text = "\n".join(view.log_tail(8))


func _open(indices: Array) -> void:
	open_indices = indices.duplicate()
	refresh()


func press_action(index: int) -> void:
	view.act(index)
	open_indices = []
	refresh()
```

- [ ] **Step 6：创建 `game/ui/main.gd`**

```gdscript
extends Control
## M1 可玩切片的入口：新游戏 → 远征 → 战斗 → 结算 → 主神空间休整。
## 只做流程和换屏；远征与战斗的状态都在 Session / Expedition / Battle 里。

const Session = preload("res://core/session/session.gd")
const ExpeditionScreen = preload("res://ui/expedition/expedition_screen.gd")
const BattleScreen = preload("res://ui/battle/battle_screen.gd")
const UiTheme = preload("res://ui/ui_theme.gd")
const Battle = preload("res://core/battle/battle.gd")

const SAVE_PATH := "user://m1_save.json"

var session: RefCounted
var content: Control
var header: Label
var save_button: Button
var load_button: Button
var battle_screen: Control = null


func _ready() -> void:
	theme = UiTheme.build()
	_build_frame()
	session = Session.new()
	session.start_m1(1)
	_show_expedition()


func _build_frame() -> void:
	UiTheme.paint_bg(self)
	var bar := ColorRect.new()
	bar.color = UiTheme.PANEL
	bar.position = Vector2(0, 0)
	bar.size = Vector2(1920, 56)
	add_child(bar)
	header = UiTheme.label("无限恐怖 · M1 可玩切片", 24, UiTheme.ACCENT2)
	header.position = Vector2(30, 12)
	header.size = Vector2(900, 34)
	add_child(header)

	save_button = UiTheme.button("保存", 18)
	save_button.position = Vector2(1560, 6)
	save_button.size = Vector2(150, 44)
	save_button.pressed.connect(_on_save)
	add_child(save_button)
	load_button = UiTheme.button("读档", 18)
	load_button.position = Vector2(1720, 6)
	load_button.size = Vector2(150, 44)
	load_button.pressed.connect(_on_load)
	add_child(load_button)

	content = Control.new()
	content.position = Vector2(0, 56)
	content.size = Vector2(1920, 1024)
	add_child(content)


func _clear() -> void:
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	battle_screen = null


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
	_clear()
	var box := VBoxContainer.new()
	box.position = Vector2(300, 110)
	box.size = Vector2(1320, 800)
	box.add_theme_constant_override("separation", 16)
	content.add_child(box)
	box.add_child(UiTheme.label("主神空间 · 第 %d 天 / 9" % session.day, 36, UiTheme.ACCENT2))
	box.add_child(UiTheme.label("回归当晚只结算和造人；兑换、修复、训练从第 2 天开始。M1 的休息期界面在后续计划里展开。", 20, UiTheme.MUTED))
	var zheng: RefCounted = session.game.characters.get("zheng_zha")
	if zheng != null:
		box.add_child(UiTheme.label("郑吒：%d 点 · 支线 B×%d" % [zheng.points, int(zheng.tickets.counts["B"])], 24, UiTheme.TEXT))
	if session.day < 9:
		var next := UiTheme.button("推进一天", 22)
		next.custom_minimum_size = Vector2(240, 56)
		next.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		next.pressed.connect(func() -> void:
			session.advance_day()
			_show_hub())
		box.add_child(next)
	else:
		var go := UiTheme.button("走光柱（下一部：异形）", 22)
		go.custom_minimum_size = Vector2(360, 56)
		go.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		go.pressed.connect(func() -> void:
			session.depart()
			_show_done())
		box.add_child(go)
	_set_status("主神空间 · 第 %d 天" % session.day)


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


func _on_save() -> void:
	var err: int = session.save_to(SAVE_PATH)
	_set_status("已保存" if err == OK else "保存失败（%d）" % err)


func _on_load() -> void:
	var s := Session.load_from(SAVE_PATH)
	if s == null:
		_set_status("没有可读的存档")
		return
	session = s
	battle_screen = null
	if session.phase == "expedition":
		_show_expedition()
	elif session.phase == "done":
		_show_done()
	else:
		_show_hub()
```

- [ ] **Step 7：创建 `game/ui/main.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/main.gd" id="1_main"]

[node name="Main" type="Control"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
script = ExtResource("1_main")
```

- [ ] **Step 8：改写 `game/project.godot`**

```
; Engine configuration file.
; 由计划 1 创建。界面相关设置在后续计划中补充。
config_version=5

[application]
config/name="无限恐怖"
run/main_scene="res://ui/main.tscn"
config/features=PackedStringArray("4.7")

[display]
window/size/viewport_width=1920
window/size/viewport_height=1080
window/stretch/mode="canvas_items"
window/stretch/aspect="keep"

[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

- [ ] **Step 9：运行切片验收**

Run: `godot --headless --path game -s res://tools/verify_m1_slice.gd; echo "exit=$?"`

预期：`M1 切片验证：失败 0 项`，`exit=0`。

- [ ] **Step 10：提交**

```bash
git add game/ui/ui_theme.gd game/ui/expedition/expedition_screen.gd game/ui/battle/battle_screen.gd game/ui/main.gd game/ui/main.tscn game/tools/verify_m1_slice.gd game/project.godot
git commit -m "feat(ui): M1 可玩切片（地点图、战斗、结算与休整）" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

### Task 4：全量、uid 与进度

- [ ] **Step 1：跑全部测试**

Run: `bash game/tools/run_tests.sh > /tmp/p7brun.txt 2>&1; echo "exit=$?"; tail -1 /tmp/p7brun.txt; echo "SCRIPT ERROR: $(grep -c 'SCRIPT ERROR' /tmp/p7brun.txt)"`

预期：`exit=0`、`共 324 个测试，失败 0 个`、`SCRIPT ERROR: 0`。

- [ ] **Step 2：导入工程，生成 uid**

Run: `godot --headless --path game --import > /tmp/p7bimp.txt 2>&1; echo "import exit=$?"; git status --short | sort`

预期：`import exit=0`，11 个新 uid：
`game/core/session/session.gd.uid`、`game/tests/unit/session/test_session.gd.uid`、`game/tests/unit/ui/test_views.gd.uid`、`game/tools/verify_m1_slice.gd.uid`、`game/ui/battle/battle_screen.gd.uid`、`game/ui/battle/battle_view.gd.uid`、`game/ui/event_text.gd.uid`、`game/ui/expedition/expedition_screen.gd.uid`、`game/ui/expedition/expedition_view.gd.uid`、`game/ui/main.gd.uid`、`game/ui/ui_theme.gd.uid`，外加 `?? _work/`。

- [ ] **Step 3：提交 uid**

```bash
git add game/core/session/session.gd.uid game/tests/unit/session/test_session.gd.uid game/tests/unit/ui/test_views.gd.uid game/tools/verify_m1_slice.gd.uid game/ui/battle/battle_screen.gd.uid game/ui/battle/battle_view.gd.uid game/ui/event_text.gd.uid game/ui/expedition/expedition_screen.gd.uid game/ui/expedition/expedition_view.gd.uid game/ui/main.gd.uid game/ui/ui_theme.gd.uid
git commit -m "chore: 纳入计划 7b 新脚本的 uid 文件" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log --oneline -1
```

- [ ] **Step 4：更新 README**

```bash
python -I -X utf8 - <<'EOF'
p = "README.md"
s = open(p, encoding="utf-8").read()
o = "- 计划 7a（M1 内容：生化危机一剧本、七名轮回者、AI 人设、章节装配）已完成，累计 315 个无界面测试。\n"
n = o + "- 计划 7b（M1 可玩切片：会话与存档、地点图与手表、战斗界面、结算与休整入口）已完成，累计 324 个无界面测试；`godot --path game` 可以直接玩，无头验收用 `godot --headless --path game -s res://tools/verify_m1_slice.gd`。\n"
assert s.count(o) == 1
open(p, "w", encoding="utf-8", newline="\n").write(s.replace(o, n))
EOF
git add README.md
git commit -m "docs: 计划 7b 完成，更新进度" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log --oneline -1; git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

- [ ] **Step 5：验收**

Run: `git log --oneline -6; git status --short; grep -c $'\r' game/ui/main.gd game/ui/expedition/expedition_screen.gd game/core/session/session.gd; godot --headless --path game -s res://tools/verify_m1_slice.gd; echo "exit=$?"`

预期：四个提交都在；`git status --short` 只有 `?? _work/`；三个 `grep -c` 都是 `0`；验收 `M1 切片验证：失败 0 项`、`exit=0`。
