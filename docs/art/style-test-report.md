# 美术风格试验报告

本报告记录任务卡 001 的最终候选及处理过程。六张素材均已完成本轮尺寸与图像模式检查，四张透明角色图已检查 alpha 边界；丧尸重画及去色键处理已完成，最终资产脚本 QA 和全部 32 个游戏测试通过。

## 工具与执行环境

- 命令从仓库根目录运行，bash 实际为 WSL，仓库路径为 `/mnt/i/workspace/mobilegame/wuxian-kongbu`。
- sprite-gen 3.15.0 的实际可执行文件：`I:/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/sprite-gen.exe`；从 WSL 调用时使用 `/mnt/i/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/sprite-gen.exe`。
- Python/Pillow 使用同一虚拟环境：`I:/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/python.exe`，Pillow 12.3.0。没有使用全局 Python 运行 sprite-gen。
- 所有生成均显式指定 `--provider codex`，使用 ChatGPT 登录；未切换到 OpenAI API、Grok 等按次计费服务，未传 codex 不支持的 `--quality`。
- Windows 子进程读取提示词及输出时使用 Windows 可见路径。提示词原文及自动附加句来自各图片的 `*.report.json`，在下文完整列出。

## 生成与画布处理

郑吒设定图先生成。平静、恐惧和战斗形象均传入同一设定图作为 `--ref`。平静立绘现为闭嘴、肩膀放松的警觉状态；恐惧立绘为瞪眼、皱眉、微张嘴和汗珠。两张最新立绘均去掉了此前误入画的座椅。

带参考图的透明生成由 sprite-gen 自动采用洋红色 chroma key，并以 `--decontam palette` 去除边缘色污染。战斗图的最终透明候选另经 `sprite-gen cutout --key magenta --decontam auto` 处理。战斗图使用 `--facing right --direction side --facing-fix regen`，最终为双手共同持一把手枪、面朝画面右侧；没有镜像图像。丧尸使用 `--transparent --alpha-mode chroma --facing left --direction side --facing-fix regen` 生成；目视确认全身完整、朝左扑咬。报告中的 `extra.view.facing` 记录请求方向，不是独立的图像方向检测结果。

丧尸一次显式 chroma 生成因提示词未写色键背景而得到空 alpha；补入纯洋红色 `#FF00FF` 背景后重画修复。最新 1024×1536 RGB 原图保存在 `sources/zombie_scientist_attack.png.raw.png`，生成阶段透明图保存在 `sources/zombie_scientist_attack.png`；随后从 RGB 原图用 `sprite-gen cutout --key magenta --decontam auto` 清理，输出 `sources/zombie_scientist_attack_cutout.png`，完整处理输出保存在 `zombie_scientist_attack.cutout.json`，最终再适配为 512×768。

`game/tools/fit_canvas.py` 只处理画布布局：透明输入按全部非零 alpha 的边界去掉空白，再等比缩放、透明补边，通常留 2px 安全边；`--bottom` 将可见脚底对齐到画布下沿上方 2px。不透明输入保持 RGB，等比缩放后以固定暗色 `#11141a` 补边。脚本不拉伸人物或背景，不负责抠图，也不改变人物朝向。

背景已重新生成。当前来源为 1672×941 RGB，以同一比例放入 1920×1080 RGB 画布，整数像素取整后内容为 1919×1080，右侧补 1px 暗色边；没有使用此前那张被纵向拉伸的背景。

## 来源、最终规格与已检查结果

所有下表中的相对路径以 `game/art/style_test/` 为起点。`sources/` 保存当前可用于复现画布处理的来源；尺寸检查针对最终文件，不用生成报告里的原始尺寸代替最终尺寸。

| 最终文件 | 当前可用来源 | 来源尺寸 → 最终尺寸 | 最终模式 / 四角 alpha | 非零 alpha 边界 |
|---|---|---|---|---|
| `zheng_zha_reference.png` | 本文件原样保留，未改画布 | 1024×1536 → 1024×1536 | RGB，不透明 | 不适用 |
| `zheng_zha_portrait_calm.png` | `sources/zheng_zha_portrait_calm.png` | 1024×1536 → 1024×1536 | RGBA / 0、0、0、0 | (158, 2, 865, 1534) |
| `zheng_zha_portrait_fear.png` | `sources/zheng_zha_portrait_fear.png` | 1024×1536 → 1024×1536 | RGBA / 0、0、0、0 | (97, 2, 926, 1534) |
| `zheng_zha_battle_idle.png` | `sources/zheng_zha_battle_idle_cutout.png` | 512×768 → 512×768 | RGBA / 0、0、0、0 | (73, 2, 438, 766) |
| `zombie_scientist_attack.png` | `sources/zombie_scientist_attack_cutout.png` | 1024×1536 → 512×768 | RGBA / 0、0、0、0 | (2, 47, 510, 766) |
| `bg_laser_corridor.png` | `sources/bg_laser_corridor.png` | 1672×941 → 1920×1080 | RGB，整张不透明 | 不适用 |

边界格式为 Pillow 的 `(left, top, right, bottom)`，右侧和底部坐标不含该位置。郑吒战斗图和丧尸的最后一行可见内容均位于 y=765，脚底到画布下沿保留 2px。四张透明角色图的四条外边均透明，不能仅凭四角 alpha 为零判断整张图的背景及人物是否正确。

最终丧尸全透明像素占 58.7145%；非零 alpha 像素中，alpha=255 的完全不透明像素占 89.6237%，其余为边缘过渡等半透明像素。主体不再整体透明；该统计不替代目视检查，轮廓仍有少量浅色点。

### 可复现的画布命令

在仓库根目录，用上述虚拟环境 Python 代替下列 `python`：

~~~bash
python game/tools/fit_canvas.py game/art/style_test/sources/zheng_zha_portrait_calm.png game/art/style_test/zheng_zha_portrait_calm.png 1024 1536
python game/tools/fit_canvas.py game/art/style_test/sources/zheng_zha_portrait_fear.png game/art/style_test/zheng_zha_portrait_fear.png 1024 1536
python game/tools/fit_canvas.py game/art/style_test/sources/zheng_zha_battle_idle_cutout.png game/art/style_test/zheng_zha_battle_idle.png 512 768 --bottom
python game/tools/fit_canvas.py game/art/style_test/sources/zombie_scientist_attack_cutout.png game/art/style_test/zombie_scientist_attack.png 512 768 --bottom
python game/tools/fit_canvas.py game/art/style_test/sources/bg_laser_corridor.png game/art/style_test/bg_laser_corridor.png 1920 1080
~~~

### 丧尸最终生成与清理命令

在仓库根目录运行，`sprite-gen.exe` 使用前文所列虚拟环境中的可执行文件：

~~~bash
sprite-gen.exe gen --provider codex --prompt-file game/art/style_test/prompts/zombie_scientist_attack.txt --out game/art/style_test/sources/zombie_scientist_attack.png --transparent --alpha-mode chroma --facing left --direction side --facing-fix regen --report game/art/style_test/zombie_scientist_attack.report.json
/mnt/i/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/sprite-gen.exe cutout game/art/style_test/sources/zombie_scientist_attack.png.raw.png --out game/art/style_test/sources/zombie_scientist_attack_cutout.png --key magenta --decontam auto > game/art/style_test/zombie_scientist_attack.cutout.json
~~~

### 历史报告路径说明

`*.report.json` 是生成阶段的原始记录，未为配合最终文件名而伪造其中的 `out`、`raw`、尺寸或 alpha 数据。平静、恐惧、丧尸和背景的最新报告指向 `sources/` 中保留的生成结果及原图。

早期清理中误删了设定图的原始副本 `zheng_zha_reference.png.raw.png`，以及战斗图的 `zheng_zha_battle_idle_raw.png` 和 `zheng_zha_battle_idle_raw.png.raw.png`。因此设定图报告的 `raw` 路径和战斗图报告的 `out/raw` 路径现已失效；报告仍可证明当时的提示词、参考图和处理参数，但不能据此声称原始文件仍在。设定图最终 PNG 仍在；战斗图后续清理结果保存在 `sources/zheng_zha_battle_idle_cutout.png`，可复现当前最终画布，却不能恢复被删除的原生尺寸图。

## 每张图的实际完整提示词

以下正文直接读取对应 `*.report.json` 的 `prompt` 字段，包括 sprite-gen 自动附加的方向和背景句；没有省略公共前缀或用概述替代。参数和图片尺寸见上文及同名 JSON。

### zheng_zha_reference.png

~~~text
日系动漫立绘风格，线条干净利落，偏写实的头身比例（约 7 头身），赛璐璐上色带少量柔和阴影；整体色调偏暗、偏冷，带一点胶片颗粒感，恐怖片氛围；人物清晰，背景阴森。
二十多岁的中国男性公司白领，短黑发，五官端正但神情疲惫，白衬衫，深色西裤，黑皮鞋，正面全身站立，身体比例自然，双手自然垂落，纯色深灰背景，完整人物从头到脚都在画面内，角色设定参考图。
~~~

### zheng_zha_portrait_calm.png

~~~text
日系动漫立绘风格，线条干净利落，偏写实的头身比例（约 7 头身），赛璐璐上色带少量柔和阴影；整体色调偏暗、偏冷，带一点胶片颗粒感，恐怖片氛围；人物清晰，背景阴森。
参考图中同一个郑吒，二十多岁的中国男性公司白领；保持他的黑色短碎发、发际线、疲惫眼袋、窄脸、鼻形、白色长袖衬衫的胸袋、黑皮带和深灰西裤。独立游戏对话立绘，从头顶到大腿中部，竖幅 2:3 构图，人物居中，头顶和双手完整且离画布边缘有余量。刚从列车上醒来，已经压住惊慌，平静但警觉地观察前方：嘴唇完全闭合，眉毛放松，眼睛正常睁开，没有张嘴、没有汗珠，肩膀自然放松，两手低垂而轻微绷紧。背景场景不入画，画面只包含人物，不出现椅子、座椅扶手、车厢或地面。保持参考图的柔和冷光，肤色自然。

The entire background is one perfectly flat, uniform pure magenta chroma-key fill (#FF00FF) with no gradient, no texture, no shadow and no ground line.
~~~

### zheng_zha_portrait_fear.png

~~~text
日系动漫立绘风格，线条干净利落，偏写实的头身比例（约 7 头身），赛璐璐上色带少量柔和阴影；整体色调偏暗、偏冷，带一点胶片颗粒感，恐怖片氛围；人物清晰，背景阴森。
参考图中同一个郑吒，二十多岁的中国男性公司白领；保持他的黑色短碎发、发际线、疲惫眼袋、窄脸、鼻形、白色长袖衬衫的胸袋、黑皮带和深灰西裤。独立游戏对话立绘，从头顶到大腿中部，竖幅 2:3 构图，头顶和双手完整且离画布边缘有余量。刚在高速列车上醒来后受到惊吓：瞳孔紧缩、眼睛睁大，眉心紧锁、眉头抬起，嘴唇微张，额头少量汗珠，肩膀耸起，上身略后退，一只手在胸口下方虚抬、另一只手紧绷下垂，手指结构正常。画面只包含人物，车厢和座椅不入画；不要椅子、座椅、扶手、地板、墙壁或任何道具。光照和服装颜色与参考图一致。

The entire background is one perfectly flat, uniform pure magenta chroma-key fill (#FF00FF) with no gradient, no texture, no shadow and no ground line.
~~~

### zheng_zha_battle_idle.png

~~~text
日系动漫立绘风格，线条干净利落，偏写实的头身比例（约 7 头身），赛璐璐上色带少量柔和阴影；整体色调偏暗、偏冷，带一点胶片颗粒感，恐怖片氛围；人物清晰，背景阴森。
与参考图中完全相同的郑吒：二十多岁的中国男性公司白领，短黑发，白衬衫、深色西裤、黑皮鞋，全身立绘，面朝画面右侧的侧面视图。双手共同握住同一把黑色手枪，手枪只有一把，双臂伸向右侧的戒备姿势，手指离开扳机，身体重心稳定，完整人物从头到脚，脚底贴近画面下沿，透明背景。

Seen from the exact side, facing right.

The subject must be facing right (toward the right edge of the image), regardless of the reference image's orientation. Preserve the subject's design.

The entire background is one perfectly flat, uniform pure magenta chroma-key fill (#FF00FF) with no gradient, no texture, no shadow and no ground line.
~~~

### bg_laser_corridor.png

~~~text
日系动漫立绘风格，线条干净利落，偏写实的头身比例（约 7 头身），赛璐璐上色带少量柔和阴影；整体色调偏暗、偏冷，带一点胶片颗粒感，恐怖片氛围；人物清晰，背景阴森。
横向 16:9、1920×1080 的完整不透明游戏场景背景，画面填满，不要黑边或边框。地下生化研究所的封闭长走廊，纯白金属墙板、白色金属天花板与冷白顶灯，整洁、压抑、没有窗户及旁侧实验室陈列。中心透视通往尽头的密封门，门前一道密集且规则的红色激光网横跨整条走廊，纵横光束形成可辨认的菱形网格，仿佛正从远处向镜头逼近。地面映出暗淡的红光，冷白与血红对照，整幅保持日系动画背景绘制的线条和赛璐璐阴影，不要人物、文字、水印、标志或相机畸变。
~~~

### zombie_scientist_attack.png

~~~text
日系动漫立绘风格，线条干净利落，偏写实的头身比例（约 7 头身），赛璐璐上色带少量柔和阴影；整体色调偏暗、偏冷，带一点胶片颗粒感，恐怖片氛围；人物清晰，背景阴森。
一名地下生化研究所的研究员丧尸，完整全身的独立游戏敌人素材，灰白皮肤、浑浊眼睛、凌乱短发，破损白色实验大褂、深灰长裤、完整皮鞋，胸前工牌。弓背前倾扑咬，张口露出牙齿，两只胳膊弯曲向前伸，双膝微屈，一脚支撑一脚略向后，紧凑而凶猛的侧面姿势。竖向 2:3 构图，人物占画面高度约 80%，四周保留至少 10% 空白；头发、手指尖、大褂下摆与双鞋全部在画布内，绝不触碰或超出边缘。不要附带地面、投影、烟雾或背景环境，人体和衣服是不透明的实体，非鬼魂、非半透明人物。
背景必须是完全不透明的纯洋红色 #FF00FF 色键底，均匀填满人物之外的全部区域，不要透明背景、灰黑渐变、光晕或棋盘格；人物本身全部不透明。The entire background is one perfectly flat, uniform pure magenta chroma-key fill (#FF00FF) with no gradient, no texture, no shadow and no ground line.

Seen from the exact side, facing left.
~~~

## 视觉复核与剩余限制

| 项目 | 已检查情况 | 限制与后续要求 |
|---|---|---|
| 郑吒身份一致性 | 设定图和三张候选保留黑色短发、疲惫眼袋、窄脸、白衬衫胸袋、黑皮带及深灰西裤；最新平静和恐惧图不含座椅，情绪可区分 | 表情、角度和光照仍会改变五官观感，不能把这些样本当成后续全部图片都能稳定保持身份的证明 |
| 头身比例 | 战斗图保留完整头、双手、枪和鞋子 | 战斗图身形偏修长，偏离“约 7 头身”的理想值；正式角色规范应统一身高和头身比 |
| 手部与武器 | 战斗图已由错误双枪重画为双手握持一把手枪，面朝右 | 双手重叠处、拇指及食指细节仍需按游戏显示大小人工检查，不能宣称解剖细节完全正确 |
| 透明边缘 | 三张郑吒透明图外边透明；sprite-gen 去色键流程已清除大面积洋红背景 | 头发处仍有少量浅色或紫色碎边；透明度数字通过不代表无需浅底、深底合成复核 |
| 激光通道 | 冷白金属走廊、红色规则激光网、强中心透视；RGB 不透明，等比放入规格画布 | 最终激光网偏近景逼近，距离表现与“尽头的一张网”有差别，不能描述成纯远景效果 |
| 丧尸 | 目视确认面朝左、弓背扑咬，头、手、双鞋完整且不含实景；最终 PNG 有非空 alpha，主体不再整体透明 | 去边后轮廓仍有少量浅色点，需在实际游戏显示大小和深浅底上继续复核；请求参数不能代替方向目视检查 |

## 批量生产建议

建议以这套风格进入有逐张复核的小批量试产，不建议无人工验收地一次生成全部资源。固定设定图、服装和镜头，并在提示词里明确情绪、手枪数量、角色是否独立以及手脚安全边距；持续使用原有参考图，避免把每次输出递归当作下一次唯一参考而积累偏移。

每张成品至少检查身份、表情、手部、武器数量、朝向、完整手脚、画布比例、可见脚底位置和深浅底上的透明边缘。未达到要求时用 sprite-gen 重画或 cutout 清理；保持朝向靠生成修正，不镜像。若多轮生成仍无法维持身份或手部/边缘质量，可采用“立绘 + 剪影战斗形象”降级方案。

## 验证记录

- fit_canvas.py 的临时合成图自检已通过：2:1 内容等比保持，透明四角和 2px 脚底边距正确，不透明输入保持 RGB，非正整数尺寸及完全透明输入被拒绝，同路径保存可用。
- `game/art/style_test/qa.json` 已记录六张最终 PNG 的 SHA-256、尺寸、模式、透明四角、非零 alpha 边界、外边像素及不透明/半透明像素数量，`all_checks_passed=true`。四张透明角色图的外边非零 alpha 像素均为 0，战斗图和丧尸的脚底留白均为 2px；设定图及背景保持 RGB 不透明。
- 五张经过画布适配的素材已从保留的 source 重新运行适配并逐像素对照，全部 `fit_reproduces_final_pixels=true`；设定图原样保留，不属于画布适配复现项。QA 同时保存了来源文件与适配脚本的 SHA-256。以上检查证明当前尺寸、透明度及画布处理可复现，不替代上文视觉限制的人工判断。
- 资源定稿后在仓库根目录运行 `bash game/tools/run_tests.sh`，命令退出码为 0，输出“共 32 个测试，失败 0 个”，没有 `SCRIPT ERROR`。Godot 为 4.7.2，完整输出保存在 `game/art/style_test/tests.log`。
- sprite-gen 的 finish 引导已运行，选择本次使用 codex、跳过可选选图界面；其退出码 2 仅询问是否保存为全局默认设置，不是图片处理失败。本任务没有修改全局默认设置。
