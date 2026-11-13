extends RefCounted
## PC 端设置：窗口模式与主音量。存 user://settings.json，读不到或坏了就用默认值。
## apply() 只在有窗口的时候动引擎；无头跑测试时直接返回，避免 DisplayServer 报警。

const PATH := "user://settings.json"
const MODES: Array[String] = ["windowed", "fullscreen"]


static func defaults() -> Dictionary:
	return {"window_mode": "windowed", "volume": 0.8, "field_wide": true}


static func load_settings(path: String = PATH) -> Dictionary:
	var s := defaults()
	if not FileAccess.file_exists(path):
		return s
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return s
	var data: Variant = json.data
	if not data is Dictionary:
		return s
	if MODES.has(String(data.get("window_mode", ""))):
		s["window_mode"] = String(data["window_mode"])
	if data.has("volume"):
		s["volume"] = clampf(float(data["volume"]), 0.0, 1.0)
	if data.has("field_wide"):
		s["field_wide"] = bool(data["field_wide"])
	return s


static func save_settings(s: Dictionary, path: String = PATH) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(s, "\t"))
	f.close()
	return OK


## 窗口模式：windowed / fullscreen；音量：0~1 的线性值，转成分贝给 Master 总线。
static func apply(s: Dictionary) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if String(s.get("window_mode", "windowed")) == "fullscreen" else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)
	var v := clampf(float(s.get("volume", 0.8)), 0.0, 1.0)
	AudioServer.set_bus_mute(0, v <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001)))


## 改一项并立刻应用，返回新的设置（调用方负责再存盘）。
static func with_value(s: Dictionary, key: String, value: Variant) -> Dictionary:
	var out := s.duplicate()
	out[key] = value
	apply(out)
	return out
