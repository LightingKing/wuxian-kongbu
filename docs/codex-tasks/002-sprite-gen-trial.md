# 任务卡 002：用 sprite-gen 试做战斗动画

## 目标
验证 [sprite-gen](https://github.com/aldegad/sprite-gen)（Apache-2.0，Codex/Claude 技能 + Python CLI）能不能把我们日系立绘风的战斗形象做成逐帧动画，并接进 Godot。结论决定设计规格第 11 节：战斗形象是"静态姿势 + Godot 动效"，还是"逐帧动画"。

## 前置
任务卡 001（美术风格试验）已完成：有郑吒设定图、郑吒战斗形象、丧尸图，并确认 Codex 生图可用。

## 允许修改
- `game/art/style_test/anim/`（新建）
- `game/tools/import_sprite_atlas.gd`（新建）
- `game/ui/dev/`（新建，演示场景）
- `docs/art/sprite-gen-report.md`（新建）
- 本任务卡末尾的"完成汇报"
- 不要修改 `game/core/`、`game/data/`、`game/tests/`

## 步骤
1. **工具已装好，不需要再装**：sprite-gen 技能和命令行都已安装（`SPRITE_GEN_ROOT=I:\workspace\mobilegame\tools\sprite-gen`，本机用法见 `~/.codex/AGENTS.md`），codex 生图已实测可用，能直接出透明背景。
2. **生成**，以 001 的 `zheng_zha_battle_idle.png` 和 `zombie_scientist_attack.png` 为基础图，走 Pipeline A（`prepare` → `gen-set --provider codex` → `extract` → `compose-atlas`）：
   - 郑吒（面朝右）：`idle`（可用 Breathe 做确定性的呼吸起伏）、`attack`（举枪射击）、`hit`（受击后仰）、`down`（倒地）
   - 丧尸（面朝左）：`idle`（摇晃）、`attack`（扑咬）、`hit`、`death`
   - 朝向用 `--facing-fix regen` 检查，不要直接镜像（手枪等单侧物件镜像后会错位）
3. **产出**：每个角色放在 `game/art/style_test/anim/<id>/`，包括 `sprite-sheet-alpha.png`、`manifest.json`、QA 用的 GIF。
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

## 完成汇报
（Codex 在这里追加）
