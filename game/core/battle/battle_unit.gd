extends RefCounted
## 战斗里的一个单位（轮回者、剧情人物或敌人）。由 unit_factory.gd 创建。
## side：我方 "ally"，敌方 "enemy"。row：0 前排、1 中排、2 后排。

const Statuses = preload("res://core/battle/statuses.gd")

var id: String = ""
var display_name: String = ""
var def_id: String = ""
var character_id: String = ""
var side: String = "ally"
var row: int = 0
var size: int = 1
## "player" 由玩家下令，"ai" 由效用 AI 决定。
var controller: String = "ai"
var ai_profile: String = "nearest"

var hp: float = 1.0
var hp_max: float = 1.0
var base_speed: float = 100.0
var base_attack_mult: float = 1.0
var spirit: float = 100.0
## 只有轮回者有基因锁，能觉醒。
var reincarnator: bool = false
var newbie: bool = false
## 隐藏潜力 0~1，影响觉醒概率（设计规格 3.6）。
var potential: float = 0.0
var gene_lock_stage: int = 0
var fear: float = 0.0

var skills: Array[String] = []
## 能量池与道具数量，例如 {"neili": 30, "grenade": 2}。
var resources: Dictionary = {}
## 技能 → 还要等几次自己的回合。
var cooldowns: Dictionary = {}
var statuses: Array[Dictionary] = []
## 按伤害标签的承伤倍率，例如爬行者 {"bullet": 0.15}。
var tag_mult: Dictionary = {}
## fearless（不会恐惧）、ignores_darkness（黑暗中命中不降）等。
var flags: Array[String] = []
## 第一次行动的延迟倍率，小于 1 表示先手。
var initiative: float = 1.0
## 登场时让对方每人增加的恐惧值。
var fear_aura: float = 0.0
## 重生十字章之类的道具：死亡时消耗一次，以部分生命复活。
var revive_charges: int = 0

var alive: bool = true
var fled: bool = false
## 感染倒计时走完，变成丧尸。
var turned: bool = false
var next_time: float = 0.0
## 本场战斗里已经做过"低血觉醒检定"。
var low_hp_checked: bool = false
## 恐惧满后已经检定过；恐惧降下来以后才会再检定。
var fear_checked: bool = false
## 本场战斗开过基因锁，战后有后遗症（由远征层处理）。
var aftereffect: bool = false
## 敌人提前定好的下一步行动（设计规格 4.6）。
var intent: Dictionary = {}


func in_play() -> bool:
	return alive and not fled


func has_flag(flag: String) -> bool:
	return flags.has(flag)


func hp_ratio() -> float:
	return hp / hp_max


func speed() -> float:
	return base_speed * Statuses.mult(self, "speed_mult")


func attack_mult() -> float:
	return base_attack_mult * Statuses.mult(self, "attack_mult")
