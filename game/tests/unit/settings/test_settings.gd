extends "res://tests/test_case.gd"
## 设置：默认值、读写往返、坏文件回退、未知值被忽略、无头下 apply 不炸。

const Settings = preload("res://core/settings/settings.gd")
const PATH := "user://test_settings.json"


func before_each() -> void:
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func _write_raw(text: String) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func test_defaults() -> void:
	var s := Settings.defaults()
	assert_eq(String(s["window_mode"]), "windowed")
	assert_almost(float(s["volume"]), 0.8)


func test_missing_file_uses_defaults() -> void:
	var s := Settings.load_settings(PATH)
	assert_eq(String(s["window_mode"]), "windowed")
	assert_almost(float(s["volume"]), 0.8)


func test_round_trip() -> void:
	assert_eq(Settings.save_settings({"window_mode": "fullscreen", "volume": 0.3}, PATH), OK)
	var back := Settings.load_settings(PATH)
	assert_eq(String(back["window_mode"]), "fullscreen")
	assert_almost(float(back["volume"]), 0.3)


func test_broken_file_falls_back() -> void:
	_write_raw("{broken")
	var s := Settings.load_settings(PATH)
	assert_eq(String(s["window_mode"]), "windowed")
	assert_almost(float(s["volume"]), 0.8)


func test_unknown_mode_and_clamped_volume() -> void:
	_write_raw('{"window_mode": "windowed_fullscreen", "volume": 2.0}')
	var s := Settings.load_settings(PATH)
	assert_eq(String(s["window_mode"]), "windowed", "不认识的值不采纳")
	assert_almost(float(s["volume"]), 1.0, 0.0001, "音量夹到 0~1")


## 无头测试里 apply 直接返回；这里只验证它不改坏字典。
func test_apply_and_with_value() -> void:
	var s := Settings.defaults()
	Settings.apply(s)
	assert_eq(String(s["window_mode"]), "windowed")
	var next := Settings.with_value(s, "volume", 0.5)
	assert_almost(float(next["volume"]), 0.5)
	assert_almost(float(s["volume"]), 0.8, 0.0001, "with_value 不改原字典")
