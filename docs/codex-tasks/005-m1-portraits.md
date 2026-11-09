# 任务卡 005：M1 剧情立绘与场景 CG

## 目标
给《生化危机一》这一部里的剧情人物和关键场景出图：**16 张半身立绘 + 4 张场景 CG**。
这批图只用在剧情/对话层（对话框右侧的立绘位、过场画面），玩法层（地点图、战斗卡片）继续用代码画的像素图，两者不要混。

## 先读
- `AGENTS.md`（尤其"图片不进仓库"这条）
- `docs/superpowers/specs/2026-11-05-wuxian-kongbu-game-design.md` 第 11 节（美术方向）
- `docs/codex-tasks/001-art-style-test.md`、`003-pixel-style-test.md`（前两次风格试验的结论）

## 已经定下来的边界
- **玩法层是像素**：地点图标、战斗卡片、头像占位，都由 `game/core/art/pixel_art.gd` 在运行时用代码画，不需要你出图。
- **剧情层是动漫插画**：这批立绘/CG 走日系动漫风格，写实比例、暗色、电影感。跟像素层刻意区分开。
- **图片不进版本库**：`.gitignore` 已经忽略 `*.png`。你只需要把图放到本机目录，把**提示词**和**校验和**提交进仓库。

## 产出路径

| 类型 | 路径 | 格式 |
|---|---|---|
| 立绘 | `game/art/portraits/<id>.png` | 512×768，PNG，RGBA 透明底 |
| 场景 CG | `game/art/cg/<scene>.png` | 1920×1080，PNG，不透明 |
| 提示词 | `art_src/prompts/<id>.md` | Markdown，一段可直接复现的提示词 + 负向词 + seed |
| 校验和 | `art_src/qa/portraits.sha256` | 每行 `<sha256>  <相对路径>` |

目录不存在就建；`art_src/` 已在仓库里（只提交提示词与校验和，图片本身被忽略）。

## 立绘清单（512×768，半身，透明底，人物居中偏下，头顶留 8% 余量）

| id | 中文名 | 要点 |
|---|---|---|
| `zheng_zha` | 郑吒 | 男，二十多岁普通公司职员，短袖衬衫有点皱，眼神倔，身上有伤 |
| `zhan_lan` | 詹岚 | 女，长黑发，冷静，浅色外套，目光像在算东西 |
| `zhang_jie` | 张杰 | 男，三十多，寸头，老兵体格，手里一把沙漠之鹰，笑得随意 |
| `mu_gang` | 牟钢 | 男，壮，工装背心，手臂有旧疤 |
| `li_xiao_yi` | 李萧毅 | 男，十七八岁学生，瘦，校服外套，紧张 |
| `xiao_pang_zi` | 小胖子 | 男，圆脸，T 恤，缩着肩 |
| `zhong_nian_fu_nv` | 中年妇女 | 女，四十多，憔悴，针织外套 |
| `matthew` | 马修·艾迪森 | 男，雇佣兵队长，战术背心，短胡渣，硬派 |
| `alice` | 艾丽丝 | 女，短发，红色连衣裙，眼神警觉 |
| `rain` | 雷恩 | 女，雇佣兵，短发，战术装备，机枪背带 |
| `kaplan` | 卡普兰 | 男，技术员，眼镜，工装，抱着笔记本 |
| `matt` | 马特 | 男，环保主义者，冲锋衣，普通市民气质 |
| `jd` | J·D | 男，雇佣兵，痞气，嚼着东西 |
| `ryan` | 瑞恩 | 女，雇佣兵，马尾，护目镜挂在脖子上 |
| `red_queen` | 火焰女皇 | 非人：红色全息少女投影，半透明，边缘有扫描线，表情中性 |
| `zhushen` | 主神 | 非人：巨大光球，冷白/金色，悬浮，不出现人脸 |

`red_queen` 与 `zhushen` 允许 512×768 内不规则构图（不一定半身），但要透明底。

## 场景 CG 清单（1920×1080，不透明）

| id | 场景 | 要点 |
|---|---|---|
| `cg_car` | 高速车厢 | 夜，车厢里七个人陆续醒来，窗外是隧道灯，冷蓝 |
| `cg_laser` | 激光通道 | 红色激光网正在合拢，窄门，人影剪影 |
| `cg_control` | 火焰女皇主机房 | 成排机柜，中央红色全息少女，冷光 |
| `cg_hub` | 主神空间 | 巨大光球悬在黑暗广场上，二十道光柱，庄严 |

## 一致性要求
1. **同一角色只锁一套外观**：先出一张，写进 `art_src/prompts/<id>.md`，后面所有变体都引用同一段人物描述和已验收的参考图。当前生图工具不支持 seed，一致性靠"固定描述 + 参考图 + 同批同风格前缀"维持，不要求 seed 可复现。
2. **统一画风**：同一批用同一段风格前缀（例如"日系动漫、赛璐璐上色、暗部偏冷、电影感构图、无文字"）。
3. **统一光比**：立绘统一左前方主光，背景透明，不要环境色溢出。
4. **不要出现的**：文字、水印、签名、边框、UI、多个角色同框（立绘里只画一个人）。

## 分批做
- **第一批（先验收风格）**：`zheng_zha`、`zhan_lan`、`zhang_jie`、`matthew`、`cg_laser` 五张。做完先停，等 Claude 看图确认，再批量。
- **第二批**：其余 12 张立绘（16 减去第一批 4 张）。
- **第三批**：其余 3 张 CG。

## 验收标准
- 尺寸、格式、透明底符合上表；
- 同一角色在不同图里能看出是同一个人（发型、服装、配色一致）；
- 立绘在 512×768 下缩到 328×328 的头像框里裁切后仍然认得出；
- 没有文字、水印、多角色；
- 提示词能复现：同一段描述 + 同一参考图，重跑结果在人物特征上接近（工具不支持 seed，不要求逐像素一致）。

## 不要做的事
- 不要把 png 提交进仓库（`git add -f` 也不行）。
- 不要改 `game/` 下的任何代码或数据，这批只出图。
- 不要动 `_work/`。
- 不要为了"更好看"改人物设定（年龄、性别、服装基调以上表为准）。

## 完成汇报
在本文件末尾追加：每批出了哪几张、路径、尺寸、SHA-256、遇到的问题；以及你认为描述里有歧义、需要 Claude 补设定的地方。

## 完成汇报

### 2026-11-09：第一批提示词准备完成，生成待登录渠道确认

- 已准备 `art_src/prompts/zheng_zha.md`、`zhan_lan.md`、`zhang_jie.md`、`matthew.md`、`cg_laser.md`，包含统一画风、固定人物描述、构图及负向词；生产说明在 `art_src/m1_portraits/README.md`。郑吒沿用已验收设定图的脸与发型，按本卡改为短袖。
- 尚未调用生图：Windows Codex CLI 当前检测为 API key 登录，需要按调用计费确认；WSL CLI 登录状态读取失败。用户约定使用 ChatGPT 订阅渠道，因此先等待恢复订阅登录或用户明确授权 API 计费。没有切换 provider，没有生成图片、生成报告或虚假的成品 SHA-256。
- 当前 sprite-gen / Codex image_gen 不支持 seed 参数，五份提示词将 seed 如实记为 `null`；无法验证“同 seed 重跑结果接近”。后续以固定人物描述、已验收参考图和原生生成报告维持一致性，需验收时确认这一工具限制。
- 清单计数提示：第二批应为其余 **12 张立绘**（16 − 4），原文“11 张”少算一张。
- 验证：仓库根目录 `bash game/tools/run_tests.sh` 退出 0，共 380 个测试，失败 0 个；`git ls-files '*.png' '*.gif'` 输出为空。未改游戏代码、数据或 `_work/`。

### 2026-11-09：第一批 5 张完成，待风格验收

用户随后明确授权使用 `https://hy.nps1.aizhidong.com:8443/` 网关和本机已配置的 API key。模型列表确认有 `gpt-image-2.6-flare` 与 `gpt-image-2.6-sunburst`，本批用 sprite-gen 的 `openai` 适配器调用前者，共 5 次生图、每张一次，无重生成。密钥仅注入子进程环境，没有写入仓库或生成记录。

| ID | 本机成品路径 | 尺寸 / 模式 | SHA-256 |
|---|---|---|---|
| 郑吒 | `game/art/portraits/zheng_zha.png` | 512×768 RGBA | `f39b4148f2fe4fa78dfea151c663e903e614d1975856e1ca85385c53aa26a9b9` |
| 詹岚 | `game/art/portraits/zhan_lan.png` | 512×768 RGBA | `11a3706e043d1a59a171cd637aa65da31ff7ca5bf49db1da212d4ad0429cf785` |
| 张杰 | `game/art/portraits/zhang_jie.png` | 512×768 RGBA | `8d8b58d2cd1ac78b5ea936aba6fa5c47df9019258e2b9043db6e953e39b734cf` |
| 马修 | `game/art/portraits/matthew.png` | 512×768 RGBA | `8d283bd222bc0e178f6dbe368d6b1a10c8fb1a20947081be93892eb21c78c208` |
| 激光通道 | `game/art/cg/cg_laser.png` | 1920×1080 RGB | `dee94b75f5e7d6aa9a0ecaba569a84049e80f9021afaa9b213e0809333032bf3` |

- 原图、原生生成报告、提示词提取副本、处理报告、预览、QA 和复现步骤保存在 `art_src/m1_portraits/`；完整提示词在 `art_src/prompts/`，最终校验和在 `art_src/qa/portraits.sha256`。
- 立绘原图为 1024×1536 RGBA，sprite-gen 原生单格 `slice-sheet` 清理外围透明雾点并统一画布，头顶有效余量 61～62px；四角和四条外边全透明，处理未裁掉主体。CG 实际返回 1672×941，使用已有 `fit_canvas.py` 等比适配，右侧补 1px 暗色。没有修改该脚本或其他游戏代码/数据。
- 主代理及独立代理实际查看深浅底立绘、328×328 头像、CG：人物外观与规定服装清楚，张杰只有一把枪，未见明显肢体错误或文字水印；全部技术检查通过。此结论不替代 Claude／用户风格验收。
- 已知限制：人物主体 alpha 主要为 253（约 99.2% 不透明），保留原生轻微透明并在 QA 记录；CG 金属反光较立绘更写实，激光网合拢的动势偏静态。当前首批没有新增必须补充的人物设定歧义；张杰深灰上衣、马修深色战术装备等细节见提示词，验收后再作为固定描述。
- 成品落盘后运行 `bash game/tools/run_tests.sh`：退出 0，共 380 个测试、失败 0 个；5 项最终 SHA-256 与文件重新计算结果一致，完整提示词与实际请求一致。图片仅留本机，未改 `_work/`。
- **停在第一批验收点**：依照本卡“做完先停，等 Claude 看图确认，再批量”，第二批 12 张立绘与第三批 3 张 CG 尚未开始。

## 完成汇报

### 2026-11-10：第二批 12 张立绘完成

依照本轮明确授权，仅制作以下第二批 12 张立绘。先写 `art_src/prompts/<id>.md`，沿用第一批相同的画风前缀，固定角色描述，再用 sprite-gen 的 `openai` 适配器经指定网关逐张调用 `gpt-image-2.6-flare`。共 13 次 API 调用：主神重做一次，其余各一次。原图均为 1024×1536 RGBA，seed 如实记为 `null`。

| ID | 本机成品路径 | 尺寸 / 模式 | SHA-256 |
|---|---|---|---|
| `mu_gang` | `game/art/portraits/mu_gang.png` | 512×768 RGBA | `44923a9c2ce4f49bbf25ff09c6399eb442d7059729b217ffc7e31887ff0a8a38` |
| `li_xiao_yi` | `game/art/portraits/li_xiao_yi.png` | 512×768 RGBA | `2325d8e59c14f0dc583a5c9524781e9207ccfb368b15c684452bfe87d4af18bf` |
| `xiao_pang_zi` | `game/art/portraits/xiao_pang_zi.png` | 512×768 RGBA | `956614239679760abe0b2889c8df9bde756a8e72d3ccd5082022169f8bff9446` |
| `zhong_nian_fu_nv` | `game/art/portraits/zhong_nian_fu_nv.png` | 512×768 RGBA | `9fc0845fd14bab67f16e3f99468586d8adad5bf916a2388503335dfcc307be0a` |
| `alice` | `game/art/portraits/alice.png` | 512×768 RGBA | `0aef94628b7867a95b9f3cd31837157d0d0dadbda0485ae6da80217fa2c7c3f5` |
| `rain` | `game/art/portraits/rain.png` | 512×768 RGBA | `74fbeff2588f8e270d225bd10425bce998c7ba11c38b81f056a17454826afea6` |
| `kaplan` | `game/art/portraits/kaplan.png` | 512×768 RGBA | `c13011016dd683367417abf43db5515253dcca68d26e1defaaa5b37695598372` |
| `matt` | `game/art/portraits/matt.png` | 512×768 RGBA | `8527e1dd6243e4bd0350adb4e3faf21b31603bc05215defd09c7b35d067360da` |
| `jd` | `game/art/portraits/jd.png` | 512×768 RGBA | `1849507ff754305058423d6b01b40eed3507cbb241efd98faa38215c51e81adf` |
| `ryan` | `game/art/portraits/ryan.png` | 512×768 RGBA | `588579bb9234da473a83301175d0676daa91f05587a53dfb1d92d8df8bc4f6fb` |
| `red_queen` | `game/art/portraits/red_queen.png` | 512×768 RGBA | `a2c5a8dc4043dc75d2d877a7bef2aad3684c98cff4b1a67bfed4afd924056867` |
| `zhushen` | `game/art/portraits/zhushen.png` | 512×768 RGBA | `80e96ecdfd0c579b06c6b5b58420c72c3a97eb34c466236e6b9840b2f5036a57` |

- 文件：新增 12 份完整提示词、实际输入 TXT、原生生成/处理报告与日志、自动 QA 脚本及报告、透明度合成规范和人工复核记录；更新 `art_src/qa/portraits.sha256`。完整复现步骤见 `art_src/m1_portraits/README-second-batch.md`。图片及中间图仅保留本机，未加入 Git。
- 处理：普通 10 人通过原生 `slice-sheet` 清理外围淡雾、等比适配；火焰女皇和主神保留原生扫描线及辉光。火焰女皇另以原生 `scene-render` 单层 `opacity=0.65` 合成，最终 alpha 最大值 165。主神首版源图辉光触边，已归档至 `art_src/m1_portraits/rejected/zhushen-v1/`；缩小占幅后重做 v2，圆球及辉光完整。
- 验证：12 张全部通过 PNG、512×768、RGBA、有效主体及透明边缘检查；原生处理报告无主体裁切。主代理与独立代理实际查看最终深浅底预览和单图，主代理核查 328×328 头像裁切；未发现必须返工的问题。自动结果见 `qa-second-batch.json`，人工结论见 `visual-review-second-batch.md`，仍待用户风格验收。
- 已知限制与设定解释：普通人物主体 alpha 主要为 253，与第一批一致；J·D 的咀嚼动作较含蓄，静态表现更像偏嘴微笑；火焰女皇和主神的浅底对比弱于深底。卡普兰的“笔记本”按笔记本电脑解释；其余未规定的发色、服装细节已记入固定提示词，后续由 Claude／用户确认后沿用。
- 项目测试：仓库根目录运行 `bash game/tools/run_tests.sh`，退出 0，共 393 个测试，失败 0 个，日志保存在 `art_src/m1_portraits/tests-second-batch.log`。第一批 5 个成品校验和保持原值；未改游戏代码、数据或 `_work/`，第三批 3 张 CG 未开始。
