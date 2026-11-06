# sprite-gen 战斗动画试验报告

日期：2026-11-06。任务卡：002。工具：sprite-gen 3.15.0（component-row revision `db8ab1c245df`），Godot 4.7.2。

## 结论

建议选择 **退回“静态姿势 + Godot 动效”**，作为当前战斗表现方案。

Pipeline A 已能生成两套可导入、可播放的透明图集，人物和日系立绘风总体延续了 001b。但四帧动作的过渡跨度、衣褶/发丝/血迹重绘差异、跨状态初始姿势变化，以及郑吒射击反馈偏弱和局部彩边，使它还不足以支撑全面逐帧动画。丧尸的扑击语义比持枪角色更清楚，可以保留为后续试验样本；仅这一套样本也不足以决定所有敌人采用逐帧动画。

这次通过的是完整生成与 Godot 接入试验，不是所有动作已经达到正式美术质量。动态平滑度仍需要连续观看本机 GIF/场景复审；下文分别记录实际运行证据和视觉检查的边界。

## 产物

| 角色 | 最终目录 | 本地图片 | 运行时文本资源 |
|---|---|---|---|
| 郑吒 | `game/art/style_test/anim/zheng_zha/` | `sprite-sheet-alpha.png` | `manifest.json`、`sprite_frames.tres` |
| 研究员丧尸 | `game/art/style_test/anim/zombie_scientist/` | `sprite-sheet-alpha.png` | `manifest.json`、`sprite_frames.tres` |

每套图集都是 **3072×3072 RGBA**，4 行×4 帧，最终单帧 **768×768**。两角色共 32 帧。

- 郑吒逐帧与 GIF：`art_src/style_test/anim/zheng_zha/frames/`、`qa/`、`previews/`。
- 丧尸逐帧与 GIF：`art_src/style_test/anim/zombie_scientist/run/frames/`、`run/qa/`、角色目录下 `gifs/`。
- 原始横排、提示词、原生报告、初版比较均保留在各角色的 art_src 目录。
- 复现命令：`art_src/style_test/anim/README.md`；完整文件 SHA-256、尺寸、alpha、GIF 元数据：`art_src/style_test/anim/asset-audit.json`。丧尸另有 `qa-summary.json`。
- 演示场景：`game/ui/dev/anim_preview.tscn`。真实 Godot 渲染截图：`art_src/style_test/anim/godot-preview.png`。

图片被 Git 忽略，仅在本机保留。检出本次提交后需恢复本机图片备份或按记录重新生成，才能加载这些资源。

## 生成流程与工具差异

输入是已接受的 `zheng_zha_battle_idle.png`（低位单枪）和 `zombie_scientist_attack.png`；未改输入图。使用 prepare → 原生 gen-set 调度 → extract → compose-atlas，codex 登录渠道，未切换收费服务。

安装的 gen-set CLI 没有转发 `--facing` / `--facing-fix` 的选项。因此 `generate_facing_rows.py` 仅通过原生 `run_set(..., gen_runner=...)` 接口把这些参数传到原生 gen；原工具仍负责并发、身份参考图、layout guide、复用、校验和报告。每次都使用 `--facing-fix regen`，并传非空 `--handed` 关闭原生工具可能采取的镜像回退。未改安装目录，也没有重写生成、抠图、分帧或合成流程。

原始生成使用每格 512×768、24 px 安全边距，magenta（郑吒）/green（丧尸）键。最终采用 LANCZOS、foot-centroid/bottom、pixel_unfake=false、decontam=auto。manifest 中 `frame_variant: "pixel"` 是工具 canonical 帧标签；这里没有转成像素画。

初版 512 宽输出不足以容纳脚部锚点一侧的枪、伸手和侧卧范围，原生 fit 会把整行缩小。保留初版后，将输出 request 的宽度扩大到 768，再由原生 extract/compose 重做。生成时的 prompts、guides 和原图保留原样。郑吒 down 首帧从约 470 px 高恢复为 699 px，idle 为 720 px，消除了明显的整体突然缩小；全部帧落在 y=744 的共同底线。没有局部画图、强制镜像或调速掩盖问题。

## 风格、身份和逐状态结果

郑吒仍是同一黑发、灰衬衫、黑裤黑鞋的角色，黑色单枪始终存在。脸与头身比总体接近输入，部分动作脸更侧、发丝和衬衫褶皱有重绘差异。hit 时支撑手离枪，未完全遵守提示词“双手一直持枪”，但枪仍留在右手，没有多枪或掉枪。

丧尸保留乱黑发、苍白腐败脸、染血破白大褂、胸牌、深裤鞋。脸部、血迹边界、衣摆破口和胸牌不是逐像素锁定，四帧间仍有变化。独立逐帧复核未发现明确多肢、缺肢、错向或裁边。

所有状态均为 4 帧、768×768。原生 `durations_ms` 优先于 fps：4/8/6 fps 对应 250/125/167 ms 每帧。

| 角色/状态 | 标称 fps | 循环 | 朝向 | 逐帧与动作判断 | 透明边缘/局限 |
|---|---:|---|---|---|---|
| 郑吒 idle | 4 | 是 | 右 | 低位单枪、脚底稳定；运动幅度很小 | 原生 inspect 给低运动量 warning，不能当作明显呼吸 |
| 郑吒 attack | 8 | 否 | 右 | 低位→抬枪→伸臂瞄准→回低位，身份稳定 | 未裁边；射击后坐/命中反馈弱，需要独立特效 |
| 郑吒 hit | 6 | 否 | 右 | 守势→轻后仰→后仰峰值→恢复，可辨受击 | 第 2/3 帧手指浅绿边，原生 decontam off 对比也未消除；保留 auto |
| 郑吒 down | 6 | 否 | 头朝右侧 | 屈膝→降低→跪撑→侧卧，终帧枪在手 | 尺度问题已修正；跪撑到侧卧的姿态跨度大，脸略转向观众 |
| 丧尸 idle | 4 | 是 | 左（人工复核） | 四帧摇晃，首末脚姿接近 | 发丝/血迹/衣褶有细节变化；方向模型返回 unknown，见下 |
| 丧尸 attack | 8 | 否 | 左 | 屈膝蓄力→张口→伸手扑击→回收，可读 | 初始屈膝与 idle 差异大；细节有重绘，暂作试验质量 |
| 丧尸 hit | 8 | 否 | 左 | 后仰、前倾、恢复，肢体完整 | 没有明显键色边或裁边；口形、衣摆仍变化 |
| 丧尸 death | 6 | 否 | 头朝左侧 | 屈膝→跪地→双手撑地→蜷卧，可读 | 四帧跨度大；从 idle 切入时姿态更低，需后续衔接设计 |

朝向检查：郑吒四行及丧尸 attack/hit/death 自动观察均与目标相同，action=none；丧尸 idle 为 `unknown / vision-uncertain`，虽有 0.99 自报 confidence，也不能当作自动确认。主审和独立审查逐帧确认鼻向、视线、扑击方向均朝左。全流程没有执行镜像或方向重生。

32 帧均有真实透明和部分 alpha 像素；原生 frame records 全部 `edge_pixels=0`、`chroma_adjacent_pixels=0`，无空帧。丧尸 inspect 无错误/警告，score=100；郑吒 inspect 无错误，保留 idle motion presence `0.0053 < 0.0100` 警告。自动零残留/满分不能替代肉眼检查，尤其不能否定郑吒手指的非键色浅绿残边。

丧尸可见姿态最高分别约 idle 711、attack 605、hit 699、death 首帧 592 px；屈膝、躯干俯仰本身会改变包围盒高度，不能据此全归为整体缩放。扩大单帧已去掉工具带来的额外收缩，源图姿态与局部比例差异仍作为后续限制保留。

## 次数与耗时

两角色各 1 个批次、每批并发 2、每状态 1 次，共 **8 次行图片生成**。没有重生；原生朝向观察是附加检查，不计为图片生成。未使用 Breathe 或 RIFE。

| 角色 | 图片生成自身耗时：idle / attack / hit / down或death | 图片阶段累计 | 批处理实际墙钟 |
|---|---|---:|---:|
| 郑吒 | 120.705 / 139.868 / 162.830 / 163.433 秒 | 586.836 秒 | 617.221 秒，约 10 分 17 秒 |
| 丧尸 | 152.974 / 164.653 / 148.769 / 173.747 秒 | 640.143 秒 | 596.967 秒，约 9 分 57 秒 |

图片自身耗时来自每行生成报告。墙钟由全新生成日志创建到原生 set.report.json 写完的文件时间测得，包含批次内朝向观察等工作；两角色也有并行，不能将这些数直接相加当作整个任务的历时。后处理、人工式检查、Godot 接入和文档时间不包含在表中。

## Godot 导入和实际验证

安装版 manifest 的矩形在 `frame_layout.rows`，fps/loop/durations_ms 实际在 `animation.rows`。导入器按这些明确数据创建 AtlasTexture 和 SpriteFrames，保留重复矩形、播放顺序与毫秒时长，不根据网格猜帧。

导入器校验尺寸、帧矩形边界、正数 fps、loop 类型和时长数量；输入、图集和输出路径统一规范化后限制在工程内。预览支持自动轮播、暂停/继续和手动换状态。复核发现的“恢复时重播已结束非循环动作”已修复并加回归验证。

执行结果：

- `godot --headless --editor --path game --import`：退出 0。
- 两套 manifest 导入：退出 0，生成两个 `.tres`，共八个动画。
- `verify_anim_preview.gd`：实际 AnimatedSprite2D 播放全部八个状态，检查帧推进、循环、单次结束停末帧、矩形/时序、暂停恢复、暂停中切换和轮播；失败 0，无 SCRIPT ERROR。
- 图形模式执行同一验证：退出 0，OpenGL 实际渲染，保存 1920×1080 截图。
- 在编辑器打开场景按 F6，桌面运行窗口出现两角色和完整中文控制。观察到 idle 帧号变化；暂停/继续有效；关闭轮播后逐个切换攻击、受击、倒地/死亡，均正常进入第 4/4 帧并停在终态，没有缺图或崩溃。

桌面工具返回的是实际运行的离散快照，没有连续高帧率录像；因此此检查证明可运行、切换和结束行为，不把它夸大为“全部过渡平滑、绝无闪烁”。静态逐帧检查与上述运行证据共同支持本次试验交付，但仍保留对正式动画质量的否定建议。

QA GIF 为便于重复检查会回绕，即使该状态运行时 loop=false；其 10 ms 时间量化也不同于运行时的 125/167 ms。不要按非循环 GIF 的最后一帧回到第一帧来判定运行时动作有跳帧。

日志位于 `art_src/style_test/anim/` 的 `godot-*.log`、`core-tests.log`。仓库根目录执行 `bash game/tools/run_tests.sh` 得到 **共 32 个测试，失败 0 个**，退出 0。提交前检查图片不受 Git 跟踪，并只提交本任务允许范围的文本、代码、manifest、`.tres` 和 `.gd.uid`。

编辑器启动自动重写过 project.godot 的注释、空行并省略默认 stretch/aspect；检查差异后恢复到任务开始时版本，避免提交范围外变化。生成的文本依据仓库 .gitattributes 统一 LF，保留计时证据的文件时间，并重新计算文本文件校验和。
