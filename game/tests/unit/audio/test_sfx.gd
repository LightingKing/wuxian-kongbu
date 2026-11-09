extends "res://tests/test_case.gd"
## 音效合成：波形长度、格式、缓存、未知 id、无宿主时不炸。

const Sfx = preload("res://core/audio/sfx.gd")


func _sfx() -> Node:
	return Sfx.new()


func test_recipes_all_synthesize() -> void:
	var sfx := _sfx()
	for id: String in Sfx.RECIPES:
		var w: AudioStreamWAV = sfx._wav(id)
		assert_true(w != null, id)
		assert_eq(int(w.mix_rate), Sfx.RATE)
		assert_eq(int(w.format), int(AudioStreamWAV.FORMAT_16_BITS))
		assert_false(bool(w.stereo))
		var expect := int(float(Sfx.RECIPES[id]["dur"]) * Sfx.RATE) * 2
		assert_eq(w.data.size(), expect, id + " 的长度")
	sfx.free()


func test_unknown_id_is_null() -> void:
	var sfx := _sfx()
	assert_true(sfx._wav("no_such_sound") == null)
	sfx.free()


func test_cache_returns_same_stream() -> void:
	var sfx := _sfx()
	var a: AudioStreamWAV = sfx._wav("click")
	var b: AudioStreamWAV = sfx._wav("click")
	assert_true(a == b, "同一个 id 复用同一份合成结果")
	sfx.free()


func test_samples_are_not_silent() -> void:
	var sfx := _sfx()
	var w: AudioStreamWAV = sfx._wav("gunshot")
	var peak := 0
	for i in range(0, w.data.size(), 2):
		peak = maxi(peak, absi(w.data.decode_s16(i)))
	assert_true(peak > 1000, "波形要有实际振幅，实际峰值 %d" % peak)
	sfx.free()


## 无头测试里没有宿主，play 只能安静地什么都不做。
func test_play_without_host_is_silent() -> void:
	Sfx.host = null
	Sfx.play("click")
	Sfx.play("no_such_sound")
	Sfx.play_for_events([{"type": "death"}, {"type": "action", "action": {"type": "skill", "skill": "pistol_shot_limited"}}])
	assert_true(Sfx.host == null)
