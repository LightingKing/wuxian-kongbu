extends RefCounted
## AI 输出记录（设计规格 8.1"可复现"）：每个任务 id 的结果写进存档，读档后同一个任务直接用记录，不会重新调用模型。
## 记录：{"intent": 意图, "source": "ai" 或 "fallback", "reason": 走兜底的原因}

var entries: Dictionary = {}


func has(task_id: String) -> bool:
	return entries.has(task_id)


func get_entry(task_id: String) -> Dictionary:
	return entries[task_id]


func put(task_id: String, entry: Dictionary) -> void:
	entries[task_id] = entry.duplicate(true)


func to_dict() -> Dictionary:
	return {"entries": entries.duplicate(true)}


func load_dict(d: Dictionary) -> void:
	entries = (d["entries"] as Dictionary).duplicate(true)
