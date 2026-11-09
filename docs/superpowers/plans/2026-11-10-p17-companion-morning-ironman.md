# 计划 17：萝丽陪伴、晨会与铁人模式 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 补上 M1 核查列出的三块体验缺口：萝丽只是一条造人记录，没有心情、亲密、对话和出征反应（规格 6.6 的 M1 要求）；第 2~8 天的晨会事件（结盟、新人去留，规格 9.6）一件都没有；规格 7.7 推荐的铁人模式没有实现，全灭以后还会领着一队死人进主神空间。

**Architecture:** 新增两个纯规则模块：`core/hub/companion.gd`（造物的心情、亲密、依赖、安心，陪她、一起训练、说话、每天的变化、出征反应）和 `core/hub/morning.gd`（按条件从章节事件表里挑当天的晨会、套用选项效果）。`Hub` 负责耗天和每天早上的结算：陪伴耗 1 天，晨会不理会就第二天按默认选项了结。`Session` 加铁人标志、全灭进 `lost` 阶段、制造者死亡时造物消失、走光柱时收集造物的告别。界面：主神空间顶部显示晨会，造人页变成造物页（数值、愿望、三个行动），能和萝丽 AI 对话；标题画面新游戏先选铁人或宽松；铁人模式的暂停菜单没有存读档；全灭显示失败画面，铁人模式删档。

**Tech Stack:** Godot 4.7.2（GDScript）、JSON 数据（晨会事件表、萝丽人设）、已有的对话层与关系网。

**依据：** 设计规格 6.6（人造人陪伴；M1：郑吒造萝丽、房间里的 AI 对话、心情与亲密度、她对出征的反应；制造者死亡造物消失）、6.1 与 9.6（广场晨会：结盟、新人去留）、7.7（推荐铁人模式，另给宽松选项）。

**本计划已在临时目录跑通：451 个无界面测试全过、`SCRIPT ERROR 0`、M1 切片验收 0 失败、40 局随机乱玩无卡死。**

**执行环境注意：**
- 仓库根目录：`I:\workspace\mobilegame\wuxian-kongbu\`；命令都在仓库根目录执行（Git Bash）。
- 只跑某个测试：`WSLENV=TEST_FILTER TEST_FILTER=<文件名> bash game/tools/run_tests.sh`。
- 文本文件 **LF**、UTF-8 无 BOM；GDScript 用 **Tab**。
- 跑测试不生成 `.gd.uid`，导入工程（Task 2）才会。
- **只提交，不推送。**
- 临时验证目录是 `_work/plan_check_p17/game`。
- **切片验收会清空 `user://` 下的三个存档槽**，只在改了工程名的副本里跑（Task 2 Step 9）。

---

## 设计要点

- **萝丽的四个数**（0~100）：心情 60、亲密 50、依赖 40、安心 40 起步。陪她一天：亲密 +10、心情 +15、安心 +10，郑吒恐惧 −10；一起训练：依赖 −5、其余各 +5，郑吒恐惧 −5；说话：每天第一次亲密 +3、心情 +5。连着两天以上没人陪，心情每天 −4。亲密到 60，她成了"锚"，郑吒休整时每天恐惧多降 5。
- **她想要什么**由数值推出来（心情低想你陪她、依赖高想跟着进片、安心低担心你回不来……），显示在造物页，也写进 AI 对话的局面说明。
- **出征反应**：亲密 ≥ 70 且心情不差时说"早点回来。我会一直等你。"并让郑吒恐惧 −10；心情低时埋怨不带她；安心低时要他答应回来。结尾画面逐个显示。
- **造物跟着制造者**：制造者死在片里，下一次结算时造物和房间一起消失，名字记进总评。
- **晨会是数据**：`data/hub/m1_morning.json` 六件——张杰提议结盟 / 张杰死了没人带、新人想退出、萝丽见大家、詹岚来谈主神、新人来借点数。条件用活着、死了、"其中有人活着"（{who} 填进文本）、有没有造物、点数够不够；效果落到关系网、恐惧、点数、规则百科、造物数值。每天早上最多一件、每件一次；不回答也不拦着玩家，第二天早上按默认选项了结；出发那天没有晨会。
- **铁人模式**：一个自动存档，暂停菜单没有存读档，`Session.can_save_manually()` 为假；全员死亡进 `lost`，失败画面删掉自动档。宽松模式就是原来的三个手动槽，全灭时回标题读档。旧存档没有 `iron_man` 字段，按宽松读。

**不在本计划范围**：约会、教她技能、带她度假或回现实（M3）；入片义务与赎身（M6）；按记忆重造（以后）；心魔检定里的"锚"（第四阶）；晨会里的投票（M2）；像素战斗画面（计划 18）；文档对齐、平衡、`tr()`（计划 19）。

---

## 文件结构

| 文件 | 职责 |
|---|---|
| `game/core/hub/companion.gd` | 造物的四个数、三个行动、每天变化、愿望、出征反应 |
| `game/core/hub/morning.gd` | 按条件挑晨会、填 {who}、套用效果 |
| `game/data/hub/m1_morning.json` | M1 的六件晨会 |
| `game/data/ai/personas.json` | 新增萝丽的人设 |
| `game/data/scenarios/biohazard1/chapter.json` | 章节指向晨会事件表 |
| `game/core/hub/hub.gd` | 造人带人设；陪伴行动耗天；每天早上的晨会；存读档 |
| `game/core/session/session.gd` | 铁人标志；全灭进 lost；造物跟着制造者；走光柱时的告别 |
| `game/ui/hub/hub_view.gd`、`game/ui/hub/hub_screen.gd` | 晨会框；造物页的数值、愿望和三个行动 |
| `game/ui/event_text.gd` | 说话涨亲密的文案 |
| `game/ui/title_screen.gd` | 新游戏先选铁人或宽松 |
| `game/ui/pause_menu.gd` | 铁人模式藏起存读档 |
| `game/ui/main.gd` | 开局模式、失败画面与删档、和萝丽对话、结尾的告别 |
| `game/tools/verify_m1_slice.gd` | 切片验收：选宽松模式、回答晨会、看到萝丽的告别 |

---

## Task 1：陪伴、晨会与铁人模式的规则

**Files:**
- Create: `game/core/hub/companion.gd`、`game/core/hub/morning.gd`、`game/data/hub/m1_morning.json`
- Modify: `game/data/ai/personas.json`、`game/data/scenarios/biohazard1/chapter.json`、`game/core/hub/hub.gd`、`game/core/session/session.gd`
- Test: `game/tests/unit/hub/test_companion.gd`（新）、`game/tests/unit/hub/test_morning.gd`（新）、`game/tests/unit/session/test_session.gd`

- [ ] **Step 1：写测试 `game/tests/unit/hub/test_companion.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Companion = preload("res://core/hub/companion.gd")
const Character = preload("res://core/model/character.gd")
const Session = preload("res://core/session/session.gd")


func _lori() -> Dictionary:
	var c := {"id": "zheng_zha_human_1", "name": "萝丽", "creator": "zheng_zha", "attributes": {}}
	Companion.init_fields(c, "luo_li", 0)
	return c


## 刚造出来：心情 60、亲密 50、依赖 40、安心 40，人设 luo_li。
func test_init_fields() -> void:
	var c := _lori()
	assert_almost(float(c["mood"]), 60.0)
	assert_almost(float(c["intimacy"]), 50.0)
	assert_eq(String(c["persona"]), "luo_li")
	assert_eq(Companion.wish(c), "想知道你每天在练什么")


## 陪她一天、一起训练、说话：各自改哪些数，制造者恐惧怎么降；说话每天只算一次。
func test_actions() -> void:
	var c := _lori()
	var zz := Character.new("zheng_zha", "郑吒", {})
	zz.fear = 30.0
	Companion.visit(c, zz, 1)
	assert_almost(float(c["intimacy"]), 60.0)
	assert_almost(float(c["mood"]), 75.0)
	assert_almost(zz.fear, 20.0)
	Companion.train_together(c, zz, 2)
	assert_almost(float(c["dependence"]), 35.0)
	assert_almost(zz.fear, 15.0)
	assert_eq(Companion.talked(c, 2).size(), 1)
	assert_eq(Companion.talked(c, 2).size(), 0, "同一天只算一次")
	assert_almost(float(c["intimacy"]), 68.0)


## 好几天没人陪，心情往下掉；亲密够高时，制造者每天恐惧多降 5。
func test_day_passed() -> void:
	var c := _lori()
	var zz := Character.new("zheng_zha", "郑吒", {})
	zz.fear = 20.0
	Companion.day_passed(c, zz, 2)
	assert_almost(float(c["mood"]), 60.0, 0.0001, "两天内不算孤单")
	Companion.day_passed(c, zz, 3)
	assert_almost(float(c["mood"]), 56.0)
	assert_almost(zz.fear, 20.0, 0.0001, "亲密 50 还不够当锚")
	c["intimacy"] = 65.0
	Companion.day_passed(c, zz, 4)
	assert_almost(zz.fear, 15.0)


## 出征时的反应随亲密和心情变；亲密又开心时，她是锚，制造者恐惧 −10。
func test_farewell() -> void:
	var c := _lori()
	assert_eq(String(Companion.farewell(c)["line"]), "路上小心。回来给我讲讲。")
	c["intimacy"] = 80.0
	var f := Companion.farewell(c)
	assert_eq(String(f["line"]), "早点回来。我会一直等你。")
	assert_almost(float(f["fear"]), -10.0)
	c["mood"] = 30.0
	assert_eq(String(Companion.farewell(c)["line"]), "你又要走了……这次也不带我。")
	assert_eq(Companion.wish(c), "想你多陪陪她")


func _hub_session() -> RefCounted:
	var s := Session.new()
	s.start_m1(1)
	s.expedition.st.outcome = "returned"
	s.settle()
	s.enter_hub()
	return s


## 休整里：造萝丽带上陪伴字段；陪她、一起训练各耗 1 天，最后一天不行；说话不耗天。
func test_hub_actions() -> void:
	var s := _hub_session()
	s.hub.create_human("zheng_zha", "萝丽", {"spirit": 120}, "luo_li")
	var id := String(s.game.companions[0]["id"])
	assert_eq(String(s.game.companions[0]["persona"]), "luo_li")
	var events: Array[Dictionary] = s.hub.visit_companion(id)
	assert_eq(String(events[0]["type"]), "companion_visited")
	assert_eq(s.hub.day, 1)
	s.hub.train_with_companion(id)
	assert_eq(s.hub.day, 2)
	assert_eq(s.hub.companion_talked(id).size(), 1)
	assert_eq(s.hub.day, 2)
	s.hub.day = 8
	assert_eq(String(s.hub.visit_companion(id)[0]["reason"]), "no_days")
	assert_eq(String(s.hub.visit_companion("nope")[0]["reason"]), "no_companion")


## 走光柱：萝丽说一句话，亲密高时郑吒更安心；九天没人陪她会难过；造物随存档走。
func test_depart_farewell() -> void:
	var s := _hub_session()
	s.hub.create_human("zheng_zha", "萝丽", {}, "luo_li")
	s.game.companions[0]["intimacy"] = 90.0
	s.game.characters["zheng_zha"].fear = 30.0
	s.hub.rest(9)
	assert_almost(float(s.game.companions[0]["mood"]), 60.0 - 7 * 4.0 - 5.0, 0.0001, "第 3~9 天没人陪每天 −4；晨会没人理，按默认让她回房间又 −5")
	s.game.companions[0]["mood"] = 80.0
	assert_true(s.depart())
	assert_eq(s.farewells.size(), 1)
	assert_eq(String(s.farewells[0]["line"]), "早点回来。我会一直等你。")
	assert_almost(s.game.characters["zheng_zha"].fear, 0.0, 0.0001, "休整九天恐惧早就降到 0，锚只是让它别往上走")
	var t := Session.new()
	assert_true(t.load_dict(s.to_dict()))
	assert_eq(t.farewells, s.farewells)


## 制造者死在片里，造物和房间一起消失（下一次结算时）。
func test_companion_follows_creator() -> void:
	var s := Session.new()
	s.start_m1(1)
	s.game.companions.append({"id": "zheng_zha_human_1", "name": "萝丽", "creator": "zheng_zha", "attributes": {}})
	s.game.characters["zheng_zha"].alive = false
	s.expedition.st.outcome = "returned"
	s.settle()
	assert_eq(s.game.companions, [])
	assert_eq(s.film_report["companions_lost"], ["萝丽"])
```

- [ ] **Step 2：写测试 `game/tests/unit/hub/test_morning.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Morning = preload("res://core/hub/morning.gd")
const Session = preload("res://core/session/session.gd")

const EVENTS := "res://data/hub/m1_morning.json"


func _session() -> RefCounted:
	var s := Session.new()
	s.start_m1(1)
	s.expedition.st.outcome = "returned"
	s.settle()
	s.enter_hub()
	return s


## 挑事件看条件：张杰活着是"结盟"，死了是"没有老手的早晨"；新人去留挑第一个活着的新人，名字填进去。
func test_pick_by_conditions() -> void:
	var s := _session()
	var events: Array = Morning.load_events(EVENTS)
	assert_eq(String(Morning.pick(s.game, events, 1, [])["id"]), "zhang_jie_alliance")
	s.game.characters["zhang_jie"].alive = false
	assert_eq(String(Morning.pick(s.game, events, 1, [])["id"]), "no_veteran")
	s.game.characters["li_xiao_yi"].alive = false
	var ev := Morning.pick(s.game, events, 2, ["no_veteran"])
	assert_eq(String(ev["id"]), "newbie_stays")
	assert_eq(String(ev["who"]), "mu_gang")
	assert_true(String(ev["prompt"]).begins_with("牟钢"))
	assert_eq(Morning.pick(s.game, events, 1, ["no_veteran", "zhang_jie_alliance"]), {}, "第 1 天只有前两件够格")


## 新人都死了：新人去留和借点数都不会发生。
func test_skip_when_nobody_fits() -> void:
	var s := _session()
	for c in ["li_xiao_yi", "mu_gang", "xiao_pang_zi", "zhong_nian_fu_nv"]:
		s.game.characters[c].alive = false
	var events: Array = Morning.load_events(EVENTS)
	var seen := ["zhang_jie_alliance", "zhan_lan_talk"]
	assert_eq(Morning.pick(s.game, events, 9, seen), {})


## 效果：借点数真的转账、关系和恐惧照选项变、百科解锁。
func test_apply_effects() -> void:
	var s := _session()
	var events: Array = Morning.load_events(EVENTS)
	var help := Morning.pick(s.game, events, 4, ["zhang_jie_alliance", "newbie_stays", "zhan_lan_talk"])
	assert_eq(String(help["id"]), "points_help")
	var who := String(help["who"])
	var before: int = s.game.characters["zheng_zha"].points
	var out: Array[Dictionary] = Morning.apply(s.game, help, "give")
	assert_eq(String(out[0]["type"]), "morning_answered")
	assert_eq(s.game.characters["zheng_zha"].points, before - 500)
	assert_eq(s.game.characters[who].points, 1500)
	assert_almost(s.game.relations.value(who, "zheng_zha", "trust"), 65.0)
	var talk := Morning.pick(s.game, events, 3, ["zhang_jie_alliance", "newbie_stays"])
	Morning.apply(s.game, talk, "listen")
	assert_true(s.game.codex.is_known("team_rating"))
	assert_eq(String(Morning.apply(s.game, talk, "nope")[0]["type"]), "morning_refused")


## 休整里：第 1 天早上有晨会；回答后收起；不回答的话第二天早上按默认了结，然后出新的；每件只发生一次；存读档保留。
func test_hub_flow() -> void:
	var s := _session()
	var ev: Array[Dictionary] = s.hub.rest(1)
	assert_true(_has(ev, "morning_event"))
	assert_eq(String(s.hub.morning["id"]), "zhang_jie_alliance")
	var ans: Array[Dictionary] = s.hub.answer_morning("own_way")
	assert_eq(String(ans[0]["type"]), "morning_answered")
	assert_true(s.hub.morning.is_empty())
	assert_almost(s.game.relations.value("zhang_jie", "zheng_zha", "trust"), 45.0)
	ev = s.hub.rest(1)
	assert_eq(String(s.hub.morning["id"]), "newbie_stays")
	ev = s.hub.rest(1)
	var auto := false
	for e in ev:
		if e["type"] == "morning_answered" and bool(e["auto"]):
			auto = true
			assert_eq(String(e["option"]), "let_go")
	assert_true(auto, "没回答的晨会第二天按默认选项了结")
	var t := Session.new()
	assert_true(t.load_dict(s.to_dict()))
	assert_eq(t.hub.morning, s.hub.morning)
	assert_eq(t.hub.morning_seen, s.hub.morning_seen)
	s.hub.rest(6)
	assert_eq(s.hub.morning_seen, ["zhang_jie_alliance", "newbie_stays", "zhan_lan_talk", "points_help"], "张杰活着、萝丽没造出来，这两件不发生")
	assert_true(s.hub.morning.is_empty(), "出发那天没有晨会")


func _has(events: Array[Dictionary], type: String) -> bool:
	for e in events:
		if String(e["type"]) == type:
			return true
	return false
```

- [ ] **Step 3：改写 `game/tests/unit/session/test_session.gd`**

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


## 铁人模式：随存档走；不能手动存档。宽松模式可以。
func test_iron_man_flag() -> void:
	var a := Session.new()
	a.start_m1(1, true)
	assert_true(a.iron_man)
	assert_true(a.game.iron_man)
	assert_false(a.can_save_manually())
	var b := Session.new()
	assert_true(b.load_dict(a.to_dict()))
	assert_true(b.iron_man)
	var c := Session.new()
	c.start_m1(1)
	assert_true(c.can_save_manually())
	var old: Dictionary = c.to_dict()
	old.erase("iron_man")
	var d := Session.new()
	assert_true(d.load_dict(old))
	assert_false(d.iron_man, "旧存档没有这个字段，按宽松模式读")


## 全员死亡：结算后进 lost，没有主神空间；lost 也能存读。
func test_wipe_is_lost() -> void:
	var s := Session.new()
	s.start_m1(1)
	for c: String in s.game.characters:
		s.game.characters[c].alive = false
	s.expedition.st.outcome = "wiped"
	assert_true(s.lost())
	s.settle()
	assert_eq(s.phase, "lost")
	assert_true(s.hub == null)
	assert_false(s.enter_hub())
	var t := Session.new()
	assert_true(t.load_dict(s.to_dict()))
	assert_eq(t.phase, "lost")


func test_reject_bad_save() -> void:
	assert_false(Session.new().load_dict({"version": 99}))
	assert_false(Session.new().load_dict({"version": 1, "chapter": "res://nope.json", "game": {}}))
	assert_true(Session.load_from("user://nope.json") == null)
```

- [ ] **Step 4：运行，确认失败**

Run: `bash game/tools/run_tests.sh | tail -3`

预期：两份新测试因为 `companion.gd` / `morning.gd` 还不存在而加载失败，`test_session.gd` 的铁人和全灭测试失败；只要不是全部通过就对。

- [ ] **Step 5：创建 `game/core/hub/companion.gd`**

```gdscript
extends RefCounted
## 人造人陪伴（设计规格 6.6；M1：郑吒造萝丽、心情与亲密度、她对出征的反应、房间里的 AI 对话）。
## 造物记在 GameState.companions，每条是字典：
##   {"id", "name", "creator", "attributes", "persona",
##    "mood" 心情, "intimacy" 亲密, "dependence" 依赖, "security" 安心（都是 0~100）,
##    "last_visit_day" 最近一次陪她是第几天, "talked_day" 最近一次说话是第几天}
## 这里只有纯函数：改字典、改制造者的恐惧、返回事件。耗不耗天由 hub.gd 决定。

const DEFAULTS := {"mood": 60.0, "intimacy": 50.0, "dependence": 40.0, "security": 40.0}
## 亲密到这里，制造者休整时恐惧多降一些（她是"锚"）。
const ANCHOR_INTIMACY := 60.0
const ANCHOR_RELIEF := 5.0
## 连着几天没人陪，心情开始往下掉。
const LONELY_AFTER_DAYS := 2
const LONELY_MOOD := 4.0


## 新造出来的人：补上陪伴字段。persona 是对话层的人设 id（萝丽是 luo_li）。
static func init_fields(c: Dictionary, persona: String, day: int) -> void:
	for k: String in DEFAULTS:
		c[k] = DEFAULTS[k]
	c["persona"] = persona
	c["last_visit_day"] = day
	c["talked_day"] = -1


static func find(game: RefCounted, companion_id: String) -> Dictionary:
	for c: Dictionary in game.companions:
		if String(c["id"]) == companion_id:
			return c
	return {}


static func _bump(c: Dictionary, deltas: Dictionary) -> void:
	for k: String in deltas:
		c[k] = clampf(float(c.get(k, DEFAULTS.get(k, 50.0))) + float(deltas[k]), 0.0, 100.0)


## 陪她待一天：亲密 +10、心情 +15、安心 +10；制造者恐惧 −10。
static func visit(c: Dictionary, creator: RefCounted, day: int) -> Array[Dictionary]:
	_bump(c, {"intimacy": 10.0, "mood": 15.0, "security": 10.0})
	c["last_visit_day"] = day
	creator.fear = maxf(0.0, creator.fear - 10.0)
	return [{"type": "companion_visited", "companion": String(c["id"]), "name": String(c["name"]), "mood": c["mood"], "intimacy": c["intimacy"]}]


## 一起训练：她觉得自己帮得上忙（依赖 −5、安心 +5、亲密 +5、心情 +5）；制造者恐惧 −5。
static func train_together(c: Dictionary, creator: RefCounted, day: int) -> Array[Dictionary]:
	_bump(c, {"intimacy": 5.0, "mood": 5.0, "dependence": -5.0, "security": 5.0})
	c["last_visit_day"] = day
	creator.fear = maxf(0.0, creator.fear - 5.0)
	return [{"type": "companion_trained", "companion": String(c["id"]), "name": String(c["name"]), "dependence": c["dependence"], "intimacy": c["intimacy"]}]


## 说了一次话（AI 对话或离线台词）：每天只算一次，亲密 +3、心情 +5。
static func talked(c: Dictionary, day: int) -> Array[Dictionary]:
	if int(c.get("talked_day", -1)) == day:
		return []
	c["talked_day"] = day
	_bump(c, {"intimacy": 3.0, "mood": 5.0})
	return [{"type": "companion_talked", "companion": String(c["id"]), "name": String(c["name"]), "intimacy": c["intimacy"]}]


## 过了一天：连着两天以上没人陪，心情 −4；亲密够高时制造者恐惧多降 5。
static func day_passed(c: Dictionary, creator: RefCounted, day: int) -> void:
	if day - int(c.get("last_visit_day", day)) > LONELY_AFTER_DAYS:
		_bump(c, {"mood": -LONELY_MOOD})
	if float(c["intimacy"]) >= ANCHOR_INTIMACY and creator != null and creator.alive:
		creator.fear = maxf(0.0, creator.fear - ANCHOR_RELIEF)


## 她现在想要什么（界面显示一句）。
static func wish(c: Dictionary) -> String:
	if float(c["mood"]) < 40.0:
		return "想你多陪陪她"
	if float(c["dependence"]) >= 60.0:
		return "想跟你一起进下一部片"
	if float(c["security"]) < 40.0:
		return "担心你回不来"
	if float(c["intimacy"]) >= 70.0:
		return "想看看现实世界是什么样子"
	return "想知道你每天在练什么"


## 出征时她的反应：亲密和心情决定说什么；亲密够高的话，她是制造者的锚，出发前恐惧 −10。
## 返回 {"companion", "name", "line", "fear"}，fear 是制造者恐惧的变化量。
static func farewell(c: Dictionary) -> Dictionary:
	var line := ""
	var fear := 0.0
	if float(c["intimacy"]) >= 70.0 and float(c["mood"]) >= 50.0:
		line = "早点回来。我会一直等你。"
		fear = -10.0
	elif float(c["mood"]) < 40.0:
		line = "你又要走了……这次也不带我。"
	elif float(c["security"]) < 40.0:
		line = "你一定要回来，答应我。"
	else:
		line = "路上小心。回来给我讲讲。"
	return {"companion": String(c["id"]), "name": String(c["name"]), "line": line, "fear": fear}
```

- [ ] **Step 6：创建 `game/core/hub/morning.gd`**

```gdscript
extends RefCounted
## 晨会（设计规格 6.1 广场、9.6 第 2~8 天的晨会事件：结盟、新人去留）。
## 每天早上最多一件，每件只发生一次。事件表来自章节（M1 是 data/hub/m1_morning.json）：
##   {"id", "day_min", "when": {条件}, "prompt", "default": 没人理会时按哪个选项, "options": [{"id", "text", "effects": [...]}]}
## 条件（都满足才发生）：alive（都活着）、dead（都死了）、any_alive（其中有人活着，第一个活着的记作 {who}）、
##   companion_of（这个人有造物）、points_min（{角色: 至少多少点}）、flag（GameState.flags 里为真）。
## 效果：rel_change {"from": [..] 或 "all", "to", "deltas"}、relation {"kind", "actor", "target"}、fear {"chars": [..] 或 "all", "amount"}、
##   points {"from", "to", "amount"}、codex [条目 id]、companion {"creator", 各项增减}、say {"speaker", "text"}。
## 文本和效果里的 {who} 换成角色 id、{who_name} 换成名字。

const DataLoader = preload("res://core/util/data_loader.gd")
const Companion = preload("res://core/hub/companion.gd")


static func load_events(path: String) -> Array:
	if path == "":
		return []
	var res := DataLoader.load_json(path)
	assert(res.ok, res.error)
	return res.data["events"]


## 今天该发生哪件晨会（已经发生过的不再发生）。返回替换过占位符的事件，没有返回空字典。
static func pick(game: RefCounted, events: Array, day: int, seen: Array) -> Dictionary:
	for ev: Dictionary in events:
		if seen.has(String(ev["id"])) or day < int(ev.get("day_min", 1)):
			continue
		var who := _check(game, ev.get("when", {}))
		if who == "?":
			continue
		return _fill(ev, who, game)
	return {}


## 条件不满足返回 "?"；满足时返回 {who}（没有 any_alive 时是空字符串）。
static func _check(game: RefCounted, when: Dictionary) -> String:
	for id: String in when.get("alive", []):
		if not _alive(game, id):
			return "?"
	for id: String in when.get("dead", []):
		if _alive(game, id):
			return "?"
	var who := ""
	if when.has("any_alive"):
		who = "?"
		for id: String in when["any_alive"]:
			if _alive(game, id):
				who = id
				break
		if who == "?":
			return "?"
	if when.has("companion_of"):
		var found := false
		for c: Dictionary in game.companions:
			if String(c["creator"]) == String(when["companion_of"]):
				found = true
		if not found:
			return "?"
	var pm: Dictionary = when.get("points_min", {})
	for id: String in pm:
		if not _alive(game, id) or int(game.characters[id].points) < int(pm[id]):
			return "?"
	if when.has("flag") and not bool(game.flags.get(String(when["flag"]), false)):
		return "?"
	return who


static func _alive(game: RefCounted, id: String) -> bool:
	return game.characters.has(id) and game.characters[id].alive


static func _fill(ev: Dictionary, who: String, game: RefCounted) -> Dictionary:
	var text := JSON.stringify(ev)
	if who != "":
		text = text.replace("{who_name}", String(game.characters[who].display_name)).replace("{who}", who)
	var parsed: Variant = JSON.parse_string(text)
	var out: Dictionary = parsed
	out["who"] = who
	return out


## 回答晨会：按选项落效果。返回事件（第一条是 morning_answered）。
static func apply(game: RefCounted, ev: Dictionary, option_id: String, auto: bool = false) -> Array[Dictionary]:
	var picked: Dictionary = {}
	for o: Dictionary in ev["options"]:
		if String(o["id"]) == option_id:
			picked = o
	if picked.is_empty():
		return [{"type": "morning_refused", "reason": "bad_option"}]
	var events: Array[Dictionary] = [{"type": "morning_answered", "event": String(ev["id"]), "option": option_id, "text": String(picked["text"]), "auto": auto}]
	for e: Dictionary in picked.get("effects", []):
		_effect(game, e, events)
	return events


static func _effect(game: RefCounted, e: Dictionary, events: Array[Dictionary]) -> void:
	if e.has("say"):
		events.append({"type": "dialogue", "speaker": String(e["say"]["speaker"]), "text": String(e["say"]["text"])})
	if e.has("rel_change"):
		var rc: Dictionary = e["rel_change"]
		var to := String(rc["to"])
		for who: String in _chars(game, rc["from"]):
			if who != to:
				game.relations.change(who, to, rc["deltas"])
		events.append({"type": "relations_changed", "to": to, "deltas": (rc["deltas"] as Dictionary).duplicate()})
	if e.has("relation"):
		var r: Dictionary = e["relation"]
		events.append(game.relations.apply_event(String(r["kind"]), String(r["actor"]), String(r["target"]), _chars(game, "all")))
	if e.has("fear"):
		for who: String in _chars(game, e["fear"]["chars"]):
			var ch: RefCounted = game.characters[who]
			ch.fear = clampf(ch.fear + float(e["fear"]["amount"]), 0.0, 100.0)
			events.append({"type": "fear_changed", "char": who, "amount": float(e["fear"]["amount"]), "fear": ch.fear, "reason": "morning"})
	if e.has("points"):
		var p: Dictionary = e["points"]
		var giver: RefCounted = game.characters[String(p["from"])]
		var amount := mini(int(p["amount"]), int(giver.points))
		giver.points -= amount
		game.characters[String(p["to"])].points += amount
		events.append({"type": "points_given", "from": String(p["from"]), "to": String(p["to"]), "amount": amount})
	if e.has("codex"):
		events.append_array(game.codex.unlock(e["codex"], "morning"))
	if e.has("companion"):
		var cs: Dictionary = (e["companion"] as Dictionary).duplicate()
		var creator := String(cs["creator"])
		cs.erase("creator")
		for c: Dictionary in game.companions:
			if String(c["creator"]) == creator:
				for k: String in cs:
					c[k] = clampf(float(c.get(k, 50.0)) + float(cs[k]), 0.0, 100.0)
				events.append({"type": "companion_changed", "companion": String(c["id"]), "name": String(c["name"]), "deltas": cs.duplicate()})


## "all" = 所有活着的轮回者；数组 = 其中活着的。
static func _chars(game: RefCounted, spec: Variant) -> Array[String]:
	var out: Array[String] = []
	if spec is Array:
		for id: String in spec:
			if _alive(game, id):
				out.append(id)
	else:
		for id: String in game.characters:
			if game.characters[id].alive:
				out.append(id)
	return out
```

- [ ] **Step 7：创建 `game/data/hub/m1_morning.json`**

```json
{
	"version": 1,
	"events": [
		{
			"id": "zhang_jie_alliance",
			"day_min": 1,
			"when": {"alive": ["zhang_jie", "zheng_zha"]},
			"prompt": "张杰把活下来的人叫到广场上：「以后你们就是一队了。我说的话，最好都记着。」",
			"default": "accept",
			"options": [
				{"id": "accept", "text": "认他当带头的老手", "effects": [
					{"rel_change": {"from": "all", "to": "zhang_jie", "deltas": {"trust": 10}}},
					{"relation": {"kind": "heeded_rules", "actor": "zheng_zha", "target": "zhang_jie"}},
					{"say": {"speaker": "zhang_jie", "text": "行。那下一部，先听我的。"}}
				]},
				{"id": "own_way", "text": "我们自己拿主意", "effects": [
					{"rel_change": {"from": ["zhang_jie"], "to": "zheng_zha", "deltas": {"trust": -5}}},
					{"rel_change": {"from": "all", "to": "zheng_zha", "deltas": {"awe": 5}}},
					{"say": {"speaker": "zhang_jie", "text": "随你。死了别怪我没提醒。"}}
				]}
			]
		},
		{
			"id": "no_veteran",
			"day_min": 1,
			"when": {"dead": ["zhang_jie"], "alive": ["zheng_zha"]},
			"prompt": "张杰没能回来。广场上没人说话，大家都看着郑吒。",
			"default": "share",
			"options": [
				{"id": "lead", "text": "站出来：以后我拿主意", "effects": [
					{"rel_change": {"from": "all", "to": "zheng_zha", "deltas": {"awe": 10}}}
				]},
				{"id": "share", "text": "大家商量着来", "effects": [
					{"rel_change": {"from": "all", "to": "zheng_zha", "deltas": {"trust": 5}}}
				]}
			]
		},
		{
			"id": "newbie_stays",
			"day_min": 2,
			"when": {"alive": ["zheng_zha"], "any_alive": ["li_xiao_yi", "mu_gang", "xiao_pang_zi", "zhong_nian_fu_nv"]},
			"prompt": "{who_name}缩在广场角落里，说下一部片不想再跟着队伍跑了。",
			"default": "let_go",
			"options": [
				{"id": "encourage", "text": "陪他聊聊，拉他一起练", "effects": [
					{"rel_change": {"from": ["{who}"], "to": "zheng_zha", "deltas": {"trust": 10, "affection": 5}}},
					{"fear": {"chars": ["{who}"], "amount": -15}}
				]},
				{"id": "let_go", "text": "随他去", "effects": [
					{"rel_change": {"from": ["{who}"], "to": "zheng_zha", "deltas": {"trust": -5}}},
					{"fear": {"chars": ["{who}"], "amount": 5}}
				]}
			]
		},
		{
			"id": "lori_meets_team",
			"day_min": 2,
			"when": {"companion_of": "zheng_zha", "alive": ["zheng_zha"]},
			"prompt": "萝丽跟着郑吒来到广场，好奇又有点怕地看着其他人。",
			"default": "keep_room",
			"options": [
				{"id": "introduce", "text": "把她介绍给大家", "effects": [
					{"companion": {"creator": "zheng_zha", "mood": 10, "security": 10}}
				]},
				{"id": "keep_room", "text": "让她先回房间", "effects": [
					{"companion": {"creator": "zheng_zha", "dependence": 10, "mood": -5}}
				]}
			]
		},
		{
			"id": "zhan_lan_talk",
			"day_min": 3,
			"when": {"alive": ["zhan_lan", "zheng_zha"]},
			"prompt": "詹岚一早来找郑吒：「我一直在想，主神为什么让我们活下来。」",
			"default": "busy",
			"options": [
				{"id": "listen", "text": "坐下来听她说完", "effects": [
					{"rel_change": {"from": ["zhan_lan"], "to": "zheng_zha", "deltas": {"trust": 8, "affection": 5}}},
					{"codex": ["team_rating"]},
					{"say": {"speaker": "zhan_lan", "text": "它在给我们打分。活得越好，下一部越难。"}}
				]},
				{"id": "busy", "text": "改天再说", "effects": [
					{"rel_change": {"from": ["zhan_lan"], "to": "zheng_zha", "deltas": {"affection": -5}}}
				]}
			]
		},
		{
			"id": "points_help",
			"day_min": 4,
			"when": {"any_alive": ["li_xiao_yi", "mu_gang", "xiao_pang_zi", "zhong_nian_fu_nv"], "points_min": {"zheng_zha": 500}},
			"prompt": "{who_name}红着脸来问郑吒，能不能借点点数，想换点保命的东西。",
			"default": "refuse",
			"options": [
				{"id": "give", "text": "给他五百点", "effects": [
					{"points": {"from": "zheng_zha", "to": "{who}", "amount": 500}},
					{"rel_change": {"from": ["{who}"], "to": "zheng_zha", "deltas": {"trust": 15, "affection": 10}}}
				]},
				{"id": "refuse", "text": "点数我自己也要用", "effects": [
					{"rel_change": {"from": ["{who}"], "to": "zheng_zha", "deltas": {"trust": -5}}}
				]}
			]
		}
	]
}
```

- [ ] **Step 8：改写 `game/data/ai/personas.json`**

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
			"background": "《生化危机》里的警察，混进蜂巢调查姐姐的死，被雇佣兵当成可疑人物押着走。",
			"personality": "冷静、多疑，有正义感，不轻易相信陌生人。",
			"speech": "话少，说话直接，带着戒备。",
			"secrets": ["他其实是来调查保护伞公司的"],
			"fallback_lines": ["你们到底是什么人？", "别跟丢了。", "我不相信你们。"]
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
			"background": "雇佣兵小队的队长，接的是保护伞公司的私活，嘴上说只认钱。",
			"personality": "强硬、现实，遇事先算代价，对手下还算负责。",
			"speech": "命令式，粗话不多，句子很短。",
			"secrets": ["他偷偷带走了 T 病毒样本，准备卖出去"],
			"fallback_lines": ["照我说的做。", "别挡路。", "这笔账出去再算。"]
		},
		"matt": {
			"name": "马特",
			"role": "plot_npc",
			"background": "环保活动家，为了找失踪的妹妹混进蜂巢，嘴硬心软。",
			"personality": "冲动、理想主义，容易和人吵起来。",
			"speech": "语速快，爱反问，带点挑衅。",
			"secrets": ["他妹妹已经被感染，关在实验区"],
			"fallback_lines": ["你们不能这么做！", "我妹妹在哪？", "我不会丢下任何人。"]
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
			"background": "雇佣兵小队的机枪手，块头大，嘴也大。",
			"personality": "爱开玩笑，实际怕黑，越是害怕话越多。",
			"speech": "贫嘴，爱给人起外号。",
			"secrets": ["他怕黑，怕到会乱开枪"],
			"fallback_lines": ["别紧张，伙计。", "这地方瘆得慌。", "我掩护你。"]
		},
		"rain": {
			"name": "雷恩",
			"role": "plot_npc",
			"background": "雇佣兵小队的女队员，负责后卫和爆破。",
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
			"background": "普通公司职员，被卷进主神空间，靠着一股不服输的劲活到现在。",
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
			"background": "大学生，跑得快，嘴也快，什么都想试一试。",
			"personality": "话多、爱表现，真出事时会跟着最靠得住的人。",
			"speech": "年轻人腔调，爱用网络词。",
			"secrets": ["他怕被队伍当成累赘丢下"],
			"fallback_lines": ["这玩意儿怎么用？", "我跟着你。", "别丢下我。"]
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
			"background": "刚毕业，体能差，怕黑，被卷进来时还以为是恶作剧。",
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

- [ ] **Step 9：改写 `game/data/scenarios/biohazard1/chapter.json`**

```json
{
	"id": "m1",
	"name": "生化危机一",
	"scenario": "res://data/scenarios/biohazard1/scenario.json",
	"roster": "res://data/characters/m1_roster.json",
	"members": ["zheng_zha", "zhang_jie", "zhan_lan", "li_xiao_yi", "mu_gang", "xiao_pang_zi", "zhong_nian_fu_nv"],
	"leader": "zheng_zha",
	"hub_tour_guide": "zhang_jie",
	"morning_events": "res://data/hub/m1_morning.json",
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

- [ ] **Step 10：改写 `game/core/hub/hub.gd`**

```gdscript
extends RefCounted
## 主神空间的一次休整（设计规格 6.2~6.4）。休整天数是行动点：兑换、结算、造人、修复不耗天；训练、休息耗天。
## 原著惯例：回归当晚（第 0 天）不兑换，只结算和造人；最后一天强制休息，不能训练；每天恐惧自然下降。
## 代兑：每人每次休整只能用自己的点数或支线给别人兑换一次（设计规格 6.3）。
## 天赋：兑换契合的强化、训练或对练会触发觉醒（talents.gd）；觉醒的"学得快"让训练熟练度翻倍。
## 造人：每个制造者的第一个造物让他的潜力突升；突升够大，主神悄悄把他复制进恶魔小队（议程里记着，玩家不知道）。
## 规则发现：每过一段天数，活着的人里够格的智者会推出隐藏规则（rule_discovery.gd），写进规则百科。
## 陪伴（companion.gd）：陪造物一天、一起训练都耗 1 天；说话每天算一次；亲密够高时制造者恐惧降得更快。
## 晨会（morning.gd）：每天早上从章节的事件表里挑一件；没人理会的话，第二天早上按默认选项了结。

const Exchange = preload("res://core/hub/exchange.gd")
const Pricing = preload("res://core/hub/pricing.gd")
const Rules = preload("res://core/util/rules.gd")
const Battle = preload("res://core/battle/battle.gd")
const UnitFactory = preload("res://core/battle/unit_factory.gd")
const Rng = preload("res://core/util/rng.gd")
const Catalog = preload("res://core/hub/catalog.gd")
const Talents = preload("res://core/model/talents.gd")
const Agenda = preload("res://core/director/agenda.gd")
const Companion = preload("res://core/hub/companion.gd")
const Morning = preload("res://core/hub/morning.gd")

## 对练用的傀儡血量，用来换算"打掉了多少"。
const DUMMY_HP := 240.0

var game: RefCounted
var days_total: int = 10
## 0 = 回归当晚；每过一天加 1，到 days_total 就该出发了。
var day: int = 0
## 这次休整里已经给别人付过钱的人。
var gifts: Dictionary = {}
var history: Array[Dictionary] = []
## 晨会事件表的路径（章节给；空表示没有晨会）、今天等回答的晨会、已经发生过的晨会 id。
var morning_path: String = ""
var morning: Dictionary = {}
var morning_seen: Array = []


func start(game_state: RefCounted, days: int = -1, morning_events: String = "") -> Array[Dictionary]:
	game = game_state
	days_total = days if days > 0 else int(Pricing.rules()["rest"]["days_default"])
	day = 0
	gifts = {}
	morning_path = morning_events
	morning = {}
	morning_seen = []
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
## persona 是她在对话层的人设 id（萝丽是 luo_li；空字符串表示没有 AI 人设）。
func create_human(creator_id: String, name: String, attrs: Dictionary, persona: String = "") -> Array[Dictionary]:
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
	Companion.init_fields(companion, persona, day)
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


## 陪造物待一天（耗 1 天，最后一天不行）。
func visit_companion(companion_id: String) -> Array[Dictionary]:
	return _companion_day(companion_id, "visit")


## 和造物一起训练（耗 1 天，最后一天不行）。
func train_with_companion(companion_id: String) -> Array[Dictionary]:
	return _companion_day(companion_id, "train")


func _companion_day(companion_id: String, kind: String) -> Array[Dictionary]:
	var c := Companion.find(game, companion_id)
	if c.is_empty():
		return _refuse("no_companion")
	var creator: RefCounted = game.characters.get(String(c["creator"]), null)
	if creator == null or not creator.alive:
		return _refuse("no_companion")
	if day + 1 > days_total - 1:
		return _refuse("no_days")
	var events: Array[Dictionary] = Companion.visit(c, creator, day + 1) if kind == "visit" else Companion.train_together(c, creator, day + 1)
	_pass_days(1, events)
	return _emit(events)


## 和造物说了一次话（对话层回过一句之后调）。每天只算一次，不耗天。
func companion_talked(companion_id: String) -> Array[Dictionary]:
	var c := Companion.find(game, companion_id)
	if c.is_empty():
		return []
	return _emit(Companion.talked(c, day))


## 回答今天的晨会。
func answer_morning(option_id: String) -> Array[Dictionary]:
	if morning.is_empty():
		return _refuse("no_morning")
	var events: Array[Dictionary] = Morning.apply(game, morning, option_id)
	if String(events[0]["type"]) == "morning_answered":
		morning = {}
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
		for c: Dictionary in game.companions:
			Companion.day_passed(c, game.characters.get(String(c["creator"]), null), day)
		_next_morning(events)
	events.append_array(game.codex.discovery.discover_all(game.living_characters(), game))


## 新的一天早上：昨天没回答的晨会按默认选项了结，再挑今天的（出发那天没有晨会）。
func _next_morning(events: Array[Dictionary]) -> void:
	if not morning.is_empty():
		events.append_array(Morning.apply(game, morning, String(morning.get("default", morning["options"][0]["id"])), true))
		morning = {}
	if day >= days_total or morning_path == "":
		return
	var ev := Morning.pick(game, Morning.load_events(morning_path), day, morning_seen)
	if ev.is_empty():
		return
	morning = ev
	morning_seen.append(String(ev["id"]))
	var shown: Array = []
	for o: Dictionary in ev["options"]:
		shown.append({"id": String(o["id"]), "text": String(o["text"])})
	events.append({"type": "morning_event", "event": String(ev["id"]), "prompt": String(ev["prompt"]), "options": shown})


## 天赋触发：觉醒的事件追加进 events，同时记进主神议程。
func _talent(char_id: String, trigger_id: String, events: Array[Dictionary]) -> void:
	for t in Talents.trigger(_char(char_id), trigger_id, events):
		Talents.record(game.agenda, char_id, t, _film())


## 这次休整接在哪部片后面（议程记录用）。
func _film() -> String:
	return String(game.films_record.back()) if not game.films_record.is_empty() else ""


func to_dict() -> Dictionary:
	return {
		"days_total": days_total, "day": day, "gifts": gifts.duplicate(),
		"morning_path": morning_path, "morning": morning.duplicate(true), "morning_seen": morning_seen.duplicate(),
	}


func load_dict(d: Dictionary, game_state: RefCounted) -> void:
	game = game_state
	days_total = int(d["days_total"])
	day = int(d["day"])
	gifts = (d["gifts"] as Dictionary).duplicate()
	morning_path = String(d.get("morning_path", ""))
	morning = (d.get("morning", {}) as Dictionary).duplicate(true)
	morning_seen = (d.get("morning_seen", []) as Array).duplicate()
```

- [ ] **Step 11：改写 `game/core/session/session.gd`**

```gdscript
extends RefCounted
## 一局游戏（设计规格 2、10.2）：把 GameState、当前远征、阶段和休整天数装在一起。
## 阶段：expedition（在片子里）→ settlement（刚回归，结算完）→ hub（主神空间休整 9 天）→ done（下一次出发，M2 未做）。
## 全员死亡时结算后进 lost（任务失败，没有主神空间可回）。
## 存档方式（设计规格 7.7）：铁人模式只有一个自动存档、不能手动存读、全灭就删档；宽松模式有三个手动槽。
## 界面只读这里的 game / expedition，并调用这里的方法推进；存档就是 to_dict()。

const GameState = preload("res://core/model/game_state.gd")
const Campaign = preload("res://core/campaign/campaign.gd")
const Scenario = preload("res://core/expedition/scenario.gd")
const Expedition = preload("res://core/expedition/expedition.gd")
const SaveService = preload("res://core/save/save_service.gd")
const Hub = preload("res://core/hub/hub.gd")
const Agenda = preload("res://core/director/agenda.gd")
const Companion = preload("res://core/hub/companion.gd")

const VERSION := 1
const M1_CHAPTER := "res://data/scenarios/biohazard1/chapter.json"
const PHASES: Array[String] = ["expedition", "settlement", "hub", "done", "lost"]
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

## 铁人模式：只有一个自动存档，不能手动存读，全灭就删档。
var iron_man: bool = false
## 走光柱时造物们的反应：[{"companion", "name", "line", "fear"}]。
var farewells: Array = []

## 聊天能拉近关系，但只到这里；再往上要靠行动（救人、并肩作战）。
const TALK_TRUST_STEP := 2.0
const TALK_TRUST_CAP := 60.0


## 开一局：建 GameState、按章节装配七名轮回者、开始第一部片。iron 为 true 是铁人模式。
func start(chapter: String, seed_value: int = 0, iron: bool = false) -> bool:
	chapter_path = chapter
	game = GameState.new(seed_value)
	iron_man = iron
	game.iron_man = iron
	farewells = []
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


func start_m1(seed_value: int = 0, iron: bool = false) -> bool:
	return start(M1_CHAPTER, seed_value, iron)


## 铁人模式不能手动存档（也不能手动读档）。
func can_save_manually() -> bool:
	return not iron_man


## 这部片全员死亡：任务失败。
func lost() -> bool:
	return expedition != null and String(expedition.st.outcome) == "wiped"


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
	if lost():
		phase = "lost"
		hub = null
		return settlement
	_companions_follow_creators()
	hub = Hub.new()
	hub.start(game, REST_DAYS, String(chapter.get("morning_events", "")))
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


## 制造者死在片里，他的造物和房间一起消失（设计规格 6.6）。消失的名字记进 film_report.companions_lost。
func _companions_follow_creators() -> void:
	var kept: Array = []
	var gone: Array = []
	for c: Dictionary in game.companions:
		var creator := String(c["creator"])
		if game.characters.has(creator) and game.characters[creator].alive:
			kept.append(c)
		else:
			gone.append(String(c["name"]))
	game.companions = kept
	film_report["companions_lost"] = gone


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


## 走光柱出发；M2 的内容还没做，先把阶段停在 done。造物们各说一句话，亲密够高的让制造者安心些。
func depart() -> bool:
	if not can_depart():
		return false
	farewells = []
	for c: Dictionary in game.companions:
		var creator: RefCounted = game.characters.get(String(c["creator"]), null)
		if creator == null or not creator.alive:
			continue
		var f := Companion.farewell(c)
		creator.fear = clampf(creator.fear + float(f["fear"]), 0.0, 100.0)
		farewells.append(f)
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
		"iron_man": iron_man,
		"farewells": farewells.duplicate(true),
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
	iron_man = bool(d.get("iron_man", false))
	game.iron_man = iron_man
	farewells = (d.get("farewells", []) as Array).duplicate(true)
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

- [ ] **Step 12：运行，确认通过**

Run: `bash game/tools/run_tests.sh > _work/p17_task1.txt 2>&1; echo "exit=$?"; tail -1 _work/p17_task1.txt; echo "SCRIPT ERROR: $(grep -c 'SCRIPT ERROR' _work/p17_task1.txt)"`

预期：`共 449 个测试，失败 0 个`、`SCRIPT ERROR: 0`。

- [ ] **Step 13：提交**

```bash
git add game/core/hub/companion.gd game/core/hub/morning.gd game/data/hub/m1_morning.json game/data/ai/personas.json game/data/scenarios/biohazard1/chapter.json game/core/hub/hub.gd game/core/session/session.gd game/tests/unit/hub/test_companion.gd game/tests/unit/hub/test_morning.gd game/tests/unit/session/test_session.gd
git commit -m "feat(hub): 萝丽有了心情亲密和出征反应，休整每天有晨会；铁人模式与全灭失败" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git status --short
```

预期：`git status --short` 只剩 `?? _work/`。

---

## Task 2：界面与验收

**Files:**
- Modify: `game/ui/hub/hub_view.gd`、`game/ui/hub/hub_screen.gd`、`game/ui/event_text.gd`、`game/ui/title_screen.gd`、`game/ui/pause_menu.gd`、`game/ui/main.gd`、`game/tools/verify_m1_slice.gd`
- Test: `game/tests/unit/hub/test_hub_view.gd`、`game/tests/unit/ui/test_title.gd`

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
	assert_eq(all.size(), 200)
	var qigong := {}
	for e: Dictionary in all:
		if e["id"] == "qigong_low":
			qigong = e
	assert_eq(qigong["points"], 500)
	assert_true(bool(qigong["ok"]))
	assert_eq((v.entries("zheng_zha", "item") as Array).size(), 28)


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


## 兑换项的一句话效果：属性、技能、能量、道具；"只看买得起的"把买不起的筛掉。
func test_entry_effects_and_affordable_filter() -> void:
	var v := _view()
	var by_id := {}
	for e: Dictionary in v.entries("zheng_zha"):
		by_id[String(e["id"])] = e
	assert_true(String(by_id["qigong_low"]["effect"]).contains("技能：气功掌"))
	assert_true(String(by_id["qigong_low"]["effect"]).contains("内力+30"))
	assert_eq(String(by_id["muscle_serum_1"]["effect"]), "肌肉+60")
	assert_eq(String(by_id["grenade_pack"]["effect"]), "手榴弹×5")
	assert_eq(String(by_id["ammo_box"]["effect"]), "子弹×30")
	var cheap: Array[Dictionary] = v.entries("zheng_zha", "", true)
	assert_true(cheap.size() > 0 and cheap.size() < 200)
	for e: Dictionary in cheap:
		assert_true(bool(e["ok"]), String(e["id"]))


## 造物页：造了萝丽之后能看到她的四项数值、她想要什么、制造者的名字；晨会取数。
func test_companions_and_morning() -> void:
	var v := _view()
	v.create_human("zheng_zha", "萝丽")
	var list: Array = v.companions()
	assert_eq(list.size(), 1)
	var c: Dictionary = list[0]
	assert_eq(String(c["creator_name"]), "郑吒")
	assert_eq(String(c["persona"]), "luo_li")
	assert_eq(String(c["wish"]), "想知道你每天在练什么")
	var m: Dictionary = v.morning()
	assert_eq(String(m["event"]), "zhang_jie_alliance")
	assert_eq((m["options"] as Array).size(), 2)
	v.answer_morning("accept")
	assert_eq(v.morning(), {})
```

- [ ] **Step 2：改写 `game/tests/unit/ui/test_title.gd`**

```gdscript
extends "res://tests/test_case.gd"
## 标题画面与暂停菜单：信号、槽位列表、空槽不可读、设置切换。

const TitleScreen = preload("res://ui/title_screen.gd")
const PauseMenu = preload("res://ui/pause_menu.gd")
const Slots = preload("res://core/save/slots.gd")
const Session = preload("res://core/session/session.gd")


func before_each() -> void:
	for i in range(1, Slots.COUNT + 1):
		Slots.erase(i)


func _title() -> Control:
	var t := TitleScreen.new()
	t.build()
	t.set_settings({"window_mode": "windowed", "volume": 0.8})
	return t


func test_title_lists_three_slots() -> void:
	var t := _title()
	t.open_slots()
	assert_eq((t.slot_rows() as Array).size(), 3)
	assert_eq(t.slot_box.get_child_count(), 3, "三个槽各一行")
	t.free()


func test_empty_slot_does_not_load() -> void:
	var t := _title()
	var loaded: Array = []
	t.load_slot.connect(func(slot: int) -> void: loaded.append(slot))
	t.press_slot(1)
	assert_eq(loaded.size(), 0, "空槽点了不读档")
	t.free()


func test_filled_slot_emits() -> void:
	var s := Session.new()
	s.start_m1(1)
	Slots.write(2, s)
	var t := _title()
	var loaded: Array = []
	t.load_slot.connect(func(slot: int) -> void: loaded.append(slot))
	t.press_slot(2)
	assert_eq(loaded.size(), 1)
	assert_eq(int(loaded[0]), 2)
	t.free()


## 新游戏先弹出存档方式；选了才发信号，带着是不是铁人模式。Esc 先关这个面板。
func test_new_game_and_quit_signals() -> void:
	var t := _title()
	var events: Array = []
	t.new_game.connect(func(iron: bool) -> void: events.append("new:%s" % iron))
	t.quit_game.connect(func() -> void: events.append("quit"))
	t.press_new()
	assert_true(t.mode_panel.visible)
	assert_eq(events, [])
	assert_true(t.handle_escape())
	assert_false(t.mode_panel.visible)
	t.press_new()
	t.press_mode(true)
	assert_false(t.mode_panel.visible)
	t.press_quit()
	assert_eq(events, ["new:true", "quit"])
	t.free()


func test_settings_toggle_and_volume() -> void:
	var t := _title()
	assert_eq(String(t.mode_button.text), "窗口")
	t.toggle_mode()
	assert_eq(String(t.mode_button.text), "全屏")
	assert_eq(String(t.settings["window_mode"]), "fullscreen")
	t.volume_down()
	assert_almost(float(t.settings["volume"]), 0.7)
	assert_true(String(t.volume_label.text).contains("70"), String(t.volume_label.text))
	t.free()


func test_escape_closes_overlay_first() -> void:
	var t := _title()
	t.open_settings()
	assert_true(t.handle_escape(), "设置开着时 Esc 先关设置")
	assert_false(t.settings_panel.visible)
	assert_false(t.handle_escape(), "都关了就交回上一层")
	t.free()


func test_pause_saves_to_slot_and_reloads() -> void:
	var p := PauseMenu.new()
	p.build()
	p.open_for("")
	var saved: Array = []
	var loaded: Array = []
	p.save_slot.connect(func(slot: int) -> void: saved.append(slot))
	p.load_slot.connect(func(slot: int) -> void: loaded.append(slot))
	p.press_save(2)
	assert_eq(saved, [2])
	p.press_load(1)
	assert_eq(loaded.size(), 0, "空槽不可读")

	var s := Session.new()
	s.start_m1(1)
	Slots.write(1, s)
	p.refresh()
	p.press_load(1)
	assert_eq(loaded, [1])
	p.free()


## 铁人模式的暂停菜单：存读档整块藏起来，按了也不发信号。
func test_pause_iron_man_hides_slots() -> void:
	var p := PauseMenu.new()
	p.build()
	p.set_iron_man(true)
	p.open_for("")
	assert_true(p.iron_label.visible)
	assert_false(p.save_buttons[0].get_parent().visible)
	var saved: Array = []
	p.save_slot.connect(func(slot: int) -> void: saved.append(slot))
	p.press_save(1)
	assert_eq(saved, [])
	p.set_iron_man(false)
	assert_false(p.iron_label.visible)
	p.press_save(1)
	assert_eq(saved, [1])
	p.free()
```

- [ ] **Step 3：运行，确认失败**

Run: `bash game/tools/run_tests.sh | tail -3`

预期：`test_hub_view.gd::test_companions_and_morning`、`test_title.gd` 的新游戏和铁人暂停菜单测试失败（或报 `SCRIPT ERROR`）。

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
const Companion = preload("res://core/hub/companion.gd")

## 兑换项效果一句话里用的中文名。
const ATTR_NAMES := {
	"intelligence": "智力", "spirit": "精神", "cell_vitality": "细胞", "nerve_reaction": "神经", "muscle": "肌肉", "immunity": "免疫",
}
const ENERGY_NAMES := {"neili": "内力", "blood": "血能", "mana": "魔力"}

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


## 兑换目录；category 为空时给全部。ok 表示现在能买，reasons 是买不了的原因，effect 是一句话效果。
## affordable_only：只列现在买得起的（目录有两百条，翻起来太长）。
func entries(char_id: String, category: String = "", affordable_only: bool = false) -> Array[Dictionary]:
	var ch: RefCounted = game.characters[char_id]
	var out: Array[Dictionary] = []
	for id: String in Catalog.entries():
		var e: Dictionary = Catalog.entry(id)
		if category != "" and String(e["category"]) != category:
			continue
		var check: Dictionary = Exchange.check(ch, id)
		if affordable_only and not bool(check["ok"]):
			continue
		var reasons: Array[String] = []
		for r: String in check["reasons"]:
			reasons.append(reason_text(r))
		out.append({
			"id": id, "name": String(e["name"]), "category": String(e["category"]),
			"series": String(e["series"]), "points": int(e["price"]["points"]),
			"tier": String(e["price"].get("tier", "")), "owned": ch.owned.has(id),
			"ok": bool(check["ok"]), "reasons": reasons,
			"warnings": (check["warnings"] as Array).duplicate(),
			"effect": effect_text(e),
		})
	return out


## 兑换项的效果，一句话：属性加多少、给什么技能、加多少能量、几件道具。只描述真能用上的积木。
static func effect_text(e: Dictionary) -> String:
	var parts: Array[String] = []
	for b: Dictionary in e["blocks"]:
		if b.has("attr"):
			for k: String in b["attr"]:
				parts.append("%s+%d" % [String(ATTR_NAMES.get(k, k)), int(b["attr"][k])])
		elif b.has("skill"):
			parts.append("技能：" + String(BattleData.skills().get(String(b["skill"]), {}).get("name", b["skill"])))
		elif b.has("energy"):
			parts.append("%s+%d" % [String(ENERGY_NAMES.get(String(b["energy"]), b["energy"])), int(b["amount"])])
		elif b.has("item"):
			parts.append("%s×%d" % [_item_name(String(b["item"])), int(b["count"])])
	return "，".join(parts)


## 道具的中文名：用得上它的技能叫什么，道具就叫什么（弹药、重生十字章单独说）。
static func _item_name(item: String) -> String:
	if item == "ammo":
		return "子弹"
	if item == "rebirth_cross":
		return "重生十字章"
	for s: String in BattleData.skills():
		if (BattleData.skills()[s].get("cost", {}) as Dictionary).has(item) and bool(BattleData.skills()[s].get("item", false)):
			return String(BattleData.skills()[s]["name"])
	return item


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


## 造物：原样字段，加上制造者的名字和她现在想要什么。
func companions() -> Array:
	var out: Array = []
	for c: Dictionary in game.companions:
		var d := c.duplicate(true)
		var creator := String(c["creator"])
		d["creator_name"] = game.characters[creator].display_name if game.characters.has(creator) else creator
		d["wish"] = Companion.wish(c)
		out.append(d)
	return out


## 造人：M1 固定郑吒造萝丽，素质取预设（不超过常人两倍），人设用 luo_li。
func create_human(creator_id: String, name: String) -> Array[Dictionary]:
	return hub.create_human(creator_id, name, LORI_ATTRS, "luo_li")


func visit_companion(companion_id: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = hub.visit_companion(companion_id)
	session.day = hub.day
	return events


func train_with_companion(companion_id: String) -> Array[Dictionary]:
	var events: Array[Dictionary] = hub.train_with_companion(companion_id)
	session.day = hub.day
	return events


func companion_talked(companion_id: String) -> Array[Dictionary]:
	return hub.companion_talked(companion_id)


## 今天的晨会：{"event", "prompt", "options": [{"id", "text"}]}；没有返回空字典。
func morning() -> Dictionary:
	if hub == null or hub.morning.is_empty():
		return {}
	var options: Array = []
	for o: Dictionary in hub.morning["options"]:
		options.append({"id": String(o["id"]), "text": String(o["text"])})
	return {"event": String(hub.morning["id"]), "prompt": String(hub.morning["prompt"]), "options": options}


func answer_morning(option_id: String) -> Array[Dictionary]:
	return hub.answer_morning(option_id)


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
		"no_companion": "没有这个造物", "no_morning": "今天没有晨会",
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
## 想跟造物说话（main 打开对话框）。
signal companion_talk_requested(companion_id: String)

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
## 兑换页只列买得起的。
var affordable_only: bool = false
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
	if not view.morning().is_empty():
		_build_morning()
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
	var only := UiTheme.button("只看买得起的" if not affordable_only else "显示全部", 18)
	only.pressed.connect(toggle_affordable)
	row.add_child(only)
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

	for e: Dictionary in view.entries(selected, category, affordable_only):
		var label := "%s   %d 点" % [String(e["name"]), int(e["points"])]
		if String(e["tier"]) != "":
			label += " · " + String(e["tier"]) + " 级"
		if String(e["effect"]) != "":
			label += "　｜" + String(e["effect"])
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


## 晨会：每天早上广场上的事。不回答也行，第二天早上按默认的了结。
func _build_morning() -> void:
	var m: Dictionary = view.morning()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.add_child(UiTheme.label("【晨会】" + String(m["prompt"]), 20, UiTheme.ACCENT2))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	for o: Dictionary in m["options"]:
		var b := UiTheme.button(String(o["text"]), 18)
		b.custom_minimum_size = Vector2(0, 44)
		b.pressed.connect(press_morning.bind(String(o["id"])))
		row.add_child(b)
	box.add_child(row)
	content_box.add_child(box)


func press_morning(option_id: String) -> void:
	var events: Array[Dictionary] = view.answer_morning(option_id)
	status_label.text = _describe(events)
	refresh()


func _build_human() -> void:
	var made: Array = view.companions()
	content_box.add_child(UiTheme.label("造人：第一个免费，之后 500 点；素质最多约常人两倍，回归当晚就能造。", 19, UiTheme.MUTED))
	var last_day: bool = view.hub.day + 1 > view.hub.days_total - 1
	for c: Dictionary in made:
		content_box.add_child(UiTheme.label("%s（%s 造的）　心情 %d · 亲密 %d · 依赖 %d · 安心 %d　她想：%s" % [
			String(c["name"]), String(c["creator_name"]), int(float(c["mood"])), int(float(c["intimacy"])),
			int(float(c["dependence"])), int(float(c["security"])), String(c["wish"])], 20))
		var acts := HBoxContainer.new()
		acts.add_theme_constant_override("separation", 10)
		var visit := UiTheme.button("陪她一天（1 天）", 18)
		visit.disabled = last_day
		visit.pressed.connect(press_visit.bind(String(c["id"])))
		acts.add_child(visit)
		var train := UiTheme.button("一起训练（1 天）", 18)
		train.disabled = last_day
		train.pressed.connect(press_train_companion.bind(String(c["id"])))
		acts.add_child(train)
		var talk := UiTheme.button("说说话", 18)
		talk.disabled = String(c.get("persona", "")) == ""
		talk.pressed.connect(press_talk_companion.bind(String(c["id"])))
		acts.add_child(talk)
		content_box.add_child(acts)
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


func toggle_affordable() -> void:
	affordable_only = not affordable_only
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


func press_visit(companion_id: String) -> void:
	var events: Array[Dictionary] = view.visit_companion(companion_id)
	status_label.text = _describe(events)
	refresh()


func press_train_companion(companion_id: String) -> void:
	var events: Array[Dictionary] = view.train_with_companion(companion_id)
	status_label.text = _describe(events)
	refresh()


func press_talk_companion(companion_id: String) -> void:
	companion_talk_requested.emit(companion_id)


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
		"companion_visited":
			return "陪%s待了一天（心情 %d，亲密 %d）" % [String(e["name"]), int(float(e["mood"])), int(float(e["intimacy"]))]
		"companion_trained":
			return "和%s一起练了一天，她觉得自己帮上了忙" % String(e["name"])
		"morning_answered":
			return "晨会：" + String(e["text"])
		"morning_refused":
			return "晨会：没有这个选项"
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

- [ ] **Step 6：改写 `game/ui/event_text.gd`**

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
		"companion_talked":
			return "%s 跟你更亲近了（亲密 %d）。" % [String(e.get("name", "")), int(float(e.get("intimacy", 0.0)))]
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

- [ ] **Step 7：改写 `game/ui/title_screen.gd`**

```gdscript
extends Control
## PC 版标题画面：新游戏（先选铁人或宽松）/ 继续（三个存档槽）/ 设置 / 退出。
## 只发信号，不碰 Session；开新游戏、读档、退出的实做在 main.gd。

## iron_man：铁人模式（一个自动存档，不能手动存读，全灭删档）。
signal new_game(iron_man: bool)
signal load_slot(slot: int)
signal quit_game
signal settings_changed(settings: Dictionary)

const UiTheme = preload("res://ui/ui_theme.gd")
const Slots = preload("res://core/save/slots.gd")
const Settings = preload("res://core/settings/settings.gd")

const VERSION_TEXT := "v0.1.0 · 计划 10"

var menu_box: VBoxContainer
var slot_panel: Control
var slot_box: VBoxContainer
var settings_panel: Control
var mode_panel: Control
var mode_button: Button
var volume_label: Label
var hint_label: Label
var settings: Dictionary = Settings.defaults()
var _built := false


func _ready() -> void:
	build()


## 幂等：界面里 _ready 调一次，测试里直接调。
func build() -> void:
	if _built:
		return
	_built = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiTheme.paint_bg(self)

	var title := UiTheme.label("无限恐怖", 84, UiTheme.ACCENT2)
	title.position = Vector2(0, 200)
	title.size = Vector2(1920, 110)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var sub := UiTheme.label("2D 回合制同人游戏 · 第一阶段《生化危机一》", 22, UiTheme.MUTED)
	sub.position = Vector2(0, 312)
	sub.size = Vector2(1920, 34)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	var rule := ColorRect.new()
	rule.color = UiTheme.LINE
	rule.position = Vector2(830, 372)
	rule.size = Vector2(260, 2)
	add_child(rule)

	menu_box = VBoxContainer.new()
	menu_box.position = Vector2(730, 420)
	menu_box.size = Vector2(460, 304)
	menu_box.add_theme_constant_override("separation", 16)
	add_child(menu_box)

	_add_menu("新游戏", press_new)
	_add_menu("继续游戏", open_slots)
	_add_menu("设置", open_settings)
	_add_menu("退出游戏", press_quit)

	var ver := UiTheme.label(VERSION_TEXT, 16, UiTheme.MUTED)
	ver.position = Vector2(60, 1012)
	ver.size = Vector2(600, 24)
	add_child(ver)

	hint_label = UiTheme.label("", 16, UiTheme.MUTED)
	hint_label.position = Vector2(1260, 1012)
	hint_label.size = Vector2(600, 24)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(hint_label)

	_build_slots()
	_build_settings()
	_build_mode()
	set_hint("Enter 确认 · Esc 返回")


func _add_menu(text: String, handler: Callable) -> Button:
	var b := UiTheme.button(text, 24)
	b.custom_minimum_size = Vector2(460, 64)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(handler)
	menu_box.add_child(b)
	return b


func _build_slots() -> void:
	slot_panel = _overlay(900, 560)
	var box := VBoxContainer.new()
	box.position = Vector2(30, 24)
	box.size = Vector2(840, 500)
	box.add_theme_constant_override("separation", 12)
	slot_panel.add_child(box)
	box.add_child(UiTheme.label("选择存档", 28, UiTheme.ACCENT2))
	slot_box = VBoxContainer.new()
	slot_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slot_box.add_theme_constant_override("separation", 10)
	box.add_child(slot_box)
	var back := UiTheme.button("返回", 20)
	back.custom_minimum_size = Vector2(140, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(close_slots)
	box.add_child(back)


## 新游戏先选存档方式（设计规格 7.7：推荐铁人模式，另给想体验剧情的人一个宽松选项）。
func _build_mode() -> void:
	mode_panel = _overlay(900, 420)
	var box := VBoxContainer.new()
	box.position = Vector2(30, 24)
	box.size = Vector2(840, 360)
	box.add_theme_constant_override("separation", 14)
	mode_panel.add_child(box)
	box.add_child(UiTheme.label("选择存档方式", 28, UiTheme.ACCENT2))
	var iron := UiTheme.button("铁人模式（推荐）：只有一个自动存档，不能读档重来，全员死亡就删档", 20)
	iron.custom_minimum_size = Vector2(840, 64)
	iron.pressed.connect(press_mode.bind(true))
	box.add_child(iron)
	var loose := UiTheme.button("宽松模式：三个手动存档槽，随时存读，想看剧情选这个", 20)
	loose.custom_minimum_size = Vector2(840, 64)
	loose.pressed.connect(press_mode.bind(false))
	box.add_child(loose)
	var back := UiTheme.button("返回", 20)
	back.custom_minimum_size = Vector2(140, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(close_mode)
	box.add_child(back)


func _build_settings() -> void:
	settings_panel = _overlay(760, 420)
	var box := VBoxContainer.new()
	box.position = Vector2(30, 24)
	box.size = Vector2(700, 360)
	box.add_theme_constant_override("separation", 16)
	settings_panel.add_child(box)
	box.add_child(UiTheme.label("设置", 28, UiTheme.ACCENT2))

	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 12)
	mode_row.add_child(UiTheme.label("窗口", 20))
	mode_button = UiTheme.button("", 20)
	mode_button.custom_minimum_size = Vector2(220, 48)
	mode_button.pressed.connect(toggle_mode)
	mode_row.add_child(mode_button)
	box.add_child(mode_row)

	var vol_row := HBoxContainer.new()
	vol_row.add_theme_constant_override("separation", 12)
	vol_row.add_child(UiTheme.label("主音量", 20))
	var down := UiTheme.button("−", 20)
	down.custom_minimum_size = Vector2(64, 48)
	down.pressed.connect(volume_down)
	vol_row.add_child(down)
	volume_label = UiTheme.label("", 20, UiTheme.ACCENT2)
	volume_label.custom_minimum_size = Vector2(120, 48)
	volume_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vol_row.add_child(volume_label)
	var up := UiTheme.button("+", 20)
	up.custom_minimum_size = Vector2(64, 48)
	up.pressed.connect(volume_up)
	vol_row.add_child(up)
	box.add_child(vol_row)

	var back := UiTheme.button("返回", 20)
	back.custom_minimum_size = Vector2(140, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(close_settings)
	box.add_child(back)


func _overlay(w: int, h: int) -> Control:
	var mask := ColorRect.new()
	mask.color = Color(0, 0, 0, 0.62)
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_STOP
	mask.visible = false
	add_child(mask)
	var p := Panel.new()
	p.position = Vector2((1920.0 - w) / 2.0, (1080.0 - h) / 2.0)
	p.size = Vector2(w, h)
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PANEL, UiTheme.LINE, 10))
	mask.add_child(p)
	return mask


func set_hint(text: String) -> void:
	if hint_label != null:
		hint_label.text = text


## 设置由 main 传进来，标题画面只负责显示与修改。
func set_settings(s: Dictionary) -> void:
	settings = s.duplicate()
	_refresh_settings()


func _refresh_settings() -> void:
	if mode_button == null:
		return
	mode_button.text = "全屏" if String(settings.get("window_mode", "windowed")) == "fullscreen" else "窗口"
	volume_label.text = "%d%%" % roundi(float(settings.get("volume", 0.8)) * 100.0)


## ---- 供界面与验收脚本调用 ----

func press_new() -> void:
	mode_panel.visible = true
	set_hint("选择存档方式 · Esc 返回")


func press_mode(iron: bool) -> void:
	mode_panel.visible = false
	new_game.emit(iron)


func close_mode() -> void:
	mode_panel.visible = false
	set_hint("Enter 确认 · Esc 返回")


func press_quit() -> void:
	quit_game.emit()


func open_slots() -> void:
	_refresh_slots()
	slot_panel.visible = true
	set_hint("选择存档位 · Esc 返回")


func close_slots() -> void:
	slot_panel.visible = false
	set_hint("Enter 确认 · Esc 返回")


func open_settings() -> void:
	_refresh_settings()
	settings_panel.visible = true
	set_hint("设置窗口与音量 · Esc 返回")


func close_settings() -> void:
	settings_panel.visible = false
	set_hint("Enter 确认 · Esc 返回")


## 三个槽的摘要；标题画面每次打开都重读，存档后不用重启也能看到。
func slot_rows() -> Array[Dictionary]:
	return Slots.all_summaries()


func _refresh_slots() -> void:
	for c in slot_box.get_children():
		slot_box.remove_child(c)
		c.queue_free()
	# 自动存档放在最上面：换地点/战斗后自动落的盘，直接"继续"。
	var auto := Slots.summary(Slots.AUTO)
	if bool(auto["exists"]):
		_add_slot_row(auto, "自动存档（继续）")
	for row: Dictionary in slot_rows():
		_add_slot_row(row, "存档 %d" % int(row["slot"]))


func _add_slot_row(row: Dictionary, prefix: String) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	var text := "%s　%s" % [prefix, String(row["label"])]
	if bool(row["exists"]):
		text += "　%d 点　%s" % [int(row["points"]), String(row["saved_at"])]
	var l := UiTheme.label(text, 19, UiTheme.TEXT if bool(row["exists"]) else UiTheme.MUTED)
	l.custom_minimum_size = Vector2(600, 76)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line.add_child(l)
	var b := UiTheme.button("读取", 19)
	b.custom_minimum_size = Vector2(140, 52)
	b.disabled = not bool(row["exists"])
	b.pressed.connect(press_slot.bind(int(row["slot"])))
	line.add_child(b)
	slot_box.add_child(line)


func press_slot(slot: int) -> void:
	var row: Dictionary = Slots.summary(slot)
	if not bool(row["exists"]):
		return
	close_slots()
	load_slot.emit(slot)


func toggle_mode() -> void:
	var next := "windowed" if String(settings.get("window_mode", "windowed")) == "fullscreen" else "fullscreen"
	settings = Settings.with_value(settings, "window_mode", next)
	_refresh_settings()
	settings_changed.emit(settings)


func volume_up() -> void:
	_bump_volume(0.1)


func volume_down() -> void:
	_bump_volume(-0.1)


func _bump_volume(delta: float) -> void:
	var v := clampf(snappedf(float(settings.get("volume", 0.8)) + delta, 0.1), 0.0, 1.0)
	settings = Settings.with_value(settings, "volume", v)
	_refresh_settings()
	settings_changed.emit(settings)


## Esc：先关覆盖层，都不开就什么都不做（标题画面不退出）。
func handle_escape() -> bool:
	if mode_panel != null and mode_panel.visible:
		close_mode()
		return true
	if slot_panel.visible:
		close_slots()
		return true
	if settings_panel.visible:
		close_settings()
		return true
	return false
```

- [ ] **Step 8：改写 `game/ui/pause_menu.gd`**

```gdscript
extends Control
## 暂停菜单（游戏内按 Esc）：继续、存到三个槽、从槽读取、回标题、退出。
## 只发信号；存读档的实做在 main.gd，菜单只负责显示摘要。

signal resume
signal save_slot(slot: int)
signal load_slot(slot: int)
signal to_title
signal quit_game

const UiTheme = preload("res://ui/ui_theme.gd")
const Slots = preload("res://core/save/slots.gd")

var status_label: Label
var slot_labels: Array[Label] = []
var save_buttons: Array[Button] = []
var load_buttons: Array[Button] = []
var panel: Panel
var _built := false
## 存读档那一块（铁人模式整块藏起来）。
var slot_section: Array[Control] = []
var iron_label: Label


func _ready() -> void:
	build()


func build() -> void:
	if _built:
		return
	_built = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var mask := ColorRect.new()
	mask.color = Color(0, 0, 0, 0.62)
	mask.set_anchors_preset(Control.PRESET_FULL_RECT)
	mask.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(mask)

	panel = Panel.new()
	panel.position = Vector2(600, 250)
	panel.size = Vector2(720, 560)
	panel.add_theme_stylebox_override("panel", UiTheme.panel_style(UiTheme.PANEL, UiTheme.LINE, 10))
	add_child(panel)

	var box := VBoxContainer.new()
	box.position = Vector2(30, 24)
	box.size = Vector2(660, 512)
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(UiTheme.label("暂停", 30, UiTheme.ACCENT2))

	var resume_button := UiTheme.button("继续游戏", 22)
	resume_button.custom_minimum_size = Vector2(300, 56)
	resume_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	resume_button.pressed.connect(press_resume)
	box.add_child(resume_button)

	iron_label = UiTheme.label("铁人模式：游戏自动保存，不能手动存档或读档。", 18, UiTheme.MUTED)
	iron_label.visible = false
	box.add_child(iron_label)
	var save_title := UiTheme.label("保存到", 18, UiTheme.MUTED)
	box.add_child(save_title)
	slot_section.append(save_title)
	var save_row := HBoxContainer.new()
	save_row.add_theme_constant_override("separation", 10)
	for i in range(1, Slots.COUNT + 1):
		var b := UiTheme.button("槽 %d" % i, 18)
		b.custom_minimum_size = Vector2(120, 48)
		b.pressed.connect(press_save.bind(i))
		save_row.add_child(b)
		save_buttons.append(b)
	box.add_child(save_row)
	slot_section.append(save_row)

	var load_title := UiTheme.label("读取", 18, UiTheme.MUTED)
	box.add_child(load_title)
	slot_section.append(load_title)
	var load_row := HBoxContainer.new()
	load_row.add_theme_constant_override("separation", 10)
	for i in range(1, Slots.COUNT + 1):
		var b := UiTheme.button("槽 %d" % i, 18)
		b.custom_minimum_size = Vector2(120, 48)
		b.pressed.connect(press_load.bind(i))
		load_row.add_child(b)
		load_buttons.append(b)
	box.add_child(load_row)
	slot_section.append(load_row)

	for i in range(1, Slots.COUNT + 1):
		var l := UiTheme.label("", 16, UiTheme.MUTED)
		l.custom_minimum_size = Vector2(660, 22)
		box.add_child(l)
		slot_labels.append(l)
		slot_section.append(l)

	status_label = UiTheme.label("", 18, UiTheme.ACCENT2)
	status_label.custom_minimum_size = Vector2(660, 26)
	box.add_child(status_label)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 10)
	var title_button := UiTheme.button("回标题", 20)
	title_button.custom_minimum_size = Vector2(180, 52)
	title_button.pressed.connect(press_title)
	bottom.add_child(title_button)
	var quit_button := UiTheme.button("退出游戏", 20)
	quit_button.custom_minimum_size = Vector2(180, 52)
	quit_button.pressed.connect(press_quit)
	bottom.add_child(quit_button)
	box.add_child(bottom)


## 打开时刷新三个槽的摘要；调用方可以顺带给一句状态（例如"已保存"）。
func open_for(status: String = "") -> void:
	build()
	visible = true
	refresh()
	set_status(status if status != "" else "Esc 关闭菜单")


func refresh() -> void:
	if not _built:
		return
	for row: Dictionary in Slots.all_summaries():
		var i := int(row["slot"]) - 1
		var text := "槽 %d　%s" % [int(row["slot"]), String(row["label"])]
		if bool(row["exists"]):
			text += "　%s" % String(row["saved_at"])
		slot_labels[i].text = text
		load_buttons[i].disabled = not bool(row["exists"])


## 铁人模式：藏起存读档，只留继续、回标题、退出。
func set_iron_man(on: bool) -> void:
	build()
	for c in slot_section:
		c.visible = not on
	iron_label.visible = on


func set_status(text: String) -> void:
	if status_label != null:
		status_label.text = text


func press_resume() -> void:
	visible = false
	resume.emit()


func press_save(slot: int) -> void:
	if not Slots.valid(slot) or iron_label.visible:
		return
	save_slot.emit(slot)
	refresh()


func press_load(slot: int) -> void:
	if iron_label.visible or not bool(Slots.summary(slot)["exists"]):
		return
	visible = false
	load_slot.emit(slot)


func press_title() -> void:
	visible = false
	to_title.emit()


func press_quit() -> void:
	quit_game.emit()
```

- [ ] **Step 9：改写 `game/ui/main.gd`**

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
	box.add_child(UiTheme.label("任务失败：全员死亡。", 36, UiTheme.ACCENT))
	for id: String in session.game.characters:
		var ch: RefCounted = session.game.characters[id]
		box.add_child(UiTheme.label("%s：%s" % [ch.display_name, String(ch.flags.get("death", ch.flags.get("erased", "死亡")))], 20, UiTheme.MUTED))
	if session.iron_man:
		Slots.erase(Slots.AUTO)
		box.add_child(UiTheme.label("铁人模式：失败就是失败。这一局的存档已经删除。", 22, UiTheme.TEXT))
	else:
		box.add_child(UiTheme.label("宽松模式：回到标题，从存档槽读回去再试一次。", 22, UiTheme.TEXT))
	var back := UiTheme.button("回到标题", 24)
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
	box.add_child(UiTheme.label("二十道光柱降下。", 36, UiTheme.ACCENT2))
	for f: Dictionary in session.farewells:
		box.add_child(UiTheme.label("%s：「%s」" % [String(f["name"]), String(f["line"])], 24, UiTheme.TEXT))
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

- [ ] **Step 10：改写 `game/tools/verify_m1_slice.gd`**

```gdscript
extends SceneTree
## M1 可玩切片的无头验收：加载主场景，按真实界面路径走一遍
## 标题 → 新游戏 → 听规则 → 大厅 → 楼梯井（扶人）→ 激光通道（救马修）
## → 主机房（跟詹岚搭话）→ 推理 → 丧尸战 → 留守 → 自由说辞逼火焰女皇 → 断电
## → 撑到回归 → 结算 → 主神空间（问主神）→ 暂停菜单存槽 → 回标题 → 从槽读回来。
## 用法：godot --headless --path game -s res://tools/verify_m1_slice.gd
## 加 --capture（不带 --headless）可以截一张结算后的图到 art_src/qa/。

const Slots = preload("res://core/save/slots.gd")
const PortraitSource = preload("res://core/art/portrait_source.gd")

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# 上次跑测试可能留下存档，先清空，截图和断言才干净。
	for i in range(1, Slots.COUNT + 1):
		Slots.erase(i)
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

	var title: Control = main.content.get_child(0)
	_expect(title.has_method("press_new"), "启动进标题画面")
	_expect((title.slot_rows() as Array).size() == 3, "标题画面列出三个存档槽")
	await _shot("m1_title.png")
	title.press_new()
	_expect(title.mode_panel.visible, "新游戏先选存档方式")
	title.press_mode(false)
	await process_frame
	_expect(not main.session.iron_man, "选了宽松模式")
	var screen: Control = main.content.get_child(0)
	_expect(screen.has_method("press_choice"), "新游戏进入地点图")
	_expect(String(main.session.phase) == "expedition", "开局在远征阶段")
	_expect(int(main.session.game.characters.size()) == 7, "七名轮回者")

	_expect(screen.press_choice("listen"), "开场选择：听规则")
	_expect(screen.press_move("hall"), "走到大厅")
	await process_frame
	await process_frame
	_expect(bool(Slots.summary(Slots.AUTO)["exists"]), "换地点后自动存档落盘")
	_expect(String(Slots.summary(Slots.AUTO)["label"]).contains("生化危机一"), "自动档摘要写着片名")

	# 禁言：当着剧情人物（马修）提"主神"，当场扣 10 点。
	_expect(screen.press_talk("matthew"), "在大厅跟马修搭话")
	var gag_panel: Control = main.panel
	if gag_panel != null:
		var before := _penalty_count(main)
		gag_panel.press_send("主神到底想让我们干什么")
		_expect(_penalty_count(main) == before + 1, "当着马修提主神被记一次泄密")
		_expect(gag_panel.log_label.text.contains("说漏了嘴"), "对话框里当场提示")
		gag_panel.press_close()
		await process_frame

	_expect(screen.press_move("stairs"), "走到楼梯井")
	_expect(screen.press_choice("help"), "扶掉队的新人")
	_expect(screen.press_move("laser"), "走进激光通道")
	await process_frame
	await process_frame
	var cs: Control = main.get_node_or_null("Cutscene")
	_expect(cs != null, "走进激光通道弹出剧情 CG")
	if cs != null:
		_expect(cs.art.texture != null, "CG 图已加载")
		_expect(String(cs.caption.text).contains("激光网"), "CG 带字幕")
		await create_timer(0.45).timeout
		await _shot("m1_cutscene.png")
		cs.press_continue()
		await process_frame
	_expect(main.session.expedition.st.pending_cutscene.is_empty(), "插图播完自动继续")

	# 说服马修：先过检定，才轮到救人选择。
	var pend: Dictionary = screen.view.pending()
	_expect(String(pend.get("kind", "")) == "check", "插图之后先等说服马修")
	_expect(String(pend.get("id", "")) == "convince_matthew", "检定是说服马修")
	_expect(screen.press_choice("save_matthew") == false or not main.session.expedition.st.pending_check.is_empty(), "没过说服不能直接选")
	screen.select_keywords(["最后", "盯着", "激光"])
	await _shot("m1_persuade_matthew.png")
	_expect(screen.press_persuade_keywords(), "用关键词说服马修")
	await process_frame
	_expect(main.session.expedition.st.pending_check.is_empty(), "说服结算后清空")
	_expect(screen.press_choice("save_matthew"), "拖着马修贴门")
	_expect(screen.press_move("control"), "进入主机房")
	_expect(int(main.session.expedition.st.clock) == 45, "第 45 分钟到达主机房")
	_expect(main.session.expedition.st.tether.is_empty(), "救下马修后绑定解除")

	_expect(screen.has_method("press_talk"), "界面支持搭话")
	_expect(screen.press_talk("zhan_lan"), "跟同队的詹岚搭话")
	var dlg: Control = main.panel
	_expect(dlg != null, "对话框打开")
	if dlg != null:
		_expect(dlg.log_label.text.contains("詹岚"), "开场有台词")
		if PortraitSource.has_portrait("zhan_lan"):
			_expect(dlg.portrait.texture.get_height() == 768, "对话框用的是正式立绘")
		else:
			_expect(dlg.portrait.texture.get_height() == 24, "没有正式立绘时回退像素头像")
		dlg.press_send("你怎么看张杰")
		_expect(main.session.dialogues.has("zhan_lan"), "对话记进存档数据")
		dlg.press_send("他讲规则讲得太顺了")
		_expect(int(main.dialogue.trust_of("zhan_lan")) >= 2, "两次对话涨到 2 点信任")
		_expect(bool(main.session.expedition.st.intel.clues_found.has("rules_too_smooth")), "信任换来线索")
		await _shot("m1_slice_dialogue.png")
		dlg.press_close()
		await process_frame

	screen.press_deduce()
	_expect(int(main.session.expedition.st.clock) == 55, "推理花了 10 分钟")
	await _shot("m1_slice_expedition.png")

	screen.press_rest(15)
	await process_frame
	await process_frame
	var battle: Control = main.content.get_child(0)
	_expect(battle.has_method("press_action"), "第 70 分钟进入战斗界面")
	_expect(battle.view.has_method("objective"), "战斗界面显示目标")
	if battle.view.has_method("objective"):
		_expect(String(battle.view.objective()).contains("消灭"), "丧尸战目标是清场")
	_expect(battle.view.has_method("intents"), "战斗界面显示敌人意图")
	if battle.view.has_method("intents"):
		_expect(battle.view.intents().size() > 0, "能看到敌人意图")
		_expect(int(battle.view.b.intel) == 1, "詹岚的判断力让意图显示到技能")
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
	await _shot("m1_slice_persuade.png")
	_expect(screen.has_method("press_persuade_free"), "界面支持自由说辞")
	var opened := false
	if screen.has_method("press_persuade_free"):
		opened = screen.press_persuade_free()
	_expect(opened, "第 125 分钟打开说服对话")
	var side: Control = main.panel
	_expect(side != null, "说服对话框打开")
	if side != null:
		side.press_send("我知道激光是你控的。不关闭，我就断电拆板——这是威胁。")
		await process_frame
		_expect(bool(main.session.expedition.st.flags.get("queen_helps", false)), "自由说辞说服成功")
		await _shot("m1_slice_persuade_panel.png")
		side.press_close()
		await process_frame
	screen.press_rest(40)
	_expect(int(main.session.expedition.st.clock) == 165, "断电事件在第 160 分钟发生")
	screen.press_rest(5)
	screen.press_rest(17)
	await process_frame
	await process_frame
	_expect(String(main.session.phase) == "settlement", "撑到 3:07 后进入结算")
	# 原著 6500 = 存活 1000 + 救马修 5000 + 精神突破 500；这一趟当着马修说漏嘴一次，扣 10。
	_expect(_found_text(main.content, "6490"), "郑吒结算 6490 点（6500 − 禁言 10）")
	_expect(_found_text(main.content, "B 级支线"), "B 级支线入账")

	var hub_btn := _find_button(main.content, "进入主神空间")
	_expect(hub_btn != null, "结算界面有进入主神空间的按钮")
	if hub_btn != null:
		hub_btn.emit_signal("pressed")
		await process_frame
	_expect(String(main.session.phase) == "hub", "进入主神空间")
	var hub: Control = main.content.get_child(0)
	_expect(hub.has_method("press_entry"), "主神空间界面加载")
	if not hub.has_method("press_entry"):
		_finish()
		return
	_expect(_found_text(main.content, "回归当晚"), "回归当晚")

	hub.press_entry("qigong_low")
	_expect(not main.session.game.characters["zheng_zha"].owned.has("qigong_low"), "当晚不能兑换")
	hub.press_rest()
	_expect(int(main.session.hub.day) == 1, "休息到第 1 天")
	_expect(not hub.view.morning().is_empty(), "第 1 天早上有晨会")
	hub.press_morning("accept")
	_expect(hub.view.morning().is_empty(), "晨会回答完就收起")
	_expect(_found_text(main.content, "第 1 天"), "界面显示第 1 天")

	main.session.hub.split_ticket("zheng_zha", "B")
	main.session.hub.split_ticket("zheng_zha", "C")
	hub.press_entry("qigong_low")
	var zz: RefCounted = main.session.game.characters["zheng_zha"]
	_expect(zz.owned.has("qigong_low"), "兑换到低级气功")
	_expect(zz.energy.has("neili"), "获得内力池")
	hub.press_attr("muscle")
	_expect(int(zz.points) == 5890, "买属性扣 100 点，剩 5890")
	hub.press_create("萝丽")
	_expect(main.session.game.companions.size() == 1, "造出萝丽")

	# 对练：兑换完气功，拿它跟训练傀儡打一场，看得见伤害数字。
	var day_before: int = main.session.hub.day
	var hp_before: float = zz.hp
	hub.open_tab("spar")
	await process_frame
	await _shot("m1_spar.png")
	hub.press_spar("qigong_low" if zz.skills.has("qigong_low") else "punch")
	_expect(int(main.session.hub.day) == day_before + 1, "对练耗 1 天")
	_expect(_found_text(hub.status_label, "打出"), "状态行给出对练伤害")
	_expect(absf(zz.hp - hp_before) < 0.01, "对练不伤角色")
	await _shot("m1_slice_hub.png")

	main._open_pause()
	await process_frame
	_expect(main.pause != null, "Esc 打开暂停菜单")
	await _shot("m1_pause.png")
	if main.pause != null:
		main.pause.press_save(1)
		_expect(bool(Slots.summary(1)["exists"]), "存到槽 1")
		_expect(String(Slots.summary(1)["label"]).contains("主神空间"), "槽 1 摘要写着主神空间")
		main._close_pause()
	main._on_load_slot(1)
	await process_frame
	var loaded: Control = main.content.get_child(0)
	_expect(String(main.session.phase) == "hub", "读档回到主神空间")
	_expect(int(main.session.hub.day) == 2, "读档保留天数（休息 1 天 + 对练 1 天）")
	_expect(main.session.game.characters["zheng_zha"].owned.has("qigong_low"), "读档保留兑换")
	_expect(main.session.game.companions.size() == 1, "读档保留造物")
	_expect(main.session.dialogues.has("zhan_lan"), "读档保留对话记忆")

	_expect(loaded.has_method("press_ask_zhushen"), "主神空间能提问")
	loaded.press_ask_zhushen()
	var zs: Control = main.panel
	_expect(zs != null, "主神对话框打开")
	if zs != null:
		zs.press_send("支线怎么拆分")
		_expect(zs.log_label.text.contains("三个 C"), "主神回答支线规则")
		zs.press_send("下一部是什么")
		_expect(zs.log_label.text.contains("权限"), "越界的问题被拒绝")
		await _shot("m1_slice_zhushen.png")
		zs.press_close()
		await process_frame

	var hurt: Array[Dictionary] = loaded.view.repairs()
	if not hurt.is_empty():
		var before_hp: float = main.session.game.characters[String(hurt[0]["id"])].hp
		loaded.press_repair(String(hurt[0]["id"]))
		_expect(main.session.game.characters[String(hurt[0]["id"])].hp > before_hp, "修复回血")

	for i in 8:
		loaded.press_rest()
	_expect(int(main.session.hub.day) == 9, "休息到第 9 天")
	_expect(bool(loaded.view.can_depart()), "第 9 天可以出发")
	loaded.press_depart()
	await process_frame
	_expect(String(main.session.phase) == "done", "走光柱后阶段结束")
	_expect(_found_text(main.content, "二十道光柱"), "结尾画面")
	_expect(_found_text(main.content, "萝丽："), "走光柱时萝丽说了一句话")

	main._show_title()
	await process_frame
	var back: Control = main.content.get_child(0)
	_expect(back.has_method("press_new"), "回到标题画面")
	back.press_slot(1)
	await process_frame
	_expect(String(main.session.phase) == "hub", "从标题读槽 1 回到主神空间")

	_finish()


## 加 --capture 时把当前画面存到 art_src/qa/（只在非 headless 下有意义）。
func _shot(name: String) -> void:
	if not OS.get_cmdline_user_args().has("--capture"):
		return
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://").path_join("../art_src/qa")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name))


func _expect(cond: bool, message: String) -> void:
	if not cond:
		failures += 1
		printerr("FAIL " + message)


## 结算账本里的罚分条数（禁言每中一句加一条）。
func _penalty_count(main: Node) -> int:
	var st: RefCounted = main.session.expedition.st
	var n := 0
	for row: Dictionary in st.ledger:
		if String(row["kind"]) == "penalty":
			n += 1
	return n


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
	for i in range(1, Slots.COUNT + 1):
		Slots.erase(i)
	Slots.erase(Slots.AUTO)
	print("M1 切片验证：失败 %d 项" % failures)
	quit(0 if failures == 0 else 1)
```

- [ ] **Step 11：在改名的副本里跑切片验收**

```bash
rm -rf _work/p17_verify && mkdir -p _work/p17_verify && cp -r game _work/p17_verify/game
sed -i 's/^config\/name=.*/config\/name="无限恐怖_验收p17"/' _work/p17_verify/game/project.godot
timeout 300 godot --headless --path _work/p17_verify/game -s res://tools/verify_m1_slice.gd 2>&1 | tail -3; echo "exit=${PIPESTATUS[0]}"
```

预期：`M1 切片验证：失败 0 项`，`exit=0`（新增三条：新游戏先选存档方式、第 1 天早上有晨会并能回答、走光柱时萝丽说了一句话）。

- [ ] **Step 12：跑全量与导入**

```bash
bash game/tools/run_tests.sh > _work/p17_run.txt 2>&1; echo "tests exit=$?"; tail -1 _work/p17_run.txt; echo "SCRIPT ERROR: $(grep -c 'SCRIPT ERROR' _work/p17_run.txt)"
godot --headless --path game --import > _work/p17_imp.txt 2>&1; echo "import exit=$?"
git status --short | sort
```

预期：`共 451 个测试，失败 0 个`、`SCRIPT ERROR: 0`、`import exit=0`；`git status` 除了界面文件、验收脚本和两份测试，多出 `companion.gd.uid`、`morning.gd.uid`、`test_companion.gd.uid`、`test_morning.gd.uid`。

- [ ] **Step 13：提交界面与 uid**

```bash
git add game/ui/hub/hub_view.gd game/ui/hub/hub_screen.gd game/ui/event_text.gd game/ui/title_screen.gd game/ui/pause_menu.gd game/ui/main.gd game/tools/verify_m1_slice.gd game/tests/unit/hub/test_hub_view.gd game/tests/unit/ui/test_title.gd game/core/hub/companion.gd.uid game/core/hub/morning.gd.uid game/tests/unit/hub/test_companion.gd.uid game/tests/unit/hub/test_morning.gd.uid
git commit -m "feat(ui): 晨会框、造物页和萝丽对话，新游戏选铁人或宽松，全灭失败画面" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log --oneline -1
```

- [ ] **Step 14：更新 README 进度并提交**

```bash
python -I -X utf8 - <<'EOF'
p = "README.md"
s = open(p, encoding="utf-8").read()
o = "- 计划 16（兑换目录扩到 200 条、按系列拆成七个文件，新增 96 个战斗技能和魔力池；消耗品带着就能在战斗里用，原著锚点条目补上能上场的技能；兑换页显示效果、可只看买得起的）已完成，累计 436 个无界面测试。\n"
n = o + "- 计划 17（萝丽有了心情、亲密、依赖、安心和愿望，能陪她、一起训练、AI 对话，走光柱时有告别；休整每天早上有晨会（结盟、新人去留等六件）；新游戏可选铁人模式，全员死亡显示失败画面、铁人模式删档）已完成，累计 451 个无界面测试。\n"
assert s.count(o) == 1
open(p, "w", encoding="utf-8", newline="\n").write(s.replace(o, n))
print("ok")
EOF
git add README.md
git commit -m "docs: 计划 17 完成，更新进度" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log --oneline -1
git status --short
```

- [ ] **Step 15：验收检查**

```bash
git log --oneline -5
grep -c $'\r' game/core/hub/companion.gd game/core/hub/morning.gd game/ui/main.gd
for f in core/hub/companion.gd core/hub/morning.gd data/hub/m1_morning.json data/ai/personas.json data/scenarios/biohazard1/chapter.json core/hub/hub.gd core/session/session.gd ui/hub/hub_view.gd ui/hub/hub_screen.gd ui/event_text.gd ui/title_screen.gd ui/pause_menu.gd ui/main.gd tools/verify_m1_slice.gd tests/unit/hub/test_companion.gd tests/unit/hub/test_morning.gd tests/unit/session/test_session.gd tests/unit/hub/test_hub_view.gd tests/unit/ui/test_title.gd; do cmp -s "game/$f" "_work/plan_check_p17/game/$f" || echo "DIFF $f"; done
echo "compare done"
test -z "$(git diff --name-only origin/main..HEAD | grep -iE '\.(png|jpe?g|webp|gif|wav|ogg)$')" && echo "no media"
```

预期：三个 `grep -c` 都是 `0`；`compare done` 前没有 `DIFF`；`no media`。
