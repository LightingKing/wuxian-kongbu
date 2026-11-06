# 丧尸动画试验 QA

## 范围与产物

- 基图：`game/art/style_test/zombie_scientist_attack.png`，使用任务 001 已验收的朝左丧尸；本次未改基图。
- 角色工作目录：`art_src/style_test/anim/zombie_scientist/`；原生运行目录为其中的 `run/`。
- 最终成品：`game/art/style_test/anim/zombie_scientist/sprite-sheet-alpha.png` 和 `manifest.json`，由原生 compose 输出逐字节复制。`.tres` 和 Godot 动态验收由其他代理负责。
- 最终图集为 3072×3072 RGBA；`frame_layout` 为四行、每行四帧，每帧 768×768，安全边距 24px。
- QA 动图和逐帧图：`run/qa/<state>.gif`、`run/qa/<state>-contact.png`、`run/qa/all-contact.png`。另外保存了原生 `compose-gif` 产物至 `gifs/`。

| 状态 | 帧数 | 运行时 fps | 循环 | 静态复核结论 |
|---|---:|---:|---|---|
| idle | 4 | 4 | 是 | pass-static，首末姿态接近；动态循环衔接由主代理在 Godot 验证 |
| attack | 4 | 8 | 否 | best-effort，蓄力、张口伸臂、扑咬、回收可读；姿态跨度和细节变化需结合播放判断 |
| hit | 4 | 8 | 否 | pass-static，后仰受击与前屈恢复可读；动态闪烁未由本代理认证 |
| death | 4 | 6 | 否 | best-effort，失稳、跪撑、蜷卧倒地可读；四帧间的节奏和过渡平滑度需播放判断 |

采用指南推荐的简单动作四帧配置，没有通过补重复帧或改播放速度掩盖动作问题。运行时以 `manifest.animation.rows` 的 fps、`durations_ms`、loop 为准；GIF 存储延时按其格式量化，不替代运行时配置。

## 原生流程与朝向适配

全部生成使用 sprite-gen 3.15.0、`--provider codex` 与已有 ChatGPT 登录；没有切换付费 provider、使用 RIFE、镜像、手切栅格或手写抽帧。Python 与 CLI 都来自 `I:/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/`。

原生 `gen-set` CLI 没有 `--facing`、`--direction`、`--facing-fix` 参数。共享的 `art_src/style_test/anim/generate_facing_rows.py` 只通过原生 `gen_set.run_set` 的 `gen_runner` 扩展点，向现有 `gen` 调用追加 `--direction side --facing left --facing-fix regen --handed "the ID badge=left chest"`。排程、引用解析、校验、日志和报告仍由原生工具负责。非空 `--handed` 禁止内部方向修复退回镜像。

生成前 `workflow --kind sprite --base-image ... --motion-method gpt-rows --confirmed-access codex` 返回 ready；通过 `WSLENV` 传递 `SPRITE_GEN_CODEX_UNAVAILABLE=ask`。选择绿色色键 `#00FF00`，避开角色大褂上的深红血迹；用原生 `extract --decontam auto` 清理边缘。

主要命令在仓库根目录、指定 bash 下执行。以下 `sprite-gen.exe` 和 `python.exe` 均指前述虚拟环境中的可执行文件：

```bash
sprite-gen.exe prepare --out-dir art_src/style_test/anim/zombie_scientist/run --character-id zombie_scientist --base-image game/art/style_test/zombie_scientist_attack.png --description 'The same accepted zombie scientist, facing left, retaining the existing ID badge on the left chest.' --chroma-key '#00FF00' --request art_src/style_test/anim/zombie_scientist/request.json
python.exe art_src/style_test/anim/generate_facing_rows.py --run-dir art_src/style_test/anim/zombie_scientist/run --provider codex --facing left --handed 'the ID badge=left chest' --concurrency 2
sprite-gen.exe extract --run-dir art_src/style_test/anim/zombie_scientist/run --decontam auto
sprite-gen.exe compose-atlas --run-dir art_src/style_test/anim/zombie_scientist/run
python.exe ../tools/sprite-gen/scripts/preview_animation.py --run-dir art_src/style_test/anim/zombie_scientist/run
sprite-gen.exe compose-gif --run-dir art_src/style_test/anim/zombie_scientist/run --out-dir art_src/style_test/anim/zombie_scientist/gifs
sprite-gen.exe inspect --run-dir art_src/style_test/anim/zombie_scientist/run --decontam auto
sprite-gen.exe score --inspect-report art_src/style_test/anim/zombie_scientist/run/sprite-inspect.report.json
python.exe art_src/style_test/anim/zombie_scientist/record_qa.py
```

## 生成次数与耗时

一个批次，并发两行，共四次动作行生成，每行一次；没有重生动作行。四个生成报告中的 `extra.facing.action` 都为 `none`，没有方向重画或镜像。不要把生成耗时、方向观察等阶段的不同计时混成一个数字。

| 状态 | 原生 gen-set 行任务墙钟（秒） | 图片报告 elapsed_seconds（秒） | 原生方向观察 |
|---|---:|---:|---|
| idle | 407.9 | 152.974 | unknown / vision-uncertain；目视四帧朝左 |
| attack | 201.0 | 164.653 | left / already-matched |
| hit | 184.6 | 148.769 | left / already-matched |
| death | 211.1 | 173.747 | left / already-matched |

批次观测墙钟约 **596.967 秒（9 分 57 秒）**，依据新建 `gen-set-attempt-1.log` 的创建时间到原生 `set.report.json` 写入时间计算；时间戳、计算口径和每行原生报告见 `qa-summary.json`。并发行任务耗时的总和不是实际等待时间。

提示词中的朝向和胸牌位置与原生追加句有重复，工具记录了 `prompt_notes: repeat`；没有方向冲突。idle 的 unknown 没有被改写成自动检查通过，目视观察与工具结果分别记录。

## 输出画布调整及证据

生成时请求和布局引导为 512×768，24px 边距。第一次原生提取同样使用 512×768，四行均成功，但较宽的攻击姿势在 foot-centroid 对齐后触发整行缩小。初版请求、帧和日志保存在 `evidence-cell-512/`。

随后仅将原生运行请求的输出 cell 改为 768×768，再执行同一个 `extract --decontam auto`；生成原图、生成提示词和初始 `request.json` 未改。共提取两次、合成一次。未手改人物比例或逐帧缩放。当前 `run/sprite-request.json` 是最终提取配方，原始生成配方仍在 `request.json` 与 `evidence-cell-512/sprite-request.json`。

| 状态 | 512 宽版该行最大可见高度 | 768 宽版该行最大可见高度 |
|---|---:|---:|
| idle | 691px | 711px |
| attack | 429px | 605px |
| hit | 608px | 699px |
| death | 504px | 592px |

上表是 alpha 包围盒高度，不是头身比或同姿态尺度测量。attack 和 death 有明显屈膝、低伏与倒地姿势，不能仅因包围盒矮就断言人物被等比例缩小。扩大 cell 解决了原生适配追加的缩小；原图的姿态、细节和潜在尺度变化仍需按实际游戏切换效果判断。

`fit.pixel_unfake=false`，使用 Lanczos、foot-centroid、bottom 和 ground_frames；没有像素化或调色板量化。原生 compose 在 manifest 中把默认 canonical 分支标为 `frame_variant: "pixel"`，这是工具分支标签，不代表本次开启了 pixel_unfake；未为改标签而篡改原生 manifest。

## 检查结果与限制

- 两次提取均为原生 components 分离，没有 slot fallback；最终 16 帧均非空，768×768 RGBA，原生 `edge_pixels=0`、`chroma_adjacent_pixels=0`。
- `extract`、`compose-atlas`、`inspect` 均 `ok=true`，errors/warnings 为空；原生 score 为 100，四行各 100。未改检查阈值或压制 warning；这些结果不代表动作生产质量已被自动证明。
- 主代理分配的独立复核和本代理逐帧检查均未发现必须重生的多肢、缺肢、错向、裁切缺陷。黑发、灰肤、破损白大褂、深灰裤、鞋和胸牌保持可识别的一致性。
- 头发、血迹、衣服破口、胸牌与手指细节在帧间有重绘变化；轮廓仍有细小浅色过渡边。生成结果比基图有局部线条、口形和着色变化，不能视为精确复制。
- idle 首末头、肩、手的姿态接近，脚姿接近，可作为循环候选。attack 初态与 idle 存在明显姿态差；death 只有四个关键姿势，落地过渡跨度较大。这些问题不能靠静态 contact 证明没有跳动。
- 已生成 QA GIF，但本代理未启动实际 GIF/GUI 播放器，避免与主代理的 Godot GUI 操作冲突。实际八状态轮播、循环衔接与节奏结论由主代理写入总报告。
- 第一条 score 命令曾把相对 `--output` 当成仓库相对路径，而工具将其再次拼接在 run 下，导致输出路径错误；原错误日志保存在 `score-path-error.log`。改用工具默认输出位置后原生 score 成功，未修改代码、图像或评分阈值。

## 校验和

`qa-summary.json` 保存基图、每行 raw、提示词、生成报告、16 张帧、四张 QA GIF 和最终文件的 SHA-256、尺寸、alpha 数据与计时。`record_qa.py` 只读取已有产物并记录元数据，不生成、裁切、重画或改变任何图片。

- 最终图集 SHA-256：`c58ef054c8d6c9252164475ab18e469b94f4d7caff043a5ad69ca7135586554e`
- 最终 manifest SHA-256：`8fdd90ab2eee5ada2c3f0faea0bea756c1ead58408295aa7f38b71788bcd9bfb`（按仓库 .gitattributes 统一 LF 后重新计算；PNG 未变化）

建议仅把该结果当作敌人逐帧动画的试验候选，在 Godot 中通过动态复核后再决定是否小批量采用；不凭自动分数承诺无人验收批量生产。
