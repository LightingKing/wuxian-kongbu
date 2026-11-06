# 丧尸像素动画 QA

日期：2026-11-06。任务卡 003 的丧尸素材子任务。最终图集和 manifest 已复制到 `game/art/pixel_test/zombie_scientist/`，复制前后字节一致；没有写 `.tres`，没有暂存、提交或推送。Godot 接入和实际播放由主任务统一完成。

## 输出

192×192 RGBA 图集，4 行×4 帧；每帧 48×48。整套实际使用共享调色板中的 23 色，调色板外颜色数为 0。所有 16 帧 alpha 只有 0/255，无空帧；每帧最后可见行都是 39（底边 40 exclusive）。

| 状态 | 帧数 / fps / loop | 最终逐帧可见高度 | 观察 |
|---|---|---|---|
| idle | 4 / 4 / true | 30、32、30、30 | 左向小幅摇晃，首末接近；身体与头部在中间帧有上抬和俯身 |
| attack | 4 / 6 / false | 32、32、31、32 | 收手、短距离前伸抓击、收回；手势完整，无武器或额外肢体 |
| hit | 4 / 6 / false | 30、32、29、30 | 后仰、低头、恢复；与 idle 有区别但都是小幅动作 |
| death | 4 / 6 / false | 32、27、21、11 | 站立、下蹲、跪撑、侧卧；末帧头在左端，身体自然变矮 |

四行保留黑色乱发、灰白脸、染血白大褂、胸牌、深色裤鞋和约 2.5 头身。48 像素格中的脸和胸牌已简化成少量色块，血迹与发丝无法逐像素锁定；这是本次试验的可读性和细节上限。最终4倍GIF已由原生工具输出到 `previews-4x/`。本子任务检查了原始横排、原生逐帧联系图和 GIF 首帧；没有把离散图像检查描述为连续播放已经完全平滑。

方向观察：基图、attack、hit、death 的原生观察返回 left；idle 返回 unknown / vision-uncertain，虽有 0.99 自报 confidence，也不算自动确认。原始 idle 横排中四个鼻尖、眼睛和伸手都明确朝左，人工式图像复核判为左向。全部生成使用 facing-fix=regen 和非空 handed；实际报告均 action=none，没有镜像，也没有方向重生。

## 原生流程和检查限制

prepare → 原生 gen-set 调度 → extract → 原生 curation → compose-atlas。复用旧任务的只读方向参数适配器，未改工具安装目录。提取使用 pixel_unfake=true、logical_height=48、palette_size=32 和共享 palette.lock.json；outline=off。每个姿态都使用同一 scale=0.8、dy=3.2，原生 compose 用 NEAREST 烘焙，未单独放大倒地帧。

原生 extract 将站立行的约 37–40 像素高度统一交给 curation 缩到约 29–32。原图的格子比请求的32像素角色更细，首三行曾有 detect=1 与 runlen≈7 的 pitch disagreement、physical cap 警告；这些日志保留在 `extract-idle-attack.log` 和 `extract-hit.log`。没有改阈值去消掉提示。

最终 inspect 退出 0、errors=[]。score 退出 **1**、ok=false、总分 **94.75**：idle/attack/hit 各100，death为79。death 的原生检测认为部分帧的 pitch 不稳定，采用10.86的共识；runlen参考约6.98，frame 2自测5.0被当作谐波，frame 0/1使用共识回退。还记录了物理尺寸上限与安全区余量信息。`run-native/sprite-score.report.json` 和 `sprite-inspect.report.json` 保留原文。

主任务决定保留当前death及警告，不为提高分数重生。最终像素满足尺寸、颜色、alpha与底线硬约束，但原生低分说明“同一格子稳定重建”仍有风险；不能把这套试验称为已能稳定批量生产的流程。

## 次数、耗时与中断边界

成功取得报告和图片共 **5 次**：1 张基图 + 4 张动作横排。没有成功产物的重生。所有渠道均为 codex；未使用 pixel-draw、付费fallback、Breathe或RIFE。

| 图片 | image report 的 elapsed_seconds |
|---|---:|
| 基图 | 119.469 |
| idle | 122.081 |
| attack | 161.731 |
| hit | 167.456 |
| death | 160.193 |
| 图片阶段累计 | **730.930 秒（约 12 分 11 秒）** |

该累计是图片生成报告之和，不是端到端墙钟。前三行以并发2生成，death在高度规则确认后单独生成；各动作 gen-set 日志记录含方向检查的任务时间约159.1 / 201.8 / 195.9 / 188.2秒。后处理、检查和文档不在图片阶段耗时内。

此外有 **2 个已启动但中断的状态任务**（首次 `run/` 的idle和attack）。原因是基图发布后的额外chroma处理错误：模型返回的透明原图有304726个非零alpha像素，`base.png`却被误抠到93个。发现后立即中断，再用未改写的原生 `base.png.raw.png` 重新准备 `run-native/`。错误图、原始图和中断目录都保留。

两个中断任务只有空日志，没有横排原图或完成报告。因此只能确认工具已启动请求，不能确认provider端是否已完成，也不能把它们报为“零次生成”或“两个完成生成”。它们的未知耗时不计入730.930秒。`qa-summary.json` 记录此边界和已完成报告，主任务据此汇总整体次数。

最终SHA-256、逐帧实测和报告路径见 `qa-summary.json`。它由只读 `record_qa.py` 生成；输出自身和会在运行结束继续写入的 `pixel-audit.log` 不参与自身文件哈希，避免循环或过时哈希。
