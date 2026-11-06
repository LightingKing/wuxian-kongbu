# 丧尸像素动画复现

任务卡 003。工具 sprite-gen 3.15.0；只使用 codex 登录渠道。

输入身份参考为 `game/art/style_test/zombie_scientist_attack.png`。基图提示词在 `base.prompt.txt`。`base.gen-report.json` 保留实际请求、方向观察和耗时。已接受的基图是未经改写的 `base.png.raw.png`：模型实际返回 native alpha，而请求中的额外 chroma 步骤把发布的 `base.png` 误抠除到只剩 93 个非零 alpha 像素；原图有 304726 个。错误发布图也保留，不作为最终参考。

`run/` 是发现上述错误后中断的首次动画批次，idle/attack 的日志已建立，但没有原图或完成报告。不能把它算作零次调用，也不能声称两个请求生成成功。采用正确透明原图的有效运行目录是 `run-native/`。

命令都从仓库根目录由 bash 执行。CLI 和 Python 必须来自 sprite-gen 自己的虚拟环境。Windows 可执行程序的数据路径使用仓库相对路径。

```bash
WSLENV=SPRITE_GEN_CODEX_UNAVAILABLE SPRITE_GEN_CODEX_UNAVAILABLE=ask /mnt/i/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/sprite-gen.exe gen --provider codex --prompt-file art_src/pixel_test/zombie_scientist/base.prompt.txt --ref game/art/style_test/zombie_scientist_attack.png --out art_src/pixel_test/zombie_scientist/base.png --transparent --alpha-mode chroma --chroma-key magenta --decontam auto --direction side --facing left --facing-fix regen --handed 'the ID badge=left chest' --report art_src/pixel_test/zombie_scientist/base.gen-report.json

/mnt/i/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/sprite-gen.exe prepare --out-dir art_src/pixel_test/zombie_scientist/run-native --character-id zombie_scientist --base-image art_src/pixel_test/zombie_scientist/base.png.raw.png --request art_src/pixel_test/zombie_scientist/request.json --description 'Q-style pixel zombie scientist with messy black hair, pale gray skin, torn bloody off-white coat, ID badge and dark trousers' --cell-size 48 --safe-margin 8 --chroma-key '#FF00FF' --fit-pixel-unfake --fit-logical-height 48 --fit-palette-size 32 --fit-outline off

WSLENV=SPRITE_GEN_CODEX_UNAVAILABLE SPRITE_GEN_CODEX_UNAVAILABLE=ask /mnt/i/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/python.exe art_src/style_test/anim/generate_facing_rows.py --run-dir art_src/pixel_test/zombie_scientist/run-native --provider codex --facing left --handed 'the ID badge=left chest' --concurrency 2

/mnt/i/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/sprite-gen.exe extract --run-dir art_src/pixel_test/zombie_scientist/run-native --decontam auto
/mnt/i/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/python.exe art_src/pixel_test/zombie_scientist/apply_uniform_scale.py
/mnt/i/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/sprite-gen.exe compose-atlas --run-dir art_src/pixel_test/zombie_scientist/run-native
/mnt/i/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/python.exe ../tools/sprite-gen/scripts/compose_sprite_gif.py --run-dir art_src/pixel_test/zombie_scientist/run-native --out-dir art_src/pixel_test/zombie_scientist/previews-4x --scale 4
/mnt/i/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/sprite-gen.exe preview --run-dir art_src/pixel_test/zombie_scientist/run-native
/mnt/i/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/sprite-gen.exe inspect --run-dir art_src/pixel_test/zombie_scientist/run-native
/mnt/i/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/sprite-gen.exe score --inspect-report art_src/pixel_test/zombie_scientist/run-native/sprite-inspect.report.json
/mnt/i/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/python.exe art_src/pixel_test/zombie_scientist/record_qa.py
```

首次 extract 前必须将共享 `game/art/pixel_test/palette.hex` 的 32 个 RGB 值写入本目录已经记录的 `run-native/palette.lock.json`；原生 extract 直接应用该锁，不做后置手工 recolor。`--fit-outline off` 避免原生描边变暗产生调色板外颜色。动作行 gen 不传 transparent，不做额外抠图；实际返回的是不透明 magenta 行图，由原生 extract 统一分帧、去色键、pixel-unfake、映射调色板和二值化 alpha。

实际执行先生成 idle/attack/hit 三行，再在用户确认“站立高度验收，倒地自然变矮”后追加 death。追加时原生 prepare 使用 `--force` 更新同一个请求、提示词和 guide，保留已生成的原图及帧；只生成 death 新行。首次中断目录保留，不复用它的素材。

`apply_uniform_scale.py` 只通过原生 `write_curation_atomic` 写入统一 scale=0.8、dy=3.2 的 curation sidecar。所有姿态同一倍率，compose 负责 NEAREST 和像素格量化；没有直接画图、逐帧等高、镜像或定制分帧。底边为 40 exclusive，即最后可见像素行 39。

`record_qa.py` 只读取图像与原生 manifest，统计真实输出的尺寸、alpha、颜色、包围盒、方向观察报告、实际耗时与 SHA-256，不生成或修改任何像素。GIF 仅用于 QA，会循环回绕；非循环状态的游戏行为以 manifest 为准。
