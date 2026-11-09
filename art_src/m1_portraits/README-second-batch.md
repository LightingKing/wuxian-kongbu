# M1 剧情立绘：第二批生产记录

对应任务卡 `docs/codex-tasks/005-m1-portraits.md`。本批仅制作剩余 12 张立绘，沿用第一批已验收的画风与提示词首段，不重复第一批生图，不制作第三批 CG。

## 当前状态

2026-11-10（北京时间）：12 张成品已全部生成、处理并通过自动 QA 和人工看图复核。共串行调用 13 次图片 API：11 个角色各一次，主神因首版辉光触边重做一次。12 张采用的原图均为 1024×1536 RGBA，成品均为 512×768 RGBA。此记录不替代用户风格验收。

用户已明确授权通过 `https://hy.nps1.aizhidong.com:8443/v1` 调用图片模型。本批使用本机 sprite-gen 的 `openai` 适配器与 `gpt-image-2.6-flare`，凭据仅由安全环境注入调用进程的 `OPENAI_API_KEY`，不将密钥值或读取路径写进文档、提示词、脚本或报告。

## 本批范围

全部成品为 512×768 RGBA PNG，保存至 `game/art/portraits/<id>.png`。

| ID | 内容与固定特征 | 构图与 alpha |
|---|---|---|
| `mu_gang` | 牟钢；壮实、工装背心、手臂旧疤 | 半身、透明背景 |
| `li_xiao_yi` | 李萧毅；十七八岁、瘦、校服外套、紧张 | 半身、透明背景 |
| `xiao_pang_zi` | 小胖子；圆脸、T 恤、缩肩 | 半身、透明背景 |
| `zhong_nian_fu_nv` | 中年妇女；四十多岁、憔悴、针织外套 | 半身、透明背景 |
| `alice` | 艾丽丝；短发、红色连衣裙、警觉 | 半身、透明背景 |
| `rain` | 雷恩；短发女雇佣兵、战术装备、机枪背带 | 半身、透明背景 |
| `kaplan` | 卡普兰；眼镜、工装、抱一台闭合笔记本电脑 | 半身、透明背景 |
| `matt` | 马特；冲锋衣、普通市民气质 | 半身、透明背景 |
| `jd` | J·D；男雇佣兵、痞气、咀嚼神情 | 半身、透明背景 |
| `ryan` | 瑞恩；女雇佣兵、马尾、护目镜挂在颈前 | 半身、透明背景 |
| `red_queen` | 火焰女皇；红色全息少女、中性表情、边缘扫描线 | 允许不规则投影与主体半透明 |
| `zhushen` | 主神；独立冷白／淡金悬浮光球，无脸、无场景 | 圆形球体近不透明，辉光渐隐至透明 |

普通人物统一左前方主光、居中偏下、头顶约 8% 余量；人物只出现一名。火焰女皇和主神按任务卡允许非人构图，保留其半透明效果，不套用普通人物的主体近不透明规则。

## 文件与复现约定

- 完整提示词：`art_src/prompts/<id>.md`，唯一的 `text` 围栏块为实际输入，包含负向词。全部风格首段与第一批詹岚逐字一致。
- 实际发送副本：`art_src/m1_portraits/prompts/<id>.txt`，UTF-8。
- 原图：`art_src/m1_portraits/sources/<id>.png`，工具保存的 `.raw.png` 同样保留，不覆写。
- 原生生成报告：`art_src/m1_portraits/reports/<id>.json`。
- 原生处理结果：`art_src/m1_portraits/processed/<id>/`，包含适配图与处理报告。
- 最终成品：`game/art/portraits/<id>.png`；图片仅保留本机，不加入 Git。
- 校验和：`art_src/qa/portraits.sha256`，更新第二批条目并保留第一批。

API 请求 `--aspect-ratio 2:3`，工具发送的尺寸参数为 1024×1536；这不保证网关实际返回相同像素尺寸，须检查原图及原生报告。最终通过 sprite-gen 原生命令等比适配到 512×768，不另写生成、抠图或切图脚本。

当前适配器不支持 seed，元数据如实记录 `null`。同一人物后续变体沿用固定描述和已验收参考图，不承诺同 seed 或逐像素复现。

## PowerShell 复现步骤

从仓库根目录执行，事先为调用进程安全设置 `OPENAI_API_KEY`。以下只包含本批 12 个 ID。生成段逐张等待完成；已有输出与报告则复用。需重新生成候选时另用输出目录，以保留此前结果。

```powershell
if (-not $env:OPENAI_API_KEY) { throw '请先为调用进程设置 OPENAI_API_KEY。' }
$env:SPRITE_GEN_OPENAI_BASE_URL = 'https://hy.nps1.aizhidong.com:8443/v1'
$secondBatchSpriteTool = 'I:/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/sprite-gen.exe'
$secondBatchPython = 'I:/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/python.exe'
$secondBatchHumanIds = @('mu_gang', 'li_xiao_yi', 'xiao_pang_zi', 'zhong_nian_fu_nv', 'alice', 'rain', 'kaplan', 'matt', 'jd', 'ryan')
$secondBatchIds = $secondBatchHumanIds + @('red_queen', 'zhushen')
$secondBatchUtf8 = [System.Text.UTF8Encoding]::new($false)

foreach ($directory in @('prompts', 'sources', 'reports', 'processed')) {
    New-Item -ItemType Directory -Force -Path "art_src/m1_portraits/$directory" | Out-Null
}
foreach ($assetId in $secondBatchIds) {
    $markdown = Get-Content -LiteralPath "art_src/prompts/$assetId.md" -Raw -Encoding utf8
    $blocks = [regex]::Matches($markdown, '(?s)```text\r?\n(.*?)\r?\n```')
    if ($blocks.Count -ne 1) { throw "$assetId 的 text 代码块数量必须为 1。" }
    [System.IO.File]::WriteAllText("$PWD/art_src/m1_portraits/prompts/$assetId.txt", $blocks[0].Groups[1].Value + "`n", $secondBatchUtf8)
}

foreach ($assetId in $secondBatchIds) {
    $sourcePath = "art_src/m1_portraits/sources/$assetId.png"
    $reportPath = "art_src/m1_portraits/reports/$assetId.json"
    if ((Test-Path -LiteralPath $sourcePath) -and (Test-Path -LiteralPath $reportPath)) { continue }
    & $secondBatchSpriteTool gen --provider openai --model gpt-image-2.6-flare --aspect-ratio 2:3 --prompt-file "art_src/m1_portraits/prompts/$assetId.txt" --out $sourcePath --transparent --alpha-mode native --report $reportPath
    if ($LASTEXITCODE -ne 0) { throw "$assetId 生成失败；先检查原生错误，不自动重发。" }
}
```

以下为实际使用的适配参数。普通 10 人使用原生淡雾清理；火焰女皇和主神使用 `--alpha-floor 0`，保留半透明扫描线或辉光。火焰女皇沿用人物布局，再通过原生 `scene-render` 调整整体透明度；主神使用 `target-height=440`、`baseline-y=604`，保持圆形。

```powershell
New-Item -ItemType Directory -Force -Path 'game/art/portraits' | Out-Null
foreach ($assetId in $secondBatchIds) {
    $alphaFloor = 64
    $baselineY = 766
    $targetHeight = 705
    if ($assetId -eq 'red_queen') { $alphaFloor = 0 }
    if ($assetId -eq 'zhushen') {
        $alphaFloor = 0
        $baselineY = 604
        $targetHeight = 440
    }
    & $secondBatchSpriteTool slice-sheet --sheet "art_src/m1_portraits/sources/$assetId.png" --out-dir "art_src/m1_portraits/processed/$assetId" --chroma-key none --alpha-floor $alphaFloor --grid 1x1 --names $assetId --cell-width 512 --cell-height 768 --baseline-y $baselineY --target-height $targetHeight --fit contain
    if ($LASTEXITCODE -ne 0) { throw "$assetId 原生处理失败。" }
    if ($assetId -ne 'red_queen') {
        Copy-Item -LiteralPath "art_src/m1_portraits/processed/$assetId/$assetId.png" -Destination "game/art/portraits/$assetId.png"
    }
}

# scene-render 要求新建或空的输出目录；重跑时使用新的目录，保留旧记录。
$redQueenRenderDir = 'art_src/m1_portraits/processed/red_queen_translucent'
if (Test-Path -LiteralPath $redQueenRenderDir) {
    $redQueenRenderDir += '_' + [guid]::NewGuid().ToString('N')
}
& $secondBatchSpriteTool scene-render --spec 'art_src/m1_portraits/red_queen-opacity.scene.json' --out-dir $redQueenRenderDir --formats png
if ($LASTEXITCODE -ne 0) { throw '火焰女皇透明度合成失败。' }
Copy-Item -LiteralPath "$redQueenRenderDir/frames/frame-00000.png" -Destination 'game/art/portraits/red_queen.png'

& $secondBatchPython 'art_src/m1_portraits/qa_second_batch.py'
if ($LASTEXITCODE -ne 0) { throw '第二批自动 QA 未通过，请查看报告。' }
```

QA 写入 `art_src/m1_portraits/qa-second-batch.json`。全部自动检查通过后才生成深底、浅底、328×328 头像三张预览，并更新校验和清单、保留第一批条目；失败时不会刷新预览或校验和，应避免把旧输出当作本次结果。

## 人工复核与最终记录

自动 QA 不代替视觉验收。重点检查：年龄和服装设定、脸与发型辨识度、手部和道具、雷恩短发与瑞恩马尾的区分、透明边缘和头顶余量、火焰女皇的扫描线与中性表情、主神球面无脸且保持正圆，以及三张预览中的整体一致性。非人的半透明和辉光属于预期效果，不能为了普通人物的 alpha 指标而破坏。

2026-11-10 完成记录：

- 全部 12 张通过 PNG、512×768、RGBA、非空主体、四角及四条外边全透明检查；普通人物的主体像素接近不透明。自动 QA 与来源哈希见 `qa-second-batch.json`，最终 SHA-256 见 `../qa/portraits.sha256`，逐次耗时见 `reports/<id>.json` 的 `elapsed_seconds`。
- 普通 10 人通过 `alpha-floor=64` 清理外围淡雾；原生报告记录主体和边缘像素未被清理操作改动，适配没有裁切主体。主体 alpha 主要为 253，沿用第一批的轻微透明，不另行强制变为 255。
- 火焰女皇原生生成的主体接近不透明，使用 `red_queen-opacity.scene.json` 的单层 `opacity=0.65` 合成后，成品 alpha 最大值为 165；原图、适配图和透明合成结果均保留。
- 主神 v1 左右辉光被源图边缘截断，已归档到 `rejected/zhushen-v1/`。更新提示词增加安全余量后重做，采用 v2，球体和有意义的辉光完整，最终四边全透明。
- 主代理与独立代理已实际查看最终深浅底合集及角色单图，主代理还检查了 328×328 头像裁切；未发现必须返工的问题。逐项观察及限制见 `visual-review-second-batch.md`。自动 QA 中的 `visual_review: pending` 表示脚本不作视觉验收结论，人工结论单独记录。
- 预览：`previews/second_batch_dark.png`、`previews/second_batch_light.png`、`previews/second_batch_avatars.png`，均仅保留本机。
- 已知限制：J·D 的咀嚼动作在静态图中较含蓄，更接近偏嘴微笑；半透明火焰女皇在浅底更淡，主神的淡金辉光在浅底对比更低，但形体仍可辨认。卡普兰的“笔记本”按笔记本电脑处理，其他首次补齐的发色、衣服细节见固定提示词，后续变体应以验收后的成品作参考。
- 仓库根目录运行 `bash game/tools/run_tests.sh`，退出 0，共 393 个测试，失败 0 个；日志为 `tests-second-batch.log`。
