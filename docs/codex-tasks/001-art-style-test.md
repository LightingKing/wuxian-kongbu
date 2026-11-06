# 任务卡 001：美术风格试验

## 目标
在批量生产美术之前，验证生图能否稳定做出本项目需要的风格、尺寸、透明背景，以及同一角色在多张图里保持一致。

## 先读
- `AGENTS.md`
- 设计规格第 11 节"美术规格"：`docs/superpowers/specs/2026-11-05-wuxian-kongbu-game-design.md`
- 全书摘要里《生化危机一》的部分：`docs/novel-summary.md`

## 允许修改
- `game/art/style_test/`（新建，放全部产出）
- `game/tools/fit_canvas.py`（新建，把生成的图放进规格画布）
- `docs/art/style-test-report.md`（新建）
- 本任务卡末尾的"完成汇报"一节

## 风格前缀（所有图共用，写在每条提示词最前面）
> 日系动漫立绘风格，线条干净利落，偏写实的头身比例（约 7 头身），赛璐璐上色带少量柔和阴影；整体色调偏暗、偏冷，带一点胶片颗粒感，恐怖片氛围；人物清晰，背景阴森。

## 要产出的图
1. **郑吒设定图**（先做这张，作为后面几张的参考图）：二十多岁的中国男性公司白领，短黑发，五官端正但神情疲惫，白衬衫、深色西裤、黑皮鞋，正面全身站立，纯色背景。文件 `game/art/style_test/zheng_zha_reference.png`，尺寸不限。
2. **郑吒立绘 ×2**：刚在高速列车车厢里醒来，惊惶而警觉。一张平静，一张恐惧。半身到大腿，**1024×1536，透明背景**。文件 `zheng_zha_portrait_calm.png`、`zheng_zha_portrait_fear.png`。
3. **郑吒战斗形象**：全身，**面朝画面右侧**，双手持手枪的戒备姿势，**512×768，透明背景**，脚底贴近画面下沿。文件 `zheng_zha_battle_idle.png`。
4. **丧尸**：地下生化研究所里穿白大褂的研究员丧尸，皮肤灰白，眼睛浑浊，**面朝画面左侧**，向前扑咬，**512×768，透明背景**。文件 `zombie_scientist_attack.png`。
5. **激光通道背景**：地下研究所里纯白金属墙面的长走廊，冷白顶灯，尽头一张红色激光网正逼近，压抑。**1920×1080**，不透明。文件 `bg_laser_corridor.png`。

## 用什么工具
用本机已装好的 **sprite-gen** 技能生图（用法见它的 `SKILL.md`，本机说明见 `~/.codex/AGENTS.md`）：
- 角色和敌人：`sprite-gen gen --provider codex --prompt-file <提示词文件> --out <输出> --transparent --report <报告>`。codex 能直接给透明背景，已实测。
- 第 2、3 张以设定图为参考：加 `--ref game/art/style_test/zheng_zha_reference.png`，保持是同一个人。
- 战斗形象和敌人要指定朝向：郑吒 `--facing right --direction side`，丧尸 `--facing left --direction side`；朝向不对时用 `--facing-fix regen` 重画，**不要镜像**（手枪会换手）。
- 背景图不加 `--transparent`。
- 生成的尺寸不是规格尺寸：写一个小脚本 `game/tools/fit_canvas.py`（Python 3 + Pillow），把图等比缩放、放进规格画布（透明补边；战斗形象脚底贴近画布下沿），命令行用法 `python game/tools/fit_canvas.py 输入.png 输出.png 宽 高 [--bottom]`。
- 如果某张透明边缘不干净，用 `sprite-gen cutout` 处理，不要自己写抠图脚本。

## 验收
- 上面 6 个文件都在 `game/art/style_test/` 下，尺寸符合要求；第 2~4 张有真正的透明通道（四角像素 alpha = 0）。
- 第 2、3 张里的郑吒和设定图看得出是同一个人。
- `docs/art/style-test-report.md` 写清楚：
  - 每张图实际用的完整提示词；
  - 一致性、手部、透明边缘这些问题各自的情况；
  - 建议：这套风格能不能批量生产；不能的话，怎么调整（例如降级为"立绘 + 剪影战斗形象"）。
- 在仓库根目录运行 `bash game/tools/run_tests.sh`，全部通过（确认没有碰坏其他东西）。

## 完成汇报
（Codex 在这里追加）
