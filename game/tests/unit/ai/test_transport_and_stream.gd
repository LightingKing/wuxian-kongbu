extends "res://tests/test_case.gd"

const HttpTransport = preload("res://ai/http_transport.gd")
const Sse = preload("res://ai/sse.gd")
const Lore = preload("res://ai/lore.gd")


## 不在场景树里时发不出去：立刻回调错误，不会卡住。
func test_http_transport_outside_tree() -> void:
	var t := HttpTransport.new()
	var box := {}
	t.send({"url": "https://example.invalid/v1/messages", "headers": PackedStringArray(), "body": "{}", "timeout": 1.0}, func(r: Dictionary) -> void: box["r"] = r)
	assert_true(box.has("r"))
	assert_false(bool(box["r"]["ok"]))
	assert_eq(box["r"]["error"], "not_in_tree")
	t.free()


## Anthropic 流式输出，数据在任意位置被切开。
func test_sse_anthropic() -> void:
	var s := Sse.new("anthropic")
	var stream := "event: message_start\ndata: {\"type\":\"message_start\",\"message\":{}}\n\n" \
		+ "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"thinking_delta\",\"thinking\":\"\"}}\n\n" \
		+ "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":1,\"delta\":{\"type\":\"text_delta\",\"text\":\"你们\"}}\n\n" \
		+ "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":1,\"delta\":{\"type\":\"text_delta\",\"text\":\"是谁？\"}}\n\n" \
		+ "event: message_delta\ndata: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"end_turn\"}}\n\n" \
		+ "event: message_stop\ndata: {\"type\":\"message_stop\"}\n\n"
	var pieces: Array[String] = []
	var i := 0
	while i < stream.length():
		pieces.append_array(s.feed(stream.substr(i, 7)))
		i += 7
	assert_eq(pieces, ["你们", "是谁？"] as Array[String])
	assert_eq(s.text, "你们是谁？")
	assert_eq(s.stop_reason, "end_turn")
	assert_true(s.done)


func test_sse_openai() -> void:
	var s := Sse.new("openai_compatible")
	var out: Array[String] = s.feed("data: {\"choices\":[{\"delta\":{\"content\":\"别\"},\"finish_reason\":null}]}\r\n\r\ndata: {\"choices\":[{\"delta\":{\"content\":\"跟丢了\"},\"finish_reason\":null}]}\n\n")
	assert_eq(out, ["别", "跟丢了"] as Array[String])
	s.feed("data: {\"choices\":[{\"delta\":{},\"finish_reason\":\"stop\"}]}\n\ndata: [DONE]\n\n")
	assert_eq(s.text, "别跟丢了")
	assert_eq(s.stop_reason, "stop")
	assert_true(s.done)


## 世界设定每次都一样（提示缓存要求前缀不变）。
func test_lore_text_is_stable() -> void:
	var a := Lore.text()
	assert_true(a.begins_with("## 主神空间"))
	assert_true(a.contains("## 输出要求"))
	assert_eq(Lore.text(), a)
