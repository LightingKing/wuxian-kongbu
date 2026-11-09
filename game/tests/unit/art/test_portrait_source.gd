extends "res://tests/test_case.gd"
## 立绘来源：有正式图就用、没有回退像素头像；CG 没有就返回 null。
## 图片不进仓库，所以"有图"的分支要看本机实际文件，没有就跳过（但仍记一次断言）。

const PortraitSource = preload("res://ui/art/portrait_source.gd")


func before_each() -> void:
	PortraitSource.clear_cache()


func test_real_portrait_size_when_present() -> void:
	if not PortraitSource.has_portrait("zheng_zha"):
		assert_true(true, "本机没有正式立绘，跳过尺寸检查")
		return
	var tex: Texture2D = PortraitSource.portrait("zheng_zha")
	assert_eq(tex.get_width(), 512)
	assert_eq(tex.get_height(), 768)


func test_falls_back_to_pixel_avatar() -> void:
	assert_false(PortraitSource.has_portrait("no_such_character"))
	var tex: Texture2D = PortraitSource.portrait("no_such_character")
	assert_eq(tex.get_width(), 24, "回退到 24px 像素头像")
	assert_eq(tex.get_height(), 24)


func test_cache_returns_same_instance() -> void:
	var a: Texture2D = PortraitSource.portrait("zhan_lan")
	var b: Texture2D = PortraitSource.portrait("zhan_lan")
	assert_true(a == b, "同一个 id 不重复加载")


func test_clear_cache_reloads() -> void:
	var a: Texture2D = PortraitSource.portrait("zhan_lan")
	PortraitSource.clear_cache()
	var b: Texture2D = PortraitSource.portrait("zhan_lan")
	assert_true(a != null and b != null)
	assert_eq(b.get_width(), a.get_width())


func test_cg_is_null_when_missing() -> void:
	assert_true(PortraitSource.cg("no_such_cg") == null)


func test_cg_size_when_present() -> void:
	if not PortraitSource.has_cg("cg_laser"):
		assert_true(true, "本机没有激光通道 CG，跳过")
		return
	var tex: Texture2D = PortraitSource.cg("cg_laser")
	assert_eq(tex.get_width(), 1920)
	assert_eq(tex.get_height(), 1080)
