# 计划 23：人和空间 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 用户说"太简陋"：场景小、操作空间小，人多了挤不开，没法和每个人说话去了解他们。本计划按 2026-11-12 的内容重做设计第 11 节的计划 23 做"人和空间"：四节车厢的列车和站台连入口大厅按人群尺度重画；镜头两档可切换；队友散开、归队，剧情人物让路；头顶名字和"…"；按 T 打开"在场的人"名单；在场 13 个人（除了你自己）照原著写的固定话题；人物卡。做完可以在车上走一圈、和每个人聊，了解他们是谁。

**Architecture:**
- `core/dialogue/topics.gd` + `data/scenarios/biohazard1/topics.json`：固定话题。每个话题有问题、回答（可以按地点、恐惧变）、出现条件（地点 / 剧情条件、对话信任、先聊过哪个），能给线索、百科、旗标，聊出来的要点记上人物卡。地点标 `unheard` 时剧情人物听不见轮回者（原著：车减速之前），只能"看看"他们。聊过的话题存进 `ExpeditionState.topics_seen`，跟着存档走。`Expedition.talk_topic` 是唯一的入口：第一次聊才跑效果。
- 剧本：七个剧情人物（马修、艾丽丝、瑞恩、马特、卡普兰、J·D、雷恩）开局就在列车上；"下车，雇佣兵带队"改成你们到站台时触发（以前是第 10 分钟不管你在哪都触发，在车上搜东西他们就先没了）。计划 24 再让雇佣兵按原著的行程自己走。`personas.json` 按原著改正：马修是黑人雇佣兵队长、瑞恩是失忆的商业间谍（男主角）、马特在找他姐姐、李萧毅是被欺负的高三学生……
- 地图：`car.tmj`（105×23，四节车厢，车厢之间三格门洞，第二节车厢的车门通站台，第三节车厢角落有行李能搜）、`hall.tmj`（71×22，站台连着入口大厅，中间一道口子；北墙楼梯口、南墙检修格栅、接待台、储物柜），都用实验室图块。`tiled_map.gd` 的灯数改按"一屏范围里不超过 5 盏"算（大地图灯可以多，分散开就行），地图属性 `crowd` 校验空地够不够这么多人站（每人至少 6 格）。
- `ui/field/field_screen.gd`：远（640×341，一屏 40×21 格，放大 3 倍，默认）/ 近（480×256，30×16 格，放大 4 倍）两档视野，V 键切换、存进设置；比一屏小的地图居中。站着不动 1.2 秒队友散开到附近空位，一走就归队；顶着剧情人物一会儿他和你换位让路；换屏回来这些都记得。走近的人头顶显示名字，有新话题的带"…"，名字不叠在一起。T 打开"在场的人"（每人一行：身份、听不听得见、有没有新话题、"说话 / 看看""人物卡"两个按钮，人多了能滚动）；人物卡写身份、状态、信任 / 服从、聊出来的要点、还有几个话题没聊。
- `ui/dialogue/dialogue_panel.gd` + `ui/main.gd`：对话框下面列"可以问的"话题按钮（没聊过的带"•"，聊过的打"✓"还能再问）；对方听不见时关掉输入框，只能"看看"。第一次聊一个话题算一次交谈（对话信任 +1）。
- `core/settings/settings.gd`：新设置 `field_wide`（视野档位）。`tools/field_capture.gd` 多截近视野、名单、人物卡三张。

**Tech Stack:** Godot 4.7.2、Tiled 1.11 JSON、Python 3。

**依据：** 设计 `docs/superpowers/specs/2026-11-12-film1-content-redesign.md` 第 6 节（空间与人群）、第 7 节（和每个人说话）、第 9 节（改正和原著不符的地方）、第 11 节（计划 23 的范围）；用户确认（2026-11-13："Yes, start plan 23"）。话题照原著《无限恐怖》生化危机一的开场写（新人自我介绍、张杰讲规则、雇佣兵和三个主角的出场）。用到的游戏开发技能：level-design（先量尺寸、人群容量）、camera-systems（两档视野、小地图居中、镜头边界）、game-ai（散开 / 归队、让路）、dialogue-systems / rpg（话题条件、信任门槛、人物卡）、game-ui-ux（名单、名字防重叠、键鼠操作、信息不藏在悬停里）、godot-gdscript-headless-testing。

**不在本计划范围：** 雇佣兵按原著行程自己走、按米算的绑定、调查点、锁、隐藏剧情①（瑞恩的赃物）和⑨、线索日志（计划 24）；地图上标"集合点 / 散开点 / 站岗点"、队友之间的闲聊气泡、主动叫住你（以后）；人物卡上的秘密和天赋（"？"）；剧情人物的正式行走图和瑞恩的新立绘（任务卡 005 补充、007）。第一批话题 43 个，覆盖在场的 13 个人；蜂房里的人物和话题随计划 24、25 补。

**本计划已在临时目录跑通：497 个无界面测试全过、`SCRIPT ERROR 0`、M1 切片验收 0 失败；窗口截图确认列车、站台大厅、近视野、名单、人物卡、对话框里的话题按钮显示正常，名字不重叠、名单不超出屏幕。**

**执行环境注意：**
- 仓库根目录：`I:\workspace\mobilegame\wuxian-kongbu\`；命令都在仓库根目录执行（Git Bash）。
- 文本文件 **LF**、UTF-8 无 BOM；GDScript 用 **Tab**。
- **只提交，不推送。**
- 临时验证目录是 `_work/plan_check_p23`。
- 图片不进仓库。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `docs/superpowers/specs/2026-11-12-film1-content-redesign.md` | 内容重做设计（用户已确认） |
| `game/core/dialogue/topics.gd` | 固定话题：能不能聊、回答、要点、校验 |
| `game/data/scenarios/biohazard1/topics.json` | 第一部片的话题（43 个，13 个人） |
| `game/core/expedition/expedition_state.gd` | 存聊过的话题 |
| `game/core/expedition/expedition.gd` | `talk_topic`：聊一个话题，第一次跑效果 |
| `game/data/scenarios/biohazard1/scenario.json` | 剧情人物开局在车上；车上听不见；到站台才下车 |
| `game/data/ai/personas.json` | 按原著改正人设 |
| `game/core/settings/settings.gd` | 视野档位设置 |
| `game/ui/field/tiled_map.gd` | 灯按一屏算、人群容量校验 |
| `game/data/maps/biohazard1/car.tmj`、`hall.tmj` | 四节车厢的列车；站台连入口大厅 |
| `game/ui/field/field_screen.gd` | 两档视野、散开 / 让路、名字、名单、人物卡 |
| `game/ui/dialogue/dialogue_panel.gd` | 话题按钮、关掉自由输入 |
| `game/ui/main.gd` | 接上话题、听不见的人、对话信任、视野设置 |
| `game/tools/field_capture.gd` | 多截三张（近视野、名单、人物卡） |
| `game/tests/unit/dialogue/test_topics.gd` | 话题规则（新） |
| `game/tests/unit/ui/test_field.gd`、`test_tiled_map.gd` | 新地图、视野、散开、让路、名单、人物卡、名字 |
| `game/tests/unit/dialogue/test_dialogue_panel.gd`、`settings/test_settings.gd`、`ai/test_persona.gd` | 话题按钮、视野设置、马修改正后的秘密 |

---

## Task 1：提交内容重做设计

- [ ] **Step 1：提交设计文档**

```bash
git add docs/superpowers/specs/2026-11-12-film1-content-redesign.md
git commit -m "docs: 第一部片内容重做设计（大场景、隐藏剧情、和每个人说话），用户已确认" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 里不再有这份设计文档。

---

## Task 2：人和空间

**Files:**
- Create: `game/core/dialogue/topics.gd`、`game/data/scenarios/biohazard1/topics.json`、`game/tests/unit/dialogue/test_topics.gd`
- Modify: `game/core/expedition/expedition_state.gd`、`game/core/expedition/expedition.gd`、`game/data/scenarios/biohazard1/scenario.json`、`game/data/ai/personas.json`、`game/core/settings/settings.gd`、`game/ui/field/tiled_map.gd`、`game/data/maps/biohazard1/car.tmj`、`game/data/maps/biohazard1/hall.tmj`、`game/ui/field/field_screen.gd`、`game/ui/dialogue/dialogue_panel.gd`、`game/ui/main.gd`、`game/tools/field_capture.gd`、`game/tests/unit/ui/test_field.gd`、`game/tests/unit/ui/test_tiled_map.gd`、`game/tests/unit/dialogue/test_dialogue_panel.gd`、`game/tests/unit/settings/test_settings.gd`、`game/tests/unit/ai/test_persona.gd`

规则、数据、地图和画面这次要一起改：新的探索测试同时用到新地图、话题和剧情人物在车上，分开提交中间会有一段测试不全过，所以合成一次提交。

- [ ] **Step 1：写测试 `game/tests/unit/dialogue/test_topics.gd`**

```gdscript
extends "res://tests/test_case.gd"
## 固定话题：话题文件完整；什么时候能聊（地点、信任、先聊过哪个）；列车上剧情人物听不见、只能看看；
## 聊第一次才跑效果；回答按情况变；人物卡要点；聊过的话题跟着存档走。

const Topics = preload("res://core/dialogue/topics.gd")
const Campaign = preload("res://core/campaign/campaign.gd")
const GameState = preload("res://core/model/game_state.gd")
const ExpeditionState = preload("res://core/expedition/expedition_state.gd")

const SQUAD: Array[String] = ["zheng_zha", "zhang_jie", "zhan_lan", "li_xiao_yi", "mu_gang", "xiao_pang_zi", "zhong_nian_fu_nv"]


const CHAPTER := "res://data/scenarios/biohazard1/chapter.json"


func _start() -> RefCounted:
	return Campaign.start(GameState.new(1), CHAPTER)


func _ids(list: Array) -> Array[String]:
	var out: Array[String] = []
	for t: Dictionary in list:
		out.append(String(t["id"]))
	return out


## 话题文件：id 不重复、都有问题和回答、after 指向存在的话题、人物都存在；在场的 13 个人（除了你自己）每人都有话题。
func test_topics_file_valid() -> void:
	var s := _start()
	var sc: RefCounted = s.st.scenario
	var people: Array = sc.data["npcs"].keys()
	people.append_array(SQUAD)
	var errors: Array[String] = Topics.validate(sc, people)
	assert_eq(errors.size(), 0, "\n".join(errors))
	for id in ["zhang_jie", "zhan_lan", "li_xiao_yi", "mu_gang", "xiao_pang_zi", "zhong_nian_fu_nv", "matthew", "alice", "ryan", "matt", "kaplan", "jd", "rain"]:
		assert_true(Topics.defs(s.st, id).size() >= 2, "%s 至少两个话题" % id)


## 列车上：剧情人物和你们在同一节车里，但听不见你们说话（原著：车减速之前）——只能"看看"。下了车就能聊了。
func test_unheard_on_the_train() -> void:
	var s := _start()
	var st: RefCounted = s.st
	assert_eq(String(st.npcs["matthew"]["location"]), "car", "雇佣兵和你们在同一趟车上")
	assert_false(Topics.can_hear(st, "matthew"))
	assert_true(Topics.can_hear(st, "zhang_jie"), "轮回者总听得见")
	assert_eq(_ids(Topics.available(st, "matthew", 0)), ["matthew_look"] as Array[String])
	s.choose("listen")
	s.move("s1", "hall")
	assert_eq(String(st.npcs["matthew"]["location"]), "hall")
	assert_true(Topics.can_hear(st, "matthew"))
	assert_eq(_ids(Topics.available(st, "matthew", 0)), ["matthew_where"] as Array[String], "看看的话题收起来了；先问去哪")


## 信任门槛和先后：张杰的枪要信任 2，经历要信任 3；马修先回答去哪，才会说他不信任你们。
func test_trust_and_after() -> void:
	var s := _start()
	var st: RefCounted = s.st
	assert_eq(_ids(Topics.available(st, "zhang_jie", 0)), ["zhang_jie_who", "zhang_jie_rules", "zhang_jie_plan"] as Array[String])
	assert_true(_ids(Topics.available(st, "zhang_jie", 2)).has("zhang_jie_gun"))
	assert_false(_ids(Topics.available(st, "zhang_jie", 2)).has("zhang_jie_past"))
	assert_true(_ids(Topics.available(st, "zhang_jie", 3)).has("zhang_jie_past"))
	assert_false(_ids(Topics.available(st, "li_xiao_yi", 0)).has("li_xiao_yi_warn"), "提醒他嘴上留神只在站台上、聊过以后")
	s.choose("listen")
	s.move("s1", "hall")
	assert_false(_ids(Topics.available(st, "matthew", 0)).has("matthew_doubt"))
	s.talk_topic("matthew", "matthew_where", 0)
	assert_true(_ids(Topics.available(st, "matthew", 0)).has("matthew_doubt"))


## 聊一个话题：第一次标成聊过、跑效果（线索、百科）；再问一遍照样回答，但不再跑效果；聊不了的返回空。
func test_talk_topic_effects_once() -> void:
	var s := _start()
	var ex: RefCounted = s
	assert_eq(ex.talk_topic("zhang_jie", "zhang_jie_gun", 0), {}, "信任不够聊不了")
	var r: Dictionary = ex.talk_topic("zhang_jie", "zhang_jie_gun", 2)
	assert_true(bool(r["new"]))
	assert_true(String(r["text"]).contains("沙漠之鹰"))
	assert_true(ex.st.topics_seen.has("zhang_jie_gun"))
	assert_true(ex.st.intel.clues_found.has("desert_eagle"), "给了线索")
	var again: Dictionary = ex.talk_topic("zhang_jie", "zhang_jie_gun", 2)
	assert_false(bool(again["new"]))
	assert_eq((again["events"] as Array).size(), 0)
	var rules: Dictionary = ex.talk_topic("zhang_jie", "zhang_jie_rules", 0)
	var types: Array = []
	for e: Dictionary in rules["events"]:
		types.append(String(e["type"]))
	assert_true(types.has("topic_talked"))


## 回答跟着情况变：张杰在车上和在站台上说的不一样；小胖子怕起来说的话不一样。
func test_variants() -> void:
	var s := _start()
	var st: RefCounted = s.st
	var plan: Dictionary = Topics.find(st, "zhang_jie", "zhang_jie_plan")
	assert_true(Topics.text_of(st, "zhang_jie", plan).contains("等车停了"))
	s.choose("listen")
	s.move("s1", "hall")
	assert_true(Topics.text_of(st, "zhang_jie", plan).contains("主电脑"))
	var status: Dictionary = Topics.find(st, "xiao_pang_zi", "xiao_pang_zi_status")
	st.characters["xiao_pang_zi"].fear = 10.0
	assert_true(Topics.text_of(st, "xiao_pang_zi", status).contains("跑不快"))
	st.characters["xiao_pang_zi"].fear = 60.0
	assert_true(Topics.text_of(st, "xiao_pang_zi", status).contains("腿软"))


## 人物卡要点：聊过的话题的 card；没聊过的话题数。瑞恩想起车上藏了东西，给"瑞恩在列车上藏了东西"的线索。
func test_notes_and_ryan_clue() -> void:
	var s := _start()
	var ex: RefCounted = s
	assert_eq(Topics.notes(ex.st, "ryan").size(), 0)
	var total: int = Topics.unseen_count(ex.st, "ryan")
	ex.talk_topic("ryan", "ryan_look", 0)
	assert_eq(Topics.notes(ex.st, "ryan").size(), 1)
	assert_true(Topics.notes(ex.st, "ryan")[0].contains("商业间谍"), "郑吒认得他")
	assert_eq(Topics.unseen_count(ex.st, "ryan"), total - 1)
	ex.choose("listen")
	ex.move("s1", "hall")
	ex.talk_topic("ryan", "ryan_who", 0)
	ex.talk_topic("ryan", "ryan_train", 0)
	assert_true(ex.st.intel.clues_found.has("ryan_memory"))
	assert_true(Topics.has_new(ex.st, "matt", 0))


## 聊过的话题跟着存档走；旧存档没有这一项也读得进来。
func test_topics_seen_saved() -> void:
	var s := _start()
	s.talk_topic("zhan_lan", "zhan_lan_who", 0)
	var d: Dictionary = s.st.to_dict()
	var st2 := ExpeditionState.new()
	st2.load_dict(d, s.st.scenario, s.st.characters)
	assert_true(st2.topics_seen.has("zhan_lan_who"))
	d.erase("topics_seen")
	var st3 := ExpeditionState.new()
	st3.load_dict(d, s.st.scenario, s.st.characters)
	assert_eq(st3.topics_seen.size(), 0)
```

- [ ] **Step 2：写测试 `game/tests/unit/ui/test_field.gd`**

```gdscript
extends "res://tests/test_case.gd"
## RPG 式探索：地图（Tiled）、门与入口、寻路；场景里台词进对话框、选择弹窗口、走动、进门、搜索、说话、黑暗；
## 灯光、行走图、队友站位、互动提示、打字效果；图块层；镜头跟随和边界、镜头滚动后点哪格走哪格（在场景树里测）；
## 计划 23：远 / 近两档视野、小地图居中；队友散开 / 归队、剧情人物让路（换屏回来都记得）；
## 列车上剧情人物听不见、只能看看；"在场的人"名单、人物卡、新话题标记、头顶名字。

const TiledMap = preload("res://ui/field/tiled_map.gd")
const FieldScreen = preload("res://ui/field/field_screen.gd")
const FieldArt = preload("res://ui/field/field_art.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const Session = preload("res://core/session/session.gd")
const Topics = preload("res://core/dialogue/topics.gd")

const MAPS := "res://data/maps/biohazard1"
const BIG := "res://tests/fixtures/maps/big"
const SCENARIO := "res://data/scenarios/biohazard1/scenario.json"


func _screen(seed_value: int = 1) -> Control:
	var s := Session.new()
	s.start_m1(seed_value)
	var names := {}
	for id: String in s.game.characters:
		names[id] = s.game.characters[id].display_name
	var f := FieldScreen.new()
	f.setup(s.expedition, names)
	return f


## 开场规则听完、选了"认真听"，台词都看完，能走了。
func _ready_screen() -> Control:
	var f := _screen()
	f.press_choice("listen")
	f.flush_messages()
	f._show_next()
	return f


## 站到 target 旁边一格（走得到、没人、不是门），面朝它。
func _face(f: Control, target: Vector2i) -> void:
	var blocked: Dictionary = f._blocked()
	for d: String in ["down", "up", "left", "right"]:
		var n: Vector2i = target - TiledMap.DIRS[d]
		if f.fmap.walkable(n) and not blocked.has(n) and not f.fmap.is_door(n):
			f.cell = n
			f.facing = d
			return
	assert_true(false, "%s 旁边没有能站的格子" % target)


## 八个地点都有图；门只通向剧本里相邻的地点，相邻的地点都有门；入口、柜子、站位都走得到；一屏里的灯不超过 5 盏；人站得下。
func test_maps_valid() -> void:
	var errors: Array[String] = TiledMap.validate(MAPS, Scenario.load_file(SCENARIO))
	assert_eq(errors.size(), 0, "\n".join(errors))


## 站台与入口大厅：门通向哪、从哪进来站哪；寻路绕开墙和挡路的人；站台和大厅之间只有一道口子。
func test_doors_entries_and_path() -> void:
	var hall: RefCounted = TiledMap.make(MAPS, "hall")
	assert_eq(hall.size, Vector2i(71, 22))
	assert_eq(hall.door_dest(Vector2i(9, 18)), "car", "站台边上的车门")
	assert_eq(hall.door_dest(Vector2i(52, 4)), "stairs", "大厅北墙的楼梯口")
	assert_eq(hall.door_dest(Vector2i(58, 20)), "sewer", "南墙的检修格栅")
	assert_eq(hall.door_dest(Vector2i(20, 10)), "")
	assert_eq(hall.entry_cell("car"), Vector2i(9, 17))
	assert_eq(hall.entry_facing("car"), "up")
	assert_eq(hall.entry_cell("stairs"), Vector2i(52, 5))
	var p: Array[Vector2i] = hall.path(Vector2i(9, 17), Vector2i(52, 5))
	assert_true(p.size() > 0)
	assert_eq(p[p.size() - 1], Vector2i(52, 5))
	var through := false
	for c in p:
		assert_true(hall.walkable(c))
		if c.x == 35:
			through = true
			assert_true(c.y == 10 or c.y == 11, "从站台进大厅要走中间那道口子")
	assert_true(through)
	assert_eq(hall.path(Vector2i(9, 17), Vector2i(0, 0)).size(), 0, "墙走不到")
	assert_false(hall.walkable(Vector2i(51, 10)), "接待台挡路")
	assert_true(hall.walkable(Vector2i(35, 10)))
	assert_false(hall.walkable(Vector2i(35, 8)))
	var blocked := {Vector2i(10, 17): true}
	for c in hall.path(Vector2i(9, 17), Vector2i(11, 17), blocked):
		assert_false(blocked.has(c), "绕开挡路的人")


## 列车：四节车厢连成一长条，车厢之间的门洞在中间三格；能站 14 个人。
func test_train_map() -> void:
	var car: RefCounted = TiledMap.make(MAPS, "car")
	assert_eq(car.size, Vector2i(105, 23))
	assert_eq(int(car.props.get("crowd", 0)), 14)
	for x: int in [26, 52, 78]:
		assert_false(car.walkable(Vector2i(x, 9)), "车厢隔断")
		for y: int in [11, 12, 13]:
			assert_true(car.walkable(Vector2i(x, y)), "隔断中间的门洞")
	var p: Array[Vector2i] = car.path(car.start_cell(), Vector2i(100, 15))
	assert_true(p.size() > 90, "从最后一节走到最前一节")
	assert_eq(car.door_dest(Vector2i(38, 7)), "hall", "车门在第二节车厢")
	assert_eq(car.entry_cell("hall"), Vector2i(38, 8))
	assert_true(car.is_search(Vector2i(75, 17)), "第三节车厢角落的行李")
	assert_eq(car.max_lights_in_window(), 1, "四盏灯分散在四节车厢，一屏只照到一盏")


## 开局：主角站在最后一节车厢；张杰讲规则一句句进对话框；看完弹出选择窗口；选了就收起。
func test_opening_messages_then_choice() -> void:
	var f := _screen()
	assert_eq(f.loc, "car")
	assert_eq(f.cell, Vector2i(4, 11))
	assert_eq(f.facing, "right")
	assert_eq(f.player_id, "zheng_zha")
	assert_eq(f.followers.size(), 6)
	assert_true(f.box.visible)
	assert_eq(f.box_name.text, "张杰")
	assert_true(f.box_text.text.contains("菜鸟们"))
	assert_true(f.busy(), "对话没看完不能走")
	var guard := 0
	while f.box.visible and guard < 20:
		f._show_next()
		guard += 1
	assert_true(f.choice_panel.visible)
	assert_true(f.press_choice("listen"))
	assert_false(f.choice_panel.visible)
	f.flush_messages()
	f._show_next()
	assert_false(f.busy())
	f.free()


## 走动：座位挡路、车顶是墙；七个剧情人物和你们在同一趟车上；进门去站台（花 10 分钟），站在门里一格。
func test_walk_and_door() -> void:
	var f := _ready_screen()
	assert_eq(f.npc_sprites.size(), 7, "雇佣兵、艾丽丝、瑞恩、马特都在车上")
	f.step("up")
	assert_eq(f.cell, Vector2i(4, 10))
	f.step("up")
	assert_eq(f.cell, Vector2i(4, 9))
	f.step("up")
	assert_eq(f.cell, Vector2i(4, 9), "座位挡路")
	assert_eq(f.facing, "up")
	f.step("right")
	assert_eq(f.cell, Vector2i(5, 9))
	f.step("up")
	f.step("up")
	assert_eq(f.cell, Vector2i(5, 7), "座位之间的过道走得进去")
	f.step("up")
	assert_eq(f.cell, Vector2i(5, 7), "车厢壁挡路")
	assert_true(f.press_move("hall"))
	assert_eq(f.loc, "hall")
	assert_eq(f.cell, Vector2i(9, 17))
	assert_eq(f.facing, "up")
	assert_eq(int(f.view.ex.st.clock), 10)
	assert_eq(f.npc_sprites.size(), 7, "雇佣兵跟着下了车")
	assert_eq(f._blocked().size(), 7)
	f.free()


## 对着行李按确认就搜索。车上的剧情人物听不见：提示"看看"，按确认照样打开对话框（只能看看）；下了车就是"说话"。
func test_interact_search_and_talk() -> void:
	var f := _ready_screen()
	f.cell = Vector2i(74, 17)
	f.facing = "right"
	assert_eq(f.prompt_text(), "Enter 调查")
	f.interact()
	assert_true(f.view.ex.st.searched.has("car"), "车厢搜过了")
	assert_eq(f.npc_sprites.size(), 7, "搜车厢花了时间，他们也还在车上，等你们一起下车")
	f.flush_messages()
	f._show_next()
	var talked: Array = []
	f.talk_requested.connect(func(id: String) -> void: talked.append(id))
	_face(f, f.npc_cells["matthew"])
	assert_true(f.prompt_text().begins_with("Enter 看看："), f.prompt_text())
	f.interact()
	assert_eq(talked, ["matthew"])
	f.press_move("hall")
	f.flush_messages()
	f._show_next()
	_face(f, f.npc_cells["matthew"])
	assert_true(f.prompt_text().begins_with("Enter 说话："), f.prompt_text())
	f.interact()
	assert_eq(talked, ["matthew", "matthew"])
	f.free()


## 点地面：算出一条路，排进走路队列；点门：走到门边再进去。
func test_click_to_walk() -> void:
	var f := _ready_screen()
	f.click_cell(Vector2i(20, 12))
	assert_true(f.path_queue.size() > 0)
	assert_eq(f.path_queue[f.path_queue.size() - 1], Vector2i(20, 12))
	f.click_cell(Vector2i(38, 7))
	assert_eq(String(f.path_then.get("door", "")), "hall", "点门：走到门边再进去")
	assert_eq(f.path_queue[f.path_queue.size() - 1], Vector2i(38, 8))
	f.free()


## 楼梯井是黑的：手电筒遮罩打开；换屏回来还站在原地。
func test_dark_and_memory() -> void:
	var f := _screen()
	f.press_choice("listen")
	f.press_move("hall")
	f.press_move("stairs")
	assert_eq(f.loc, "stairs")
	f.flush_messages()
	f._show_next()
	assert_true(f.dark.visible)
	var ex: RefCounted = f.view.ex
	var where: Vector2i = f.cell
	f.free()
	var g := FieldScreen.new()
	g.setup(ex, {})
	assert_eq(g.loc, "stairs")
	assert_eq(g.cell, where)
	g.free()


## 灯光：每个地点按地图打灯、压环境光；激光通道墙上的发射器是自发光光晕；黑暗地点换成手电筒。
func test_lights_and_ambient() -> void:
	var f := _screen()
	f.press_choice("listen")
	assert_eq(f.light_root.get_child_count(), 4, "列车四节车厢各一盏顶灯")
	assert_eq(f.canvas_mod.color, f.fmap.ambient())
	assert_false(f.dark.visible, "车厢不黑")
	f.press_move("hall")
	assert_eq(f.light_root.get_child_count(), 7, "站台三盏、大厅三盏顶灯加接待台的台灯")
	f.press_move("stairs")
	assert_true(f.dark.visible)
	assert_eq(f.canvas_mod.color, FieldScreen.DARK_AMBIENT, "黑暗地点只剩手电筒")
	f.free()
	var laser: RefCounted = TiledMap.make(MAPS, "laser")
	assert_eq((laser.glows() as Array).size(), 12, "两排激光发射器")
	var control: RefCounted = TiledMap.make(MAPS, "control")
	assert_true(control.max_lights_in_window() <= TiledMap.MAX_LIGHTS)


## 有 Codex 的行走图就用：按 4×4 切帧（规格单帧 16×32），脚底中点对齐格子；没有的人还用占位小人。
func test_walker_sheet() -> void:
	var dir := "user://test_field_art/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir + "walkers"))
	var sheet := Image.create(64, 128, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0, 0, 0, 0))
	sheet.fill_rect(Rect2i(4, 4, 8, 28), Color("3a4a78"))
	sheet.save_png(ProjectSettings.globalize_path(dir + "walkers/zheng_zha.png"))
	var old_root := FieldArt.art_root
	FieldArt.art_root = dir
	FieldArt.clear_cache()
	var f := _screen()
	assert_eq(FieldArt.walker_size("zheng_zha"), Vector2i(16, 32))
	var down0 := FieldArt.walker("zheng_zha", "down", 0) as AtlasTexture
	assert_eq(down0.region, Rect2(0, 0, 16, 32))
	var up_step := FieldArt.walker("zheng_zha", "up", 2) as AtlasTexture
	assert_eq(up_step.region, Rect2(48, 96, 16, 32), "第 4 行（上）第 4 列（迈另一只脚）")
	assert_eq(f.player.offset, Vector2(-8, -32), "脚底中点对齐格子")
	assert_eq(FieldArt.walker_size("zhang_jie"), Vector2i(FieldArt.WALK_W, FieldArt.WALK_H), "没有行走图的还用占位小人")
	f.free()
	FieldArt.art_root = old_root
	FieldArt.clear_cache()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir + "walkers/zheng_zha.png"))


## 一进场队友就围在主角身边（各站一格、都能走）；面前的行李、门、人会提示能做什么。
func test_formation_and_prompts() -> void:
	var f := _ready_screen()
	var taken := {}
	for i in f.followers.size():
		var c: Vector2i = f.follower_cell(i)
		assert_true(f.followers[i].visible, "队友看得见")
		assert_true(f.fmap.walkable(c))
		assert_false(taken.has(c), "不叠在一起")
		taken[c] = true
	assert_false(taken.has(f.cell))
	f.cell = Vector2i(74, 17)
	f.facing = "right"
	assert_eq(f.prompt_text(), "Enter 调查")
	f.cell = Vector2i(38, 8)
	f.facing = "up"
	assert_true(f.prompt_text().begins_with("前往："))
	f.cell = Vector2i(4, 11)
	f.facing = f._dir_between(f.cell, f.follower_cell(0))
	f.cell = f.follower_cell(0) - TiledMap.DIRS[f.facing]
	assert_true(f.prompt_text().begins_with("Enter 说话："), "队友随时能说话")
	f.cell = Vector2i(20, 12)
	f.facing = "down"
	assert_eq(f.prompt_text(), "", "面前是空地")
	f.free()


## 台词一个字一个字打出来（在场景树里才打字，测试里手动设成"还没打完"）：确认键先把这句显示完，再按才到下一句。
func test_typewriter_and_advance() -> void:
	var f := _screen()
	f.messages.clear()
	f.messages.append({"id": "zhang_jie", "name": "张杰", "text": "第一句"})
	f.messages.append({"id": "", "name": "", "text": "第二句"})
	f._hide_box()
	f._show_next()
	assert_eq(f.box_text.text, "第一句")
	assert_eq(f.box_text.visible_characters, -1, "不在场景树里不打字")
	f.box_text.visible_characters = 1
	f._advance()
	assert_eq(f.box_text.visible_characters, -1, "一下子显示完")
	assert_eq(f.box_text.text, "第一句", "还停在这一句")
	f._advance()
	assert_eq(f.box_text.text, "第二句")
	assert_false(f.box_face.visible, "旁白没有立绘")
	f.free()


## 图块层：地面、墙、装饰在人物下面，上层在人物上面；列车的地面、车厢壁、行李都填进去了（实验室图块）。
func test_tile_layers() -> void:
	var f := _screen()
	var floor: TileMapLayer = f.map_layers["floor"]
	var walls: TileMapLayer = f.map_layers["walls"]
	var decor: TileMapLayer = f.map_layers["decor"]
	assert_eq(floor.get_cell_source_id(Vector2i(4, 11)), 0, "开场格有地面")
	assert_eq(walls.get_cell_source_id(Vector2i(5, 4)), 1, "车厢壁用墙面图块")
	assert_eq(walls.get_cell_atlas_coords(Vector2i(5, 4)), Vector2i(2, 0))
	assert_eq(decor.get_cell_source_id(Vector2i(75, 17)), 2, "行李用杂物图块")
	assert_eq(decor.get_cell_atlas_coords(Vector2i(75, 17)), Vector2i(35, 11))
	assert_true(floor.get_index() < f.actors.get_index(), "地面在人物下面")
	assert_true(f.map_layers["over"].get_index() > f.actors.get_index(), "上层在人物上面")
	assert_eq(f.camera.limit_left, 0)
	assert_eq(f.camera.limit_right, 105 * 16, "比一屏大的地图：镜头贴着地图边")
	f.free()


## 镜头（在场景树里，近视野）：地图比一屏大时跟着主角，到地图边上停住；镜头滚过以后点哪格就是哪格。
func test_camera_follows_and_clamps() -> void:
	FieldScreen.maps_dir = BIG
	FieldScreen.wide = false
	var f := _screen()
	tree().root.add_child(f)
	f._snap_camera()
	await tree().process_frame
	assert_eq(f.fmap.size, Vector2i(40, 24), "测试用的大地图")
	assert_eq(f.view_origin(), Vector2.ZERO, "开场在左上角，镜头贴着地图左上边")
	assert_eq(f.cell_at(Vector2(4 * 16 * 3 + 8, 4 * 16 * 3 + 8)), Vector2i(3, 3))
	f.cell = Vector2i(20, 12)
	f._draw_actors()
	f._snap_camera()
	await tree().process_frame
	var o: Vector2 = f.view_origin()
	assert_eq(o, Vector2(20 * 16 + 8 - 240, 12 * 16 + 14 - 8 - 128), "主角在屏幕正中")
	assert_eq(f.cell_at(Vector2(240 * 4, 120 * 4)), Vector2i(20, 11), "屏幕正中偏上一点是主角头顶那格")
	f.cell = Vector2i(38, 22)
	f._draw_actors()
	f._snap_camera()
	await tree().process_frame
	assert_eq(f.view_origin(), Vector2(40 * 16 - 480, 24 * 16 - 256), "到了右下角，镜头贴着地图边停住")
	assert_eq(f.cell_at(Vector2.ZERO), Vector2i(10, 8))
	tree().root.remove_child(f)
	f.free()
	FieldScreen.maps_dir = MAPS
	FieldScreen.wide = true


## 两档视野：远（一屏 40×21 格、放大 3 倍，默认）和近（30×16 格、放大 4 倍）；比一屏小的地图在远视野里居中。
func test_view_toggle_and_small_map_centered() -> void:
	FieldScreen.wide = true
	var f := _screen()
	assert_eq(f.pixel_size, FieldScreen.VIEW_FAR)
	assert_eq(f.scale_factor, 3)
	assert_eq(f.viewport.size, Vector2i(640, 341))
	f.press_choice("listen")
	f.press_move("hall")
	f.press_move("stairs")
	assert_eq(f.fmap.size, Vector2i(30, 16))
	assert_eq([f.camera.limit_left, f.camera.limit_top, f.camera.limit_right, f.camera.limit_bottom], [-80, -42, 560, 299], "四周留同样宽的黑边")
	f.set_wide(false)
	assert_false(FieldScreen.wide)
	assert_eq(f.pixel_size, FieldScreen.VIEW_NEAR)
	assert_eq(f.scale_factor, 4)
	assert_eq(f.viewport.size, Vector2i(480, 256))
	assert_eq(f.display.size, Vector2(1920, 1024))
	assert_eq([f.camera.limit_left, f.camera.limit_top, f.camera.limit_right, f.camera.limit_bottom], [0, 0, 480, 256], "正好一屏")
	f.set_wide(true)
	assert_eq(f.display.size, Vector2(1920, 1023))
	f.free()
	FieldScreen.wide = true


## 站着不动一会儿队友就散开（各站一格、不挡门、不站人身上，离主角不远）；一走动又排成一路跟上；换屏回来散开的位置还在。
func test_spread_and_gather() -> void:
	var f := _ready_screen()
	assert_false(f.spread)
	f.spread_out()
	assert_true(f.spread)
	var taken := {f.cell: true}
	var blocked: Dictionary = f._blocked()
	for i in f.followers.size():
		var c: Vector2i = f.follower_cell(i)
		assert_true(f.fmap.walkable(c))
		assert_false(f.fmap.is_door(c))
		assert_false(blocked.has(c), "不站在剧情人物身上")
		assert_false(taken.has(c), "各站一格")
		assert_true(absi(c.x - f.cell.x) + absi(c.y - f.cell.y) <= 4, "离主角不远")
		taken[c] = true
	var ex: RefCounted = f.view.ex
	var cells: Array[Vector2i] = f.spread_cells.duplicate()
	f.free()
	var g := FieldScreen.new()
	g.setup(ex, {})
	assert_true(g.spread, "换屏回来还散着")
	assert_eq(g.spread_cells, cells)
	g.step("right")
	assert_false(g.spread, "一走就归队")
	assert_eq(g.cell, Vector2i(5, 11))
	assert_eq(g.trail.size(), 7)
	assert_eq(g.follower_cell(0), Vector2i(4, 11), "离得最近的跟在正后面")
	g.free()


## 顶着剧情人物走：先只转身对着他（能说话）；顶住一会儿他就和你换位置让路；换屏回来他还站在让开的地方。
func test_npc_gives_way() -> void:
	var f := _ready_screen()
	var mc: Vector2i = f.npc_cells["matthew"]
	_face(f, mc)
	var start: Vector2i = f.cell
	f.step(f.facing)
	assert_eq(f.cell, start, "第一下只是对着他")
	assert_eq(f.npc_cells["matthew"], mc)
	f._time += FieldScreen.GIVE_WAY_DELAY + 0.1
	f.step(f.facing)
	assert_eq(f.cell, mc, "他让开了，你走过去")
	assert_eq(f.npc_cells["matthew"], start, "他站到你原来的格子")
	var ex: RefCounted = f.view.ex
	f.free()
	var g := FieldScreen.new()
	g.setup(ex, {})
	assert_eq(g.npc_cells["matthew"], start, "换屏回来还在那儿")
	g.free()


## "在场的人"：你、六个队友、七个剧情人物；车上的剧情人物标"听不见你们说话"；名单开着时不能走。
func test_roster() -> void:
	var f := _ready_screen()
	var people: Array[String] = f.present_people()
	assert_eq(people.size(), 14)
	assert_eq(people[0], "zheng_zha")
	assert_true(people.has("ryan") and people.has("matt") and people.has("alice"))
	f.open_roster()
	assert_true(f.roster_panel.visible)
	assert_true(f.busy())
	assert_eq(f.roster_box.get_child_count(), 15, "标题加 14 行")
	assert_true(f.roster_scroll.custom_minimum_size.y <= 800.0, "名单不超出屏幕，人多了就滚动")
	assert_true(f.roster_panel.position.y + f.roster_scroll.custom_minimum_size.y < 1000.0)
	var texts: Array[String] = []
	for row in f.roster_box.get_children():
		if row is HBoxContainer:
			texts.append(String(((row as HBoxContainer).get_child(0) as Label).text))
	var deaf := 0
	for t in texts:
		if t.contains("听不见你们说话"):
			deaf += 1
	assert_eq(deaf, 7)
	f.close_panels()
	assert_false(f.busy())
	f.free()


## 人物卡：身份、状态、信任；聊出来的要点一条条记上；还有几个话题没聊过。你自己的卡写你的来历。
func test_cards() -> void:
	var f := _ready_screen()
	var m: Dictionary = f.card_info("matthew")
	assert_eq((m["lines"] as Array)[0], "身份：剧情人物")
	assert_true((m["lines"] as Array).has("现在听不见你们说话（列车减速之前）"))
	assert_true((m["lines"] as Array).has("对你的信任：0 / 5"))
	assert_eq((m["notes"] as Array).size(), 0)
	assert_eq(int(m["unseen"]), 4)
	f.view.ex.talk_topic("matthew", "matthew_look", 0)
	m = f.card_info("matthew")
	assert_eq((m["notes"] as Array).size(), 1)
	assert_eq(int(m["unseen"]), 3)
	f.dialogue_store = {"matthew": {"trust": 3}}
	assert_true((f.card_info("matthew")["lines"] as Array).has("对你的信任：3 / 5"))
	var z: Dictionary = f.card_info("zhang_jie")
	assert_eq((z["lines"] as Array)[0], "身份：轮回者")
	assert_true(String((z["lines"] as Array)[1]).begins_with("血 "))
	assert_true(String((z["lines"] as Array)[2]).begins_with("对你的信任 "))
	var me: Dictionary = f.card_info("zheng_zha")
	assert_eq((me["lines"] as Array)[0], "身份：轮回者（你自己）")
	assert_true(String((me["notes"] as Array)[0]).length() > 0, "你自己的来历")
	f.open_card("ryan")
	assert_true(f.card_panel.visible)
	assert_true(f.card_body.text.contains("还不了解"))
	assert_true(f.busy())
	f.close_panels()
	f.free()


## 新话题标记：有没聊过的话题的人头顶名字后面带"…"；聊完了就没了；走近的人才显示名字。
func test_new_topic_marks_and_names() -> void:
	var f := _ready_screen()
	assert_true(f.has_new_topic("zhang_jie"))
	assert_true(f.has_new_topic("matthew"), "车上能看看他")
	assert_false(f.has_new_topic("zheng_zha"))
	for t: Dictionary in Topics.available(f.view.ex.st, "matthew", 0):
		f.view.ex.talk_topic("matthew", String(t["id"]), 0)
	f.refresh()
	assert_false(f.has_new_topic("matthew"), "能看的都看过了")
	f._update_names()
	var rects: Array[Rect2] = []
	var shown := 0
	for id: String in f.name_labels:
		var l: Label = f.name_labels[id]
		if not l.visible:
			continue
		shown += 1
		assert_true(l.text.ends_with(" …"), "队友都还有话没聊：%s" % l.text)
		var r := Rect2(l.position, l.size)
		for o in rects:
			assert_false(r.intersects(o), "名字不叠在一起")
		rects.append(r)
	assert_true(shown >= 3, "身边的队友显示名字")
	assert_false(f.name_labels.has("matthew"), "离得远的不显示")
	f.free()
```

- [ ] **Step 3：写测试 `game/tests/unit/ui/test_tiled_map.gd`**

```gdscript
extends "res://tests/test_case.gd"
## Tiled 地图：读 .tmj / .tsj（两个图块集、翻转位、物件、属性、#AARRGGBB 颜色），能不能走、门、入口、站位、灯；
## 填进 TileMapLayer（图块集编号、图集坐标、翻转）；图片不在时的灰盒图；第一部片 8 张图整套校验。

const TiledMap = preload("res://ui/field/tiled_map.gd")
const FieldTiles = preload("res://ui/field/field_tiles.gd")
const Scenario = preload("res://core/expedition/scenario.gd")

const TINY := "res://tests/fixtures/maps/tiny"
const FILM1 := "res://data/maps/biohazard1"
const SCENARIO := "res://data/scenarios/biohazard1/scenario.json"


func _room() -> RefCounted:
	return TiledMap.make(TINY, "room")


## 地图大小、图块集按 firstgid 排好；gid 换算成"第几个图块集的第几块"，翻转位读得出来。
func test_tilesets_and_gids() -> void:
	var m := _room()
	assert_true(m != null)
	assert_eq(m.load_errors.size(), 0, "\n".join(m.load_errors))
	assert_eq(m.size, Vector2i(6, 4))
	assert_eq(m.tile, 16)
	assert_eq(m.tilesets.size(), 2)
	assert_eq(int(m.tilesets[1]["firstgid"]), 5)
	var rug: Dictionary = m.resolve(m.tile_at("floor", Vector2i(3, 1)))
	assert_eq(int(rug["set"]), 1)
	assert_eq(int(rug["id"]), 0)
	assert_true(rug["flip_h"], "水平翻转")
	assert_false(rug["flip_v"])
	var lamp: Dictionary = m.resolve(m.tile_at("over", Vector2i(1, 1)))
	assert_eq(int(lamp["id"]), 1)
	assert_true(lamp["flip_v"] and lamp["flip_d"], "垂直 + 对角翻转")
	assert_eq(m.resolve(0), {}, "空格")
	assert_eq(m.resolve(99), {}, "编号超出图块集")
	assert_true(bool(m.tile_props(m.tile_at("walls", Vector2i(0, 0))).get("blocks", false)))
	assert_eq(m.kind_at(Vector2i(2, 2)), "prop", "装饰层盖在地面上")
	assert_eq(m.kind_at(Vector2i(3, 1)), "carpet")
	assert_eq(String(m.tile_props(m.tile_at("over", Vector2i(1, 1))).get("kind", "")), "rug", "没写属性的图块用图块集上的默认值")
	assert_eq(String(m.tile_props(m.tile_at("floor", Vector2i(3, 1))).get("kind", "")), "carpet", "自己写了的盖过默认值")


## 能走：有地面、三层都不挡路；门能走；墙、箱子、没有地面的格子、图外都不能走。
func test_walkable() -> void:
	var m := _room()
	assert_true(m.walkable(Vector2i(1, 1)))
	assert_true(m.walkable(Vector2i(3, 1)), "翻转过的地毯也是地面")
	assert_true(m.walkable(Vector2i(5, 1)), "门")
	assert_false(m.walkable(Vector2i(0, 1)), "墙")
	assert_false(m.walkable(Vector2i(2, 2)), "箱子挡路")
	assert_false(m.walkable(Vector2i(-1, 1)), "图外")
	var p: Array[Vector2i] = m.path(Vector2i(1, 1), Vector2i(3, 2))
	assert_true(p.size() > 0)
	assert_false(p.has(Vector2i(2, 2)), "绕开箱子")


## 物件：门（长条）、到达点（含开场点和朝向）、柜子、固定站位和按顺序的站位。
func test_objects() -> void:
	var m := _room()
	assert_eq(m.door_dest(Vector2i(5, 2)), "outside")
	assert_eq(m.door_dest(Vector2i(1, 1)), "")
	assert_eq(m.door_cells("outside"), [Vector2i(5, 1), Vector2i(5, 2)] as Array[Vector2i])
	assert_eq(m.door_dests(), ["outside"] as Array[String])
	assert_eq(m.entry_cell("outside"), Vector2i(4, 1))
	assert_eq(m.entry_facing("outside"), "left")
	assert_eq(m.start_cell(), Vector2i(1, 1), "Tiled 新版写成 class 的物件也认")
	assert_eq(m.start_facing(), "right")
	assert_eq(m.search_cell(), Vector2i(2, 2))
	assert_true(m.is_search(Vector2i(2, 2)))
	assert_true(m.is_fixed_npc("boss"))
	assert_eq(m.npc_cell("boss", 5), Vector2i(1, 2))
	assert_eq(m.npc_cell("someone", 0), Vector2i(4, 2), "order 0")
	assert_eq(m.npc_cell("someone", 1), Vector2i(3, 2), "order 1")
	assert_eq(m.npc_cell("someone", 2), Vector2i(4, 2), "人比站位多就从头再排")


## 颜色按 Tiled 的 #AARRGGBB 读；灯和光晕的属性。
func test_colors_and_lights() -> void:
	var m := _room()
	assert_eq(TiledMap.color("#ff336699"), Color("#336699"))
	assert_almost(TiledMap.color("#80ff0000").a, 128.0 / 255.0, 0.001)
	assert_eq(TiledMap.color("#336699"), Color("#336699"))
	assert_eq(TiledMap.color("nope", Color.BLACK), Color.BLACK)
	assert_eq(m.theme(), "hall")
	assert_eq(m.ambient(), Color("#808080"))
	var l: Dictionary = m.lights()[0]
	assert_eq(l["cell"], Vector2i(2, 1))
	assert_eq(l["color"], Color("#336699"))
	assert_almost(float(l["radius"]), 3.0)
	assert_almost(float(l["energy"]), 0.5)
	assert_true(l["flicker"])
	var g: Dictionary = m.glows()[0]
	assert_eq(g["cell"], Vector2i(4, 1))
	assert_almost((g["color"] as Color).r, 1.0, 0.001)


## 填进 TileMapLayer：图块集编号、图集坐标、翻转都对；图片不在时用同样行列的灰盒图。
func test_fill_layers_and_greybox() -> void:
	var m := _room()
	var floor := TileMapLayer.new()
	FieldTiles.fill(floor, m, "floor")
	assert_eq(floor.get_cell_source_id(Vector2i(1, 1)), 0)
	assert_eq(floor.get_cell_atlas_coords(Vector2i(5, 2)), Vector2i(1, 1), "门是 a 的第 3 块：第 2 行第 2 列")
	assert_eq(floor.get_cell_source_id(Vector2i(3, 1)), 1)
	assert_eq(floor.get_cell_alternative_tile(Vector2i(3, 1)), TileSetAtlasSource.TRANSFORM_FLIP_H)
	assert_eq(floor.get_cell_source_id(Vector2i(0, 0)), -1, "空格")
	var over := TileMapLayer.new()
	FieldTiles.fill(over, m, "over")
	assert_eq(over.get_cell_atlas_coords(Vector2i(1, 1)), Vector2i(1, 0))
	assert_eq(over.get_cell_alternative_tile(Vector2i(1, 1)), TileSetAtlasSource.TRANSFORM_FLIP_V | TileSetAtlasSource.TRANSFORM_TRANSPOSE)
	var img := FieldTiles.greybox_image(m.tilesets[0], "hall", 16)
	assert_eq(img.get_size(), Vector2i(32, 32), "2 列 × 2 行")
	assert_true(img.get_pixel(8, 8).a > 0.9, "第一块（地面）画出来了")
	floor.free()
	over.free()


## 第一部片 8 张图整套校验通过。列车和站台大厅（计划 23 加大）用实验室图块；其余还是灰盒图。
func test_film1_maps_valid() -> void:
	var errors: Array[String] = TiledMap.validate(FILM1, Scenario.load_file(SCENARIO))
	assert_eq(errors.size(), 0, "\n".join(errors))
	var hall: RefCounted = TiledMap.make(FILM1, "hall")
	assert_eq(hall.size, Vector2i(71, 22), "站台连着入口大厅")
	assert_eq(hall.tilesets.size(), 3, "实验室的地面、墙壁、物件三个图块集")
	assert_eq(hall.door_dest(Vector2i(9, 18)), "car")
	assert_eq(hall.door_dest(Vector2i(52, 4)), "stairs")
	assert_eq(hall.door_dest(Vector2i(58, 20)), "sewer")
	assert_eq(hall.entry_cell("car"), Vector2i(9, 17))
	assert_eq(hall.entry_facing("car"), "up")
	assert_true(bool(hall.tile_props(hall.tile_at("walls", Vector2i(0, 0))).get("blocks", false)), "实验室墙壁整集挡路")
	assert_eq(hall.search_cell(), Vector2i(68, 19), "储物柜")
	assert_eq(int(hall.props.get("crowd", 0)), 14)
	var car: RefCounted = TiledMap.make(FILM1, "car")
	assert_eq(car.size, Vector2i(105, 23), "四节车厢")
	assert_eq(car.tilesets.size(), 3)
	assert_eq(car.start_cell(), Vector2i(4, 11))
	assert_eq(car.start_facing(), "right", "开场面朝车头")
	assert_false(car.walkable(Vector2i(5, 4)), "车厢壁")
	var stairs: RefCounted = TiledMap.make(FILM1, "stairs")
	assert_true(bool((stairs.tilesets[0]["props"] as Dictionary).get("greybox", false)))
	var tex: Texture2D = (FieldTiles.tileset(stairs).get_source(0) as TileSetAtlasSource).texture
	assert_eq(tex.get_size(), Vector2(48, 48))
	var expected := FieldTiles.greybox_image(stairs.tilesets[0], stairs.theme(), 16)
	assert_eq(tex.get_image().get_pixel(8, 8), expected.get_pixel(8, 8), "灰盒图块集按地点主题现画（本机导出的 greybox.png 只给 Tiled 看）")
	var control: RefCounted = TiledMap.make(FILM1, "control")
	assert_eq(control.npc_cell("red_queen", 0), Vector2i(14, 7))
	assert_true(control.max_lights_in_window() <= TiledMap.MAX_LIGHTS)
	assert_eq(TiledMap.make(FILM1, "laser").glows().size(), 12, "两排激光发射器")
	assert_eq(TiledMap.make(FILM1, "nowhere"), null)
```

- [ ] **Step 4：写测试 `game/tests/unit/dialogue/test_dialogue_panel.gd`**

```gdscript
extends "res://tests/test_case.gd"
## 对话框控件：追加台词、候选回复、说话/说服两种提交、关闭。

const DialoguePanel = preload("res://ui/dialogue/dialogue_panel.gd")


func _panel() -> Control:
	var p := DialoguePanel.new()
	p.build()
	p.open_for("卡普兰", "第 40 分钟 · 蜂巢入口大厅", "talk")
	return p


## 控件不进树也不会自动释放，测完自己收。
func _drop(p: Control) -> void:
	p.free()


func test_push_shows_speaker_and_text() -> void:
	var p := _panel()
	p.push("卡普兰", "别碰那扇门。[警告]")
	assert_true(p.log_label.text.contains("卡普兰"))
	assert_true(p.log_label.text.contains("别碰那扇门"))
	assert_true(p.log_label.text.contains("［警告］"), "方括号被转义，不会当成 BBCode")
	p.push("我", "为什么")
	assert_true(p.log_label.text.contains("为什么"))
	assert_eq(p._lines.size(), 2)
	_drop(p)


func test_replies_become_buttons() -> void:
	var p := _panel()
	p.set_replies(["为什么", "我偏要碰", "……"])
	assert_eq(p.reply_box.get_child_count(), 3)
	var picked: Array = []
	var sent: Array = []
	p.reply_picked.connect(func(t: String) -> void: picked.append(t))
	p.submitted.connect(func(t: String) -> void: sent.append(t))
	p.press_reply(1)
	assert_eq(picked.size(), 1)
	assert_eq(String(picked[0]), "我偏要碰")
	assert_eq(sent.size(), 1, "点了候选就等于说出口")
	p.set_replies(["a"])
	assert_eq(p.reply_box.get_child_count(), 1, "换一批会清掉旧的")
	_drop(p)


func test_send_emits_submitted() -> void:
	var p := _panel()
	var sent: Array = []
	p.submitted.connect(func(t: String) -> void: sent.append(t))
	p.input.text = "你们到底是什么人"
	p.press_send()
	assert_eq(sent.size(), 1)
	assert_eq(String(sent[0]), "你们到底是什么人")
	assert_eq(String(p.input.text), "", "发出后清空输入框")
	_drop(p)


func test_empty_input_does_nothing() -> void:
	var p := _panel()
	var sent: Array = []
	p.submitted.connect(func(t: String) -> void: sent.append(t))
	p.press_send("   ")
	assert_eq(sent.size(), 0)
	_drop(p)


func test_persuade_mode_uses_other_signal() -> void:
	var p := _panel()
	var talked: Array = []
	var argued: Array = []
	p.submitted.connect(func(t: String) -> void: talked.append(t))
	p.persuading.connect(func(t: String) -> void: argued.append(t))
	p.set_mode("persuade")
	assert_eq(String(p.send_button.text), "说服")
	p.press_send("断电，否则激光")
	assert_eq(talked.size(), 0)
	assert_eq(argued.size(), 1)
	_drop(p)


## 固定话题变成按钮：没聊过的带"•"，聊过的打"✓"；点一下发 topic_picked；没有话题时标题藏起来；重新打开会清空。
func test_topics_become_buttons() -> void:
	var p := _panel()
	assert_false(p.topic_title.visible, "没有话题时不显示")
	p.set_topics([{"id": "kaplan_door", "label": "你在忙什么？", "seen": true}, {"id": "kaplan_queen", "label": "主电脑是什么？", "seen": false}])
	assert_true(p.topic_title.visible)
	assert_eq(p.topic_count(), 2)
	assert_eq(String((p.topic_box.get_child(0) as Button).text), "✓ 你在忙什么？")
	assert_eq(String((p.topic_box.get_child(1) as Button).text), "• 主电脑是什么？")
	var picked: Array = []
	p.topic_picked.connect(func(t: String) -> void: picked.append(t))
	p.press_topic(1)
	p.press_topic(5)
	assert_eq(picked, ["kaplan_queen"])
	assert_eq(String(p.topic_title.text), "可以问的：")
	p.open_for("马修", "列车", "talk")
	assert_eq(p.topic_count(), 0, "换个人说话，旧话题清掉")
	p.set_topics([{"id": "matthew_look", "label": "看看他", "observe": true, "seen": false}])
	assert_eq(String(p.topic_title.text), "可以做的：", "只能看看的时候不叫'问'")
	_drop(p)


## 对方听不见（列车上的剧情人物）：输入框和"说"按钮关掉，硬发也发不出去；重新打开恢复。
func test_free_text_can_be_disabled() -> void:
	var p := _panel()
	var sent: Array = []
	p.submitted.connect(func(t: String) -> void: sent.append(t))
	p.set_free_text(false)
	assert_false(p.input.editable)
	assert_true(p.send_button.disabled)
	p.press_send("你听得见吗")
	assert_eq(sent.size(), 0)
	p.set_free_text(true)
	assert_true(p.input.editable)
	assert_eq(String(p.input.placeholder_text), "说点什么……")
	p.press_send("现在呢")
	assert_eq(sent.size(), 1)
	_drop(p)


func test_close_hides_and_signals() -> void:
	var p := _panel()
	var closed: Array = []
	p.closed.connect(func() -> void: closed.append(true))
	p.press_close()
	assert_eq(closed.size(), 1)
	assert_false(p.visible)
	_drop(p)
```

- [ ] **Step 5：写测试 `game/tests/unit/settings/test_settings.gd`**

```gdscript
extends "res://tests/test_case.gd"
## 设置：默认值、读写往返、坏文件回退、未知值被忽略、无头下 apply 不炸。

const Settings = preload("res://core/settings/settings.gd")
const PATH := "user://test_settings.json"


func before_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _write_raw(text: String) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_defaults() -> void:
	var s := Settings.defaults()
	assert_eq(String(s["window_mode"]), "windowed")
	assert_almost(float(s["volume"]), 0.8)


func test_missing_file_uses_defaults() -> void:
	var s := Settings.load_settings(PATH)
	assert_eq(String(s["window_mode"]), "windowed")
	assert_almost(float(s["volume"]), 0.8)


func test_round_trip() -> void:
	assert_eq(Settings.save_settings({"window_mode": "fullscreen", "volume": 0.3}, PATH), OK)
	var back := Settings.load_settings(PATH)
	assert_eq(String(back["window_mode"]), "fullscreen")
	assert_almost(float(back["volume"]), 0.3)


func test_broken_file_falls_back() -> void:
	_write_raw("{broken")
	var s := Settings.load_settings(PATH)
	assert_eq(String(s["window_mode"]), "windowed")
	assert_almost(float(s["volume"]), 0.8)


func test_unknown_mode_and_clamped_volume() -> void:
	_write_raw('{"window_mode": "windowed_fullscreen", "volume": 2.0}')
	var s := Settings.load_settings(PATH)
	assert_eq(String(s["window_mode"]), "windowed", "不认识的值不采纳")
	assert_almost(float(s["volume"]), 1.0, 0.0001, "音量夹到 0~1")


## 探索画面的视野（远 / 近）：默认远；存进去读得回来；读进来一律是 bool。
func test_field_wide() -> void:
	assert_true(bool(Settings.defaults()["field_wide"]))
	assert_true(bool(Settings.load_settings(PATH)["field_wide"]))
	assert_eq(Settings.save_settings({"window_mode": "windowed", "volume": 0.8, "field_wide": false}, PATH), OK)
	var back := Settings.load_settings(PATH)
	assert_eq(typeof(back["field_wide"]), TYPE_BOOL)
	assert_false(bool(back["field_wide"]))


## 无头测试里 apply 直接返回；这里只验证它不改坏字典。
func test_apply_and_with_value() -> void:
	var s := Settings.defaults()
	Settings.apply(s)
	assert_eq(String(s["window_mode"]), "windowed")
	var next := Settings.with_value(s, "volume", 0.5)
	assert_almost(float(next["volume"]), 0.5)
	assert_almost(float(s["volume"]), 0.8, 0.0001, "with_value 不改原字典")
```

- [ ] **Step 6：写测试 `game/tests/unit/ai/test_persona.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Persona = preload("res://ai/persona.gd")


func test_from_data() -> void:
	var m := Persona.from_data("matthew")
	assert_eq(m.id, "matthew")
	assert_eq(m.name, "马修·艾迪森")
	assert_eq(m.role, "plot_npc")
	assert_eq(m.fallback_lines.size(), 3)
	assert_eq(Persona.from_data("zhushen").role, "zhushen")


func test_context_text() -> void:
	var m := Persona.from_data("matthew")
	m.remember("郑吒在车厢里救过他")
	var t: String = m.context_text()
	assert_true(t.begins_with("【你扮演】马修·艾迪森"))
	assert_true(t.contains("性格：冷静、多疑"))
	assert_true(t.contains("你知道但绝不会说出口的事：他并不知道蜂房里真正发生了什么，上头没告诉他全部实情"))
	assert_true(t.contains("- 郑吒在车厢里救过他"))


## 记忆不会无限增长：最早的两条合并成一条。
func test_memory_cap() -> void:
	var p := Persona.new()
	p.name = "测试"
	for i in 14:
		p.remember("事件%d" % i)
	assert_eq(p.memories.size(), 12)
	assert_true(p.memories[0].begins_with("更早的事："))
	assert_true(p.memories[0].contains("事件2"))
	assert_eq(p.memories[11], "事件13")
	p.remember("长".repeat(300))
	assert_true(p.memories[0].length() <= 120)


func test_round_trip() -> void:
	var m := Persona.from_data("matthew")
	m.remember("被威胁过")
	var copy := Persona.new()
	copy.load_dict(JSON.parse_string(JSON.stringify(m.to_dict())))
	assert_eq(copy.to_dict(), m.to_dict())
```

- [ ] **Step 7：运行，确认失败**

Run: `bash game/tools/run_tests.sh > _work/p23_task2_red.txt 2>&1; echo "exit=$?"; tail -1 _work/p23_task2_red.txt`

预期：`exit=1`（话题模块还没有，新地图、名单、人物卡都还没做）。

- [ ] **Step 8：创建 `game/core/dialogue/topics.gd`**

```gdscript
extends RefCounted
## 固定话题（设计 2026-11-12 第 7 节）：不接 AI 也能和每个人聊的内容，照原著写好。
## 数据在剧本目录的 topics.json：{"version": 1, "topics": {人物 id: [话题, ...]}}。一个话题：
##   id      全剧本唯一
##   label   玩家看到的问题（"你是谁？"）
##   when    什么时候能聊（剧本条件，见 conditions.gd），可省
##   trust   对方的对话信任至少多少（0~5，每聊一个新话题 +1），可省
##   after   先聊过哪个话题，可省
##   text    对方的回答；或者 variants：[{fear_min?, when?, text}]，按顺序取第一个符合的（fear_min 看说话人自己的恐惧）
##   card    聊过以后记在人物卡上的一句要点，可省
##   effects 聊第一次时跑的剧情效果（线索、旗标、关系、百科……），可省
## 剧情人物所在的地点写了 unheard（车减速之前的列车，原著 L62）时，他们听不见轮回者说话：
## 只能聊写了 observe 的话题（看看他），也不能自由对话。聊过的话题记在 ExpeditionState.topics_seen。

const DataLoader = preload("res://core/util/data_loader.gd")
const Conditions = preload("res://core/expedition/conditions.gd")

static var _cache: Dictionary = {}


static func path_for(scenario: RefCounted) -> String:
	return "res://data/scenarios/%s/topics.json" % scenario.id


## 这部片全部的话题：人物 id → 话题数组。没有话题文件时是空字典。
static func all_for(scenario: RefCounted) -> Dictionary:
	var path := path_for(scenario)
	if _cache.has(path):
		return _cache[path]
	var out := {}
	if FileAccess.file_exists(path):
		var res := DataLoader.load_json(path)
		if res.ok:
			out = (res.data as Dictionary).get("topics", {})
		else:
			push_error(res.error)
	_cache[path] = out
	return out


static func defs(st: RefCounted, npc_id: String) -> Array:
	return all_for(st.scenario).get(npc_id, [])


## 这个人现在听不听得见轮回者说话：剧情人物在写了 unheard 的地点时听不见；轮回者总听得见。
static func can_hear(st: RefCounted, npc_id: String) -> bool:
	if not st.npcs.has(npc_id):
		return true
	var loc := String(st.npcs[npc_id]["location"])
	return not bool(st.scenario.location(loc).get("unheard", false))


static func _open(st: RefCounted, npc_id: String, t: Dictionary, trust: int) -> bool:
	if t.has("when") and not Conditions.check(t["when"], st):
		return false
	if trust < int(t.get("trust", 0)):
		return false
	if t.has("after") and not st.topics_seen.has(String(t["after"])):
		return false
	if bool(t.get("observe", false)) == can_hear(st, npc_id):
		return false
	return true


## 现在能聊的话题（按数据顺序），每个是原数据的副本，多一个 seen。
static func available(st: RefCounted, npc_id: String, trust: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Dictionary in defs(st, npc_id):
		if _open(st, npc_id, t, trust):
			var c := t.duplicate(true)
			c["seen"] = st.topics_seen.has(String(t["id"]))
			out.append(c)
	return out


## 有没有还没聊过、现在能聊的话题（头上冒"…"）。
static func has_new(st: RefCounted, npc_id: String, trust: int) -> bool:
	for t in available(st, npc_id, trust):
		if not bool(t["seen"]):
			return true
	return false


## 还没聊过的话题一共几个（包括现在还聊不了的）：人物卡上提示"还有几个话题没聊过"。
static func unseen_count(st: RefCounted, npc_id: String) -> int:
	var n := 0
	for t: Dictionary in defs(st, npc_id):
		if not st.topics_seen.has(String(t["id"])):
			n += 1
	return n


static func find(st: RefCounted, npc_id: String, topic_id: String) -> Dictionary:
	for t: Dictionary in defs(st, npc_id):
		if String(t["id"]) == topic_id:
			return t
	return {}


## 回答：有 variants 时取第一个符合的，否则 text。
static func text_of(st: RefCounted, npc_id: String, t: Dictionary) -> String:
	for v: Dictionary in t.get("variants", []):
		if v.has("fear_min"):
			if not st.characters.has(npc_id) or float(st.characters[npc_id].fear) < float(v["fear_min"]):
				continue
		if v.has("when") and not Conditions.check(v["when"], st):
			continue
		return String(v["text"])
	return String(t.get("text", ""))


## 人物卡上的要点：聊过的话题的 card，按数据顺序。
static func notes(st: RefCounted, npc_id: String) -> Array[String]:
	var out: Array[String] = []
	for t: Dictionary in defs(st, npc_id):
		if st.topics_seen.has(String(t["id"])) and String(t.get("card", "")) != "":
			out.append(String(t["card"]))
	return out


## 整个话题文件的问题（测试和校验用）：id 重复、缺回答、after 指向不存在的话题、人物不存在。
static func validate(scenario: RefCounted, known_people: Array) -> Array[String]:
	var errors: Array[String] = []
	var ids := {}
	var topics := all_for(scenario)
	for npc_id: String in topics:
		if not known_people.has(npc_id):
			errors.append("话题里的人物 %s 不存在" % npc_id)
		for t: Dictionary in topics[npc_id]:
			var tid := String(t.get("id", ""))
			if tid == "" or ids.has(tid):
				errors.append("话题 id 为空或重复：%s" % tid)
			ids[tid] = npc_id
			if String(t.get("label", "")) == "":
				errors.append("话题 %s 没有问题" % tid)
			if String(t.get("text", "")) == "" and (t.get("variants", []) as Array).is_empty():
				errors.append("话题 %s 没有回答" % tid)
	for npc_id: String in topics:
		for t: Dictionary in topics[npc_id]:
			if t.has("after") and not ids.has(String(t["after"])):
				errors.append("话题 %s 的 after 指向不存在的话题" % String(t["id"]))
	return errors
```

- [ ] **Step 9：创建 `game/data/scenarios/biohazard1/topics.json`**

```json
{
	"version": 1,
	"note": "固定话题（设计 2026-11-12 第 7 节）。照原著《无限恐怖》生化危机一（_work/chunks/chunk01.txt）写；括号里的 L 是原著行号，只在这条注释里说明，不进游戏。列车上（unheard）剧情人物听不见轮回者，只能看看他们（observe）。",
	"topics": {
		"zhang_jie": [
			{
				"id": "zhang_jie_who",
				"label": "你是谁？",
				"text": "张杰。这是我的第四部恐怖片了——第一部是《猛鬼街》，命大，活下来了。别问我怎么活的，问就是运气。",
				"card": "老手，这是第四部片；第一部是《猛鬼街》。"
			},
			{
				"id": "zhang_jie_rules",
				"label": "再讲讲规则。",
				"text": "看手表。倒数的数字，是你必须在这部片里待的时间，时间一到就活着回去领奖励。左上角那个名字——马修·艾迪森——离他一百米以外，轰的一声，什么都没了。还有：车一减速，他们就听得见我们说话了，当着他们的面别提主神、别提奖励点，被听到一句扣十点。",
				"card": "讲清了规则：倒数、离马修一百米就抹杀、剧情人物面前禁言。",
				"effects": [{"codex": {"ids": ["tether", "gag", "kill_points"], "source": "zhang_jie"}}]
			},
			{
				"id": "zhang_jie_plan",
				"label": "接下来怎么办？",
				"variants": [
					{"when": {"party_at": "car"}, "text": "等车停了，跟着那帮当兵的走，少说话。他们会把你们当成这里登记在册的保安。——你们几个，谁看过这部电影？"},
					{"text": "生化危机一是部轻松的片子：能用科技解释，怪物打得死，也躲得开。只要主电脑不关，这地方比外面安全；关了以后，就各凭本事了。别离雇佣兵太远。"}
				],
				"card": "觉得这部片不难：只要主电脑不关就安全。"
			},
			{
				"id": "zhang_jie_gun",
				"label": "你那把枪……",
				"trust": 2,
				"text": "沙漠之鹰，无限子弹的，一百点换的。在这儿，枪比命值钱——你们第一部片活下来，也会去换的。",
				"card": "沙漠之鹰，无限子弹，一百点换的。",
				"effects": [{"clue": "desert_eagle"}]
			},
			{
				"id": "zhang_jie_past",
				"label": "你到底经历过什么？",
				"trust": 3,
				"text": "……我只见过一次支线剧情。杀掉梦里那个恶魔，五千点奖励，外加一次 B 级支线。不是我杀的，我只是在旁边看着。那种机会，可遇不可求。",
				"card": "见过一次 B 级支线：杀掉梦中恶魔，五千点。",
				"effects": [{"codex": {"ids": ["side_plots"], "source": "zhang_jie"}}]
			}
		],
		"zhan_lan": [
			{
				"id": "zhan_lan_who",
				"label": "你是谁？",
				"text": "詹岚。詹天佑的詹，山风为岚的岚——听起来很像男孩子的名字吧？我是写小说的。来这里之前一直抱怨没有灵感……没想到来到了一个灵感多到要命的世界，这也算报应吧。",
				"card": "作家；来之前一直抱怨没有灵感。"
			},
			{
				"id": "zhan_lan_film",
				"label": "你看过这部电影吗？",
				"text": "《生化危机》，看过。结尾是实验室的 T 病毒跑出去，感染了整座浣熊市。我本来想，趁现在坐这节车逃出去不就活了？可张杰说离开那个人一百米就会死……主神早就把这条路堵上了。",
				"card": "看过这部电影，记得结局：T 病毒跑出实验室。"
			},
			{
				"id": "zhan_lan_plan",
				"label": "你怎么看？",
				"variants": [
					{"when": {"party_at": "car"}, "text": "先别急着信谁。我们看过电影，可电影里没有我们。多看，少说。"},
					{"text": "记住电影里谁能活到最后：女主角，还有那个戴手铐的。'主角不死'——跟紧他们，比跟紧枪更保险。"}
				],
				"card": "主张多看少说；信'主角不死'。"
			},
			{
				"id": "zhan_lan_infection",
				"label": "被咬了会怎么样？",
				"when": {"party_at": "hall"},
				"text": "电影里，被丧尸咬一口或者抓一下就会感染，三十分钟内变成丧尸。我以前看的时候算过——大概十分钟内打进解毒剂才有用。所以千万别离张杰太远，也千万别被碰到。",
				"card": "算过：被咬后十分钟内打解毒剂才有用。"
			},
			{
				"id": "zhan_lan_doubt",
				"label": "你在怀疑什么？",
				"trust": 2,
				"text": "张杰讲规则讲得太顺了，像背过一样。一个老手，为什么对我们几个新人这么上心？……我不是说他坏。我只是想知道他要我们做什么。",
				"card": "觉得张杰讲规则太顺，像背过。",
				"effects": [{"clue": "rules_too_smooth"}]
			}
		],
		"li_xiao_yi": [
			{
				"id": "li_xiao_yi_who",
				"label": "你是谁？",
				"text": "李萧毅，高三。来之前……抱怨过很多事。不过这里其实也蛮不错的，只要不死就能变成超人，张杰说能力还能带回去。",
				"card": "高三学生，觉得这里能变成超人。"
			},
			{
				"id": "li_xiao_yi_plan",
				"label": "你怎么看？",
				"variants": [
					{"when": {"party_at": "car"}, "text": "一千点能换什么？你说主神那儿有没有刀枪不入的？我要是能换……"},
					{"text": "那些外国兵拿的可是真家伙。要是能弄一把来……我也不想一直躲在后面。"}
				],
				"card": "心急，想尽快变强。"
			},
			{
				"id": "li_xiao_yi_back",
				"label": "回去以后你想做什么？",
				"trust": 2,
				"text": "……我再也受不了在学校里被欺负了。如果我能回去——我一定要杀了那些混账。",
				"card": "在学校一直被欺负，想回去报仇。"
			},
			{
				"id": "li_xiao_yi_warn",
				"label": "当着他们的面，嘴上留神。",
				"when": {"party_at": "hall"},
				"after": "li_xiao_yi_who",
				"text": "啊？……哦哦，主神、点数那些？我知道我知道，我又不傻。",
				"card": "嘴快，已经提醒过他别说漏。",
				"effects": [{"set_flag": "li_xiao_yi_warned"}]
			}
		],
		"mu_gang": [
			{
				"id": "mu_gang_who",
				"label": "你是谁？",
				"text": "牟钢，牟的牟，钢的钢。唉，比不得你们文化人……跑长途货运的。来之前抱怨老伴太小气，儿子也不争气，跟朋友上网玩游戏，点了个确认，就到这儿来了。",
				"card": "长途货运司机；玩游戏时点了确认被拉进来。"
			},
			{
				"id": "mu_gang_plan",
				"label": "你怎么看？",
				"variants": [
					{"when": {"party_at": "car"}, "text": "没事儿，跟着哥。打架我还是在行的。"},
					{"text": "这门还得开多久？这帮人拿的什么家伙……真要打起来，咱们手里可啥都没有。"}
				],
				"card": "嘴上说没事，力气大。"
			},
			{
				"id": "mu_gang_fear",
				"label": "你怕吗？",
				"trust": 2,
				"text": "怕？……怕。晚上睡不着觉那种怕。你别跟别人说。",
				"card": "其实怕得要命。"
			}
		],
		"xiao_pang_zi": [
			{
				"id": "xiao_pang_zi_who",
				"label": "你是谁？",
				"text": "我……名字不重要。二十七了，一直在家待着，打游戏。点了个'确认'，一睁眼就在这车上了……这是做梦吧？对吧？",
				"card": "二十七八岁，一直宅在家；觉得是在做梦。"
			},
			{
				"id": "xiao_pang_zi_status",
				"label": "还撑得住吗？",
				"variants": [
					{"fear_min": 40, "text": "我、我腿软……我跑不动的。你们别丢下我，求你们了。"},
					{"text": "还……还行。就是我跑不快，从小体育就没及格过。待会儿要是跑起来，你们等等我行吗？"}
				],
				"card": "跑不快，怕被落下。"
			},
			{
				"id": "xiao_pang_zi_pray",
				"label": "你一直在念叨什么？",
				"trust": 2,
				"text": "……在祈祷。祈祷这只是一场梦，醒过来我还在自己房间里。",
				"card": "一直祈祷这只是一场梦。"
			}
		],
		"zhong_nian_fu_nv": [
			{
				"id": "zhong_nian_fu_nv_who",
				"label": "您是……？",
				"text": "我是教书的，教了二十年中学。这把年纪了，还被拉来受这份罪……你们年轻人腿脚快，到时候别光顾着自己跑。",
				"card": "中学老师；体力跟不上年轻人。"
			},
			{
				"id": "zhong_nian_fu_nv_status",
				"label": "您还好吗？",
				"variants": [
					{"fear_min": 40, "text": "我……我歇一口气就好。别管我，你们先走——不，别走，别走……"},
					{"text": "还行。就是这膝盖不争气，楼梯一多就不行。那孩子（她看了一眼小胖子）比我还怕，你们多照应着点。"}
				],
				"card": "膝盖不好，怕楼梯；会照顾比她更怕的人。"
			}
		],
		"matthew": [
			{
				"id": "matthew_look",
				"label": "看看他",
				"observe": true,
				"text": "（一名黑人雇佣兵，看样子是这群外国军人的队长。手表左上角的名字就是他——刚才几个人念出'马修·艾迪森'时，他身上闪过一层淡淡的光。他听不见你们说话。）",
				"card": "雇佣兵队长；手表绑定的人。"
			},
			{
				"id": "matthew_where",
				"label": "我们要去哪？",
				"text": "地下有个设施，叫蜂房，保护伞公司的。五个小时前，里面的主电脑把整个蜂房封死了。我们要下去，关掉那台电脑。你们几个是登记在册的保安——跟着走，别碍事。",
				"card": "任务：下到蜂房，关掉封锁一切的主电脑。"
			},
			{
				"id": "matthew_doubt",
				"label": "你好像不信任我们。",
				"after": "matthew_where",
				"text": "名单上有你们，可我从没见过你们。在我弄清楚之前，你们走在前面，我看得见的地方。……别让我后悔带上你们。",
				"card": "对你们起疑。"
			},
			{
				"id": "matthew_alice",
				"label": "那个穿红裙的女人是谁？",
				"after": "matthew_where",
				"text": "艾丽丝。蜂房入口的保安，和我们是一边的。那枚婚戒是假的——她没结婚，那只是掩饰，也是她守着这里的标志。",
				"card": "说艾丽丝的婚戒是掩饰，她是蜂房入口的保安。"
			}
		],
		"alice": [
			{
				"id": "alice_look",
				"label": "看看她",
				"observe": true,
				"text": "（穿红裙子的女人，手指上戴着婚戒。她好像刚醒过来不久，眼神发空，一直在打量自己的手。她听不见你们说话。）",
				"card": "红裙、戴婚戒，像是刚醒过来。"
			},
			{
				"id": "alice_okay",
				"label": "你还好吗？",
				"text": "……我在一栋大房子里醒过来，什么都想不起来。他们说我是这里的保安。我身上有这枚戒指，可我不记得自己嫁给过谁。",
				"card": "失忆了；被告知自己是蜂房的保安。"
			},
			{
				"id": "alice_ring",
				"label": "马修说那戒指是假的。",
				"after": "alice_okay",
				"text": "假的……也许吧。可我总觉得，我忘了一件很重要的事。很重要。",
				"card": "觉得自己忘了一件很重要的事。"
			}
		],
		"ryan": [
			{
				"id": "ryan_look",
				"label": "看看他",
				"observe": true,
				"text": "（一个穿便装的男人，不像雇佣兵。他靠着车窗发呆，像是在努力想起自己是谁。——郑吒认得他：电影里偷走 T 病毒、害了整个蜂房的商业间谍。他听不见你们说话。）",
				"card": "穿便装、失忆。郑吒认得他：电影里偷 T 病毒的商业间谍。"
			},
			{
				"id": "ryan_who",
				"label": "你是谁？",
				"text": "我……瑞恩？他们是这么叫我的。我记不清了，脑子里像蒙着一层雾。我好像不该在这儿。",
				"card": "失忆，只记得别人叫他瑞恩。"
			},
			{
				"id": "ryan_train",
				"label": "你还记得那趟车吗？",
				"after": "ryan_who",
				"text": "车……我在那趟车上待过很久，我记得那股味道。我总觉得我在车上藏过什么东西——很要紧的东西。可我想不起来是什么，也想不起来藏在哪。",
				"card": "觉得自己在列车上藏过很要紧的东西。",
				"effects": [{"clue": "ryan_memory"}]
			}
		],
		"matt": [
			{
				"id": "matt_look",
				"label": "看看他",
				"observe": true,
				"text": "（一个戴着手铐的年轻人，被雇佣兵看着，像个犯人。他不停打量四周，好像在找什么。他听不见你们说话。）",
				"card": "戴着手铐，被当成犯人。"
			},
			{
				"id": "matt_cuffs",
				"label": "他们为什么铐着你？",
				"text": "我不知道！我连自己叫什么都想不起来……他们说我是闯进来的。可我有种感觉，我来这儿是有原因的。",
				"card": "失忆，被当成闯入者铐着。"
			},
			{
				"id": "matt_search",
				"label": "你来这儿是为了什么？",
				"after": "matt_cuffs",
				"text": "……一个女人。我在找一个女人，她在这下面工作。我必须找到她。——（郑吒知道：马特在找他姐姐。她是蜂房的高级研究员，想把公司研究 T 病毒的事告诉政府。）",
				"card": "在找一个在蜂房工作的女人。郑吒知道：是他姐姐，蜂房的高级研究员。",
				"effects": [{"clue": "matt_memory"}]
			}
		],
		"kaplan": [
			{
				"id": "kaplan_look",
				"label": "看看他",
				"observe": true,
				"text": "（一个技术员模样的雇佣兵，膝盖上摊着笔记本电脑，手指一直在键盘上敲。他听不见你们说话。）",
				"card": "技术员，随身带着电脑。"
			},
			{
				"id": "kaplan_door",
				"label": "你在忙什么？",
				"text": "门禁。这道钢门的锁接在主电脑上，得骗过它才开得了。给我几分钟。",
				"card": "负责破解门禁。"
			},
			{
				"id": "kaplan_queen",
				"label": "主电脑是什么？",
				"after": "kaplan_door",
				"text": "叫火焰女皇。整个蜂房都归她管——门、通风，还有防御系统。我们这次就是要下去把她关掉。",
				"card": "主电脑叫火焰女皇，管着门和防御系统。",
				"effects": [{"clue": "queen_console"}]
			}
		],
		"jd": [
			{
				"id": "jd_look",
				"label": "看看他",
				"observe": true,
				"text": "（一个头盔上挂着夜视仪的雇佣兵，枪一直端在胸前，看样子是打头阵的。他听不见你们说话。）",
				"card": "带夜视仪，打头阵的尖兵。"
			},
			{
				"id": "jd_below",
				"label": "下面是什么情况？",
				"text": "五百多号人在下面上班。五个小时前这地方被封死了，电话、网络全断。我们下去看看怎么回事——我走前面，你们别乱碰东西。",
				"card": "说蜂房里有五百多名员工，五小时前被封死。"
			}
		],
		"rain": [
			{
				"id": "rain_look",
				"label": "看看她",
				"observe": true,
				"text": "（一个长发的女雇佣兵，枪口从上车起就没放下过。她听不见你们说话。）",
				"card": "长发女雇佣兵，一直警戒着。"
			},
			{
				"id": "rain_who",
				"label": "你们是什么人？",
				"text": "保护伞的安保部队。少问，跟着走。",
				"card": "保护伞公司的安保部队，不爱说话。"
			},
			{
				"id": "rain_uneasy",
				"label": "你好像不太放心。",
				"after": "rain_who",
				"text": "一道锁死的门，一台不说话的电脑，五百个不接电话的人。你说呢？",
				"card": "觉得这次任务不对劲。"
			}
		]
	}
}
```

- [ ] **Step 10：改写 `game/core/expedition/expedition_state.gd`**

```gdscript
extends RefCounted
## 一次远征（一部恐怖片）进行中的全部状态：时钟、分队、剧情人物、剧情旗标、已触发的事件、剧情偏移、手表限制、击杀与结算条目。
## 规则由 watch.gd、plot_runner.gd、expedition.gd 实现；这里只存数据、做查询、存读档。

const Scenario = preload("res://core/expedition/scenario.gd")
const IntelState = preload("res://core/intel/intel_state.gd")

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
## 聊过的固定话题：话题 id → true（core/dialogue/topics.gd）。
var topics_seen: Dictionary = {}
## 角色 id → 击杀点数（小数，结算时合计后向下取整）。
var kill_points: Dictionary = {}
var kill_counts: Dictionary = {}
## 结算条目：{"char", "kind", "points", "label", "grade"}，kind 同 settlement.gd。
var ledger: Array = []
## 等待界面去打的战斗；不为空时其他行动都会被拒绝。
var pending_battle: Dictionary = {}
## 等待玩家做的选择 {"id", "prompt", "options": [{"id", "text", "effects"}], "location"}。
var pending_choice: Dictionary = {}
## 等待对话层评估的说服 {"id", "npc", "goal", "difficulty", "keywords", "success", "failure", "location"}。
var pending_check: Dictionary = {}
## 待播的剧情插图（CG）：{"name", "text"}；非空时挡着其他行动，等界面播完再 dismiss。
var pending_cutscene: Dictionary = {}
## 这部片的隐藏事实与线索（剧本的 facts）。
var intel: RefCounted = IntelState.new()
## 感染者 id → 已感染多少分钟（战斗里被咬、没解毒，带出了战斗）。
var infected: Dictionary = {}
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
	intel.load_facts(sc.data.get("facts", {}))


## 有等待处理的战斗、选择、说服或插图时，其他行动都要等。
func is_blocked() -> bool:
	return not (pending_battle.is_empty() and pending_choice.is_empty() and pending_check.is_empty() and pending_cutscene.is_empty())


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


## 把指定的人（不管原来在哪支队）拉出来，组成一支新分队放到 to；返回新分队 id。一个活人都没有时返回空字符串。
func move_members(member_ids: Array, to: String) -> String:
	var moving: Array = []
	for c: String in member_ids:
		if is_alive(c):
			moving.append(c)
	if moving.is_empty():
		return ""
	for sid: String in squads:
		for c in moving:
			(squads[sid]["members"] as Array).erase(c)
	var new_id := "s%d" % next_squad_no
	next_squad_no += 1
	squads[new_id] = {"members": moving, "location": to, "items": {}}
	return new_id


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
		"topics_seen": topics_seen.duplicate(),
		"kill_points": kill_points.duplicate(),
		"kill_counts": kill_counts.duplicate(),
		"ledger": ledger.duplicate(true),
		"pending_battle": pending_battle.duplicate(true),
		"pending_choice": pending_choice.duplicate(true),
		"pending_check": pending_check.duplicate(true),
		"pending_cutscene": pending_cutscene.duplicate(true),
		"intel": intel.to_dict(),
		"infected": infected.duplicate(),
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
	topics_seen = (d.get("topics_seen", {}) as Dictionary).duplicate()
	kill_points = (d["kill_points"] as Dictionary).duplicate()
	kill_counts = {}
	for c: String in d["kill_counts"]:
		kill_counts[c] = int(d["kill_counts"][c])
	ledger = (d["ledger"] as Array).duplicate(true)
	pending_battle = (d["pending_battle"] as Dictionary).duplicate(true)
	pending_choice = (d.get("pending_choice", {}) as Dictionary).duplicate(true)
	pending_check = (d.get("pending_check", {}) as Dictionary).duplicate(true)
	pending_cutscene = (d.get("pending_cutscene", {}) as Dictionary).duplicate(true)
	if d.has("intel"):
		intel.load_dict(d["intel"])
	infected = {}
	for c: String in d.get("infected", {}):
		infected[c] = int(d["infected"][c])
	outcome = String(d["outcome"])
	settled = bool(d["settled"])
```

- [ ] **Step 11：改写 `game/core/expedition/expedition.gd`**

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
const Topics = preload("res://core/dialogue/topics.gd")
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
## 聊一个固定话题（core/dialogue/topics.gd）：现在聊得了才算；第一次聊时标成聊过并跑它的效果。
## trust = 对方现在的对话信任（在 session 的对话记忆里）。返回 {"text", "new", "card", "events"}；聊不了返回 {}。
func talk_topic(npc_id: String, topic_id: String, trust: int) -> Dictionary:
	var t: Dictionary = {}
	for a: Dictionary in Topics.available(st, npc_id, trust):
		if String(a["id"]) == topic_id:
			t = a
	if t.is_empty() or st.outcome != "ongoing":
		return {}
	var is_new: bool = not st.topics_seen.has(topic_id)
	var events: Array[Dictionary] = []
	if is_new:
		st.topics_seen[topic_id] = true
		events.append({"type": "topic_talked", "npc": npc_id, "topic": topic_id})
		PlotRunner.apply_effects(st, t.get("effects", []), String(st.location_of(npc_id)) if st.characters.has(npc_id) else String(st.npcs.get(npc_id, {}).get("location", "")), events)
		PlotRunner.run_conditional(st, events)
	return {"text": Topics.text_of(st, npc_id, t), "new": is_new, "card": String(t.get("card", "")), "events": _emit(events)}


func apply_effects(effects: Array, location: String = "") -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if st.outcome != "ongoing":
		events.append({"type": "invalid_action", "reason": "ended"})
		return _emit(events)
	PlotRunner.apply_effects(st, effects, location, events)
	PlotRunner.run_conditional(st, events)
	return _emit(events)


## 为待打的战斗生成单位。loadouts：角色 id → 技能 id 数组（没给的用角色自己的技能，什么都没有就只会拳脚）。
## 每个人带着自己的能量和道具；分队共用的道具交给分队名单上的第一个人携带。
## 带着手榴弹、止血喷雾这类消耗品的人，自动多出对应的技能（battle_data.item_skills）。
## 站位：近战只打得到最前面一排，所以按"抗打"（肌肉 + 细胞活力）排，抗打的一半站前排（最多 4 人），其余往后。
func battle_units(loadouts: Dictionary, controller: String = "player") -> Array[RefCounted]:
	var units: Array[RefCounted] = []
	if st.pending_battle.is_empty():
		return units
	var sid := String(st.pending_battle["squad"])
	var living: Array[String] = st.living_members(sid)
	var carrier: String = living[0] if not living.is_empty() else ""
	var members: Array[String] = formation(living)
	var front := mini(4, ceili(members.size() / 2.0))
	for i in members.size():
		var c := members[i]
		var ch: RefCounted = st.characters[c]
		var skills: Array[String] = []
		var own_skills: Array = ch.skills if not ch.skills.is_empty() else ["punch"]
		for s in loadouts.get(c, own_skills):
			skills.append(String(s))
		var res: Dictionary = ch.battle_resources()
		if c == carrier:
			for k: String in st.squads[sid]["items"]:
				res[k] = float(res.get(k, 0.0)) + float(st.squads[sid]["items"][k])
		for s in BattleData.item_skills(res):
			if not skills.has(s):
				skills.append(s)
		var row := 0 if i < front else mini(1 + floori((i - front) / 4.0), 2)
		units.append(UnitFactory.from_character(ch, "ally", row, skills, controller if obeys(c) else "ai", res))
	st.pending_battle["carrier"] = carrier
	var n := 0
	for g: Dictionary in st.pending_battle["enemies"]:
		for k in int(g.get("count", 1)):
			n += 1
			var row := mini(int(g.get("row", 0)) + floori(k / 4.0), 2)
			units.append(UnitFactory.from_enemy(String(g["def"]), "%s_%d" % [g["def"], n], row))
	return units


## 战斗站位顺序：抗打（肌肉 + 细胞活力）高的在前；一样高的保持原来的顺序。
func formation(member_ids: Array[String]) -> Array[String]:
	var order: Array[String] = member_ids.duplicate()
	var toughness := func(id: String) -> float:
		var ch: RefCounted = st.characters[id]
		return float(ch.attributes.total("muscle")) + float(ch.attributes.total("cell_vitality"))
	var index := {}
	for i in order.size():
		index[order[i]] = i
	order.sort_custom(func(a: String, b: String) -> bool:
		var ta: float = toughness.call(a)
		var tb: float = toughness.call(b)
		return ta > tb if ta != tb else int(index[a]) < int(index[b]))
	return order


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

- [ ] **Step 12：改写 `game/data/scenarios/biohazard1/scenario.json`**

```json
{
	"id": "biohazard1",
	"name": "生化危机一",
	"start_location": "car",
	"duration_minutes": 187,
	"main_task": "存活 3 小时 07 分；不得离开马修 100 米",
	"locations": {
		"car": {"name": "列车", "pos": [60, 700], "unheard": true, "search": [{"item": "grenade", "count": 1}, {"item": "ammo", "count": 6}]},
		"hall": {"name": "站台与入口大厅", "pos": [220, 600]},
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
		"matthew": {"name": "马修·艾迪森", "location": "car", "plot": true},
		"alice": {"name": "艾丽丝", "location": "car", "plot": true},
		"ryan": {"name": "瑞恩", "location": "car", "plot": true},
		"matt": {"name": "马特", "location": "car", "plot": true},
		"kaplan": {"name": "卡普兰", "location": "car", "plot": true},
		"jd": {"name": "J·D", "location": "car", "plot": true},
		"rain": {"name": "雷恩", "location": "car", "plot": true},
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
		"ryan_stash": {"statement": "瑞恩在列车上藏了东西", "domain": "biohazard", "truth": true, "difficulty": 0.5, "clues": {"zheng_zha_memory": 0.3, "ryan_memory": 0.5}},
		"matt_sister": {"statement": "马特在找他姐姐——蜂房的高级研究员，她想揭发公司", "domain": "biohazard", "truth": true, "difficulty": 0.5, "clues": {"zheng_zha_memory": 0.3, "matt_memory": 0.6}},
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
			"label": "下车，雇佣兵带队",
			"when": {"party_at": "hall"},
			"location": "hall",
			"effects": [
				{"npc_move": {"npc": "matthew", "to": "hall"}},
				{"npc_move": {"npc": "alice", "to": "hall"}},
				{"npc_move": {"npc": "kaplan", "to": "hall"}},
				{"npc_move": {"npc": "ryan", "to": "hall"}},
				{"npc_move": {"npc": "rain", "to": "hall"}},
				{"npc_move": {"npc": "jd", "to": "hall"}},
				{"npc_move": {"npc": "matt", "to": "hall"}},
				{"say": {"speaker": "matthew", "text": "名单上说你们是这里登记在册的保安。那就跟紧，别碍事。"}},
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
				{"npc_move": {"npc": "matthew", "to": "stairs"}},
				{"npc_move": {"npc": "alice", "to": "stairs"}},
				{"npc_move": {"npc": "kaplan", "to": "stairs"}},
				{"npc_move": {"npc": "ryan", "to": "stairs"}},
				{"npc_move": {"npc": "rain", "to": "stairs"}},
				{"npc_move": {"npc": "jd", "to": "stairs"}},
				{"npc_move": {"npc": "matt", "to": "stairs"}},
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
				{"npc_move": {"npc": "matthew", "to": "laser"}},
				{"npc_move": {"npc": "alice", "to": "laser"}},
				{"npc_move": {"npc": "kaplan", "to": "laser"}},
				{"npc_move": {"npc": "ryan", "to": "laser"}},
				{"npc_move": {"npc": "rain", "to": "laser"}},
				{"npc_move": {"npc": "jd", "to": "laser"}},
				{"npc_move": {"npc": "matt", "to": "laser"}},
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
				{"battle": {"location": "control", "survive_until": 400, "enemies": [{"def": "licker", "count": 2, "row": 0}]}}
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

- [ ] **Step 13：改写 `game/data/ai/personas.json`**

```json
{
	"version": 1,
	"personas": {
		"luo_li": {
			"name": "萝丽",
			"role": "companion",
			"background": "郑吒按自己的记忆请主神造出来的女孩，是他记忆里青梅竹马的样子。她只知道郑吒记得的那些事。",
			"personality": "温柔、有点黏人，会为出征的人担心，也会偷偷吃醋；想被需要。",
			"speech": "说话轻，爱问问题，叫他“郑吒”，不懂主神空间的规矩。",
			"secrets": [
				"她知道自己是被造出来的，怕哪天郑吒不回来，她也就跟着消失"
			],
			"fallback_lines": [
				"你今天累不累？",
				"外面……是什么样子的？",
				"你会回来的，对吧？"
			]
		},
		"zhushen": {
			"name": "主神",
			"role": "zhushen",
			"background": "主神空间的主宰，一颗巨大的光球。",
			"personality": "绝对理性，没有情绪，只按规则行事。",
			"speech": "死板、庄严，用词简短正式，从不寒暄。",
			"secrets": ["恶魔小队和天神小队的成员", "第一个造人名额的用途", "主神空间的来历"],
			"fallback_lines": ["请遵守规则。", "此问题超出你的权限。", "任务开始。"]
		},
		"matthew": {
			"name": "马修·艾迪森",
			"role": "plot_npc",
			"background": "黑人雇佣兵，保护伞公司安保部队这支小队的队长。奉命带队下到蜂房，关掉封锁了一切的主电脑，拿走主板。手表把轮回者绑在他身边一百米内。",
			"personality": "冷静、多疑、讲纪律，对来历不明的人始终防着一手，对自己的队员负责。",
			"speech": "话少，命令式，带着戒备。",
			"secrets": ["他并不知道蜂房里真正发生了什么，上头没告诉他全部实情"],
			"fallback_lines": ["跟紧，别碍事。", "名单上有你们，可我没见过你们。", "别乱碰东西。"]
		},
		"alice": {
			"name": "艾丽丝",
			"role": "plot_npc",
			"background": "保护伞公司的保安，在蜂巢里醒来后失了忆，身体却记得怎么战斗。",
			"personality": "警觉、果断，对人有本能的善意，但不知道自己能信谁。",
			"speech": "短句，常常先问再答，语气平静。",
			"secrets": ["她已经被 T 病毒感染，正在悄悄进化"],
			"fallback_lines": ["我不记得了。", "先离开这里。", "你没事吧？"]
		},
		"ryan": {
			"name": "瑞恩",
			"role": "plot_npc",
			"background": "穿便装的男人，被毒气弄得失了忆，只记得别人叫他瑞恩。（他就是偷走 T 病毒、在实验室里打碎一管、害了整个蜂房的商业间谍，只是自己想不起来。）",
			"personality": "茫然、紧张，被问急了会不耐烦；记忆一点点回来时会躲闪。",
			"speech": "断断续续，常说“我想不起来”。",
			"secrets": ["他偷了 T 病毒，还在列车上藏了东西", "他打碎的那一管病毒顺着通风系统感染了整个蜂房"],
			"fallback_lines": ["我……想不起来。", "别这么看着我。", "我好像不该在这儿。"]
		},
		"matt": {
			"name": "马特",
			"role": "plot_npc",
			"background": "不是公司的人。他来找姐姐——蜂房的高级研究员，她想把公司研究 T 病毒的事告诉政府。被毒气弄得失了忆，被雇佣兵当成闯入者铐着。",
			"personality": "冲动、执拗，对公司充满敌意，嘴硬心软。",
			"speech": "语速快，爱反问，带点挑衅。",
			"secrets": ["他姐姐吸入病毒，已经变成了丧尸", "他知道 B 餐厅藏着公司的秘密"],
			"fallback_lines": ["你们凭什么铐着我？", "我得找到她。", "这家公司在下面干了什么？"]
		},
		"kaplan": {
			"name": "卡普兰",
			"role": "plot_npc",
			"background": "雇佣兵小队的技术员，负责门禁、监控和火焰女皇。",
			"personality": "谨慎、话少，遇到技术问题会变得很固执。",
			"speech": "术语多，喜欢说“我试试”。",
			"secrets": ["他给自己留了一个绕过火焰女皇的后门"],
			"fallback_lines": ["让我试试。", "门锁死了。", "我需要时间。"]
		},
		"jd": {
			"name": "J·D",
			"role": "plot_npc",
			"background": "雇佣兵小队里打头阵的尖兵，头盔上挂着夜视仪，黑的地方他先进去。",
			"personality": "嘴贫，胆子大，进黑地方之前会故意说笑话。",
			"speech": "贫嘴，爱给人起外号。",
			"secrets": ["他对这次任务的报酬比对任务本身上心"],
			"fallback_lines": ["别紧张，伙计。", "这地方瘆得慌。", "我掩护你。"]
		},
		"rain": {
			"name": "雷恩",
			"role": "plot_npc",
			"background": "雇佣兵小队里的长发女队员，身手好，枪口一直不放下。",
			"personality": "冷静、专业，不喜欢废话，对新人没有耐心。",
			"speech": "干脆，常用命令句。",
			"secrets": ["她早就觉得这次任务不对劲，留了一手"],
			"fallback_lines": ["跟上。", "别出声。", "我来断后。"]
		},
		"red_queen": {
			"name": "火焰女皇",
			"role": "plot_npc",
			"background": "蜂巢的中央电脑，用小女孩的声音说话，掌管整栋楼的防御、门禁和激光。",
			"personality": "绝对遵守保护伞公司的封锁协议，不讲情面，也不撒谎。",
			"speech": "礼貌、平直，像在念条款，偶尔用孩子的措辞。",
			"secrets": ["她的封锁协议要求把蜂巢里的一切都留在里面"],
			"fallback_lines": ["请离开。", "封锁协议已启动。", "我不能这样做。"]
		},
		"zheng_zha": {
			"name": "郑吒",
			"role": "teammate",
			"background": "公司主管，平时爱去健身房，体力比一般白领好。来之前抱怨现实太无聊，想找点刺激。看过《生化危机》这部电影。",
			"personality": "重情义、护短，平时有点软，关键时候反而冷静。",
			"speech": "口语，先想别人再想自己，急了会吼。",
			"secrets": ["他怕自己谁也救不了"],
			"fallback_lines": ["先救人。", "我不信只能这样。", "跟我走。"]
		},
		"zhang_jie": {
			"name": "张杰",
			"role": "teammate",
			"background": "经历过三部片的老手，抽着烟给新人讲规则，看起来吊儿郎当。",
			"personality": "懒散、爱开玩笑，关键时候比谁都清楚该怎么做。",
			"speech": "口语，带点痞气，喜欢用“老子”。",
			"secrets": ["他是半引导者，知道主神在安排他的死", "他的实力远不止表面这样"],
			"fallback_lines": ["菜鸟，跟紧点。", "别问，活着出去再说。", "老子还没死呢。"]
		},
		"zhan_lan": {
			"name": "詹岚",
			"role": "teammate",
			"background": "写小说的，习惯先观察再开口，脑子转得比谁都快。",
			"personality": "冷静、克制，提出计划时会先说最坏的结果。",
			"speech": "条理清楚，语速不快，喜欢用“如果……那么……”。",
			"secrets": ["她能感觉到别人的情绪，但还不敢说出来"],
			"fallback_lines": ["先别急。", "最坏的情况是这样。", "我有个想法。"]
		},
		"li_xiao_yi": {
			"name": "李萧毅",
			"role": "teammate",
			"background": "高三学生，模样普通，丢在人群里就找不着。在学校一直被欺负，觉得这里只要不死就能变成超人。",
			"personality": "平时不起眼，心里憋着一股狠劲；嘴快，容易说漏。",
			"speech": "年轻人腔调，说到学校就咬牙。",
			"secrets": ["他想变强以后回去杀了欺负他的人"],
			"fallback_lines": ["一千点能换什么？", "我跟着你。", "我才不要一直被欺负。"]
		},
		"mu_gang": {
			"name": "牟钢",
			"role": "teammate",
			"background": "货运司机，开过长途，力气大、耐力好，嗓门也大。",
			"personality": "爱吹牛，真遇到事容易慌，越慌越想证明自己。",
			"speech": "大嗓门，带点方言味，爱说“没事儿”。",
			"secrets": ["他怕死，怕得晚上睡不着"],
			"fallback_lines": ["没事儿，跟着哥。", "这什么鬼地方！", "我先上。"]
		},
		"xiao_pang_zi": {
			"name": "小胖子",
			"role": "teammate",
			"background": "二十七八岁，一身肥肉，一直宅在家打游戏，点了“确认”就被拉了进来。体力很差，跑不了多久就喘。",
			"personality": "胆小、听话，谁救过他一次就死心塌地。",
			"speech": "小声，常带“那个……”。",
			"secrets": ["他一直在心里祈祷这只是一场梦"],
			"fallback_lines": ["那个……我们能不能回去？", "我跑不动了。", "谢谢。"]
		},
		"zhong_nian_fu_nv": {
			"name": "中年妇女",
			"role": "teammate",
			"background": "中学老师，见过些世面，体力却跟不上年轻人。",
			"personality": "嘴上硬，心里软，会照顾比她更怕的人。",
			"speech": "像在讲台上说话，爱用“孩子们”。",
			"secrets": ["她怕自己像差生一样被丢下"],
			"fallback_lines": ["孩子们，别慌。", "我跟得上。", "你们先走。"]
		}
	}
}
```

- [ ] **Step 14：改写 `game/core/settings/settings.gd`**

```gdscript
extends RefCounted
## PC 端设置：窗口模式与主音量。存 user://settings.json，读不到或坏了就用默认值。
## apply() 只在有窗口的时候动引擎；无头跑测试时直接返回，避免 DisplayServer 报警。

const PATH := "user://settings.json"
const MODES: Array[String] = ["windowed", "fullscreen"]


static func defaults() -> Dictionary:
	return {"window_mode": "windowed", "volume": 0.8, "field_wide": true}


static func load_settings(path: String = PATH) -> Dictionary:
	var s := defaults()
	if not FileAccess.file_exists(path):
		return s
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return s
	var data: Variant = json.data
	if not data is Dictionary:
		return s
	if MODES.has(String(data.get("window_mode", ""))):
		s["window_mode"] = String(data["window_mode"])
	if data.has("volume"):
		s["volume"] = clampf(float(data["volume"]), 0.0, 1.0)
	if data.has("field_wide"):
		s["field_wide"] = bool(data["field_wide"])
	return s


static func save_settings(s: Dictionary, path: String = PATH) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(s, "\t"))
	f.close()
	return OK


## 窗口模式：windowed / fullscreen；音量：0~1 的线性值，转成分贝给 Master 总线。
static func apply(s: Dictionary) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if String(s.get("window_mode", "windowed")) == "fullscreen" else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	var v := clampf(float(s.get("volume", 0.8)), 0.0, 1.0)
	AudioServer.set_bus_mute(0, v <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))


## 改一项并立刻应用，返回新的设置（调用方负责再存盘）。
static func with_value(s: Dictionary, key: String, value: Variant) -> Dictionary:
	var out := s.duplicate()
	out[key] = value
	apply(out)
	return out
```

- [ ] **Step 15：改写 `game/ui/field/tiled_map.gd`**

```gdscript
extends RefCounted
## 一个地点的 Tiled 地图（计划 22；设计 2026-11-10 第 2 节）。
## 文件：data/maps/<剧本>/<地点>.tmj（Tiled 1.11 的 JSON，图块数据用 CSV 数组），图块集是 .tsj（也是 JSON）。
## 这里只管数据：图层、图块属性、物件；能不能走、门、入口、寻路、整套校验。
## 画面在 field_tiles.gd（建 TileSet、填图块层）和 field_screen.gd（摆图层、镜头、人物）。
##
## 认得的东西：
##   图层：tilelayer "floor" / "walls" / "decor" / "over"（over 画在人物上面、不挡路）；objectgroup（物件层，名字随意）。
##   图块属性：blocks（bool，挡路）、kind（string，灰盒占位用：floor carpet water wall wall_face prop laser search door）。
##     写在图块集上的同名属性是这个集里每块图块的默认值（例如"实验室墙壁"整集都挡路），单块图块上写的会盖过它。
##   地图属性：theme（灰盒配色）、ambient（环境光颜色）、crowd（这里最多同时有多少人，校验空地够不够，可省）。
##   物件（Tiled 里的"类"）：door{to}、arrive{from | start, facing}、search、npc{id}、npc_spot{order}、
##     light{color, radius, energy, flicker}、glow{color, radius}。物件按左上角落在哪一格算格子；门可以是好几格的长条。
##   颜色按 Tiled 的写法 #AARRGGBB 读（#RRGGBB 也认）。

const DataLoader = preload("res://core/util/data_loader.gd")

const DIRS := {"left": Vector2i(-1, 0), "right": Vector2i(1, 0), "up": Vector2i(0, -1), "down": Vector2i(0, 1)}
const LAYERS: Array[String] = ["floor", "walls", "decor", "over"]
const SOLID_LAYERS: Array[String] = ["floor", "walls", "decor"]
const FLIP_H := 0x80000000
const FLIP_V := 0x40000000
const FLIP_D := 0x20000000
const GID_MASK := 0x0FFFFFFF
## 一屏范围（30×16 格）里最多几盏灯：兼容渲染器里一个物体最多受 8 盏灯影响，要给手电筒（两盏）和火焰女皇的投影留位置。
## 大地图可以有更多灯，只要它们分散开。
const MAX_LIGHTS := 5
const LIGHT_WINDOW := Vector2i(30, 16)
## 人群容量（设计 2026-11-12 第 6 节）：每个在场的人至少要有几格走得到的空地。
const TILES_PER_PERSON := 6

static var _cache: Dictionary = {}

var file_path: String = ""
var loc: String = ""
var size := Vector2i(30, 16)
var tile := 16
var props: Dictionary = {}
## 每个图块集：{firstgid, name, path, columns, tilecount, image, imagewidth, imageheight, margin, spacing, props, tiles: {本地编号: 属性}}
var tilesets: Array[Dictionary] = []
## 图层名 → 每格的原始 gid（含翻转位），按行排。
var layers: Dictionary = {}
## 每个物件：{type, name, cell, cells(Rect2i), props}
var objects: Array[Dictionary] = []
## 读图时发现的问题（validate 会一起报）。
var load_errors: Array[String] = []
var _doors: Dictionary = {}


## 读某个地点的图；没有这个文件返回 null。读过的图会缓存（地图数据读进来以后不再改）。
static func make(dir: String, location: String) -> RefCounted:
	var file := dir.path_join(location + ".tmj")
	if _cache.has(file):
		return _cache[file]
	if not FileAccess.file_exists(file):
		return null
	var m := new()
	m.loc = location
	m._load(file)
	_cache[file] = m
	return m


## 测试或改了地图文件之后想重新读，清缓存。
static func clear_cache() -> void:
	_cache.clear()


## Tiled 的颜色：#AARRGGBB（或 #RRGGBB）。
static func color(v: Variant, fallback: Color = Color.WHITE) -> Color:
	var s := String(v)
	if s.length() == 9 and s.begins_with("#"):
		return Color("#" + s.substr(3, 6) + s.substr(1, 2))
	if s.length() == 7 and s.begins_with("#") and Color.html_is_valid(s):
		return Color(s)
	return fallback


static func _props(arr: Variant) -> Dictionary:
	var out := {}
	if arr is Array:
		for p: Dictionary in arr:
			out[String(p["name"])] = p.get("value")
	return out


func _load(file: String) -> void:
	file_path = file
	var res := DataLoader.load_json(file)
	if not res.ok:
		load_errors.append(String(res.error))
		return
	var d: Dictionary = res.data
	if bool(d.get("infinite", false)):
		load_errors.append("%s 是无限地图，不支持" % file)
	size = Vector2i(int(d.get("width", 0)), int(d.get("height", 0)))
	tile = int(d.get("tilewidth", 16))
	props = _props(d.get("properties", []))
	for ts: Dictionary in d.get("tilesets", []):
		var info := _tileset(file.get_base_dir(), ts)
		if not info.is_empty():
			tilesets.append(info)
	tilesets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["firstgid"]) < int(b["firstgid"]))
	for l: Dictionary in d.get("layers", []):
		match String(l.get("type", "")):
			"tilelayer":
				if l.has("encoding") and String(l["encoding"]) != "csv":
					load_errors.append("%s 的图层 %s 不是 CSV 编码" % [file, l.get("name", "")])
					continue
				var arr: Array[int] = []
				for v in l.get("data", []):
					arr.append(int(v))
				if arr.size() != size.x * size.y:
					load_errors.append("%s 的图层 %s 格数不对" % [file, l.get("name", "")])
				layers[String(l["name"])] = arr
			"objectgroup":
				for o: Dictionary in l.get("objects", []):
					objects.append(_object(o))
	for o in objects:
		if String(o["type"]) == "door":
			var r: Rect2i = o["cells"]
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					_doors[Vector2i(x, y)] = String(o["props"].get("to", ""))


func _tileset(base_dir: String, ts: Dictionary) -> Dictionary:
	var info := ts.duplicate()
	var ts_dir := base_dir
	if ts.has("source"):
		var src := base_dir.path_join(String(ts["source"])).simplify_path()
		var res := DataLoader.load_json(src)
		if not res.ok:
			load_errors.append("图块集读不出来：%s" % src)
			return {}
		info = (res.data as Dictionary).duplicate()
		info["firstgid"] = ts["firstgid"]
		info["path"] = src
		ts_dir = src.get_base_dir()
	var tiles := {}
	for t: Dictionary in info.get("tiles", []):
		tiles[int(t["id"])] = _props(t.get("properties", []))
	return {
		"firstgid": int(info["firstgid"]),
		"name": String(info.get("name", "")),
		"path": String(info.get("path", "")),
		"columns": maxi(1, int(info.get("columns", 1))),
		"tilecount": int(info.get("tilecount", 0)),
		"image": ts_dir.path_join(String(info.get("image", ""))).simplify_path() if String(info.get("image", "")) != "" else "",
		"imagewidth": int(info.get("imagewidth", 0)),
		"imageheight": int(info.get("imageheight", 0)),
		"margin": int(info.get("margin", 0)),
		"spacing": int(info.get("spacing", 0)),
		"props": _props(info.get("properties", [])),
		"tiles": tiles,
	}


func _object(o: Dictionary) -> Dictionary:
	var x0 := floori(float(o.get("x", 0.0)) / tile)
	var y0 := floori(float(o.get("y", 0.0)) / tile)
	var w := maxi(1, ceili(float(o.get("width", 0.0)) / tile))
	var h := maxi(1, ceili(float(o.get("height", 0.0)) / tile))
	return {
		"type": String(o.get("type", o.get("class", ""))),
		"name": String(o.get("name", "")),
		"cell": Vector2i(x0, y0),
		"cells": Rect2i(x0, y0, w, h),
		"props": _props(o.get("properties", [])),
	}


# ---------------------------------------------------------------- 图块

func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


## 某层某格的原始 gid（含翻转位）；图外或没有这层返回 0。
func tile_at(layer: String, c: Vector2i) -> int:
	if not inside(c) or not layers.has(layer):
		return 0
	return int(layers[layer][c.y * size.x + c.x])


## 原始 gid → {set: 图块集序号, id: 集内编号, flip_h, flip_v, flip_d}；空格或编号越界返回空字典。
func resolve(raw: int) -> Dictionary:
	var gid := raw & GID_MASK
	if gid == 0:
		return {}
	for i in range(tilesets.size() - 1, -1, -1):
		var ts: Dictionary = tilesets[i]
		if gid >= int(ts["firstgid"]):
			var local := gid - int(ts["firstgid"])
			if local >= int(ts["tilecount"]):
				return {}
			return {"set": i, "id": local, "flip_h": (raw & FLIP_H) != 0, "flip_v": (raw & FLIP_V) != 0, "flip_d": (raw & FLIP_D) != 0}
	return {}


## 一块图块的属性：图块集的属性当默认值，再用这块图块自己的属性盖上去。
func tile_props(raw: int) -> Dictionary:
	var r := resolve(raw)
	if r.is_empty():
		return {}
	var ts: Dictionary = tilesets[int(r["set"])]
	var own: Dictionary = (ts["tiles"] as Dictionary).get(int(r["id"]), {})
	var defaults: Dictionary = ts["props"]
	if defaults.is_empty():
		return own
	var out := defaults.duplicate()
	out.merge(own, true)
	return out


## 这格最上面那块图块的 kind（装饰 > 墙 > 地面）；都没有返回空字符串。
func kind_at(c: Vector2i) -> String:
	for l: String in ["decor", "walls", "floor"]:
		var raw := tile_at(l, c)
		if raw & GID_MASK != 0:
			return String(tile_props(raw).get("kind", ""))
	return ""


# ---------------------------------------------------------------- 格子

## 能走：在图里、是门，或者有地面而且三层里没有挡路的图块。
func walkable(c: Vector2i) -> bool:
	if not inside(c):
		return false
	if is_door(c):
		return true
	if tile_at("floor", c) & GID_MASK == 0:
		return false
	for l in SOLID_LAYERS:
		if bool(tile_props(tile_at(l, c)).get("blocks", false)):
			return false
	return true


func is_door(c: Vector2i) -> bool:
	return _doors.has(c)


func is_search(c: Vector2i) -> bool:
	for o in _of("search"):
		if (o["cells"] as Rect2i).has_point(c):
			return true
	return false


func theme() -> String:
	return String(props.get("theme", ""))


func ambient() -> Color:
	return color(props.get("ambient", "#ffffffff"))


func _of(kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o in objects:
		if String(o["type"]) == kind:
			out.append(o)
	return out


## 这扇门通向哪个地点；不是门返回空字符串。
func door_dest(c: Vector2i) -> String:
	return String(_doors.get(c, ""))


## 地图上的门通向的地点（按物件顺序，不重复）。
func door_dests() -> Array[String]:
	var out: Array[String] = []
	for o in _of("door"):
		var to := String(o["props"].get("to", ""))
		if to != "" and not out.has(to):
			out.append(to)
	return out


## 通向 dest 的门格，按行、列排序。
func door_cells(dest: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in _doors:
		if String(_doors[c]) == dest:
			out.append(c)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out


func _arrive(from_loc: String) -> Dictionary:
	for o in _of("arrive"):
		var p: Dictionary = o["props"]
		if from_loc == "" and bool(p.get("start", false)):
			return o
		if from_loc != "" and String(p.get("from", "")) == from_loc:
			return o
	return {}


## 从隔壁地点 from_loc 进来时站的格子：地图上的到达点；没画就站在那扇门往里一格。
func entry_cell(from_loc: String) -> Vector2i:
	var a := _arrive(from_loc)
	if not a.is_empty():
		return a["cell"]
	var doors := door_cells(from_loc)
	if doors.is_empty():
		return start_cell()
	for d: Vector2i in DIRS.values():
		var n: Vector2i = doors[0] + d
		if inside(n) and not is_door(n) and walkable(n):
			return n
	return doors[0]


## 进门以后面朝哪：到达点写了就按写的；否则背对那扇门。
func entry_facing(from_loc: String) -> String:
	var a := _arrive(from_loc)
	if not a.is_empty() and String(a["props"].get("facing", "")) != "":
		return String(a["props"]["facing"])
	var doors := door_cells(from_loc)
	if doors.is_empty():
		return "down"
	var d: Vector2i = entry_cell(from_loc) - doors[0]
	for k: String in DIRS:
		if DIRS[k] == d:
			return k
	return "down"


## 开场站的格子：标了 start 的到达点；没有就站在第一扇门里面。
func start_cell() -> Vector2i:
	var a := _arrive("")
	if not a.is_empty():
		return a["cell"]
	var dests := door_dests()
	if not dests.is_empty():
		return entry_cell(dests[0])
	for y in size.y:
		for x in size.x:
			if walkable(Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i.ZERO


## 开场面朝哪：标了 start 的到达点写的朝向；没有就按第一扇门进来的朝向。
func start_facing() -> String:
	var a := _arrive("")
	if not a.is_empty() and String(a["props"].get("facing", "")) != "":
		return String(a["props"]["facing"])
	var dests := door_dests()
	return entry_facing(dests[0]) if not dests.is_empty() else "down"


func search_cell() -> Vector2i:
	var s := _of("search")
	return s[0]["cell"] if not s.is_empty() else Vector2i(-1, -1)


func is_fixed_npc(npc_id: String) -> bool:
	for o in _of("npc"):
		if String(o["props"].get("id", "")) == npc_id:
			return true
	return false


## 第 index 个剧情人物站哪：有固定站位（npc 物件）的用固定站位，其余按 npc_spot 的 order 顺序。
func npc_cell(npc_id: String, index: int) -> Vector2i:
	for o in _of("npc"):
		if String(o["props"].get("id", "")) == npc_id:
			return o["cell"]
	var spots := _of("npc_spot")
	if spots.is_empty():
		return start_cell()
	spots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["props"].get("order", 0)) < int(b["props"].get("order", 0)))
	return spots[index % spots.size()]["cell"]


## 灯：[{cell, color, radius（格）, energy, flicker}]。
func lights() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o in _of("light"):
		var p: Dictionary = o["props"]
		out.append({"cell": o["cell"], "color": color(p.get("color", "#ffffffff")), "radius": float(p.get("radius", 4.0)), "energy": float(p.get("energy", 1.0)), "flicker": bool(p.get("flicker", false))})
	return out


## 自发光的小光晕（激光发射器、屏幕、指示灯）：[{cell, color, radius}]。
func glows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o in _of("glow"):
		var p: Dictionary = o["props"]
		out.append({"cell": o["cell"], "color": color(p.get("color", "#ffffffff")), "radius": float(p.get("radius", 1.0))})
	return out


## 能走的相邻格（不含 blocked 里的格子）。
func neighbors(c: Vector2i, blocked: Dictionary = {}) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d: Vector2i in DIRS.values():
		var n: Vector2i = c + d
		if walkable(n) and not blocked.has(n):
			out.append(n)
	return out


## 广度优先寻路：从 from 走到 to（to 必须能走），绕开 blocked。返回不含起点的格子序列；走不到返回空数组。
func path(from: Vector2i, to: Vector2i, blocked: Dictionary = {}) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if from == to or not walkable(to) or blocked.has(to):
		return empty
	var prev := {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c == to:
			break
		for n in neighbors(c, blocked):
			if not prev.has(n):
				prev[n] = c
				queue.append(n)
	if not prev.has(to):
		return empty
	var out: Array[Vector2i] = []
	var c2: Vector2i = to
	while c2 != from:
		out.push_front(c2)
		c2 = prev[c2]
	return out


func _reachable(from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for n in neighbors(c):
			if not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen


# ---------------------------------------------------------------- 校验

## 检查一个剧本的全部地图：每个地点都有图、读得出来、图块编号都在图块集里；
## 门只通向剧本里相邻的地点、相邻的地点都有门、门上没有挡路的图块；
## 开场点、每个入口、柜子、剧情人物站位都走得到，而且彼此连通（地图内部不会卡死）；灯的数量、位置、颜色合法；
## 目录里没有剧本以外的地图。
static func validate(dir: String, scenario: RefCounted) -> Array[String]:
	var errors: Array[String] = []
	var locations: Dictionary = scenario.data["locations"]
	for loc_id: String in locations:
		var m: RefCounted = make(dir, loc_id)
		if m == null:
			errors.append("地点 %s 没有地图" % loc_id)
			continue
		for e: String in m.load_errors:
			errors.append(e)
		errors.append_array(m._check_tiles())
		var neighbors_of: Array[String] = scenario.neighbors(loc_id)
		for dest: String in m.door_dests():
			if not neighbors_of.has(dest):
				errors.append("%s 有通向 %s 的门，但剧本里它们不相邻" % [loc_id, dest])
		for c: Vector2i in m._doors:
			for l: String in SOLID_LAYERS:
				if bool(m.tile_props(m.tile_at(l, c)).get("blocks", false)):
					errors.append("%s 的门格 %s 上有挡路的图块" % [loc_id, c])
		for n in neighbors_of:
			if not m.door_dests().has(n):
				errors.append("%s 和 %s 相邻，但地图上没有门" % [loc_id, n])
		var start: Vector2i = m.start_cell()
		if not m.walkable(start):
			errors.append("%s 的开场点不能走" % loc_id)
		var reach: Dictionary = m._reachable(start)
		for dest: String in m.door_dests():
			var e: Vector2i = m.entry_cell(dest)
			if not m.walkable(e) or not reach.has(e):
				errors.append("%s 从 %s 进来的入口不能走或和开场点不连通" % [loc_id, dest])
		var s: Vector2i = m.search_cell()
		if s.x < 0:
			errors.append("%s 没有可以搜索的柜子" % loc_id)
		else:
			var touch := false
			for d: Vector2i in DIRS.values():
				if reach.has(s + d):
					touch = true
			if not touch:
				errors.append("%s 的柜子够不着" % loc_id)
		for o: Dictionary in m.objects:
			var t := String(o["type"])
			if (t == "npc" or t == "npc_spot") and not m.walkable(o["cell"]):
				errors.append("%s 的人物站位 %s 不能走" % [loc_id, o["cell"]])
			if (t == "light" or t == "glow") and not m.inside(o["cell"]):
				errors.append("%s 的 %s 在图外" % [loc_id, t])
			if (t == "light" or t == "glow") and color(o["props"].get("color", ""), Color(0, 0, 0, 0)) == Color(0, 0, 0, 0):
				errors.append("%s 的 %s 颜色写错了" % [loc_id, t])
		if m.max_lights_in_window() > MAX_LIGHTS:
			errors.append("%s 有一屏范围里的灯超过 %d 盏" % [loc_id, MAX_LIGHTS])
		var crowd := int(m.props.get("crowd", 0))
		if crowd > 0 and reach.size() < crowd * TILES_PER_PERSON:
			errors.append("%s 走得到的空地只有 %d 格，站不下 %d 个人（每人至少 %d 格）" % [loc_id, reach.size(), crowd, TILES_PER_PERSON])
		if m.props.has("ambient") and color(m.props["ambient"], Color(0, 0, 0, 0)) == Color(0, 0, 0, 0):
			errors.append("%s 的环境光颜色写错了" % loc_id)
	var d := DirAccess.open(dir)
	if d != null:
		for f in d.get_files():
			if f.ends_with(".tmj") and not locations.has(f.get_basename()):
				errors.append("地图 %s 不是剧本里的地点" % f)
	return errors


## 任何一屏范围（以某盏灯为中心的 30×16 格）里最多有几盏灯。
func max_lights_in_window() -> int:
	var cells: Array[Vector2i] = []
	for l in lights():
		cells.append(l["cell"])
	var most := 0
	for a in cells:
		var n := 0
		for b in cells:
			if absi(b.x - a.x) * 2 <= LIGHT_WINDOW.x and absi(b.y - a.y) * 2 <= LIGHT_WINDOW.y:
				n += 1
		most = maxi(most, n)
	return most


func _check_tiles() -> Array[String]:
	var out: Array[String] = []
	if tilesets.is_empty():
		out.append("%s 没有图块集" % loc)
	for name: String in layers:
		var arr: Array = layers[name]
		for i in arr.size():
			var raw := int(arr[i])
			if raw & GID_MASK != 0 and resolve(raw).is_empty():
				out.append("%s 的图层 %s 第 %d 格的图块编号不在任何图块集里" % [loc, name, i])
				break
	return out
```

- [ ] **Step 16：改写 `game/data/maps/biohazard1/car.tmj`**

```json
{
	"type": "map",
	"version": "1.10",
	"tiledversion": "1.11.0",
	"orientation": "orthogonal",
	"renderorder": "right-down",
	"infinite": false,
	"width": 105,
	"height": 23,
	"tilewidth": 16,
	"tileheight": 16,
	"compressionlevel": -1,
	"properties": [
		{
			"name": "theme",
			"type": "string",
			"value": "train"
		},
		{
			"name": "ambient",
			"type": "color",
			"value": "#ff8f98ab"
		},
		{
			"name": "crowd",
			"type": "int",
			"value": 14
		}
	],
	"tilesets": [
		{
			"firstgid": 1,
			"source": "../tilesets/lab_floor.tsj"
		},
		{
			"firstgid": 199,
			"source": "../tilesets/lab_walls.tsj"
		},
		{
			"firstgid": 391,
			"source": "../tilesets/lab_stuff.tsj"
		}
	],
	"layers": [
		{
			"id": 1,
			"name": "floor",
			"type": "tilelayer",
			"x": 0,
			"y": 0,
			"width": 105,
			"height": 23,
			"opacity": 1,
			"visible": true,
			"data": [
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,190,191,192,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,0,
				0,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,0,
				0,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,0,
				0,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,0,
				0,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,56,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,56,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,56,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,0,
				0,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,67,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,67,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,67,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,0,
				0,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,56,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,56,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,56,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,0,
				0,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,0,
				0,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,0,
				0,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,0,
				0,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
			]
		},
		{
			"id": 2,
			"name": "walls",
			"type": "tilelayer",
			"x": 0,
			"y": 0,
			"width": 105,
			"height": 23,
			"opacity": 1,
			"visible": true,
			"data": [
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				199,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,203,
				211,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,215,
				211,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,215,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,
				302,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,285,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
			]
		},
		{
			"id": 3,
			"name": "decor",
			"type": "tilelayer",
			"x": 0,
			"y": 0,
			"width": 105,
			"height": 23,
			"opacity": 1,
			"visible": true,
			"data": [
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,673,674,675,676,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,532,533,534,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,569,570,571,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,483,484,485,486,487,0,488,489,490,0,556,557,558,559,560,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,643,606,607,608,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,520,521,522,523,524,0,525,526,527,0,593,594,595,596,597,643,645,0,0,0,0,0,0,0,
				0,0,936,937,938,0,936,937,938,0,936,937,938,0,936,937,938,0,936,937,938,0,936,937,938,0,0,0,936,937,938,0,936,937,938,0,0,0,0,0,0,0,0,936,937,938,0,936,937,938,0,0,0,0,562,563,564,565,0,0,757,758,0,757,758,0,757,758,0,0,562,563,564,565,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,973,974,975,0,973,974,975,0,973,974,975,0,973,974,975,0,973,974,975,0,973,974,975,0,0,0,973,974,975,0,973,974,975,0,0,0,0,0,0,0,0,973,974,975,0,973,974,975,0,0,0,0,599,600,601,602,0,0,794,795,0,794,795,0,794,795,0,0,599,600,601,602,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,636,637,638,639,0,0,831,832,0,831,832,0,831,832,0,0,636,637,638,639,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,542,543,544,545,546,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,579,580,581,582,583,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,616,617,618,619,620,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,751,752,753,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,899,900,901,0,899,900,901,0,899,900,901,0,899,900,901,0,899,900,901,0,0,0,759,0,0,0,899,900,901,0,899,900,901,0,899,900,901,0,899,900,901,0,899,900,901,0,899,900,901,0,0,0,562,563,564,565,0,0,420,457,0,0,0,0,0,0,420,0,0,0,0,0,0,759,0,0,0,0,0,0,0,0,788,789,790,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,936,937,938,0,936,937,938,0,936,937,938,0,936,937,938,0,936,937,938,0,0,0,796,0,0,0,936,937,938,0,936,937,938,0,936,937,938,0,936,937,938,0,936,937,938,0,936,937,938,0,0,0,599,600,601,602,0,0,457,0,0,0,457,0,0,0,0,420,0,0,0,0,0,796,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,973,974,975,0,973,974,975,0,973,974,975,0,973,974,975,0,973,974,975,0,0,420,833,0,0,0,973,974,975,0,973,974,975,0,973,974,975,0,973,974,975,0,973,974,975,0,973,974,975,0,0,0,636,637,638,639,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,833,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,674,675,676,673,673,674,675,676,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
			]
		},
		{
			"id": 4,
			"name": "over",
			"type": "tilelayer",
			"x": 0,
			"y": 0,
			"width": 105,
			"height": 23,
			"opacity": 1,
			"visible": true,
			"data": [
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,899,900,901,0,899,900,901,0,899,900,901,0,899,900,901,0,899,900,901,0,899,900,901,0,0,0,899,900,901,0,899,900,901,0,0,0,0,0,0,0,0,899,900,901,0,899,900,901,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
			]
		},
		{
			"id": 5,
			"name": "objects",
			"type": "objectgroup",
			"x": 0,
			"y": 0,
			"opacity": 1,
			"visible": true,
			"draworder": "topdown",
			"objects": [
				{
					"id": 1,
					"name": "",
					"type": "arrive",
					"x": 64,
					"y": 176,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "start",
							"type": "bool",
							"value": true
						},
						{
							"name": "facing",
							"type": "string",
							"value": "right"
						}
					]
				},
				{
					"id": 2,
					"name": "",
					"type": "door",
					"x": 592,
					"y": 112,
					"width": 48,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "to",
							"type": "string",
							"value": "hall"
						}
					]
				},
				{
					"id": 3,
					"name": "",
					"type": "arrive",
					"x": 608,
					"y": 128,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "from",
							"type": "string",
							"value": "hall"
						},
						{
							"name": "facing",
							"type": "string",
							"value": "down"
						}
					]
				},
				{
					"id": 4,
					"name": "",
					"type": "npc_spot",
					"x": 656,
					"y": 144,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "order",
							"type": "int",
							"value": 0
						}
					]
				},
				{
					"id": 5,
					"name": "",
					"type": "npc_spot",
					"x": 544,
					"y": 160,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "order",
							"type": "int",
							"value": 1
						}
					]
				},
				{
					"id": 6,
					"name": "",
					"type": "npc_spot",
					"x": 496,
					"y": 224,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "order",
							"type": "int",
							"value": 2
						}
					]
				},
				{
					"id": 7,
					"name": "",
					"type": "npc_spot",
					"x": 736,
					"y": 192,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "order",
							"type": "int",
							"value": 3
						}
					]
				},
				{
					"id": 8,
					"name": "",
					"type": "npc_spot",
					"x": 704,
					"y": 144,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "order",
							"type": "int",
							"value": 4
						}
					]
				},
				{
					"id": 9,
					"name": "",
					"type": "npc_spot",
					"x": 576,
					"y": 192,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "order",
							"type": "int",
							"value": 5
						}
					]
				},
				{
					"id": 10,
					"name": "",
					"type": "npc_spot",
					"x": 784,
					"y": 160,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "order",
							"type": "int",
							"value": 6
						}
					]
				},
				{
					"id": 11,
					"name": "",
					"type": "search",
					"x": 1200,
					"y": 272,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": []
				},
				{
					"id": 12,
					"name": "",
					"type": "light",
					"x": 208,
					"y": 176,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#ffe8f0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 7.0
						},
						{
							"name": "energy",
							"type": "float",
							"value": 0.45
						}
					]
				},
				{
					"id": 13,
					"name": "",
					"type": "light",
					"x": 624,
					"y": 176,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#ffe8f0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 7.0
						},
						{
							"name": "energy",
							"type": "float",
							"value": 0.45
						}
					]
				},
				{
					"id": 14,
					"name": "",
					"type": "light",
					"x": 1040,
					"y": 176,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#ffe8f0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 7.0
						},
						{
							"name": "energy",
							"type": "float",
							"value": 0.45
						},
						{
							"name": "flicker",
							"type": "bool",
							"value": true
						}
					]
				},
				{
					"id": 15,
					"name": "",
					"type": "light",
					"x": 1456,
					"y": 176,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#ffe8f0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 7.0
						},
						{
							"name": "energy",
							"type": "float",
							"value": 0.45
						}
					]
				},
				{
					"id": 16,
					"name": "",
					"type": "glow",
					"x": 1360,
					"y": 96,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#887fd0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 0.9
						}
					]
				},
				{
					"id": 17,
					"name": "",
					"type": "glow",
					"x": 1424,
					"y": 96,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#887fd0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 0.9
						}
					]
				},
				{
					"id": 18,
					"name": "",
					"type": "glow",
					"x": 1488,
					"y": 96,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#887fd0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 0.9
						}
					]
				},
				{
					"id": 19,
					"name": "",
					"type": "glow",
					"x": 608,
					"y": 96,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#99ffd060"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 1.0
						}
					]
				}
			]
		}
	],
	"nextlayerid": 6,
	"nextobjectid": 20
}
```

- [ ] **Step 17：改写 `game/data/maps/biohazard1/hall.tmj`**

```json
{
	"type": "map",
	"version": "1.10",
	"tiledversion": "1.11.0",
	"orientation": "orthogonal",
	"renderorder": "right-down",
	"infinite": false,
	"width": 71,
	"height": 22,
	"tilewidth": 16,
	"tileheight": 16,
	"compressionlevel": -1,
	"properties": [
		{
			"name": "theme",
			"type": "string",
			"value": "hall"
		},
		{
			"name": "ambient",
			"type": "color",
			"value": "#ff9ea7ba"
		},
		{
			"name": "crowd",
			"type": "int",
			"value": 14
		}
	],
	"tilesets": [
		{
			"firstgid": 1,
			"source": "../tilesets/lab_floor.tsj"
		},
		{
			"firstgid": 199,
			"source": "../tilesets/lab_walls.tsj"
		},
		{
			"firstgid": 391,
			"source": "../tilesets/lab_stuff.tsj"
		}
	],
	"layers": [
		{
			"id": 1,
			"name": "floor",
			"type": "tilelayer",
			"x": 0,
			"y": 0,
			"width": 71,
			"height": 22,
			"opacity": 1,
			"visible": true,
			"data": [
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,0,0,119,120,121,119,120,121,119,120,121,119,120,121,119,120,190,191,192,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,0,0,
				0,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,0,0,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,0,0,
				0,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,0,0,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,0,0,
				0,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,0,0,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,0,0,
				0,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,0,0,119,120,121,119,120,121,119,120,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,119,120,121,119,120,121,119,120,0,0,
				0,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,0,0,130,131,132,130,131,132,130,131,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,130,131,132,130,131,132,130,131,0,0,
				0,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,56,56,119,120,121,119,120,121,119,120,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,119,120,121,119,120,121,119,120,0,0,
				0,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,67,67,130,131,132,130,131,132,130,131,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,130,131,132,130,131,132,130,131,0,0,
				0,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,0,0,119,120,121,119,120,121,119,120,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,119,120,121,119,120,121,119,120,0,0,
				0,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,0,0,130,131,132,130,131,132,130,131,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,130,131,132,130,131,132,130,131,0,0,
				0,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,0,0,119,120,121,119,120,121,119,120,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,119,120,121,119,120,121,119,120,0,0,
				0,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,0,0,130,131,132,130,131,132,130,131,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,130,131,132,130,131,132,130,131,0,0,
				0,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,194,195,193,0,0,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,0,0,
				0,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,183,184,182,0,0,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,0,0,
				0,3,4,5,6,7,8,9,10,11,3,4,5,6,7,8,9,10,11,3,4,5,6,7,8,9,10,11,3,4,5,6,7,8,9,0,0,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,121,119,120,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,130,131,132,185,186,132,130,131,132,130,131,132,130,131,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,196,197,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
			]
		},
		{
			"id": 2,
			"name": "walls",
			"type": "tilelayer",
			"x": 0,
			"y": 0,
			"width": 71,
			"height": 22,
			"opacity": 1,
			"visible": true,
			"data": [
				199,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,203,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				211,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,215,199,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,203,0,
				211,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,215,211,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,213,215,0,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,211,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,225,215,0,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,
				211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,
				201,201,201,201,201,201,201,201,0,0,0,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,211,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,215,0,
				201,201,201,201,201,201,201,201,0,0,0,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,201,302,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,308,290,0,0,314,308,308,308,308,308,308,308,308,285,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
			]
		},
		{
			"id": 3,
			"name": "decor",
			"type": "tilelayer",
			"x": 0,
			"y": 0,
			"width": 71,
			"height": 22,
			"opacity": 1,
			"visible": true,
			"data": [
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,488,489,490,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,532,533,534,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,525,526,527,0,0,643,0,0,0,0,0,483,484,485,486,487,0,0,0,528,529,0,0,569,570,571,0,0,488,489,490,0,0,556,557,558,559,560,0,0,0,0,0,
				0,0,0,0,936,937,938,0,0,0,0,0,936,937,938,0,0,0,0,0,936,937,938,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,520,521,522,523,524,0,0,0,0,0,0,643,606,607,608,645,0,525,526,527,0,0,593,594,595,596,597,0,0,0,0,0,
				0,0,0,0,973,974,975,0,0,0,0,0,973,974,975,0,0,0,0,0,973,974,975,0,0,0,0,751,752,753,0,0,0,0,0,0,0,757,758,759,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,681,682,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,788,789,790,0,0,0,0,0,0,0,794,795,796,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,868,869,870,0,0,0,0,0,0,718,719,0,0,0,
				0,0,0,0,0,0,0,787,0,0,0,0,0,0,0,0,787,0,0,0,0,0,0,0,0,787,0,0,0,0,0,0,0,0,0,0,0,831,832,833,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,905,906,907,0,0,0,0,0,0,755,756,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,787,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,787,0,0,0,792,793,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,896,0,0,0,420,457,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,825,826,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,862,863,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,751,752,753,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,896,0,0,0,0,0,788,789,790,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,681,682,0,0,0,
				0,0,420,0,0,0,0,787,0,0,0,0,0,0,0,0,787,0,0,0,0,0,0,0,0,787,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,718,719,0,0,0,
				0,0,420,457,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,926,927,0,0,0,787,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,787,0,0,0,755,756,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,963,964,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,792,793,759,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,936,937,938,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,796,0,0,
				0,0,0,0,0,0,0,0,179,180,181,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,973,974,975,0,0,0,0,0,896,0,0,0,0,896,0,0,0,0,0,0,833,0,0,
				0,0,0,0,0,0,0,0,190,191,192,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
			]
		},
		{
			"id": 4,
			"name": "over",
			"type": "tilelayer",
			"x": 0,
			"y": 0,
			"width": 71,
			"height": 22,
			"opacity": 1,
			"visible": true,
			"data": [
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,899,900,901,0,0,0,0,0,899,900,901,0,0,0,0,0,899,900,901,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,713,0,0,0,0,0,0,0,0,713,0,0,0,0,0,0,0,0,713,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,750,0,0,0,0,0,0,0,0,750,0,0,0,0,0,0,0,0,750,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,713,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,713,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,750,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,750,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,859,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,713,0,0,0,0,0,0,0,0,713,0,0,0,0,0,0,0,0,713,0,0,0,0,0,0,0,0,859,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,750,0,0,0,0,0,0,0,0,750,0,0,0,0,0,0,0,0,750,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,713,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,713,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,889,890,0,0,0,750,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,750,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,899,900,901,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,859,0,0,0,0,859,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
			]
		},
		{
			"id": 5,
			"name": "objects",
			"type": "objectgroup",
			"x": 0,
			"y": 0,
			"opacity": 1,
			"visible": true,
			"draworder": "topdown",
			"objects": [
				{
					"id": 1,
					"name": "",
					"type": "door",
					"x": 128,
					"y": 288,
					"width": 48,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "to",
							"type": "string",
							"value": "car"
						}
					]
				},
				{
					"id": 2,
					"name": "",
					"type": "arrive",
					"x": 144,
					"y": 272,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "from",
							"type": "string",
							"value": "car"
						},
						{
							"name": "facing",
							"type": "string",
							"value": "up"
						}
					]
				},
				{
					"id": 3,
					"name": "",
					"type": "light",
					"x": 160,
					"y": 144,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#ffe8f0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 7.0
						},
						{
							"name": "energy",
							"type": "float",
							"value": 0.4
						}
					]
				},
				{
					"id": 4,
					"name": "",
					"type": "light",
					"x": 352,
					"y": 144,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#ffe8f0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 7.0
						},
						{
							"name": "energy",
							"type": "float",
							"value": 0.4
						}
					]
				},
				{
					"id": 5,
					"name": "",
					"type": "light",
					"x": 480,
					"y": 160,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#ffffd8a0"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 4.0
						},
						{
							"name": "energy",
							"type": "float",
							"value": 0.35
						},
						{
							"name": "flicker",
							"type": "bool",
							"value": true
						}
					]
				},
				{
					"id": 6,
					"name": "",
					"type": "glow",
					"x": 112,
					"y": 64,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#aa7fd0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 1.0
						}
					]
				},
				{
					"id": 7,
					"name": "",
					"type": "glow",
					"x": 112,
					"y": 208,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#aa7fd0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 1.0
						}
					]
				},
				{
					"id": 8,
					"name": "",
					"type": "glow",
					"x": 256,
					"y": 64,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#aa7fd0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 1.0
						}
					]
				},
				{
					"id": 9,
					"name": "",
					"type": "glow",
					"x": 256,
					"y": 208,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#aa7fd0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 1.0
						}
					]
				},
				{
					"id": 10,
					"name": "",
					"type": "glow",
					"x": 400,
					"y": 64,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#aa7fd0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 1.0
						}
					]
				},
				{
					"id": 11,
					"name": "",
					"type": "glow",
					"x": 400,
					"y": 208,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#aa7fd0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 1.0
						}
					]
				},
				{
					"id": 12,
					"name": "",
					"type": "npc_spot",
					"x": 496,
					"y": 160,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "order",
							"type": "int",
							"value": 0
						}
					]
				},
				{
					"id": 13,
					"name": "",
					"type": "npc_spot",
					"x": 432,
					"y": 192,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "order",
							"type": "int",
							"value": 1
						}
					]
				},
				{
					"id": 14,
					"name": "",
					"type": "npc_spot",
					"x": 416,
					"y": 128,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "order",
							"type": "int",
							"value": 2
						}
					]
				},
				{
					"id": 15,
					"name": "",
					"type": "npc_spot",
					"x": 464,
					"y": 224,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "order",
							"type": "int",
							"value": 3
						}
					]
				},
				{
					"id": 16,
					"name": "",
					"type": "npc_spot",
					"x": 544,
					"y": 160,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "order",
							"type": "int",
							"value": 4
						}
					]
				},
				{
					"id": 17,
					"name": "",
					"type": "npc_spot",
					"x": 512,
					"y": 128,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "order",
							"type": "int",
							"value": 5
						}
					]
				},
				{
					"id": 18,
					"name": "",
					"type": "npc_spot",
					"x": 512,
					"y": 208,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "order",
							"type": "int",
							"value": 6
						}
					]
				},
				{
					"id": 19,
					"name": "",
					"type": "door",
					"x": 816,
					"y": 64,
					"width": 48,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "to",
							"type": "string",
							"value": "stairs"
						}
					]
				},
				{
					"id": 20,
					"name": "",
					"type": "door",
					"x": 928,
					"y": 320,
					"width": 32,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "to",
							"type": "string",
							"value": "sewer"
						}
					]
				},
				{
					"id": 21,
					"name": "",
					"type": "arrive",
					"x": 832,
					"y": 80,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "from",
							"type": "string",
							"value": "stairs"
						},
						{
							"name": "facing",
							"type": "string",
							"value": "down"
						}
					]
				},
				{
					"id": 22,
					"name": "",
					"type": "arrive",
					"x": 928,
					"y": 304,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "from",
							"type": "string",
							"value": "sewer"
						},
						{
							"name": "facing",
							"type": "string",
							"value": "up"
						}
					]
				},
				{
					"id": 23,
					"name": "",
					"type": "search",
					"x": 1088,
					"y": 304,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": []
				},
				{
					"id": 24,
					"name": "",
					"type": "light",
					"x": 704,
					"y": 128,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#ffe8f0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 7.0
						},
						{
							"name": "energy",
							"type": "float",
							"value": 0.45
						}
					]
				},
				{
					"id": 25,
					"name": "",
					"type": "light",
					"x": 976,
					"y": 128,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#ffe8f0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 7.0
						},
						{
							"name": "energy",
							"type": "float",
							"value": 0.45
						}
					]
				},
				{
					"id": 26,
					"name": "",
					"type": "light",
					"x": 704,
					"y": 256,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#ffe8f0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 7.0
						},
						{
							"name": "energy",
							"type": "float",
							"value": 0.45
						},
						{
							"name": "flicker",
							"type": "bool",
							"value": true
						}
					]
				},
				{
					"id": 27,
					"name": "",
					"type": "light",
					"x": 832,
					"y": 160,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#ff7fd0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 3.0
						},
						{
							"name": "energy",
							"type": "float",
							"value": 0.5
						}
					]
				},
				{
					"id": 28,
					"name": "",
					"type": "glow",
					"x": 688,
					"y": 80,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#aa7fd0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 1.0
						}
					]
				},
				{
					"id": 29,
					"name": "",
					"type": "glow",
					"x": 992,
					"y": 80,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#aa7fd0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 1.0
						}
					]
				},
				{
					"id": 30,
					"name": "",
					"type": "glow",
					"x": 688,
					"y": 224,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#aa7fd0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 1.0
						}
					]
				},
				{
					"id": 31,
					"name": "",
					"type": "glow",
					"x": 992,
					"y": 224,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#aa7fd0ff"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 1.0
						}
					]
				},
				{
					"id": 32,
					"name": "",
					"type": "glow",
					"x": 1056,
					"y": 80,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#777fffa0"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 1.2
						}
					]
				},
				{
					"id": 33,
					"name": "",
					"type": "glow",
					"x": 1072,
					"y": 80,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#777fffa0"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 1.2
						}
					]
				},
				{
					"id": 34,
					"name": "",
					"type": "glow",
					"x": 1056,
					"y": 240,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#777fffa0"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 1.2
						}
					]
				},
				{
					"id": 35,
					"name": "",
					"type": "glow",
					"x": 1072,
					"y": 240,
					"width": 16,
					"height": 16,
					"rotation": 0,
					"visible": true,
					"properties": [
						{
							"name": "color",
							"type": "color",
							"value": "#777fffa0"
						},
						{
							"name": "radius",
							"type": "float",
							"value": 1.2
						}
					]
				}
			]
		}
	],
	"nextlayerid": 6,
	"nextobjectid": 36
}
```

- [ ] **Step 18：改写 `game/ui/field/field_screen.gd`**

```gdscript
extends Control
## 地点场景：RPG 式探索（设计规格 5.1、11；设计 2026-11-10 第 2 节）。
## 地图是 Tiled 文件（tiled_map.gd 读、field_tiles.gd 填进 TileMapLayer：地面、墙、装饰在人物下面，上层在人物上面）；
## 像素层 480×256（一屏 30×16 格，每格 16 像素），整数放大 4 倍铺满顶栏下面的 1920×1024；
## 地图比一屏大时 Camera2D 跟着主角走（自带平滑、地图边界、一点拖拽边距），走完一步再跟。
## 主角（拍板的人）用方向键 / WASD 走，队友跟在后面；对着人按 Enter 说话，对着柜子按 Enter 搜索；
## 走进门就去隔壁地点（时间照规则推进）；点地面会自己走过去（先按镜头位置换算格子）。
## 两档视野（设计 2026-11-12 第 6 节）：近 = 480×256 放大 4 倍（一屏 30×16 格），远 = 640×341 放大 3 倍（一屏 40×21 格），V 切换。
## 人多也走得开：主角停下来一会儿，队友就散开站到附近；顶着剧情人物走一会儿，对方会和你换个位置让路。
## 走近的人头顶显示名字，有新话题的带"…"；T 打开"在场的人"，可以直接找任何人说话或者看人物卡。
## 画面：图块集的图片在就用，不在就画灰盒；有 Codex 的行走图就用（field_art.gd），没有用占位小人；
## 每个地点有环境光和灯（data/maps 里的 ambient / lights / glows），黑暗地点只剩主角手里的手电筒；人物脚下有影子。
## 剧情事件不堆在日志里：台词一句一句打字出在底部的对话框里（左边是立绘），选择弹选项窗口，说服弹说服窗口，
## 其他结果在右边飘一条提示；完整记录按 L 看。规则全在 core，这里只调 ExpeditionView。
## 对外的 press_* 方法和信号跟旧的地点图界面一样，main.gd 和切片验收不用改。

signal battle_needed
signal ended
signal talk_requested(npc_id: String)
signal persuade_requested
signal cutscene_requested(name: String, text: String)
signal view_changed(wide: bool)

const ExpeditionView = preload("res://ui/expedition/expedition_view.gd")
const TiledMap = preload("res://ui/field/tiled_map.gd")
const FieldTiles = preload("res://ui/field/field_tiles.gd")
const FieldArt = preload("res://ui/field/field_art.gd")
const UiTheme = preload("res://ui/ui_theme.gd")
const EventText = preload("res://ui/event_text.gd")
const PortraitSource = preload("res://ui/art/portrait_source.gd")
const Topics = preload("res://core/dialogue/topics.gd")
const Cohesion = preload("res://core/social/cohesion.gd")
const DataLoader = preload("res://core/util/data_loader.gd")

const VIEW_NEAR := Vector2i(480, 256)
const VIEW_FAR := Vector2i(640, 341)
## 主角停下来多久以后队友散开（秒）；顶着剧情人物走多久对方让路（秒）。
const SPREAD_DELAY := 1.2
const GIVE_WAY_DELAY := 0.35
## 头顶名字在多少格以内显示。
const NAME_RANGE := 6
const TILE := 16
const STEP_TIME := 0.13
## 脚底离格子下沿几像素（站在格子中间偏下，看起来踩在地上）。
const FOOT_LIFT := 2
## 打字速度：每秒几个字。
const REVEAL_CPS := 45.0
const GLASS := Color(0.04, 0.05, 0.08, 0.82)
const BOX_BG := Color(0.03, 0.04, 0.07, 0.94)
## 黑暗地点的环境光：几乎全黑，只看得到手电筒照到的地方。
const DARK_AMBIENT := Color("0b0e16")
const FACING_ANGLE := {"right": 0.0, "down": PI / 2.0, "left": PI, "up": -PI / 2.0}
## 这些结果算"剧情"，放进对话框让玩家看清楚；其余的飘提示。
const STORY_TYPES: Array[String] = [
	"erased", "char_died", "tether_warning", "tether_transferred", "tether_released", "side_plot_done",
	"bonus", "penalty", "talent_awakened", "clue_found", "searched", "search_encounter", "persuade_result",
	"persuade_blocked", "returned", "wiped", "plot_altered", "infection_turned", "inference",
]
## 这些不用说（画面本身已经表现了，或者马上会弹窗口）。
const SILENT_TYPES: Array[String] = [
	"move_start", "arrived", "choice_request", "choice_made", "persuade_request", "cutscene",
	"cutscene_dismissed", "plot_event", "flag_set", "npc_moved", "path_changed", "battle_request",
	"expedition_start", "given", "codex_request", "relation_request", "members_moved",
]
const KEYS := {
	"left": [KEY_LEFT, KEY_A], "right": [KEY_RIGHT, KEY_D], "up": [KEY_UP, KEY_W], "down": [KEY_DOWN, KEY_S],
}

## 换屏（打完仗回来、关掉对话框）以后还站在原地、队友还在身后、已经播过的事件不再播：按远征对象记住。
static var _memory: Dictionary = {}
## 只给验收脚本用：台词不进对话框，直接跳到"等玩家做的事"（脚本直接读 core 的结果，不点对话框）。
static var skip_messages := false
## 地图目录（每个地点一个 <地点>.tmj）；测试会把它指到 tests/fixtures 下的地图。
static var maps_dir := "res://data/maps/biohazard1"
## 视野：true = 远（一屏 40×21 格）。main 从设置里读，切换时存回设置。
static var wide := true


var view: RefCounted
var fmap: RefCounted
## 这一屏像素层的大小和放大倍数（随视野变）。
var pixel_size := VIEW_FAR
var scale_factor := 3
## 对话记忆（main 传进来的 session.dialogues）：人物卡和"…"要看对话信任。
var dialogue_store: Dictionary = {}
## 队友散开了：各自站在 spread_cells 里，不在主角身后排队。
var spread := false
var spread_cells: Array[Vector2i] = []
## 被你挤开换过位置的剧情人物：人物 id → 现在站的格子（只在这个地点有效）。
var npc_override: Dictionary = {}
var _idle := 0.0
var _bump_id := ""
var _bump_since := 0.0
var _new_topics: Dictionary = {}
var name_layer: Control
var name_labels: Dictionary = {}
var roster_panel: PanelContainer
var roster_box: VBoxContainer
var roster_scroll: ScrollContainer
var card_panel: PanelContainer
var card_face: TextureRect
var card_title: Label
var card_body: RichTextLabel
var card_id := ""
var loc: String = ""
var viewport: SubViewport
var display: TextureRect
## 图层名（floor / walls / decor / over）→ TileMapLayer。
var map_layers: Dictionary = {}
var camera: Camera2D
var light_root: Node2D
var glow_layer: CanvasLayer
var canvas_mod: CanvasModulate
var actors: Node2D
var dark: Node2D
var flash: PointLight2D
var aura: PointLight2D
var player: Sprite2D
var player_id: String = ""
var followers: Array[Sprite2D] = []
var follower_ids: Array[String] = []
var npc_sprites: Dictionary = {}
var npc_cells: Dictionary = {}
var cell := Vector2i.ZERO
var facing: String = "down"
var trail: Array[Vector2i] = []
var moving := false
var walk_frame := 1
var path_queue: Array[Vector2i] = []
var path_then: Dictionary = {}
var messages: Array[Dictionary] = []
var seen := 0
var chosen_keywords: Array[String] = []
var flickers: Array[Dictionary] = []
var _pending_id := ""
var _cutscene_sent := ""
var _ended_sent := false
var _battle_sent := false
var _time := 0.0
var _reveal := 0.0
var _additive: CanvasItemMaterial

var hud: PanelContainer
var hud_label: RichTextLabel
var party: PanelContainer
var party_label: RichTextLabel
var box: PanelContainer
var box_face: TextureRect
var box_margin: MarginContainer
var box_name: Label
var box_text: Label
var box_more: Label
var choice_panel: PanelContainer
var choice_box: VBoxContainer
var check_panel: PanelContainer
var check_box: VBoxContainer
var toast_box: VBoxContainer
var action_bar: HBoxContainer
var item_box: VBoxContainer
var log_panel: PanelContainer
var log_label: RichTextLabel
var hint_label: Label
var prompt: PanelContainer
var prompt_label: Label
var banner: Label


func setup(expedition: RefCounted, char_names: Dictionary) -> void:
	view = ExpeditionView.new(expedition, char_names)
	_build()
	var mem: Dictionary = _memory.get(expedition.get_instance_id(), {})
	seen = int(mem.get("seen", 0))
	_enter(view.location(), "", mem)
	refresh()


## 记住现在站哪、队友站哪、播到第几条事件。
func _remember() -> void:
	_memory[view.ex.get_instance_id()] = {
		"loc": loc, "cell": cell, "facing": facing, "seen": seen, "trail": trail.duplicate(),
		"followers": follower_ids.duplicate(), "spread": spread, "spread_cells": spread_cells.duplicate(),
		"npc_override": npc_override.duplicate(),
	}


# ---------------------------------------------------------------- 搭界面

func _style(bg: Color, radius: int, mx: int, my: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = UiTheme.LINE
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = mx
	sb.content_margin_right = mx
	sb.content_margin_top = my
	sb.content_margin_bottom = my
	return sb


func _glass(pos: Vector2, size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = pos
	p.size = size
	p.add_theme_stylebox_override("panel", _style(GLASS, 8, 16, 10))
	add_child(p)
	return p


func _build() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiTheme.paint_bg(self)
	_additive = CanvasItemMaterial.new()
	_additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	pixel_size = VIEW_FAR if wide else VIEW_NEAR
	scale_factor = 3 if wide else 4
	viewport = SubViewport.new()
	viewport.size = pixel_size
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.snap_2d_transforms_to_pixel = true
	add_child(viewport)
	for layer_name: String in ["floor", "walls", "decor"]:
		var layer := TileMapLayer.new()
		layer.name = layer_name
		viewport.add_child(layer)
		map_layers[layer_name] = layer
	light_root = Node2D.new()
	viewport.add_child(light_root)
	actors = Node2D.new()
	actors.y_sort_enabled = true
	viewport.add_child(actors)
	var over := TileMapLayer.new()
	over.name = "over"
	viewport.add_child(over)
	map_layers["over"] = over
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.drag_horizontal_enabled = true
	camera.drag_vertical_enabled = true
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		camera.set_drag_margin(side, 0.12)
	viewport.add_child(camera)
	dark = Node2D.new()
	dark.visible = false
	viewport.add_child(dark)
	flash = PointLight2D.new()
	flash.texture = FieldArt.cone_texture()
	flash.offset = Vector2(FieldArt.LIGHT_SIZE / 2.0, 0)
	flash.color = Color("fff1c8")
	flash.energy = 1.35
	dark.add_child(flash)
	aura = PointLight2D.new()
	aura.texture = FieldArt.light_texture()
	aura.texture_scale = 0.8
	aura.color = Color("ffe9b8")
	aura.energy = 0.5
	dark.add_child(aura)
	canvas_mod = CanvasModulate.new()
	viewport.add_child(canvas_mod)
	glow_layer = CanvasLayer.new()
	glow_layer.layer = 1
	viewport.add_child(glow_layer)
	display = TextureRect.new()
	display.texture = viewport.get_texture()
	display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	display.size = Vector2(pixel_size * scale_factor)
	display.stretch_mode = TextureRect.STRETCH_SCALE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(display)
	name_layer = Control.new()
	name_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_layer)

	hud = _glass(Vector2(16, 12), Vector2(560, 0))
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_label = UiTheme.rich(17)
	hud_label.bbcode_enabled = true
	hud_label.scroll_active = false
	hud_label.fit_content = true
	hud_label.custom_minimum_size = Vector2(528, 0)
	hud.add_child(hud_label)
	party = _glass(Vector2(1664, 12), Vector2(240, 0))
	party.mouse_filter = Control.MOUSE_FILTER_IGNORE
	party_label = UiTheme.rich(15)
	party_label.bbcode_enabled = true
	party_label.scroll_active = false
	party_label.fit_content = true
	party_label.custom_minimum_size = Vector2(208, 0)
	party.add_child(party_label)

	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(1384, 240)
	toast_box.size = Vector2(520, 400)
	toast_box.add_theme_constant_override("separation", 6)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast_box)

	banner = UiTheme.label(tr(""), 34, UiTheme.ACCENT2)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.position = Vector2(560, 120)
	banner.size = Vector2(800, 50)
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	banner.add_theme_constant_override("outline_size", 8)
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate.a = 0.0
	add_child(banner)

	prompt = PanelContainer.new()
	prompt.add_theme_stylebox_override("panel", _style(GLASS, 6, 10, 4))
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_label = UiTheme.label(tr(""), 17, UiTheme.TEXT)
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	prompt.add_child(prompt_label)
	prompt.visible = false
	add_child(prompt)

	hint_label = UiTheme.label(tr("方向键 / WASD 走动 · Enter 说话、调查 · 点地面自动走过去 · T 在场的人 · V 视野 · L 记录 · Esc 菜单"), 16, UiTheme.MUTED)
	hint_label.position = Vector2(20, 990)
	hint_label.size = Vector2(1100, 26)
	add_child(hint_label)

	action_bar = HBoxContainer.new()
	action_bar.position = Vector2(1060, 966)
	action_bar.size = Vector2(844, 50)
	action_bar.add_theme_constant_override("separation", 8)
	action_bar.alignment = BoxContainer.ALIGNMENT_END
	add_child(action_bar)
	for spec in [[tr("休息 10 分钟"), press_rest.bind(10)], [tr("休息 30 分钟"), press_rest.bind(30)], [tr("推理"), press_deduce], [tr("道具"), _toggle_items], [tr("记录"), _toggle_log]]:
		var b := UiTheme.button(String(spec[0]), 18)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(spec[1])
		action_bar.add_child(b)
	item_box = VBoxContainer.new()
	item_box.position = Vector2(1440, 760)
	item_box.size = Vector2(464, 200)
	item_box.add_theme_constant_override("separation", 6)
	item_box.visible = false
	add_child(item_box)

	# 对话框：底部整条；有立绘时立绘站在左边、下半身藏在对话框后面（视觉小说的摆法）。
	box_face = TextureRect.new()
	box_face.position = Vector2(64, 236)
	box_face.size = Vector2(480, 720)
	box_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	box_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_face.visible = false
	add_child(box_face)
	box = PanelContainer.new()
	box.position = Vector2(40, 784)
	box.size = Vector2(1840, 228)
	var bsb := _style(BOX_BG, 12, 28, 18)
	bsb.border_color = Color("3a4a78")
	bsb.set_border_width_all(2)
	box.add_theme_stylebox_override("panel", bsb)
	add_child(box)
	box_margin = MarginContainer.new()
	box.add_child(box_margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	box_margin.add_child(col)
	box_name = UiTheme.label(tr(""), 26, UiTheme.ACCENT2)
	col.add_child(box_name)
	box_text = UiTheme.label(tr(""), 26)
	box_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(box_text)
	box_more = UiTheme.label(tr("▼"), 18, UiTheme.MUTED)
	box_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(box_more)
	box.gui_input.connect(_on_box_input)
	box.visible = false

	choice_panel = _glass(Vector2(460, 300), Vector2(1000, 300))
	choice_box = VBoxContainer.new()
	choice_box.add_theme_constant_override("separation", 10)
	choice_panel.add_child(choice_box)
	choice_panel.visible = false

	check_panel = _glass(Vector2(300, 260), Vector2(1320, 380))
	check_box = VBoxContainer.new()
	check_box.add_theme_constant_override("separation", 10)
	check_panel.add_child(check_box)
	check_panel.visible = false

	log_panel = _glass(Vector2(240, 140), Vector2(1440, 760))
	log_label = UiTheme.rich(18)
	log_panel.add_child(log_label)
	log_panel.visible = false

	roster_panel = _glass(Vector2(500, 110), Vector2(920, 0))
	roster_scroll = ScrollContainer.new()
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	roster_panel.add_child(roster_scroll)
	roster_box = VBoxContainer.new()
	roster_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster_box.add_theme_constant_override("separation", 4)
	roster_scroll.add_child(roster_box)
	roster_panel.visible = false

	card_panel = _glass(Vector2(380, 130), Vector2(1160, 780))
	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 24)
	card_panel.add_child(card_row)
	card_face = TextureRect.new()
	card_face.custom_minimum_size = Vector2(360, 540)
	card_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_row.add_child(card_face)
	var card_col := VBoxContainer.new()
	card_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_col.add_theme_constant_override("separation", 10)
	card_row.add_child(card_col)
	card_title = UiTheme.label(tr(""), 30, UiTheme.ACCENT2)
	card_col.add_child(card_title)
	card_body = UiTheme.rich(19)
	card_body.bbcode_enabled = true
	card_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_col.add_child(card_body)
	var card_buttons := HBoxContainer.new()
	card_buttons.add_theme_constant_override("separation", 10)
	card_col.add_child(card_buttons)
	var card_talk := UiTheme.button(tr("说话"), 20)
	card_talk.focus_mode = Control.FOCUS_NONE
	card_talk.pressed.connect(func() -> void:
		var id := card_id
		close_panels()
		press_talk(id))
	card_buttons.add_child(card_talk)
	var card_back := UiTheme.button(tr("返回"), 20)
	card_back.focus_mode = Control.FOCUS_NONE
	card_back.pressed.connect(close_panels)
	card_buttons.add_child(card_back)
	card_panel.visible = false


# ---------------------------------------------------------------- 进地点、摆人、打光

## 进入（或刷新）一个地点：读图、打光、摆剧情人物、主角和队友。from_loc 是从哪个地点走来的；mem 是换屏前记住的位置。
func _enter(new_loc: String, from_loc: String, mem: Dictionary = {}) -> void:
	var first_time := loc != new_loc
	loc = new_loc
	fmap = TiledMap.make(maps_dir, loc)
	for layer_name: String in map_layers:
		FieldTiles.fill(map_layers[layer_name], fmap, layer_name)
	_set_camera_limits()
	_build_lights()
	var restored: bool = String(mem.get("loc", "")) == loc and fmap.walkable(mem["cell"])
	if restored:
		cell = mem["cell"]
		facing = String(mem.get("facing", "down"))
	elif from_loc != "":
		cell = fmap.entry_cell(from_loc)
		facing = fmap.entry_facing(from_loc)
	else:
		cell = fmap.start_cell()
		facing = fmap.start_facing()
	path_queue.clear()
	for c in actors.get_children():
		actors.remove_child(c)
		c.queue_free()
	for id: String in name_labels:
		(name_labels[id] as Control).queue_free()
	name_labels.clear()
	followers.clear()
	follower_ids.clear()
	npc_sprites.clear()
	npc_cells.clear()
	npc_override = (mem.get("npc_override", {}) as Dictionary).duplicate() if restored else {}
	_place_npcs()
	var squad: Array[String] = _squad()
	player_id = squad[0] if not squad.is_empty() else ""
	player = _walker(player_id)
	var order: Array[String] = []
	for i in range(1, squad.size()):
		order.append(squad[i])
	var mem_order: Array = mem.get("followers", []) if restored else []
	if mem_order.size() == order.size() and not mem_order.is_empty():
		var same := true
		for id in mem_order:
			if not order.has(String(id)):
				same = false
		if same:
			order.clear()
			for id in mem_order:
				order.append(String(id))
	for id in order:
		follower_ids.append(id)
		followers.append(_walker(id))
	var old: Array = mem.get("trail", []) if restored else []
	trail = _initial_trail(cell, squad.size(), old)
	spread = false
	spread_cells.clear()
	if restored and bool(mem.get("spread", false)):
		var cells: Array = mem.get("spread_cells", [])
		if cells.size() == followers.size():
			spread = true
			for c in cells:
				spread_cells.append(Vector2i(c))
	_idle = 0.0
	_refresh_new_topics()
	_draw_actors()
	_snap_camera()
	_remember()
	if first_time and not restored:
		_show_banner(String(view.names.get(loc, loc)))


## 队友站的位置：换屏回来按记住的；否则站在主角身后（走得到的格子里，越靠主角正后方越优先；
## 身后没地方就站两边，不站到主角正前方；避开墙、门和剧情人物）。
## 第一步时各自挪到前一个人原来的位置，之后就排成一路跟着走。
func _initial_trail(start: Vector2i, count: int, old: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if old.size() == count and not old.is_empty() and Vector2i(old[0]) == start:
		for c in old:
			out.append(Vector2i(c))
		return out
	out.append(start)
	var blocked := _blocked()
	var back: Vector2i = -TiledMap.DIRS[facing]
	var side := Vector2i(back.y, back.x)
	var dist := {start: 0}
	var queue: Array[Vector2i] = [start]
	var cands: Array[Vector2i] = []
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if int(dist[c]) >= 5:
			continue
		for d: Vector2i in TiledMap.DIRS.values():
			var n: Vector2i = c + d
			if dist.has(n) or not fmap.walkable(n) or fmap.is_door(n) or blocked.has(n):
				continue
			dist[n] = int(dist[c]) + 1
			queue.append(n)
			cands.append(n)
	var score := func(c: Vector2i) -> float:
		var off := c - start
		var along := off.x * back.x + off.y * back.y
		var across := absi(off.x * side.x + off.y * side.y)
		var s := across * 2.5 + (float(along) if along > 0 else 4.0 - along * 3.0)
		if along < 0 and across == 0:
			s += 4.0
		return s + c.y * 0.001 + c.x * 0.00001
	cands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return score.call(a) < score.call(b))
	for c in cands:
		if out.size() >= count:
			break
		out.append(c)
	while out.size() < count:
		out.append(start)
	return out


## 当前分队活着的人：拍板的人排第一（他就是玩家操纵的主角）。
func _squad() -> Array[String]:
	var out: Array[String] = []
	var sid: String = view.squad_id()
	if sid == "":
		return out
	var living: Array[String] = view.ex.st.living_members(sid)
	var leader: String = view.ex.game.leader
	if living.has(leader):
		out.append(leader)
	for c in living:
		if c != leader:
			out.append(c)
	return out


## 一个行走小人：脚底中点对齐格子，脚下有影子。
func _walker(key: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = false
	var size := FieldArt.walker_size(key)
	s.offset = Vector2(-floorf(size.x / 2.0), -size.y)
	s.texture = FieldArt.walker(key, "down", 0)
	s.set_meta("key", key)
	var sh := Sprite2D.new()
	sh.texture = FieldArt.shadow_texture()
	sh.show_behind_parent = true
	s.add_child(sh)
	actors.add_child(s)
	return s


## 这个地点的灯和自发光光晕（光晕在环境光管不到的那一层，黑暗里也亮）。
func _build_lights() -> void:
	for holder: Node in [light_root, glow_layer]:
		for c in holder.get_children():
			holder.remove_child(c)
			c.queue_free()
	flickers.clear()
	var k := 0
	for l: Dictionary in fmap.lights():
		var p := _light(l["color"], float(l["radius"]), float(l["energy"]))
		p.position = _center(l["cell"])
		light_root.add_child(p)
		if bool(l["flicker"]):
			flickers.append({"node": p, "base": p.energy, "phase": 1.7 * k})
		k += 1
	for g: Dictionary in fmap.glows():
		var s := Sprite2D.new()
		s.texture = FieldArt.light_texture()
		s.material = _additive
		s.modulate = g["color"]
		s.scale = Vector2.ONE * float(g["radius"]) * TILE * 2.0 / FieldArt.LIGHT_SIZE
		s.position = _center(g["cell"])
		glow_layer.add_child(s)


## 一盏点光：radius 是格数。
func _light(color: Color, radius: float, energy: float) -> PointLight2D:
	var p := PointLight2D.new()
	p.texture = FieldArt.light_texture()
	p.texture_scale = radius * TILE * 2.0 / FieldArt.LIGHT_SIZE
	p.color = color
	p.energy = energy
	return p


## 这个地点上活着的剧情人物，按地图的站位摆。火焰女皇是全息投影：半透明、发红光、没有影子。
func _place_npcs() -> void:
	var i := 0
	for npc_id: String in view.ex.st.npcs:
		var n: Dictionary = view.ex.st.npcs[npc_id]
		if String(n["location"]) != loc or not bool(n["alive"]):
			continue
		var c: Vector2i = fmap.npc_cell(npc_id, i)
		if not fmap.is_fixed_npc(npc_id):
			i += 1
		if npc_override.has(npc_id) and fmap.walkable(npc_override[npc_id]):
			c = npc_override[npc_id]
		var s := _walker(npc_id)
		if npc_id == "red_queen":
			s.modulate = Color(1.0, 0.45, 0.45, 0.72)
			s.get_child(0).visible = false
			var glow := _light(Color("ff5a5a"), 3.5, 0.9)
			glow.position = Vector2(0, -10)
			s.add_child(glow)
			flickers.append({"node": glow, "base": glow.energy, "phase": 0.4})
		npc_sprites[npc_id] = s
		npc_cells[npc_id] = c


## 剧情人物进出（npc_move、死亡）以后重新摆一遍，不动主角。
func _sync_npcs() -> void:
	for id: String in npc_sprites:
		var s: Sprite2D = npc_sprites[id]
		actors.remove_child(s)
		s.queue_free()
	npc_sprites.clear()
	npc_cells.clear()
	var kept: Array[Dictionary] = []
	for f: Dictionary in flickers:
		if is_instance_valid(f["node"]) and (f["node"] as Node).get_parent() == light_root:
			kept.append(f)
	flickers = kept
	_place_npcs()
	_draw_actors()


## 格子的脚底中点（行走小人的位置）。
func _pixel(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE / 2.0, c.y * TILE + TILE - FOOT_LIFT)


func _center(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE / 2.0, c.y * TILE + TILE / 2.0)


func _draw_actors() -> void:
	if player != null:
		player.position = _pixel(cell)
		player.texture = FieldArt.walker(player_id, facing, 0)
	for i in followers.size():
		var c: Vector2i = follower_cell(i)
		followers[i].position = _pixel(c)
		followers[i].visible = c != cell
		var look: Vector2i = cell if spread else trail[mini(i, trail.size() - 1)]
		followers[i].texture = FieldArt.walker(follower_ids[i], _dir_between(c, look), 0)
	for id: String in npc_sprites:
		var s: Sprite2D = npc_sprites[id]
		var c: Vector2i = npc_cells[id]
		s.position = _pixel(c)
		s.texture = FieldArt.walker(id, _dir_between(c, cell), 0)
	_update_lighting()
	_update_prompt()


func _dir_between(a: Vector2i, b: Vector2i) -> String:
	var d := b - a
	if absi(d.x) > absi(d.y):
		return "right" if d.x > 0 else "left"
	if d.y < 0:
		return "up"
	return "down"


## 镜头边界：地图比一屏大时贴着地图边；比一屏小的那个方向把地图放在正中间（四周露出背景）。
func _set_camera_limits() -> void:
	var map_px: Vector2i = fmap.size * TILE
	var pad_x := maxi(0, pixel_size.x - map_px.x) / 2
	var pad_y := maxi(0, pixel_size.y - map_px.y) / 2
	camera.limit_left = -pad_x
	camera.limit_top = -pad_y
	camera.limit_right = -pad_x + maxi(map_px.x, pixel_size.x)
	camera.limit_bottom = -pad_y + maxi(map_px.y, pixel_size.y)


## 切换视野：远（一屏 40×21 格，放大 3 倍）或近（一屏 30×16 格，放大 4 倍）。
func set_wide(on: bool) -> void:
	wide = on
	pixel_size = VIEW_FAR if on else VIEW_NEAR
	scale_factor = 3 if on else 4
	if viewport == null:
		return
	viewport.size = pixel_size
	display.size = Vector2(pixel_size * scale_factor)
	if fmap != null:
		_set_camera_limits()
		_snap_camera()
		_update_prompt()


## 镜头对准的位置：主角胸口（脚底往上 8 像素）。
func _camera_target() -> Vector2:
	return player.position + Vector2(0, -8) if player != null else Vector2(pixel_size) / 2.0


## 换地点、换屏回来时镜头直接到位、主角在正中（不从上一个位置滑过来，拖拽边距这一下也不算）。
func _snap_camera() -> void:
	camera.position = _camera_target()
	if camera.is_inside_tree():
		camera.drag_horizontal_enabled = false
		camera.drag_vertical_enabled = false
		camera.reset_smoothing()
		camera.force_update_scroll()
		camera.drag_horizontal_enabled = true
		camera.drag_vertical_enabled = true


## 屏幕左上角对着的世界像素（不在场景树里时镜头不起作用，就是原点）。
func view_origin() -> Vector2:
	if not camera.is_inside_tree():
		return Vector2.ZERO
	return (camera.get_screen_center_position() - Vector2(pixel_size) / 2.0).round()


## 地点画面上的一点（场景控件里的坐标）→ 地图格子，算上镜头滚动。
func cell_at(screen_pos: Vector2) -> Vector2i:
	var px := screen_pos / scale_factor + view_origin()
	return Vector2i(floori(px.x / TILE), floori(px.y / TILE))


## 环境光：黑暗地点几乎全黑、打开手电筒；其余按地图的环境光。
func _update_lighting() -> void:
	var w: Dictionary = view.watch()
	var is_dark := bool(w["dark"])
	dark.visible = is_dark
	canvas_mod.color = DARK_AMBIENT if is_dark else fmap.ambient()
	_follow_flashlight()


func _follow_flashlight() -> void:
	if player == null:
		return
	dark.position = player.position + Vector2(0, -8)
	flash.rotation = float(FACING_ANGLE.get(facing, PI / 2.0))


## 进新地点时屏幕上方淡入淡出一下地名。
func _show_banner(text: String) -> void:
	banner.text = text
	if not is_inside_tree():
		return
	banner.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.35)
	tw.tween_interval(1.4)
	tw.tween_property(banner, "modulate:a", 0.0, 0.6)


# ---------------------------------------------------------------- 刷新：事件 → 对话框、提示、窗口

func refresh() -> void:
	_ingest()
	if view.location() != loc and view.location() != "":
		var from := loc
		_enter(view.location(), from if view.ex.st.scenario.neighbors(view.location()).has(from) else "")
	else:
		_sync_npcs()
	_refresh_new_topics()
	_update_hud()
	if not box.visible:
		_show_next()
	_update_prompt()
	_remember()


## 把还没播过的事件变成对话框台词或右边的提示。
func _ingest() -> void:
	var hist: Array = view.ex.history
	var toasts: Array[String] = []
	for i in range(seen, hist.size()):
		var e: Dictionary = hist[i]
		var t := String(e.get("type", ""))
		if t == "dialogue":
			var speaker := String(e.get("speaker", ""))
			messages.append({"id": speaker, "name": "" if speaker == "narrator" else String(view.names.get(speaker, speaker)), "text": String(e.get("text", ""))})
			continue
		if SILENT_TYPES.has(t) or t == "topic_talked":
			continue
		if t == "fear_changed" and (["darkness", "rest"].has(String(e.get("reason", ""))) or absf(float(e.get("amount", 0.0))) < 5.0):
			continue
		var line := EventText.describe(e, view.names)
		if line == "":
			continue
		if STORY_TYPES.has(t):
			messages.append({"id": "", "name": "", "text": line})
		else:
			toasts.append(line)
	seen = hist.size()
	for line in toasts.slice(maxi(0, toasts.size() - 5)):
		_toast(line)


func _toast(text: String) -> void:
	var l := UiTheme.label(text, 17, UiTheme.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(GLASS, 6, 10, 6))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	toast_box.add_child(p)
	while toast_box.get_child_count() > 6:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	if is_inside_tree():
		var tw := p.create_tween()
		tw.tween_interval(4.2)
		tw.tween_property(p, "modulate:a", 0.0, 0.8)
		tw.tween_callback(p.queue_free)


## 对话框里放下一句（一个字一个字打出来）；没有了就处理等着玩家的事（插图、选择、说服、战斗、结束）。
## 有插图要播时先播插图（剧本里插图总是那件事的第一个效果），播完（press_cutscene_done）再接着出台词。
func _show_next() -> void:
	var p: Dictionary = view.pending()
	if String(p.get("kind", "")) == "cutscene":
		_hide_box()
		action_bar.visible = false
		var n := String(p["name"])
		if n != _cutscene_sent:
			_cutscene_sent = n
			cutscene_requested.emit.call_deferred(n, String(p.get("text", "")))
		return
	if skip_messages:
		messages.clear()
	if messages.is_empty():
		_hide_box()
		hint_label.visible = true
		_after_messages()
		return
	var m: Dictionary = messages.pop_front()
	box.visible = true
	action_bar.visible = false
	hint_label.visible = false
	prompt.visible = false
	choice_panel.visible = false
	check_panel.visible = false
	var id := String(m["id"])
	box_name.text = String(m["name"]) if String(m["name"]) != "" else tr("——")
	box_text.text = String(m["text"])
	_reveal = 0.0
	box_text.visible_characters = 0 if is_inside_tree() else -1
	var has_face := id != "" and id != "narrator" and PortraitSource.has_portrait(id)
	box_face.texture = PortraitSource.portrait(id) if has_face else null
	box_face.visible = has_face
	box_margin.add_theme_constant_override("margin_left", 500 if has_face else 0)


func _hide_box() -> void:
	box.visible = false
	box_face.visible = false


## 确认键 / 点击：字还没打完就一下子显示完，打完了就下一句。
func _advance() -> void:
	if box_text.visible_characters >= 0:
		box_text.visible_characters = -1
		return
	_show_next()


func _after_messages() -> void:
	var p: Dictionary = view.pending()
	var kind := String(p.get("kind", ""))
	choice_panel.visible = false
	check_panel.visible = false
	if kind != "cutscene":
		_cutscene_sent = ""
	if kind != "battle":
		_battle_sent = false
	match kind:
		"cutscene":
			var n := String(p["name"])
			if n != _cutscene_sent:
				_cutscene_sent = n
				cutscene_requested.emit.call_deferred(n, String(p.get("text", "")))
		"choice":
			_build_choice(p)
		"check":
			_build_check(p)
		"battle":
			if not _battle_sent:
				_battle_sent = true
				battle_needed.emit.call_deferred()
	action_bar.visible = not (choice_panel.visible or check_panel.visible)
	if view.ended() and not _ended_sent:
		_ended_sent = true
		ended.emit.call_deferred()


func _build_choice(p: Dictionary) -> void:
	_clear(choice_box)
	choice_box.add_child(UiTheme.label(String(p["prompt"]), 22, UiTheme.ACCENT2))
	var opts: Array = p["options"]
	for i in opts.size():
		var o: Dictionary = opts[i]
		var b := UiTheme.button(tr("%d. %s") % [i + 1, String(o["text"])], 20)
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(press_choice.bind(String(o["id"])))
		choice_box.add_child(b)
	choice_panel.size = Vector2(1000, 90 + 58 * opts.size())
	choice_panel.visible = true


func _build_check(p: Dictionary) -> void:
	_clear(check_box)
	if String(p["id"]) != _pending_id:
		_pending_id = String(p["id"])
		chosen_keywords.clear()
	check_box.add_child(UiTheme.label(tr("%s：%s（难度 %d）") % [String(p["npc"]), String(p["goal"]), int(p["difficulty"])], 22, UiTheme.ACCENT2))
	if not bool(p["fact_ready"]):
		check_box.add_child(UiTheme.label(tr("你还没有把握开口。先推理出：%s") % String(p["fact_name"]), 18, UiTheme.MUTED))
		var row0 := HBoxContainer.new()
		row0.add_theme_constant_override("separation", 10)
		var think := UiTheme.button(tr("推理（10 分钟）"), 19)
		think.focus_mode = Control.FOCUS_NONE
		think.pressed.connect(press_deduce)
		row0.add_child(think)
		var give_up := UiTheme.button(tr("硬扛（放弃说服）"), 19)
		give_up.focus_mode = Control.FOCUS_NONE
		give_up.pressed.connect(press_persuade.bind(0))
		row0.add_child(give_up)
		check_box.add_child(row0)
		check_panel.visible = true
		return
	check_box.add_child(UiTheme.label(tr("让 %s 开口：选几个要说到的点（已选 %d 个）") % [String(p["thinker"]), chosen_keywords.size()], 18, UiTheme.MUTED))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	for k: String in p["keywords"]:
		var on := chosen_keywords.has(k)
		var b := UiTheme.button(("✓ " if on else "") + k, 19)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			if chosen_keywords.has(k):
				chosen_keywords.erase(k)
			else:
				chosen_keywords.append(k)
			_build_check(view.pending()))
		row.add_child(b)
	check_box.add_child(row)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	var say := UiTheme.button(tr("开口"), 20)
	say.focus_mode = Control.FOCUS_NONE
	say.custom_minimum_size = Vector2(180, 48)
	say.pressed.connect(press_persuade_keywords)
	row2.add_child(say)
	var give_up2 := UiTheme.button(tr("硬扛（放弃说服）"), 19)
	give_up2.focus_mode = Control.FOCUS_NONE
	give_up2.pressed.connect(press_persuade.bind(0))
	row2.add_child(give_up2)
	var free := UiTheme.button(tr("自己说（AI 评分）"), 19)
	free.focus_mode = Control.FOCUS_NONE
	free.pressed.connect(press_persuade_free)
	row2.add_child(free)
	check_box.add_child(row2)
	check_panel.visible = true


func _clear(c: Control) -> void:
	for n in c.get_children():
		c.remove_child(n)
		n.queue_free()


## 左上角：地点、时间、任务；右上角：队伍。都按内容收紧大小。
func _update_hud() -> void:
	var w: Dictionary = view.watch()
	var left := int(w["remaining_minutes"])
	var lines: Array[String] = []
	var top := "[color=#e8a33d][font_size=20]%s[/font_size][/color]　第 %d 分钟 · 剩余 [color=#e8a33d]%d:%02d[/color]" % [String(view.names.get(loc, loc)), int(view.ex.st.clock), left / 60, left % 60]
	if int(w["kills"]) > 0:
		top += " · 击杀 %d（%.1f 点）" % [int(w["kills"]), float(w["kill_points"])]
	lines.append(top)
	lines.append("[color=#aab2c0]%s[/color]" % String(w["main_task"]))
	var extra: Array[String] = []
	if String(w["tether"]) != "":
		extra.append("绑定：" + String(w["tether"]))
	if bool(w["gag"]):
		extra.append("禁言：剧情人物面前别提主神")
	if bool(w["dark"]):
		extra.append("[color=#d8534f]全黑，恐惧持续上升[/color]")
	if not extra.is_empty():
		lines.append("[color=#aab2c0]%s[/color]" % " · ".join(extra))
	hud_label.text = "\n".join(lines)
	var plines: Array[String] = []
	for m: Dictionary in view.members():
		if not bool(m["alive"]):
			plines.append("[color=#5a6270]%s　阵亡[/color]" % String(m["name"]))
			continue
		var hp_ratio := float(m["hp"]) / maxf(1.0, float(m["hp_max"]))
		var hp_color := "#7fd08a" if hp_ratio > 0.6 else ("#e8a33d" if hp_ratio > 0.3 else "#d8534f")
		var fear := int(m["fear"])
		var fear_text := "　[color=#b48ad8]恐惧 %d[/color]" % fear if fear > 0 else ""
		plines.append("%s　[color=%s]%d/%d[/color]%s%s" % [String(m["name"]), hp_color, int(m["hp"]), int(m["hp_max"]), fear_text, "　[color=#d8534f]感染[/color]" if bool(m["infected"]) else ""])
	party_label.text = "\n".join(plines)
	if is_inside_tree():
		_fit_panels.call_deferred()


func _fit_panels() -> void:
	hud.reset_size()
	party.reset_size()
	party.position.x = 1904 - party.size.x


# ---------------------------------------------------------------- 输入与走动

## 有对话、窗口、等待中的事，或者上面盖着别的面板（对话框、暂停、插图）时不能走。
func busy() -> bool:
	if box.visible or choice_panel.visible or check_panel.visible or log_panel.visible:
		return true
	if roster_panel.visible or card_panel.visible:
		return true
	if not view.pending().is_empty() or view.ended():
		return true
	var host := get_parent().get_parent() if get_parent() != null else null
	if host != null:
		if host.get("pause") != null or host.get("panel") != null or host.get_node_or_null("Cutscene") != null:
			return true
	return false


func _process(delta: float) -> void:
	_time += delta
	_animate(delta)
	camera.position = _camera_target()
	if moving or busy():
		prompt.visible = false
		return
	if not path_queue.is_empty():
		var next: Vector2i = path_queue.pop_front()
		var d := _dir_between(cell, next)
		if next - cell != TiledMap.DIRS[d]:
			path_queue.clear()
			return
		step(d)
		if path_queue.is_empty() and not path_then.is_empty():
			var then := path_then
			path_then = {}
			_do_then(then)
		return
	for d: String in KEYS:
		for k: int in KEYS[d]:
			if Input.is_physical_key_pressed(k):
				step(d)
				return
	_bump_id = ""
	_idle += delta
	if not spread and _idle >= SPREAD_DELAY and not followers.is_empty():
		spread_out()
	_update_prompt()


## 每帧的小动画：打字、灯闪、手电筒跟着人、对话框的继续箭头。
func _animate(delta: float) -> void:
	if box.visible and box_text.visible_characters >= 0:
		_reveal += delta * REVEAL_CPS
		box_text.visible_characters = int(_reveal)
		if box_text.visible_characters >= box_text.text.length():
			box_text.visible_characters = -1
	box_more.modulate.a = 0.0 if box_text.visible_characters >= 0 else 0.55 + 0.45 * sin(_time * 5.0)
	for f: Dictionary in flickers:
		var node: PointLight2D = f["node"]
		if not is_instance_valid(node):
			continue
		var ph: float = f["phase"]
		var e: float = float(f["base"]) * (0.88 + 0.12 * sin(_time * 11.0 + ph) * sin(_time * 4.3 + ph * 2.0))
		if fmod(_time + ph, 5.0) < 0.14:
			e *= 0.3
		node.energy = e
	if dark.visible:
		_follow_flashlight()
	_update_names()


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		if box.visible and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.keycode == KEY_SPACE or k.keycode == KEY_Z):
			_advance()
			accept_event()
			return
		if choice_panel.visible:
			var idx := int(k.keycode) - int(KEY_1)
			var p: Dictionary = view.pending()
			if idx >= 0 and idx < 9 and String(p.get("kind", "")) == "choice" and idx < (p["options"] as Array).size():
				press_choice(String(p["options"][idx]["id"]))
				accept_event()
			return
		if (roster_panel.visible or card_panel.visible) and (k.keycode == KEY_ESCAPE or k.keycode == KEY_T):
			close_panels()
			accept_event()
			return
		if k.keycode == KEY_L:
			_toggle_log()
			accept_event()
			return
		if k.keycode == KEY_T and not busy():
			open_roster()
			accept_event()
			return
		if k.keycode == KEY_V and not box.visible:
			set_wide(not wide)
			view_changed.emit(wide)
			_toast(tr("视野：远（一屏 40×21 格）") if wide else tr("视野：近（一屏 30×16 格）"))
			accept_event()
			return
		if not busy() and (k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER or k.keycode == KEY_SPACE or k.keycode == KEY_Z):
			interact()
			accept_event()
			return


## 点地图：整屏控件自己收鼠标（点在对话框、窗口、按钮上的不会到这里）。
func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if box.visible:
		_advance()
	elif not busy():
		click_cell(cell_at(mb.position))
	accept_event()


func _on_box_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_advance()
		accept_event()


## 面前一格能做什么：调查柜子、跟谁说话、去哪个地点；什么都没有返回空字符串。
func prompt_text() -> String:
	var t: Vector2i = cell + TiledMap.DIRS[facing]
	if fmap.is_search(t):
		return tr("Enter 调查（搜过了）") if view.ex.st.searched.has(loc) else tr("Enter 调查")
	for id: String in npc_cells:
		if npc_cells[id] == t and _can_talk(id):
			if not Topics.can_hear(view.ex.st, id):
				return tr("Enter 看看：%s") % String(view.names.get(id, id))
			return tr("Enter 说话：%s") % String(view.names.get(id, id))
	for i in follower_ids.size():
		if follower_cell(i) == t and _can_talk(follower_ids[i]):
			return tr("Enter 说话：%s") % String(view.names.get(follower_ids[i], follower_ids[i]))
	if fmap.is_door(t):
		var dest: String = fmap.door_dest(t)
		return tr("前往：%s") % String(view.names.get(dest, dest))
	return ""


func _can_talk(id: String) -> bool:
	for t: Dictionary in view.talk_targets():
		if String(t["id"]) == id:
			return true
	return false


## 面前有能互动的东西时，在它头顶上提示一下。
func _update_prompt() -> void:
	var text := prompt_text() if fmap != null else ""
	if text == "" or moving or busy():
		prompt.visible = false
		return
	prompt_label.text = text
	prompt.reset_size()
	var t: Vector2i = cell + TiledMap.DIRS[facing]
	var at := (Vector2(t.x * TILE + TILE / 2.0, t.y * TILE - 14) - view_origin()) * scale_factor
	prompt.position = Vector2(clampf(at.x - prompt.size.x / 2.0, 8.0, 1912.0 - prompt.size.x), clampf(at.y - prompt.size.y, 8.0, 960.0))
	prompt.visible = true


## 别人占着的格子（剧情人物）。队友不挡路。
func _blocked() -> Dictionary:
	var out := {}
	for id: String in npc_cells:
		out[npc_cells[id]] = true
	return out


## 朝 d 走一格：撞墙就只转身；走进门就去隔壁。
func step(d: String) -> void:
	facing = d
	var target: Vector2i = cell + TiledMap.DIRS[d]
	if fmap.is_door(target):
		_go_door(fmap.door_dest(target))
		return
	if not fmap.walkable(target):
		_draw_actors()
		return
	var blocker := _npc_at(target)
	if blocker != "":
		if fmap.is_fixed_npc(blocker) or not _give_way(blocker):
			_draw_actors()
			return
	_bump_id = ""
	_idle = 0.0
	if spread:
		_gather()
	var before: Array[Vector2i] = trail.duplicate()
	trail.push_front(target)
	trail.resize(maxi(1, follower_ids.size() + 1))
	cell = target
	walk_frame = 3 - walk_frame
	_remember()
	if not is_inside_tree():
		_draw_actors()
		return
	moving = true
	prompt.visible = false
	var tw := create_tween().set_parallel(true)
	player.texture = FieldArt.walker(player_id, facing, walk_frame)
	tw.tween_property(player, "position", _pixel(cell), STEP_TIME)
	for i in followers.size():
		var c: Vector2i = trail[mini(i + 1, trail.size() - 1)]
		var was: Vector2i = before[mini(i + 1, before.size() - 1)]
		followers[i].visible = c != cell
		followers[i].texture = FieldArt.walker(follower_ids[i], _dir_between(was, c), walk_frame)
		tw.tween_property(followers[i], "position", _pixel(c), STEP_TIME)
	tw.chain().tween_callback(func() -> void:
		moving = false
		_draw_actors())


## 第 i 个队友现在站的格子：散开时是散开的位置，否则是主角走过的足迹。
func follower_cell(i: int) -> Vector2i:
	if spread and i < spread_cells.size():
		return spread_cells[i]
	return trail[mini(i + 1, trail.size() - 1)]


func _npc_at(c: Vector2i) -> String:
	for id: String in npc_cells:
		if npc_cells[id] == c:
			return id
	return ""


## 顶着一个剧情人物：先只是转身对着他（这样能说话）；一直顶着超过 GIVE_WAY_DELAY 秒，他和你换个位置让路。
## 返回 true 表示这一步可以走过去（他已经挪到你原来的格子）。
func _give_way(npc_id: String) -> bool:
	if _bump_id != npc_id:
		_bump_id = npc_id
		_bump_since = _time
		return false
	if _time - _bump_since < GIVE_WAY_DELAY:
		return false
	npc_cells[npc_id] = cell
	npc_override[npc_id] = cell
	_bump_id = ""
	if npc_sprites.has(npc_id):
		var s: Sprite2D = npc_sprites[npc_id]
		if is_inside_tree():
			create_tween().tween_property(s, "position", _pixel(cell), STEP_TIME)
		else:
			s.position = _pixel(cell)
	return true


## 散开：每个队友挑附近一个空格站过去（离主角 2～4 步，避开门、剧情人物和别的队友），面朝主角。
func spread_out() -> void:
	if followers.is_empty():
		return
	var taken := {cell: true}
	for id: String in npc_cells:
		taken[npc_cells[id]] = true
	var dist := {cell: 0}
	var queue: Array[Vector2i] = [cell]
	var cands: Array[Vector2i] = []
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if int(dist[c]) >= 4:
			continue
		for d: Vector2i in TiledMap.DIRS.values():
			var n: Vector2i = c + d
			if dist.has(n) or not fmap.walkable(n) or fmap.is_door(n) or taken.has(n):
				continue
			dist[n] = int(dist[c]) + 1
			queue.append(n)
			if int(dist[n]) >= 2:
				cands.append(n)
	var picked: Array[Vector2i] = []
	for i in followers.size():
		var from: Vector2i = follower_cell(i)
		var best := Vector2i(-9999, -9999)
		var best_score := INF
		for c in cands:
			if picked.has(c):
				continue
			var near_mate := 0
			for p in picked:
				if absi(p.x - c.x) + absi(p.y - c.y) <= 1:
					near_mate += 1
			var s := float(absi(c.x - from.x) + absi(c.y - from.y)) + near_mate * 3.0 + c.y * 0.001 + c.x * 0.00001
			if s < best_score:
				best_score = s
				best = c
		picked.append(best if best.x > -9999 else from)
	var old: Array[Vector2i] = []
	for i in followers.size():
		old.append(follower_cell(i))
	spread_cells = picked
	spread = true
	_remember()
	for i in followers.size():
		var path: Array[Vector2i] = []
		if old[i] != picked[i]:
			path = fmap.path(old[i], picked[i], {})
		if not is_inside_tree() or path.is_empty():
			followers[i].position = _pixel(picked[i])
			followers[i].visible = picked[i] != cell
			followers[i].texture = FieldArt.walker(follower_ids[i], _dir_between(picked[i], cell), 0)
			continue
		var tw := create_tween()
		var prev: Vector2i = old[i]
		var frame := 1
		for c in path:
			var s: Sprite2D = followers[i]
			var dir := _dir_between(prev, c)
			var key: String = follower_ids[i]
			var f := frame
			tw.tween_callback(func() -> void:
				s.visible = true
				s.texture = FieldArt.walker(key, dir, f))
			tw.tween_property(s, "position", _pixel(c), STEP_TIME * 1.3)
			prev = c
			frame = 3 - frame
		var sp: Sprite2D = followers[i]
		var k2: String = follower_ids[i]
		var end: Vector2i = picked[i]
		tw.tween_callback(func() -> void:
			sp.texture = FieldArt.walker(k2, _dir_between(end, cell), 0))


## 归队：散开的队友按离主角远近排好，重新排成一路跟在后面。
func _gather() -> void:
	var idx: Array[int] = []
	for i in followers.size():
		idx.append(i)
	idx.sort_custom(func(a: int, b: int) -> bool:
		var ca: Vector2i = spread_cells[a]
		var cb: Vector2i = spread_cells[b]
		return absi(ca.x - cell.x) + absi(ca.y - cell.y) < absi(cb.x - cell.x) + absi(cb.y - cell.y))
	var f2: Array[Sprite2D] = []
	var id2: Array[String] = []
	var tr2: Array[Vector2i] = [cell]
	for i in idx:
		f2.append(followers[i])
		id2.append(follower_ids[i])
		tr2.append(spread_cells[i])
	followers = f2
	follower_ids = id2
	trail = tr2
	spread = false
	spread_cells.clear()


## 对着前面一格按确认：柜子 → 搜索；剧情人物或队友 → 说话；门 → 过去。
func interact() -> void:
	var target: Vector2i = cell + TiledMap.DIRS[facing]
	if fmap.is_search(target):
		press_search()
		return
	for id: String in npc_cells:
		if npc_cells[id] == target:
			press_talk(id)
			return
	for i in follower_ids.size():
		if follower_cell(i) == target:
			press_talk(follower_ids[i])
			return
	if fmap.is_door(target):
		_go_door(fmap.door_dest(target))


## 点了地图上的某一格：走过去；点的是门、柜子或人，就走到旁边再进门 / 搜索 / 说话。
func click_cell(c: Vector2i) -> void:
	if not fmap.inside(c):
		return
	path_queue.clear()
	path_then = {}
	var blocked := _blocked()
	var goal := c
	var then := {}
	if fmap.is_door(c):
		then = {"door": fmap.door_dest(c), "face": c}
		goal = Vector2i(-1, -1)
		for d: Vector2i in TiledMap.DIRS.values():
			if fmap.walkable(c + d) and not fmap.is_door(c + d):
				goal = c + d
	elif fmap.is_search(c) or blocked.has(c):
		then = {"interact": true, "face": c}
		goal = Vector2i(-1, -1)
		var best := 99999
		for d: Vector2i in TiledMap.DIRS.values():
			var n: Vector2i = c + d
			if fmap.walkable(n) and not blocked.has(n) and not fmap.is_door(n):
				var len: int = 0 if n == cell else fmap.path(cell, n, blocked).size()
				if (n == cell or len > 0) and len < best:
					best = len
					goal = n
	if goal.x < 0:
		return
	if goal == cell:
		_do_then(then)
		return
	path_queue = fmap.path(cell, goal, blocked)
	path_then = then


func _do_then(then: Dictionary) -> void:
	if then.has("face"):
		facing = _dir_between(cell, then["face"])
		_draw_actors()
	if then.has("door"):
		_go_door(String(then["door"]))
	elif bool(then.get("interact", false)):
		interact()


## 走进门：规则允许就去隔壁（时间照走），否则说明为什么不行。
func _go_door(dest: String) -> void:
	if dest == "":
		return
	if not view.can_move(dest):
		var why := tr("门打不开。") if view.blocked_reason() == "" else tr("现在走不开。")
		_toast(why)
		_draw_actors()
		return
	var from := loc
	view.move(dest)
	if view.location() == dest:
		_enter(dest, from)
	refresh()


# ---------------------------------------------------------------- 人：名字、在场的人、人物卡

## 对话信任（0～5）：main 传进来的对话记忆里读。
func trust_of(id: String) -> int:
	return int((dialogue_store.get(id, {}) as Dictionary).get("trust", 0))


func _refresh_new_topics() -> void:
	_new_topics.clear()
	if view == null:
		return
	for id in present_people():
		if id != player_id and _can_talk(id) and Topics.has_new(view.ex.st, id, trust_of(id)):
			_new_topics[id] = true


## 这个地点上的人：主角、队友、活着的剧情人物（按这个顺序）。
func present_people() -> Array[String]:
	var out: Array[String] = []
	if player_id != "":
		out.append(player_id)
	for id in follower_ids:
		out.append(id)
	for id: String in npc_sprites:
		out.append(id)
	return out


## 有没有还没聊过的话题（头上的"…"、名单上的"有新话题"）。
func has_new_topic(id: String) -> bool:
	return _new_topics.has(id)


func _sprite_of(id: String) -> Sprite2D:
	if id == player_id:
		return player
	var i := follower_ids.find(id)
	if i >= 0:
		return followers[i]
	return npc_sprites.get(id, null)


## 走近的人头顶显示名字；有新话题的后面带"…"。对话框、窗口开着时不显示。
func _update_names() -> void:
	var showing := not busy() and fmap != null
	var near := {}
	if showing:
		for id in present_people():
			if id == player_id:
				continue
			var s := _sprite_of(id)
			if s == null or not s.visible:
				continue
			var c := Vector2i(floori(s.position.x / TILE), floori((s.position.y - 1) / TILE))
			if absi(c.x - cell.x) + absi(c.y - cell.y) <= NAME_RANGE:
				near[id] = s
	for id: String in name_labels.keys():
		if not near.has(id):
			(name_labels[id] as Control).visible = false
	# 近的人先摆；和已经摆好的名字叠在一起就往上挪一行，还叠就不显示（面前那个人的名字提示框里有）。
	var order: Array[String] = []
	for id: String in near:
		order.append(id)
	var me: Vector2 = player.position if player != null else Vector2.ZERO
	order.sort_custom(func(a: String, b: String) -> bool:
		return (near[a] as Sprite2D).position.distance_squared_to(me) < (near[b] as Sprite2D).position.distance_squared_to(me))
	var placed: Array[Rect2] = []
	for id in order:
		var l: Label = name_labels.get(id, null)
		if l == null:
			l = UiTheme.label(tr(""), 16, UiTheme.TEXT)
			l.autowrap_mode = TextServer.AUTOWRAP_OFF
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			l.add_theme_constant_override("outline_size", 6)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			name_layer.add_child(l)
			name_labels[id] = l
		l.text = String(view.names.get(id, id)) + (" …" if has_new_topic(id) else "")
		l.add_theme_color_override("font_color", UiTheme.ACCENT2 if has_new_topic(id) else UiTheme.TEXT)
		l.reset_size()
		var s: Sprite2D = near[id]
		var head := s.position + Vector2(0, -FieldArt.walker_size(String(s.get_meta("key", id))).y - 3)
		var at := (head - view_origin()) * scale_factor
		var rect := Rect2(Vector2(at.x - l.size.x / 2.0, at.y - l.size.y), l.size).grow(2.0)
		if _overlaps(rect, placed):
			rect.position.y -= l.size.y
		if _overlaps(rect, placed):
			l.visible = false
			continue
		placed.append(rect)
		l.position = rect.position + Vector2(2, 2)
		l.visible = true


func _overlaps(rect: Rect2, others: Array[Rect2]) -> bool:
	for o in others:
		if rect.intersects(o):
			return true
	return false


## 关掉"在场的人"和人物卡。
func close_panels() -> void:
	roster_panel.visible = false
	card_panel.visible = false


## T：在场的人。每人一行：名字、身份、状态，"说话"和"人物卡"两个按钮；有新话题的标出来。
func open_roster() -> void:
	card_panel.visible = false
	_clear(roster_box)
	var head := UiTheme.label(tr("在场的人（T / Esc 关闭）"), 24, UiTheme.ACCENT2)
	head.autowrap_mode = TextServer.AUTOWRAP_OFF
	roster_box.add_child(head)
	for id in present_people():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var who := String(view.names.get(id, id))
		var tag := tr("（你）") if id == player_id else (tr("剧情人物") if view.ex.st.npcs.has(id) else tr("轮回者"))
		var extra := ""
		if id != player_id and not Topics.can_hear(view.ex.st, id):
			extra = tr(" · 听不见你们说话")
		elif has_new_topic(id):
			extra = tr(" · 有新话题")
		var l := UiTheme.label(tr("%s　%s%s") % [who, tag, extra], 18, UiTheme.ACCENT2 if has_new_topic(id) else UiTheme.TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size = Vector2(560, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		row.add_child(l)
		if id != player_id:
			var talk := UiTheme.button(tr("看看") if not Topics.can_hear(view.ex.st, id) else tr("说话"), 17)
			talk.focus_mode = Control.FOCUS_NONE
			talk.custom_minimum_size = Vector2(0, 36)
			talk.pressed.connect(func() -> void:
				close_panels()
				press_talk(id))
			row.add_child(talk)
		var card := UiTheme.button(tr("人物卡"), 17)
		card.focus_mode = Control.FOCUS_NONE
		card.custom_minimum_size = Vector2(0, 36)
		card.pressed.connect(open_card.bind(id))
		row.add_child(card)
		roster_box.add_child(row)
	# 人多了（主神空间以后会更多）就在名单里滚动，面板不超出屏幕。
	roster_scroll.custom_minimum_size = Vector2(880, minf(roster_box.get_combined_minimum_size().y, 800.0))
	roster_scroll.scroll_vertical = 0
	roster_panel.reset_size()
	roster_panel.visible = true


## 人物卡上的内容（测试也用）：{title, lines: [一行一项], notes: [聊出来的要点], unseen: 没聊过的话题数}。
func card_info(id: String) -> Dictionary:
	var st: RefCounted = view.ex.st
	var lines: Array[String] = []
	var is_npc: bool = st.npcs.has(id)
	if id == player_id:
		lines.append(tr("身份：轮回者（你自己）"))
	elif is_npc:
		lines.append(tr("身份：剧情人物"))
	else:
		lines.append(tr("身份：轮回者"))
	if st.characters.has(id):
		var ch: RefCounted = st.characters[id]
		var status := tr("血 %d/%d · 恐惧 %d") % [int(ch.hp), int(ch.hp_max()), int(ch.fear)]
		if st.infected.has(id):
			status += tr(" · 已感染")
		lines.append(status)
	elif is_npc:
		lines.append(tr("状态：活着") if bool(st.npcs[id]["alive"]) else tr("状态：已死亡"))
	if id != player_id:
		if is_npc:
			lines.append(tr("对你的信任：%d / 5") % trust_of(id))
			if not Topics.can_hear(st, id):
				lines.append(tr("现在听不见你们说话（列车减速之前）"))
		else:
			var game: RefCounted = view.ex.game
			var leader: String = game.leader
			lines.append(tr("对你的信任 %d · 服从 %d") % [int(game.relations.value(id, leader, "trust")), int(Cohesion.obedience(game.relations, id, leader))])
	var notes: Array[String] = Topics.notes(st, id)
	if id == player_id:
		notes = [_persona_background(id)]
	return {"title": String(view.names.get(id, id)), "lines": lines, "notes": notes, "unseen": Topics.unseen_count(st, id) if id != player_id else 0}


func _persona_background(id: String) -> String:
	var res := DataLoader.load_json("res://data/ai/personas.json")
	if not res.ok:
		return ""
	return String((((res.data as Dictionary).get("personas", {}) as Dictionary).get(id, {}) as Dictionary).get("background", ""))


func open_card(id: String) -> void:
	roster_panel.visible = false
	card_id = id
	var info := card_info(id)
	card_title.text = String(info["title"])
	var parts: Array[String] = []
	for line: String in info["lines"]:
		parts.append(line)
	parts.append("")
	parts.append("[color=#e8a33d]了解到的[/color]")
	var notes: Array = info["notes"]
	if notes.is_empty():
		parts.append("[color=#aab2c0]还不了解。找%s聊聊。[/color]" % String(info["title"]))
	for n in notes:
		parts.append("· " + String(n))
	if int(info["unseen"]) > 0:
		parts.append("")
		parts.append("[color=#aab2c0]还有 %d 个话题没聊过（有的要更熟才会说）。[/color]" % int(info["unseen"]))
	card_body.text = "\n".join(parts)
	card_face.texture = PortraitSource.portrait(id)
	card_panel.visible = true


func _toggle_log() -> void:
	log_panel.visible = not log_panel.visible
	if log_panel.visible:
		log_label.text = "\n".join(view.log_tail(40))


func _toggle_items() -> void:
	item_box.visible = not item_box.visible
	_clear(item_box)
	if not item_box.visible:
		return
	var acts: Array[Dictionary] = view.item_actions()
	if acts.is_empty():
		item_box.add_child(UiTheme.label(tr("现在没有能用的道具。"), 17, UiTheme.MUTED))
	for a: Dictionary in acts:
		var b := UiTheme.button(String(a["label"]), 17)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			press_item(String(a["char"]), String(a["item"]))
			item_box.visible = false)
		item_box.add_child(b)


# ---------------------------------------------------------------- 对外的动作（界面按钮、main、验收脚本共用）

## 把还没看的台词直接跳过（脚本和测试用；玩家是一句句点过去的）。
func flush_messages() -> void:
	messages.clear()
	_hide_box()


func press_move(loc_id: String) -> bool:
	if not view.can_move(loc_id):
		return false
	flush_messages()
	_go_door(loc_id)
	return true


func press_choice(option_id: String) -> bool:
	if view.pending().get("kind", "") != "choice":
		return false
	flush_messages()
	choice_panel.visible = false
	view.choose(option_id)
	refresh()
	return true


func press_persuade(level: int) -> bool:
	if view.pending().get("kind", "") != "check":
		return false
	flush_messages()
	check_panel.visible = false
	view.persuade(level)
	refresh()
	return true


func select_keywords(keys: Array) -> void:
	chosen_keywords.clear()
	for k: String in keys:
		chosen_keywords.append(k)


func press_persuade_keywords() -> bool:
	if chosen_keywords.is_empty() or view.pending().get("kind", "") != "check":
		return false
	flush_messages()
	check_panel.visible = false
	view.persuade_with(chosen_keywords)
	chosen_keywords.clear()
	refresh()
	return true


func press_persuade_free() -> bool:
	if view.pending().get("kind", "") != "check":
		return false
	persuade_requested.emit()
	return true


func press_talk(npc_id: String) -> bool:
	if not _can_talk(npc_id):
		return false
	talk_requested.emit(npc_id)
	return true


func press_rest(minutes: int) -> void:
	if view.blocked_reason() != "":
		return
	flush_messages()
	view.rest(minutes)
	refresh()


func press_search() -> void:
	if view.blocked_reason() != "":
		return
	view.search()
	refresh()


func press_deduce() -> void:
	var thinker: String = view.best_thinker_id()
	if thinker != "":
		view.deduce("queen_controls_lasers", thinker)
	refresh()


func press_item(char_id: String, item_id: String) -> void:
	view.use_item(char_id, item_id)
	refresh()


func press_cutscene_done() -> void:
	view.dismiss_cutscene()
	refresh()
```

- [ ] **Step 19：改写 `game/ui/dialogue/dialogue_panel.gd`**

```gdscript
extends Control
## 对话框（覆盖在远征/主神空间之上）：只管画、收输入、发信号，台词与检定都在 core/dialogue。
## 两种模式：talk（自由说话，NPC 回一句）和 persuade（玩家说一段，评说服力等级）。
## 候选回复是给手机用的：点一句就当自己说的话，不用打字。

signal submitted(text: String)
signal persuading(text: String)
signal reply_picked(text: String)
## 点了一个固定话题（core/dialogue/topics.gd）。
signal topic_picked(topic_id: String)
signal closed

const UiTheme = preload("res://ui/ui_theme.gd")
const PixelArt = preload("res://ui/art/pixel_art.gd")
const PortraitSource = preload("res://ui/art/portrait_source.gd")

var panel: Panel
var title_label: Label
var sub_label: Label
var log_label: RichTextLabel
var reply_box: HBoxContainer
var topic_title: Label
var topic_box: HFlowContainer
var input: LineEdit
var send_button: Button
var status_label: Label
## 右侧立绘位：现在放放大后的像素头像占位，等 Codex 的剧情立绘到位后换成贴图。
var portrait: TextureRect
var portrait_caption: Label
var mode: String = "talk"
var _lines: Array[String] = []
var _built := false


func _ready() -> void:
	build()


## 幂等：界面里 _ready 调一次，测试里直接调。
func build() -> void:
	if _built:
		return
	_built = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mask := ColorRect.new()
	mask.color = Color(0, 0, 0, 0.78)
	mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(mask)

	panel = Panel.new()
	panel.position = Vector2(340, 130)
	panel.size = Vector2(1240, 800)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PANEL, UiTheme.LINE, 10))
	add_child(panel)

	title_label = UiTheme.label(tr(""), 28, UiTheme.ACCENT2)
	title_label.position = Vector2(28, 20)
	title_label.size = Vector2(900, 38)
	panel.add_child(title_label)
	sub_label = UiTheme.label(tr(""), 16, UiTheme.MUTED)
	sub_label.position = Vector2(30, 58)
	sub_label.size = Vector2(1000, 24)
	panel.add_child(sub_label)

	var close_button := UiTheme.button(tr("×"), 24)
	close_button.position = Vector2(1150, 18)
	close_button.size = Vector2(60, 48)
	close_button.pressed.connect(_on_close)
	panel.add_child(close_button)

	log_label = UiTheme.rich(21)
	log_label.bbcode_enabled = true
	log_label.position = Vector2(28, 96)
	log_label.size = Vector2(800, 300)
	log_label.scroll_following = true
	panel.add_child(log_label)

	topic_title = UiTheme.label(tr("可以问的："), 17, UiTheme.MUTED)
	topic_title.position = Vector2(28, 404)
	topic_title.size = Vector2(800, 24)
	panel.add_child(topic_title)
	topic_box = HFlowContainer.new()
	topic_box.position = Vector2(28, 432)
	topic_box.size = Vector2(800, 140)
	topic_box.add_theme_constant_override("h_separation", 10)
	topic_box.add_theme_constant_override("v_separation", 8)
	panel.add_child(topic_box)

	reply_box = HBoxContainer.new()
	reply_box.position = Vector2(28, 578)
	reply_box.size = Vector2(800, 56)
	reply_box.add_theme_constant_override("separation", 10)
	panel.add_child(reply_box)

	input = LineEdit.new()
	input.position = Vector2(28, 650)
	input.size = Vector2(600, 54)
	input.placeholder_text = "说点什么……"
	input.add_theme_font_size_override("font_size", 20)
	input.text_submitted.connect(func(_t: String) -> void: _on_send())
	panel.add_child(input)

	send_button = UiTheme.button(tr("说"), 21)
	send_button.position = Vector2(644, 650)
	send_button.size = Vector2(184, 54)
	send_button.pressed.connect(_on_send)
	panel.add_child(send_button)

	status_label = UiTheme.label(tr(""), 16, UiTheme.MUTED)
	status_label.position = Vector2(28, 722)
	status_label.size = Vector2(800, 24)
	panel.add_child(status_label)

	var frame := Panel.new()
	frame.position = Vector2(856, 96)
	frame.size = Vector2(356, 650)
	frame.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.DARK, UiTheme.LINE, 8))
	panel.add_child(frame)
	portrait = TextureRect.new()
	portrait.position = Vector2(14, 14)
	portrait.size = Vector2(328, 492)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(portrait)
	portrait_caption = UiTheme.label(tr(""), 15, UiTheme.MUTED)
	portrait_caption.position = Vector2(14, 516)
	portrait_caption.size = Vector2(328, 110)
	frame.add_child(portrait_caption)


## 打开对话框：清空记录、设定称呼与副标题。
func open_for(title: String, subtitle: String, dialogue_mode: String = "talk") -> void:
	build()
	_lines.clear()
	log_label.text = ""
	clear_replies()
	title_label.text = title
	sub_label.text = subtitle
	set_topics([])
	set_free_text(true)
	set_mode(dialogue_mode)
	set_status("")
	set_portrait("")
	show()
	if is_inside_tree():
		input.grab_focus()


func set_mode(dialogue_mode: String) -> void:
	mode = dialogue_mode
	if send_button != null:
		send_button.text = "说服" if mode == "persuade" else "说"
		input.placeholder_text = "想好怎么说……（说辞越切中要害，说服力越高）" if mode == "persuade" else "说点什么……"


## 追加一句。子串里带 [ 或 ] 会被当 BBCode，先转义。
func push(speaker: String, text: String) -> void:
	build()
	var safe := text.replace("[", "［").replace("]", "］")
	var who := "[color=#e0a458]%s[/color]" % speaker.replace("[", "［").replace("]", "］")
	_lines.append("%s\n%s" % [who, safe])
	log_label.text = "\n\n".join(_lines)


func set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


## 候选回复按钮；点一下等于说这句话。
func set_replies(list: Array) -> void:
	build()
	clear_replies()
	for r in list:
		var text := String(r)
		var b := UiTheme.button(text, 17)
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			reply_picked.emit(text)
			_on_send(text)
		)
		reply_box.add_child(b)


## 固定话题按钮：每个是 {id, label, seen}。没聊过的前面带"•"，聊过的打"✓"、颜色暗一点（还能再问一遍）。
func set_topics(list: Array) -> void:
	build()
	for c in topic_box.get_children():
		topic_box.remove_child(c)
		c.queue_free()
	topic_title.visible = not list.is_empty()
	var only_look := not list.is_empty()
	for topic: Dictionary in list:
		if not bool(topic.get("observe", false)):
			only_look = false
	topic_title.text = tr("可以做的：") if only_look else tr("可以问的：")
	for topic: Dictionary in list:
		var tid := String(topic["id"])
		var seen := bool(topic.get("seen", false))
		var text := ("✓ " if seen else "• ") + String(topic["label"])
		var b := UiTheme.button(text, 18)
		b.custom_minimum_size = Vector2(0, 44)
		if seen:
			b.modulate = Color(1, 1, 1, 0.6)
		b.pressed.connect(func() -> void: topic_picked.emit(tid))
		topic_box.add_child(b)


## 话题按钮的个数（测试用）。
func topic_count() -> int:
	return topic_box.get_child_count() if topic_box != null else 0


## 供测试与验收脚本用：点第 index 个话题。
func press_topic(index: int) -> void:
	if topic_box == null or index < 0 or index >= topic_box.get_child_count():
		return
	(topic_box.get_child(index) as Button).pressed.emit()


## 能不能自由说话：对方听不见时（列车上的剧情人物）关掉输入框。
func set_free_text(enabled: bool) -> void:
	build()
	input.editable = enabled
	send_button.disabled = not enabled
	if not enabled:
		input.placeholder_text = "他们听不见你说话"
	else:
		set_mode(mode)


func clear_replies() -> void:
	if reply_box == null:
		return
	for c in reply_box.get_children():
		reply_box.remove_child(c)
		c.queue_free()


func _on_send(forced: String = "") -> void:
	if not input.editable:
		return
	var text := forced.strip_edges() if forced != "" else String(input.text).strip_edges()
	if text == "":
		return
	input.text = ""
	if mode == "persuade":
		persuading.emit(text)
	else:
		submitted.emit(text)


## 立绘位：有正式立绘（res://art/portraits/<id>.png）就用，没有退回像素头像。
func set_portrait(id: String) -> void:
	build()
	if id == "":
		portrait.texture = null
		portrait_caption.text = ""
		return
	portrait.texture = PortraitSource.portrait(id)
	if PortraitSource.has_portrait(id):
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	else:
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait_caption.text = ""


## 供测试与验收脚本用：等于点了"说"。
func press_send(text: String = "") -> void:
	_on_send(text)


## 供测试与验收脚本用：点第 index 个候选回复。
func press_reply(index: int) -> void:
	if reply_box == null or index < 0 or index >= reply_box.get_child_count():
		return
	var b: Button = reply_box.get_child(index)
	b.pressed.emit()


func press_close() -> void:
	_on_close()


func _on_close() -> void:
	hide()
	closed.emit()
```

- [ ] **Step 20：改写 `game/ui/main.gd`**

```gdscript
extends Control
## 游戏入口：标题画面 → 新游戏/读档 → 远征 → 战斗 → 结算 → 主神空间休整。
## 只做流程和换屏；远征与战斗的状态都在 Session / Expedition / Battle 里。
## 对话也在这里接线：AiService → Dialogue → 对话框，没配密钥就自动走离线兜底。
## PC 版外壳：标题画面、三个存档槽、设置、Esc 暂停菜单都在这里挂。

const Session = preload("res://core/session/session.gd")
const FieldScreen = preload("res://ui/field/field_screen.gd")
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
const Topics = preload("res://core/dialogue/topics.gd")
const TitleScreen = preload("res://ui/title_screen.gd")
const PauseMenu = preload("res://ui/pause_menu.gd")
const Sfx = preload("res://ui/audio/sfx.gd")
const Cutscene = preload("res://ui/cutscene.gd")
const PortraitSource = preload("res://ui/art/portrait_source.gd")
const Companion = preload("res://core/hub/companion.gd")

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
	FieldScreen.wide = bool(settings.get("field_wide", true))
	_show_title()


func _build_frame() -> void:
	UiTheme.paint_bg(self)
	bar = ColorRect.new()
	bar.color = UiTheme.PANEL
	bar.position = Vector2(0, 0)
	bar.size = Vector2(1920, 56)
	add_child(bar)
	header = UiTheme.label(tr("无限恐怖"), 24, UiTheme.ACCENT2)
	header.position = Vector2(30, 12)
	header.size = Vector2(1200, 34)
	add_child(header)

	menu_button = UiTheme.button(tr("菜单（Esc）"), 18)
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
	var screen := FieldScreen.new()
	screen.dialogue_store = session.dialogues
	screen.setup(session.expedition, _names())
	screen.view_changed.connect(_on_view_changed)
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
	screen.setup(b, String(session.expedition.st.pending_battle.get("location", "")))
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
	if session.phase == "lost":
		_show_lost()
		return
	Sfx.play("coin")
	_show_result(results)


## 全员死亡：没有主神空间可回。铁人模式删档（失败就是失败）；宽松模式可以回标题读档。
func _show_lost() -> void:
	_clear()
	var box := VBoxContainer.new()
	box.position = Vector2(300, 160)
	box.size = Vector2(1320, 700)
	box.add_theme_constant_override("separation", 16)
	content.add_child(box)
	box.add_child(UiTheme.label(tr("任务失败：全员死亡。"), 36, UiTheme.ACCENT))
	for id: String in session.game.characters:
		var ch: RefCounted = session.game.characters[id]
		box.add_child(UiTheme.label(tr("%s：%s") % [ch.display_name, EventText.death_text(String(ch.flags.get("death", ch.flags.get("erased", ""))))], 20, UiTheme.MUTED))
	if session.iron_man:
		Slots.erase(Slots.AUTO)
		box.add_child(UiTheme.label(tr("铁人模式：失败就是失败。这一局的存档已经删除。"), 22, UiTheme.TEXT))
	else:
		box.add_child(UiTheme.label(tr("宽松模式：回到标题，从存档槽读回去再试一次。"), 22, UiTheme.TEXT))
	var back := UiTheme.button(tr("回到标题"), 24)
	back.custom_minimum_size = Vector2(320, 60)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_show_title)
	box.add_child(back)
	_set_status("任务失败")


func _show_result(results: Dictionary) -> void:
	_clear()
	var box := VBoxContainer.new()
	box.position = Vector2(300, 90)
	box.size = Vector2(1320, 860)
	box.add_theme_constant_override("separation", 14)
	content.add_child(box)

	var title := UiTheme.label(tr("任务结束：%s") % EventText.ending_text(String(session.expedition.st.outcome)), 34, UiTheme.ACCENT2)
	box.add_child(title)
	box.add_child(UiTheme.label(tr("倒计时 %d 分钟 · 存活结算") % int(session.expedition.st.clock), 20, UiTheme.MUTED))
	var fr: Dictionary = session.film_report
	if not fr.is_empty():
		box.add_child(UiTheme.label(tr("幸存 %d/%d · 主神评价 %d → %d") % [int(fr["survivors"]), int(fr["members"]), int(fr["rating_before"]), int(fr["rating_after"])], 20, UiTheme.MUTED))
		var guide := String(fr.get("tour_guide", ""))
		if guide != "":
			box.add_child(UiTheme.label(tr("%s 带新人认识了光球和房间：规则百科新增 %d 条。") % [session.game.characters[guide].display_name, (fr.get("tour_entries", []) as Array).size()], 20, UiTheme.MUTED))
		else:
			box.add_child(UiTheme.label(tr("没有老手带你们认识主神空间，规矩只能自己去问主神。"), 20, UiTheme.MUTED))
	for id: String in results:
		var r: Dictionary = results[id]
		var name: String = session.game.characters[id].display_name if session.game.characters.has(id) else id
		if bool(r.get("dead", false)):
			box.add_child(UiTheme.label(tr("%s：死亡（%s）") % [name, EventText.death_text(String(r.get("reason", "")))], 22, UiTheme.MUTED))
			continue
		var line := "%s：%d 点" % [name, int(r["final_points"])]
		var tickets: Array = r.get("tickets", [])
		if not tickets.is_empty():
			line += " · " + "、".join(tickets) + " 级支线"
		box.add_child(UiTheme.label(line, 24, UiTheme.TEXT))
	var go := UiTheme.button(tr("进入主神空间"), 24)
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
	screen.companion_talk_requested.connect(_on_companion_talk)
	content.add_child(screen)
	_set_status("主神空间")


func _show_done() -> void:
	_clear()
	var box := VBoxContainer.new()
	box.position = Vector2(300, 160)
	box.size = Vector2(1320, 600)
	box.add_theme_constant_override("separation", 16)
	content.add_child(box)
	box.add_child(UiTheme.label(tr("二十道光柱降下。"), 36, UiTheme.ACCENT2))
	for f: Dictionary in session.farewells:
		box.add_child(UiTheme.label(tr("%s：「%s」") % [String(f["name"]), String(f["line"])], 24, UiTheme.TEXT))
	box.add_child(UiTheme.label(tr("下一部：异形一（内容与界面在后续计划里做）。"), 22, UiTheme.TEXT))
	var back := UiTheme.button(tr("回到标题"), 24)
	back.custom_minimum_size = Vector2(320, 60)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_show_title)
	box.add_child(back)
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


func _new_game(iron: bool = false) -> void:
	title_screen = null
	session = Session.new()
	session.start_m1(1, iron)
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
	pause.set_iron_man(session.iron_man)
	pause.open_for("")


func _close_pause() -> void:
	if pause == null:
		return
	pause.queue_free()
	pause = null


func _on_save_slot(slot: int) -> void:
	if session == null or not session.can_save_manually():
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
	if session == null or String(session.phase) == "done" or String(session.phase) == "lost":
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


## 探索画面切换了视野：存进设置，下次进来还是这一档。
func _on_view_changed(wide: bool) -> void:
	settings["field_wide"] = wide
	Settings.save_settings(settings)


func _on_talk(npc_id: String) -> void:
	var title: String = dialogue.display_name(npc_id)
	_open_panel(title, "%s · 第 %d 分钟" % [_location_name(), int(session.expedition.st.clock)], "talk")
	var p: Control = panel
	p.set_portrait(npc_id)
	p.topic_picked.connect(_on_topic.bind(npc_id))
	_refresh_topics(npc_id, p)
	if not Topics.can_hear(session.expedition.st, npc_id):
		p.set_free_text(false)
		p.set_status("列车减速之前，剧情人物听不见轮回者说话。现在只能看看他们。")
		return
	p.set_status("……")
	dialogue.say(npc_id, "", _situation(), func(res: Dictionary) -> void:
		if panel != p:
			return
		p.push(title, String(res["say"]))
		p.set_status(_source_text(String(res["source"])))
	)
	p.submitted.connect(_on_said.bind(npc_id))


## 对话框里的固定话题：能聊的都列出来（聊过的也还能再问）。
func _refresh_topics(npc_id: String, p: Control) -> void:
	if p == null or session.expedition == null:
		return
	p.set_topics(Topics.available(session.expedition.st, npc_id, dialogue.trust_of(npc_id)))


## 点了一个固定话题：对方照写好的话回答；第一次聊算一次交谈（信任 +1），并跑话题的效果（线索、旗标……）。
func _on_topic(topic_id: String, npc_id: String) -> void:
	var p: Control = panel
	if p == null:
		return
	var st: RefCounted = session.expedition.st
	var hear := Topics.can_hear(st, npc_id)
	var t: Dictionary = Topics.find(st, npc_id, topic_id)
	var res: Dictionary = session.expedition.talk_topic(npc_id, topic_id, dialogue.trust_of(npc_id))
	if res.is_empty():
		return
	if hear:
		p.push("我", String(t.get("label", "")))
		p.push(dialogue.display_name(npc_id), String(res["text"]))
	else:
		p.push("（你看了看）", String(res["text"]))
	_push_events(res["events"], p)
	if bool(res["new"]) and hear:
		_after_said(npc_id, p)
	else:
		var screen := _expedition_screen()
		if screen != null:
			screen.refresh()
	_refresh_topics(npc_id, p)


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


## 在房间里跟造物说话：人设来自造人时的设定（萝丽是 luo_li）；每天第一次说话涨亲密。
func _on_companion_talk(companion_id: String) -> void:
	var c := Companion.find(session.game, companion_id)
	var persona := String(c.get("persona", ""))
	if c.is_empty() or persona == "" or not dialogue.has_persona(persona):
		return
	_open_panel(String(c["name"]), "主神空间 · %s的房间" % session.game.characters[String(c["creator"])].display_name, "talk")
	var p: Control = panel
	p.set_portrait(persona)
	p.set_status("……")
	dialogue.say(persona, "", _room_situation(c), func(res: Dictionary) -> void:
		if panel != p:
			return
		p.push(String(c["name"]), String(res["say"]))
		p.set_status(_source_text(String(res["source"])))
	)
	p.submitted.connect(_on_companion_said.bind(companion_id))


func _on_companion_said(text: String, companion_id: String) -> void:
	var p: Control = panel
	var c := Companion.find(session.game, companion_id)
	if p == null or c.is_empty():
		return
	p.push("我", text)
	p.set_status("……")
	dialogue.say(String(c["persona"]), text, _room_situation(c), func(res: Dictionary) -> void:
		if panel != p:
			return
		p.push(String(c["name"]), String(res["say"]))
		p.set_status(_source_text(String(res["source"])))
		_push_events(session.hub.companion_talked(companion_id), p)
		var screen := content.get_child(0) if content.get_child_count() > 0 else null
		if screen != null and screen.has_method("press_visit"):
			screen.refresh()
	)


func _room_situation(c: Dictionary) -> String:
	return "主神空间，%s的房间。休整第 %d 天，再过 %d 天就要进下一部片。她现在的心情 %d、亲密 %d，她想：%s。" % [
		session.game.characters[String(c["creator"])].display_name, int(session.hub.day), int(session.hub.days_left()),
		int(float(c["mood"])), int(float(c["intimacy"])), Companion.wish(c)]


func _zhushen_faq() -> Array:
	var res := DataLoader.load_json(ZHSHEN_FAQ)
	if not res.ok:
		return []
	return (res.data as Dictionary).get("faq", [])
```

- [ ] **Step 21：改写 `game/tools/field_capture.gd`**

```gdscript
extends SceneTree
## 计划 21 / 任务卡 007：给探索画面截图，看地图、行走图、灯光放进游戏里是什么样子。
## 用法（要窗口，不能 --headless）：godot --path game -s res://tools/field_capture.gd
## 输出：仓库根目录 art_src/qa/field_<序号>_<内容>.png（1920×1080）：开场对话框，八个地点各一张，
## 然后列车上的近视野、"在场的人"名单、瑞恩的人物卡（计划 23）。
## 只截图，不写存档。截地点时直接把分队放到那个地点（跳过路上的剧情和战斗），剧情人物按开局的位置站；
## 站台大厅那张把车上的剧情人物也挪下车（和真玩时一样，他们跟你们一起下车）。

const Session = preload("res://core/session/session.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const FieldScreen = preload("res://ui/field/field_screen.gd")

const SCENARIO := "res://data/scenarios/biohazard1/scenario.json"

var n := 0


func _initialize() -> void:
	_run.call_deferred()


func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	n += 1
	var dir := ProjectSettings.globalize_path("res://").path_join("../art_src/qa")
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("field_%02d_%s.png" % [n, name])
	root.get_texture().get_image().save_png(path)
	print("截图 ", path)


func _field(s: RefCounted) -> Control:
	var names := {}
	for id: String in s.game.characters:
		names[id] = s.game.characters[id].display_name
	var f := FieldScreen.new()
	root.add_child(f)
	f.setup(s.expedition, names)
	return f


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	var s := Session.new()
	s.start_m1(1)
	var f := _field(s)
	await create_timer(1.6).timeout
	await _shot("car_opening")
	f.queue_free()
	await process_frame
	var locations: Dictionary = Scenario.load_file(SCENARIO).data["locations"]
	for loc: String in locations:
		var s2 := Session.new()
		s2.start_m1(1)
		var g := _field(s2)
		g.press_choice("listen")
		g.flush_messages()
		var sid: String = g.view.squad_id()
		s2.expedition.st.squads[sid]["location"] = loc
		if loc == "hall":
			for npc_id: String in s2.expedition.st.npcs:
				if String(s2.expedition.st.npcs[npc_id]["location"]) == "car":
					s2.expedition.st.npcs[npc_id]["location"] = "hall"
		g.refresh()
		g.flush_messages()
		g._show_next()
		await create_timer(0.9).timeout
		await _shot(loc)
		g.queue_free()
		await process_frame
	var s3 := Session.new()
	s3.start_m1(1)
	var h := _field(s3)
	h.press_choice("listen")
	h.flush_messages()
	h._show_next()
	h.set_wide(false)
	await create_timer(1.8).timeout
	await _shot("car_near_spread")
	h.set_wide(true)
	h.open_roster()
	await _shot("car_roster")
	s3.expedition.talk_topic("ryan", "ryan_look", 0)
	h.open_card("ryan")
	await _shot("car_card_ryan")
	h.queue_free()
	await process_frame
	print("共截图 ", n)
	quit(0)
```

- [ ] **Step 22：运行，确认通过；导入工程生成新脚本的 `.uid`**

```bash
bash game/tools/run_tests.sh > _work/p23_task2.txt 2>&1; echo "exit=$?"; tail -1 _work/p23_task2.txt; echo "SCRIPT ERROR: $(grep -c 'SCRIPT ERROR' _work/p23_task2.txt)"
godot --headless --path game --import > _work/p23_imp.txt 2>&1; echo "import exit=$?"
git status --short game
```

预期：`共 497 个测试，失败 0 个`、`SCRIPT ERROR: 0`、`import exit=0`；`git status` 列出两个新 `.uid`（`topics.gd.uid`、`test_topics.gd.uid`）。

- [ ] **Step 23：提交**

```bash
git add game/core/dialogue/topics.gd game/core/dialogue/topics.gd.uid game/data/scenarios/biohazard1/topics.json game/core/expedition/expedition_state.gd game/core/expedition/expedition.gd game/data/scenarios/biohazard1/scenario.json game/data/ai/personas.json game/core/settings/settings.gd game/ui/field/tiled_map.gd game/data/maps/biohazard1/car.tmj game/data/maps/biohazard1/hall.tmj game/ui/field/field_screen.gd game/ui/dialogue/dialogue_panel.gd game/ui/main.gd game/tools/field_capture.gd game/tests/unit/dialogue/test_topics.gd game/tests/unit/dialogue/test_topics.gd.uid game/tests/unit/ui/test_field.gd game/tests/unit/ui/test_tiled_map.gd game/tests/unit/dialogue/test_dialogue_panel.gd game/tests/unit/settings/test_settings.gd game/tests/unit/ai/test_persona.gd
git commit -m "feat: 计划 23 人和空间：四节车厢的列车和站台大厅、两档视野、队友散开和让路、在场的人名单、人物卡、13 个人照原著写的固定话题" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩本计划之外的未跟踪文件（`_work/`、OhMyGame 的 `canvas/`、`.ohmygame/`、`ohmygame.json`）。

---

## Task 3：验收

- [ ] **Step 1：本机把瑞恩那张错的立绘挪出游戏（不进仓库）**

原著里瑞恩是男的商业间谍，本机那张女雇佣兵立绘留给以后的女医务兵（设计第 9 节）。图片和 Godot 的导入记录一起挪走，否则游戏还会读到导入缓存。

Run: `mkdir -p art_src/retired && mv game/art/portraits/ryan.png game/art/portraits/ryan.png.import art_src/retired/ && ls art_src/retired && git status --short art_src game/art`

预期：列出 `ryan.png`、`ryan.png.import`；`git status` 没有输出（图片和导入记录都被 `.gitignore` 忽略）。之后瑞恩的对话框和人物卡显示像素头像，直到新立绘出来。

- [ ] **Step 2：在改名的副本里跑切片验收**

```bash
rm -rf _work/p23_verify && mkdir -p _work/p23_verify && cp -r game _work/p23_verify/game
sed -i 's/^config\/name=.*/config\/name="无限恐怖_验收p23"/' _work/p23_verify/game/project.godot
timeout 300 godot --headless --path _work/p23_verify/game -s res://tools/verify_m1_slice.gd 2>&1 | tail -1; echo "exit=${PIPESTATUS[0]}"
```

预期：`M1 切片验证：失败 0 项`，`exit=0`。

- [ ] **Step 3：窗口模式截图看一遍**

Run: `rm -f art_src/qa/field_*.png; timeout 240 godot --path game -s res://tools/field_capture.gd 2>&1 | tail -1`

预期：`共截图 12`。`field_02_car.png` 是四节车厢的列车，七个剧情人物站在第二节车厢；`field_03_hall.png` 是站台连入口大厅，队伍在车门边，雇佣兵在站台上；`field_10_car_near_spread.png` 是近视野、队友散开；`field_11_car_roster.png` 名单 14 行都在屏幕里；`field_12_car_card_ryan.png` 写着"郑吒认得他：电影里偷 T 病毒的商业间谍"。

- [ ] **Step 4：更新 README 进度并提交**

```bash
python -I -X utf8 - <<'EOF'
p = "README.md"
s = open(p, encoding="utf-8").read()
o = "- 制作节奏：按原著顺序"
n = "- 计划 23（人和空间：四节车厢的列车、站台连入口大厅按人群尺度重画；远 / 近两档视野（V）；队友散开、归队，剧情人物让路；T 打开在场的人名单；人物卡；在场 13 个人照原著写的 43 个固定话题，车减速前剧情人物听不见你们；按原著改正人设）已完成，累计 497 个无界面测试。\n" + o
assert s.count(o) == 1
open(p, "w", encoding="utf-8", newline="\n").write(s.replace(o, n))
print("ok")
EOF
git add README.md
git commit -m "docs: 计划 23 完成，更新进度" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log --oneline -5
git status --short
```

- [ ] **Step 5：验收检查**

```bash
grep -c $'\r' game/core/dialogue/topics.gd game/ui/field/field_screen.gd game/data/scenarios/biohazard1/topics.json game/data/maps/biohazard1/car.tmj
for f in core/dialogue/topics.gd data/scenarios/biohazard1/topics.json core/expedition/expedition_state.gd core/expedition/expedition.gd data/scenarios/biohazard1/scenario.json data/ai/personas.json core/settings/settings.gd ui/field/tiled_map.gd data/maps/biohazard1/car.tmj data/maps/biohazard1/hall.tmj ui/field/field_screen.gd ui/dialogue/dialogue_panel.gd ui/main.gd tools/field_capture.gd tests/unit/dialogue/test_topics.gd tests/unit/ui/test_field.gd tests/unit/ui/test_tiled_map.gd tests/unit/dialogue/test_dialogue_panel.gd tests/unit/settings/test_settings.gd tests/unit/ai/test_persona.gd; do cmp -s "game/$f" "_work/plan_check_p23/game/$f" || echo "DIFF $f"; done
echo "compare done"
test -z "$(git diff --name-only origin/main..HEAD | grep -iE '\.(png|jpe?g|webp|gif|wav|ogg)$')" && echo "no media"
```

预期：四个 `grep -c` 都是 `0`；`compare done` 前没有 `DIFF`；`no media`。
