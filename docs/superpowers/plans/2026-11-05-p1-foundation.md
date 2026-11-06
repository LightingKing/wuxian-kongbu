# 计划 1：工程骨架与规则内核基础 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立 Godot 工程、无界面测试体系，以及第一批纯规则模块（属性、基因锁发挥率、支线剧情库存、相对击杀奖励、结算、存档），全部有测试，测试锚点取自原著数字。

**Architecture:** `game/core/` 是纯逻辑层，只用 `RefCounted` 和 `preload` 常量，不依赖场景树，所以能在 `godot --headless -s` 下测试（无界面模式下不导入工程时 `class_name` 不会注册，这是实测结论，所以 core 层一律不用 `class_name`）。规则常量放在 `game/data/rules/core_rules.json`，可调。测试由自写的轻量运行器执行，外加一个 shell 包装脚本检查输出里的 `SCRIPT ERROR`，因为 GDScript 的运行时错误不会让测试自动失败。

**Tech Stack:** Godot 4.7.2（GDScript）、Git Bash、Python 3 + Pillow（只用于美术任务卡里的抠图脚本）。

**依据：** `docs/superpowers/specs/2026-11-05-wuxian-kongbu-game-design.md`（v0.6）第 3、5.6、7、10 节；`docs/core-mechanics-analysis.md` 第二节。

**本计划的全部代码都已在临时目录里实际跑通（32 个测试全部通过），照抄即可。**

**仓库：** 远程仓库 `https://github.com/LightingKing/wuxian-kongbu`（执行前为空）。本地工作目录 `I:\workspace\mobilegame\wuxian-kongbu\`，分支 `main`。提交身份只设在本仓库：`LightingKing <LightingKing@users.noreply.github.com>`。全部任务完成后推送到 `origin/main`。

**执行环境注意：**
- 所有命令都在 Git Bash 里运行（`I:\Git\bin\bash.exe`），工作目录为仓库根目录。
- 所有文本文件用 **LF** 换行（`run_tests.sh` 如果是 CRLF，bash 会报错）。本机 Git 的系统配置是 `core.autocrlf=true`，所以 Task 1 加了 `.gitattributes` 强制 LF。
- GDScript 代码块用 **Tab** 缩进，照抄时保留 Tab。

---

## 子计划总览（本计划是其中第 1 个）

设计规格覆盖多个独立子系统，按"一个子系统一份计划"拆开，每份计划都能单独产出可测试的成果：

| 计划 | 内容 | 依赖 |
|---|---|---|
| **P1（本计划）** | 工程骨架、测试体系、规则常量、随机数、属性与派生属性、基因锁发挥率、支线剧情库存、角色、相对击杀奖励、结算、游戏状态与存档；Codex 任务卡 001（美术风格试验） | — |
| P2 | 战斗内核：三排战场、CTB 行动时间轴、技能数据与结算、状态效果、敌人意图、恐惧值与基因锁觉醒/崩溃、死亡；确定性效用 AI；战斗模拟测试 | P1 |
| P3 | 远征内核：地点图、剧情时钟与事件（含剧情惯性）、手表（任务、倒计时、百米绑定、禁言）、分队、结算接入 | P1 |
| P4 | 兑换与主神空间逻辑：效果积木、定价公式（以原著价格为验收锚点）、兑换目录（约 200 条）、前置与双血统风险、代兑、熟练度、修复、造人、休整日 | P1 |
| P5 | 智谋、关系与主神议程骨架：信息模型（事实、线索、推论）、规则发现锁、计策积木与规划器骨架、关系网与凝聚力、主神议程状态 | P1、P2、P3 |
| P6 | AI 接入层：可切换服务商（Anthropic / OpenAI 兼容）、流式输出、意图格式与校验、世界设定库、人设与记忆、离线兜底、AI 输出写入存档 | P1 |
| P7 | M1 内容数据：《生化危机一》地点图、剧情时钟、剧情人物、敌人、技能；第一次休整；规则百科首批条目 | P2~P6 |
| P8 | M1 界面与美术（以 Codex 任务卡交付）：地点图、战斗、主神空间、对话界面；美术批量生产；PC 与安卓导出 | P7 |

---

## 文件结构（本计划创建）

所有路径相对仓库根目录 `I:\workspace\mobilegame\wuxian-kongbu\`。

| 文件 | 职责 |
|---|---|
| `.gitignore` | 忽略 Godot 缓存、导出产物，以及 `_work/` 里含原著片段的材料 |
| `.gitattributes` | 文本文件统一 LF，图片音频按二进制处理 |
| `README.md` | 仓库简介：项目说明、欢迎提建议、`main` 只由维护者提交 |
| `AGENTS.md` | 给 Codex 的项目约定（Codex 每次会自动读取） |
| `game/project.godot` | Godot 工程配置（1920×1080、`canvas_items` 拉伸、兼容渲染器） |
| `game/tests/test_case.gd` | 测试基类：断言、失败收集、断言计数 |
| `game/tests/run_tests.gd` | 测试运行器（`SceneTree` 脚本） |
| `game/tools/run_tests.sh` | 包装脚本：运行测试并把 `SCRIPT ERROR` 视为失败 |
| `game/tests/unit/test_smoke.gd` | 冒烟测试 |
| `game/data/rules/core_rules.json` | 规则常量（属性、派生系数、发挥率、结算、击杀阈值、支线比例） |
| `game/core/util/data_loader.gd` | 读 JSON，报告缺失字段 |
| `game/core/util/rules.gd` | 加载并缓存 `core_rules.json` |
| `game/core/util/rng.gd` | 带种子的随机数，可序列化 |
| `game/core/model/attributes.gd` | 六项属性（自身 + 兑换强化） |
| `game/core/model/derived_stats.gd` | 派生战斗属性 |
| `game/core/model/gene_lock.gd` | 基因锁发挥率 |
| `game/core/economy/plot_tickets.gd` | 支线剧情库存：增减、拆分、合成 |
| `game/core/model/character.gd` | 轮回者：属性、点数、支线、基因锁、恐惧、生死 |
| `game/core/economy/kill_reward.gd` | 相对击杀奖励 |
| `game/core/economy/settlement.gd` | 一部片结束时的个人结算 |
| `game/core/model/game_state.gd` | 整局状态 |
| `game/core/save/save_service.gd` | 存档读写 |
| `game/tests/unit/core/test_*.gd` | 各模块的单元测试 |
| `docs/codex-tasks/001-art-style-test.md` | Codex 任务卡：美术风格试验 |

**运行测试**（在仓库根目录执行）：

```bash
bash game/tools/run_tests.sh
```

只跑某个文件：

```bash
TEST_FILTER=test_rng bash game/tools/run_tests.sh
```

---

### Task 1：仓库与工程骨架

**Files:**
- Create: `.gitignore`、`.gitattributes`、`README.md`、`AGENTS.md`、`game/project.godot`、`game/tests/test_case.gd`、`game/tests/run_tests.gd`、`game/tools/run_tests.sh`、`game/tests/unit/test_smoke.gd`

- [ ] **Step 1：初始化仓库并连接远程**

```bash
cd /i/workspace/mobilegame/wuxian-kongbu
git init -b main
git config user.name "LightingKing"
git config user.email "LightingKing@users.noreply.github.com"
git remote add origin https://github.com/LightingKing/wuxian-kongbu.git
git ls-remote origin
```

预期：`git init` 输出 `Initialized empty Git repository in .../wuxian-kongbu/.git/`；`git ls-remote origin` 没有输出、退出码 0（远程是空仓库）。如果 `ls-remote` 列出了任何分支，**停下来报告**，不要继续。

- [ ] **Step 2：创建 `.gitignore`**

```gitignore
# Godot
game/.godot/
game/export/
game/build/
*.tmp

# 阅读材料里含原著片段，不进版本控制
_work/chunks/
_work/excerpts/
_work/godot_probe/
_work/plan_check/
_work/*_raw.txt

# 系统
.DS_Store
Thumbs.db
```

- [ ] **Step 2b：创建 `.gitattributes`**

```gitattributes
# 统一用 LF：bash 脚本遇到 CRLF 会报错，Godot 也推荐 LF
* text=auto eol=lf
*.png binary
*.jpg binary
*.ogg binary
*.wav binary
```

- [ ] **Step 2c：创建 `README.md`**（仓库简介：欢迎提建议；`main` 只由维护者提交，其他人在自己的分支上改、发 Pull Request）

````markdown
# 无限恐怖 · 2D 回合制同人游戏

以 zhttty 的小说《无限恐怖》为蓝本的 2D 回合制游戏：在主神空间变强，进恐怖片活下去，回来结算——暗黑地牢式的据点 + 远征 + 回合制战斗，永久死亡、恐惧值、基因锁、团战、智者布局，主神和 NPC 由 AI 接管。

引擎 Godot 4.7.2（GDScript），目标平台 Windows 和安卓。

## 当前进度
- 设计规格 v0.6 已完成。
- 正在实施计划 1：工程骨架与规则内核基础。
- 制作节奏：按原著顺序，一部恐怖片一部恐怖片地打磨。第一个里程碑是《生化危机一》+ 第一次主神空间休整。

## 文档
- [设计规格](docs/superpowers/specs/2026-11-05-wuxian-kongbu-game-design.md)
- [核心机制分析](docs/core-mechanics-analysis.md)：主神的行为逻辑、相对奖励、选人与天赋、兑换体系、AI 接管、养成、陪伴、内斗、智谋线、特殊小队、失败的代价
- [全书摘要](docs/novel-summary.md)
- [实施计划](docs/superpowers/plans/)

## 运行测试
需要 Godot 4.7.2 在 PATH 里，在仓库根目录执行（Windows 上用 Git Bash）：

```bash
bash game/tools/run_tests.sh
```

## 欢迎提建议
非常欢迎大家帮忙提建议：玩法、机制、对原著的理解、数值、剧情取舍、美术……什么都可以。直接在 [Issues](https://github.com/LightingKing/wuxian-kongbu/issues) 里提就好。

## 参与方式
- **`main` 分支只由项目维护者提交**，请不要直接向 `main` 推送。
- 想直接动手改：先 Fork 本仓库（协作者也可以在本仓库里新建自己的分支），在**你自己的分支**上提交，然后发 Pull Request。维护者审核后再合并进 `main`。
- 改动前建议先开一个 Issue 说说想法，免得白费工夫。

## 版权说明
这是个人的非商业同人项目，不公开发行游戏本体。小说《无限恐怖》的版权归原作者 zhttty 所有；作品中借用的电影、动漫等元素，版权归各自的权利人。
````

- [ ] **Step 3：创建 `AGENTS.md`**

```markdown
# AGENTS.md：给 Codex 的项目约定

本项目是以小说《无限恐怖》为蓝本的 2D 回合制同人游戏（个人项目，不公开发行）。引擎 Godot 4.7.2，语言 GDScript。

## 先读这些
- 设计规格：`docs/superpowers/specs/2026-11-05-wuxian-kongbu-game-design.md`
- 核心机制分析：`docs/core-mechanics-analysis.md`
- 全书摘要：`docs/novel-summary.md`

## 你的任务从哪里来
- 任务卡在 `docs/codex-tasks/NNN-*.md`，由用户交给你。**只修改任务卡"允许修改"一栏列出的文件和目录。**
- 完成后，在任务卡末尾追加一节 `## 完成汇报`，写明：做了什么、改了哪些文件、怎么验证的、还有哪些问题。

## 目录与所有权
| 目录 | 维护者 | 说明 |
|---|---|---|
| `game/core/` | Claude | 纯规则层。不要修改，除非任务卡明确允许 |
| `game/data/` | Claude | 规则与内容数据（JSON）。不要改格式 |
| `game/tests/` | Claude | 无界面测试 |
| `game/ui/` | Codex | 场景与界面 |
| `game/art/`、`game/audio/` | Codex | 美术与音频资源 |
| `game/tools/` | 双方 | 工具脚本，按任务卡分配 |
| `_work/` | — | 阅读材料，含原著片段，**不要提交** |

## 代码约定
- Tab 缩进，snake_case 命名，尽量写静态类型。
- `game/core/` 里不使用 `class_name`，一律用 `const X = preload("res://...")`。原因：无界面测试在不导入工程时，`class_name` 不会注册。`game/ui/` 里可以用 `class_name`。
- 界面只订阅 core 返回的事件来播放表现，并把玩家的选择交回 core；不要在界面里写规则判断。
- 文本用中文，通过 `tr()` 包装，为以后的翻译留口。

## 界面约定
- 基准分辨率 1920×1080，横屏，`canvas_items` 拉伸，保持宽高比。
- PC（键鼠）和安卓（触屏）都要能操作；可点元素的触控尺寸不小于 48dp；没有悬停时用长按显示详情。

## 美术约定
- 日系动漫立绘风，场景偏暗，具体规范以 `docs/art/` 为准（风格试验通过后建立）。
- 资源一律 PNG；角色、敌人、图标用透明背景。
- 路径：`game/art/<类别>/<id>_<姿势或用途>.png`，例如 `game/art/characters/zheng_zha_idle.png`。

## 验证
- 任何改动完成后都要在仓库根目录运行 `bash game/tools/run_tests.sh`，全部通过才算完成。
```

- [ ] **Step 4：创建 `game/project.godot`**

```ini
; Engine configuration file.
; 由计划 1 创建。界面相关设置在后续计划中补充。
config_version=5

[application]
config/name="无限恐怖"
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

- [ ] **Step 5：创建测试基类 `game/tests/test_case.gd`**

```gdscript
extends RefCounted
## 所有单元测试的基类。测试方法以 test_ 开头；断言失败只记录，不中断。

var _failures: Array[String] = []
var _assert_count := 0


func assert_true(cond: bool, msg: String = "") -> void:
	_assert_count += 1
	if not cond:
		_failures.append("assert_true 失败 %s" % msg)


func assert_false(cond: bool, msg: String = "") -> void:
	assert_true(not cond, msg)


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	_assert_count += 1
	var both_numbers := _is_number(actual) and _is_number(expected)
	if typeof(actual) != typeof(expected) and not both_numbers:
		_failures.append("assert_eq 类型不同：期望 %s，实际 %s %s" % [var_to_str(expected), var_to_str(actual), msg])
		return
	if actual != expected:
		_failures.append("assert_eq：期望 %s，实际 %s %s" % [var_to_str(expected), var_to_str(actual), msg])


func assert_almost(actual: float, expected: float, eps: float = 0.0001, msg: String = "") -> void:
	_assert_count += 1
	if absf(actual - expected) > eps:
		_failures.append("assert_almost：期望 %f，实际 %f %s" % [expected, actual, msg])


func take_failures() -> Array[String]:
	var out := _failures.duplicate()
	_failures.clear()
	return out


func take_assert_count() -> int:
	var n := _assert_count
	_assert_count = 0
	return n


func _is_number(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT
```

- [ ] **Step 6：创建测试运行器 `game/tests/run_tests.gd`**

```gdscript
extends SceneTree
## 无界面测试入口：godot --headless --path game -s res://tests/run_tests.gd
## 环境变量 TEST_FILTER 可只跑路径里包含该字符串的测试文件。

const ROOT := "res://tests/unit"


func _init() -> void:
	var files := _collect(ROOT)
	files.sort()
	var filter := OS.get_environment("TEST_FILTER")
	var total := 0
	var failed := 0
	for path in files:
		if filter != "" and not path.contains(filter):
			continue
		var script: Variant = load(path)
		if script == null or not script.can_instantiate():
			total += 1
			failed += 1
			print("FAIL  %s（脚本无法加载）" % path)
			continue
		var inst: Variant = script.new()
		for m in inst.get_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			total += 1
			if inst.has_method("before_each"):
				inst.call("before_each")
			inst.call(name)
			var fails: Array[String] = inst.take_failures()
			var asserts: int = inst.take_assert_count()
			if asserts == 0:
				fails.append("没有任何断言")
			if fails.is_empty():
				print("ok    %s::%s" % [path.get_file(), name])
			else:
				failed += 1
				print("FAIL  %s::%s" % [path.get_file(), name])
				for f in fails:
					print("        " + f)
	print("\n共 %d 个测试，失败 %d 个" % [total, failed])
	quit(1 if failed > 0 else 0)


func _collect(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	for f in d.get_files():
		if f.begins_with("test_") and f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
	for sub in d.get_directories():
		out.append_array(_collect(dir_path.path_join(sub)))
	return out
```

- [ ] **Step 7：创建包装脚本 `game/tools/run_tests.sh`**

```bash
#!/usr/bin/env bash
# 运行全部无界面测试。运行时错误不会中断 GDScript，所以额外检查输出里的 SCRIPT ERROR。
cd "$(dirname "$0")/.." || exit 2
out=$(godot --headless --path . -s res://tests/run_tests.gd 2>&1)
code=$?
echo "$out"
if echo "$out" | grep -q "SCRIPT ERROR"; then
	echo "!! 检测到脚本错误"
	exit 1
fi
exit $code
```

- [ ] **Step 8：创建冒烟测试 `game/tests/unit/test_smoke.gd`**

```gdscript
extends "res://tests/test_case.gd"


func test_runner_works() -> void:
	assert_eq(1 + 1, 2)
```

- [ ] **Step 9：运行冒烟测试**

Run: `bash game/tools/run_tests.sh`

预期输出（结尾）：

```
ok    test_smoke.gd::test_runner_works

共 1 个测试，失败 0 个
```

退出码 0（`echo $?` 输出 `0`）。

- [ ] **Step 10：确认失败能被发现**

临时创建 `game/tests/unit/test_tmp_fail.gd`：

```gdscript
extends "res://tests/test_case.gd"


func test_should_fail() -> void:
	assert_eq(2, 3, "故意失败")


func test_runtime_error() -> void:
	var d: Dictionary = {}
	var x = d.nope.foo
	assert_true(true)
```

Run: `bash game/tools/run_tests.sh; echo "exit=$?"`

预期：`test_should_fail` 和 `test_runtime_error` 都显示 `FAIL`（后者附"没有任何断言"），输出含 `!! 检测到脚本错误`，最后一行 `exit=1`。

然后删除这个临时文件：

```bash
rm game/tests/unit/test_tmp_fail.gd
```

- [ ] **Step 11：提交**

```bash
git add .gitignore .gitattributes README.md AGENTS.md game/project.godot game/tests/test_case.gd game/tests/run_tests.gd game/tools/run_tests.sh game/tests/unit/test_smoke.gd
git commit -m "chore: 建立 Godot 工程与无界面测试体系" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2：规则常量与数据加载

**Files:**
- Create: `game/data/rules/core_rules.json`、`game/core/util/data_loader.gd`、`game/core/util/rules.gd`
- Test: `game/tests/unit/core/test_data_loader.gd`

- [ ] **Step 1：写测试 `game/tests/unit/core/test_data_loader.gd`**

```gdscript
extends "res://tests/test_case.gd"

const DataLoader = preload("res://core/util/data_loader.gd")
const Rules = preload("res://core/util/rules.gd")


func test_missing_file_reports_error() -> void:
	var res := DataLoader.load_json("res://data/nope.json")
	assert_false(res.ok)
	assert_true(res.error.contains("不存在"))


func test_core_rules_load() -> void:
	var res := DataLoader.load_json(Rules.PATH)
	assert_true(res.ok, res.error)
	var errs := DataLoader.missing_keys(res.data, ["attributes", "settlement", "plot_tickets", "kill_reward"], "core_rules")
	assert_eq(errs.size(), 0, str(errs))


func test_rules_values() -> void:
	assert_eq(int(Rules.get_value("settlement", "survival")), 1000)
	assert_eq(int(Rules.get_value("plot_tickets", "ratio")), 3)
```

- [ ] **Step 2：运行，确认失败**

Run: `TEST_FILTER=test_data_loader bash game/tools/run_tests.sh`

预期：`FAIL  res://tests/unit/core/test_data_loader.gd（脚本无法加载）`（被 preload 的文件还不存在），退出码 1。

- [ ] **Step 3：创建 `game/data/rules/core_rules.json`**

```json
{
	"version": 1,
	"attributes": ["intelligence", "spirit", "cell_vitality", "nerve_reaction", "muscle", "immunity"],
	"attribute_names": {
		"intelligence": "智力",
		"spirit": "精神力",
		"cell_vitality": "细胞活力",
		"nerve_reaction": "神经反应速度",
		"muscle": "肌肉组织强度",
		"immunity": "免疫力强度"
	},
	"human_baseline": 100,
	"points_per_attribute": 10,
	"derived": {
		"hp_base": 40,
		"hp_per_cell_vitality": 0.6,
		"hp_per_muscle": 0.4
	},
	"gene_lock_effectiveness": [0.5, 0.7, 0.85, 0.95, 1.0, 1.0],
	"settlement": {
		"survival": 1000,
		"explain_rules": 100,
		"kill_newbie": -1000,
		"leak_per_sentence": -10
	},
	"kill_reward": {
		"zero_below_ratio": 0.05
	},
	"plot_tickets": {
		"grades": ["D", "C", "B", "A", "S"],
		"ratio": 3
	}
}
```

- [ ] **Step 4：创建 `game/core/util/data_loader.gd`**

```gdscript
extends RefCounted
## 读取 res://data 下的 JSON。返回 {"ok": bool, "data": Variant, "error": String}。
## 注意：JSON 里的数字一律解析成 float，调用方需要自己转 int。


static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "data": null, "error": "文件不存在：" + path}
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		var msg := "%s 第 %d 行：%s" % [path, json.get_error_line(), json.get_error_message()]
		return {"ok": false, "data": null, "error": msg}
	return {"ok": true, "data": json.data, "error": ""}


static func missing_keys(d: Dictionary, keys: Array, ctx: String) -> Array[String]:
	var errs: Array[String] = []
	for k in keys:
		if not d.has(k):
			errs.append("%s 缺少字段 '%s'" % [ctx, k])
	return errs
```

- [ ] **Step 5：创建 `game/core/util/rules.gd`**

```gdscript
extends RefCounted
## 核心规则常量（data/rules/core_rules.json）。第一次访问时加载并缓存。

const DataLoader = preload("res://core/util/data_loader.gd")
const PATH := "res://data/rules/core_rules.json"

static var _cache: Dictionary = {}


static func get_rules() -> Dictionary:
	if _cache.is_empty():
		var res := DataLoader.load_json(PATH)
		assert(res.ok, res.error)
		_cache = res.data
	return _cache


static func get_value(section: String, key: String) -> Variant:
	return get_rules()[section][key]
```

- [ ] **Step 6：运行，确认通过**

Run: `TEST_FILTER=test_data_loader bash game/tools/run_tests.sh`

预期：3 个 `ok`，`共 3 个测试，失败 0 个`。

- [ ] **Step 7：提交**

```bash
git add game/data/rules/core_rules.json game/core/util/data_loader.gd game/core/util/rules.gd game/tests/unit/core/test_data_loader.gd
git commit -m "feat(core): 规则常量与 JSON 加载" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3：带种子的随机数

**Files:**
- Create: `game/core/util/rng.gd`
- Test: `game/tests/unit/core/test_rng.gd`

- [ ] **Step 1：写测试 `game/tests/unit/core/test_rng.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Rng = preload("res://core/util/rng.gd")


func test_same_seed_same_sequence() -> void:
	var a := Rng.new(42)
	var b := Rng.new(42)
	for i in 5:
		assert_eq(a.randi_range(0, 1000), b.randi_range(0, 1000), "第 %d 次" % i)


func test_save_and_restore_continues_sequence() -> void:
	var a := Rng.new(7)
	a.randf()
	a.randf()
	var saved := a.to_dict()
	var expected := [a.randi_range(0, 99999), a.randi_range(0, 99999)]
	var b := Rng.new(0)
	b.load_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_eq([b.randi_range(0, 99999), b.randi_range(0, 99999)], expected)


func test_chance_extremes() -> void:
	var r := Rng.new(1)
	assert_false(r.chance(0.0))
	assert_true(r.chance(1.0))
```

- [ ] **Step 2：运行，确认失败**

Run: `TEST_FILTER=test_rng bash game/tools/run_tests.sh`

预期：`FAIL  res://tests/unit/core/test_rng.gd（脚本无法加载）`。

- [ ] **Step 3：创建 `game/core/util/rng.gd`**

```gdscript
extends RefCounted
## 带种子的随机数。规则层的所有随机都走这里；存档保存 seed 和 state，读档后序列不变。
## seed/state 是 64 位整数，JSON 的 double 存不下，所以序列化成字符串。

var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value


func randf() -> float:
	return _rng.randf()


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func chance(probability: float) -> bool:
	return _rng.randf() < probability


func to_dict() -> Dictionary:
	return {"seed": str(_rng.seed), "state": str(_rng.state)}


func load_dict(d: Dictionary) -> void:
	_rng.seed = String(d["seed"]).to_int()
	_rng.state = String(d["state"]).to_int()
```

- [ ] **Step 4：运行，确认通过**

Run: `TEST_FILTER=test_rng bash game/tools/run_tests.sh`

预期：`共 3 个测试，失败 0 个`。

- [ ] **Step 5：提交**

```bash
git add game/core/util/rng.gd game/tests/unit/core/test_rng.gd
git commit -m "feat(core): 带种子、可存档的随机数" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4：六项属性、派生属性、基因锁发挥率

**Files:**
- Create: `game/core/model/attributes.gd`、`game/core/model/derived_stats.gd`、`game/core/model/gene_lock.gd`
- Test: `game/tests/unit/core/test_attributes.gd`

- [ ] **Step 1：写测试 `game/tests/unit/core/test_attributes.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Attributes = preload("res://core/model/attributes.gd")
const DerivedStats = preload("res://core/model/derived_stats.gd")
const GeneLock = preload("res://core/model/gene_lock.gd")


func test_default_is_human_baseline() -> void:
	var a := Attributes.new()
	for k in Attributes.KEYS:
		assert_almost(a.total(k), 100.0, 0.0001, k)


func test_enhanced_adds_to_total() -> void:
	var a := Attributes.new({"muscle": 112})
	a.add_enhanced("muscle", 190)
	assert_almost(a.total("muscle"), 302.0)


func test_derived_for_ordinary_human() -> void:
	var s := DerivedStats.compute(Attributes.new())
	assert_almost(s.hp_max, 140.0)
	assert_almost(s.speed, 100.0)
	assert_almost(s.attack_mult, 1.0)


func test_derived_for_zheng_zha_after_first_rest() -> void:
	# 原著 L605：郑吒第一次休整后为 智187 精232 细胞321 神经287 肌肉302 免疫331
	var a := Attributes.new({"intelligence": 187, "spirit": 232, "cell_vitality": 321, "nerve_reaction": 287, "muscle": 302, "immunity": 331})
	var s := DerivedStats.compute(a)
	assert_almost(s.hp_max, 40.0 + 0.6 * 321.0 + 0.4 * 302.0)
	assert_almost(s.speed, 287.0)
	assert_almost(s.attack_mult, 3.02)


func test_gene_lock_effectiveness_table() -> void:
	assert_almost(GeneLock.effectiveness(0), 0.5)
	assert_almost(GeneLock.effectiveness(4), 1.0)
	assert_almost(GeneLock.effectiveness(9), 1.0, 0.0001, "超出上限按第五阶")
	assert_almost(GeneLock.effectiveness(-1), 0.5, 0.0001, "低于下限按 0 阶")


func test_round_trip() -> void:
	var a := Attributes.new({"spirit": 122})
	a.add_enhanced("spirit", 110)
	var b := Attributes.new()
	b.load_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	assert_almost(b.total("spirit"), 232.0)
```

- [ ] **Step 2：运行，确认失败**

Run: `TEST_FILTER=test_attributes bash game/tools/run_tests.sh`

预期：`FAIL  res://tests/unit/core/test_attributes.gd（脚本无法加载）`。

- [ ] **Step 3：创建 `game/core/model/attributes.gd`**

```gdscript
extends RefCounted
## 六项基础属性（原著）：智力、精神力、细胞活力、神经反应速度、肌肉组织强度、免疫力强度。常人各约 100。
## base = 自身（天生 + 锻炼，主神评价看不见锻炼部分）；enhanced = 在主神处兑换来的强化量（10 点奖励点数 = 1 点）。

const KEYS: Array[String] = ["intelligence", "spirit", "cell_vitality", "nerve_reaction", "muscle", "immunity"]

var base: Dictionary = {}
var enhanced: Dictionary = {}


func _init(values: Dictionary = {}) -> void:
	for k in KEYS:
		base[k] = float(values.get(k, 100.0))
		enhanced[k] = 0.0


func total(key: String) -> float:
	return float(base[key]) + float(enhanced[key])


func add_enhanced(key: String, amount: float) -> void:
	enhanced[key] = float(enhanced[key]) + amount


func add_trained(key: String, amount: float) -> void:
	base[key] = float(base[key]) + amount


func to_dict() -> Dictionary:
	return {"base": base.duplicate(), "enhanced": enhanced.duplicate()}


func load_dict(d: Dictionary) -> void:
	for k in KEYS:
		base[k] = float(d["base"][k])
		enhanced[k] = float(d["enhanced"][k])
```

- [ ] **Step 4：创建 `game/core/model/derived_stats.gd`**

```gdscript
extends RefCounted
## 由六项属性派生战斗属性（设计规格 3.2，系数在 core_rules.json 的 derived 里，可调）。

const Rules = preload("res://core/util/rules.gd")


static func compute(attrs: RefCounted) -> Dictionary:
	var d: Dictionary = Rules.get_rules()["derived"]
	var cell: float = attrs.total("cell_vitality")
	var muscle: float = attrs.total("muscle")
	return {
		"hp_max": float(d["hp_base"]) + float(d["hp_per_cell_vitality"]) * cell + float(d["hp_per_muscle"]) * muscle,
		"speed": attrs.total("nerve_reaction"),
		"attack_mult": muscle / 100.0,
		"mental_resist": attrs.total("spirit"),
		"infection_resist": attrs.total("immunity"),
		"recovery": cell,
	}
```

- [ ] **Step 5：创建 `game/core/model/gene_lock.gd`**

```gdscript
extends RefCounted
## 基因锁阶数 0~5（原著）。发挥率只作用于 B 级及以上兑换项的效果强度（设计规格 3.4）。

const Rules = preload("res://core/util/rules.gd")
const MAX_STAGE := 5


static func effectiveness(stage: int) -> float:
	var table: Array = Rules.get_rules()["gene_lock_effectiveness"]
	return float(table[clampi(stage, 0, MAX_STAGE)])
```

- [ ] **Step 6：运行，确认通过**

Run: `TEST_FILTER=test_attributes bash game/tools/run_tests.sh`

预期：`共 6 个测试，失败 0 个`。

- [ ] **Step 7：提交**

```bash
git add game/core/model/attributes.gd game/core/model/derived_stats.gd game/core/model/gene_lock.gd game/tests/unit/core/test_attributes.gd
git commit -m "feat(core): 六项属性、派生属性与基因锁发挥率" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5：支线剧情库存

**Files:**
- Create: `game/core/economy/plot_tickets.gd`
- Test: `game/tests/unit/core/test_plot_tickets.gd`

- [ ] **Step 1：写测试 `game/tests/unit/core/test_plot_tickets.gd`**

```gdscript
extends "res://tests/test_case.gd"

const PlotTickets = preload("res://core/economy/plot_tickets.gd")


func test_split_b_into_three_c() -> void:
	var t := PlotTickets.new()
	t.add("B")
	assert_true(t.split("B"))
	assert_eq(t.counts["B"], 0)
	assert_eq(t.counts["C"], 3)


func test_zheng_zha_first_split() -> void:
	# 原著 s01：郑吒把 B 级支线拆成 2 个 C + 3 个 D
	var t := PlotTickets.new()
	t.add("B")
	t.split("B")
	t.split("C")
	assert_eq(t.counts["C"], 2)
	assert_eq(t.counts["D"], 3)


func test_merge_three_b_into_a() -> void:
	# 原著 s05：詹岚的 A 级支线由三个 B 合成
	var t := PlotTickets.new()
	t.add("B", 3)
	assert_true(t.merge("B"))
	assert_eq(t.counts["A"], 1)
	assert_eq(t.counts["B"], 0)


func test_cannot_split_d_or_merge_s() -> void:
	var t := PlotTickets.new()
	t.add("D")
	t.add("S", 3)
	assert_false(t.split("D"))
	assert_false(t.merge("S"))
	assert_eq(t.counts["D"], 1)
	assert_eq(t.counts["S"], 3)


func test_spend_insufficient_changes_nothing() -> void:
	var t := PlotTickets.new()
	t.add("C", 1)
	assert_false(t.spend("C", 2))
	assert_eq(t.counts["C"], 1)
	assert_false(t.merge("C"))
	assert_eq(t.counts["C"], 1)
```

- [ ] **Step 2：运行，确认失败**

Run: `TEST_FILTER=test_plot_tickets bash game/tools/run_tests.sh`

预期：`FAIL  res://tests/unit/core/test_plot_tickets.gd（脚本无法加载）`。

- [ ] **Step 3：创建 `game/core/economy/plot_tickets.gd`**

```gdscript
extends RefCounted
## 支线剧情库存（原著）：D < C < B < A < S，1 个高一级 = 3 个低一级（L401）。
## 原著的"双B"指需要 2 个 B，所以库存只按基础等级计数。

const GRADES: Array[String] = ["D", "C", "B", "A", "S"]
const RATIO := 3

var counts: Dictionary = {"D": 0, "C": 0, "B": 0, "A": 0, "S": 0}


func add(grade: String, n: int = 1) -> void:
	assert(GRADES.has(grade), "未知支线等级：" + grade)
	counts[grade] = int(counts[grade]) + n


func has_at_least(grade: String, n: int = 1) -> bool:
	return int(counts[grade]) >= n


func spend(grade: String, n: int = 1) -> bool:
	if not has_at_least(grade, n):
		return false
	counts[grade] = int(counts[grade]) - n
	return true


## 1 个 grade 拆成 3 个低一级；D 不能再拆。
func split(grade: String) -> bool:
	var i := GRADES.find(grade)
	if i <= 0 or not spend(grade, 1):
		return false
	add(GRADES[i - 1], RATIO)
	return true


## 3 个 grade 合成 1 个高一级；S 不能再合。
func merge(grade: String) -> bool:
	var i := GRADES.find(grade)
	if i < 0 or i >= GRADES.size() - 1 or not spend(grade, RATIO):
		return false
	add(GRADES[i + 1], 1)
	return true


func to_dict() -> Dictionary:
	return counts.duplicate()


func load_dict(d: Dictionary) -> void:
	for g in GRADES:
		counts[g] = int(d.get(g, 0))
```

- [ ] **Step 4：运行，确认通过**

Run: `TEST_FILTER=test_plot_tickets bash game/tools/run_tests.sh`

预期：`共 5 个测试，失败 0 个`。

- [ ] **Step 5：提交**

```bash
git add game/core/economy/plot_tickets.gd game/tests/unit/core/test_plot_tickets.gd
git commit -m "feat(core): 支线剧情库存（拆分与合成）" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6：轮回者

**Files:**
- Create: `game/core/model/character.gd`
- Test: `game/tests/unit/core/test_character.gd`

- [ ] **Step 1：写测试 `game/tests/unit/core/test_character.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Character = preload("res://core/model/character.gd")


func test_new_character_full_hp_and_newbie() -> void:
	var c := Character.new("zheng_zha", "郑吒")
	assert_almost(c.hp, c.hp_max())
	assert_true(c.is_newbie())
	c.films_completed = 1
	assert_false(c.is_newbie())


func test_round_trip_through_json() -> void:
	var c := Character.new("zhan_lan", "詹岚", {"spirit": 130})
	c.points = 1500
	c.tickets.add("D", 2)
	c.gene_lock_stage = 1
	c.flags["writer"] = true
	var d := Character.new()
	d.load_dict(JSON.parse_string(JSON.stringify(c.to_dict())))
	assert_eq(d.id, "zhan_lan")
	assert_eq(d.points, 1500)
	assert_eq(d.tickets.counts["D"], 2)
	assert_eq(d.gene_lock_stage, 1)
	assert_almost(d.attributes.total("spirit"), 130.0)
	assert_true(d.flags["writer"])
```

- [ ] **Step 2：运行，确认失败**

Run: `TEST_FILTER=test_character bash game/tools/run_tests.sh`

预期：`FAIL  res://tests/unit/core/test_character.gd（脚本无法加载）`。

- [ ] **Step 3：创建 `game/core/model/character.gd`**

```gdscript
extends RefCounted
## 一个轮回者。点数和支线是个人的（原著里每人各自结算、各自兑换）。

const Attributes = preload("res://core/model/attributes.gd")
const PlotTickets = preload("res://core/economy/plot_tickets.gd")
const DerivedStats = preload("res://core/model/derived_stats.gd")

var id: String = ""
var display_name: String = ""
var attributes: RefCounted = Attributes.new()
var tickets: RefCounted = PlotTickets.new()
var points: int = 0
var gene_lock_stage: int = 0
var fear: float = 0.0
var hp: float = 0.0
var alive: bool = true
var films_completed: int = 0
var revived_once: bool = false
var flags: Dictionary = {}


func _init(char_id: String = "", name: String = "", attr_values: Dictionary = {}) -> void:
	id = char_id
	display_name = name
	attributes = Attributes.new(attr_values)
	hp = hp_max()


func hp_max() -> float:
	return float(DerivedStats.compute(attributes)["hp_max"])


## 原著：未完成过任何一部片的人算新人（复活免费）。
func is_newbie() -> bool:
	return films_completed == 0


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
```

- [ ] **Step 4：运行，确认通过**

Run: `TEST_FILTER=test_character bash game/tools/run_tests.sh`

预期：`共 2 个测试，失败 0 个`。

- [ ] **Step 5：提交**

```bash
git add game/core/model/character.gd game/tests/unit/core/test_character.gd
git commit -m "feat(core): 轮回者数据模型" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7：相对击杀奖励

**Files:**
- Create: `game/core/economy/kill_reward.gd`
- Test: `game/tests/unit/core/test_kill_reward.gd`

- [ ] **Step 1：写测试 `game/tests/unit/core/test_kill_reward.gd`**

```gdscript
extends "res://tests/test_case.gd"

const KillReward = preload("res://core/economy/kill_reward.gd")


func test_licker_curve_from_novel() -> void:
	# 爬行者基础价 100：普通人打它（威胁高于自己）给满额；队伍变强后递减
	assert_almost(KillReward.points_for_kill(100.0, 300.0, 120.0), 100.0, 0.0001, "生化危机一")
	assert_almost(KillReward.points_for_kill(100.0, 300.0, 600.0), 50.0, 0.0001, "生化危机二")
	assert_almost(KillReward.points_for_kill(100.0, 300.0, 1200.0), 25.0, 0.0001, "偷袭生化")


func test_trivial_kill_gives_nothing() -> void:
	# 威胁不到自身评价战力的 5%：像玩一样，不给分
	assert_almost(KillReward.points_for_kill(100.0, 40.0, 1000.0), 0.0)


func test_ratio_exactly_at_cutoff_still_counts() -> void:
	assert_almost(KillReward.points_for_kill(100.0, 50.0, 1000.0), 5.0)


func test_zombie_tenth_point_each() -> void:
	# 原著 L50：10 只丧尸 = 1 点（对普通人）
	assert_almost(KillReward.points_for_kill(0.1, 100.0, 100.0), 0.1)
```

- [ ] **Step 2：运行，确认失败**

Run: `TEST_FILTER=test_kill_reward bash game/tools/run_tests.sh`

预期：`FAIL  res://tests/unit/core/test_kill_reward.gd（脚本无法加载）`。

- [ ] **Step 3：创建 `game/core/economy/kill_reward.gd`**

```gdscript
extends RefCounted
## 击杀奖励与相对难度挂钩（核心机制分析 第二节）：
##   奖励 = 基础价 × min(1, 怪物威胁 / 击杀者的评价战力)
## 比值低于阈值（默认 0.05）时为 0——"像玩一样"的杀戮不给分。
## 标定（原著）：爬行者 100（生化危机一）→ 50（生化危机二，L6524）→ 25（偷袭生化，L13099）。
## 评价战力只算主神"看得见"的部分（兑换），不含自创技能和基因锁，由调用方传入。

const Rules = preload("res://core/util/rules.gd")


static func points_for_kill(base_value: float, enemy_threat: float, killer_rating_power: float) -> float:
	if killer_rating_power <= 0.0:
		return base_value
	var ratio := enemy_threat / killer_rating_power
	var zero_below := float(Rules.get_value("kill_reward", "zero_below_ratio"))
	if ratio < zero_below:
		return 0.0
	return base_value * minf(1.0, ratio)
```

- [ ] **Step 4：运行，确认通过**

Run: `TEST_FILTER=test_kill_reward bash game/tools/run_tests.sh`

预期：`共 4 个测试，失败 0 个`。

- [ ] **Step 5：提交**

```bash
git add game/core/economy/kill_reward.gd game/tests/unit/core/test_kill_reward.gd
git commit -m "feat(core): 与相对难度挂钩的击杀奖励" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8：一部片的个人结算

**Files:**
- Create: `game/core/economy/settlement.gd`
- Test: `game/tests/unit/core/test_settlement.gd`

- [ ] **Step 1：写测试 `game/tests/unit/core/test_settlement.gd`**

```gdscript
extends "res://tests/test_case.gd"

const Settlement = preload("res://core/economy/settlement.gd")
const KillReward = preload("res://core/economy/kill_reward.gd")


func test_zheng_zha_first_film_is_6502() -> void:
	# 原著 L482：6502 = 1000 基本 + 5000（B 级支线）+ 500 其他 + 2（杀丧尸）
	var entries: Array = [
		{"kind": "survival", "points": 1000, "label": "存活"},
		{"kind": "side_plot", "points": 5000, "grade": "B", "label": "救下马修"},
		{"kind": "bonus", "points": 500, "label": "精神临界值突破"},
	]
	for i in 20:
		entries.append({"kind": "kill", "points": KillReward.points_for_kill(0.1, 100.0, 100.0)})
	var r := Settlement.settle(entries, 0)
	assert_eq(r.delta, 6502)
	assert_eq(r.final_points, 6502)
	assert_eq(r.tickets, ["B"])
	assert_false(r.erased)


func test_fractional_kills_round_down() -> void:
	var entries: Array = []
	for i in 19:
		entries.append({"kind": "kill", "points": 0.1})
	assert_eq(Settlement.settle(entries, 0).delta, 1)


func test_negative_result_is_erased() -> void:
	# 原著 L1872：奖励点数成负数就会被主神抹杀
	var r := Settlement.settle([{"kind": "penalty", "points": -1000, "label": "杀死新人"}], 200)
	assert_eq(r.final_points, -800)
	assert_true(r.erased)


func test_leak_penalty_absorbed_by_survival() -> void:
	# 原著：李萧毅说漏"奖励点"被扣 10 点，结算时被存活奖励抵消
	var r := Settlement.settle([
		{"kind": "penalty", "points": -10, "label": "泄密"},
		{"kind": "survival", "points": 1000, "label": "存活"},
	], 0)
	assert_eq(r.final_points, 990)
	assert_false(r.erased)
```

- [ ] **Step 2：运行，确认失败**

Run: `TEST_FILTER=test_settlement bash game/tools/run_tests.sh`

预期：`FAIL  res://tests/unit/core/test_settlement.gd（脚本无法加载）`。

- [ ] **Step 3：创建 `game/core/economy/settlement.gd`**

```gdscript
extends RefCounted
## 一部恐怖片结束时的个人结算。
## entries 每条：{"kind": String, "points": float, "grade": String（可选，支线等级）, "label": String}
##   kind = "survival"（存活固定奖励）| "kill"（击杀，可为小数，结算时合计后向下取整）
##        | "side_plot"（支线完成：点数 + 一个支线等级）| "bonus"（特殊奖励）| "penalty"（扣分，points 为负）
## 返回 {"delta": int, "final_points": int, "tickets": Array[String], "erased": bool, "lines": Array[String]}
## erased = 结算后点数为负 → 被主神抹杀（原著 L1872）。


static func settle(entries: Array, current_points: int) -> Dictionary:
	var kill_sum := 0.0
	var other := 0
	var tickets: Array[String] = []
	var lines: Array[String] = []
	for e in entries:
		var kind: String = e["kind"]
		var pts: float = float(e.get("points", 0.0))
		var label: String = e.get("label", kind)
		match kind:
			"kill":
				kill_sum += pts
			"side_plot":
				other += int(pts)
				var grade: String = e.get("grade", "")
				if grade != "":
					tickets.append(grade)
				lines.append("%s：%+d 点，%s 级支线一个" % [label, int(pts), grade])
			"survival", "bonus", "penalty":
				other += int(pts)
				lines.append("%s：%+d 点" % [label, int(pts)])
			_:
				assert(false, "未知结算类型：" + kind)
	var kill_points := int(floor(kill_sum))
	if kill_sum > 0.0:
		lines.append("击杀：%+d 点" % kill_points)
	var delta := other + kill_points
	var final_points := current_points + delta
	return {
		"delta": delta,
		"final_points": final_points,
		"tickets": tickets,
		"erased": final_points < 0,
		"lines": lines,
	}
```

- [ ] **Step 4：运行，确认通过**

Run: `TEST_FILTER=test_settlement bash game/tools/run_tests.sh`

预期：`共 4 个测试，失败 0 个`，其中 `test_zheng_zha_first_film_is_6502` 为 `ok`。

- [ ] **Step 5：提交**

```bash
git add game/core/economy/settlement.gd game/tests/unit/core/test_settlement.gd
git commit -m "feat(core): 一部片的个人结算（原著 6502 点锚点）" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9：游戏状态与存档

**Files:**
- Create: `game/core/model/game_state.gd`、`game/core/save/save_service.gd`
- Test: `game/tests/unit/core/test_save_service.gd`

- [ ] **Step 1：写测试 `game/tests/unit/core/test_save_service.gd`**

```gdscript
extends "res://tests/test_case.gd"

const GameState = preload("res://core/model/game_state.gd")
const Character = preload("res://core/model/character.gd")
const SaveService = preload("res://core/save/save_service.gd")

const PATH := "user://test_save_roundtrip.json"


func test_save_and_load_round_trip() -> void:
	var s := GameState.new(12345)
	var z := Character.new("zheng_zha", "郑吒", {"nerve_reaction": 131})
	z.points = 6502
	z.tickets.add("C", 2)
	s.add_character(z)
	s.add_character(Character.new("zhang_jie", "张杰"))
	s.team_rating = 1
	s.films_record.append("biohazard1")
	assert_eq(SaveService.save_to(PATH, s), OK)
	var loaded: Variant = SaveService.load_from(PATH)
	assert_true(loaded != null)
	assert_eq(loaded.characters.size(), 2)
	assert_eq(loaded.characters["zheng_zha"].points, 6502)
	assert_eq(loaded.characters["zheng_zha"].tickets.counts["C"], 2)
	assert_eq(loaded.team_rating, 1)
	assert_eq(loaded.films_record, ["biohazard1"])
	assert_true(loaded.iron_man)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_rng_sequence_survives_save() -> void:
	var s := GameState.new(99)
	s.rng.randf()
	SaveService.save_to(PATH, s)
	var expected: int = s.rng.randi_range(0, 99999)
	var loaded: Variant = SaveService.load_from(PATH)
	var actual: int = loaded.rng.randi_range(0, 99999)
	assert_eq(actual, expected)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_missing_save_returns_null() -> void:
	assert_true(SaveService.load_from("user://does_not_exist.json") == null)


func test_living_characters() -> void:
	var s := GameState.new()
	var a := Character.new("a", "甲")
	var b := Character.new("b", "乙")
	b.alive = false
	s.add_character(a)
	s.add_character(b)
	assert_eq(s.living_characters().size(), 1)
```

- [ ] **Step 2：运行，确认失败**

Run: `TEST_FILTER=test_save_service bash game/tools/run_tests.sh`

预期：`FAIL  res://tests/unit/core/test_save_service.gd（脚本无法加载）`。

- [ ] **Step 3：创建 `game/core/model/game_state.gd`**

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
	flags = (d["flags"] as Dictionary).duplicate(true)
```

- [ ] **Step 4：创建 `game/core/save/save_service.gd`**

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
```

- [ ] **Step 5：运行，确认通过**

Run: `TEST_FILTER=test_save_service bash game/tools/run_tests.sh`

预期：`共 4 个测试，失败 0 个`。

- [ ] **Step 6：提交**

```bash
git add game/core/model/game_state.gd game/core/save/save_service.gd game/tests/unit/core/test_save_service.gd
git commit -m "feat(core): 游戏状态与存档读写" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10：Codex 任务卡 001（美术风格试验）

这张任务卡不依赖本计划的其他任务，写好后就可以交给 Codex，和后续计划并行。

**Files:**
- Create: `docs/codex-tasks/001-art-style-test.md`

- [ ] **Step 1：创建 `docs/codex-tasks/001-art-style-test.md`**

```markdown
# 任务卡 001：美术风格试验

## 目标
在批量生产美术之前，验证生图能否稳定做出本项目需要的风格、尺寸、透明背景，以及同一角色在多张图里保持一致。

## 先读
- `AGENTS.md`
- 设计规格第 11 节"美术规格"：`docs/superpowers/specs/2026-11-05-wuxian-kongbu-game-design.md`
- 全书摘要里《生化危机一》的部分：`docs/novel-summary.md`

## 允许修改
- `game/art/style_test/`（新建，放全部产出）
- `game/tools/chroma_key.py`（新建，仅在生图不能直接给出透明背景时需要）
- `docs/art/style-test-report.md`（新建）
- 本任务卡末尾的"完成汇报"一节

## 风格前缀（所有图共用，写在每条提示词最前面）
> 日系动漫立绘风格，线条干净利落，偏写实的头身比例（约 7 头身），赛璐璐上色带少量柔和阴影；整体色调偏暗、偏冷，带一点胶片颗粒感，恐怖片氛围；人物清晰，背景阴森。

## 要产出的图
1. **郑吒设定图**（先做这张，作为后面几张的参考图）：二十多岁的中国男性公司白领，短黑发，五官端正但神情疲惫，白衬衫、深色西裤、黑皮鞋，正面全身站立，纯色背景。文件 `game/art/style_test/zheng_zha_reference.png`，尺寸不限。
2. **郑吒立绘 ×2**：刚在高速列车车厢里醒来，惊惶而警觉。一张平静，一张恐惧。半身到大腿，**1024×1536，透明背景**。文件 `zheng_zha_portrait_calm.png`、`zheng_zha_portrait_fear.png`。
3. **郑吒战斗形象**：全身，**面朝画面右侧**，双手持手枪的戒备姿势，**512×768，透明背景**，脚底贴近画面下沿。文件 `zheng_zha_battle_idle.png`。
4. **丧尸**：地下生化研究所里穿白大褂的研究员丧尸，皮肤灰白，眼睛浑浊，**面朝画面左侧**，向前扑咬，**512×768，透明背景**。文件 `zombie_scientist_attack.png`。
5. **激光通道背景**：地下研究所里纯白金属墙面的长走廊，冷白顶灯，尽头一张红色激光网正逼近，压抑。**1920×1080**，不透明。文件 `bg_laser_corridor.png`。

## 透明背景的做法
如果生图不能直接输出透明通道：
1. 在纯绿色（#00FF00）背景上生成；
2. 写 `game/tools/chroma_key.py`（Python 3 + Pillow，本机已装 Pillow 12），命令行用法：`python game/tools/chroma_key.py 输入.png 输出.png`，把接近 #00FF00 的像素变透明，并对边缘做 1~2 像素的去绿边处理；
3. 用它处理第 2~4 张图。

## 验收
- 上面 6 个文件都在 `game/art/style_test/` 下，尺寸符合要求；第 2~4 张有真正的透明通道（四角像素 alpha = 0）。
- 第 2、3 张里的郑吒和设定图看得出是同一个人。
- `docs/art/style-test-report.md` 写清楚：
  - 每张图实际用的完整提示词；
  - 一致性、手部、透明边缘这些问题各自的情况；
  - 建议：这套风格能不能批量生产；不能的话，怎么调整（例如降级为"立绘 + 剪影战斗形象"）。
- 在仓库根目录运行 `bash game/tools/run_tests.sh`，全部通过（确认没有碰坏其他东西）。

## 完成汇报
（Codex 在这里追加）
```

- [ ] **Step 2：提交**

```bash
git add docs/codex-tasks/001-art-style-test.md
git commit -m "docs: Codex 任务卡 001 美术风格试验" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 3：告诉用户**：任务卡 001 已就绪，可以交给 Codex。

---

### Task 11：全量验证与收尾

**Files:**
- Create: `docs/superpowers/specs/`、`docs/novel-summary.md`、`docs/core-mechanics-analysis.md` 纳入版本控制（已存在，只提交）

- [ ] **Step 1：跑全部测试**

Run: `bash game/tools/run_tests.sh; echo "exit=$?"`

预期：结尾为 `共 32 个测试，失败 0 个`，`exit=0`，输出里没有 `SCRIPT ERROR`。

- [ ] **Step 2：确认工程能被 Godot 编辑器导入**

Run: `godot --headless --path game --import; echo "exit=$?"`

预期：`exit=0`，生成 `game/.godot/`（已被 `.gitignore` 忽略）。

- [ ] **Step 3：提交已有的设计文档**

```bash
git add docs/novel-summary.md docs/core-mechanics-analysis.md docs/superpowers/specs/2026-11-05-wuxian-kongbu-game-design.md docs/superpowers/plans/2026-11-05-p1-foundation.md docs/codex-tasks/000-execute-plan-p1.md
git commit -m "docs: 全书摘要、核心机制分析、设计规格与计划 1" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

- [ ] **Step 4：确认工作区干净**

Run: `git status --short`

预期：只可能列出 `_work/` 下未被忽略的文件（摘要、分析材料）。是否纳入版本控制由用户决定，本计划不提交它们。

- [ ] **Step 5：推送到远程**

```bash
git push -u origin main
git log --oneline
```

预期：推送成功（`branch 'main' set up to track 'origin/main'`）；`git log --oneline` 列出 11 个提交（Task 1~10 各一个，Task 11 一个）。如果推送要求输入账号密码或失败，**停下来报告**，不要尝试其他认证方式。
