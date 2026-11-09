# M1 剧情立绘与场景 CG：首批生产记录

对应任务卡：`docs/codex-tasks/005-m1-portraits.md`。用户已授权通过指定网关使用 API 生图，第一批 5 张已完成，技术检查通过，等待 Claude／用户风格验收；使用本机 sprite-gen，模型为 `gpt-image-2.6-flare`。

## 首批范围

| ID | 内容 | 最终规格 | 成品路径 |
|---|---|---|---|
| `zheng_zha` | 郑吒 | 512×768，RGBA 透明底 | `game/art/portraits/zheng_zha.png` |
| `zhan_lan` | 詹岚 | 512×768，RGBA 透明底 | `game/art/portraits/zhan_lan.png` |
| `zhang_jie` | 张杰 | 512×768，RGBA 透明底 | `game/art/portraits/zhang_jie.png` |
| `matthew` | 马修·艾迪森 | 512×768，RGBA 透明底 | `game/art/portraits/matthew.png` |
| `cg_laser` | 激光通道 | 1920×1080，PNG 不透明 | `game/art/cg/cg_laser.png` |

立绘采用半身构图，人物居中偏下，头顶保留约 8%（61px）空白，统一左前方主光。首批完成后按任务卡验收风格，再制作后续批次。

## 网关与生成记录（2026-11-09）

最初检查发现 Windows Codex CLI 使用 API key、WSL 登录状态读取失败，曾暂停生成。随后用户明确指定并授权 `https://hy.nps1.aizhidong.com:8443/`；使用本机配置的 API key 请求该域的 `GET /v1/models` 成功，返回 `gpt-image-2.6-flare` 与 `gpt-image-2.6-sunburst`。本批选择 `gpt-image-2.6-flare`，通过 sprite-gen 的 OpenAI 兼容接口调用，原登录阻塞已解决。

- Provider：`openai`；API 根地址：`https://hy.nps1.aizhidong.com:8443/v1`。
- 密钥仅注入调用子进程的 `OPENAI_API_KEY` 环境变量，不写入提示词、仓库、日志或报告，不展示密钥值。
- 立绘请求 `--aspect-ratio 2:3`，请求及实际返回尺寸均为 1024×1536；CG 请求 `16:9`、请求尺寸 1536×864，网关实际返回 1672×941。最终画布适配到任务要求尺寸。
- 郑吒原图已成功生成，耗时 63.238 秒，接口 `/images/edits`；詹岚 34.629 秒、张杰 42.077 秒，接口 `/images/generations`。马修 42.095 秒、激光 CG 29.189 秒，也均生成成功。每张生成一次，共 5 次 API 生图，没有重生成。

以上耗时以原生生成报告为准。成品通过技术检查和人工风格验收后，才继续后续批次。

## 提示词与输出约定

- 完整提示词：`art_src/prompts/<id>.md`。**只提取其中唯一的 `text` 围栏代码块**作为实际发送内容；该块已包含负向词，不发送 Markdown 说明或其他代码块。
- 提取后的纯文本：`art_src/m1_portraits/prompts/<id>.txt`，使用 UTF-8。
- 生成原图：`art_src/m1_portraits/sources/<id>.png`，保留工具产生的原始副本。
- 原生生成报告：`art_src/m1_portraits/reports/<id>.json`，仅由实际生成产生，不预填成功记录。
- 立绘适配结果及原生处理报告：`art_src/m1_portraits/processed/<id>/`。保留原图与 `.raw.png`，不覆写源文件。
- 最终成品按上表保存，原图、中间文件、提示词与报告留在 `art_src/`。
- 全部首批成品实际生成并检查后，再写入 `art_src/qa/portraits.sha256`，格式为 `<sha256>  <相对路径>`；图片只留本机，不加入 Git。

## 复现步骤

从仓库根目录运行 PowerShell，调用进程需事先安全设置 `OPENAI_API_KEY`。以下使用已安装虚拟环境中的绝对路径，不使用全局 Python。生成命令会向用户指定网关发起实际 API 调用；若需保留既有候选，使用新的输出目录。

```powershell
if (-not $env:OPENAI_API_KEY) { throw '请先为调用进程设置 OPENAI_API_KEY。' }
$env:SPRITE_GEN_OPENAI_BASE_URL = 'https://hy.nps1.aizhidong.com:8443/v1'
$portraitSpriteTool = 'I:/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/sprite-gen.exe'
$portraitPython = 'I:/workspace/mobilegame/tools/sprite-gen/.venv/Scripts/python.exe'
$portraitIds = @('zheng_zha', 'zhan_lan', 'zhang_jie', 'matthew')
$allPortraitBatchIds = $portraitIds + @('cg_laser')
$portraitUtf8 = [System.Text.UTF8Encoding]::new($false)

foreach ($directory in @('prompts', 'sources', 'reports', 'processed')) {
    New-Item -ItemType Directory -Force -Path "art_src/m1_portraits/$directory" | Out-Null
}
foreach ($assetId in $allPortraitBatchIds) {
    $markdown = Get-Content -LiteralPath "art_src/prompts/$assetId.md" -Raw -Encoding utf8
    $blocks = [regex]::Matches($markdown, '(?s)```text\r?\n(.*?)\r?\n```')
    if ($blocks.Count -ne 1) { throw "$assetId 的 text 代码块数量必须为 1。" }
    [System.IO.File]::WriteAllText("$PWD/art_src/m1_portraits/prompts/$assetId.txt", $blocks[0].Groups[1].Value + "`n", $portraitUtf8)
}
```

逐张生成四张立绘。显式指定 `--alpha-mode native`，避免带参考图时自动改走色键。郑吒参考图仅用于保留身份与画风，衬衫以本任务要求的短袖为准。

```powershell
foreach ($assetId in $portraitIds) {
    $portraitGenArgs = @('gen', '--provider', 'openai', '--model', 'gpt-image-2.6-flare',
        '--aspect-ratio', '2:3', '--prompt-file', "art_src/m1_portraits/prompts/$assetId.txt",
        '--out', "art_src/m1_portraits/sources/$assetId.png", '--transparent', '--alpha-mode', 'native',
        '--report', "art_src/m1_portraits/reports/$assetId.json")
    if ($assetId -eq 'zheng_zha') {
        $portraitGenArgs += @('--ref', 'game/art/style_test/zheng_zha_reference.png')
    }
    & $portraitSpriteTool @portraitGenArgs
    if ($LASTEXITCODE -ne 0) { throw "$assetId 生成失败，请检查原生错误后再处理。" }
}

& $portraitSpriteTool gen --provider openai --model gpt-image-2.6-flare --aspect-ratio 16:9 --prompt-file 'art_src/m1_portraits/prompts/cg_laser.txt' --out 'art_src/m1_portraits/sources/cg_laser.png' --report 'art_src/m1_portraits/reports/cg_laser.json'
if ($LASTEXITCODE -ne 0) { throw 'cg_laser 生成失败，请检查原生错误后再处理。' }
```

使用 sprite-gen 原生 `slice-sheet` 的单格流程清理外围淡雾并等比适配立绘。`--alpha-floor 64` 保留主体与相邻抗锯齿边缘，清除远离主体的低 alpha 雾点；不把主体 alpha 强制改为 255。`--baseline-y 766 --target-height 705 --fit contain` 保持下方定位及约 8% 头顶余量，实际留白仍需检查。

```powershell
New-Item -ItemType Directory -Force -Path 'game/art/portraits', 'game/art/cg' | Out-Null
foreach ($assetId in $portraitIds) {
    & $portraitSpriteTool slice-sheet --sheet "art_src/m1_portraits/sources/$assetId.png" --out-dir "art_src/m1_portraits/processed/$assetId" --chroma-key none --alpha-floor 64 --grid 1x1 --names $assetId --cell-width 512 --cell-height 768 --baseline-y 766 --target-height 705 --fit contain
    if ($LASTEXITCODE -ne 0) { throw "$assetId 画布适配失败。" }
    Copy-Item -LiteralPath "art_src/m1_portraits/processed/$assetId/$assetId.png" -Destination "game/art/portraits/$assetId.png"
}
& $portraitPython 'game/tools/fit_canvas.py' 'art_src/m1_portraits/sources/cg_laser.png' 'game/art/cg/cg_laser.png' 1920 1080
if ($LASTEXITCODE -ne 0) { throw 'cg_laser 画布适配失败。' }
```

CG 使用仓库已有的 `game/tools/fit_canvas.py`，未修改脚本。只有最终图片放入 `game/art/`，所有来源及处理报告留在 `art_src/`。

## 一致性与验收

当前 CLI 不支持 seed 参数，提示词记录中的 seed 为 `null`（不支持），不能承诺同 seed 复现。保留完整提示词、原图与报告；后续同一人物引用首张已验收图及固定人物描述，以提高外观一致性。

目前已生成的人物原图主体 alpha 主要为 253，没有 255 像素，约为 99.2% 不透明。这是模型输出的轻微半透明限制；保留原始 alpha 并在深浅底检查效果，不通过整体强制不透明掩饰。原生清理仅处理外围淡雾，处理报告保留实际修改统计。

使用 `art_src/m1_portraits/qa_first_batch.py` 检查最终尺寸、图像模式、alpha、边界及 SHA-256，并生成供人工复核的预览；以实际脚本输出为准。人工检查头顶留白、深浅底边缘、人物身份与服装、手部和枪械数量、328×328 头像裁切辨识度。CG 检查动漫画风、窄门、人物剪影与正在合拢的红色激光网。未通过的候选保留来源与问题记录。

首批通过人工风格验收前，不开始第二、第三批。第二批为其余 12 张立绘，任务卡已修正计数及 seed 说明。

## 最终验证

2026-11-09：全部 5 张成品已保存，`qa_first_batch.py` 退出 0；四张立绘的四角和外边透明，主体非空且近不透明，头顶有效像素从 y=61～62 开始，符合约 8% 留白；CG 为 1920×1080 RGB、不透明。原图及处理报告均保留。最终 SHA-256 见 `art_src/qa/portraits.sha256`，已逐项重新计算核对；完整提示词与实际生成报告的请求内容一致。

技术侧逐图及独立目视复核未发现必须返工的明显问题，328×328 头像可辨识；这不代表 Claude／用户已经批准风格。详见 `art_src/m1_portraits/visual-review.md`。已知限制为人物主体轻微半透明（主要 alpha 253/255）、CG 由 1672×941 等比放大约 1.148 倍后右侧补 1px 暗色、激光网合拢动势偏静态，CG 金属反光比立绘更写实。

成品完成后在仓库根目录运行 `bash game/tools/run_tests.sh`，退出 0，共 380 个测试、失败 0 个，日志保存于本目录 `tests.log`。没有修改游戏代码或数据。图片仅留本机；提示词、生成/处理报告、QA、校验和及交付说明纳入版本记录。
