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
（Codex 在这里追加）
