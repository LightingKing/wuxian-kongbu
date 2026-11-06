# 美术风格试验报告

> 下文记录任务 001 的历史结果，文件引用已按 001b 迁移；本轮最终结果和测量结论见末尾“返工”一节。

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

下表记录 001 的历史成品，未返工的成品仍在 `game/art/style_test/`；旧战斗图和旧背景现位于 `art_src/style_test/rejected/`。来源列相对于 `art_src/style_test/`，完整迁移关系见末尾返工记录。尺寸检查针对当时的成品，不用生成报告里的原始尺寸代替成品尺寸。

| 最终文件 | 当前可用来源 | 来源尺寸 → 最终尺寸 | 最终模式 / 四角 alpha | 非零 alpha 边界 |
|---|---|---|---|---|
| `zheng_zha_reference.png` | 本文件原样保留，未改画布 | 1024×1536 → 1024×1536 | RGB，不透明 | 不适用 |
| `zheng_zha_portrait_calm.png` | `sources/zheng_zha_portrait_calm.png` | 1024×1536 → 1024×1536 | RGBA / 0、0、0、0 | (158, 2, 865, 1534) |
| `zheng_zha_portrait_fear.png` | `sources/zheng_zha_portrait_fear.png` | 1024×1536 → 1024×1536 | RGBA / 0、0、0、0 | (97, 2, 926, 1534) |
| `zheng_zha_battle_idle.png` | `rejected/sources/zheng_zha_battle_idle_cutout.png` | 512×768 → 512×768 | RGBA / 0、0、0、0 | (73, 2, 438, 766) |
| `zombie_scientist_attack.png` | `sources/zombie_scientist_attack_cutout.png` | 1024×1536 → 512×768 | RGBA / 0、0、0、0 | (2, 47, 510, 766) |
| `bg_laser_corridor.png` | `rejected/sources/bg_laser_corridor.png` | 1672×941 → 1920×1080 | RGB，整张不透明 | 不适用 |

边界格式为 Pillow 的 `(left, top, right, bottom)`，右侧和底部坐标不含该位置。郑吒战斗图和丧尸的最后一行可见内容均位于 y=765，脚底到画布下沿保留 2px。四张透明角色图的四条外边均透明，不能仅凭四角 alpha 为零判断整张图的背景及人物是否正确。

最终丧尸全透明像素占 58.7145%；非零 alpha 像素中，alpha=255 的完全不透明像素占 89.6237%，其余为边缘过渡等半透明像素。主体不再整体透明；该统计不替代目视检查，轮廓仍有少量浅色点。

### 可复现的画布命令

在仓库根目录，用上述虚拟环境 Python 代替下列 `python`：

~~~bash
python game/tools/fit_canvas.py art_src/style_test/sources/zheng_zha_portrait_calm.png game/art/style_test/zheng_zha_portrait_calm.png 1024 1536
python game/tools/fit_canvas.py art_src/style_test/sources/zheng_zha_portrait_fear.png game/art/style_test/zheng_zha_portrait_fear.png 1024 1536
python game/tools/fit_canvas.py art_src/style_test/rejected/sources/zheng_zha_battle_idle_cutout.png art_src/style_test/rejected/zheng_zha_battle_idle.png 512 768 --bottom
python game/tools/fit_canvas.py art_src/style_test/sources/zombie_scientist_attack_cutout.png game/art/style_test/zombie_scientist_attack.png 512 768 --bottom
python game/tools/fit_canvas.py art_src/style_test/rejected/sources/bg_laser_corridor.png art_src/style_test/rejected/bg_laser_corridor.png 1920 1080
~~~

### 丧尸最终生成与清理命令

在仓库根目录运行，`sprite-gen.exe` 使用前文所列虚拟环境中的可执行文件：

~~~bash
sprite-gen.exe gen --provider codex --prompt-file art_src/style_test/prompts/zombie_scientist_attack.txt --out art_src/style_test/sources/zombie_scientist_attack.png --transparent --alpha-mode chroma --facing left --direction side --facing-fix regen --report art_src/style_test/zombie_scientist_attack.report.json
/mnt/i/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/sprite-gen.exe cutout art_src/style_test/sources/zombie_scientist_attack.png.raw.png --out art_src/style_test/sources/zombie_scientist_attack_cutout.png --key magenta --decontam auto > art_src/style_test/zombie_scientist_attack.cutout.json
~~~

### 历史报告路径说明

`*.report.json` 记录生成阶段的提示词与原始统计。001b 按实际移动位置更新了 `out`、`raw` 等路径字段，并添加迁移说明，生成提示词、尺寸和 alpha 数据未改。平静、恐惧、丧尸的报告指向 `art_src/style_test/sources/`；旧背景及旧战斗图的报告位于 `art_src/style_test/rejected/`。

早期清理中误删了设定图的原始副本，以及旧战斗图的原生尺寸图和原始副本。迁移后记录的缺失路径分别为 `art_src/style_test/sources/zheng_zha_reference.png.raw.png`、`art_src/style_test/rejected/sources/zheng_zha_battle_idle_raw.png` 和 `art_src/style_test/rejected/sources/zheng_zha_battle_idle_raw.png.raw.png`。这些历史缺失没有被伪装成已恢复。设定图成品仍在；旧战斗图后续清理结果保存在 `art_src/style_test/rejected/sources/zheng_zha_battle_idle_cutout.png`，可复现其归档画布。

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
- `art_src/style_test/rejected/qa-001.json` 已记录六张最终 PNG 的 SHA-256、尺寸、模式、透明四角、非零 alpha 边界、外边像素及不透明/半透明像素数量，`all_checks_passed=true`。四张透明角色图的外边非零 alpha 像素均为 0，战斗图和丧尸的脚底留白均为 2px；设定图及背景保持 RGB 不透明。
- 五张经过画布适配的素材已从保留的 source 重新运行适配并逐像素对照，全部 `fit_reproduces_final_pixels=true`；设定图原样保留，不属于画布适配复现项。QA 同时保存了来源文件与适配脚本的 SHA-256。以上检查证明当前尺寸、透明度及画布处理可复现，不替代上文视觉限制的人工判断。
- 资源定稿后在仓库根目录运行 `bash game/tools/run_tests.sh`，命令退出码为 0，输出“共 32 个测试，失败 0 个”，没有 `SCRIPT ERROR`。Godot 为 4.7.2，完整输出保存在 `art_src/style_test/rejected/tests-001.log`。
- sprite-gen 的 finish 引导已运行，选择本次使用 codex、跳过可选选图界面；其退出码 2 仅询问是否保存为全局默认设置，不是图片处理失败。本任务没有修改全局默认设置。

## 返工（任务 001b，2026-11-06）

### 目录与图片提交规则

`game/art/style_test/` 现在只保留六张本机成品 PNG：设定图、平静立绘、恐惧立绘、新战斗待机图、丧尸和新背景 `bg_lab_corridor.png`。已通过 001 验收的设定图、两张立绘和丧尸没有重新生成，SHA-256 与原验收结果一致。

已跟踪的提示词、JSON 和日志用 `git mv` 移至 `art_src/style_test/`；未跟踪的来源图片用 `mv` 移动。`sources/`、`prompts/` 的层级保留，退役背景、旧战斗图及其提示词、报告、可用来源归入 `rejected/`。旧背景的 `sources/bg_laser_corridor.png.raw.png` 与 `.png` 经逐字节比较一致，只保留后者。旧 QA 和测试记录另存为 `rejected/qa-001.json`、`rejected/tests-001.log`，没有用新结果覆盖旧验收证据。所有报告和 QA 的路径已迁移，001 早期丢失的三个原图路径仍明确标为历史缺失。

成品、原图、淘汰图和预览均只在本机保留，遵守现有图片忽略规则，不使用 `git add -f`。本次提交仅包含提示词、生成/清理报告、校验和、测量、预览配置及文档等文本。`game/tools/fit_canvas.py` 无需修改。

### 背景：重画 1 次

新背景采用明确的手绘线稿、灰蓝/灰紫色块和赛璐璐阴影。镜头沿侧墙横向展开，污迹、划痕、管道和门体现废弃实验室；部分顶灯熄灭。相比旧背景，取消了写实金属反射、中央狭窄透视及整面激光网，角色站位不会被激光图案遮挡。

墙地交界目视约在 y=666，底部连续平地约 `(1080−666)/1080 = 38.33%`，接近任务的 40%；该数值是构图估测，不是语义分割结果。下方没有大物件、台阶或障碍。激光留给后续 Godot 效果层。本次未实现该效果层。

源图 `art_src/style_test/sources/bg_lab_corridor.png` 为 1672×941 RGB，原始副本同时保留；等比适配到 1920×1080 RGB，实际内容 1919×1080，右侧补 1px 暗色。新旧图可在本机直接对比：`game/art/style_test/bg_lab_corridor.png` 与 `art_src/style_test/rejected/bg_laser_corridor.png`。

### 战斗形象：重画 2 次，采用第 2 次

两次生成都使用设定图作为身份参考，指定 `--facing right --direction side --facing-fix regen`，没有镜像。第 2 次额外引用第 1 次的姿势图，身份与配色基准仍是原设定图。最终姿势是双肘弯曲、双手在腰腹前共同握住一把手枪，枪口朝前下方，膝盖微屈；不再平举双臂瞄准。

两次均先使用 `gen --decontam off` 保留候选，再从各自 RGB 原图使用 `sprite-gen cutout --key magenta --decontam auto` 清理边缘，最后运行现有 `fit_canvas.py --bottom`。没有手工修改头部大小、拉伸身体或改 RGB 数值来通过验收。第 1 次姿势和颜色合格，但头身比偏差 14.05%，未采用；其最终候选保存为 `art_src/style_test/rejected/zheng_zha_battle_idle_rework_01.png`。

完整来源链及参数位于 `art_src/style_test/zheng_zha_battle_idle_rework_01.report.json`、`zheng_zha_battle_idle_rework_02.report.json` 和相应 `.cutout.json`；第 2 次最终适配来源为 `art_src/style_test/sources/zheng_zha_battle_idle_rework_02_cutout.png`。

### 头身比与颜色测量

坐标以左上角为原点。人工标记头顶、下巴、鞋底，用端点差计算头高与全身高。参考图标点约 ±3px，候选图约 ±2px，RGBA 鞋底取最后一个非零 alpha 行。基准在读取新图之前固定，未为通过检查而改动。

| 图 | 头顶 / 下巴 / 鞋底 y | 头高 / 全身高 | 头高占比 | 相对参考偏差 | 判定 |
|---|---|---|---|---|---|
| 设定图 | 15 / 200 / 1492 | 185 / 1477 | 0.125254 | 基准 | — |
| 001 旧战斗图 | 3 / 104 / 765 | 101 / 762 | 0.132546 | 5.82% | 按本次定义在范围内 |
| 001b 第 1 次 | 2 / 111 / 765 | 109 / 763 | 0.142857 | 14.05% | 不通过 |
| 001b 第 2 次，最终 | 2 / 106 / 765 | 104 / 763 | 0.136304 | **8.82%** | **≤10%，通过名义值检查** |

旧图按明确公式约为 7.54 头身，参考图约为 7.98 头身，与任务背景中“约 9 头身”的目视描述不同。这里保留实际坐标，不调整标点去复现该描述。最终图比例接近上限，人工标点误差可能影响临界判定；不能把该测量表述为无误差的解剖比例。

发色 ROI 按头发内部的几何区域选取，避开脸、背景和最外圈碎边；不按 RGB 挑区域。参考 ROI 固定，新旧图使用相同的解剖选区规则。采用 `Y=0.2126R+0.7152G+0.0722B`（直接作用于 8 位 sRGB 值），只统计 ROI 内 `alpha=255` 且 `Y<70` 的像素。完整多边形坐标、像素数、RGB 均值和每张图 SHA-256 在 `art_src/style_test/measurements.json`，已独立重新计算核对。

| 图 | 合格像素数 | 平均 R−G | 与参考的绝对差 | 判定 |
|---|---:|---:|---:|---|
| 设定图 | 7406 | −0.564002 | 基准 | — |
| 001 旧战斗图 | 2323 | −5.159277 | 4.595275 | 不通过 |
| 001b 第 1 次 | 3353 | +0.237996 | 0.801998 | 通过 |
| 001b 第 2 次，最终 | 2856 | **−0.215336** | **0.348666** | **≤1.5，通过** |

本次 ROI 与 001 验收的粗略矩形区域不同，故绝对均值不复现其约 −1.2 / −3.3；旧图明显偏青的结论一致，且所有新旧比较均使用本次固定方法。

### 最终验收

- 六张成品的尺寸、模式、四角和四边 alpha、SHA-256 已写入 `art_src/style_test/qa.json`。四张透明图四角及四条外边全透明；战斗图和丧尸脚底距下沿 2px。设定图与背景为 RGB 不透明。
- 五张经过画布适配的成品均从当前保留来源重新执行 `fit_canvas.py`，与最终图逐像素一致；四张未返工成品的 SHA-256 与 001 记录一致。所有测量文件所指图片的 SHA-256 也已核对。
- 浅色底 `[235,235,240,255]` 与深色底 `[24,24,28,255]` 的复核预览使用 sprite-gen 的 `scene-render`，输出和配置均存于 `art_src/style_test/previews/`，不修改成品。
- 根目录执行 `bash game/tools/run_tests.sh`，**共 32 个测试，失败 0 个，退出码 0**，没有 `SCRIPT ERROR`；日志位于 `art_src/style_test/tests.log`。

四张透明成品均已在上述浅、深底上逐张查看，共八组预览，另生成一张深底并排比较图，顺序为左设定图、中新版战斗图、右旧版战斗图。新版头发和裤子呈中性偏暖深灰，未见旧版的明显青蓝感；姿势改为低位持枪戒备。轮廓连续，没有大片残底或厚白晕。原平静立绘发丝有极细紫点，恐惧立绘发丝及耳下有少量紫边，丧尸发丝、指尖和衣摆有少量浅灰/微绿细点；这些是 001 已通过的残余边缘，不在此次重新生成范围。新版战斗图仅见少量细灰抗锯齿边。全部 scene 检查均无裁切、空图或警告。

结论：本轮替换背景和战斗图，继续使用逐张审核的小批量生产流程。姿势和暗部偏色改善，比例名义值通过，但仍需保留人工标点的不确定度。没有更改引擎代码或制作新动作；下一任务可引用此次低位待机图。

### 本轮采用图片的实际完整提示词

下列提示词直接从生成报告读取，包含工具自动附加的背景和方向句；第 1 次战斗图提示词另保留在 art_src/style_test/prompts/zheng_zha_battle_idle_rework_01.txt。

#### 背景 bg_lab_corridor.png

~~~text
日系动漫立绘风格，线条干净利落，偏写实的头身比例（约 7 头身），赛璐璐上色带少量柔和阴影；整体色调偏暗、偏冷，带一点胶片颗粒感，恐怖片氛围；人物清晰，背景阴森。
为日系 2D 回合制游戏绘制一张地下生化研究所走廊战斗背景。只画空环境，没有人物、怪物或角色影子。横向 16:9，1920×1080 完整不透明画面，没有黑边或边框。
画法必须是手绘日本动画背景：可见且干净的深色轮廓线、结构线与少量笔触，清晰分层的平面色块和硬边赛璐璐阴影，有限冷灰蓝与灰紫色板；让画面与二维动漫人物同属一套美术，像动画片里画好的背景板，不是摄影、不是写实材质、不是 3D 建模渲染、不是游戏引擎截图。金属以简洁线稿和色块表现，不使用镜面反射或逼真光追。
构图是横向展开的宽走廊侧壁。相机大致平行于长侧墙，宽景偏侧视，轻微向下看见地面，不对准走廊尽头，不使用中央单点消失点或狭窄漏斗地面。墙与地面的交线大致水平，位于画面高度的 58% 至 60%，横贯左右两端；下方约 40% 全部是平整、连续、开阔、可行走的地面，左右双方三排角色可以自由站立。地面只保留低对比细缝、少量浅淡擦痕和大块平缓阴影，没有任何大物件、立柱、散落箱子、电缆、尸体、地洞、台阶、栏杆或障碍物，不要地面透视线汇聚到正中央。
画面中线以上安排少数实验室元素：带小观察窗的封闭金属门、墙内控制面板、通风格栅、沿上缘的管道、褪色的无字警示色块。原本灰白的金属墙面老旧发暗，局部污迹、锈水痕与划痕，线条和大色块要明确。顶灯有些熄灭，剩余灯只发昏暗的冷白光，整体低照度、压抑而阴森，但地面与墙面仍能清楚辨认。不要激光、红色光网、光束、危险特效、火焰、烟雾、文字、水印或标志。优先确保侧视平宽构图与下方 40% 的连续空地。
~~~

#### 战斗待机，第 2 次

~~~text
日系动漫立绘风格，线条干净利落，偏写实的头身比例（约 7 头身），赛璐璐上色带少量柔和阴影；整体色调偏暗、偏冷，带一点胶片颗粒感，恐怖片氛围；人物清晰，背景阴森。
第一张参考图是郑吒的身份、服装和身体比例的唯一基准；第二张参考图只提供低位持枪姿势。人物为同一个二十多岁的中国男性公司白领，短黑碎发、发际线、略疲惫的端正窄脸，白色长袖衬衫、胸袋、黑皮带、深灰西裤、黑皮鞋。
修正第二张图偏大的头：在完整全身的画面里，把头从头顶到下巴的高度缩小到第二张的约 88%，不要缩短身体、不要拉长腿；调整肩颈自然衔接。以第一张参考图实际约八头身为准：头顶至下巴高度是头顶至鞋底总高度的八分之一，即 12.5%。这张图的精确身体比例以第一张参考图为准，头不要再画成七分之一。保留成年男性正常宽肩、正常四肢长度；头部不能夸大，腿也不能异常细长。
保留第二张的低位持枪待机姿势：身体微侧、双脚稳定分开、膝盖稍弯、重心略低；两肘弯曲贴近躯干，双手在腰腹前共同握住同一把黑色手枪。枪口斜朝前下方约 40 度、在腰部以下，没有平举瞄准，没有开火，视线警戒前方。只有一把枪，双手包握同一握柄，手指结构正常、食指离开扳机。
头发、裤子、皮鞋和枪保持第一张参考图的中性炭灰黑，黑色暗部各RGB通道接近相等，红通道不要明显低于绿通道；不受青绿环境光或洋红背景反光染色。白衬衫用中性灰的赛璐璐块面阴影。完整头发、手指、枪口和双鞋全在画布内，四周留出空白，人物占画面高度约85%。单独人物，没有地面、投影、场景、文字或其它道具，不是照片或3D渲染。

Seen from the exact side, facing right.

The subject must be facing right (toward the right edge of the image), regardless of the reference image's orientation. Preserve the subject's design.

The entire background is one perfectly flat, uniform pure magenta chroma-key fill (#FF00FF) with no gradient, no texture, no shadow and no ground line.
~~~
