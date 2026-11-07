# 任务卡 003：像素风格试验

## 背景
美术方向改了（设计规格第 11 节，v0.8）：**玩法画面（战斗、地点、主神空间）全部用 Q 版像素**，只有剧情（对话立绘、剧情插图、过场）用日系动漫插画。任务卡 002 的动漫逐帧动画到此为止。这张卡验证像素这条路：能不能稳定地画出认得出的 Q 版郑吒和丧尸，动作能不能看，和动漫立绘放在一起协不协调。

## 先读
- 设计规格第 11 节（像素画面、资源规格、生图工具）
- `AGENTS.md` 的"美术约定"
- sprite-gen 的 `docs/pixel-unfake.md`；本机说明 `~/.codex/AGENTS.md`
- 任务卡 002 的 `docs/art/sprite-gen-report.md`（Pipeline A 怎么跑、`game/tools/import_sprite_atlas.gd` 怎么用）

## 硬性约定
- 只用 `--provider codex`。**不要用 `pixel-draw`**（走用户的 Claude 订阅额度，用户已决定不用）。
- 图片不进仓库；成品放 `game/art/pixel_test/`，中间文件放 `art_src/pixel_test/`。
- 不改 `game/core/`、`game/data/`、`game/tests/`，也不改 `game/project.godot`（像素层的设置先放在演示场景里）。

## 允许修改
- `game/art/pixel_test/`（新建，只放成品和运行时用的文本资源）
- `art_src/pixel_test/`（新建）
- `game/ui/dev/`（新增演示场景，不动 002 的文件）
- `game/tools/import_sprite_atlas.gd`（只在需要时）
- `game/tools/pixelize_scene.py`（新建，只在 sprite-gen 没有处理整张场景图的命令时）
- `docs/art/pixel-test-report.md`（新建）
- 本任务卡末尾的"完成汇报"

## 步骤
1. **调色板**：定一套全项目共用的像素调色板，**不超过 32 色**，偏暗偏冷，要有黑发、肤色、白衬衫的灰白、深灰西裤、血红、丧尸的灰白皮肤和枪的金属色。存成文本 `game/art/pixel_test/palette.hex`（一行一个 `#RRGGBB`）。下面所有像素图都只用这套颜色。

2. **郑吒像素小人**（面朝右）：
   - 以 `game/art/style_test/zheng_zha_reference.png` 为参考，转成 Q 版 2~3 头身：短黑发、白衬衫、黑皮带、深灰西裤、黑皮鞋、一把黑色手枪。
   - 单帧画布 48×48，透明；人物可见高度 28~34px，脚底贴同一条基线。
   - 四个动作，每个 2~6 帧：`idle`（呼吸或轻微晃动，循环）、`attack`（举枪射击，可以有一帧枪口火光）、`hit`（受击后仰）、`down`（倒地，不循环）。
   - 走 Pipeline A：`prepare --cell-size 48 --fit-pixel-unfake --fit-palette-size …` → `gen-set --provider codex` → `extract` → `compose-atlas`。其余参数你按 `pixel-unfake.md` 自己定。朝向用 `--facing-fix regen` 修，不要镜像。

3. **丧尸像素小人**（面朝左）：以 `game/art/style_test/zombie_scientist_attack.png` 为参考，研究员丧尸：灰白皮肤、破白大褂、工牌、血迹。规格同上，四个动作：`idle`（摇晃）、`attack`（扑咬）、`hit`、`death`。

4. **像素背景** `bg_lab_corridor_pixel.png`：480×270，不透明，只用调色板颜色。内容沿用 001b 的研究所走廊（可以拿 `game/art/style_test/bg_lab_corridor.png` 当参考）：侧视宽景，画面下方约 40% 是开阔地面，不画激光。sprite-gen 有处理整张图的像素化命令就用它；没有的话写 `game/tools/pixelize_scene.py`（Python 3 + Pillow：kcentroid 式缩小到 480×270，再量化到调色板），并在报告里说明。

5. **导入 Godot**：用 `import_sprite_atlas.gd` 生成两个角色的 `SpriteFrames`（`.tres`）。

6. **演示场景** `game/ui/dev/pixel_preview.tscn`：
   - 像素层：480×270 的 SubViewport，整数放大 4 倍铺满 1920×1080，纹理过滤 Nearest，像素对齐。
   - 背景上左边站 3 个郑吒、右边站 3 个丧尸（错开成前、中、后排），各自循环播放四个动作。
   - 按一个键切换"对话模式"：像素画面压暗，在原生分辨率上叠郑吒的平静立绘（`game/art/style_test/zheng_zha_portrait_calm.png`）和一个中文对话框，台词"这是……什么地方？"。
   - 用 Godot 实际渲染两张截图（战斗模式、对话模式），存到 `art_src/pixel_test/`。

7. **报告** `docs/art/pixel-test-report.md`：
   - 认不认得出：放大 4 倍后，像素郑吒和他的立绘、设定图并排，还看不看得出是同一个人；丧尸看不看得出是研究员丧尸。
   - 像素质量：是不是真正的像素格子（没有半透明、没有糊边、没有半格错位），每个动作内各帧大小和颜色是否一致（没有闪烁），实际用了多少种颜色。
   - 动作：四个动作在 4 倍下是否看得懂。
   - 两种画风放一起是否协调（看对话模式截图）。
   - 每个角色生成了几次、用了多久。
   - 建议：可以照这套流程批量生产，还是要先调整（尺寸、头身比、调色板、流程）。

## 验收
- 两个角色的图集、manifest、`.tres` 在 `game/art/pixel_test/`；背景、调色板也在；中间文件在 `art_src/pixel_test/`。
- 每帧 48×48；人物可见高度 28~34px；像素只有全透明和全不透明两种（alpha 只有 0 和 255）。
- 所有像素图（两个角色、背景）用到的颜色都在 `palette.hex` 里，总数不超过 32。
- 演示场景能运行，两张截图都在。
- 仓库根目录运行 `bash game/tools/run_tests.sh` 全部通过。
- `git ls-files '*.png' '*.gif'` 输出为空；一个提交：`art: 像素风格试验（郑吒、丧尸、走廊背景、演示场景）`；**只提交，不推送**。

## 完成汇报

2026-11-06：已完成像素风格试验，以一个提交交付，未推送。仅使用 codex 生图，没有使用 pixel-draw、其他 provider、镜像或 RIFE；图片/GIF 均留在本机。

- 完成 32 色调色板、郑吒/研究员丧尸各四动作四帧图集、manifest、SpriteFrames，以及 480×270 走廊背景。成品在 `game/art/pixel_test/`；原图、中间文件、GIF、提示词、原生报告和 SHA-256 在 `art_src/pixel_test/`。
- 新增 `game/ui/dev/pixel_preview.tscn`、`pixel_preview.gd`、`verify_pixel_preview.gd` 及 UID，实现 480×270 SubViewport、Nearest 四倍、双方各三人轮播、D 键/触屏按钮切对话、原生立绘与中文台词。生成战斗、对话、四倍逐帧及身份对照四张真实 Godot 截图。
- 原生工具没有整场景 kcentroid 缩小命令，按授权新增 `game/tools/pixelize_scene.py`。未修改 002 文件、导入器、core/data/tests 或 project.godot。
- 落盘审计：32 帧均 48×48；站立动作高 28～32px；用户已确认倒地自然变矮，郑吒 down 为 31/28/24/17px，丧尸 death 为 32/27/21/11px；所有帧底边为 y=40。角色 alpha 仅 0/255，背景全不透明。角色和背景合计 30 色，全部来自共享调色板。战斗截图 115680 个四倍像素块无插值差异。
- Godot 两套导入、八个实际动画、轮播及对话验证均通过，失败 0 项、无 SCRIPT ERROR。仓库根目录 `bash game/tools/run_tests.sh` 得到“共 32 个测试，失败 0 个”，退出 0；`git ls-files '*.png' '*.gif'` 输出为空。
- 郑吒成功生成 5 张，图片阶段累计 582.924 秒；丧尸成功 5 张、730.930 秒，另有 2 个中断行请求，provider 完成状态及耗时未知；背景 1 张、121.024 秒。
- 保留问题：丧尸 native alpha 基图曾被额外 chroma 误抠，已改用未损坏原生 raw 并保留证据；丧尸 death 网格检测不稳定，原生 score 79、总分 94.75，score 命令退出 1，未伪报通过。四倍视觉复核发现郑吒跨状态裤子颜色、头形变化，以及枪/工牌细节不稳定。浏览器电脑操作被工具停止，最终使用 Godot 渲染验收。

详细报告：`docs/art/pixel-test-report.md`。建议继续像素方向，先固定像素参考、材质色阶与轮廓，再批量生产；当前结果作为流程试验基线。

提交信息：`art: 像素风格试验（郑吒、丧尸、走廊背景、演示场景）`。

## 验收记录（Claude，2026-11-07）

- 作为流程试验通过：每帧 48×48，alpha 只有 0/255，站立高度 28~32px，脚底同一基线；角色和背景共用 30 色，全部来自 `palette.hex`；仓库里没有图片；32 个测试通过（以上都已复测）。
- 方向成立：对话模式里动漫立绘叠在压暗的像素画面上，原生分辨率中文清楚，两种画风放在一起协调；像素背景本身画得好。
- 美术质量还不能批量生产：
  - 小人颗粒感重：丧尸的白大褂被暗色碎点打散，原尺寸下看不清脸，像一团灰；郑吒轮廓不齐。原因之一是对整套帧做了 0.8 倍最近邻缩小，这是非整数缩放，会不规则地吞掉行和列（设计规格第 11 节不允许）。
  - 跨动作漂移：每个动作行单独生图，裤子颜色、头形在行与行之间变化。
  - 背景比例和 Q 版人物不配：门大约是人物的 3 倍高，Q 版场景里应在 1.5 倍左右。
- 用户看过后决定：现在的质量够用，就按这套流程和画风继续，不返工。以上问题记作已知问题。
