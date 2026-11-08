extends Node
## 真实的传输层：用 HTTPRequest 发一次 POST，完成后回调 done({"ok", "status", "body", "error"})。
## 这个节点要挂在场景树里才能联网（例如做成自动加载）；不在树里时直接回调错误 not_in_tree。
## 流式输出（对话逐字出现）用 sse.gd 解析，等界面需要时再在这里加 HTTPClient 的流式读取。


func send(req: Dictionary, done: Callable) -> void:
	if not is_inside_tree():
		done.call({"ok": false, "status": 0, "body": "", "error": "not_in_tree"})
		return
	var http := HTTPRequest.new()
	http.timeout = float(req.get("timeout", 60.0))
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		http.queue_free()
		var ok := result == HTTPRequest.RESULT_SUCCESS
		done.call({"ok": ok, "status": code, "body": body.get_string_from_utf8(), "error": "" if ok else "result_%d" % result})
	)
	var err := http.request(String(req["url"]), req["headers"], HTTPClient.METHOD_POST, String(req["body"]))
	if err != OK:
		http.queue_free()
		done.call({"ok": false, "status": 0, "body": "", "error": "request_error_%d" % err})
