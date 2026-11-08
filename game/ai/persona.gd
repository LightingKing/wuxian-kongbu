extends RefCounted
## 人设与记忆（设计规格 8.1"上下文与记忆"）：每个由 AI 驱动的角色有一份人设和一份记忆摘要，随存档保存。
## 记忆最多保留 MAX_MEMORIES 条；超出时把最早的两条合并成一条"更早的事"（截到 120 字），所以记忆不会无限增长。
## 人设数据在 data/ai/personas.json；以后造人、新人生成时由引擎按设定写入。

const DataLoader = preload("res://core/util/data_loader.gd")

const PATH := "res://data/ai/personas.json"
const MAX_MEMORIES := 12
const MERGED_MAX := 120

var id: String = ""
var name: String = ""
var role: String = ""
var background: String = ""
var personality: String = ""
var speech: String = ""
var secrets: Array[String] = []
var fallback_lines: Array[String] = []
var memories: Array[String] = []

static var _cache: Dictionary = {}


static func load_all() -> Dictionary:
	if _cache.is_empty():
		var res := DataLoader.load_json(PATH)
		assert(res.ok, res.error)
		_cache = res.data["personas"]
	return _cache


## 按 personas.json 里的 id 创建。
static func from_data(persona_id: String) -> RefCounted:
	var p := new()
	p.load_dict(load_all()[persona_id])
	p.id = persona_id
	return p


func remember(text: String) -> void:
	memories.append(text)
	while memories.size() > MAX_MEMORIES:
		var merged := ("更早的事：%s；%s" % [memories[0], memories[1]]).left(MERGED_MAX)
		memories.remove_at(0)
		memories[0] = merged


## system 里的第二块：人设、记忆、当前局面（每次都不同，放在缓存的世界设定之后）。
func context_text() -> String:
	var lines: Array[String] = ["【你扮演】" + name]
	if background != "":
		lines.append("身份：" + background)
	if personality != "":
		lines.append("性格：" + personality)
	if speech != "":
		lines.append("说话方式：" + speech)
	if not secrets.is_empty():
		lines.append("你知道但绝不会说出口的事：" + "；".join(secrets))
	if not memories.is_empty():
		lines.append("你记得的事：")
		for m in memories:
			lines.append("- " + m)
	return "\n".join(lines)


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"role": role,
		"background": background,
		"personality": personality,
		"speech": speech,
		"secrets": secrets.duplicate(),
		"fallback_lines": fallback_lines.duplicate(),
		"memories": memories.duplicate(),
	}


func load_dict(d: Dictionary) -> void:
	id = String(d.get("id", id))
	name = String(d["name"])
	role = String(d.get("role", ""))
	background = String(d.get("background", ""))
	personality = String(d.get("personality", ""))
	speech = String(d.get("speech", ""))
	secrets.assign(d.get("secrets", []))
	fallback_lines.assign(d.get("fallback_lines", []))
	memories.assign(d.get("memories", []))
