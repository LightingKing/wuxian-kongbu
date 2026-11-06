# 任务 002：动画试验复现说明

全部 shell 命令从仓库根目录通过本机 Git Bash 入口执行；该入口实际使用 WSL。Windows sprite-gen/Python 的参数使用仓库相对路径或 Windows 路径，不能把 `/mnt/i/...` 当作 Windows 程序的数据文件路径。

只使用 `../tools/sprite-gen/.venv/Scripts/` 里的工具。codex 登录不可用时停止，不切换付费 provider；本轮没有使用 RIFE。运行记录对应 sprite-gen 3.15.0，图片生成不是确定性的，SHA-256 用于识别这次本机产物，不承诺重新生成得到相同像素。

## 实际流程

1. 以现有的两张接受图运行 workflow；按角色输入 request 执行原生 prepare。输入 request 与输出 run 必须分开，`--description` 和 `--chroma-key` 从 CLI 传给 prepare。
2. 使用 `generate_facing_rows.py` 调原生 `sprite_gen.gen.gen_set.run_set`。该版本 gen-set CLI 不转发 facing 参数，适配器仅给每次原生 gen 调用添加方向和 handed 参数，调度、参考图解析、报告与复用仍由原工具完成。
3. 使用原生 extract（components，decontam=auto）、compose-atlas、compose-gif、preview_animation.py、inspect。没有自制生成、抠图、分帧、图集合成或局部修图脚本。
4. 初始 raw/layout guide 均是 512×768 单帧的四帧横排。脚部锚点使伸手/侧卧行缩小后，保存初版，修改输出 run 的 `sprite-request.json.cell.width` 再运行 extract，保持所有原图、提示词和输入 request 不变。最终宽度见各 run request 与总报告。
5. 只把最终 PNG 和 manifest 复制到 `game/art/style_test/anim/<id>/`。原图、帧、提示词、QA GIF 均留在 art_src；Godot 导入器生成 `.tres`。

生成命令（需要对应 run 已 prepare；不得用 force 覆盖本次证据）：

```bash
WSLENV=SPRITE_GEN_CODEX_UNAVAILABLE SPRITE_GEN_CODEX_UNAVAILABLE=ask ../tools/sprite-gen/.venv/Scripts/python.exe art_src/style_test/anim/generate_facing_rows.py --run-dir art_src/style_test/anim/zheng_zha --provider codex --facing right --handed 'the single black pistol=right hand' --concurrency 2
WSLENV=SPRITE_GEN_CODEX_UNAVAILABLE SPRITE_GEN_CODEX_UNAVAILABLE=ask ../tools/sprite-gen/.venv/Scripts/python.exe art_src/style_test/anim/generate_facing_rows.py --run-dir art_src/style_test/anim/zombie_scientist/run --provider codex --facing left --handed 'the ID badge=left chest' --concurrency 2
```

以郑吒为例，原生后处理命令（丧尸替换 run 路径）：

```bash
../tools/sprite-gen/.venv/Scripts/sprite-gen.exe extract --run-dir art_src/style_test/anim/zheng_zha --decontam auto
../tools/sprite-gen/.venv/Scripts/sprite-gen.exe compose-atlas --run-dir art_src/style_test/anim/zheng_zha
../tools/sprite-gen/.venv/Scripts/sprite-gen.exe compose-gif --run-dir art_src/style_test/anim/zheng_zha --out-dir art_src/style_test/anim/zheng_zha/previews
../tools/sprite-gen/.venv/Scripts/python.exe ../tools/sprite-gen/scripts/preview_animation.py --run-dir art_src/style_test/anim/zheng_zha
../tools/sprite-gen/.venv/Scripts/sprite-gen.exe inspect --run-dir art_src/style_test/anim/zheng_zha
```

## Godot 与校验

```bash
godot --headless --editor --path game --import
godot --headless --path game --script res://tools/import_sprite_atlas.gd
godot --headless --path game --script res://ui/dev/verify_anim_preview.gd
godot --editor --path game res://ui/dev/anim_preview.tscn
bash game/tools/run_tests.sh
../tools/sprite-gen/.venv/Scripts/python.exe art_src/style_test/anim/audit_outputs.py
git ls-files '*.png' '*.gif'
```

在编辑器打开 anim_preview.tscn 后运行当前场景（F6）。空格暂停/继续，右方向键或“下个动作”按钮换状态，“自动轮播”开关可停在当前动作。界面按钮高度 64 px。

`audit_outputs.py` 只读取像素元数据、GIF 时长与文件哈希，不修改图片。`asset-audit.json` 收录本轮输入、最终资源、帧和 QA GIF 的 SHA-256。图片本身被 Git 忽略；从仓库拉取文本不会自动拥有这些本机 PNG，须恢复本地备份或重新生成后再导入。
