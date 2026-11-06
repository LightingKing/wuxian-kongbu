# 郑吒动画 QA

2026-11-06，sprite-gen 3.15.0，原生 component-row engine revision `db8ab1c245df`。身份输入是已接受的 `game/art/style_test/zheng_zha_battle_idle.png`，没有额外动作参考。

## 生成与处理

- Pipeline A；每行 4 帧，codex 登录渠道，4 次生图，未重生、未镜像、未用收费 provider、RIFE 或手绘处理。
- `reports/gen-set/*.json` 是完整提示词、参考图、朝向检查与生成耗时证据。每行都传 `--facing right --facing-fix regen --handed 'the single black pistol=right hand'`；检查均观察为 right、action=none。非空 handed 禁止原生 regen 的镜像回退。
- 图片生成自身耗时：idle 120.705 s、attack 139.868 s、hit 162.830 s、down 163.433 s，总计 586.836 s。批处理含朝向观察等步骤的各行耗时为 412.0 / 192.5 / 424.7 / 199.0 s；并发 2，不能把串行求和当作实际等待时间。
- 文件时间观测的批次墙钟为 617.221 s（首个全新行日志创建到 set.report.json 写完），约 10 分 17 秒；来源保存在总 asset-audit.json。
- 原始布局与提示词使用 512×768、24 px 安全边距。初次提取发现 down 因脚部锚点加横向侧卧空间被整行缩小。保留在 `attempts/initial-512-cell/`，将最终 request 的输出宽度改为 768，再用原生 extract/compose 重做；没有重采样原图或手写裁切。
- 最终每帧 768×768；LANCZOS，foot-centroid/bottom，pixel_unfake=false，magenta 键，decontam=auto。down 首帧 alpha 高 699 px，idle 720 px；全部帧 alpha 底部 y=744，末帧侧卧右缘 x=726，未裁切。
- 观察到 hit 手指浅绿边后，以原生 `--decontam off` 对比，未消除该问题；恢复 auto。对照在 `attempts/768-decontam-auto/` 与 `attempts/768-decontam-off/`。没有用局部画图掩盖残留。
- 提前对部分已生成行执行 preview 被工具拒绝（缺 hit/down）；完整四行后正常生成。一次 Windows Python 脚本路径误用 WSL 绝对路径，改为仓库相对路径后正常运行；均未影响图像内容。

## 逐帧审查

| 状态 | 时间配置 | 静态逐帧结论 | 保留问题 |
|---|---|---|---|
| idle | 4 帧，4 fps，循环 | 四帧同一人物、低位单枪、脚底稳定，动作幅度很小 | inspect 提示 motion presence 0.0053 < 0.0100；不能当作明显呼吸动作 |
| attack | 4 帧，8 fps，单次 | 低位、抬枪、伸臂瞄准、回低位；单枪未丢失、未见多肢 | 后坐/射击反馈较弱；衣褶和发丝有重绘差异 |
| hit | 4 帧，6 fps，单次 | 守势、轻后仰、最大后仰、恢复；支撑手离枪，枪仍在右手 | 支撑手与原提示的双手持续持枪不完全一致；手指局部浅绿边 |
| down | 4 帧，6 fps，单次 | 微屈、屈膝、跪倒、侧卧，完整身体与右手单枪保留 | 跪倒到侧卧只有一帧跨度；落地脸转向观众一些，整体头向仍在右侧 |

主审和独立审查均检查了全部静态帧，没有发现额外肢体、重复枪或裁切；此项不等于动态流畅度通过。实际 Godot 播放记录见总报告。

原生 extract 无 errors/warnings；inspect 无 errors，但保留 idle 低运动量 warning。自动指标为 edge_pixels=0、chroma_adjacent_pixels=0；这不能排除肉眼可见的非键色浅绿残边。

`qa/*.gif` 与 `previews/*.gif` 都只是重复播放的 QA 工具；非循环动作不能用 GIF 的回绕评价首尾接缝，运行时以 manifest 的 loop=false 为准。GIF 的百分之一秒量化不等于运行时帧长：qa 中 8 fps 为 120 ms，6 fps 为 170 ms；compose-gif 的 6 fps 为 160 ms。最终 SpriteFrames 优先使用 manifest 的 durations_ms：标称 4/8/6 fps 分别为每帧 250/125/167 ms。
