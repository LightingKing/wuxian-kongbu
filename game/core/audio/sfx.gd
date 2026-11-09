extends Node
## 音效：运行时用正弦波 + 白噪声合成，不依赖音频文件，也不进仓库。
## 用法：main 里 add_child(Sfx.new()) 设好宿主，其余地方 Sfx.play("click")。
## 没有宿主时（无头测试直接调界面）静默返回，不报错、不建节点。
## 音色是刻意做旧的芯片味：短、干、不抢戏，够让点击和开枪有反馈就行。

const BattleData = preload("res://core/battle/battle_data.gd")

const RATE := 22050
const POOL := 8

## dur 秒、f0→f1 频率滑音、noise 噪声占比、decay 指数衰减、vol 音量。
const RECIPES := {
	"click": {"dur": 0.05, "f0": 900.0, "f1": 900.0, "noise": 0.0, "decay": 0.015, "vol": 0.30},
	"gunshot": {"dur": 0.22, "f0": 190.0, "f1": 55.0, "noise": 0.72, "decay": 0.05, "vol": 0.70},
	"hit": {"dur": 0.12, "f0": 150.0, "f1": 70.0, "noise": 0.5, "decay": 0.03, "vol": 0.50},
	"hurt": {"dur": 0.26, "f0": 480.0, "f1": 180.0, "noise": 0.12, "decay": 0.09, "vol": 0.42},
	"death": {"dur": 0.48, "f0": 210.0, "f1": 50.0, "noise": 0.28, "decay": 0.18, "vol": 0.55},
	"coin": {"dur": 0.14, "f0": 1320.0, "f1": 1760.0, "noise": 0.0, "decay": 0.05, "vol": 0.32},
	"confirm": {"dur": 0.18, "f0": 660.0, "f1": 990.0, "noise": 0.0, "decay": 0.07, "vol": 0.32},
	"cancel": {"dur": 0.16, "f0": 420.0, "f1": 280.0, "noise": 0.0, "decay": 0.06, "vol": 0.32},
}

static var host: Node = null
## 缓存与播放器挂在实例上（不是 static），这样随节点释放，不会在退出时被算成泄漏。
var _cache: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []


func _ready() -> void:
	host = self


func _exit_tree() -> void:
	if host == self:
		host = null


## 播一个音效；没有宿主、id 不认识都只是安静地不做。
static func play(id: String) -> void:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return
	# 无头跑测试时音频驱动是 Dummy：播放不会结束，播放器会一直占着，干脆不播。
	if AudioServer.get_driver_name() == "Dummy":
		return
	host._play(id)


func _play(id: String) -> void:
	var stream := _wav(id)
	if stream == null:
		return
	var p := _pick()
	p.stream = stream
	p.play()


func _pick() -> AudioStreamPlayer:
	for p in _players:
		if is_instance_valid(p) and not p.playing:
			return p
	if _players.size() >= POOL:
		return _players[0]
	var p := AudioStreamPlayer.new()
	host.add_child(p)
	_players.append(p)
	return p


## 同一个 id 只合成一次。
func _wav(id: String) -> AudioStreamWAV:
	if _cache.has(id):
		return _cache[id]
	if not RECIPES.has(id):
		return null
	var r: Dictionary = RECIPES[id]
	var stream := _synth(float(r["dur"]), float(r["f0"]), float(r["f1"]), float(r["noise"]), float(r["decay"]), float(r["vol"]))
	_cache[id] = stream
	return stream


static func _synth(dur: float, f0: float, f1: float, noise: float, decay: float, vol: float) -> AudioStreamWAV:
	var n := maxi(int(dur * RATE), 1)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261109
	for i in n:
		var t := float(i) / float(RATE)
		var k := float(i) / float(maxi(n - 1, 1))
		var f := lerpf(f0, f1, k)
		var env := exp(-t / maxf(decay, 0.001))
		var wave := sin(TAU * f * t) * (1.0 - noise) + rng.randf_range(-1.0, 1.0) * noise
		bytes.encode_s16(i * 2, int(clampf(wave * env * vol, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


## 给界面用：从一批事件里挑该响的声音（战斗与主神空间共用）。
static func play_for_events(events: Array) -> void:
	for e: Dictionary in events:
		match String(e.get("type", "")):
			"action":
				var act: Dictionary = e.get("action", {})
				if String(act.get("type", "")) == "skill":
					var all := BattleData.skills()
					var skill_id := String(act.get("skill", ""))
					if all.has(skill_id) and ((all[skill_id] as Dictionary).get("tags", []) as Array).has("bullet"):
						play("gunshot")
			"damage":
				play("hit")
			"death":
				play("death")
			"miss":
				play("cancel")
			"fled":
				play("cancel")
			"exchange_done", "attribute_bought", "repaired", "human_created", "trained", "ticket_split":
				play("coin")
			"exchange_refused", "hub_refused":
				play("cancel")
