extends RefCounted
## 剧情立绘来源：优先用 `res://art/portraits/<id>.png`（Codex 出的正式立绘），
## 没有就退回 `PixelArt.portrait()` 的像素头像——所以美术没到位时界面照样能跑。
## 正式图不进仓库（.gitignore 忽略 png），但导出时 `export_filter=all_resources` 会把它打进包。
## 刚放进来的图还没被 Godot 导入时，ResourceLoader 找不到，这里退回直接读文件（本地开发够用）。

const PixelArt = preload("res://ui/art/pixel_art.gd")

const PORTRAIT_DIR := "res://art/portraits/"
const CG_DIR := "res://art/cg/"

static var _cache: Dictionary = {}
static var _exists: Dictionary = {}


## 这个角色有没有正式立绘（不触发纹理加载，标题/日志里可以放心问）。
static func has_portrait(id: String) -> bool:
	if _exists.has(id):
		return _exists[id]
	var path := PORTRAIT_DIR + id + ".png"
	var found := ResourceLoader.exists(path) or FileAccess.file_exists(path)
	_exists[id] = found
	return found


static func has_cg(name: String) -> bool:
	var path := CG_DIR + name + ".png"
	return ResourceLoader.exists(path) or FileAccess.file_exists(path)


## 对话立绘：有正式图用正式图，没有就用像素头像。
static func portrait(id: String) -> Texture2D:
	if _cache.has(id):
		return _cache[id]
	var tex := _load(PORTRAIT_DIR + id + ".png")
	if tex == null:
		tex = PixelArt.portrait(id)
	_cache[id] = tex
	return tex


## 场景 CG：没有就返回 null（调用方自己决定退化成什么）。
static func cg(name: String) -> Texture2D:
	if _cache.has("cg:" + name):
		return _cache["cg:" + name]
	var tex := _load(CG_DIR + name + ".png")
	_cache["cg:" + name] = tex
	return tex


## 重新生成图片后想立刻看到效果，调这个（否则要重启）。
static func clear_cache() -> void:
	_cache.clear()
	_exists.clear()


static func _load(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res: Resource = load(path)
		if res is Texture2D:
			return res
	if not FileAccess.file_exists(path):
		return null
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)
