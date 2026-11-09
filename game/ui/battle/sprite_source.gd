extends RefCounted
## 战斗小人与战斗背景从哪来（设计规格 11：Q 版像素小人，单帧 48×48，我方朝右、敌方朝左；背景 480×270）。
## 小人按顺序找：
##   1. res://art/battle/<key>/sprite_frames.tres（任务卡 006 由 Codex 生成；图片只在本机，不进仓库）；
##   2. 像素试验（任务卡 003）留下的两套：郑吒、研究员丧尸（给普通丧尸用）；
##   3. 都没有就用代码画一张静态帧：人物画一个 Q 版全身小人（配色取 pixel_art.gd 的 PEOPLE），
##      敌人用 pixel_art.gd 的敌人图；动作靠位移和闪色补。
## .tres 是文本、进仓库，但它引用的 PNG 不进仓库，所以先查依赖是否都在，缺了就跳过，免得加载报错。
## 动作名统一成 idle / attack / hit / down；试验图里丧尸的倒地叫 death，按 down 用。

const PixelArt = preload("res://ui/art/pixel_art.gd")

const ART_FRAMES := "res://art/battle/%s/sprite_frames.tres"
const ART_BG := "res://art/battle/bg_%s.png"
const TRIAL_FRAMES := {
	"zheng_zha": "res://art/pixel_test/zheng_zha/sprite_frames.tres",
	"zombie": "res://art/pixel_test/zombie_scientist/sprite_frames.tres",
}
const TRIAL_BG := "res://art/pixel_test/bg_lab_corridor_pixel.png"
const BG_SIZE := Vector2i(480, 270)
## 共用调色板里的几种颜色，画缺图时的备用背景。
const WALL_TOP := Color("0B0F1A")
const WALL_LOW := Color("20283B")
const FLOOR := Color("30384A")
const FLOOR_LINE := Color("263C54")
const HORIZON := Color("141B2B")

static var _frames_cache: Dictionary = {}


## 单位用哪套图：轮回者按角色 id，敌人按敌人种类（zombie_3 用 zombie）。
static func key_of(unit_id: String, character_id: String, def_id: String, side: String) -> String:
	if side == "ally":
		return character_id if character_id != "" else unit_id
	return def_id if def_id != "" else unit_id


static func frames(key: String, side: String) -> SpriteFrames:
	var ck := key + ":" + side
	if _frames_cache.has(ck):
		return _frames_cache[ck]
	var found: SpriteFrames = null
	for path: String in [ART_FRAMES % key, String(TRIAL_FRAMES.get(key, ""))]:
		if path == "" or not usable(path):
			continue
		var res := load(path) as SpriteFrames
		if res != null and res.has_animation("idle"):
			found = res
			break
	if found == null:
		found = _static_frames(key, side)
	_frames_cache[ck] = found
	return found


## 有没有真正的逐帧动作（代码画的静态帧只有一张 idle）。
static func animated(f: SpriteFrames) -> bool:
	return f.has_animation("attack") and f.get_frame_count("attack") > 1


## 动作名对不上时的替代：down 找不到就找 death，再找不到就 idle。
static func action_name(f: SpriteFrames, action: String) -> String:
	if f.has_animation(action):
		return action
	if action == "down" and f.has_animation("death"):
		return "death"
	return "idle"


## 战斗背景：art/battle/bg_<地点>.png → 像素试验的走廊 → 代码画的墙和地面。尺寸不对的不用。
static func background(location: String) -> Texture2D:
	for path: String in [ART_BG % location, TRIAL_BG]:
		if location == "" and path != TRIAL_BG:
			continue
		if usable(path):
			var tex := load(path) as Texture2D
			if tex != null and Vector2i(tex.get_size()) == BG_SIZE:
				return tex
	return fallback_background()


## 代码画的备用背景：上面是渐暗的墙，下面 40% 是地面（留给三排站位），地面有横线。
static func fallback_background() -> Texture2D:
	var img := Image.create(BG_SIZE.x, BG_SIZE.y, false, Image.FORMAT_RGBA8)
	var horizon := int(BG_SIZE.y * 0.6)
	for y in BG_SIZE.y:
		var c: Color
		if y < horizon:
			c = WALL_TOP.lerp(WALL_LOW, float(y) / float(horizon))
		elif y < horizon + 3:
			c = HORIZON
		else:
			c = FLOOR_LINE if (y - horizon) % 12 == 0 else FLOOR
		for x in BG_SIZE.x:
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


## 资源存在、而且它依赖的文件（图集 PNG）也都在本机。
static func usable(path: String) -> bool:
	if not ResourceLoader.exists(path):
		return false
	for dep: String in ResourceLoader.get_dependencies(path):
		var cut := dep.rfind("res://")
		if cut < 0:
			continue
		var dep_path := dep.substr(cut).get_slice("::", 0)
		if not ResourceLoader.exists(dep_path) and not FileAccess.file_exists(dep_path):
			return false
	return true


static func _static_frames(key: String, side: String) -> SpriteFrames:
	var f := SpriteFrames.new()
	if f.has_animation("default"):
		f.rename_animation("default", "idle")
	elif not f.has_animation("idle"):
		f.add_animation("idle")
	var person := side == "ally" or PixelArt.PEOPLE.has(key)
	f.add_frame("idle", figure(key, side) if person else PixelArt.unit(key, side))
	f.set_animation_loop("idle", true)
	return f


## 代码画的 Q 版全身小人：24×34，约 2.5 头身，脚在最底一行；我方朝右，敌方朝左。
static func figure(key: String, side: String) -> Texture2D:
	var colors: Array = PixelArt.PEOPLE.get(key, ["#4a5568", "#e0bb95", "#2b2119"])
	var shirt := Color(String(colors[0]))
	var skin := Color(String(colors[1]))
	var hair := Color(String(colors[2]))
	var pants := shirt.darkened(0.55)
	var dark := PixelArt.DARK
	var img := Image.create(24, 34, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_box(img, 6, 0, 12, 12, dark)
	_box(img, 7, 1, 10, 10, skin)
	_box(img, 7, 1, 10, 3, hair)
	_box(img, 7, 4, 2, 3, hair)
	var eye := 12 if side == "ally" else 9
	_box(img, eye, 6, 1, 2, dark)
	_box(img, eye + 3, 6, 1, 2, dark)
	_box(img, 6, 12, 12, 12, dark)
	_box(img, 7, 12, 10, 11, shirt)
	_box(img, 4, 13, 3, 9, dark)
	_box(img, 5, 13, 2, 7, shirt)
	_box(img, 5, 20, 2, 2, skin)
	_box(img, 17, 13, 3, 9, dark)
	_box(img, 17, 13, 2, 7, shirt)
	_box(img, 17, 20, 2, 2, skin)
	_box(img, 7, 23, 10, 9, dark)
	_box(img, 8, 23, 3, 8, pants)
	_box(img, 13, 23, 3, 8, pants)
	_box(img, 7, 32, 4, 2, dark)
	_box(img, 13, 32, 4, 2, dark)
	return ImageTexture.create_from_image(img)


static func _box(img: Image, x: int, y: int, w: int, h: int, c: Color) -> void:
	img.fill_rect(Rect2i(x, y, w, h), c)
