# 整张场景的像素化转换

任务卡 003 第 4 步允许：sprite-gen 没有处理整张场景的像素化命令时，新建 game/tools/pixelize_scene.py。本次只将这条分支用于不透明研究所背景；角色仍走 sprite-gen Pipeline A。

## 工具能力调查

已只读检查本机 sprite-gen 3.15.0 的 SKILL.md、docs/pixel-unfake.md、docs/recolor.md、docs/asset-tools.md，以及 CLI 帮助和必要源码。

- CLI 不存在独立 pixel-unfake 子命令。fit.pixel_unfake 属于角色行的 extract 流程，会做组件分离、网格检测与角色对齐，不是整张场景画布的固定尺寸转换入口。
- background-tile 处理重复背景的拼接缝，不做目标尺寸像素化。
- scene-render 缩放层使用 resize_cell 的平滑颜色/覆盖率重采样，没有 kcentroid 或固定外部调色板的整图像素化参数。
- recolor 只重写 RGB 并原样保留 alpha，不负责缩小。不能把它当作场景转换或透明度二值化工具。

因此采用任务卡授权的 Python 3 + Pillow 脚本。没有使用 pixel-draw、其他付费 provider、抠图或角色裁切。

## 转换方法

源图 art_src/pixel_test/background-raw.png，1672×941 RGB，全部不透明。

将完整源画布按目标 480×270 像素划分成互不重叠的整数区域，每个源像素都属于一个区域。每个区域执行按像素数量加权的 RGB 二聚类：以颜色跨度最大通道的两端初始化，最多迭代 8 次，保留较大簇的颜色均值。之后按 RGB 欧氏距离平方映射到共享 palette.hex 中的最近颜色，无抖动。

这属于 kcentroid 式区域主色缩小，不宣称与 sprite-gen 内部算法字节一致。转换没有主体检测、裁切、补边或透明度丢弃；透明输入会被拒绝。源宽高比与目标 16:9 相差约 0.053%，本次完整映射到目标尺寸，不宣称严格等比。

命令由仓库根目录在指定 Bash 下执行，使用 sprite-gen 虚拟环境 Python：

~~~bash
/mnt/i/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/python.exe game/tools/pixelize_scene.py art_src/pixel_test/background-raw.png game/art/pixel_test/bg_lab_corridor_pixel.png --palette game/art/pixel_test/palette.hex --report art_src/pixel_test/background-conversion.report.json
~~~

## 落盘成品验证

脚本从保存的 PNG 重新读取并统计，完整结果在 background-conversion.report.json：

- 成品：480×270 RGB，alpha 隐式为 255；转为 RGBA 后 alpha 唯一值为 [255]。
- 共享调色板 32 色，成品实际使用 26 色，调色板外颜色 0 种。
- 源图 SHA-256：a8205672d175125a20beeeb2f1f6c436125b300a3032ee148a0a9c346efefcce。
- 成品 SHA-256：71b0ca746bf2142b83204d35beb872d41b58a6a4e90f9bbbff5e570d6b146939。
- 调色板 SHA-256：8b5632860302785e35c48f891e815e4a77b2f0edea0364a815991e83d9b22657。
- 命令退出码 0，报告 passed: true。

已查看成品静态图：仍是侧视研究所宽景，门、管道和通风口位于中线上方，下方约 38% 为开阔地面，无激光。量化使渐变转为色块；少量墙面细碎纹理仍在，最终可读性还需结合 Godot 的 4 倍 Nearest 显示与角色站位验收。
