extends RefCounted
## 由六项属性派生战斗属性（设计规格 3.2，系数在 core_rules.json 的 derived 里，可调）。

const Rules = preload("res://core/util/rules.gd")


static func compute(attrs: RefCounted) -> Dictionary:
	var d: Dictionary = Rules.get_rules()["derived"]
	var cell: float = attrs.total("cell_vitality")
	var muscle: float = attrs.total("muscle")
	return {
		"hp_max": float(d["hp_base"]) + float(d["hp_per_cell_vitality"]) * cell + float(d["hp_per_muscle"]) * muscle,
		"speed": attrs.total("nerve_reaction"),
		"attack_mult": muscle / 100.0,
		"mental_resist": attrs.total("spirit"),
		"infection_resist": attrs.total("immunity"),
		"recovery": cell,
	}
