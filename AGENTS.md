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
| `game/ai/` | Claude | AI 接入层：服务商、意图校验、人设、兜底。不要修改，除非任务卡明确允许 |
| `game/ui/` | Codex | 场景与界面 |
| `game/art/`、`game/audio/` | Codex | 美术与音频资源 |
| `game/tools/` | 双方 | 工具脚本，按任务卡分配 |
| `_work/` | — | 阅读材料，含原著片段，**不要提交** |

## 代码约定
- Tab 缩进，snake_case 命名，尽量写静态类型。
- `game/core/` 里不使用 `class_name`，一律用 `const X = preload("res://...")`。原因：无界面测试在不导入工程时，`class_name` 不会注册。`game/ui/` 里可以用 `class_name`。
- Godot 为每个脚本生成的 `*.uid` 文件（如 `rng.gd.uid`）要和脚本一起提交，不要删除，也不要加进 `.gitignore`。
- 界面只订阅 core 返回的事件来播放表现，并把玩家的选择交回 core；不要在界面里写规则判断。
- 文本用中文，通过 `tr()` 包装，为以后的翻译留口。

## 界面约定
- 基准分辨率 1920×1080，横屏，`canvas_items` 拉伸，保持宽高比。
- PC（键鼠）和安卓（触屏）都要能操作；可点元素的触控尺寸不小于 48dp；没有悬停时用长按显示详情。

## 美术约定
- **两套画风**：玩法画面（战斗、地点探索、主神空间）用 Q 版像素；剧情（对话立绘、剧情插图、过场）用日系动漫插画。规格见设计规格第 11 节，具体规范以 `docs/art/` 为准。
- 像素图：Godot 里纹理过滤设为 Nearest，只做整数倍放大；同一套格子和调色板。像素层内部分辨率 480×270，界面和文字按 1920×1080 原生分辨率绘制。
- 资源一律 PNG；角色、敌人、图标用透明背景。
- **图片不进仓库**：png/jpg/webp/gif 已在 `.gitignore` 里忽略，只在本机保留，不要 `git add -f`。生成图片用的提示词、生成报告、QA 校验和（含 SHA-256）照常提交，别人可以照着重新生成。
- 只有最终成品放在 `game/art/`；原图、中间文件、提示词、报告放在仓库根目录的 `art_src/`（不在 Godot 工程里，不会被导入和打包）。
- 生图、动画图集、抠图一律用本机的 sprite-gen 技能（本机说明见 `~/.codex/AGENTS.md`），不要另写同类脚本。
- 路径：`game/art/<类别>/<id>_<姿势或用途>.png`，例如 `game/art/characters/zheng_zha_idle.png`。

## 验证
- 任何改动完成后都要在仓库根目录运行 `bash game/tools/run_tests.sh`，全部通过才算完成。
