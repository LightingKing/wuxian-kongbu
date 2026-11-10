extends SceneTree
## 把灰盒图块集画成图片 game/art/tiles/greybox.png（本机用，不进仓库），这样用 Tiled 打开第一部片的地图时看得到图块。
## 游戏本身不需要这张图：图片不在时 field_tiles.gd 会在运行时画同样的灰盒。
## 用法（仓库根目录）：godot --headless --path game -s res://tools/export_greybox.gd

const TiledMap = preload("res://ui/field/tiled_map.gd")
const FieldTiles = preload("res://ui/field/field_tiles.gd")


func _initialize() -> void:
	var m: RefCounted = TiledMap.make("res://data/maps/biohazard1", "hall")
	var info: Dictionary = m.tilesets[0]
	var img := FieldTiles.greybox_image(info, "hall", m.tile)
	var out := ProjectSettings.globalize_path(String(info["image"]))
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	var err := img.save_png(out)
	print("灰盒图块集：", out, "（", img.get_size(), "）" if err == OK else "（保存失败）")
	quit(0 if err == OK else 1)
