extends SceneTree
## 任务卡 007：导出每个地点的版式图（照着画整张地图），检查已经画好的地图和行走图。
## 用法（仓库根目录）：godot --headless --path game -s res://tools/field_guides.gd
## 输出（都在仓库根目录的 art_src/field/ 下，图片不进仓库）：
##   guides/<地点>.png      480×256，一格一色的版式图（图例见 ui/field/field_guide.gd 的 COLORS）
##   guides/<地点>_x4.png   同一张放大 4 倍（1920×1024），给生图当构图参考
##   qa/<地点>_overlay.png  已经有 game/art/field/maps/<地点>.png 时：画好的图放大 4 倍，盖上碰撞颜色和格线
## 同时检查：地图是不是 480×256、不透明；game/art/field/walkers/ 下的行走图是不是 4×4、单帧 32×32、有透明。
## 有问题时退出码为 1，并逐条打印。

const FieldMap = preload("res://ui/field/field_map.gd")
const FieldArt = preload("res://ui/field/field_art.gd")
const FieldGuide = preload("res://ui/field/field_guide.gd")

const MAPS := "res://data/maps/biohazard1.json"
const MAP_SIZE := Vector2i(480, 256)


func _initialize() -> void:
	var out := ProjectSettings.globalize_path("res://").path_join("../art_src/field")
	DirAccess.make_dir_recursive_absolute(out.path_join("guides"))
	DirAccess.make_dir_recursive_absolute(out.path_join("qa"))
	var problems: Array[String] = []
	var all := FieldMap.load_file(MAPS)
	for loc: String in all["maps"]:
		var m: RefCounted = FieldMap.make(MAPS, loc)
		var g := FieldGuide.guide(m)
		g.save_png(out.path_join("guides/%s.png" % loc))
		var g4 := g.duplicate() as Image
		g4.resize(g.get_width() * FieldGuide.ZOOM, g.get_height() * FieldGuide.ZOOM, Image.INTERPOLATE_NEAREST)
		g4.save_png(out.path_join("guides/%s_x4.png" % loc))
		var painted := FieldArt.map_image(loc)
		if painted == null:
			print("%s：版式图已导出，还没有画好的地图" % loc)
			continue
		var img := painted.get_image()
		if img.get_size() != MAP_SIZE:
			problems.append("%s：地图是 %s，应该是 %s" % [loc, img.get_size(), MAP_SIZE])
		if img.detect_alpha() != Image.ALPHA_NONE:
			problems.append("%s：地图有透明像素，应该不透明" % loc)
		FieldGuide.overlay(m, img).save_png(out.path_join("qa/%s_overlay.png" % loc))
		print("%s：版式图、对位图已导出" % loc)
	var walkers := "res://art/field/walkers/"
	var dir := DirAccess.open(walkers)
	if dir != null:
		for file in dir.get_files():
			if not file.ends_with(".png"):
				continue
			var tex := FieldArt._load(walkers + file)
			if tex == null:
				problems.append("行走图 %s 读不出来" % file)
				continue
			for p in FieldGuide.check_sheet(tex.get_image()):
				problems.append("行走图 %s：%s" % [file, p])
			print("行走图 %s：%s" % [file, tex.get_size()])
	for p in problems:
		print("问题：", p)
	print("完成，问题 %d 个" % problems.size())
	quit(1 if not problems.is_empty() else 0)
