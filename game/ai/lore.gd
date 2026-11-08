extends RefCounted
## 世界设定库（设计规格 8.1"上下文与记忆"）：给 AI 的静态背景，放在 system 的最前面并加提示缓存。
## 内容在 ai/lore/*.json（用 JSON 而不是 .md，导出时会被打包）。以后可以按需要加更多文件（全书摘要、机制百科……）。

const DataLoader = preload("res://core/util/data_loader.gd")

const FILES: Array[String] = ["res://ai/lore/world_rules.json"]

static var _text: String = ""


## 全部设定拼成一段文字；内容不变就每次都一样（提示缓存要求前缀逐字节不变）。
static func text() -> String:
	if _text == "":
		var parts: Array[String] = []
		for path in FILES:
			var res := DataLoader.load_json(path)
			assert(res.ok, res.error)
			for s: Dictionary in res.data["sections"]:
				parts.append("## %s\n%s" % [s["title"], s["text"]])
		_text = "\n\n".join(parts)
	return _text
