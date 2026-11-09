extends RefCounted
## 程序化像素图：用代码画队友、敌人和地点图标，运行时生成贴图，不落盘、不依赖美术资源。
## 所以仓库里不用放 png（.gitignore 也禁了），缺图也能玩；正式美术到位后把 portrait()/place()
## 换成 load("res://art/...") 即可，界面不用改。
## 风格跟美术规格一致：Q 版 32px 像素、深色描边、高饱和主色。

const UNIT_SIZE := 24
const ENEMY_SIZE := 28
const PLACE_SIZE := 40

const DARK := Color("1b1f28")
const SHADOW := Color("2b303c")

## id → [主色, 肤色, 发色]；没配的角色用默认配色。
const PEOPLE := {
	"zheng_zha": ["#3a4a78", "#e8c39b", "#23262e"],
	"zhan_lan": ["#5a3f73", "#e8c39b", "#23262e"],
	"zhang_jie": ["#47543c", "#d9b489", "#3a3327"],
	"mu_gang": ["#6b4a2f", "#d9b489", "#2b2119"],
	"li_xiao_yi": ["#3f4a58", "#e0bb95", "#2b2119"],
	"xiao_pang_zi": ["#7a5b38", "#efc9a3", "#3a2a1c"],
	"zhong_nian_fu_nv": ["#6b343a", "#e0bb95", "#3a2a1c"],
	"matthew": ["#4a5a6b", "#e0bb95", "#4a4336"],
	"alice": ["#7a3a3a", "#efd0ae", "#8a5a2a"],
	"rain": ["#3f5548", "#d9b489", "#2b2119"],
	"kaplan": ["#4a4a58", "#e0bb95", "#3a3327"],
	"matt": ["#5a5a3f", "#e0bb95", "#3a2a1c"],
	"jd": ["#584a3f", "#d9b489", "#2b2119"],
	"ryan": ["#3f4a58", "#d9b489", "#23262e"],
	"zhushen": ["#8a6a2a", "#f0d68a", "#5a4218"],
	"red_queen": ["#7a2a2f", "#f0c8c8", "#3a1216"],
}

static var _cache: Dictionary = {}


## 队友/剧情人物的头像。side 只影响边框色（我方偏蓝、敌方偏红），目前都按人物画。
static func portrait(id: String, side: String = "ally") -> Texture2D:
	var key := "p:%s:%s" % [id, side]
	if _cache.has(key):
		return _cache[key]
	var tex := ImageTexture.create_from_image(_person(id, side))
	_cache[key] = tex
	return tex


## 敌人头像：按 id 分丧尸、丧尸犬、爬行者、火焰女皇，其余用通用敌人占位。
static func enemy(enemy_id: String) -> Texture2D:
	var key := "e:" + enemy_id
	if _cache.has(key):
		return _cache[key]
	var img: Image
	match enemy_id:
		"zombie_dog":
			img = _dog()
		"licker":
			img = _licker()
		"red_queen":
			img = _queen()
		_:
			img = _zombie()
	var tex := ImageTexture.create_from_image(img)
	_cache[key] = tex
	return tex


## 战场单位统一入口：敌人走 enemy()，其余走 portrait()。
static func unit(unit_id: String, side: String) -> Texture2D:
	if side == "enemy":
		var base := unit_id
		var cut := base.rfind("_")
		if cut > 0 and base.substr(cut + 1).is_valid_int():
			base = base.substr(0, cut)
		return enemy(base)
	return portrait(unit_id, side)


## 地点图标：车厢、大门、楼梯、激光、主机、走廊、冷库、下水道，认不出的用通用方块。
static func place(loc_id: String) -> Texture2D:
	var key := "l:" + loc_id
	if _cache.has(key):
		return _cache[key]
	var tex := ImageTexture.create_from_image(_place(loc_id))
	_cache[key] = tex
	return tex


static func _person(id: String, side: String) -> Image:
	var colors: Array = PEOPLE.get(id, ["#4a5260", "#e0bb95", "#2b2119"])
	var main := Color(String(colors[0]))
	var skin := Color(String(colors[1]))
	var hair := Color(String(colors[2]))
	var img := _blank(UNIT_SIZE, UNIT_SIZE)
	var frame := Color("8a3a3a") if side == "enemy" else Color("3a4a78")
	# 身体
	_fill(img, 7, 12, 10, 9, main)
	_fill(img, 5, 13, 2, 7, main)
	_fill(img, 17, 13, 2, 7, main)
	# 头
	_fill(img, 8, 4, 8, 8, skin)
	_fill(img, 8, 3, 8, 3, hair)
	# 眼睛
	img.set_pixel(10, 8, DARK)
	img.set_pixel(13, 8, DARK)
	# 腿
	_fill(img, 8, 21, 3, 3, SHADOW)
	_fill(img, 13, 21, 3, 3, SHADOW)
	# 脚下阴影与阵营标记
	_fill(img, 6, 23, 12, 1, frame * Color(1, 1, 1, 0.5))
	return img


static func _zombie() -> Image:
	var img := _blank(ENEMY_SIZE, ENEMY_SIZE)
	var skin := Color("7d8f63")
	var cloth := Color("4a4238")
	_fill(img, 8, 4, 9, 9, skin)
	_fill(img, 8, 3, 9, 2, Color("3f4a30"))
	img.set_pixel(10, 7, Color("c8452f"))
	img.set_pixel(14, 7, Color("c8452f"))
	_fill(img, 7, 13, 12, 9, cloth)
	_fill(img, 4, 12, 3, 8, skin)
	_fill(img, 19, 12, 4, 3, skin)
	_fill(img, 8, 22, 3, 4, Color("2f2a24"))
	_fill(img, 15, 22, 3, 4, Color("2f2a24"))
	return img


static func _dog() -> Image:
	var img := _blank(ENEMY_SIZE, ENEMY_SIZE)
	var fur := Color("5b4230")
	var skin := Color("8a6a4a")
	_fill(img, 6, 14, 15, 7, fur)
	_fill(img, 17, 12, 6, 6, skin)
	img.set_pixel(19, 14, Color("c8452f"))
	_fill(img, 22, 14, 3, 2, Color("c8452f"))
	_fill(img, 7, 21, 2, 5, fur)
	_fill(img, 11, 21, 2, 5, fur)
	_fill(img, 17, 21, 2, 5, fur)
	_fill(img, 3, 11, 4, 2, fur)
	return img


static func _licker() -> Image:
	var img := _blank(ENEMY_SIZE, ENEMY_SIZE)
	var skin := Color("6e2b30")
	var dark := Color("3d1518")
	_fill(img, 6, 8, 14, 14, skin)
	_fill(img, 8, 5, 11, 8, skin)
	_fill(img, 8, 4, 11, 2, dark)
	img.set_pixel(10, 8, Color("e0423a"))
	img.set_pixel(15, 8, Color("e0423a"))
	# 外露的舌头与爪
	_fill(img, 11, 17, 3, 6, Color("b0444a"))
	_fill(img, 3, 14, 3, 4, dark)
	_fill(img, 21, 14, 3, 4, dark)
	_fill(img, 6, 22, 4, 2, dark)
	_fill(img, 16, 22, 4, 2, dark)
	return img


static func _queen() -> Image:
	var img := _blank(ENEMY_SIZE, ENEMY_SIZE)
	var glow := Color("c8343c")
	var dim := Color("5e1a20")
	_fill(img, 5, 5, 18, 18, dim)
	_fill(img, 8, 8, 12, 12, glow)
	_fill(img, 11, 11, 6, 6, Color("f0d0d4"))
	_fill(img, 2, 12, 2, 4, dim)
	_fill(img, 24, 12, 2, 4, dim)
	_fill(img, 12, 2, 4, 2, dim)
	_fill(img, 12, 24, 4, 2, dim)
	return img


static func _place(loc_id: String) -> Image:
	var img := _blank(PLACE_SIZE, PLACE_SIZE)
	var line := Color("6f7b8c")
	var accent := Color("e0a458")
	match loc_id:
		"car":
			_fill(img, 6, 14, 28, 12, Color("2f3a48"))
			_fill(img, 9, 17, 8, 5, Color("93a6bd"))
			_fill(img, 20, 17, 8, 5, Color("93a6bd"))
			_fill(img, 10, 26, 6, 4, line)
			_fill(img, 24, 26, 6, 4, line)
		"hall":
			_fill(img, 8, 8, 24, 24, Color("2a3240"))
			_fill(img, 12, 12, 16, 20, Color("0e1218"))
			_fill(img, 8, 8, 24, 2, accent)
		"stairs":
			for i in 4:
				_fill(img, 8, 10 + i * 6, 24, 5, line)
				_fill(img, 8, 15 + i * 6, 24, 1, Color("1a2029"))
		"laser":
			_fill(img, 8, 8, 24, 24, Color("241a1c"))
			for i in 5:
				_fill(img, 8 + i * 5, 8, 1, 24, Color(0.86, 0.25, 0.22, 0.9))
			for i in 5:
				_fill(img, 8, 8 + i * 5, 24, 1, Color(0.86, 0.25, 0.22, 0.6))
		"control":
			_fill(img, 6, 10, 28, 20, Color("20262f"))
			_fill(img, 9, 13, 22, 14, Color("1f4a3a"))
			_fill(img, 12, 17, 16, 2, Color("6fbf73"))
			_fill(img, 12, 21, 10, 2, Color("6fbf73"))
		"corridor":
			_fill(img, 6, 8, 28, 26, Color("2a3240"))
			_fill(img, 14, 14, 12, 14, Color("0e1218"))
			for i in 4:
				_fill(img, 8 + i, 10 + i, 1, 24 - i * 2, line)
				_fill(img, 31 - i, 10 + i, 1, 24 - i * 2, line)
		"freezer":
			_fill(img, 6, 8, 28, 26, Color("26323d"))
			var snow := Color("bcd6e8")
			_fill(img, 19, 12, 2, 18, snow)
			_fill(img, 12, 18, 16, 2, snow)
			_fill(img, 13, 13, 3, 3, snow)
			_fill(img, 25, 24, 3, 3, snow)
		"sewer":
			_fill(img, 7, 10, 26, 22, Color("2a3240"))
			_fill(img, 10, 13, 20, 16, Color("10222a"))
			_fill(img, 10, 26, 20, 4, Color("2f5b6b"))
			_fill(img, 12, 27, 6, 1, Color("4f8b9b"))
			_fill(img, 20, 28, 5, 1, Color("4f8b9b"))
		_:
			_fill(img, 10, 10, 20, 20, Color("2a3240"))
			_fill(img, 10, 10, 20, 2, line)
	return img


static func _blank(w: int, h: int) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


static func _fill(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for py in range(y, mini(y + h, img.get_height())):
		for px in range(x, mini(x + w, img.get_width())):
			img.set_pixel(px, py, color)
