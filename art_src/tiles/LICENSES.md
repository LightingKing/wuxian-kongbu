# 探索画面用的第三方素材：来源与许可

只用免费素材（用户 2026-11-10 决定）。"免费"不等于许可：每个包都在作者的原页面和包里自带的许可文件核对过。
图片不进仓库（多数许可也不允许转发原图），只在本机 `game/art/` 下；这里记来源、许可、署名和改动，照着可以重新做出同样的文件。

## 正在用的

### Land of pixels — Laboratory tileset（实验室图块）
- 作者：marceles（https://marceles.itch.io/）
- 出处：https://opengameart.org/content/laboratory-tileset-pixelart-16px （文件 `tiles_laboratory_landofpixels_0.zip`）
- 许可：**CC BY 4.0**（https://creativecommons.org/licenses/by/4.0/ ；包里的 `LICENSE.txt` 也写的是这个）。可以使用、修改，**要署名**。
- 署名：游戏标题画面的"致谢"页（`game/data/credits.json`）。
- 用在哪：`game/art/tiles/lab/tilesFloor.png`、`tilesWalls.png`、`tilesStuff.png`（包里 `16px/` 那三张），图块集描述 `game/data/maps/tilesets/lab_floor.tsj`、`lab_walls.tsj`、`lab_stuff.tsj`；第一张用它的地图是 `game/data/maps/biohazard1/hall.tmj`（样板房间：蜂巢入口大厅，用户 2026-11-11 选了"共用调色板"版）。
- 改动：每张都映射到共用 32 色调色板 `game/art/pixel_test/palette.hex`，不缩放、不抖动、不改透明度；工具 `game/tools/palette_map.py`，报告（含原图和成品的 SHA-256）在 `art_src/tiles/lab/*.report.json`。
- 重新做一遍：下载上面的 zip，解压出 `tiles_laboratory_LandOfPixels/16px/` 里的三张，在仓库根目录运行
  `python -I -X utf8 game/tools/palette_map.py <解压目录>/16px/tilesFloor.png game/art/tiles/lab/tilesFloor.png --palette game/art/pixel_test/palette.hex --report art_src/tiles/lab/tilesFloor.report.json`
  （`tilesWalls`、`tilesStuff` 同样各跑一次），对照报告里的 `output_sha256`。
- 同一页还有 `labnpcs.png`（两个研究员、一个防护服人物的四方向走路图，同样 CC BY 4.0）。现在本机把它们裁成我们的行走图格式，临时顶替还没画出来的轮回者和剧情人物（Codex 按任务卡 007 出正式行走图后替换）；只是本机占位，不算正式素材。

## 看过、暂时没用的

| 素材 | 作者 | 许可（原页面 / 包内文件） | 情况 |
|---|---|---|---|
| Interior Tileset 16x16（https://opengameart.org/content/interior-tileset-16x16） | Bonsaiheldin（http://bonsaiheld.org） | CC BY-SA 3.0，要署名 | 家居室内（木地板、地毯、床、窗、门），以后给郑吒的房间、回归现实那一章备用 |
| Colony sim assets（https://opengameart.org/content/colony-sim-assets） | Buch | CC0 | 科幻机械，备用 |
| Dread Rooms #1 — Abandoned Hospital, Free Version（https://pixlog.itch.io/dread-rooms） | PixLog | 包内 LICENSE：可用于自己的项目、可改、可随游戏发布；不能转发素材本身、不能拿去训练 AI；署名非必需。作者说明是 AI 辅助制作 | 免费版只够一间病房，没用 |
| Gridwright Haunted Asylum — Free Sample（https://gridwrightstudio.itch.io/horror-tileset-16x16-pixel-art-asylum-hospital-top-down） | Gridwright | 包内 LICENSE：可用于个人和商业项目、可改；不能转发素材本身、不能训练 AI；**要署名**"Art by Gridwright"并链接 https://gridwrightstudio.itch.io | 免费样本只够一间病房，没用；以后做医疗区或"破败"状态时可以拿病房墙、血迹、纸张 |

itch.io 的页面经网关 192.168.1.2 的 PassWall2（`DEV_TOOLS` 规则加了 `domain:itch.io`、`domain:itch.zone`）才能打开，2026-11-11。
