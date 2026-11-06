extends RefCounted
## 存档读写（JSON）。铁人模式只有一个存档位，由调用方传入固定路径。

const GameState = preload("res://core/model/game_state.gd")


static func save_to(path: String, state: RefCounted) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(state.to_dict(), "\t"))
	f.close()
	return OK


## 读档失败返回 null。
static func load_from(path: String) -> RefCounted:
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var state := GameState.new()
	state.load_dict(data)
	return state
