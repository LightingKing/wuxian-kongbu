# 任务卡 006：M1 战斗像素小人与战斗背景

## 目标
计划 18 把战斗画面换成了像素舞台（480×270 像素层，整数放大 4 倍），但现在只有像素试验（任务卡 003）留下的郑吒和研究员丧尸两套图，其余人物是代码画的占位小人。这张卡给《生化危机一》的战斗出正式的像素小人和战斗背景：**7 个轮回者 + 4 种敌人 + 9 张背景**。

做完之后不用改任何代码：游戏会自动找到 `game/art/battle/` 下的新图并替换占位。

## 先读
- `AGENTS.md`（尤其"图片不进仓库""只修改允许的路径"）
- 设计规格 `docs/superpowers/specs/2026-11-05-wuxian-kongbu-game-design.md` 第 11 节（像素玩法画面的尺寸、朝向、动作、背景构图）
- `docs/codex-tasks/003-pixel-style-test.md` 和 `docs/art/pixel-test-report.md`（已验收的流程、调色板、遇到的问题）
- `art_src/pixel_test/README.md`（003 的复现步骤）
- `game/ui/battle/sprite_source.gd`（游戏怎么找图：路径、动作名、缺图时的退路）

## 允许修改
- `game/art/battle/`（新建）
- `art_src/battle/`（新建：原图、中间文件、提示词、报告、QA）
- 本任务卡末尾的"完成汇报"

不要改 `game/` 下的任何代码、数据、测试，也不要改 `project.godot`。

## 产出路径与格式

| 类型 | 路径 | 格式 |
|---|---|---|
| 小人图集 | `game/art/battle/<id>/sprite-sheet-alpha.png` | RGBA 透明底，4 行 × 4 列，单帧正方形 |
| 图集说明 | `game/art/battle/<id>/manifest.json` | sprite-gen 原生 manifest |
| 动作资源 | `game/art/battle/<id>/sprite_frames.tres` | Godot SpriteFrames，动作名见下 |
| 战斗背景 | `game/art/battle/bg_<地点>.png` | 480×270，不透明 |
| 提示词、报告、QA | `art_src/battle/` | Markdown / JSON，含每个成品的 SHA-256 |

**动作名必须是** `idle`（4fps，循环）、`attack`、`hit`、`down`（6fps，不循环），每个 4 帧。行顺序 idle → attack → hit → down。敌人的倒地也叫 `down`（不要叫 `death`）。

**脚底基线**：单帧四边留 8px 安全边，脚踩在底边往上 8px 的那一行（48 格就是第 40 行，跟 003 一样，用 foot-centroid / bottom 对齐、ground_frames）。倒地帧自然变矮，不要拉伸到站立高度。

**朝向**：我方朝右，敌方朝左。不要靠镜像翻转出朝向。

## 清单

### 轮回者（朝右，单帧 48×48，人物约 32px 高，Q 版 2.5～3 头身）

| id | 人物 | 32px 下要看得出的特征（以 `game/art/portraits/<id>.png` 和 `art_src/prompts/<id>.md` 为准） |
|---|---|---|
| `zheng_zha` | 郑吒 | 黑短发、灰白短袖衬衫、深色裤子、手枪（可以从 003 的郑吒定稿出正式版） |
| `zhang_jie` | 张杰 | 寸头、深灰上衣、老兵体格、沙漠之鹰 |
| `zhan_lan` | 詹岚 | 长黑发、浅色外套 |
| `li_xiao_yi` | 李萧毅 | 瘦、校服外套 |
| `mu_gang` | 牟钢 | 壮、工装背心、手臂露出 |
| `xiao_pang_zi` | 小胖子 | 圆脸、T 恤、缩着肩 |
| `zhong_nian_fu_nv` | 中年妇女 | 针织外套、头发挽起 |

attack 按各自的招式画：郑吒、张杰是举枪射击（有枪口火光）；其他人是挥拳。

### 敌人（朝左）

| id | 敌人 | 单帧 | 要点 |
|---|---|---|---|
| `zombie` | 丧尸 | 48×48 | 普通丧尸（实验区员工、保安混搭的通用造型），苍白、衣服破烂；attack 是扑咬 |
| `zombie_dog` | 丧尸犬 | 48×48 | 四足，皮肉溃烂；attack 是扑咬 |
| `licker` | 爬行者 | 64×64 | 四足爬行、无皮肤肌肉外露、长舌、巨爪；attack 用爪击，体型明显比丧尸大 |
| `training_dummy` | 训练傀儡 | 48×48 | 主神空间训练场的金属假人；attack 四帧可以就是 idle 的轻微晃动 |

### 战斗背景（480×270，不透明，侧视宽景，下方约 40% 是平整开阔的地面）

| 文件 | 地点 | 要点 |
|---|---|---|
| `bg_car.png` | 高速车厢 | 地铁/高速列车车厢内部，冷蓝灯，座椅 |
| `bg_hall.png` | 蜂巢入口大厅 | 豪宅地下入口改造的大厅，大理石地面 |
| `bg_stairs.png` | 楼梯井 | 金属楼梯平台，管线 |
| `bg_laser.png` | 激光通道 | 白色金属走廊、尽头一道门；**不画激光**（激光由游戏做成效果层） |
| `bg_control.png` | 火焰女皇主机房 | 成排机柜、中央全息投影台（不画人） |
| `bg_corridor.png` | 实验区走廊 | 可以从 003 的走廊背景定稿 |
| `bg_freezer.png` | 冷冻仓库 | 冷柜、结霜、冷光 |
| `bg_sewer.png` | 下水道 | 拱形隧道、浅水、管口 |
| `bg_training.png` | 主神空间训练场 | 空旷的金属训练大厅，冷白光（以后给对练用） |

背景只画环境，不画人物、文字、UI；不要画会动的危险物（激光、火焰）。

## 流程（沿用 003）
1. 每个小人先依据动漫立绘出一张 Q 版像素基础图，再走 prepare → 原生 gen-set → extract → compose-atlas。统一 cell、logical_height、`pixel_unfake=true`、foot-centroid/bottom、ground_frames。
2. 首次 extract 前写入 `palette.lock.json`，颜色全部取自 `game/art/pixel_test/palette.hex`（32 色共用调色板）；关闭 outline。
3. 背景用 003 的整场景转换方式（`game/tools/pixelize_scene.py`）映射到同一调色板，不裁切、不抖动。
4. 生成 `sprite_frames.tres` 的方式同 003；动作名按本卡统一成 idle / attack / hit / down。
5. **只用 codex 登录渠道（sprite-gen `gen --provider codex`）。不要用 `pixel-draw`。** 如果 codex 渠道不可用，停下来在完成汇报里写明，等用户决定；不要自己切换到别的 provider 或按调用计费的接口。

## 分批做
- **第一批（先验收）**：`zheng_zha`、`zhang_jie`、`zombie`、`bg_control.png`。做完先停，等 Claude 看图确认。
- **第二批**：其余 5 个轮回者、`zombie_dog`、`licker`、`training_dummy`。
- **第三批**：其余 8 张背景。

## 验收标准
- 尺寸、透明、行列、动作名、帧数、fps 符合上表；颜色全部在共用调色板里。
- 朝向正确，脚底基线统一，站立高度约 32px（爬行者按体型）。
- 同一角色四个动作能看出是同一个人（发型、服装配色一致）；32px 看不清五官、手指是正常的，不要求。
- 背景地面在下方约 40%，没有人物、文字、激光。
- 在游戏里看效果：把 `game/` 复制到一个临时目录，**先把副本 `project.godot` 里的 `config/name` 改掉**（切片验收会清空存档槽，存档目录跟着工程名走），再在副本里运行
  `godot --path <副本>/game -s res://tools/verify_m1_slice.gd -- --capture`，
  截图在 `<副本>/art_src/qa/m1_slice_battle.png`，应该看到新的小人站在火焰女皇主机房背景上。
- 仓库根目录 `bash game/tools/run_tests.sh` 全部通过（只出图，测试数不变）。

## 不要做的事
- 不要把 png 提交进仓库（`git add -f` 也不行）；提交提示词、报告、manifest、`sprite_frames.tres` 和 SHA-256。
- 不要改游戏代码、数据、测试；不要动 `_work/`。
- 不要为了"更好看"改人物设定。

## 完成汇报
在本文件末尾追加：每批出了哪些、路径、尺寸、SHA-256、用了几次生图、遇到的问题；以及你认为描述有歧义、需要 Claude 补设定的地方。
