# 任务卡 007：探索画面的行走图（第一部片 + 主神空间）

> 2026-11-10 改写：按《生化危机一》与主神空间重做的设计（`docs/superpowers/specs/2026-11-10-film1-hub-remake-design.md` 第 3 节）。
> 原来的"每个地点一张整图"取消：地图改用 Tiled + 免费图块包，免费包没有的东西才由 Codex 画。

## 目标
探索画面改成了 Tiled 地图（16×16 图块、3/4 俯视、镜头跟随），地图图块用许可允许的免费图块包。这张卡出**人物在地图上的行走图**：先出郑吒一套当样板，用户在样板房间里看过、批准以后，其余人物照它成批出。之后还有地图上的敌人和免费包里没有的场景件（分批见下）。

做完不用改代码：游戏会自动读 `game/art/field/walkers/` 下的图替换占位小人。

## 先读
- `AGENTS.md`（尤其"图片不进仓库""只修改允许的路径"）
- 设计 `docs/superpowers/specs/2026-11-10-film1-hub-remake-design.md` 第 3 节（美术规格、批准样板再成批做、来源记录）
- `docs/codex-tasks/003-pixel-style-test.md`、`docs/art/pixel-test-report.md`（已验收的像素流程和 32 色共用调色板）
- `docs/codex-tasks/006-m1-battle-sprites.md`（人物特征表；同一个人在战斗和地图上要认得出是同一个人）
- `game/ui/field/field_art.gd`（游戏怎么切行走图的帧）

## 允许修改
- `game/art/field/`（新建）
- `art_src/field/`（新建：原图、中间文件、提示词、报告、QA）
- `art_src/manifest/field.json`（只追加本卡出的图的条目）
- 本任务卡末尾的"完成汇报"

不要改 `game/` 下的任何代码、数据、测试，也不要改 `project.godot`。

## 行走图规格
- 路径：`game/art/field/walkers/<id>.png`，64×128 RGBA，4 列 × 4 行，**单帧 16×32**（一格宽、两格高）。
- **行**（从上到下）：面朝下（朝镜头）、面朝左、面朝右、面朝上（背对镜头）。
- **列**（从左到右）：站立、迈一只脚、站立、迈另一只脚（游戏走路时轮流用第 2、4 列，停下用第 1 列）。
- Q 版 2.5～3 头身，可见高度 26～30 像素，水平居中，**脚踩在单帧最下面一行**；四个方向、四帧的脚底在同一条线上。
- 3/4 俯视的人物画法（看得到头顶一点和身体正面），和 16 像素图块包的人物比例一致。
- 面朝右那一行可以是面朝左的水平镜像。
- alpha 只有 0 和 255。颜色先用共用调色板 `game/art/pixel_test/palette.hex`；如果样板房间最后选了"图块包原色"，Claude 会在本卡注明改用哪套颜色。
- 发型、服装配色和立绘 `game/art/portraits/<id>.png`、提示词 `art_src/prompts/<id>.md`、006 的战斗小人一致。

## 分批做
- **第一批（样板，做完就停）**：`zheng_zha` 一套。Claude 把它放进样板房间，和候选图块一起在游戏里截图给用户看；批准后这套就是之后所有行走图的参考（比例、头身、描边、颜色以它为准）。
- **第二批**：其余 15 个人，以郑吒那套为参考成批出——
  - 轮回者：`zhang_jie`、`zhan_lan`、`li_xiao_yi`、`mu_gang`、`xiao_pang_zi`、`zhong_nian_fu_nv`（特征见 006 卡的表格）；
  - 剧情人物：`matthew`、`alice`、`rain`、`jd`、`ryan`、`kaplan`、`matt`、`red_queen`（特征以立绘和 `art_src/prompts/<id>.md` 为准；火焰女皇画成正常配色的小女孩，游戏会叠半透明红色和红光）；
  - 萝丽：`luo_li`（以 005 卡补充的萝丽立绘为准）。
- **第三批**：地图上的敌人 `game/art/field/enemies/<id>.png`，排法同行走图：`zombie`、`zombie_dog`（单帧 16×32），`licker`（单帧 32×32，整张 128×128，四足爬行）。给计划 24 的游荡敌人用。
- **第四批**：免费图块包里没有的场景件（高速列车车厢、火焰女皇的全息投影台、主神空间的地面和墙、主神光球、传送光柱）。具体尺寸和风格要等样板房间定下图块包以后，由 Claude 补到本卡，现在先不做。

## 流程
- 每个人物先出一张 Q 版像素基础图（可以从 006 的战斗小人基础图出发，改成 3/4 俯视的站姿），再走 sprite-gen 的 prepare → gen-set → extract → compose-atlas：cell 16×32，四行动作依次是面朝下、左、右、上的走路，每行 4 帧，`pixel_unfake=true`，首次 extract 前写 `palette.lock.json`，脚底用 foot-centroid / bottom 对齐到最下面一行，关闭 outline。
- **只用 codex 登录渠道（sprite-gen `gen --provider codex`）。不要用 `pixel-draw`。**codex 渠道不可用就停下来，在完成汇报里写明，等用户决定；不要自己换别的 provider 或按调用计费的接口。
- 看游戏里的样子：把 `game/` 复制到临时目录，**先改掉副本 `project.godot` 里的 `config/name`**，在副本里运行 `godot --path <副本>/game -s res://tools/field_capture.gd`（要窗口），截图在 `<副本>/art_src/qa/field_*.png`。

## 记录来源
在 `art_src/manifest/field.json` 的 `assets` 数组里给每个成品加一条（文件不存在就建，顶层写 `{"schema_version": 1, "assets": []}`）：
`id`、`role`（用途）、`path`、`status`（`draft` / `approved`）、`technical`（`dimensions`、`frame`、`alpha`、`anchor: bottom-center`、`frames: 16`、`filtering: nearest`）、`source`（`kind: generated`、`url_or_tool: sprite-gen gen --provider codex`、`created_at`、`prompt_or_source_record`：提示词文件路径）、`verification`（`native_scale_reviewed`、`in_engine_reviewed`、`technical_checks_passed`、`approved_by`）。成品的 SHA-256 写进 `art_src/field/` 的报告。

## 验收标准
- 尺寸、行列、帧大小、alpha、脚底基线符合上面的规格；颜色在约定的调色板里。
- 同一个人四个方向、四帧认得出是同一个人，走路时不闪不跳；和他的战斗小人、立绘对得上。
- 截图里人物站在地面上，和图块的比例协调。
- 仓库根目录 `bash game/tools/run_tests.sh` 全部通过（只出图，测试数不变）。

## 不要做的事
- 不要把 png 提交进仓库（`git add -f` 也不行）；提交提示词、报告、清单条目和 SHA-256。
- 不要改游戏代码、数据、测试；不要动 `_work/`。
- 不要参照或模仿任何现成游戏的人物图（包括以前的《无限恐怖》同人游戏和 RPG Maker 自带素材）。
- 不要为了"更好看"改人物设定。

## 完成汇报
在本文件末尾追加：每批出了哪些、路径、尺寸、SHA-256、用了几次生图、遇到的问题；以及你认为描述有歧义、需要 Claude 补设定的地方。
