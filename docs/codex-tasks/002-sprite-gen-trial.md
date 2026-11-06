# 任务卡 002：用 sprite-gen 试做战斗动画

## 目标
验证 [sprite-gen](https://github.com/aldegad/sprite-gen)（Apache-2.0，Codex/Claude 技能 + Python CLI）能不能把我们日系立绘风的战斗形象做成逐帧动画，并接进 Godot。结论决定设计规格第 11 节：战斗形象是"静态姿势 + Godot 动效"，还是"逐帧动画"。

## 前置
任务卡 001 和返工 001b 已完成：有郑吒设定图、重画后的低位持枪战斗形象、丧尸图，并确认 Codex 生图可用。

## 允许修改
- `game/art/style_test/anim/`（新建，只放成品）
- `art_src/style_test/anim/`（新建，放中间文件和 QA 用的 GIF）
- `game/tools/import_sprite_atlas.gd`（新建）
- `game/ui/dev/`（新建，演示场景）
- `docs/art/sprite-gen-report.md`（新建）
- 本任务卡末尾的"完成汇报"
- 不要修改 `game/core/`、`game/data/`、`game/tests/`

## 步骤
1. **工具已装好，不需要再装**：sprite-gen 技能和命令行都已安装（`SPRITE_GEN_ROOT=I:\workspace\mobilegame\tools\sprite-gen`，本机用法见 `~/.codex/AGENTS.md`），codex 生图已实测可用，能直接出透明背景。
2. **生成**，以 001b 重画后的 `zheng_zha_battle_idle.png` 和 `zombie_scientist_attack.png` 为基础图，走 Pipeline A（`prepare` → `gen-set --provider codex` → `extract` → `compose-atlas`）：
   - 郑吒（面朝右）：`idle`（可用 Breathe 做确定性的呼吸起伏）、`attack`（举枪射击）、`hit`（受击后仰）、`down`（倒地）
   - 丧尸（面朝左）：`idle`（摇晃）、`attack`（扑咬）、`hit`、`death`
   - 朝向用 `--facing-fix regen` 检查，不要直接镜像（手枪等单侧物件镜像后会错位）
3. **产出**：成品放 `game/art/style_test/anim/<id>/`：`sprite-sheet-alpha.png`、`manifest.json`、导入生成的 `.tres`。QA 用的 GIF、逐帧中间文件放 `art_src/style_test/anim/<id>/`。图片不进仓库（见 `AGENTS.md`），manifest 和 `.tres` 照常提交。
4. **Godot 导入**：写 `game/tools/import_sprite_atlas.gd`，读取 `manifest.json` 的 `frame_layout`（帧矩形、每个状态的 fps、是否循环），生成 `SpriteFrames` 资源（`.tres`，每个状态一个动画）。再做一个演示场景 `game/ui/dev/anim_preview.tscn`，用 `AnimatedSprite2D` 轮流播放每个状态。
5. **报告** `docs/art/sprite-gen-report.md`：
   - 和 001 的静态图比，风格和人物一致性如何（脸、发型、服装、手枪）
   - 每个状态的帧数、单帧尺寸、透明边缘、朝向问题
   - 每个角色用了多少次生成、耗时多久
   - 建议三选一：全面采用逐帧动画 / 只给敌人和小怪用 / 退回"静态姿势 + Godot 动效"

## 验收
- 两个角色的图集、manifest、QA GIF 都在。
- 演示场景在编辑器里能正常播放全部状态。
- 仓库根目录运行 `bash game/tools/run_tests.sh` 全部通过。
- 报告写完。
- `git ls-files '*.png' '*.gif'` 输出为空；一个提交，**只提交，不推送**。

## 完成汇报
（Codex 在这里追加）

### 2026-11-06 执行结果

已完成两角色 Pipeline A 试做与 Godot 接入。每角色 4 个状态、每状态 4 帧，最终单帧 768×768、图集 3072×3072 RGBA；各生成 4 次，无重生、无镜像，使用 codex 登录渠道。生成批次墙钟约为郑吒 617.221 秒、丧尸 596.967 秒，具体定义和逐行时间见报告。

改动与本地产物：

- `game/art/style_test/anim/<id>/`：两套最终 PNG、manifest、SpriteFrames `.tres`；PNG 本机保留且由 Git 忽略。
- `art_src/style_test/anim/`：请求、提示词、原生生成/提取/合成报告、原图与帧、QA GIF、初版对比、SHA-256 元数据及复现说明。图片和 GIF 均不提交。
- `game/tools/import_sprite_atlas.gd` 及 UID：依据明确帧矩形、fps、loop、durations_ms 导入；真实 schema 的时序在 `animation.rows`。
- `game/ui/dev/anim_preview.tscn`、预览/验证脚本及 UID：八个动作轮播、暂停恢复、手动切换。
- `docs/art/sprite-gen-report.md`：完整试验结果和推荐方案；本任务卡追加本节。

验证结果：

- 原生 components 提取和 atlas 合成通过，32 帧非空，边界/键色邻近像素指标均为 0。
- Godot headless editor 导入、两套 `.tres` 生成、八个实际动画播放及控制回归检查退出码均为 0；`动画导入与预览验证：失败 0 项`，没有 SCRIPT ERROR。
- 图形模式真实渲染通过，截图在 `art_src/style_test/anim/godot-preview.png`。编辑器 F6 运行后，已观察待机帧推进，暂停/恢复、攻击、受击及倒地/死亡切换和末帧正常。
- 仓库根目录执行 `bash game/tools/run_tests.sh`：`共 32 个测试，失败 0 个`，退出 0；日志保存在 art_src。
- `git ls-files '*.png' '*.gif'` 输出为空。按本次要求只作一个本地提交，不推送；原有 `_work/` 未纳入提交。

问题与处理：

- 当前 gen-set CLI 不转发朝向参数，因此使用薄适配器调用原生 run_set，并传 `--facing-fix regen` 及禁止镜像回退的非空 handed；没有重写生图/抠图/分帧/合成工具。
- 初版 512 宽输出会使伸手/侧卧所在整行缩小，保存初版后用原生工具扩大输出宽度重提取。郑吒倒地首帧已恢复到 699 px 高，待机为 720 px。
- 保留郑吒 idle 低运动量警告、射击反馈弱、hit 手指浅绿边，以及丧尸逐帧细节与状态衔接变化。丧尸 idle 自动朝向观察为 unknown，独立逐帧复核确认朝左；未把未知记录改写成自动通过。
- 运行验证采用实际播放快照及事件检查，未用连续高帧率录像确认所有过渡无闪烁；不宣称这些试验图已达到正式动画质量。
- 建议选择 **退回“静态姿势 + Godot 动效”**，保留两套图集作为后续试验依据。
