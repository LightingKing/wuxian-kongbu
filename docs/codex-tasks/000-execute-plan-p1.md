# 任务卡 000：执行计划 1（工程骨架与规则内核基础）

## 你的角色
你是这个项目的实现者。设计和计划由 Claude 写好，计划里的代码已经在临时目录里跑通（32 个测试全部通过）。你的工作是**严格照计划执行**，完成后由 Claude 验收。

## 先读
- **计划（逐条执行的依据）**：`docs/superpowers/plans/2026-11-05-p1-foundation.md`
- 设计规格（背景，了解即可）：`docs/superpowers/specs/2026-11-05-wuxian-kongbu-game-design.md`

## 执行规则
1. 按 Task 1 → Task 11 的顺序，逐个 Step 执行。**不要修改计划文件本身**（包括勾选框），进度记在完成汇报里。
2. **代码块一字不改地照抄。** 文件内容、文件名、路径都以计划为准；不要顺手优化、重命名、调整格式或补充功能。
   - GDScript 保留 **Tab** 缩进；
   - 所有文本文件用 **LF** 换行、UTF-8 无 BOM。
3. **命令在 Git Bash 里执行**，不要改写成 PowerShell 语法：
   `I:\Git\bin\bash.exe -lc "cd /i/workspace/mobilegame/wuxian-kongbu && <计划里的命令>"`
4. 每个"运行，确认失败/通过"的步骤，都把实际输出和计划里的"预期"对比：
   - 一致 → 继续；
   - 不一致 → **立刻停下**。不要为了让它通过去改计划里的代码。把命令、完整输出和你的判断写进完成汇报，然后结束。
5. 提交信息、提交次数照计划（共 11 个提交）。提交身份在 Task 1 里设在本仓库，**不要改全局 git 配置**。
6. **推送只在 Task 11 Step 5 做一次**：`git push -u origin main`。如果要求输入账号密码或推送失败，停下来报告；不要尝试别的认证方式，**不要 force push**。
7. 不要碰 `_work/` 目录（含原著片段，已被忽略）；不要提交计划之外的文件。
8. **本任务卡的授权范围**：可以创建或修改计划 1"文件结构"表里列出的全部文件，以及本任务卡末尾的"完成汇报"。除此之外不要改任何文件。这是对 `AGENTS.md` 里"`game/core`、`game/data`、`game/tests` 由 Claude 维护"的一次性授权。

## 完成汇报
全部做完（或中途停下）后，在本文件末尾追加下面这些内容，**不需要提交**，Claude 会在本地查看。同样的内容也在你的最后一条回复里给出。
- 每个 Task：完成或未完成；有没有偏差，有就写清楚
- `bash game/tools/run_tests.sh` 输出的最后 5 行
- `git log --oneline` 的完整输出
- `git push` 的输出
- 遇到的问题，以及你认为计划里有疑问的地方

---
（以下由 Codex 追加）

## 完成汇报

- Task 1：未完成。已执行 Step 1，创建仓库并连接远程；已创建 Step 2～8 所列文件。Step 9 运行冒烟测试时停止。
- Task 2：未完成，未开始。
- Task 3：未完成，未开始。
- Task 4：未完成，未开始。
- Task 5：未完成，未开始。
- Task 6：未完成，未开始。
- Task 7：未完成，未开始。
- Task 8：未完成，未开始。
- Task 9：未完成，未开始。
- Task 10：未完成，未开始。
- Task 11：未完成，未开始。

Task 1 Step 9 实际命令：

~~~
bash game/tools/run_tests.sh; echo $?
~~~

实际输出：

~~~
game/tools/run_tests.sh: line 4: godot: command not found
0
~~~

预期应为冒烟测试通过，结尾为 ok    test_smoke.gd::test_runner_works、共 1 个测试，失败 0 个，退出码 0。实际找不到 godot，与预期不一致，因此按规则停止。

bash game/tools/run_tests.sh 输出最后 5 行：

~~~
game/tools/run_tests.sh: line 4: godot: command not found
0
~~~

git log --oneline 完整输出：

~~~
wsl: Failed to start the systemd user session for 'data'. See journalctl for more details.
fatal: your current branch 'main' does not have any commits yet
git_log_exit=0
~~~

git push 输出：未执行（在 Task 1 Step 9 验证失败后已停止）。

遇到的问题与计划疑问：

- 计划示例路径 /i/workspace/mobilegame/wuxian-kongbu 在当前 Git Bash 中不存在，实际挂载路径为 /mnt/i/workspace/mobilegame/wuxian-kongbu，执行时使用了等价的实际挂载路径。
- Git Bash 启动时额外输出 wsl: Failed to start the systemd user session for 'data'. See journalctl for more details.。
- 当前环境的 PATH 中没有 godot，导致 Step 9 无法运行测试；未修改计划代码来绕过。
- 尚未产生提交，未执行推送。

## 续行完成汇报（安装 Godot 后）

用户要求安装 Godot 后继续执行。检查确认本机已有计划指定版本 Godot 4.7.2，版本输出为：

~~~
4.7.2.stable.official.ed1daf0bf
~~~

已在用户 PATH 已包含的 C:\Users\Administrator\.local\bin 下配置 godot 包装器，使 Git Bash 可直接调用该版本的 console 可执行文件。

- Task 1：完成。Step 9 冒烟测试通过，Step 10 故障探测符合预期，Step 11 已提交，提交为 219fa63。
- Task 2：未完成。Step 1 已创建 game/tests/unit/core/test_data_loader.gd；Step 2 运行失败后停止，未创建实现文件，未提交。
- Task 3：未完成，未开始。
- Task 4：未完成，未开始。
- Task 5：未完成，未开始。
- Task 6：未完成，未开始。
- Task 7：未完成，未开始。
- Task 8：未完成，未开始。
- Task 9：未完成，未开始。
- Task 10：未完成，未开始。
- Task 11：未完成，未开始。

Task 2 Step 2 实际命令：

~~~
TEST_FILTER=test_data_loader bash game/tools/run_tests.sh
~~~

实际输出：

~~~
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org

SCRIPT ERROR: Parse Error: Preload file "res://core/util/data_loader.gd" does not exist.
   at: GDScript::reload (res://tests/unit/core/test_data_loader.gd:3)
SCRIPT ERROR: Parse Error: Preload file "res://core/util/rules.gd" does not exist.
   at: GDScript::reload (res://tests/unit/core/test_data_loader.gd:4)
SCRIPT ERROR: Parse Error: Cannot infer the type of "res" variable because the value doesn't have a set type.
   at: GDScript::reload (res://tests/unit/core/test_data_loader.gd:8)
SCRIPT ERROR: Parse Error: Cannot infer the type of "res" variable because the value doesn't have a set type.
   at: GDScript::reload (res://tests/unit/core/test_data_loader.gd:14)
SCRIPT ERROR: Parse Error: Cannot infer the type of "errs" variable because the value doesn't have a set type.
   at: GDScript::reload (res://tests/unit/core/test_data_loader.gd:16)
SCRIPT ERROR: Failed to load script ...
FAIL  res://tests/unit/core/test_data_loader.gd（脚本无法加载）
ok    test_smoke.gd::test_runner_works

共 2 个测试，失败 1 个
!! 检测到脚本错误
~~~

预期是 test_data_loader 文件显示 FAIL 并退出码 1；实际额外出现多条 SCRIPT ERROR，且 TEST_FILTER=test_data_loader 没有过滤掉 test_smoke。按任务卡规则，实际输出与预期不一致，立即停止；没有修改计划代码来绕过。

本次停止时未执行新的 git log 或 git push；此前仍只有 Task 1 的一个提交，Task 2 未提交。

## 最终续行完成汇报（Task 11 Step 4 停止）

- Task 1：完成，提交 219fa63。
- Task 2：完成，提交 8254715。
- Task 3：完成，提交 84ae097。
- Task 4：完成，提交 dd6564a。
- Task 5：完成，提交 c46c253。
- Task 6：完成，提交 1fdb5dd。
- Task 7：完成，提交 714dcba。
- Task 8：完成，提交 8bf8eb5。
- Task 9：完成，提交 c46f17c。
- Task 10：完成，提交 a8be610；任务卡 001 已就绪。
- Task 11：未完成。Step 1 全量测试通过，Step 2 Godot 导入通过；Step 4 工作区检查发现计划未预期的 .gd.uid 文件后停止。Step 3 文档提交和 Step 5 推送未执行。

Task 11 Step 1 实际结果：

~~~
共 32 个测试，失败 0 个
exit=0
~~~

Task 11 Step 2 实际结果以 exit=0 结束，并生成 game/.godot/。

Task 11 Step 4 实际命令：

~~~
git status --short
~~~

实际输出：

~~~
?? _work/
?? docs/codex-tasks/000-execute-plan-p1.md
?? docs/core-mechanics-analysis.md
?? docs/novel-summary.md
?? docs/superpowers/
?? game/core/economy/kill_reward.gd.uid
?? game/core/economy/plot_tickets.gd.uid
?? game/core/economy/settlement.gd.uid
?? game/core/model/attributes.gd.uid
?? game/core/model/character.gd.uid
?? game/core/model/derived_stats.gd.uid
?? game/core/model/game_state.gd.uid
?? game/core/model/gene_lock.gd.uid
?? game/core/save/save_service.gd.uid
?? game/core/util/data_loader.gd.uid
?? game/core/util/rng.gd.uid
?? game/core/util/rules.gd.uid
?? game/tests/run_tests.gd.uid
?? game/tests/test_case.gd.uid
?? game/tests/unit/core/test_attributes.gd.uid
?? game/tests/unit/core/test_character.gd.uid
?? game/tests/unit/core/test_data_loader.gd.uid
?? game/tests/unit/core/test_kill_reward.gd.uid
?? game/tests/unit/core/test_plot_tickets.gd.uid
?? game/tests/unit/core/test_rng.gd.uid
?? game/tests/unit/core/test_save_service.gd.uid
?? game/tests/unit/core/test_settlement.gd.uid
?? game/tests/unit/test_smoke.gd.uid
~~~

预期只可能列出 _work/ 下未被忽略的文件；实际还有 23 个 Godot 生成的 .gd.uid 文件以及计划文档未提交文件，因此按规则停止。没有删除这些文件来强行匹配预期。

全量测试输出的结尾：

~~~
ok    test_settlement.gd::test_negative_result_is_erased
ok    test_settlement.gd::test_leak_penalty_absorbed_by_survival
ok    test_smoke.gd::test_runner_works

共 32 个测试，失败 0 个
exit=0
~~~

git log --oneline 完整输出：

~~~
a8be610 docs: Codex 任务卡 001 美术风格试验
c46f17c feat(core): 游戏状态与存档读写
8bf8eb5 feat(core): 一部片的个人结算（原著 6502 点锚点）
714dcba feat(core): 与相对难度挂钩的击杀奖励
1fdb5dd feat(core): 轮回者数据模型
c46c253 feat(core): 支线剧情库存（拆分与合成）
dd6564a feat(core): 六项属性、派生属性与基因锁发挥率
84ae097 feat(core): 带种子、可存档的随机数
8254715 feat(core): 规则常量与 JSON 加载
219fa63 chore: 建立 Godot 工程与无界面测试体系
~~~

git push 输出：未执行，因为 Task 11 Step 4 已按规则停止。

问题与计划疑问：

- 当前 Git Bash 的工作区路径为 /mnt/i/workspace/mobilegame/wuxian-kongbu；计划示例中的 /i 路径只在由 Windows cmd 启动的 Git Bash 中可用。
- Godot 4.7.2 已存在；已配置 Git Bash 的 godot 包装器以调用 console 可执行文件。
- Git Bash 直接向 Windows Godot 传递 TEST_FILTER 失败，过滤测试使用了临时 cmd 环境适配；实现代码和测试运行器未修改。
- Godot 4.7.2 导入时生成 .gd.uid sidecar 文件，计划未将其列入 .gitignore 或 Step 4 预期；因此未擅自删除、忽略或提交这些文件。

## 收尾完成汇报

1. 修正存档缩进：已将 game/core/save/save_service.gd 第 11 行改为计划原文的字面量反斜杠加 t。检查命令输出为：

~~~
11:^If.store_string(JSON.stringify(state.to_dict(), "	"))$
~~~

已提交：cbd19cc fix(core): 存档缩进改回计划原文的转义写法。

2. 已在 AGENTS.md 代码约定中加入 .uid 文件必须随脚本提交的规则。执行 git add AGENTS.md game 后，git diff --cached --name-only 正好列出 AGENTS.md 加 23 个 .gd.uid，共 24 个文件。已提交：516bbe3 chore: 纳入 Godot 生成的脚本 uid 文件。

3. 全量测试通过：

~~~
共 32 个测试，失败 0 个
exit=0
~~~

输出中没有 SCRIPT ERROR。

4. 已执行计划 Task 11 Step 3 并提交设计文档：1f3c3cb docs: 全书摘要、核心机制分析、设计规格与计划 1。

5. git status --short 输出：

~~~
?? _work/
~~~

与预期一致。

6. 已执行计划 Task 11 Step 5 的唯一一次 git push -u origin main。该进程超过一分钟没有任何推送结果、凭据提示或错误输出，已中断；随后 git ls-remote origin refs/heads/main 无输出，确认远程 main 尚未建立。没有重试、没有更换认证方式、没有 force push。

捕获到的 git push 输出仅有 Git Bash 启动提示：

~~~
wsl: Failed to start the systemd user session for 'data'. See journalctl for more details.
~~~

7. 本节是在推送尝试后追加，未提交。

git log --oneline 完整输出：

~~~
1f3c3cb docs: 全书摘要、核心机制分析、设计规格与计划 1
516bbe3 chore: 纳入 Godot 生成的脚本 uid 文件
cbd19cc fix(core): 存档缩进改回计划原文的转义写法
a8be610 docs: Codex 任务卡 001 美术风格试验
c46f17c feat(core): 游戏状态与存档读写
8bf8eb5 feat(core): 一部片的个人结算（原著 6502 点锚点）
714dcba feat(core): 与相对难度挂钩的击杀奖励
1fdb5dd feat(core): 轮回者数据模型
c46c253 feat(core): 支线剧情库存（拆分与合成）
dd6564a feat(core): 六项属性、派生属性与基因锁发挥率
84ae097 feat(core): 带种子、可存档的随机数
8254715 feat(core): 规则常量与 JSON 加载
219fa63 chore: 建立 Godot 工程与无界面测试体系
~~~

## 验收记录（Claude，2026-11-06）

- 13 个提交逐个核对：文件范围与计划一致；作者 LightingKing（noreply 邮箱），每个都带 Co-Authored-By；全部 LF、权限 100644。
- 全量测试 32 个全部通过；文件内容与验证副本一致（`AGENTS.md` 多出 uid 规则一行，属预期）。
- 推送卡住的原因：Codex 的 bash 是 WSL，WSL 里的 git 拿不到 Windows 凭据管理器里的 GitHub 登录，一直在等一个看不见的用户名输入。改由 Windows Git 推送成功，远程 `main` 为 `1f3c3cb`。
- 以后的计划里 Codex 只提交、不推送，由 Claude 验收后推送。
