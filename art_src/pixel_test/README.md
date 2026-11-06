# 003 像素试验复现记录

全部生图使用 sprite-gen 的 codex 登录渠道。没有使用 pixel-draw、OpenAI/Grok 计费 provider、RIFE 或镜像。

命令在仓库根目录运行，shell 为 `I:\Git\bin\bash.exe`（本机实际进入 WSL）。Windows 可执行文件的数据路径使用仓库相对路径或 Windows 路径。

## 基础图和背景

- 郑吒提示词、codex 报告：`zheng_zha/base-prompt.txt`、`base.report.json`。
- 丧尸提示词、codex 报告和原生 alpha 异常证据：`zombie_scientist/`。
- 背景：`background-prompt.txt`、`background-generation.report.json`。
- 32 色来源：`../../game/art/pixel_test/palette.hex`，颜色用途见 `palette-notes.md`。

每次命令前传入 `WSLENV=SPRITE_GEN_CODEX_UNAVAILABLE SPRITE_GEN_CODEX_UNAVAILABLE=ask`。codex 退出 75 时停止询问，不自动切换 provider。

```bash
/mnt/i/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/sprite-gen.exe gen \
  --provider codex --prompt-file art_src/pixel_test/zheng_zha/base-prompt.txt \
  --ref game/art/style_test/zheng_zha_reference.png \
  --direction side --facing right --facing-fix regen \
  --handed 'the single black pistol=right hand' \
  --out art_src/pixel_test/zheng_zha/base.png \
  --report art_src/pixel_test/zheng_zha/base.report.json
```

完整展开后的动作提示词、参考图路径、渠道、计时及朝向观察在每个 run 的 `reports/gen-set/*.json` 中。生成结果并非字节确定，SHA-256 用于核对本次产物。

## Pipeline A

郑吒 run 为 `zheng_zha/run`；丧尸有效 run 为 `zombie_scientist/run-native`。以下以郑吒为例。

```bash
/mnt/i/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/sprite-gen.exe prepare \
  --out-dir art_src/pixel_test/zheng_zha/run --character-id zheng_zha_pixel \
  --base-image art_src/pixel_test/zheng_zha/base.png \
  --request art_src/pixel_test/zheng_zha/request.json \
  --cell-size 48 --fit-pixel-unfake --fit-logical-height 48 \
  --fit-palette-size 32 --fit-outline off --chroma-key '#FF00FF'

/mnt/i/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/python.exe \
  art_src/pixel_test/generate_facing_rows.py \
  --run-dir art_src/pixel_test/zheng_zha/run --provider codex \
  --facing right --handed 'the single black pistol=right hand' --concurrency 2

/mnt/i/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/sprite-gen.exe extract \
  --run-dir art_src/pixel_test/zheng_zha/run

/mnt/i/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/python.exe \
  art_src/pixel_test/apply_native_curation.py \
  --run-dir art_src/pixel_test/zheng_zha/run --scale 0.8 --dy 3.2

/mnt/i/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/sprite-gen.exe compose-atlas \
  --run-dir art_src/pixel_test/zheng_zha/run

/mnt/i/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/python.exe \
  I:/workspace/mobilegame/tools/sprite-gen/scripts/compose_sprite_gif.py \
  --run-dir art_src/pixel_test/zheng_zha/run \
  --out-dir art_src/pixel_test/zheng_zha/previews-4x --scale 4
```

首次 extract **之前**，将本次提交记录的 `palette.lock.json` 放入 run（`colors` 必须逐项等于 palette.hex）。prepare 不会自动建外部共享调色板。不要开启 outline，它会在量化之后改变 RGB。

`generate_facing_rows.py` 仅转发方向参数给原生 gen-set 的 `gen_runner`，不重写生图流程；非空 handed 禁用 regen 的镜像回退。`apply_native_curation.py` 仅通过原生接口写 sidecar，由原生 compose 执行统一最近邻变换，不在 Python 中另写人物裁切、缩放、抠图或动画合成算法。

本次先生成 idle/attack/hit，用户确认“按站立高度验收，倒地自然变矮”后追加 down/death。因此生成分成两批。原始前三状态的未调整图集保留在 `uncurated/` 作比较；原始逐帧始终在 run 的 frames 中，curation 不覆盖它们。

原生 `sprite-gen compose-gif` 包装入口没有暴露 `--scale`，所以四倍 QA GIF 使用同一安装包的官方 `scripts/compose_sprite_gif.py`。运行时仅 idle 循环，QA GIF 会回绕方便重复查看；GIF 以 10ms 为单位，6fps 的 167ms 会量化为 170ms，不能当作运行时时序。

## 背景与审计

原生工具没有整张场景 kcentroid 缩小入口，使用任务卡允许的新工具：

```bash
/mnt/i/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/python.exe \
  game/tools/pixelize_scene.py art_src/pixel_test/background-raw.png \
  game/art/pixel_test/bg_lab_corridor_pixel.png \
  --palette game/art/pixel_test/palette.hex \
  --report art_src/pixel_test/background-conversion.report.json

/mnt/i/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/python.exe \
  art_src/pixel_test/audit_assets.py
```

背景转换只做整画布缩小和固定调色板量化，详见 `background-conversion.md`。审计脚本只读取落盘图，记录逐帧 bbox、实际色数、alpha、基线及 SHA-256。

`review.html` 是本地图片的四倍显示页，不处理图片。本次浏览器电脑操作因工具无法可靠识别当前 URL 而停止，最终视觉证据使用 Godot 实际渲染截图。
