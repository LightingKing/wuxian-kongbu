extends RefCounted
## 读取 res://data 下的 JSON。返回 {"ok": bool, "data": Variant, "error": String}。
## 注意：JSON 里的数字一律解析成 float，调用方需要自己转 int。


static func load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "data": null, "error": "文件不存在：" + path}
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		var msg := "%s 第 %d 行：%s" % [path, json.get_error_line(), json.get_error_message()]
		return {"ok": false, "data": null, "error": msg}
	return {"ok": true, "data": json.data, "error": ""}


static func missing_keys(d: Dictionary, keys: Array, ctx: String) -> Array[String]:
	var errs: Array[String] = []
	for k in keys:
		if not d.has(k):
			errs.append("%s 缺少字段 '%s'" % [ctx, k])
	return errs
